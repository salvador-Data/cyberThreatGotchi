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
# Diagnose without changes:
#   bash /mnt/ctg/ctg-seamless-guest.sh --diagnose-only
set -uo pipefail

DIAGNOSE_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --diagnose-only|--diagnose) DIAGNOSE_ONLY=true ;;
        -h|--help)
            echo "Usage: bash $(basename "$0") [--diagnose-only]"
            echo "  --diagnose-only  Print checks; do not change panel/VBoxClient/autostart"
            exit 0
            ;;
    esac
done

log() { printf '[ctg-seamless-guest] %s\n' "$*"; }
warn() { printf '[ctg-seamless-guest] WARNING: %s\n' "$*"; }
err() { printf '[ctg-seamless-guest] ERROR: %s\n' "$*"; }

DESKTOP_USER=""
DISPLAY_NUM=":0"
VBOX_CLIENT=""
SESSION_TYPE="unknown"
WAYLAND_BLOCK=false
ISSUES=0

note_issue() { ISSUES=$((ISSUES + 1)); }

run_optional() {
    local desc="$1"
    shift
    if "$@"; then
        return 0
    fi
    warn "$desc (skipped — non-fatal)"
    note_issue
    return 0
}

check_crlf() {
    if grep -q $'\r' "$0" 2>/dev/null; then
        err "This script has Windows CRLF line endings — bash will fail with \$'\\r' errors."
        err "Fix on Windows host: .\\scripts\\windows\\Stage-KaliLabToBackups.ps1 then re-run in VM."
        note_issue
        return 1
    fi
    return 0
}

detect_desktop_user() {
    DESKTOP_USER="$(who 2>/dev/null | awk '/\(:[0-9]+\)/{print $1; exit}')"
    if [[ -z "$DESKTOP_USER" ]]; then
        DESKTOP_USER="${SUDO_USER:-${USER:-}}"
    fi
    local disp
    disp="$(who 2>/dev/null | grep -oE '\(:[0-9]+\)' | head -n1 | tr -d '()')"
    [[ -n "$disp" ]] && DISPLAY_NUM="$disp"
    if [[ -z "$DESKTOP_USER" || "$DESKTOP_USER" == root ]]; then
        err "No graphical (:N) desktop user found."
        err "Log in to the Kali Xfce/GNOME GUI first (not just a TTY or SSH), then re-run:"
        err "  bash /mnt/ctg/ctg-seamless-guest.sh"
        err "If the VM is headless from Windows, open the VM window and sign in at the login screen."
        return 1
    fi
    log "Desktop user: $DESKTOP_USER on DISPLAY=$DISPLAY_NUM"
    return 0
}

has_x_display() {
    as_user bash -lc 'xdpyinfo >/dev/null 2>&1' 2>/dev/null
}

as_user() {
    sudo -u "$DESKTOP_USER" -H env DISPLAY="$DISPLAY_NUM" \
        XAUTHORITY="/home/$DESKTOP_USER/.Xauthority" "$@"
}

find_vboxclient() {
    VBOX_CLIENT=""
    if command -v VBoxClient >/dev/null 2>&1; then
        VBOX_CLIENT="$(command -v VBoxClient)"
        return 0
    fi
    local candidate
    for candidate in /usr/bin/VBoxClient /opt/VBoxGuestAdditions/bin/VBoxClient; do
        if [[ -x "$candidate" ]]; then
            VBOX_CLIENT="$candidate"
            export PATH="$(dirname "$candidate"):$PATH"
            return 0
        fi
    done
    return 1
}

