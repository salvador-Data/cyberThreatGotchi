#!/usr/bin/env bash
# CTG Kali guest — panel + VBoxClient for VirtualBox seamless (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Run as the graphical user (not root on :0):
#   bash /mnt/ctg/ctg-seamless-guest.sh
# Or once as root after login exists:
#   sudo -u "$(who | awk '/\(:0\)/{print $1; exit}')" bash /mnt/ctg/ctg-seamless-guest.sh
set -euo pipefail

log() { printf '[ctg-seamless-guest] %s\n' "$*"; }

run_as_desktop_user() {
    local u
    u="$(who 2>/dev/null | awk '/\(:0\)/{print $1; exit}')"
    if [[ -z "$u" ]]; then
        u="${SUDO_USER:-${USER:-}}"
    fi
    if [[ -z "$u" || "$u" == root ]]; then
        log "No :0 desktop user — log in to Kali GUI first, then re-run"
        return 1
    fi
    export DISPLAY="${DISPLAY:-:0}"
    sudo -u "$u" -H env DISPLAY="$DISPLAY" XAUTHORITY="${XAUTHORITY:-/home/$u/.Xauthority}" "$@"
}

fix_xfce_panel() {
    if ! command -v xfconf-query >/dev/null 2>&1; then
        return 0
    fi
    log "XFCE: disable panel autohide (seamless top edge)"
    run_as_desktop_user xfconf-query -c xfce4-panel -p /panels/panel-0/autohide-behavior -n -t int -s 0 2>/dev/null || true
    run_as_desktop_user xfconf-query -c xfce4-panel -p /panels/panel-0/mode -n -t int -s 0 2>/dev/null || true
    run_as_desktop_user xfconf-query -c xfce4-panel -p /panels/panel-0/position -n -t string -s 'p=0;x=0;y=0' 2>/dev/null || true
}

start_vboxclient() {
    if ! command -v VBoxClient >/dev/null 2>&1; then
        log "VBoxClient missing — run: sudo bash /mnt/ctg/kali-boot-autopatch.sh"
        return 1
    fi
    log "Starting VBoxClient --seamless (user session)"
    run_as_desktop_user VBoxClient --seamless 2>/dev/null || true
    run_as_desktop_user VBoxClient --clipboard 2>/dev/null || true
    run_as_desktop_user VBoxClient --draganddrop 2>/dev/null || true
}

log "=== CTG seamless guest fix ==="
fix_xfce_panel
start_vboxclient
log "Windows host: Host+L toggle seamless, Host+Home (Right Ctrl+Home) VM menu, top-edge mini toolbar"
log "Docs: docs/KALI_SEAMLESS_MODE.md"
