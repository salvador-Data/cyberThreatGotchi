#!/usr/bin/env bash
# CTG Lab Playground — interactive menu to experiment with lab tools (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA · https://github.com/salvador-Data/cyberThreatGotchi
#
# Usage: sudo bash ctg-lab-playground.sh
# Staged: /mnt/ctg/ctg-lab-playground.sh or repo scripts/kali/
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CTG_ROOT="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
WIFI_LOG="/var/log/ctg-wifi-lab.log"
WIFI_CONF="/etc/ctg/lab-wifi.conf"
IDS_LOG_DIR="/var/log/ctg-snort"
CLAM_LOG="/var/log/ctg-clamav"

log() { printf '[ctg-playground] %s\n' "$*"; }

professor() {
    printf '\n  📚 Professor note: %s\n\n' "$*"
}

need_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "Run as root: sudo $0" >&2
        exit 1
    fi
}

resolve_script() {
    local name="$1"
    local candidate
    for candidate in \
        "/mnt/ctg/${name}" \
        "/mnt/ctg-backups/${name}" \
        "${SCRIPT_DIR}/${name}" \
        "/opt/ctg/${name}"; do
        if [[ -f "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

resolve_ctg_tool() {
    local rel="$1"
    local candidate
    for candidate in \
        "${CTG_ROOT}/${rel}" \
        "/opt/ctg/tor-http-scrambler/${rel}" \
        "${SCRIPT_DIR}/tor-http-scrambler/${rel}" \
        "/mnt/ctg/tor-http-scrambler/${rel}"; do
        if [[ -f "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

pause_enter() {
    read -r -p "  Press Enter to return to menu..." _
}

# --- menu actions ---

play_wifi_status() {
    professor "Wired Ethernet uses classic promisc on the NIC. WiFi 802.11 capture needs monitor mode (airmon-ng) — promisc alone often cannot see other stations' frames. This demo is read-only status plus an optional monitor toggle hint."
    log "=== WiFi / Ethernet lab status ==="
    if [[ -f "$WIFI_CONF" ]]; then
        log "Config: $WIFI_CONF (mode $(stat -c '%a' "$WIFI_CONF" 2>/dev/null || echo '?'))"
        grep -E '^CTG_LAB_WIFI_SSID=|^CTG_LAB_WIFI_KEY_MGMT=' "$WIFI_CONF" 2>/dev/null | sed 's/PSK=.*/PSK=***redacted***/' || true
    else
        log "No $WIFI_CONF — copy lab-wifi.conf.example from /mnt/ctg"
    fi
    if [[ -f "$WIFI_LOG" ]]; then
        log "Last 8 lines of $WIFI_LOG:"
        tail -n 8 "$WIFI_LOG" 2>/dev/null || true
    else
        log "WiFi lab log not found — run ctg-wifi-lab-autorun.sh once"
    fi
    log "Interfaces:"
    ip -br link 2>/dev/null || ifconfig -a 2>/dev/null | head -20 || true
    local wlan eth
    wlan="$(ip -br link 2>/dev/null | awk '/wl/ {print $1; exit}')"
    eth="$(ip -br link 2>/dev/null | awk '/^e/ && $1 !~ /docker|veth/ {print $1; exit}')"
    if [[ -n "$eth" ]]; then
        local promisc
        promisc="$(cat "/sys/class/net/${eth}/flags" 2>/dev/null | awk '{printf "%d", and($1, 0x100)}')"
        log "Ethernet $eth promisc flag: ${promisc:-unknown} (1=on)"
    fi
    if [[ -n "$wlan" ]]; then
        log "USB/wlan $wlan — monitor demo:"
        read -r -p "  Toggle monitor-mode demo on $wlan? [y/N] " ans
        case "${ans,,}" in
            y|yes)
                if command -v airmon-ng >/dev/null 2>&1; then
                    airmon-ng check kill 2>/dev/null || true
                    airmon-ng start "$wlan" 2>/dev/null || log "airmon-ng failed — driver may lack monitor mode"
                    ip link show 2>/dev/null | grep -E 'mon|wl' || true
                    professor "Monitor interface (wlan0mon) is for authorized lab capture only — never deauth or jam."
                else
                    log "airmon-ng not installed — apt install aircrack-ng in lab only"
                fi
                ;;
            *)
                log "Monitor demo skipped"
                ;;
        esac
    else
        log "No wlan interface detected — plug Realtek USB dongle for WiFi lab"
    fi
    log "Docs: docs/KALI_WIFI_ETH_PROMISC.md"
}

play_shield_status() {
    local shield
    shield="$(resolve_ctg_tool ctg-shield-rotate.sh)" || {
        log "Shield script not installed — run install-scrambler.sh or ctg-lab-autorun.sh"
        return 1
    }
    professor "CTG Shield rotates USB wlan lab IP/MAC after high-severity IDS events (manual y/n in production playbook). DuckDuckGo DNS (94.140.14.14/15) is preserved."
    log "=== CTG Shield status ==="
    bash "$shield" status || true
    read -r -p "  Rotate USB wlan IP/MAC now? [y/N] " ans
    case "${ans,,}" in
        y|yes)
            log "Operator confirmed rotate"
            bash "$shield" rotate || log "Rotate failed — check USB wlan and lab scope"
            ;;
        *)
            log "Rotate skipped (safe default)"
            ;;
    esac
}

play_scrambler_demo() {
    local daemon
    daemon="$(resolve_ctg_tool scrambler-daemon.sh)" || {
        log "Scrambler not installed — run ctg-lab-autorun.sh"
        return 1
    }
    professor "Tor mode routes browser traffic via SOCKS (127.0.0.1:9050). HTTP mode is clearnet for authorized lab targets only. Auto mode reads site-rules.conf (banking→http, .onion→tor). No third-party attacks."
    log "=== Scrambler demo ==="
    bash "$daemon" status 2>/dev/null || true
    for mode in tor http auto; do
        log "Demo set-mode: $mode"
        bash "$daemon" set-mode "$mode" 2>/dev/null || true
        sleep 1
        bash "$daemon" status 2>/dev/null || true
    done
    bash "$daemon" set-mode tor 2>/dev/null || true
    log "Restored default mode: tor"
    log "GUI: python3 ${CTG_ROOT}/ctg-scrambler-gui.py"
    log "Desktop: CTG .TOR/HTTP Scrambler"
    professor "Launch the GUI to toggle modes, tail IDS alerts, and view shield IP/MAC without editing files."
}

play_siem_dry_run() {
    professor "SIEM hook tails IDS/ClamAV/syslog, offers shield rotate on HIGH severity (y/n), and optional local log gzip. Dry-run shows sources only — no rotate prompts."
    log "=== SIEM hook dry-run (read-only tail) ==="
    local src found=false
    for src in \
        /var/log/ctg-snort/alert \
        /var/log/ctg-snort/suricata-fast.log \
        /var/log/ctg-snort/suricata-eve.json \
        /var/log/ctg-clamav/scan.log \
        /var/log/suricata/fast.log \
        /var/log/snort/alert \
        /var/log/ctg-siem/alerts.log; do
        if [[ -f "$src" ]]; then
            found=true
            log "--- tail -5 $src ---"
            tail -n 5 "$src" 2>/dev/null || true
        fi
    done
    if ! $found; then
        log "No alert files yet — run: sudo bash $(resolve_script ctg-ids-ips-autorun.sh || echo ctg-ids-ips-autorun.sh) --optimize --skip-snort"
    fi
    log "Live hook (with prompts): sudo $(resolve_ctg_tool siem-hook.sh || echo /opt/ctg/tor-http-scrambler/siem-hook.sh)"
    log "Windows tail: Backups/logs/siem/ctg-siem-latest.json"
}

play_clamav_scan() {
    professor "ClamAV scans /home for malware signatures — defensive hygiene on your lab VM, not offensive payload delivery. Small scan limits keep the 8 GB VM responsive."
    log "=== ClamAV test scan /home (small) ==="
    if ! command -v clamscan >/dev/null 2>&1; then
        log "clamscan not installed — run ctg-ids-ips-autorun.sh --install"
        return 1
    fi
    mkdir -p "$CLAM_LOG" 2>/dev/null || true
    local out="${CLAM_LOG}/playground-scan.log"
    log "Scanning /home (max 50 files) — log: $out"
    clamscan -r --max-files=50 /home 2>&1 | tee "$out" | tail -n 15
    log "Full scheduled scan: systemctl list-timers ctg-clamav-scan.timer"
}

play_ids_tail() {
    professor "Suricata is primary on this lab VM (detect-only). Snort may coexist if installed. Alerts are for your lab segment — tune rules, do not point IDS at unauthorized networks."
    log "=== Last 5 IDS alert lines ==="
    local found=false f
    for f in \
        "${IDS_LOG_DIR}/suricata-fast.log" \
        "${IDS_LOG_DIR}/alert" \
        /var/log/suricata/fast.log \
        /var/log/snort/alert; do
        if [[ -f "$f" ]]; then
            found=true
            log "--- $f ---"
            tail -n 5 "$f" 2>/dev/null || true
        fi
    done
    if ! $found; then
        log "No Suricata/Snort logs — install via ctg-ids-ips-autorun.sh"
    fi
}

play_rogue_ap_guard() {
    local guard
    guard="$(resolve_script rogue-ap-guard.sh)" || {
        log "rogue-ap-guard.sh not found on /mnt/ctg — stage from repo"
        return 1
    }
    professor "Passive scan only: duplicate SSIDs, open networks, evil-twin hints. No deauth, no jamming. Compare against your known home SSID."
    local ssid=""
    read -r -p "  Enter your known home/lab SSID (authorized AP you own): " ssid
    if [[ -z "$ssid" ]]; then
        log "SSID empty — skipped"
        return 0
    fi
    log "Running passive rogue AP guard for SSID: $ssid"
    bash "$guard" -k "$ssid" || log "Scan finished with warnings — see ~/Backups/logs/rogue-ap-guard.log"
}

play_tor_check() {
    professor "Tor connectivity check uses SOCKS5 to 127.0.0.1:9050 — same path as scrambler tor mode. If this fails, run: systemctl start tor"
    log "=== Tor connectivity check ==="
    systemctl is-active tor 2>/dev/null && log "tor service: active" || log "tor service: inactive — starting..."
    systemctl start tor 2>/dev/null || true
    sleep 2
    if command -v curl >/dev/null 2>&1; then
        log "curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip"
        curl -sS --max-time 25 --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip 2>&1 || log "Tor curl failed — is tor running?"
    else
        log "curl not installed"
    fi
    if command -v torsocks >/dev/null 2>&1; then
        log "torsocks curl https://check.torproject.org/api/ip"
        torsocks curl -sS --max-time 25 https://check.torproject.org/api/ip 2>&1 || true
    fi
}

play_nmap_ask() {
    local ask_bin=""
    for candidate in /usr/local/bin/ctg-nmap-ask /opt/ctg/nmap-ask/ctg-nmap-ask.sh /mnt/ctg/ctg-nmap-ask.sh; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            ask_bin="$candidate"
            break
        fi
    done
    professor "a\$k (ctg-nmap-ask) runs an adaptive nmap ladder: discovery → ports → services → OS → safe NSE. State JSON stores IP/MAC for reconnect after VM reboot. Lab-targets gate blocks non-lab IPs unless -i."
    if [[ -z "$ask_bin" ]]; then
        log "ctg-nmap-ask not installed — run: sudo bash /mnt/ctg/kali-boot-autopatch.sh --install"
        return 1
    fi
    log "=== nmap-ask (a\$k) — verify / list / optional scan ==="
    bash "$ask_bin" --help 2>&1 | head -20 || true
    bash "$ask_bin" --list 2>/dev/null || true
    read -r -p "  Dump identifiers for a lab target IP (blank to skip): " dump_tgt
    if [[ -n "$dump_tgt" ]]; then
        bash "$ask_bin" --dump "$dump_tgt" 2>/dev/null || log "No saved state for $dump_tgt"
    fi
    read -r -p "  Run adaptive scan? Enter lab IP/CIDR or blank to skip: " tgt
    if [[ -z "$tgt" ]]; then
        log "Scan skipped — invoke: a\$k <lab-ip> or a\$k - to reconnect"
        return 0
    fi
    read -r -p "  Confirm scan of $tgt (authorized lab only)? [y/N] " confirm
    case "${confirm,,}" in
        y|yes)
            log "Running: bash $ask_bin $tgt"
            bash "$ask_bin" "$tgt" || log "Scan finished with warnings — see /var/log/ctg/nmap-ask.log"
            ;;
        *)
            log "Scan skipped (safe default)"
            ;;
    esac
    log "Docs: docs/NMAP_ASK_ANALYSIS.md"
}