detect_session_type() {
    SESSION_TYPE="$(as_user bash -lc 'echo -n "${XDG_SESSION_TYPE:-}"' 2>/dev/null || true)"
    if [[ -z "$SESSION_TYPE" || "$SESSION_TYPE" == "unknown" ]]; then
        local sid
        sid="$(loginctl 2>/dev/null | awk -v u="$DESKTOP_USER" '$0 ~ u {print $1; exit}')"
        if [[ -n "$sid" ]]; then
            SESSION_TYPE="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || echo unknown)"
        fi
    fi
    log "Graphical session type: ${SESSION_TYPE:-unknown}"
    if [[ "$SESSION_TYPE" == "wayland" ]]; then
        warn "Wayland session detected — VirtualBox seamless WILL glitch and revert."
        warn "Need X11/Xorg session. Forcing X11 config and requesting re-login."
        WAYLAND_BLOCK=true
        run_optional "GDM Wayland disable" force_x11_display_manager
        run_optional "Xfce X11 session default" ensure_xfce_x11_session
        return 1
    fi
    run_optional "Xfce X11 session default" ensure_xfce_x11_session
    return 0
}

ensure_xfce_x11_session() {
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
        if [[ $EUID -ne 0 ]]; then
            warn "Not root — cannot update AccountsService XSession (optional; .dmrc is set)"
            return 0
        fi
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
    return 0
}

force_x11_display_manager() {
    if [[ $EUID -ne 0 ]]; then
        warn "Not root — cannot edit GDM/SDDM config. Re-run: sudo bash $0"
        return 1
    fi
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
    else
        log "GDM3 not present — skipping /etc/gdm3/custom.conf"
    fi
    if command -v sddm >/dev/null 2>&1; then
        log "SDDM present — choose an 'X11'/'Xorg' session at login (not Wayland)"
    fi
    log "After re-login on X11, re-run: bash /mnt/ctg/ctg-seamless-guest.sh"
    return 0
}

fix_xfce_panel() {
    if ! as_user bash -lc 'command -v xfconf-query >/dev/null 2>&1'; then
        return 1
    fi
    if ! has_x_display; then
        warn "No active X display on $DISPLAY_NUM — log into the Xfce desktop first, then re-run."
        return 1
    fi
    log "XFCE detected — forcing panel-0 visible (autohide off, reserve space, top)"
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/autohide-behavior --create -t int -s 0 2>/dev/null || true
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/mode --create -t int -s 0 2>/dev/null || true
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/disable-struts --create -t bool -s false 2>/dev/null || true
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/position --create -t string -s 'p=6;x=0;y=0' 2>/dev/null || true
    as_user xfconf-query -c xfce4-panel -p /panels/panel-0/position-locked --create -t bool -s true 2>/dev/null || true
    as_user bash -lc 'xfce4-panel -r >/dev/null 2>&1 || true'
    return 0
}

fix_gnome_panel() {
    if ! as_user bash -lc 'command -v gsettings >/dev/null 2>&1'; then
        return 1
    fi
    if ! has_x_display; then
        warn "No active X display on $DISPLAY_NUM — log into the GNOME desktop first, then re-run."
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
    log "No XFCE/GNOME panel tool found or X not running — install xfce4-panel or log into desktop first"
    return 1
}

restart_vboxclient() {
    if ! find_vboxclient; then
        err "VBoxClient not found in PATH or /usr/bin — guest additions may be missing."
        err "Install: sudo bash /mnt/ctg/kali-boot-autopatch.sh"
        return 1
    fi
    log "VBoxClient: $VBOX_CLIENT"
    local svc
    for svc in vboxadd-service vboxadd vboxservice; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
            systemctl start "${svc}.service" 2>/dev/null || true
        fi
    done
    if ! has_x_display; then
        warn "No active X display — VBoxClient needs a logged-in X11 session."
        warn "Log into the Kali desktop, then re-run this script."
        return 1
    fi
    log "Restarting VBoxClient cleanly (kill stale seamless, relaunch)"
    as_user bash -lc 'pkill -u "$USER" -f "VBoxClient --seamless" >/dev/null 2>&1 || true'
    sleep 1
    as_user bash -lc "$VBOX_CLIENT --vmsvga >/dev/null 2>&1 || $VBOX_CLIENT --display >/dev/null 2>&1 || true"
    as_user bash -lc "$VBOX_CLIENT --seamless >/dev/null 2>&1 || true"
    as_user bash -lc "$VBOX_CLIENT --clipboard >/dev/null 2>&1 || true"
    as_user bash -lc "$VBOX_CLIENT --draganddrop >/dev/null 2>&1 || true"
    return 0
}

