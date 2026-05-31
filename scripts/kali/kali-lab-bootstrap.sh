#!/usr/bin/env bash
# CyberThreatGotchi — Kali lab bootstrap (authorized defensive use only).
# Hacker Planet LLC · Philadelphia, PA · https://github.com/salvador-Data/cyberThreatGotchi
#
# Run on Kali after gold install: sudo ./kali-lab-bootstrap.sh [--wifi-profile=company-lab|home-conservative]
# No secrets in this script — OSINT API keys via /etc/environment.d/ctg-osint.env (mode 600).
#
# WiFi Option 2 (company-lab, DEFAULT): legal regdomain + lab-isolated RF tuning only.
# Does NOT bypass FCC/ETSI limits, illegal TX power, or regulatory domain evasion.

set -euo pipefail

WIFI_PROFILE="${WIFI_PROFILE:-company-lab}"
SKIP_SNORT=false
SKIP_REALTEK=false
DRY_RUN=false
PRESERVE_DDG_DNS=true
DDG_DNS_ONLY=false
LAB_ANONYMITY=true
INSTALL_SCRAMBLER=true
LAB_TARGETS_EXAMPLE="scripts/kali/lab-targets.example"
LAB_TARGETS_CONF="scripts/kali/lab-targets.conf"

DDG_DNS_PRIMARY="94.140.14.14"
DDG_DNS_SECONDARY="94.140.15.15"
DDG_DOH_URL="https://dns.duckduckgo.com/dns-query"
IPHONE_HARDENING_DOC="docs/IPHONE_HARDENING.md"

usage() {
    cat <<'EOF'
Usage: kali-lab-bootstrap.sh [OPTIONS]

Options:
  --wifi-profile=PROFILE   company-lab (default) | home-conservative
  --preserve-ddg-dns       Respect existing DuckDuckGo DNS in resolv.conf (default ON)
  --no-preserve-ddg-dns    Allow overwriting resolv.conf without DDG check
  --ddg-dns-only           Set resolv.conf + optional Unbound stub to DuckDuckGo only
  --skip-snort             Skip passive Snort install
  --skip-realtek           Skip Realtek USB driver detection/install
  --lab-anonymity          Install Tor, proxychains4, Tor Browser launcher (default ON)
  --no-lab-anonymity       Skip anonymity packages (tor/proxychains/Tor Browser deps)
  --install-scrambler      Install CTG Tor/HTTP scrambler (default ON with --lab-anonymity)
  --no-install-scrambler   Skip tor-http-scrambler install
  --dry-run                Print planned actions only
  -h, --help               Show this help

DuckDuckGo DNS: $DDG_DNS_PRIMARY / $DDG_DNS_SECONDARY (DoH: $DDG_DOH_URL).
Preserve rules match $IPHONE_HARDENING_DOC — do NOT stack NextDNS/Cloudflare on host or phone.

Lab anonymity: privacy research (Tor Browser, proxychains) — NOT crime or law-enforcement evasion.
Pentest tools (nmap, metasploit, burp, sqlmap): lab targets in $LAB_TARGETS_CONF only (see $LAB_TARGETS_EXAMPLE).
Bootstrap does NOT configure illegal exit nodes or attack C2.

Authorized use: systems and RF you own or have written scope to test (Hacker Planet lab VLAN).
EOF
}

for arg in "$@"; do
    case "$arg" in
        --wifi-profile=*) WIFI_PROFILE="${arg#*=}" ;;
        --preserve-ddg-dns) PRESERVE_DDG_DNS=true ;;
        --no-preserve-ddg-dns) PRESERVE_DDG_DNS=false ;;
        --ddg-dns-only) DDG_DNS_ONLY=true; PRESERVE_DDG_DNS=true ;;
        --skip-snort) SKIP_SNORT=true ;;
        --skip-realtek) SKIP_REALTEK=true ;;
        --lab-anonymity) LAB_ANONYMITY=true; INSTALL_SCRAMBLER=true ;;
        --no-lab-anonymity) LAB_ANONYMITY=false; INSTALL_SCRAMBLER=false ;;
        --install-scrambler) INSTALL_SCRAMBLER=true ;;
        --no-install-scrambler) INSTALL_SCRAMBLER=false ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
    esac
done