play_lab_dry_status() {
    professor "Dry status checks what ctg-lab-autorun would use — without rebooting or re-running bootstrap. Green checks mean that phase is ready."
    log "=== CTG lab stack dry status ==="
    local ok miss
    ok=0 miss=0
    check_item() {
        local label="$1" path="$2"
        if [[ -e "$path" ]] || [[ "$path" == service:* && $(systemctl is-active "${path#service:}" 2>/dev/null) == active ]]; then
            log "  [OK]   $label"
            ok=$((ok + 1))
        else
            log "  [MISS] $label"
            miss=$((miss + 1))
        fi
    }
    check_item "bootstrap marker" "/var/lib/ctg/kali-bootstrap.done"
    check_item "ctg share mount" "/mnt/ctg"
    check_item "lab-wifi.conf" "$WIFI_CONF"
    check_item "scrambler daemon" "$(resolve_ctg_tool scrambler-daemon.sh || echo /opt/ctg/tor-http-scrambler/scrambler-daemon.sh)"
    check_item "tor service" "service:tor"
    check_item "suricata service" "service:ctg-suricata"
    check_item "ids-ips service" "service:ctg-ids-ips"
    check_item "clamav timer" "/lib/systemd/system/ctg-clamav-scan.timer"
    check_item "siem export dir" "/var/log/ctg-siem"
    check_item "boot autopatch service" "service:ctg-kali-autopatch"
    check_item "nmap-ask binary" "/usr/local/bin/ctg-nmap-ask"
    check_item "nmap-ask state dir" "/var/log/ctg/nmap-ask"
    log "Summary: $ok ready, $miss missing/optional"
    log "Full autorun (may reboot): CTG_NO_REBOOT=1 sudo bash $(resolve_script ctg-lab-autorun.sh || echo /mnt/ctg/ctg-lab-autorun.sh)"
}