verify_seamless() {
    sleep 1
    if as_user bash -lc 'pgrep -u "$USER" -f "VBoxClient --seamless" >/dev/null 2>&1'; then
        log "OK: VBoxClient --seamless is running (host Host+L will stay in seamless)"
        return 0
    fi
    warn "VBoxClient --seamless is NOT running — seamless will revert."
    warn "Check: ps aux | grep VBoxClient ; journalctl -b | grep -i vboxclient"
    warn "Likely causes: Wayland session, no GUI login, or guest additions not fully installed."
    note_issue
    return 1
}

fix_autoresize() {
    if ! has_x_display; then
        return 0
    fi
    if ! as_user bash -lc 'command -v xrandr >/dev/null 2>&1'; then
        return 0
    fi
    log "xrandr: fit-to-window (--auto only — never largest mode; avoids cut-off)"
    as_user bash -lc '
        out="$(xrandr 2>/dev/null | awk "/ connected/{print \$1; exit}")"
        [ -n "$out" ] && xrandr --output "$out" --auto >/dev/null 2>&1 || true
    ' || true
    return 0
}

install_autostart() {
    if [[ $EUID -ne 0 ]] && [[ "$(id -un)" != "$DESKTOP_USER" ]]; then
        warn "Not root and not desktop user — skipping autostart install (run with sudo after GUI login)"
        return 1
    fi
    local autostart_dir="/home/$DESKTOP_USER/.config/autostart"
    install -d -m 0755 -o "$DESKTOP_USER" -g "$DESKTOP_USER" "$autostart_dir" 2>/dev/null || true
    local f="$autostart_dir/vboxclient-seamless.desktop"
    cat >"$f" <<'DESK'
[Desktop Entry]
Type=Application
Name=CTG VBoxClient Seamless+Resize
Comment=Hacker Planet CTG lab — seamless + autoresize at login
Exec=sh -c 'sleep 5; VBoxClient --vmsvga 2>/dev/null || VBoxClient --display 2>/dev/null; VBoxClient --seamless; VBoxClient --clipboard'
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
    chown "$DESKTOP_USER:$DESKTOP_USER" "$f" 2>/dev/null || true
    chmod 644 "$f" 2>/dev/null || true
    log "Installed per-user autostart: $f"
    if [[ $EUID -eq 0 ]]; then
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
    fi
    return 0
}

diagnose_only() {
    log "=== CTG seamless diagnose (read-only) ==="
    check_crlf || true
    if ! detect_desktop_user; then
        log "who output: $(who 2>/dev/null || echo '(empty)')"
        log "loginctl sessions: $(loginctl 2>/dev/null | head -n5 || echo '(unavailable)')"
        exit 1
    fi
    if has_x_display; then
        log "X display: OK ($DISPLAY_NUM, xdpyinfo succeeds)"
    else
        warn "X display: NOT reachable on $DISPLAY_NUM — log into Xfce/GNOME desktop first"
        note_issue
    fi
    detect_session_type || true
    if find_vboxclient; then
        log "VBoxClient: $VBOX_CLIENT ($( $VBOX_CLIENT --version 2>/dev/null || echo 'version unknown'))"
    else
        err "VBoxClient: NOT FOUND — run sudo bash /mnt/ctg/kali-boot-autopatch.sh"
        note_issue
    fi
    if as_user bash -lc 'command -v xfconf-query >/dev/null 2>&1'; then
        log "xfconf-query: present"
    else
        log "xfconf-query: not available (not XFCE or package missing)"
    fi
    local gdm=/etc/gdm3/custom.conf
    if [[ -f "$gdm" ]]; then
        if grep -q 'WaylandEnable=false' "$gdm" 2>/dev/null; then
            log "GDM: WaylandEnable=false (good for seamless)"
        else
            warn "GDM: WaylandEnable not false in $gdm — seamless may revert on Wayland"
            note_issue
        fi
    else
        log "GDM custom.conf: not present (may use SDDM/lightdm)"
    fi
    verify_seamless || true
    log ""
    if $WAYLAND_BLOCK; then
        warn "ACTION: log out and back in on X11/Xorg, then re-run without --diagnose-only"
    fi
    if [[ $ISSUES -gt 0 ]]; then
        err "Diagnose found $ISSUES issue(s) — fix above, then: bash /mnt/ctg/ctg-seamless-guest.sh"
        exit 1
    fi
    log "Diagnose: all checks passed — run without --diagnose-only to apply fixes"
    exit 0
}