if [[ "$WIFI_PROFILE" != "company-lab" && "$WIFI_PROFILE" != "home-conservative" ]]; then
    echo "Invalid --wifi-profile=$WIFI_PROFILE (use company-lab or home-conservative)" >&2
    exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $0 $*" >&2
    exit 1
fi

log() { printf '[ctg-kali] %s\n' "$*"; }
run() {
    if $DRY_RUN; then
        log "[dry-run] $*"
    else
        log "+ $*"
        "$@"
    fi
}

CTG_ENV="/etc/environment.d/ctg-osint.env"
CTG_WIFI_BASE="/usr/local/sbin/wifi-lab-baseline.sh"

log "CyberThreatGotchi Kali lab bootstrap — wifi-profile=$WIFI_PROFILE preserve-ddg-dns=$PRESERVE_DDG_DNS ddg-dns-only=$DDG_DNS_ONLY lab-anonymity=$LAB_ANONYMITY install-scrambler=$INSTALL_SCRAMBLER"
log "DuckDuckGo preserve: same rules as $IPHONE_HARDENING_DOC — no NextDNS/Cloudflare stack on host/iPhone/router"
log "Authorized pentest: targets only in $LAB_TARGETS_CONF (copy from $LAB_TARGETS_EXAMPLE) — never third parties"

resolv_has_ddg() {
    [[ -f /etc/resolv.conf ]] && grep -qE '94\.140\.(14\.14|15\.15)' /etc/resolv.conf
}

# --- ddg-dns (preserve / optional upstream) ---
log "Phase: ddg-dns (DuckDuckGo preserve)"
if $DDG_DNS_ONLY; then
    log "Configuring Kali resolv.conf + Unbound stub → DuckDuckGo DNS only"
    if ! $DRY_RUN; then
        run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unbound resolvconf 2>/dev/null || \
            run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unbound || true
        mkdir -p /etc/unbound/unbound.conf.d
        cat >/etc/unbound/unbound.conf.d/ctg-ddg-forward.conf <<UNBOUNDEOF
# CTG Kali lab — forward to DuckDuckGo DNS (see docs/OPNSENSE_LAB_DNS.md)
server:
  interface: 127.0.0.1
  access-control: 127.0.0.0/8 allow
  do-not-query-localhost: no
forward-zone:
  name: "."
  forward-addr: $DDG_DNS_PRIMARY
  forward-addr: $DDG_DNS_SECONDARY
UNBOUNDEOF
        systemctl enable --now unbound 2>/dev/null || true
        cat >/etc/resolv.conf <<RESOLVEOF
# CTG Kali lab — DuckDuckGo DNS (ddg-dns-only). Preserve rules: $IPHONE_HARDENING_DOC
nameserver 127.0.0.1
nameserver $DDG_DNS_PRIMARY
nameserver $DDG_DNS_SECONDARY
RESOLVEOF
        log "resolv.conf → 127.0.0.1 (Unbound stub) + DDG fallback nameservers"
    else
        run echo "[dry-run] configure Unbound stub + resolv.conf for DDG only"
    fi
elif $PRESERVE_DDG_DNS && resolv_has_ddg; then
    log "preserve-ddg-dns: DuckDuckGo DNS already in /etc/resolv.conf — no changes"
elif $PRESERVE_DDG_DNS; then
    log "preserve-ddg-dns: resolv.conf has no DDG entries — leaving upstream unchanged (use --ddg-dns-only to set DDG)"
    log "Optional: point Kali to OPNsense lab LAN Unbound with DDG forwarders (docs/OPNSENSE_LAB_DNS.md)"
else
    log "WARNING: --no-preserve-ddg-dns — bootstrap will not protect existing DNS; verify host/iPhone DDG unchanged"
fi

