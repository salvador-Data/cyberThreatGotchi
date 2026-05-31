#!/usr/bin/env bash
# CTG reboot helper — aggregate reboot signals after lab autorun (kernel, DKMS, GDM, apt).
# Authorized defensive lab use only — Hacker Planet LLC · Philadelphia, PA
#
# Usage:
#   ctg-reboot-if-needed.sh --mark              # flag reboot required (after guest additions, GDM, DKMS, etc.)
#   ctg-reboot-if-needed.sh --check             # exit 0 if reboot needed, 1 if not
#   ctg-reboot-if-needed.sh --reboot            # schedule reboot when needed
#   ctg-reboot-if-needed.sh --auto-reboot       # autorun: schedule +1 min when needed (TTY countdown)
#   ctg-reboot-if-needed.sh --auto-reboot --no-reboot   # skip schedule (SSH remote runs)
#
# Disable autorun reboot: CTG_NO_REBOOT=1
set -euo pipefail

LOG_FILE="/var/log/ctg-reboot.log"
MARKER_CTG="/var/run/ctg-reboot-required"
MARKER_DEB="/var/run/reboot-required"
MARKER_GDM="/var/run/ctg-gdm-config-changed"

DO_MARK=false
DO_MARK_GDM=false
DO_CHECK=false
DO_REBOOT=false
DO_AUTO_REBOOT=false
DO_NO_REBOOT=false

log() {
    local msg="[$(date -Iseconds)] [ctg-reboot] $*"
    printf '%s\n' "$msg"
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

usage() {
    cat <<EOF
CTG reboot helper — authorized defensive lab use only.

  --mark           Set /var/run/ctg-reboot-required
  --mark-gdm       GDM/Wayland config changed (also sets CTG marker)
  --check          Exit 0 if reboot needed, 1 otherwise
  --reboot         Schedule shutdown -r +1 when needed
  --auto-reboot    Same as --reboot with optional 10s TTY notice (lab autorun)
  --no-reboot      With --auto-reboot/--reboot: never schedule (SSH remote)

Disable autorun reboot: export CTG_NO_REBOOT=1
Log: ${LOG_FILE}
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mark) DO_MARK=true ;;
        --mark-gdm) DO_MARK_GDM=true ;;
        --check) DO_CHECK=true ;;
        --reboot) DO_REBOOT=true ;;
        --auto-reboot) DO_AUTO_REBOOT=true ;;
        --no-reboot) DO_NO_REBOOT=true ;;
        --help|-h) usage; exit 0 ;;
        *) log "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

if $DO_MARK; then
    touch "$MARKER_CTG"
    log "Marked reboot required: $MARKER_CTG"
fi

kernel_reboot_pending() {
    local running latest
    running="$(uname -r)"
    latest="$(ls -1 /lib/modules 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -n "$latest" && "$running" != "$latest" ]]; then
        log "Kernel pending: running=$running latest_modules=$latest"
        return 0
    fi
    return 1
}

dkms_reboot_pending() {
    if ! command -v dkms >/dev/null 2>&1; then
        return 1
    fi
    local running line kver
    running="$(uname -r)"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ,[[:space:]]*([^,]+),[[:space:]]*[^:]+:[[:space:]]*installed ]]; then
            kver="${BASH_REMATCH[1]}"
            kver="${kver//[[:space:]]/}"
            if [[ "$kver" != "$running" ]]; then
                log "DKMS installed for $kver but running $running"
                return 0
            fi
        fi
    done < <(dkms status 2>/dev/null || true)
    return 1
}

reboot_is_needed() {
    if [[ -f "$MARKER_CTG" ]]; then
        log "Reboot needed: $MARKER_CTG"
        return 0
    fi
    if [[ -f "$MARKER_DEB" ]]; then
        log "Reboot needed: $MARKER_DEB (apt)"
        return 0
    fi
    if [[ -f "$MARKER_GDM" ]]; then
        log "Reboot needed: $MARKER_GDM (GDM/Wayland)"
        return 0
    fi
    if kernel_reboot_pending; then
        return 0
    fi
    if dkms_reboot_pending; then
        return 0
    fi
    return 1
}

mark_gdm_config_changed() {
    touch "$MARKER_GDM"
    log "GDM/Wayland config change marker: $MARKER_GDM"
}

if $DO_MARK_GDM; then
    mark_gdm_config_changed
    touch "$MARKER_CTG"
fi

tty_countdown_notice() {
    local secs="${CTG_REBOOT_COUNTDOWN_SECS:-10}"
    local msg="CTG lab autorun: reboot in ${secs}s (guest additions / kernel / GDM / WiFi DKMS)"
    local tty
    for tty in /dev/tty1 /dev/tty2 /dev/tty3; do
        if [[ -w "$tty" ]]; then
            {
                printf '\n%s\n' "$msg"
                for ((i = secs; i >= 1; i--)); do
                    printf '\rRebooting in %2ds ... ' "$i"
                    sleep 1
                done
                printf '\rCTG reboot starting now.                    \n'
            } >"$tty" 2>/dev/null || true
        fi
    done
}

schedule_reboot() {
    local reason="${1:-CTG lab autorun complete}"
    if [[ "${CTG_NO_REBOOT:-}" == "1" ]] || $DO_NO_REBOOT; then
        log "Reboot skipped (CTG_NO_REBOOT or --no-reboot)"
        return 0
    fi
    if shutdown -r +1 "$reason" 2>/dev/null; then
        log "Scheduled: shutdown -r +1 \"$reason\""
    else
        log "shutdown -r +1 failed — try: sudo reboot"
        return 1
    fi
}

if $DO_CHECK; then
    if reboot_is_needed; then
        exit 0
    fi
    exit 1
fi

if $DO_REBOOT || $DO_AUTO_REBOOT; then
    if ! reboot_is_needed; then
        log "No reboot required"
        exit 0
    fi
    if $DO_AUTO_REBOOT; then
        tty_countdown_notice &
    fi
    schedule_reboot "CTG lab autorun complete"
    exit 0
fi

if ! $DO_MARK && ! $DO_MARK_GDM; then
    usage
    exit 1
fi
