#!/usr/bin/env bash
# CTG Kali guest — HiDPI / font / terminal scale for VirtualBox (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Fixes tiny terminals, panels, and dialogs when:
#   - Guest resolution is inflated (e.g. 3428×1660 from LastGuestSizeHint + 150% Windows scaling)
#   - XFCE defaults to 96 DPI on a dense display
#   - VBoxClient display/vmsvga autoresize is not running
#
# Run after GUI login:
#   bash /mnt/ctg/ctg-display-scale.sh
#   sudo bash /mnt/ctg/ctg-display-scale.sh
# Diagnose only:
#   bash /mnt/ctg/ctg-display-scale.sh --diagnose-only
set -uo pipefail

DIAGNOSE_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --diagnose-only|--diagnose) DIAGNOSE_ONLY=true ;;
        -h|--help)
            echo "Usage: bash $(basename "$0") [--diagnose-only]"
            echo "  Scales XFCE/GNOME DPI, panel, terminal font; VBoxClient + xrandr autoresize."
            exit 0
            ;;
    esac
done

log() { printf '[ctg-display-scale] %s\n' "$*"; }
warn() { printf '[ctg-display-scale] WARNING: %s\n' "$*"; }
err() { printf '[ctg-display-scale] ERROR: %s\n' "$*"; }

DESKTOP_USER=""
DISPLAY_NUM=":0"
VBOX_CLIENT=""
TARGET_DPI=96
TERM_FONT="Monospace 11"
PANEL_SIZE=30
RES_W=0
RES_H=0
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
        err "No graphical (:N) desktop user found — log in to Xfce/GNOME first."
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
            return 0
        fi
    done
    return 1
}

get_current_resolution() {
    if ! has_x_display; then
        echo "0 0"
        return 1
    fi
    as_user bash -lc '
        xrandr 2>/dev/null | awk "/\\*/ {gsub(/[^0-9x]/,\"\",\$1); split(\$1,a,\"x\"); print a[1], a[2]; exit}"
    ' 2>/dev/null || echo "0 0"
}

compute_target_dpi() {
    local w="$1" h="$2"
    RES_W="$w"
    RES_H="$h"
    # Inflated seamless/scaled guest sizes (Windows 125–150% + bad LastGuestSizeHint)
    if [[ "$w" -ge 3200 ]] || [[ "$w" -ge 2800 && "$h" -ge 1500 ]]; then
        TARGET_DPI=144
        TERM_FONT="Monospace 14"
        PANEL_SIZE=48
    elif [[ "$w" -ge 2560 ]] || [[ "$h" -ge 1400 ]]; then
        TARGET_DPI=120
        TERM_FONT="Monospace 12"
        PANEL_SIZE=40
    else
        TARGET_DPI=96
        TERM_FONT="Monospace 11"
        PANEL_SIZE=30
    fi
    log "Resolution ${w}x${h} -> target DPI=$TARGET_DPI panel=$PANEL_SIZE font=$TERM_FONT"
}

fix_vbox_autoresize() {
    if ! find_vboxclient; then
        warn "VBoxClient not found — install virtualbox-guest-x11 (kali-boot-autopatch.sh)"
        return 1
    fi
    if ! has_x_display; then
        warn "No X display — log into desktop first"
        return 1
    fi
    log "Starting VBoxClient --vmsvga / --display (autoresize)"
    as_user bash -lc "$VBOX_CLIENT --vmsvga >/dev/null 2>&1 || $VBOX_CLIENT --display >/dev/null 2>&1 || true"
    return 0
}