# --- lab-anonymity (Tor / proxychains — privacy research; no illegal exit/C2) ---
if $LAB_ANONYMITY; then
    log "Phase: lab-anonymity (Tor, proxychains4, Tor Browser launcher — authorized lab privacy research)"
    run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        tor torbrowser-launcher proxychains4 firefox-esr 2>/dev/null || \
    run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        tor proxychains4 firefox-esr

    if ! $DRY_RUN; then
        systemctl enable tor 2>/dev/null || true
        systemctl start tor 2>/dev/null || true
        if [[ -f /etc/proxychains4.conf ]] && ! grep -q '^strict_chain' /etc/proxychains4.conf; then
            sed -i 's/^#strict_chain/strict_chain/' /etc/proxychains4.conf 2>/dev/null || true
        fi
        if [[ -f /etc/proxychains4.conf ]] && ! grep -q 'socks5.*127.0.0.1.*9050' /etc/proxychains4.conf; then
            log "proxychains4: ensure [ProxyList] ends with: socks5 127.0.0.1 9050 (Tor SOCKS)"
        fi
    fi
    log "Tor service enabled — SOCKS 127.0.0.1:9050 for authorized lab CLI via proxychains"
    log "Tor Browser: launch manually from desktop (torbrowser-launcher) — first run downloads bundle; verify Tor Project signature"
    log "firefox-esr: optional hardened profile — use Tor Browser for sensitive anonymity research"
    log "Whonix: optional second VM — see docs/KALI_LAB_ARCHITECTURE.md (not installed by bootstrap)"
    log "DNS/WebRTC: run leak checklist in docs/KALI_LAB_ARCHITECTURE.md after enabling Tor or changing DNS"
    log "Do NOT configure illegal exit nodes, custom attack C2, or scans outside lab-targets.conf"
else
    log "Phase: lab-anonymity skipped (--no-lab-anonymity)"
fi

# --- lab-targets reminder ---
if ! $DRY_RUN; then
    CTG_TARGETS="/etc/ctg/lab-targets.conf"
    mkdir -p /etc/ctg
    if [[ ! -f "$CTG_TARGETS" ]]; then
        cat >"$CTG_TARGETS" <<'TARGETSEOF'
# CTG authorized lab targets — edit IPs to match your VMs (Hacker Planet LLC lab only).
# Copy full template from repo: scripts/kali/lab-targets.example
127.0.0.1
10.0.2.0/24
192.168.50.0/24
# 192.168.50.10   # DVWA placeholder
# 192.168.50.11   # Metasploitable placeholder
TARGETSEOF
        chmod 600 "$CTG_TARGETS"
        log "Created $CTG_TARGETS — edit before nmap/metasploit/sqlmap; sync from repo lab-targets.conf"
    else
        log "Lab targets file exists: $CTG_TARGETS"
    fi
fi

# --- harden ---
log "Phase: harden"
run apt-get update -qq
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    fail2ban unattended-upgrades lynis ufw \
    apt-listchanges needrestart

if ! $DRY_RUN; then
    dpkg-reconfigure -plow unattended-upgrades || true
fi

run systemctl enable --now fail2ban || true

if ! $DRY_RUN && command -v ufw >/dev/null; then
    ufw default deny incoming || true
    ufw default allow outgoing || true
    ufw allow 22/tcp comment 'SSH lab' || true
    ufw --force enable || true
fi

# --- clamav ---
log "Phase: clamav"
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq clamav clamav-daemon clamav-freshclam
run systemctl stop clamav-freshclam 2>/dev/null || true
run freshclam || log "freshclam may need retry after mirror sync"
run systemctl enable --now clamav-freshclam clamav-daemon || true

if ! $DRY_RUN; then
    mkdir -p /var/log/ctg-clamav
    cat >/etc/systemd/system/ctg-clamav-home-scan.service <<'CLAMEOF'
[Unit]
Description=CTG weekly ClamAV scan of /home (lightweight)
After=clamav-freshclam.service

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=/usr/bin/clamscan -r --infected --remove=no --log=/var/log/ctg-clamav/scan.log /home
CLAMEOF
    cat >/etc/systemd/system/ctg-clamav-home-scan.timer <<'CLAMEOF'
[Unit]
Description=CTG weekly ClamAV /home scan (Sunday 03:00)

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
CLAMEOF
    systemctl daemon-reload
    systemctl enable --now ctg-clamav-home-scan.timer 2>/dev/null || true
    log "ClamAV weekly timer: ctg-clamav-home-scan.timer"
fi

for d in /home/*/samples /home/*/downloads; do
    if [[ -d "$d" ]]; then
        run clamscan -r --infected --remove=no "$d" || true
    fi
done

