#!/usr/bin/env bash
# CTG SIEM autorun — Wazuh agent (optional) or local JSON log export for Windows CTG tail.
# Authorized defensive lab use only — Hacker Planet LLC · Philadelphia, PA
#
# Usage:
#   sudo bash ctg-siem-autorun.sh
#   sudo bash ctg-siem-autorun.sh --install
#   sudo bash ctg-siem-autorun.sh --wazuh-agent
#   sudo bash ctg-siem-autorun.sh --filebeat-local   # default: JSON aggregator (no Elastic stack)
#   sudo bash ctg-siem-autorun.sh --skip-wazuh
set -euo pipefail

LOG_FILE="/var/log/ctg-siem/autorun.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBOOT_HELPER="${SCRIPT_DIR}/ctg-reboot-if-needed.sh"
SERVICE_NAME="ctg-siem-export.service"
TIMER_NAME="ctg-siem-export.timer"
UNIT_DEST="/etc/systemd/system/${SERVICE_NAME}"
TIMER_DEST="/etc/systemd/system/${TIMER_NAME}"
CTG_ROOT="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
SIEM_HOOK="${CTG_SIEM_HOOK:-$CTG_ROOT/siem-hook.sh}"
IDS_LOG="/var/log/ctg-snort"
CLAMAV_LOG="/var/log/ctg-clamav"

# Windows host tail path (VBox shared folder or manual rsync target)
SIEM_EXPORT="${CTG_SIEM_EXPORT:-/mnt/ctg-backups/logs/siem}"
WAZUH_MANAGER="${CTG_WAZUH_MANAGER:-${WAZUH_MANAGER:-}}"

DO_INSTALL=false
DO_WAZUH=false
DO_FILEBEAT_LOCAL=true
DO_SKIP_WAZUH=false

log() {
    local msg="[$(date -Iseconds)] [ctg-siem] $*"
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
CTG SIEM autorun — authorized defensive lab use only.

  sudo bash $0                     Export IDS/ClamAV JSON to ${SIEM_EXPORT} (lightweight)
  sudo bash $0 --install           Install ${TIMER_NAME} (every 5 min export)
  sudo bash $0 --wazuh-agent       Install Wazuh agent when CTG_WAZUH_MANAGER is set
  sudo bash $0 --filebeat-local    Same as default — local JSON aggregator (no Elastic VM)
  sudo bash $0 --skip-wazuh        Export only; never attempt Wazuh install

Windows tail: Backups\\logs\\siem\\*.json (via shared folder ${SIEM_EXPORT})
Docs: docs/KALI_SIEM_STACK.md · SIEM hook: ${SIEM_HOOK}
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) DO_INSTALL=true ;;
        --wazuh-agent) DO_WAZUH=true ;;
        --filebeat-local) DO_FILEBEAT_LOCAL=true ;;
        --skip-wazuh) DO_SKIP_WAZUH=true ;;
        --help|-h) usage; exit 0 ;;
        *) log "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")" "$SIEM_EXPORT" /var/log/ctg-siem
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "=== CTG SIEM autorun start (wazuh=$DO_WAZUH export=$DO_FILEBEAT_LOCAL) ==="

install_wazuh_agent() {
    if $DO_SKIP_WAZUH; then
        log "Wazuh skipped (--skip-wazuh)"
        return 0
    fi
    if [[ -z "$WAZUH_MANAGER" ]]; then
        log "CTG_WAZUH_MANAGER unset — skip Wazuh agent (use --filebeat-local or set manager IP)"
        return 0
    fi
    if systemctl is-active --quiet wazuh-agent 2>/dev/null; then
        log "Wazuh agent already active — manager $WAZUH_MANAGER"
        return 0
    fi
    log "Phase: Wazuh agent install (manager=$WAZUH_MANAGER)"
    export DEBIAN_FRONTEND=noninteractive
    if ! command -v curl >/dev/null 2>&1; then
        apt-get install -y -qq curl ca-certificates
    fi
    local major="4"
    curl -s "https://packages.wazuh.com/${major}.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${major}.9.2-1_amd64.deb" \
        -o /tmp/wazuh-agent.deb 2>/dev/null || {
        log "Wazuh agent .deb download failed — install manually; see docs/KALI_SIEM_STACK.md"
        return 0
    }
    WAZUH_MANAGER="$WAZUH_MANAGER" dpkg -i /tmp/wazuh-agent.deb 2>/dev/null || apt-get install -f -y -qq
    if [[ -f /var/ossec/etc/ossec.conf ]]; then
        sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|" /var/ossec/etc/ossec.conf 2>/dev/null || true
    fi
    systemctl daemon-reload
    systemctl enable --now wazuh-agent 2>/dev/null || log "Wazuh agent enable failed — check manager reachability :1514"
    log "Wazuh agent configured for $WAZUH_MANAGER"
}