log "=== CTG seamless/scaled guest fix ==="
check_crlf || true

if $DIAGNOSE_ONLY; then
    diagnose_only
fi

if ! detect_desktop_user; then
    exit 1
fi

detect_session_type || true
run_optional "desktop panel fix" fix_panel
run_optional "VBoxClient restart" restart_vboxclient
run_optional "xrandr autoresize" fix_autoresize
run_optional "autostart install" install_autostart
verify_seamless || true

# HiDPI / terminal font scale (see docs/KALI_DISPLAY_SCALING.md)
run_display_scale() {
    local scale_script=""
    for candidate in /mnt/ctg/ctg-display-scale.sh /opt/ctg/ctg-display-scale.sh \
        "$(dirname "$0")/ctg-display-scale.sh"; do
        if [[ -f "$candidate" ]]; then
            scale_script="$candidate"
            break
        fi
    done
    if [[ -z "$scale_script" ]]; then
        warn "ctg-display-scale.sh not found — skip DPI/terminal scale"
        return 1
    fi
    log "Running display scale (fit-window, after VBoxClient): $scale_script --fit-window"
    bash "$scale_script" --fit-window
}
run_optional "display scale (DPI/terminal)" run_display_scale

log ""
if $WAYLAND_BLOCK; then
    log "ACTION REQUIRED: log out of the Wayland session and log back in on X11/Xorg,"
    log "then re-run this script. Seamless cannot work on Wayland."
fi
log "IMPORTANT — VirtualBox toolbar facts (Windows host):"
log "  * Seamless mode shows NO menu/toolbar/scrollbar by design; its only chrome is the"
log "    mini-toolbar, which VirtualBox 7 frequently fails to draw in seamless (known bug)."
log "  * For a visible toolbar + scrollbars, use NORMAL or SCALED window, not seamless:"
log "      Windows:  .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (text-small; not Scaled)"
log "      In-VM toggle: Host+L (seamless), Host+C (scaled), Host+Home (menu), Host+F (fullscreen)"
log "Docs: docs/KALI_SEAMLESS_MODE.md"

spawn_ctg_trigger_watch() {
    local root w
    for root in /mnt/ctg /media/sf_ctg-backups /media/sf_ctg; do
        w="$root/ctg-watch-trigger.sh"
        if [[ -f "$w" ]] && ! pgrep -f "ctg-watch-trigger.sh" >/dev/null 2>&1; then
            log "Starting share trigger watch (CTG_TRIGGER_AUTORUN from Windows host)"
            CTG_TRIGGER_MAX_LOOPS=0 nohup bash "$w" >>/var/log/ctg-watch-trigger.log 2>&1 &
            return 0
        fi
    done
    return 1
}
spawn_ctg_trigger_watch || true

if [[ $ISSUES -gt 0 ]]; then
    warn "Completed with $ISSUES non-fatal issue(s) — see messages above"
    exit 1
fi
exit 0
