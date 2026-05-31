#!/usr/bin/env bash
# CTG Network IDS/IPS + ClamAV autorun — Suricata-primary; detect-only default; optional inline IPS.
# Authorized defensive lab use only — Hacker Planet LLC · Philadelphia, PA
#
# Usage:
#   sudo bash ctg-ids-ips-autorun.sh
#   sudo bash ctg-ids-ips-autorun.sh --install
#   sudo bash ctg-ids-ips-autorun.sh --optimize       # CPU affinity, af-packet tune, rule trim
#   sudo bash ctg-ids-ips-autorun.sh --EnableIPS      # NFQUEUE inline — lab VLAN ONLY (dangerous)
#   sudo bash ctg-ids-ips-autorun.sh --skip-snort     # Suricata-primary (lighter VM)
#   sudo bash ctg-ids-ips-autorun.sh --skip-suricata   # Snort-only legacy mode
set -euo pipefail

LOG_FILE="/var/log/ctg-ids-ips.log"
CTG_SNORT_DIR="/etc/ctg/snort"
CTG_SURICATA_DIR="/etc/ctg/suricata"
SNORT_LOG="/var/log/ctg-snort"
CLAMAV_LOG="/var/log/ctg-clamav"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBOOT_HELPER="${SCRIPT_DIR}/ctg-reboot-if-needed.sh"
SERVICE_NAME="ctg-ids-ips.service"
SURICATA_SVC="ctg-suricata.service"
UNIT_DEST="/etc/systemd/system/${SERVICE_NAME}"
SURICATA_UNIT="/etc/systemd/system/${SURICATA_SVC}"
CTG_ROOT="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
SIEM_HOOK="${CTG_SIEM_HOOK:-$CTG_ROOT/siem-hook.sh}"
SHIELD="${CTG_SHIELD_SCRIPT:-$CTG_ROOT/ctg-shield-rotate.sh}"
LAB_VLAN="${CTG_IPS_LAB_VLAN:-192.168.50.0/24}"
NFQUEUE_NUM="${CTG_IPS_NFQUEUE:-0}"

DO_INSTALL=false
DO_ENABLE_IPS=false
DO_SKIP_SURICATA=false
DO_SKIP_SNORT=false
DO_OPTIMIZE=false

log() {
    local msg="[$(date -Iseconds)] [ctg-ids-ips] $*"
    printf '%s\n' "$msg"
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

ctg_reboot_helper() {
    local helper="$REBOOT_HELPER"
    for candidate in /mnt/ctg/ctg-reboot-if-needed.sh /opt/ctg/ctg-reboot-if-needed.sh; do
        if [[ -f "$candidate" ]]; then
            helper="$candidate"
            break
        fi
    done
    [[ -f "$helper" ]] || return 0
    bash "$helper" "$@" || true
}

usage() {
    cat <<EOF
CTG Network IDS/IPS + ClamAV autorun — authorized defensive lab use only.

  sudo bash $0                     ClamAV + Suricata-primary IDS (Snort optional coexist)
  sudo bash $0 --install           Install ${SERVICE_NAME} + ${SURICATA_SVC} for boot
  sudo bash $0 --optimize          CPU affinity, af-packet tune, suricata-update, rule trim
  sudo bash $0 --EnableIPS         Inline IPS via NFQUEUE on ${LAB_VLAN} ONLY (danger)
  sudo bash $0 --skip-snort        Suricata-only (recommended on 8GB Kali VM)
  sudo bash $0 --skip-suricata     Snort-only legacy mode
  sudo bash $0 --help

Logs: ${SNORT_LOG}/ · ${LOG_FILE}
Docs: docs/KALI_IDS_IPS_CLAMAV.md · docs/KALI_SIEM_STACK.md
SIEM: ${SIEM_HOOK} · Shield: ${SHIELD}
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) DO_INSTALL=true ;;
        --EnableIPS|--enable-ips) DO_ENABLE_IPS=true ;;
        --skip-suricata) DO_SKIP_SURICATA=true ;;
        --skip-snort) DO_SKIP_SNORT=true ;;
        --optimize) DO_OPTIMIZE=true ;;
        --help|-h) usage; exit 0 ;;
        *) log "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

if [[ "${CTG_OPTIMIZE:-0}" == "1" ]]; then
    DO_OPTIMIZE=true
fi