export_local_siem_json() {
    local ts outfile combined
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$SIEM_EXPORT"
    outfile="${SIEM_EXPORT}/ctg-siem-${ts}.json"
    combined="${SIEM_EXPORT}/ctg-siem-latest.json"

    python3 - "$outfile" "$combined" "$IDS_LOG" "$CLAMAV_LOG" <<'PYEOF'
import json, sys, os
from datetime import datetime, timezone

outfile, combined, ids_log, clam_log = sys.argv[1:5]
payload = {
    "source": "ctg-kali-siem-export",
    "exported_at": datetime.now(timezone.utc).isoformat(),
    "suricata_eve_tail": [],
    "suricata_fast_tail": [],
    "snort_alert_tail": [],
    "clamav_scan_tail": [],
}

def tail_lines(path, n=50):
    if not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        return [ln.rstrip("\n") for ln in lines[-n:]]
    except OSError:
        return []

for name, fname in [
    ("suricata_eve_tail", "suricata-eve.json"),
    ("suricata_fast_tail", "suricata-fast.log"),
    ("snort_alert_tail", "alert"),
]:
    payload[name] = tail_lines(os.path.join(ids_log, fname))

payload["clamav_scan_tail"] = tail_lines(os.path.join(clam_log, "scan.log"), 30)
text = json.dumps(payload, indent=2)
with open(outfile, "w", encoding="utf-8") as f:
    f.write(text)
with open(combined, "w", encoding="utf-8") as f:
    f.write(text)
print(outfile)
PYEOF
    log "Exported SIEM JSON: $outfile"
    find "$SIEM_EXPORT" -maxdepth 1 -name 'ctg-siem-2*.json' -mtime +7 -delete 2>/dev/null || true
}

integrate_siem_hook() {
    if [[ -x "$SIEM_HOOK" ]]; then
        log "SIEM hook available: sudo $SIEM_HOOK"
    elif [[ -f "$SCRIPT_DIR/tor-http-scrambler/siem-hook.sh" ]]; then
        log "Stage scrambler for SIEM hook: bash $SCRIPT_DIR/tor-http-scrambler/install-scrambler.sh"
    fi
}

install_systemd_units() {
    log "Installing ${SERVICE_NAME} + ${TIMER_NAME}"
    install -d -m 0755 /opt/ctg
    local script_src="$SCRIPT_DIR/ctg-siem-autorun.sh"
    for candidate in /mnt/ctg/ctg-siem-autorun.sh /media/sf_ctg-backups/ctg-siem-autorun.sh; do
        [[ -f "$candidate" ]] && script_src="$candidate" && break
    done
    [[ -f "$script_src" ]] && install -m 0755 "$script_src" /opt/ctg/ctg-siem-autorun.sh

    cat >"$UNIT_DEST" <<UNITEOF
[Unit]
Description=CTG SIEM JSON export (Suricata/Snort/ClamAV tail)
After=network-online.target

[Service]
Type=oneshot
Environment=CTG_SIEM_EXPORT=${SIEM_EXPORT}
ExecStart=/opt/ctg/ctg-siem-autorun.sh --skip-wazuh
StandardOutput=journal
StandardError=journal
UNITEOF

    cat >"$TIMER_DEST" <<'TIMEREOF'
[Unit]
Description=CTG SIEM JSON export timer (every 5 min)

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
TIMEREOF

    systemctl daemon-reload
    systemctl enable --now "$TIMER_NAME"
    log "Enabled ${TIMER_NAME}"
}

if $DO_WAZUH || [[ -n "$WAZUH_MANAGER" && ! $DO_SKIP_WAZUH ]]; then
    install_wazuh_agent
fi

if $DO_FILEBEAT_LOCAL; then
    export_local_siem_json
fi

integrate_siem_hook

if $DO_INSTALL; then
    install_systemd_units
fi

[[ -f /var/run/reboot-required ]] && ctg_reboot_helper --mark

log "=== CTG SIEM autorun complete ==="
log "Windows tail: Backups\\logs\\siem\\ctg-siem-latest.json (map ${SIEM_EXPORT})"
log "Docs: docs/KALI_SIEM_STACK.md"
