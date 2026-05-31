#!/usr/bin/env bash
# CTG Kali guest — display fit + readable fonts for VirtualBox (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Default (--fonts-only): guest resolution tracks VM window (VBoxClient autoresize);
# modest Xft DPI (108–112) and larger terminal/Gtk fonts only — NOT whole-desktop blow-up.
#
# Use --aggressive for legacy resolution-based DPI (120/144), panel scale, xrandr caps.
# Use --reset to undo over-scaling from prior runs or Scaled + high DPI.
#
# Prereq: mount share first:
#   sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
# Run after GUI login:
#   bash /mnt/ctg/ctg-display-scale.sh
#   bash /mnt/ctg/ctg-display-scale.sh --reset
#   bash /mnt/ctg/ctg-display-scale.sh --diagnose-only
# Troubleshooting: docs/KALI_DISPLAY_SCALING.md
set -uo pipefail

DIAGNOSE_ONLY=false
RESET_MODE=false
FONTS_ONLY=true
AGGRESSIVE=false

for arg in "$@"; do
    case "$arg" in
        --diagnose-only|--diagnose) DIAGNOSE_ONLY=true ;;
        --reset) RESET_MODE=true; FONTS_ONLY=false; AGGRESSIVE=false ;;
        --fonts-only) FONTS_ONLY=true; AGGRESSIVE=false ;;
        --aggressive|--full-scale) AGGRESSIVE=true; FONTS_ONLY=false ;;
        -h|--help)
            echo "Usage: bash $(basename "$0") [--fonts-only] [--reset] [--aggressive] [--diagnose-only]"
            echo "  Default apply: --fonts-only (VBoxClient autoresize + modest DPI/fonts; no xrandr cap)"
            echo "  --reset       Undo over-scale (DPI 96, default fonts, xrandr --auto)"
            echo "  --aggressive  Legacy HiDPI (DPI 120/144, panel scale, xrandr cap >3200px)"
            echo "  --diagnose-only  Show resolution, DPI, fonts (no changes)"
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
GTK_FONT="Sans 10"
PANEL_SIZE=30
RES_W=0
RES_H=0
ISSUES=0
APPLY_MODE="fonts-only"

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

    if $RESET_MODE; then
        APPLY_MODE="reset"
        TARGET_DPI=96
        TERM_FONT="Monospace 11"
        GTK_FONT="Sans 10"
        PANEL_SIZE=30
        log "Reset mode -> DPI=$TARGET_DPI font=$TERM_FONT gtk=$GTK_FONT panel=$PANEL_SIZE"
        return 0
    fi

    if $AGGRESSIVE; then
        APPLY_MODE="aggressive"
        if [[ "$w" -ge 3200 ]] || [[ "$w" -ge 2800 && "$h" -ge 1500 ]]; then
            TARGET_DPI=144
            TERM_FONT="Monospace 14"
            PANEL_SIZE=48
            GTK_FONT="Sans 12"
        elif [[ "$w" -ge 2560 ]] || [[ "$h" -ge 1400 ]]; then
            TARGET_DPI=120
            TERM_FONT="Monospace 12"
            PANEL_SIZE=40
            GTK_FONT="Sans 11"
        else
            TARGET_DPI=96
            TERM_FONT="Monospace 11"
            PANEL_SIZE=30
            GTK_FONT="Sans 10"
        fi
        log "Aggressive ${w}x${h} -> DPI=$TARGET_DPI panel=$PANEL_SIZE font=$TERM_FONT gtk=$GTK_FONT"
        return 0
    fi

    # fonts-only (default): modest DPI bump; larger text only — resolution stays on autoresize
    APPLY_MODE="fonts-only"
    TARGET_DPI=108
    TERM_FONT="Monospace 13"
    GTK_FONT="Sans 11"
    PANEL_SIZE=30
    if [[ "$w" -ge 1920 ]] || [[ "$h" -ge 1080 ]]; then
        TARGET_DPI=112
        TERM_FONT="Monospace 14"
        GTK_FONT="Sans 12"
    fi
    log "Fonts-only ${w}x${h} -> DPI=$TARGET_DPI (no panel/xrandr upscale) font=$TERM_FONT gtk=$GTK_FONT"
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
    log "Starting VBoxClient --vmsvga / --display (autoresize — guest fits VM window)"
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
    log "xrandr: --auto on primary output (no forced downscale)"
    as_user bash -lc '
        out="$(xrandr 2>/dev/null | awk "/ connected/{print \$1; exit}")"
        [ -z "$out" ] && exit 0
        xrandr --output "$out" --auto 2>/dev/null || true
    ' || true

    if $AGGRESSIVE; then
        log "Aggressive: optional cap if mode width > 3200px"
        as_user bash -lc '
            out="$(xrandr 2>/dev/null | awk "/ connected/{print \$1; exit}")"
            [ -z "$out" ] && exit 0
            cur_w="$(xrandr 2>/dev/null | awk "/\\*/ {gsub(/[^0-9x]/,\"\",\$1); split(\$1,a,\"x\"); print a[1]; exit}")"
            if [ -n "$cur_w" ] && [ "$cur_w" -gt 3200 ] 2>/dev/null; then
                if xrandr 2>/dev/null | grep -q "1920x1080"; then
                    xrandr --output "$out" --mode 1920x1080 2>/dev/null || true
                elif xrandr 2>/dev/null | grep -q "2560x1440"; then
                    xrandr --output "$out" --mode 2560x1440 2>/dev/null || true
                fi
            fi
        ' || true
    fi
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

    log "XFCE Gtk/FontName: $GTK_FONT"
    as_user xfconf-query -c xsettings -p /Gtk/FontName --create -t string -s "$GTK_FONT" 2>/dev/null \
        || as_user xfconf-query -c xsettings -p /Gtk/FontName -s "$GTK_FONT" 2>/dev/null || true

    if [[ "$APPLY_MODE" == "aggressive" ]]; then
        local panel_idx
        for panel_idx in 0 1 2; do
            as_user xfconf-query -c xfce4-panel -p "/panels/panel-${panel_idx}/size" --create -t int -s "$PANEL_SIZE" 2>/dev/null \
                || as_user xfconf-query -c xfce4-panel -p "/panels/panel-${panel_idx}/size" -s "$PANEL_SIZE" 2>/dev/null || true
        done
    elif [[ "$APPLY_MODE" == "reset" ]]; then
        local panel_idx
        for panel_idx in 0 1 2; do
            as_user xfconf-query -c xfce4-panel -p "/panels/panel-${panel_idx}/size" -s "$PANEL_SIZE" 2>/dev/null || true
        done
    fi

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
    if [[ "$APPLY_MODE" == "aggressive" ]]; then
        case "$TARGET_DPI" in
            144) factor="1.5" ;;
            120) factor="1.25" ;;
        esac
    elif [[ "$APPLY_MODE" == "fonts-only" ]]; then
        case "$TARGET_DPI" in
            112) factor="1.08" ;;
            108) factor="1.05" ;;
        esac
    fi
    log "GNOME: text-scaling-factor=$factor"
    as_user gsettings set org.gnome.desktop.interface text-scaling-factor "$factor" 2>/dev/null || true
    if [[ "$APPLY_MODE" == "aggressive" ]]; then
        as_user gsettings set org.gnome.desktop.interface cursor-size "$PANEL_SIZE" 2>/dev/null || true
    elif [[ "$APPLY_MODE" == "reset" ]]; then
        as_user gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
    fi
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
Comment=Hacker Planet CTG lab — fonts-only + VBoxClient autoresize at login
Exec=sh -c 'sleep 3; bash /mnt/ctg/ctg-display-scale.sh --fonts-only 2>/dev/null || bash /opt/ctg/ctg-display-scale.sh --fonts-only 2>/dev/null || true'
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
    chown "$DESKTOP_USER:$DESKTOP_USER" "$f" 2>/dev/null || true
    chmod 644 "$f" 2>/dev/null || true
    log "Installed autostart: $f (--fonts-only)"
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
    local fo_dpi=108 fo_term="Monospace 13" fo_gtk="Sans 11"
    if [[ "$RES_W" -ge 1920 ]] || [[ "$RES_H" -ge 1080 ]]; then
        fo_dpi=112
        fo_term="Monospace 14"
        fo_gtk="Sans 12"
    fi
    log "Recommended (text too small): --fonts-only -> DPI=$fo_dpi terminal=$fo_term gtk=$fo_gtk"
    if [[ "$RES_W" -ge 2560 ]]; then
        log "Avoid with host Scaled mode: --aggressive would use DPI 120–144 (whole desktop huge)"
    fi
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
        local dpi panel gtk font
        dpi="$(as_user xfconf-query -c xsettings -p /Xft/DPI 2>/dev/null || echo unset)"
        gtk="$(as_user xfconf-query -c xsettings -p /Gtk/FontName 2>/dev/null || echo unset)"
        panel="$(as_user xfconf-query -c xfce4-panel -p /panels/panel-0/size 2>/dev/null || echo unset)"
        font="$(as_user xfconf-query -c xfce4-terminal -p /profiles/default/font-name 2>/dev/null || echo unset)"
        log "XFCE /Xft/DPI: $dpi (fonts-only target: $fo_dpi; reset: 96)"
        log "XFCE Gtk/FontName: $gtk (fonts-only target: $fo_gtk)"
        log "XFCE panel-0 size: $panel"
        log "XFCE terminal font: $font (fonts-only target: $fo_term)"
        if [[ "$dpi" != unset && "$dpi" -ge 120 ]]; then
            warn "DPI $dpi is high — guest may look huge with host Scaled mode; try --reset then --fonts-only"
            note_issue
        fi
    elif as_user bash -lc 'command -v gsettings >/dev/null 2>&1'; then
        local gsf
        gsf="$(as_user gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null || echo unset)"
        log "GNOME text-scaling-factor: $gsf"
    else
        log "Desktop toolkit: xfconf/gsettings not available"
    fi
    log "Host (text small): .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (not Scaled)"
    log "Guest fix: bash /mnt/ctg/ctg-display-scale.sh --fonts-only  |  undo: --reset"
    log "Docs: docs/KALI_DISPLAY_SCALING.md"
    if [[ $ISSUES -gt 0 ]]; then
        err "Diagnose found $ISSUES issue(s)"
        exit 1
    fi
    log "Diagnose: OK — apply: bash /mnt/ctg/ctg-display-scale.sh --fonts-only"
    exit 0
}

mode_label="fonts-only"
if $RESET_MODE; then mode_label="reset"; elif $AGGRESSIVE; then mode_label="aggressive"; fi
log "=== CTG display scale ($mode_label) ==="
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

log "Mode: $APPLY_MODE (use --help for --reset / --aggressive)"

run_optional "VBoxClient autoresize" fix_vbox_autoresize
run_optional "xrandr autoresize" fix_xrandr
run_optional "desktop DPI/font scale" fix_desktop_scale
if ! $RESET_MODE; then
    run_optional "autostart install" install_autostart
fi

log "Done — open a new terminal window if font size unchanged in existing tabs."
if [[ "$APPLY_MODE" == "fonts-only" ]]; then
    log "Host: .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (AutoresizeGuest; avoid Scaled for text-only fix)"
else
    log "Host: .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui"
fi
log "Docs: docs/KALI_DISPLAY_SCALING.md"

if [[ $ISSUES -gt 0 ]]; then
    warn "Completed with $ISSUES non-fatal issue(s)"
    exit 1
fi
exit 0
