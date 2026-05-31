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

# Seamless requires an X11/Xorg session. A Wayland session makes VirtualBox
# enable seamless then immediately revert ("glitch and revert"), because the
# guest cannot report seamless window regions over Wayland.
SESSION_TYPE="unknown"

detect_session_type() {
    SESSION_TYPE="$(as_user bash -lc 'echo -n "${XDG_SESSION_TYPE:-}"' 2>/dev/null || true)"
    if [[ -z "$SESSION_TYPE" || "$SESSION_TYPE" == "unknown" ]]; then
        # Fallback: ask loginctl for the user's graphical session
        local sid
        sid="$(loginctl 2>/dev/null | awk -v u="$DESKTOP_USER" '$0 ~ u {print $1; exit}')"
        if [[ -n "$sid" ]]; then
            SESSION_TYPE="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || echo unknown)"
        fi
    fi
    log "Graphical session type: ${SESSION_TYPE:-unknown}"
    if [[ "$SESSION_TYPE" == "wayland" ]]; then
        log "WARNING: Wayland session detected — VirtualBox seamless WILL glitch and revert."
        log "Forcing X11 (WaylandEnable=false) and requesting a re-login."
        force_x11_display_manager
        ensure_xfce_x11_session
        return 1
    fi
    ensure_xfce_x11_session
    return 0
}

ensure_xfce_x11_session() {
    # Prefer Xfce on Xorg at login (not GNOME Wayland).
    local dmrc="/home/$DESKTOP_USER/.dmrc"
    if [[ ! -f "$dmrc" ]] || ! grep -q 'Session=xfce' "$dmrc" 2>/dev/null; then
        cat >"$dmrc" <<'DMRC'
[Desktop]
Session=xfce
DMRC
        chown "$DESKTOP_USER:$DESKTOP_USER" "$dmrc" 2>/dev/null || true
        chmod 644 "$dmrc" 2>/dev/null || true
        log "Set default session Xfce in $dmrc"
    fi
    local acc="/var/lib/AccountsService/users/$DESKTOP_USER"
    if [[ -d /var/lib/AccountsService/users ]]; then
        install -d -m 0755 /var/lib/AccountsService/users
        if [[ ! -f "$acc" ]] || ! grep -q 'XSession=xfce' "$acc" 2>/dev/null; then
            {
                echo '[User]'
                echo 'Session=xfce'
                echo 'XSession=xfce'
            } >"$acc"
            chmod 644 "$acc" 2>/dev/null || true
            log "AccountsService: XSession=xfce for $DESKTOP_USER"
        fi
    fi
}