# --- passive snort (optional) ---
if ! $SKIP_SNORT; then
    log "Phase: passive snort (detect-only, not inline perimeter)"
    run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq snort snort-rules-default || true
    if ! $DRY_RUN && [[ -f /etc/snort/snort.conf ]]; then
        sed -i 's/^ipvar HOME_NET .*/ipvar HOME_NET 10.0.0.0\/8,172.16.0.0\/12,192.168.0.0\/16/' /etc/snort/snort.conf || true
        systemctl disable snort 2>/dev/null || true
        log "Snort installed but not enabled inline — use SPAN/tap lab exercises only"
    fi
fi

# --- osint tier 1/2 packages ---
log "Phase: osint (apt packages; Maltego CE is manual — EULA)"
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    theharvester amass recon-ng whois dnsutils curl jq \
    spiderfoot maltego-teeth 2>/dev/null || \
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    theharvester amass recon-ng whois dnsutils curl jq

if ! $DRY_RUN && [[ ! -f "$CTG_ENV" ]]; then
    cat >"$CTG_ENV" <<'ENVEOF'
# CTG OSINT API placeholders — set values locally; never commit secrets.
# CTG_SHODAN_API_KEY=
# CTG_CENSYS_API_ID=
# CTG_CENSYS_API_SECRET=
# CTG_VT_API_KEY=
ENVEOF
    chmod 600 "$CTG_ENV"
    log "Created $CTG_ENV (edit API keys locally)"
fi

# --- realtek USB driver detection ---
if ! $SKIP_REALTEK; then
    log "Phase: realtek-driver (conditional on lsusb)"
    run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        dkms build-essential linux-headers-"$(uname -r)" git usbutils

    if lsusb 2>/dev/null | grep -qiE 'realtek|0bda:'; then
        log "Realtek USB device detected:"
        lsusb | grep -iE 'realtek|0bda:' || true
        VIDPID="$(lsusb | grep -iE '0bda:' | head -1 | awk '{print $6}' || true)"
        case "${VIDPID:-}" in
            0bda:8812|0bda:881a|0bda:881b|0bda:8821|0bda:8179|0bda:818b|0bda:818c)
                log "Known Realtek chipset $VIDPID — attempting rtl88xxau DKMS (lab use)"
                if [[ ! -d /usr/src/rtl88xxau ]]; then
                    run git clone --depth 1 https://github.com/aircrack-ng/rtl8812au.git /usr/src/rtl88xxau || true
                    if [[ -d /usr/src/rtl88xxau ]]; then
                        run make -C /usr/src/rtl88xxau dkms_install || log "DKMS build failed — verify headers and chipset"
                    fi
                fi
                ;;
            *)
                log "Realtek present ($VIDPID) but no automated driver role — document in lab journal"
                ;;
        esac
    else
        log "No Realtek USB dongle attached — skip driver (pass through from VirtualBox when ready)"
    fi
fi

# --- wifi-lab-tune ---
log "Phase: wifi-lab-tune (profile=$WIFI_PROFILE)"
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wireless-tools iw wpasupplicant wireshark tshark

if ! $DRY_RUN; then
    mkdir -p "$(dirname "$CTG_WIFI_BASE")"
    cat >"$CTG_WIFI_BASE" <<'WIFIEOF'
#!/usr/bin/env bash
# CTG WiFi lab baseline — legal regdomain only. Authorized lab SSIDs.
set -euo pipefail
REG="${CTG_WIFI_REGDOMAIN:-US}"
echo "[wifi-lab] Setting legal regdomain: $REG"
iw reg set "$REG"
for dev in $(iw dev 2>/dev/null | awk '/Interface/ {print $2}'); do
    ip link set "$dev" up 2>/dev/null || true
    iw dev "$dev" set power_save off 2>/dev/null || true
done
echo "[wifi-lab] Current reg:"
iw reg get
WIFIEOF
    chmod 755 "$CTG_WIFI_BASE"

    mkdir -p /etc/environment.d
    if [[ "$WIFI_PROFILE" == "company-lab" ]]; then
        cat >/etc/environment.d/ctg-wifi.conf <<'EOF'
# Hacker Planet lab — Option 2: company lab VLAN / owned AP only
CTG_WIFI_REGDOMAIN=US
CTG_WIFI_PROFILE=company-lab
EOF
        log "Option 2 company-lab: regdomain US, power_save off, lab AP/VLAN only"
    else
        cat >/etc/environment.d/ctg-wifi.conf <<'EOF'