fix_xrandr() {
    if ! has_x_display; then
        return 0
    fi
    if ! as_user bash -lc 'command -v xrandr >/dev/null 2>&1'; then
        return 0
    fi
    log "xrandr: --auto on primary output"
    as_user bash -lc '
        out="$(xrandr 2>/dev/null | awk "/ connected/{print \$1; exit}")"
        [ -z "$out" ] && exit 0
        xrandr --output "$out" --auto 2>/dev/null || true
        cur_w="$(xrandr 2>/dev/null | awk "/\\*/ {gsub(/[^0-9x]/,\"\",\$1); split(\$1,a,\"x\"); print a[1]; exit}")"
        if [ -n "$cur_w" ] && [ "$cur_w" -gt 3200 ] 2>/dev/null; then
            if xrandr 2>/dev/null | grep -q "1920x1080"; then
                xrandr --output "$out" --mode 1920x1080 2>/dev/null || true
            elif xrandr 2>/dev/null | grep -q "2560x1440"; then
                xrandr --output "$out" --mode 2560x1440 2>/dev/null || true
            fi
        fi
    ' || true
    return 0
}

xfconf_profile_paths() {
    as_user bash -lc '
        if ! command -v xfconf-query >/dev/null 2>&1; then exit 1; fi
        xfconf-query -c xfce4-terminal -l 2>/dev/null | grep -E "/profiles/profile-[0-9]+/font-name$" || true
        xfconf-query -c xfce4-terminal -l 2>/dev/null | grep "/profiles/default/font-name$" || true
    ' 2>/dev/null
}

fix_xfce_scale() {
    if ! as_user bash -lc 'command -v xfconf-query >/dev/null 2>&1'; then
        return 1
    fi
    if ! has_x_display; then
        warn "No X display for xfconf — log into Xfce first"
        return 1
    fi
    log "XFCE: setting /Xft/DPI=$TARGET_DPI"
    as_user xfconf-query -c xsettings -p /Xft/DPI --create -t int -s "$TARGET_DPI" 2>/dev/null \
        || as_user xfconf-query -c xsettings -p /Xft/DPI -s "$TARGET_DPI" 2>/dev/null || true

    local panel_idx
    for panel_idx in 0 1 2; do
        as_user xfconf-query -c xfce4-panel -p "/panels/panel-${panel_idx}/size" --create -t int -s "$PANEL_SIZE" 2>/dev/null \
            || as_user xfconf-query -c xfce4-panel -p "/panels/panel-${panel_idx}/size" -s "$PANEL_SIZE" 2>/dev/null || true
    done

    log "XFCE terminal font: $TERM_FONT"
    local path
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        as_user xfconf-query -c xfce4-terminal -p "$path" -s "$TERM_FONT" 2>/dev/null || true
    done < <(xfconf_profile_paths)

    if ! xfconf_profile_paths | grep -q .; then
        as_user xfconf-query -c xfce4-terminal -p /profiles/default/font-name --create -t string -s "$TERM_FONT" 2>/dev/null || true
    fi

    as_user bash -lc 'xfce4-panel -r >/dev/null 2>&1 || true'
    return 0
}

fix_gnome_scale() {
    if ! as_user bash -lc 'command -v gsettings >/dev/null 2>&1'; then
        return 1
    fi
    if ! has_x_display; then
        return 1
    fi
    local factor="1.0"
    case "$TARGET_DPI" in
        144) factor="1.5" ;;
        120) factor="1.25" ;;
    esac
    log "GNOME: text-scaling-factor=$factor"
    as_user gsettings set org.gnome.desktop.interface text-scaling-factor "$factor" 2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface cursor-size "$PANEL_SIZE" 2>/dev/null || true
    return 0
}

fix_desktop_scale() {
    if fix_xfce_scale; then return 0; fi
    if fix_gnome_scale; then return 0; fi
    log "No xfconf-query or gsettings — skip desktop DPI/font scale"
    return 1
}

install_autostart() {
    if [[ $EUID -ne 0 ]] && [[ "$(id -un)" != "$DESKTOP_USER" ]]; then
        return 1
    fi
    local autostart_dir="/home/$DESKTOP_USER/.config/autostart"
    install -d -m 0755 -o "$DESKTOP_USER" -g "$DESKTOP_USER" "$autostart_dir" 2>/dev/null || true
    local f="$autostart_dir/ctg-display-scale.desktop"
    cat >"$f" <<'DESK'
[Desktop Entry]
Type=Application
Name=CTG Display Scale
Comment=Hacker Planet CTG lab — HiDPI + VBoxClient autoresize at login
Exec=sh -c 'sleep 3; bash /mnt/ctg/ctg-display-scale.sh 2>/dev/null || bash /opt/ctg/ctg-display-scale.sh 2>/dev/null || true'
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
    chown "$DESKTOP_USER:$DESKTOP_USER" "$f" 2>/dev/null || true
    chmod 644 "$f" 2>/dev/null || true
    log "Installed autostart: $f"
    return 0
}

