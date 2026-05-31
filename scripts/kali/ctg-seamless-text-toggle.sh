#!/usr/bin/env bash
# CTG Kali guest — toggle text size when entering/exiting VirtualBox seamless (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Flow:
#   1. Session login autostart runs --restore-medium (DPI 108 / Sans 11 / Monospace 12)
#   2. Host+L into seamless → run --enter-seamless (smaller text for seamless viewport)
#   3. Host+L out of seamless → run --exit-seamless (restore medium preset)
#
#   bash /mnt/ctg/ctg-seamless-text-toggle.sh --enter-seamless
#   bash /mnt/ctg/ctg-seamless-text-toggle.sh --exit-seamless
set -uo pipefail

ACTION=""
for arg in "$@"; do
    case "$arg" in
        --enter-seamless) ACTION=enter ;;
        --exit-seamless) ACTION=exit ;;
        -h|--help)
            echo "Usage: bash $(basename "$0") --enter-seamless | --exit-seamless"
            echo "  --enter-seamless  Apply seamless smaller text (DPI 100, Sans 10, Monospace 11)"
            echo "  --exit-seamless   Restore medium post-login text (DPI 108, Sans 11, Monospace 12)"
            echo "Docs: docs/KALI_SEAMLESS_MODE.md · docs/KALI_DISPLAY_SCALING.md"
            exit 0
            ;;
        *)
            echo "[ctg-seamless-text-toggle] Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

log() { printf '[ctg-seamless-text-toggle] %s\n' "$*"; }
err() { printf '[ctg-seamless-text-toggle] ERROR: %s\n' "$*" >&2; }

if [[ -z "$ACTION" ]]; then
    err "Specify --enter-seamless or --exit-seamless"
    exit 2
fi

resolve_scale_script() {
    local candidate
    for candidate in \
        "$(dirname "$0")/ctg-display-scale.sh" \
        /mnt/ctg/ctg-display-scale.sh \
        /opt/ctg/ctg-display-scale.sh \
        /media/sf_ctg-backups/ctg-display-scale.sh; do
        if [[ -f "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

SCALE_SCRIPT="$(resolve_scale_script)" || {
    err "ctg-display-scale.sh not found — mount share: sudo bash /media/sf_ctg-backups/ctg-mount-share.sh"
    exit 1
}

case "$ACTION" in
    enter)
        log "Entering seamless text mode via $SCALE_SCRIPT --seamless-text-reduce"
        exec bash "$SCALE_SCRIPT" --seamless-text-reduce
        ;;
    exit)
        log "Restoring medium text via $SCALE_SCRIPT --restore-medium"
        exec bash "$SCALE_SCRIPT" --restore-medium
        ;;
esac