mkdir -p "$CTG_SNORT_DIR" "$CTG_SURICATA_DIR" "$SNORT_LOG" "$CLAMAV_LOG" /etc/ctg
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "=== CTG IDS/IPS autorun start (ips=$DO_ENABLE_IPS optimize=$DO_OPTIMIZE skip_snort=$DO_SKIP_SNORT skip_suricata=$DO_SKIP_SURICATA) ==="

iface_link_up() {
    local dev="$1"
    [[ -n "$dev" ]] && ip link show "$dev" 2>/dev/null | grep -q 'state UP'
}

detect_wired_iface() {
    local dev
    for dev in eth0 enp0s3 enp0s8 ens33; do
        if [[ -d "/sys/class/net/$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done
    ip -o link show 2>/dev/null | awk -F': ' '{gsub(/@.*/,"",$2); print $2}' | \
        grep -E '^(eth|enp|eno|ens)' | head -1
}

detect_usb_wlan_iface() {
    local dev phy bus
    while read -r dev; do
        [[ -z "$dev" ]] && continue
        [[ "$dev" =~ ^(eth|enp|eno|ens|em|docker|veth|lo|virbr|vb)$ ]] && continue
        if iw dev "$dev" info 2>/dev/null | grep -q 'type managed'; then
            phy="$(readlink -f "/sys/class/net/${dev}/device" 2>/dev/null || true)"
            bus="$(readlink -f "/sys/class/net/${dev}/device/../.." 2>/dev/null || true)"
            if [[ "$phy" == *usb* ]] || [[ "$bus" == *usb* ]]; then
                echo "$dev"
                return 0
            fi
        fi
    done < <(iw dev 2>/dev/null | awk '/Interface/ {print $2}')
    iw dev 2>/dev/null | awk '/Interface/ {print $2}' | grep -E '^wlan' | tail -1
}

detect_lab_iface() {
    local wired wlan
    wired="$(detect_wired_iface || true)"
    if [[ -n "$wired" ]] && iface_link_up "$wired"; then
        echo "$wired"
        return 0
    fi
    wlan="$(detect_usb_wlan_iface || true)"
    if [[ -z "$wlan" ]]; then
        wlan="$(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | grep -E '^wlan' | head -1 || true)"
    fi
    if [[ -n "$wlan" ]] && ip link show "$wlan" 2>/dev/null | grep -q 'state UP'; then
        echo "$wlan"
        return 0
    fi
    [[ -n "$wired" ]] && echo "$wired" && return 0
    [[ -n "$wlan" ]] && echo "$wlan" && return 0
    echo "eth0"
}

harden_clamav_config() {
    log "Phase: ClamAV hardening (/etc/clamav — OnAccess off, localhost TCP only)"
    mkdir -p /etc/clamav/clamd.conf.d "$CLAMAV_LOG"
    cat >/etc/clamav/clamd.conf.d/ctg-hardening.conf <<'CLAMEOF'
# CTG lab — performance + localhost-only daemon
LocalSocket /var/run/clamav/clamd.ctl
FixStaleSocket yes
LocalSocketMode 660
User clamav
TCPSocket 3310
TCPAddr 127.0.0.1
MaxThreads 4
MaxConnectionQueueLength 10
MaxQueue 50
IdleTimeout 30
OnAccessMaxFileSize 5M
# OnAccess disabled for VM performance — use scheduled clamscan instead
# OnAccessPrevention no
CLAMEOF

    if [[ -f /etc/clamav/freshclam.conf ]]; then
        sed -i 's/^Example/#Example/' /etc/clamav/freshclam.conf 2>/dev/null || true
        grep -q '^Checks ' /etc/clamav/freshclam.conf 2>/dev/null || \
            echo 'Checks 4' >>/etc/clamav/freshclam.conf
        grep -q '^NotifyClamAD ' /etc/clamav/freshclam.conf 2>/dev/null || \
            echo 'NotifyClamAD yes' >>/etc/clamav/freshclam.conf
    fi
}

ensure_clamav() {
    log "Phase: ClamAV (freshclam + daemon + daily /home scan timer)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -qq clamav clamav-daemon clamav-freshclam 2>/dev/null || \
        apt-get install -y -qq clamav clamav-daemon || true
    harden_clamav_config
    systemctl stop clamav-freshclam 2>/dev/null || true
    freshclam 2>/dev/null || log "freshclam deferred — retry after mirror sync"
    systemctl enable --now clamav-freshclam clamav-daemon 2>/dev/null || true

    cat >/etc/systemd/system/ctg-clamav-scan.service <<CLAMEOF
[Unit]
Description=CTG daily ClamAV scan of /home (lightweight)
After=clamav-freshclam.service

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=/usr/bin/clamscan -r --infected --remove=no --log=${CLAMAV_LOG}/scan.log /home
CLAMEOF

    cat >/etc/systemd/system/ctg-clamav-scan.timer <<'CLAMEOF'
[Unit]
Description=CTG daily ClamAV /home scan (03:30 local)

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=45m

[Install]
WantedBy=timers.target
CLAMEOF

    ln -sf /etc/systemd/system/ctg-clamav-scan.service \
        /etc/systemd/system/ctg-clamav-home-scan.service 2>/dev/null || true
    ln -sf /etc/systemd/system/ctg-clamav-scan.timer \
        /etc/systemd/system/ctg-clamav-home-scan.timer 2>/dev/null || true

    systemctl daemon-reload
    systemctl enable --now ctg-clamav-scan.timer 2>/dev/null || true
    log "ClamAV hardened + ctg-clamav-scan.timer enabled (daily 03:30)"
}

install_ids_packages() {
    log "Phase: install Suricata-primary IDS packages"
    export DEBIAN_FRONTEND=noninteractive
    if ! $DO_SKIP_SURICATA; then
        apt-get install -y -qq suricata 2>/dev/null || log "Suricata install skipped (retry apt)"
        if $DO_OPTIMIZE; then
            apt-get install -y -qq suricata-update python3-yaml 2>/dev/null || \
                log "suricata-update optional — install manually for rule refresh"
        fi
    fi
    if ! $DO_SKIP_SNORT; then
        apt-get install -y -qq snort snort-rules-default 2>/dev/null || \
            apt-get install -y -qq snort || log "Snort coexist skipped (use --skip-snort on 8GB VM)"
    fi
}

run_suricata_update() {
    if ! command -v suricata-update >/dev/null 2>&1; then
        return 0
    fi
    log "Running suricata-update (Emerging Threats Open)"
    suricata-update --no-test --no-reload 2>/dev/null || log "suricata-update failed — retry when online"
    if [[ -f /var/lib/suricata/rules/suricata.rules ]]; then
        ln -sf /var/lib/suricata/rules/suricata.rules "$CTG_SURICATA_DIR/suricata.rules" 2>/dev/null || true
    fi
}

install_suricata_update_timer() {
    if ! command -v suricata-update >/dev/null 2>&1; then
        return 0
    fi
    cat >/etc/systemd/system/ctg-suricata-update.service <<'EOF'
[Unit]
Description=CTG Suricata rule update (suricata-update)
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/suricata-update --no-test
StandardOutput=journal
StandardError=journal
EOF

    cat >/etc/systemd/system/ctg-suricata-update.timer <<'EOF'
[Unit]
Description=CTG Suricata rules refresh (daily 04:00)

[Timer]
OnCalendar=*-*-* 04:00:00
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl enable --now ctg-suricata-update.timer 2>/dev/null || true
    log "ctg-suricata-update.timer enabled"
}

deploy_snort_config() {
    local iface="$1"
    if $DO_SKIP_SNORT; then
        log "Snort skipped (--skip-snort) — Suricata-primary"
        return 0
    fi
    log "Deploying Snort config under $CTG_SNORT_DIR (iface=$iface, community rules, detect-only)"
    mkdir -p "$CTG_SNORT_DIR" "$SNORT_LOG"
    local rule_path="/etc/snort/rules"
    [[ -d "$rule_path" ]] || rule_path="/usr/share/snort/rules"
    [[ -d "$rule_path" ]] || mkdir -p "$rule_path"

    cat >"$CTG_SNORT_DIR/snort.conf" <<SNORTEOF
# CTG Kali lab — passive Snort IDS (community rules, detect-only). Primary IDS: Suricata.
ipvar HOME_NET [10.0.0.0/8,172.16.0.0/12,192.168.0.0/16]
ipvar EXTERNAL_NET !\$HOME_NET
var RULE_PATH ${rule_path}
var SO_RULE_PATH /etc/snort/so_rules
var PREPROC_RULE_PATH /etc/snort/preproc_rules
var WHITE_LIST_PATH \$RULE_PATH
var BLACK_LIST_PATH \$RULE_PATH
var SQL_SERVERS \$HOME_NET
var DNS_SERVERS \$HOME_NET
var SMTP_SERVERS \$HOME_NET
var HTTP_SERVERS \$HOME_NET

config logdir: ${SNORT_LOG}
config alert_with_interface_name
config disable_decode_drops
config disable_tcpopt_experimentation_drops
config disable_tcpopt_obsolete_drops
config disable_ttcp_reassembly
config checksum_mode: all
SNORTEOF

    if $DO_OPTIMIZE; then
        cat >>"$CTG_SNORT_DIR/snort.conf" <<'SNOPTEOF'
# CTG --optimize: lightweight preprocessors only
preprocessor stream5_global: max_tcp 262144, track_tcp yes, track_udp yes, track_icmp no
preprocessor stream5_tcp: policy first, use_static_footprint_sizes
preprocessor stream5_udp: timeout 30
preprocessor sfportscan: proto { all } scan_type { all } sense_level low
SNOPTEOF
    fi

    cat >>"$CTG_SNORT_DIR/snort.conf" <<SNORTEOF
output alert_fast: ${SNORT_LOG}/alert
output unified2: filename ${SNORT_LOG}/snort.u2, limit 128

include \$RULE_PATH/local.rules
SNORTEOF

    if [[ -f "$rule_path/snort.rules" ]]; then
        echo "include \$RULE_PATH/snort.rules" >>"$CTG_SNORT_DIR/snort.conf"
    elif [[ -f /usr/share/snort/rules/snort.rules ]]; then
        echo "include /usr/share/snort/rules/snort.rules" >>"$CTG_SNORT_DIR/snort.conf"
    else
        log "Snort community rules not found — install snort-rules-default"
    fi

    if [[ ! -f "$rule_path/local.rules" ]]; then
        cat >"$rule_path/local.rules" <<'LOCALEOF'
# CTG lab local Snort rules — authorized lab signatures only
LOCALEOF
    fi

    cat >"$CTG_SNORT_DIR/ctg-lab-iface.env" <<EOF
CTG_IDS_IFACE=${iface}
SNORTEOF
    chmod 644 "$CTG_SNORT_DIR/snort.conf" "$CTG_SNORT_DIR/ctg-lab-iface.env"
}

deploy_suricata_config() {
    local iface="$1"
    if $DO_SKIP_SURICATA; then
        return 0
    fi
    log "Deploying Suricata config under $CTG_SURICATA_DIR (iface=$iface)"
    mkdir -p "$CTG_SURICATA_DIR" "$SNORT_LOG"

    local detect_profile="medium"
    local runmode="autofp"
    local threads=2
    local set_cpu="no"
    if $DO_OPTIMIZE; then
        detect_profile="low"
        runmode="workers"
        threads=2
        set_cpu="yes"
    fi

    cat >"$CTG_SURICATA_DIR/suricata.yaml" <<SUREOF
%YAML 1.1
---
run-as:
  user: suricata
  group: suricata
vars:
  address-groups:
    HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"
  port-groups:
    HTTP_PORTS: "80,8080,8000"
    SHELLCODE_PORTS: "!80"
default-log-dir: ${SNORT_LOG}/
outputs:
  - fast:
      enabled: yes
      filename: suricata-fast.log
  - eve-log:
      enabled: yes
      filetype: regular
      filename: suricata-eve.json
      types:
        - alert
        - dns
        - flow
af-packet:
  - interface: ${iface}
    threads: ${threads}
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
    tpacket-v3: yes
    ring-size: 2048
    block-size: 32768
    block-timeout: 10
detect-profile: ${detect_profile}
runmode: ${runmode}
set-cpu-affinity: ${set_cpu}
max-pending-packets: 1024
SUREOF

    if [[ -f /var/lib/suricata/rules/suricata.rules ]]; then
        echo "default-rule-path: /var/lib/suricata/rules" >>"$CTG_SURICATA_DIR/suricata.yaml"
        echo "rule-files:" >>"$CTG_SURICATA_DIR/suricata.yaml"
        echo "  - suricata.rules" >>"$CTG_SURICATA_DIR/suricata.yaml"
    fi
    chmod 644 "$CTG_SURICATA_DIR/suricata.yaml"
    id suricata >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin suricata 2>/dev/null || true
    chown -R suricata:suricata "$SNORT_LOG" "$CTG_SURICATA_DIR" 2>/dev/null || true
}

stop_existing_ids() {
    pkill -f "snort.*${CTG_SNORT_DIR}" 2>/dev/null || true
    pkill -f "suricata.*${CTG_SURICATA_DIR}" 2>/dev/null || true
    systemctl stop ctg-snort-ids.service 2>/dev/null || true
    systemctl stop "$SURICATA_SVC" 2>/dev/null || true
    systemctl stop suricata 2>/dev/null || true
}

start_snort_ids() {
    local iface="$1"
    if $DO_SKIP_SNORT; then
        return 0
    fi
    if ! command -v snort >/dev/null 2>&1; then
        log "Snort binary missing — skip"
        return 0
    fi
    log "Starting Snort passive IDS on $iface (community rules, detect-only)"
    snort -D -i "$iface" -c "$CTG_SNORT_DIR/snort.conf" -l "$SNORT_LOG" -A alert 2>/dev/null || \
        snort -D -i "$iface" -c "$CTG_SNORT_DIR/snort.conf" -l "$SNORT_LOG" 2>>"$LOG_FILE" || \
        log "Snort start failed — check $LOG_FILE"
    if [[ -f "${SNORT_LOG}/alert" ]]; then
        ln -sf "${SNORT_LOG}/alert" /var/log/snort/alert 2>/dev/null || \
            mkdir -p /var/log/snort && ln -sf "${SNORT_LOG}/alert" /var/log/snort/alert 2>/dev/null || true
    fi
}

start_suricata_ids() {
    local iface="$1"
    if $DO_SKIP_SURICATA; then
        log "Suricata skipped (--skip-suricata)"
        return 0
    fi
    if ! command -v suricata >/dev/null 2>&1; then
        log "Suricata binary missing — skip"
        return 0
    fi
    sed -i "s/interface: .*/interface: ${iface}/" "$CTG_SURICATA_DIR/suricata.yaml" 2>/dev/null || true
    if $DO_ENABLE_IPS; then
        log "Suricata inline IPS (NFQUEUE $NFQUEUE_NUM) — lab VLAN ${LAB_VLAN} ONLY"
        modprobe nfnetlink_queue 2>/dev/null || true
        iptables -C FORWARD -s "$LAB_VLAN" -j NFQUEUE --queue-num "$NFQUEUE_NUM" 2>/dev/null || \
            iptables -I FORWARD -s "$LAB_VLAN" -j NFQUEUE --queue-num "$NFQUEUE_NUM" 2>/dev/null || \
            log "WARNING: iptables NFQUEUE failed — IPS not inline"
        suricata -D -c "$CTG_SURICATA_DIR/suricata.yaml" -q "$NFQUEUE_NUM" 2>>"$LOG_FILE" || \
            log "Suricata IPS start failed"
    else
        log "Starting Suricata detect-only on $iface (primary IDS)"
        if systemctl is-enabled "$SURICATA_SVC" >/dev/null 2>&1; then
            systemctl restart "$SURICATA_SVC" 2>/dev/null || \
                suricata -D -c "$CTG_SURICATA_DIR/suricata.yaml" -i "$iface" 2>>"$LOG_FILE" || \
                log "Suricata IDS start failed"
        else
            suricata -D -c "$CTG_SURICATA_DIR/suricata.yaml" -i "$iface" 2>>"$LOG_FILE" || \
                log "Suricata IDS start failed — see $LOG_FILE"
        fi
    fi
    ln -sf "${SNORT_LOG}/suricata-fast.log" /var/log/suricata/fast.log 2>/dev/null || \
        mkdir -p /var/log/suricata && ln -sf "${SNORT_LOG}/suricata-fast.log" /var/log/suricata/fast.log 2>/dev/null || true
    ln -sf "${SNORT_LOG}/suricata-eve.json" /var/log/suricata/eve.json 2>/dev/null || true
}

install_ctg_suricata_service() {
    if $DO_SKIP_SURICATA; then
        return 0
    fi
    local iface="$1"
    log "Installing ${SURICATA_SVC}"
    cat >"$SURICATA_UNIT" <<EOF
[Unit]
Description=CTG Suricata IDS (lab detect-only)
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
Environment=CTG_SURICATA_IFACE=${iface}
PIDFile=/var/run/suricata.pid
ExecStartPre=/bin/mkdir -p ${SNORT_LOG}
ExecStartPre=/bin/chown suricata:suricata ${SNORT_LOG}
ExecStart=/usr/bin/suricata -D -c ${CTG_SURICATA_DIR}/suricata.yaml -i ${iface}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SURICATA_SVC" 2>/dev/null || true
    log "Enabled ${SURICATA_SVC}"
}

forward_ids_to_syslog() {
    if command -v logger >/dev/null 2>&1; then
        logger -t ctg-ids "CTG IDS/IPS autorun complete — logs ${SNORT_LOG} iface=$(detect_lab_iface)"
    fi
}

integrate_siem_shield() {
    log "SIEM hook: $SIEM_HOOK · ctg-siem-autorun.sh for JSON export"
    if [[ -x "$SIEM_HOOK" ]]; then
        log "Run manually: sudo $SIEM_HOOK"
    elif [[ -f "$SCRIPT_DIR/tor-http-scrambler/siem-hook.sh" ]]; then
        log "Install scrambler for SIEM: bash $SCRIPT_DIR/tor-http-scrambler/install-scrambler.sh"
    fi
    local siem_script="$SCRIPT_DIR/ctg-siem-autorun.sh"
    for candidate in /mnt/ctg/ctg-siem-autorun.sh /opt/ctg/ctg-siem-autorun.sh; do
        [[ -f "$candidate" ]] && siem_script="$candidate" && break
    done
    if [[ -f "$siem_script" ]]; then
        bash "$siem_script" --skip-wazuh 2>/dev/null || log "ctg-siem-autorun deferred"
    fi
    if [[ -x "$SHIELD" ]]; then
        "$SHIELD" status 2>/dev/null || log "CTG Shield: $SHIELD"
    fi
}

install_systemd_unit() {
    log "Installing ${SERVICE_NAME}"
    local script_src="$SCRIPT_DIR/ctg-ids-ips-autorun.sh"
    for candidate in /mnt/ctg/ctg-ids-ips-autorun.sh /media/sf_ctg-backups/ctg-ids-ips-autorun.sh; do
        if [[ -f "$candidate" ]]; then
            script_src="$candidate"
            break
        fi
    done
    install -d -m 0755 /opt/ctg
    if [[ -f "$script_src" ]]; then
        install -m 0755 "$script_src" /opt/ctg/ctg-ids-ips-autorun.sh
    fi
    local ips_env="" opt_env=""
    $DO_ENABLE_IPS && ips_env="Environment=CTG_IPS_ENABLE=1"
    $DO_OPTIMIZE && opt_env="Environment=CTG_OPTIMIZE=1"
    cat >"$UNIT_DEST" <<UNITEOF
[Unit]
Description=CTG lab IDS/IPS + ClamAV autorun (Suricata-primary, detect-only default)
After=network-online.target clamav-daemon.service
Wants=network-online.target

[Service]
Type=oneshot
${ips_env}
${opt_env}
ExecStart=/opt/ctg/ctg-ids-ips-autorun.sh --skip-snort
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNITEOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    log "Enabled ${SERVICE_NAME}"
}

# --- main ---
if [[ "${CTG_IPS_ENABLE:-0}" == "1" ]]; then
    DO_ENABLE_IPS=true
fi

ensure_clamav
install_ids_packages

LAB_IFACE="$(detect_lab_iface)"
log "Lab capture/IDS interface: $LAB_IFACE (eth if cabled UP, else wlan)"

if $DO_OPTIMIZE; then
    run_suricata_update
    install_suricata_update_timer
fi

deploy_snort_config "$LAB_IFACE"
deploy_suricata_config "$LAB_IFACE"

if $DO_ENABLE_IPS; then
    log "WARNING: --EnableIPS — inline NFQUEUE on ${LAB_VLAN}. Lab VLAN only. OPNsense remains perimeter IPS."
else
    log "IDS mode: detect-only. Perimeter IPS: OPNsense Suricata. Lab inline: --EnableIPS on isolated VLAN."
fi

stop_existing_ids
start_snort_ids "$LAB_IFACE"
start_suricata_ids "$LAB_IFACE"
forward_ids_to_syslog
integrate_siem_shield

if $DO_INSTALL; then
    install_systemd_unit
    install_ctg_suricata_service "$LAB_IFACE"
fi

[[ -f /var/run/reboot-required ]] && ctg_reboot_helper --mark

log "=== CTG IDS/IPS autorun complete ==="
log "Suricata EVE: ${SNORT_LOG}/suricata-eve.json · Snort: ${SNORT_LOG}/alert"
log "ClamAV daily: systemctl list-timers ctg-clamav-scan.timer"
log "Wireshark: add user to wireshark group — see docs/KALI_SIEM_STACK.md"
log "Docs: docs/KALI_IDS_IPS_CLAMAV.md · docs/KALI_SIEM_STACK.md"