show_menu() {
    cat <<'MENU'

╔══════════════════════════════════════════════════════════╗
║  CTG Lab Playground — authorized lab only (Hacker Planet) ║
╠══════════════════════════════════════════════════════════╣
║  1  WiFi status + promisc/monitor toggle demo           ║
║  2  Shield status + optional rotate (y/n)               ║
║  3  Scrambler tor/http/auto demo + GUI hint             ║
║  4  SIEM hook dry-run (tail only)                       ║
║  5  ClamAV test scan /home (small)                      ║
║  6  Suricata/Snort tail alerts (5 lines)                ║
║  7  Rogue AP guard scan (prompt home SSID)              ║
║  8  Tor connectivity check (curl via tor)               ║
║  9  Full lab dry status (what's installed)              ║
║ 10  nmap-ask (a$k) adaptive lab recon                  ║
║  0  Exit                                                  ║
╚══════════════════════════════════════════════════════════╝
MENU
}

main_loop() {
    need_root
    log "CTG Lab Playground — systems you own or have written scope to test."
    while true; do
        show_menu
        read -r -p "  Choose [0-9]|10: " choice
        case "${choice:-}" in
            1) play_wifi_status ;;
            2) play_shield_status ;;
            3) play_scrambler_demo ;;
            4) play_siem_dry_run ;;
            5) play_clamav_scan ;;
            6) play_ids_tail ;;
            7) play_rogue_ap_guard ;;
            8) play_tor_check ;;
            9) play_lab_dry_status ;;
            10) play_nmap_ask ;;
            0|q|Q) log "Good lab session — stay defensive."; exit 0 ;;
            *) log "Invalid choice: $choice" ;;
        esac
        pause_enter
    done
}

main_loop "$@"