CTG_WIFI_REGDOMAIN=US
CTG_WIFI_PROFILE=home-conservative
EOF
        log "Option 1 home-conservative profile"
    fi
    CTG_WIFI_REGDOMAIN=US CTG_WIFI_PROFILE="$WIFI_PROFILE" "$CTG_WIFI_BASE" || true
fi

# --- wireshark permissions (analyst group) ---
if ! $DRY_RUN && getent group wireshark >/dev/null; then
    for u in kali sal; do
        if id "$u" &>/dev/null; then
            usermod -aG wireshark "$u" 2>/dev/null || true
        fi
    done
fi

# --- lynis audit (non-fatal) ---
log "Phase: lynis audit (report only)"
run lynis audit system --quick --quiet || true

# --- tor-http-scrambler (CTG Privacy Router lab module) ---
if $INSTALL_SCRAMBLER; then
    log "Phase: tor-http-scrambler (CTG Privacy Router — browser Tor default, site-rules auto)"
    SCRAMBLER_SRC=""
    for candidate in \
        "$(dirname "$0")/tor-http-scrambler/install-scrambler.sh" \
        "/mnt/ctg/tor-http-scrambler/install-scrambler.sh" \
        "/opt/ctg/tor-http-scrambler/install-scrambler.sh"; do
        if [[ -f "$candidate" ]]; then
            SCRAMBLER_SRC="$candidate"
            break
        fi
    done
    if [[ -n "$SCRAMBLER_SRC" ]]; then
        if ! $DRY_RUN; then
            run bash "$SCRAMBLER_SRC"
            run /opt/ctg/tor-http-scrambler/scrambler-daemon.sh set-mode tor || true
            log "Scrambler: manual launch only (desktop CTG .TOR/HTTP Scrambler or ctg-scrambler-gui.py)"
            log "No profile.d login hook — avoids VirtualBox GNOME blank screen"
        else
            run echo "[dry-run] install-scrambler.sh from $SCRAMBLER_SRC"
        fi
    else
        log "install-scrambler.sh not found — copy scripts/kali/tor-http-scrambler to VM and re-run --install-scrambler"
    fi
else
    log "Phase: tor-http-scrambler skipped (--no-install-scrambler or --no-lab-anonymity)"
fi

if ! $DRY_RUN; then
    mkdir -p /var/lib/ctg
    date -Iseconds >/var/lib/ctg/kali-bootstrap.done
fi

log "Bootstrap complete. Next: snapshot VM, attach Realtek USB in VirtualBox, edit $CTG_ENV for OSINT keys."
if $LAB_ANONYMITY; then
    log "Anonymity: launch Tor Browser manually; pentest only against /etc/ctg/lab-targets.conf entries"
fi
log "Maltego CE: manual install from vendor .deb (EULA). Suricata primary IDS belongs on OPNsense, not Kali."
log "DuckDuckGo: preserve host/iPhone/router DNS per $IPHONE_HARDENING_DOC — OPNsense lab forwarders: docs/OPNSENSE_LAB_DNS.md"
log "Pentest (nmap, metasploit, burp, sqlmap): lab-owned VMs and written scope only — see docs/KALI_LAB_ARCHITECTURE.md"
log "One-shot autorun: sudo bash /mnt/ctg/ctg-lab-autorun.sh — see docs/CTG_LAB_AUTORUN.md"
IDS_SCRIPT=""
for ids_candidate in "$(dirname "$0")/ctg-ids-ips-autorun.sh" /mnt/ctg/ctg-ids-ips-autorun.sh; do
    if [[ -f "$ids_candidate" ]]; then
        IDS_SCRIPT="$ids_candidate"
        break
    fi
done
if [[ -n "$IDS_SCRIPT" ]]; then
    log "Phase: ctg-ids-ips (detect-only Snort/Suricata + ClamAV ensure)"
    if ! $DRY_RUN; then
        bash "$IDS_SCRIPT" || log "ctg-ids-ips-autorun returned non-zero (Snort/Suricata may need apt retry)"
    else
        run echo "[dry-run] bash $IDS_SCRIPT"
    fi
else
    log "ctg-ids-ips-autorun.sh not found — stage on ctg share; see docs/KALI_IDS_IPS_CLAMAV.md"
fi