print_diagnose() {
    log "=== CTG display scale diagnose (read-only) ==="
    check_crlf || true
    if ! detect_desktop_user; then
        exit 1
    fi
    if has_x_display; then
        log "X display: OK ($DISPLAY_NUM)"
    else
        warn "X display: NOT reachable on $DISPLAY_NUM"
        note_issue
    fi
    local res
    res="$(get_current_resolution)"
    read -r RES_W RES_H <<< "$res"
    log "Resolution: ${RES_W}x${RES_H}"
    compute_target_dpi "$RES_W" "$RES_H"
    if find_vboxclient; then
        log "VBoxClient: $VBOX_CLIENT"
        if as_user bash -lc 'pgrep -u "$USER" -f "VBoxClient --vmsvga|VBoxClient --display" >/dev/null 2>&1'; then
            log "VBoxClient autoresize: running"
        else
            warn "VBoxClient autoresize: NOT running"
            note_issue
        fi
    else
        warn "VBoxClient: NOT FOUND"
        note_issue
    fi
    if as_user bash -lc 'command -v xfconf-query >/dev/null 2>&1'; then
        local dpi panel
        dpi="$(as_user xfconf-query -c xsettings -p /Xft/DPI 2>/dev/null || echo unset)"
        panel="$(as_user xfconf-query -c xfce4-panel -p /panels/panel-0/size 2>/dev/null || echo unset)"
        log "XFCE /Xft/DPI: $dpi (recommended: $TARGET_DPI)"
        log "XFCE panel-0 size: $panel (recommended: $PANEL_SIZE)"
        local font
        font="$(as_user xfconf-query -c xfce4-terminal -p /profiles/default/font-name 2>/dev/null || echo unset)"
        log "XFCE terminal font: $font (recommended: $TERM_FONT)"
        if [[ "$dpi" != unset && "$dpi" != "$TARGET_DPI" ]]; then
            warn "DPI mismatch — run without --diagnose-only to apply"
            note_issue
        fi
    elif as_user bash -lc 'command -v gsettings >/dev/null 2>&1'; then
        local gsf
        gsf="$(as_user gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null || echo unset)"
        log "GNOME text-scaling-factor: $gsf"
    else
        log "Desktop toolkit: xfconf/gsettings not available"
    fi
    log "Host fix: .\\scripts\\windows\\Start-KaliSeamless.ps1 clears bad GUI/LastGuestSizeHint"
    log "Docs: docs/KALI_DISPLAY_SCALING.md"
    if [[ $ISSUES -gt 0 ]]; then
        err "Diagnose found $ISSUES issue(s)"
        exit 1
    fi
    log "Diagnose: OK — run without --diagnose-only to apply scale fixes"
    exit 0
}

log "=== CTG display scale ==="
check_crlf || true

if $DIAGNOSE_ONLY; then
    print_diagnose
fi

if ! detect_desktop_user; then
    exit 1
fi

res="$(get_current_resolution)"
read -r RES_W RES_H <<< "$res"
compute_target_dpi "$RES_W" "$RES_H"

run_optional "VBoxClient autoresize" fix_vbox_autoresize
run_optional "xrandr autoresize" fix_xrandr
run_optional "desktop DPI/font scale" fix_desktop_scale
run_optional "autostart install" install_autostart

log "Done — open a new terminal window if font size unchanged in existing tabs."
log "Windows host: .\\scripts\\windows\\Start-KaliSeamless.ps1 (AutoresizeGuest + clear huge LastGuestSizeHint)"
log "Docs: docs/KALI_DISPLAY_SCALING.md"

if [[ $ISSUES -gt 0 ]]; then
    warn "Completed with $ISSUES non-fatal issue(s)"
    exit 1
fi
exit 0
