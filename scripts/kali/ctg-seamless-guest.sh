#!/usr/bin/env bash
# CTG Kali guest — panel + VBoxClient + autoresize for VirtualBox seamless/scaled (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Fixes "no top toolbar / wrap / clipped" in seamless by:
#   - forcing the desktop panel (XFCE or GNOME) visible, autohide off, space reserved
#   - starting VBoxClient --seamless + --vmsvga (autoresize) so the guest matches the host
#   - nudging xrandr to the largest mode (no wrap/scroll when guest > window)
#
# Run as the graphical user (not root on :0):
#   bash /mnt/ctg/ctg-seamless-guest.sh
# Or once as root after a GUI login exists:
#   sudo bash /mnt/ctg/ctg-seamless-guest.sh
set -euo pipefail

log() { printf '[ctg-seamless-guest] %s\n' "$*"; }

DESKTOP_USER=""
DISPLAY_NUM=":0"

detect_desktop_user() {
    DESKTOP_USER="$(who 2>/dev/null | awk '/\(:[0-9]+\)/{print $1; exit}')"
    if [[ -z "$DESKTOP_USER" ]]; then
        DESKTOP_USER="${SUDO_USER:-${USER:-}}"
    fi
    local disp
    disp="$(who 2>/dev/null | grep -oE '\(:[0-9]+\)' | head -n1 | tr -d '()')"
    [[ -n "$disp" ]] && DISPLAY_NUM="$disp"
    if [[ -z "$DESKTOP_USER" || "$DESKTOP_USER" == root ]]; then
        log "No graphical (:N) desktop user found — log in to the Kali GUI first, then re-run"
        return 1
    fi
    log "Desktop user: $DESKTOP_USER on DISPLAY=$DISPLAY_NUM"
    return 0
}

as_user() {
    sudo -u "$DESKTOP_USER" -H env DISPLAY="$DISPLAY_NUM" \
        XAUTHORITY="/home/$DESKTOP_USER/.Xauthority" "$@"
}

fix_xfce_panel() {
    if ! as_user bash -lc 'command -v xfconf-query >/dev/null 2>&1'; then
        return 1
    fi
    log "XFCE detected — forcing panel-0 visible (autohide off, reserve space, top)"
    # autohide-behavior: 0 = never hide
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/autohide-behavior --create -t int -s 0 2>/dev/null || true
    # mode: 0 = horizontal
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/mode --create -t int -s 0 2>/dev/null || true
    # disable-struts false => panel reserves screen space (apps don't cover it)
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/disable-struts --create -t bool -s false 2>/dev/null || true
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/position --create -t string -s 'p=6;x=0;y=0' 2>/dev/null || true
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/position-locked --create -t bool -s true 2>/dev/null || true
    # restart the panel so changes apply now
    as_user bash -lc 'xfce4-panel -r >/dev/null 2>&1 || true'
    return 0
}

fix_gnome_panel() {
    if ! as_user bash -lc 'command -v gsettings >/dev/null 2>&1'; then
        return 1
    fi
    if as_user bash -lc 'pgrep -u "$USER" -x gnome-shell >/dev/null 2>&1'; then
        log "GNOME Shell detected — top bar is always-on (cannot autohide without extensions)"
        as_user gsettings set org.gnome.shell.extensions.dash-to-dock autohide false 2>/dev/null || true
        return 0
    fi
    return 1
}

fix_panel() {
    if fix_xfce_panel; then return 0; fi
    if fix_gnome_panel; then return 0; fi
    log "No XFCE/GNOME panel tool found — install xfce4-panel or use GNOME; skipping panel fix"
}

start_vboxclient() {
    if ! command -v VBoxClient >/dev/null 2>&1; then
        log "VBoxClient missing — run: sudo bash /mnt/ctg/kali-boot-autopatch.sh"
        return 1
    fi
    log "Starting VBoxClient services (seamless, autoresize/vmsvga, clipboard, dnd)"
    # --vmsvga drives dynamic resize on the VMSVGA controller (no wrap/clip)
    as_user bash -lc 'VBoxClient --vmsvga >/dev/null 2>&1 || VBoxClient --display >/dev/null 2>&1 || true'
    as_user bash -lc 'VBoxClient --seamless >/dev/null 2>&1 || true'
    as_user bash -lc 'VBoxClient --clipboard >/dev/null 2>&1 || true'
    as_user bash -lc 'VBoxClient --draganddrop >/dev/null 2>&1 || true'
}

fix_autoresize() {
    if ! as_user bash -lc 'command -v xrandr >/dev/null 2>&1'; then
        return 0
    fi
    log "xrandr: selecting largest available mode (prevents wrap/scroll when guest > window)"
    as_user bash -lc '
        out="$(xrandr 2>/dev/null | awk "/ connected/{print \$1; exit}")"
        [ -n "$out" ] && xrandr --output "$out" --auto >/dev/null 2>&1 || true
    ' || true
}

install_autostart() {
    # Persist VBoxClient seamless+autoresize for every GUI login (in addition to apt package autostart).
    local autostart_dir="/home/$DESKTOP_USER/.config/autostart"
    install -d -m 0755 -o "$DESKTOP_USER" -g "$DESKTOP_USER" "$autostart_dir" 2>/dev/null || true
    local f="$autostart_dir/ctg-vboxclient-seamless.desktop"
    cat >"$f" <<'DESK'
[Desktop Entry]
Type=Application
Name=CTG VBoxClient Seamless+Resize
Comment=Hacker Planet CTG lab — seamless + autoresize at login
Exec=sh -c 'VBoxClient --vmsvga || VBoxClient --display; VBoxClient --seamless; VBoxClient --clipboard'
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
    chown "$DESKTOP_USER:$DESKTOP_USER" "$f" 2>/dev/null || true
    chmod 644 "$f" 2>/dev/null || true
    log "Installed per-user autostart: $f"
}

log "=== CTG seamless/scaled guest fix ==="
if ! detect_desktop_user; then
    exit 1
fi
fix_panel
start_vboxclient
fix_autoresize
install_autostart
log ""
log "IMPORTANT — VirtualBox toolbar facts (Windows host):"
log "  * Seamless mode shows NO menu/toolbar/scrollbar by design; its only chrome is the"
log "    mini-toolbar, which VirtualBox 7 frequently fails to draw in seamless (known bug)."
log "  * For a visible toolbar + scrollbars, use NORMAL or SCALED window, not seamless:"
log "      Windows:  .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Scaled"
log "      In-VM toggle: Host+L (seamless), Host+C (scaled), Host+Home (menu), Host+F (fullscreen)"
log "Docs: docs/KALI_SEAMLESS_MODE.md"