force_x11_display_manager() {
    # GDM3
    local gdm=/etc/gdm3/custom.conf
    if [[ -d /etc/gdm3 ]] || command -v gdm3 >/dev/null 2>&1; then
        install -d -m 0755 /etc/gdm3
        if [[ -f "$gdm" ]]; then
            if grep -q '^[[:space:]]*#\?WaylandEnable=' "$gdm"; then
                sed -i 's/^[[:space:]]*#\?WaylandEnable=.*/WaylandEnable=false/' "$gdm"
            elif grep -q '^\[daemon\]' "$gdm"; then
                sed -i '/^\[daemon\]/a WaylandEnable=false' "$gdm"
            else
                printf '\n[daemon]\nWaylandEnable=false\n' >>"$gdm"
            fi
        else
            printf '[daemon]\nWaylandEnable=false\n' >"$gdm"
        fi
        chmod 644 "$gdm"
        log "GDM: WaylandEnable=false in $gdm (log out / reboot to apply)"
    fi
    # SDDM (KDE) — force X11 greeter session
    if command -v sddm >/dev/null 2>&1; then
        log "SDDM present — choose an 'X11'/'Xorg' session at login (not Wayland)"
    fi
    log "After re-login on X11, re-run: bash /mnt/ctg/ctg-seamless-guest.sh"
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

restart_vboxclient() {
    if ! command -v VBoxClient >/dev/null 2>&1; then
        log "VBoxClient missing — run: sudo bash /mnt/ctg/kali-boot-autopatch.sh"
        return 1
    fi
    # Ensure the kernel guest service is up first (seamless needs vboxadd/vboxguest).
    local svc
    for svc in vboxadd-service vboxadd vboxservice; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
            systemctl start "${svc}.service" 2>/dev/null || true
        fi
    done
    # Kill stale/crashed VBoxClient seamless so we relaunch cleanly (fixes glitch-revert).
    log "Restarting VBoxClient cleanly (kill stale seamless, relaunch)"
    as_user bash -lc 'pkill -u "$USER" -f "VBoxClient --seamless" >/dev/null 2>&1 || true'
    sleep 1
    # --vmsvga drives dynamic resize on the VMSVGA controller (no wrap/clip)
    as_user bash -lc 'VBoxClient --vmsvga >/dev/null 2>&1 || VBoxClient --display >/dev/null 2>&1 || true'
    as_user bash -lc 'VBoxClient --seamless >/dev/null 2>&1 || true'
    as_user bash -lc 'VBoxClient --clipboard >/dev/null 2>&1 || true'
    as_user bash -lc 'VBoxClient --draganddrop >/dev/null 2>&1 || true'
}

verify_seamless() {
    sleep 1
    if as_user bash -lc 'pgrep -u "$USER" -f "VBoxClient --seamless" >/dev/null 2>&1'; then
        log "OK: VBoxClient --seamless is running (host Host+L will stay in seamless)"
        return 0
    fi
    log "WARNING: VBoxClient --seamless is NOT running — seamless will revert."
    log "  Check: ps aux | grep VBoxClient ; journalctl -b | grep -i vboxclient"
    log "  Likely Wayland session (need X11) or guest additions not fully installed."
    return 1
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
    local autostart_dir="/home/$DESKTOP_USER/.config/autostart"
    install -d -m 0755 -o "$DESKTOP_USER" -g "$DESKTOP_USER" "$autostart_dir" 2>/dev/null || true
    local f="$autostart_dir/vboxclient-seamless.desktop"
    cat >"$f" <<'DESK'
[Desktop Entry]
Type=Application
Name=CTG VBoxClient Seamless+Resize
Comment=Hacker Planet CTG lab — seamless + autoresize at login
Exec=sh -c 'sleep 2; VBoxClient --vmsvga 2>/dev/null || VBoxClient --display 2>/dev/null; VBoxClient --seamless; VBoxClient --clipboard'
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
    chown "$DESKTOP_USER:$DESKTOP_USER" "$f" 2>/dev/null || true
    chmod 644 "$f" 2>/dev/null || true
    log "Installed per-user autostart: $f"
    install -d -m 0755 /etc/xdg/autostart
    local sys=/etc/xdg/autostart/vboxclient-seamless.desktop
    if [[ ! -f "$sys" ]]; then
        cat >"$sys" <<'SYS'
[Desktop Entry]
Type=Application
Name=VirtualBox Seamless Client
Comment=CTG lab — VBoxClient seamless at login
Exec=sh -c 'VBoxClient --vmsvga 2>/dev/null || VBoxClient --display 2>/dev/null; VBoxClient --seamless'
X-GNOME-Autostart-enabled=true
NoDisplay=true
SYS
        chmod 644 "$sys"
        log "Installed system autostart: $sys"
    fi
}

log "=== CTG seamless/scaled guest fix ==="
if ! detect_desktop_user; then
    exit 1
fi
WAYLAND_BLOCK=false
detect_session_type || WAYLAND_BLOCK=true
fix_panel
restart_vboxclient
fix_autoresize
install_autostart
verify_seamless || true
log ""
if $WAYLAND_BLOCK; then
    log "ACTION REQUIRED: log out of the Wayland session and log back in on X11/Xorg,"
    log "then re-run this script. Seamless cannot work on Wayland."
fi
log "IMPORTANT — VirtualBox toolbar facts (Windows host):"
log "  * Seamless mode shows NO menu/toolbar/scrollbar by design; its only chrome is the"
log "    mini-toolbar, which VirtualBox 7 frequently fails to draw in seamless (known bug)."
log "  * For a visible toolbar + scrollbars, use NORMAL or SCALED window, not seamless:"
log "      Windows:  .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Scaled"
log "      In-VM toggle: Host+L (seamless), Host+C (scaled), Host+Home (menu), Host+F (fullscreen)"
log "Docs: docs/KALI_SEAMLESS_MODE.md"
