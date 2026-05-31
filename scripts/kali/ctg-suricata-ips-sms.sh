#!/usr/bin/env bash
# CTG Kali — stage Suricata EVE JSON to ctg-backups for Windows alert bridge.
# Authorized defensive lab use only — Hacker Planet LLC · Philadelphia, PA
#
# Usage:
#   sudo bash ctg-suricata-ips-sms.sh
#   sudo bash ctg-suricata-ips-sms.sh --install   # systemd timer every 2 min
#   sudo bash ctg-suricata-ips-sms.sh --tail 200  # copy last N EVE lines
#
# Windows host polls: Backups/logs/kali-suricata/suricata-eve.json
# Alerts on Windows via signal-cli (preferred) or Twilio — never stage secrets on guest.
set -euo pipefail

LOG_FILE="/var/log/ctg-suricata-sms-bridge.log"
EVE_SRC="/var/log/ctg-snort/suricata-eve.json"
FAST_SRC="/var/log/ctg-snort/suricata-fast.log"
CTG_MOUNT="${CTG_MOUNT:-/mnt/ctg}"
STAGE_DIR="${CTG_KALI_SURICATA_STAGE:-${CTG_MOUNT}/logs/kali-suricata}"
TAIL_LINES="${CTG_SURICATA_STAGE_TAIL:-500}"
DO_INSTALL=false

log() {
    local msg="[$(date -Iseconds)] [ctg-suricata-sms] $*"
    printf '%s\n' "$msg"
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

usage() {
    cat <<EOF
CTG Suricata EVE staging for Windows alert bridge (authorized lab only).

  sudo bash $0                  Copy EVE tail to ctg-backups share
  sudo bash $0 --install        Install ctg-suricata-sms-bridge.timer (2 min)
  sudo bash $0 --tail N         Copy last N EVE lines (default ${TAIL_LINES})

Prereq: ctg-ids-ips-autorun.sh (Suricata-primary) + mounted ctg-backups share.
Windows: Start-CtgKaliSuricataSmsBridge.ps1
Docs: docs/FREE_IPS_SURICATA.md
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) DO_INSTALL=true ;;
        --tail)
            shift
            TAIL_LINES="${1:-500}"
            ;;
        --help|-h) usage; exit 0 ;;
        *) log "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

resolve_mount() {
    for d in /mnt/ctg /media/sf_ctg-backups; do
        if [[ -d "$d" && -w "$d" ]]; then
            CTG_MOUNT="$d"
            STAGE_DIR="${CTG_MOUNT}/logs/kali-suricata"
            return 0
        fi
    done
    return 1
}

stage_eve() {
    if [[ ! -f "$EVE_SRC" ]]; then
        log "EVE source missing: $EVE_SRC — run ctg-ids-ips-autorun.sh first"
        return 1
    fi
    if ! resolve_mount; then
        log "ctg-backups share not writable — mount: sudo bash ctg-mount-share.sh"
        return 1
    fi
    mkdir -p "$STAGE_DIR"
    tail -n "$TAIL_LINES" "$EVE_SRC" >"${STAGE_DIR}/suricata-eve.json.tmp"
    mv -f "${STAGE_DIR}/suricata-eve.json.tmp" "${STAGE_DIR}/suricata-eve.json"
    if [[ -f "$FAST_SRC" ]]; then
        tail -n 100 "$FAST_SRC" >"${STAGE_DIR}/suricata-fast.log.tmp" 2>/dev/null || true
        mv -f "${STAGE_DIR}/suricata-fast.log.tmp" "${STAGE_DIR}/suricata-fast.log" 2>/dev/null || true
    fi
    chmod 644 "${STAGE_DIR}/suricata-eve.json" 2>/dev/null || true
    log "Staged EVE tail (${TAIL_LINES} lines) -> ${STAGE_DIR}/suricata-eve.json"
}

install_timer() {
    local script_src="$0"
    for candidate in /opt/ctg/ctg-suricata-ips-sms.sh /mnt/ctg/ctg-suricata-ips-sms.sh /media/sf_ctg-backups/ctg-suricata-ips-sms.sh; do
        [[ -f "$candidate" ]] && script_src="$candidate" && break
    done
    install -d -m 0755 /opt/ctg
    [[ -f "$script_src" ]] && install -m 0755 "$script_src" /opt/ctg/ctg-suricata-ips-sms.sh

    cat >/etc/systemd/system/ctg-suricata-sms-bridge.service <<'EOF'
[Unit]
Description=CTG stage Suricata EVE to ctg-backups for Windows alert bridge
After=network-online.target ctg-suricata.service

[Service]
Type=oneshot
ExecStart=/opt/ctg/ctg-suricata-ips-sms.sh
StandardOutput=journal
StandardError=journal
EOF

    cat >/etc/systemd/system/ctg-suricata-sms-bridge.timer <<'EOF'
[Unit]
Description=CTG Suricata EVE staging timer (every 2 min)

[Timer]
OnBootSec=3min
OnUnitActiveSec=2min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now ctg-suricata-sms-bridge.timer 2>/dev/null || true
    log "Enabled ctg-suricata-sms-bridge.timer"
}

stage_eve || exit 1
$DO_INSTALL && install_timer
log "Complete — Windows: Start-CtgKaliSuricataSmsBridge.ps1 -RunMinutes 60"
