#!/usr/bin/env bash
# CTG Kali guest — display fit + readable fonts for VirtualBox (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Default (--fit-window): guest resolution FITS the VM window (VBoxClient + xrandr --auto);
# never force oversized modes; then Andy-approved medium text (DPI 108, Sans 11, Monospace 12, panel 30).
#
# Use --text-medium / --text-plus15 for medium fonts only (same as fit-window text layer; no geometry change).
# Use --text-large for larger text (DPI 120, Sans 13, Monospace 15) — no geometry change.
# Use --fonts-only for lighter text (minimal xrandr; after fit-window once).
# Use --aggressive for legacy resolution-based DPI (120/144), panel scale — NOT with host Scaled.
# Use --login-scale for GDM/lightdm sign-in greeter (medium fonts; root; before GUI login).
# Use --cursor-neon for neon lemon-yellow pointer + black outline, ~10% larger (X11/Xfce only).
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
FIT_WINDOW=true
FONTS_ONLY=false
TEXT_MEDIUM=false
TEXT_LARGE=false
TEXT_PLUS15=false
AGGRESSIVE=false
LOGIN_SCALE=false
GREETER_SESSION=false
CURSOR_NEON=false

# Andy-approved medium preset (23258d4) — single source of truth for all screen modes
CTG_TEXT_MEDIUM_DPI=108
CTG_TEXT_MEDIUM_GTK="Sans 11"
CTG_TEXT_MEDIUM_TERM="Monospace 12"
CTG_TEXT_MEDIUM_PANEL=30

CTG_LOGIN_TEXT_SCALE="${CTG_LOGIN_TEXT_SCALE:-1.0}"
CTG_LIGHTDM_GREETER_FONT="${CTG_LIGHTDM_GREETER_FONT:-$CTG_TEXT_MEDIUM_GTK}"
CTG_LOGIN_CURSOR_SIZE="${CTG_LOGIN_CURSOR_SIZE:-12}"
CTG_CURSOR_THEME="${CTG_CURSOR_THEME:-CTG-Neon-Lemon}"
CTG_CURSOR_SIZE="${CTG_CURSOR_SIZE:-26}"

for arg in "$@"; do
    case "$arg" in
        --diagnose-only|--diagnose) DIAGNOSE_ONLY=true ;;
        --login-scale) LOGIN_SCALE=true; DIAGNOSE_ONLY=false; FIT_WINDOW=false; FONTS_ONLY=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; TEXT_LARGE=false; AGGRESSIVE=false; RESET_MODE=false; GREETER_SESSION=false ;;
        --greeter-session) GREETER_SESSION=true; LOGIN_SCALE=true; DIAGNOSE_ONLY=false; FIT_WINDOW=false; FONTS_ONLY=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; TEXT_LARGE=false; AGGRESSIVE=false; RESET_MODE=false ;;
        --cursor-neon) CURSOR_NEON=true; FIT_WINDOW=false; FONTS_ONLY=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; TEXT_LARGE=false; AGGRESSIVE=false; RESET_MODE=false ;;
        --reset) RESET_MODE=true; FIT_WINDOW=false; FONTS_ONLY=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; TEXT_LARGE=false; AGGRESSIVE=false; LOGIN_SCALE=false ;;
        --fit-window) FIT_WINDOW=true; FONTS_ONLY=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; TEXT_LARGE=false; AGGRESSIVE=false ;;
        --fonts-only) FONTS_ONLY=true; FIT_WINDOW=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; TEXT_LARGE=false; AGGRESSIVE=false ;;
        --text-medium|--text-plus15) TEXT_MEDIUM=true; TEXT_PLUS15=true; FIT_WINDOW=false; FONTS_ONLY=false; TEXT_LARGE=false; AGGRESSIVE=false ;;
        --text-large) TEXT_LARGE=true; FIT_WINDOW=false; FONTS_ONLY=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; AGGRESSIVE=false ;;
        --aggressive|--full-scale) AGGRESSIVE=true; FIT_WINDOW=false; FONTS_ONLY=false; TEXT_MEDIUM=false; TEXT_PLUS15=false; TEXT_LARGE=false ;;
        -h|--help)
            echo "Usage: bash $(basename "$0") [--fit-window] [--text-medium] [--text-plus15] [--text-large] [--fonts-only] [--login-scale] [--cursor-neon] [--reset] [--aggressive] [--diagnose-only]"
            echo "  Default apply: --fit-window (VBoxClient + xrandr fit; medium DPI ${CTG_TEXT_MEDIUM_DPI}; ${CTG_TEXT_MEDIUM_GTK}; ${CTG_TEXT_MEDIUM_TERM})"
            echo "  --text-medium / --text-plus15  Text layer only — medium preset (DPI ${CTG_TEXT_MEDIUM_DPI}; ${CTG_TEXT_MEDIUM_GTK})"
            echo "  --text-large  Text layer only — DPI 120, Sans 13, Monospace 15 (no oversized xrandr)"
            echo "  --fonts-only  Lighter DPI/fonts only — minimal xrandr (after fit-window once)"
            echo "  --login-scale GDM/lightdm greeter medium fonts / ${CTG_TEXT_MEDIUM_GTK} (sudo; greeter only)"
            echo "  --greeter-session GDM Init hook — xrandr + dconf each greeter (logout included)"
            echo "  --cursor-neon CTG-Neon-Lemon cursor (yellow + black ring), size ${CTG_CURSOR_SIZE} (~10% over 24; X11)"
            echo "  --reset       Undo over-scale (DPI 96, default fonts, xrandr --auto)"
            echo "  --aggressive  Legacy HiDPI (DPI 120/144, panel scale) — not with host Scaled"
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
APPLY_MODE="fit-window"

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

detect_ctg_display_manager() {
    local dm=""
    if [[ -f /etc/X11/default-display-manager ]]; then
        dm="$(basename "$(readlink -f /etc/X11/default-display-manager 2>/dev/null || true)" 2>/dev/null || true)"
    fi
    if [[ -z "$dm" || "$dm" == "." ]]; then
        local cand
        for cand in gdm3 gdm lightdm sddm; do
            if systemctl is-enabled "$cand" &>/dev/null 2>&1; then
                dm="$cand"
                break
            fi
        done
    fi
    if [[ -z "$dm" ]] && { [[ -d /etc/gdm3 ]] || command -v gdm3 &>/dev/null 2>&1; }; then
        dm=gdm3
    fi
    if [[ -z "$dm" ]] && [[ -d /etc/lightdm ]]; then
        dm=lightdm
    fi
    printf '%s' "${dm:-unknown}"
}

gdm_greeter_set_key() {
    local f="$1" key="$2" val="$3"
    if [[ -f "$f" ]] && grep -qE "^${key}=" "$f" 2>/dev/null; then
        if grep -qE "^${key}=${val}\$" "$f" 2>/dev/null; then
            return 0
        fi
        sed -i "s/^${key}=.*/${key}=${val}/" "$f"
        log "GDM greeter: updated ${key}=${val} in $f"
        return 0
    fi
    if [[ ! -f "$f" ]] || ! grep -qF '[org/gnome/desktop/interface]' "$f" 2>/dev/null; then
        {
            echo "# CTG login greeter scale (Hacker Planet lab)"
            echo "[org/gnome/desktop/interface]"
        } >>"$f"
    fi
    echo "${key}=${val}" >>"$f"
    chmod 644 "$f"
    log "GDM greeter: appended ${key}=${val} to $f"
}

compile_gdm_greeter_dconf() {
    local scale="$1"
    local cursor="${2:-12}"
    local font="${3:-$CTG_TEXT_MEDIUM_GTK}"
    local db_dir=/etc/dconf/db/gdm.d
    local db_file="${db_dir}/00-ctg-login-scale"
    install -d -m 0755 "$db_dir"
    cat >"$db_file" <<EOF
# CTG login greeter medium fonts (Hacker Planet lab — preset 23258d4)
[org/gnome/desktop/interface]
text-scaling-factor=${scale}
cursor-size=${cursor}
font-name='${font}'
EOF
    chmod 644 "$db_file"
    local lock_dir=/etc/dconf/db/gdm.d/locks
    install -d -m 0755 "$lock_dir"
    cat >"${lock_dir}/00-ctg-login-scale" <<'LOCKEOF'
/org/gnome/desktop/interface/text-scaling-factor
/org/gnome/desktop/interface/cursor-size
/org/gnome/desktop/interface/font-name
LOCKEOF
    chmod 644 "${lock_dir}/00-ctg-login-scale"
    if command -v dconf >/dev/null 2>&1; then
        dconf update
        log "GDM dconf db compiled: $db_file (+ locks; logout greeter uses same scale)"
    else
        warn "dconf not found — install dconf-cli for greeter dconf db"
        note_issue
    fi
}

refresh_greeter_framebuffer() {
    if ! command -v xrandr >/dev/null 2>&1; then
        return 0
    fi
    local out
    out="$(xrandr 2>/dev/null | awk '/ connected/{print $1; exit}')"
    if [[ -n "$out" ]]; then
        xrandr --output "$out" --auto 2>/dev/null || xrandr --auto 2>/dev/null || true
        log "Greeter framebuffer: xrandr --output ${out} --auto"
    else
        xrandr --auto 2>/dev/null || true
        log "Greeter framebuffer: xrandr --auto"
    fi
    return 0
}

signal_host_greeter_refresh() {
    local share path
    for share in /media/sf_ctg-backups /mnt/ctg; do
        if [[ -d "$share" && -w "$share" ]]; then
            path="${share}/CTG_GREETER_REFRESH"
            if date -Iseconds >"$path" 2>/dev/null; then
                log "Host greeter refresh signal: $path"
                return 0
            fi
        fi
    done
    if command -v VBoxControl >/dev/null 2>&1; then
        VBoxControl guestproperty write /VirtualBox/HostInfo/GUI/LoggedOutUsers 1 >/dev/null 2>&1 \
            && log "Host greeter refresh signal: VBoxControl guestproperty LoggedOutUsers=1" \
            || true
    fi
    return 0
}

install_gdm_greeter_init_script() {
    local init_dir=/etc/gdm3/Init/Default
    local init_script="${init_dir}/01-ctg-greeter-display"
    install -d -m 0755 "$init_dir"
    cat >"$init_script" <<'INITEOF'
#!/bin/sh
# CTG — greeter framebuffer + login scale on every greeter display (boot + logout)
if command -v xrandr >/dev/null 2>&1; then
    OUT="$(xrandr 2>/dev/null | awk '/ connected/{print $1; exit}')"
    if [ -n "$OUT" ]; then
        xrandr --output "$OUT" --auto 2>/dev/null || xrandr --auto 2>/dev/null || true
    else
        xrandr --auto 2>/dev/null || true
    fi
fi
for ScaleSh in /opt/ctg/ctg-display-scale.sh /mnt/ctg/ctg-display-scale.sh /media/sf_ctg-backups/ctg-display-scale.sh; do
    if [ -f "$ScaleSh" ]; then
        bash "$ScaleSh" --greeter-session 2>/dev/null || true
        break
    fi
done
INITEOF
    chmod 755 "$init_script"
    log "GDM Init: $init_script (xrandr + --greeter-session each greeter)"
}

install_gdm_postsession_script() {
    local post_dir=/etc/gdm3/PostSession/Default
    local post_script="${post_dir}/01-ctg-greeter-host-refresh"
    install -d -m 0755 "$post_dir"
    cat >"$post_script" <<'POSTEOF'
#!/bin/sh
# CTG — tell Windows host to refresh greeter video hint after logout
for Share in /media/sf_ctg-backups /mnt/ctg; do
    if [ -d "$Share" ]; then
        date -Iseconds >"$Share/CTG_GREETER_REFRESH" 2>/dev/null || true
        break
    fi
done
if command -v VBoxControl >/dev/null 2>&1; then
    VBoxControl guestproperty write /VirtualBox/HostInfo/GUI/LoggedOutUsers 1 2>/dev/null || true
fi
POSTEOF
    chmod 755 "$post_script"
    log "GDM PostSession: $post_script (CTG_GREETER_REFRESH on logout)"
}

install_lightdm_greeter_init_script() {
    local drop_dir=/etc/lightdm/lightdm.conf.d
    local drop_file="${drop_dir}/50-ctg-greeter-display.conf"
    install -d -m 0755 "$drop_dir"
    cat >"$drop_file" <<'LDMEOF'
# CTG — run greeter scale before lightdm gtk greeter (boot + logout)
[Seat:*]
display-setup-script=bash /opt/ctg/ctg-display-scale.sh --greeter-session 2>/dev/null || bash /mnt/ctg/ctg-display-scale.sh --greeter-session 2>/dev/null || true
LDMEOF
    chmod 644 "$drop_file"
    log "lightdm: display-setup-script -> --greeter-session in $drop_file"
}

apply_gdm3_greeter_text_scale() {
    local scale="$1"
    local cursor="${2:-12}"
    local font="${3:-$CTG_TEXT_MEDIUM_GTK}"
    local f=/etc/gdm3/greeter.dconf-defaults
    install -d -m 0755 /etc/gdm3
    touch "$f"
    chmod 644 "$f"
    gdm_greeter_set_key "$f" text-scaling-factor "$scale"
    gdm_greeter_set_key "$f" cursor-size "$cursor"
    gdm_greeter_set_key "$f" font-name "'${font}'"
    compile_gdm_greeter_dconf "$scale" "$cursor" "$font"
    install_gdm_greeter_init_script
    install_gdm_postsession_script
}

apply_lightdm_gtk_greeter_fonts() {
    local font="$1"
    local drop_dir=/etc/lightdm/lightdm-gtk-greeter.conf.d
    local drop_file="${drop_dir}/50-ctg-login-scale.conf"
    install -d -m 0755 "$drop_dir"
    cat >"$drop_file" <<EOF
# CTG login greeter medium fonts (Hacker Planet lab — preset 23258d4)
[greeter]
theme-font-name=${font}
clock-font-name=${font}
EOF
    chmod 644 "$drop_file"
    log "lightdm-gtk-greeter: theme/clock font ${font} in $drop_file"
    install_lightdm_greeter_init_script
}

apply_sddm_greeter_font_scale() {
    local pt="${1:-14}"
    local drop_dir=/etc/sddm.conf.d
    local drop_file="${drop_dir}/50-ctg-login-scale.conf"
    install -d -m 0755 "$drop_dir"
    cat >"$drop_file" <<EOF
# CTG login greeter scale (Hacker Planet lab)
[Theme]
Font=Sans,${pt},-1,5,50,0,0,0,0,0
EOF
    chmod 644 "$drop_file"
    log "SDDM: Font=Sans,${pt} in $drop_file"
}

fix_login_greeter_scale() {
    if [[ $EUID -ne 0 ]]; then
        err "--login-scale requires root: sudo bash $(basename "$0") --login-scale"
        return 1
    fi
    local dm scale font cursor sddm_pt
    dm="$(detect_ctg_display_manager)"
    scale="$CTG_LOGIN_TEXT_SCALE"
    font="$CTG_LIGHTDM_GREETER_FONT"
    cursor="$CTG_LOGIN_CURSOR_SIZE"
    sddm_pt="${font#Sans }"
    [[ "$sddm_pt" == "$font" ]] && sddm_pt="${CTG_TEXT_MEDIUM_GTK#Sans }"
    log "=== CTG login greeter medium (${font} / scale ${scale} / cursor ${cursor}) ==="
    log "Display manager: $dm"
    case "$dm" in
        gdm3|gdm)
            apply_gdm3_greeter_text_scale "$scale" "$cursor" "$font"
            ;;
        lightdm)
            if [[ -d /etc/lightdm ]] && { [[ -f /etc/lightdm/lightdm-gtk-greeter.conf ]] || [[ -d /usr/share/lightdm/lightdm-gtk-greeter.conf ]]; }; then
                apply_lightdm_gtk_greeter_fonts "$font"
            else
                warn "lightdm without gtk-greeter — try GDM or manual greeter font"
                note_issue
            fi
            ;;
        sddm)
            apply_sddm_greeter_font_scale "$sddm_pt"
            ;;
        *)
            if [[ -d /etc/gdm3 ]]; then
                apply_gdm3_greeter_text_scale "$scale" "$cursor" "$font"
            elif [[ -d /etc/lightdm ]]; then
                apply_lightdm_gtk_greeter_fonts "$font"
            else
                warn "Unknown display manager ($dm) — no greeter scale applied"
                note_issue
            fi
            ;;
    esac
    log "Post-login desktop unchanged — still use --fit-window (medium DPI ${CTG_TEXT_MEDIUM_DPI}, ${CTG_TEXT_MEDIUM_GTK}) after Xfce login"
    log "Greeter hooks installed — logout greeter uses same scale (GDM Init + PostSession)"
    return 0
}

run_greeter_session_refresh() {
    log "=== CTG greeter session refresh (logout greeter / GDM Init) ==="
    refresh_greeter_framebuffer
    compile_gdm_greeter_dconf "$CTG_LOGIN_TEXT_SCALE" "$CTG_LOGIN_CURSOR_SIZE" "$CTG_LIGHTDM_GREETER_FONT"
    signal_host_greeter_refresh
    return 0
}

resolve_ctg_neon_cursor_assets() {
    local candidate script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for candidate in \
        "${script_dir}/assets/ctg-neon-cursor" \
        /mnt/ctg/assets/ctg-neon-cursor \
        /opt/ctg/assets/ctg-neon-cursor \
        /media/sf_ctg-backups/assets/ctg-neon-cursor; do
        if [[ -f "${candidate}/build-cursor-theme.sh" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

install_ctg_neon_cursor_theme() {
    local asset_dir build_sh install_root user_icons
    asset_dir="$(resolve_ctg_neon_cursor_assets)" || {
        warn "CTG neon cursor assets not found (assets/ctg-neon-cursor)"
        return 1
    }
    build_sh="${asset_dir}/build-cursor-theme.sh"
    install_root="/opt/ctg/cursors/${CTG_CURSOR_THEME}"
    if [[ $EUID -eq 0 ]]; then
        bash "$build_sh" "$install_root" || return 1
        user_icons="/home/${DESKTOP_USER}/.icons/${CTG_CURSOR_THEME}"
        install -d -m 0755 "/home/${DESKTOP_USER}/.icons"
        rm -rf "$user_icons" 2>/dev/null || true
        cp -a "$install_root" "$user_icons" 2>/dev/null || ln -sf "$install_root" "$user_icons" 2>/dev/null || true
        chown -R "${DESKTOP_USER}:${DESKTOP_USER}" "/home/${DESKTOP_USER}/.icons/${CTG_CURSOR_THEME}" 2>/dev/null || true
        log "Installed cursor theme system + user: ${CTG_CURSOR_THEME} -> ${install_root}"
    else
        install_root="/home/${DESKTOP_USER}/.icons/${CTG_CURSOR_THEME}"
        bash "$build_sh" "$install_root" || return 1
        log "Installed cursor theme user: ${CTG_CURSOR_THEME} -> ${install_root}"
    fi
    return 0
}

apply_cursor_neon() {
    if ! detect_desktop_user; then
        return 1
    fi
    log "=== CTG neon cursor (${CTG_CURSOR_THEME}, size ${CTG_CURSOR_SIZE}; X11 only) ==="
    run_optional "install CTG-Neon-Lemon theme" install_ctg_neon_cursor_theme
    if as_user bash -lc 'command -v xfconf-query >/dev/null 2>&1'; then
        log "XFCE cursor: ${CTG_CURSOR_THEME} size ${CTG_CURSOR_SIZE}"
        as_user xfconf-query -c xsettings -p /Gtk/CursorThemeName --create -t string -s "$CTG_CURSOR_THEME" 2>/dev/null \
            || as_user xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "$CTG_CURSOR_THEME" 2>/dev/null || true
        as_user xfconf-query -c xsettings -p /Gtk/CursorThemeSize --create -t int -s "$CTG_CURSOR_SIZE" 2>/dev/null \
            || as_user xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s "$CTG_CURSOR_SIZE" 2>/dev/null || true
    fi
    if as_user bash -lc 'command -v gsettings >/dev/null 2>&1'; then
        as_user gsettings set org.gnome.desktop.interface cursor-theme "$CTG_CURSOR_THEME" 2>/dev/null || true
        as_user gsettings set org.gnome.desktop.interface cursor-size "$CTG_CURSOR_SIZE" 2>/dev/null || true
    fi
    log "Cursor: neon lemon-yellow circle + black ring (~10% over default 24px). Wayland not supported in VBox lab."
    return 0
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

apply_medium_text() {
    TARGET_DPI="$CTG_TEXT_MEDIUM_DPI"
    GTK_FONT="$CTG_TEXT_MEDIUM_GTK"
    TERM_FONT="$CTG_TEXT_MEDIUM_TERM"
    PANEL_SIZE="$CTG_TEXT_MEDIUM_PANEL"
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

    if $TEXT_LARGE; then
        APPLY_MODE="text-large"
        TARGET_DPI=120
        TERM_FONT="Monospace 15"
        GTK_FONT="Sans 13"
        PANEL_SIZE=36
        log "Text-large ${w}x${h} -> DPI=$TARGET_DPI font=$TERM_FONT gtk=$GTK_FONT (geometry unchanged)"
        return 0
    fi

    if $TEXT_MEDIUM; then
        APPLY_MODE="text-medium"
        apply_medium_text
        log "Text-medium ${w}x${h} -> DPI=$TARGET_DPI font=$TERM_FONT gtk=$GTK_FONT (geometry unchanged; xfconf persists)"
        return 0
    fi

    if $FONTS_ONLY; then
        APPLY_MODE="fonts-only"
        TARGET_DPI=105
        TERM_FONT="Monospace 11"
        GTK_FONT="Sans 10"
        PANEL_SIZE=30
        log "Fonts-only ${w}x${h} -> DPI=$TARGET_DPI font=$TERM_FONT gtk=$GTK_FONT"
        return 0
    fi

    if ! $FIT_WINDOW; then
        APPLY_MODE="none"
        return 0
    fi

    # fit-window (default): geometry fit + medium text (saved to ~/.config/xfce4 via xfconf)
    APPLY_MODE="fit-window"
    apply_medium_text
    log "Fit-window ${w}x${h} -> DPI=$TARGET_DPI (VBoxClient+xrandr fit; medium fonts) font=$TERM_FONT gtk=$GTK_FONT panel=$PANEL_SIZE"
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

downscale_oversized_xrandr() {
    # Guest larger than VM window → cut-off / blown-out desktop. Never upscaling here.
    as_user bash -lc '
        out="$(xrandr 2>/dev/null | awk "/ connected/{print \$1; exit}")"
        [ -z "$out" ] && exit 0
        cur_w="$(xrandr 2>/dev/null | awk "/\\*/ {gsub(/[^0-9x]/,\"\",\$1); split(\$1,a,\"x\"); print a[1]; exit}")"
        cur_h="$(xrandr 2>/dev/null | awk "/\\*/ {gsub(/[^0-9x]/,\"\",\$1); split(\$1,a,\"x\"); print a[2]; exit}")"
        max_w=2560
        max_h=1600
        need=0
        if [ -n "$cur_w" ] && [ "$cur_w" -gt "$max_w" ] 2>/dev/null; then need=1; fi
        if [ -n "$cur_h" ] && [ "$cur_h" -gt "$max_h" ] 2>/dev/null; then need=1; fi
        [ "$need" -eq 0 ] && exit 0
        for mode in 2560x1440 1920x1200 1920x1080 1680x1050 1600x900 1366x768 1280x720; do
            if xrandr 2>/dev/null | grep -Eq "[[:space:]]${mode}[[:space:]]"; then
                xrandr --output "$out" --mode "$mode" 2>/dev/null && exit 0
            fi
        done
    ' || true
}

fix_xrandr() {
    if ! has_x_display; then
        return 0
    fi
    if ! as_user bash -lc 'command -v xrandr >/dev/null 2>&1'; then
        return 0
    fi
    if $FIT_WINDOW || $RESET_MODE; then
        log "xrandr: fit-to-window (--auto; downscale if guest > 2560×1600 — fixes cut-off)"
    else
        log "xrandr: --auto on primary output (no forced upscale)"
    fi
    as_user bash -lc '
        out="$(xrandr 2>/dev/null | awk "/ connected/{print \$1; exit}")"
        [ -z "$out" ] && exit 0
        xrandr --output "$out" --auto 2>/dev/null || true
    ' || true

    if $FIT_WINDOW || $RESET_MODE; then
        downscale_oversized_xrandr
    fi

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

    if [[ "$APPLY_MODE" == "aggressive" || "$APPLY_MODE" == "fit-window" || "$APPLY_MODE" == "text-medium" || "$APPLY_MODE" == "text-large" ]]; then
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
    elif [[ "$APPLY_MODE" == "fonts-only" || "$APPLY_MODE" == "fit-window" || "$APPLY_MODE" == "text-medium" || "$APPLY_MODE" == "text-large" ]]; then
        case "$TARGET_DPI" in
            120) factor="1.12" ;;
            108) factor="1.0" ;;
            105) factor="1.03" ;;
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

ctg_display_autostart_desktop() {
    cat <<'DESK'
[Desktop Entry]
Type=Application
Name=CTG Display Scale
Comment=Hacker Planet CTG lab — fit-window medium fonts + VBoxClient at login (before seamless)
Exec=sh -c 'sleep 2; bash /mnt/ctg/ctg-display-scale.sh --fit-window --cursor-neon 2>/dev/null || bash /opt/ctg/ctg-display-scale.sh --fit-window --cursor-neon 2>/dev/null || true'
X-GNOME-Autostart-Delay=2
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
}

install_autostart() {
    if [[ $EUID -ne 0 ]] && [[ "$(id -un)" != "$DESKTOP_USER" ]]; then
        return 1
    fi
    local autostart_dir="/home/$DESKTOP_USER/.config/autostart"
    install -d -m 0755 -o "$DESKTOP_USER" -g "$DESKTOP_USER" "$autostart_dir" 2>/dev/null || true
    local f="$autostart_dir/ctg-display-scale.desktop"
    ctg_display_autostart_desktop >"$f"
    chown "$DESKTOP_USER:$DESKTOP_USER" "$f" 2>/dev/null || true
    chmod 644 "$f" 2>/dev/null || true
    log "Installed user autostart: $f (--fit-window medium + --cursor-neon, before seamless)"
    if [[ $EUID -eq 0 ]]; then
        install -d -m 0755 /etc/xdg/autostart
        ctg_display_autostart_desktop >/etc/xdg/autostart/ctg-display-scale.desktop
        chmod 644 /etc/xdg/autostart/ctg-display-scale.desktop
        log "Installed system autostart: /etc/xdg/autostart/ctg-display-scale.desktop (kali-boot-autopatch --install)"
    fi
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
    local fo_dpi="$CTG_TEXT_MEDIUM_DPI" fo_term="$CTG_TEXT_MEDIUM_TERM" fo_gtk="$CTG_TEXT_MEDIUM_GTK"
    log "Recommended default: --fit-window (VBoxClient + xrandr fit + medium DPI=$fo_dpi preset 23258d4)"
    log "Medium text only (no geometry): --text-medium / --text-plus15 -> DPI=$fo_dpi $fo_gtk $fo_term"
    log "Larger text: --text-large -> DPI=120 Sans 13 Monospace 15"
    log "Smaller text: --fonts-only -> DPI=105 Sans 10 Monospace 11"
    if [[ "$RES_W" -gt 2560 ]] || [[ "$RES_H" -gt 1600 ]]; then
        warn "Resolution ${RES_W}x${RES_H} exceeds VM window — cut-off likely; run --fit-window or --reset"
        note_issue
    fi
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
        log "XFCE /Xft/DPI: $dpi (fit-window target: $fo_dpi; reset: 96)"
        log "XFCE Gtk/FontName: $gtk (fit-window target: $fo_gtk)"
        log "XFCE panel-0 size: $panel"
        log "XFCE terminal font: $font (fit-window target: $fo_term)"
        if [[ "$dpi" != unset && "$dpi" -ge 144 ]]; then
            warn "DPI $dpi is very high — whole desktop may look huge; try --reset then --fit-window"
            note_issue
        elif [[ "$dpi" != unset && "$dpi" -eq 120 && "$RES_W" -ge 2560 ]]; then
            warn "DPI 120 on wide guest — OK for --text-large; if chrome huge use --reset then --fit-window"
        fi
    elif as_user bash -lc 'command -v gsettings >/dev/null 2>&1'; then
        local gsf
        gsf="$(as_user gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null || echo unset)"
        log "GNOME text-scaling-factor: $gsf"
    else
        log "Desktop toolkit: xfconf/gsettings not available"
    fi
    log "Host (cut-off / blown out): .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (not Scaled)"
    log "Login greeter tiny text: sudo bash /mnt/ctg/ctg-display-scale.sh --login-scale (medium greeter fonts; greeter only)"
    log "Neon cursor: bash /mnt/ctg/ctg-display-scale.sh --cursor-neon (or with --fit-window)"
    log "Guest fix: bash /mnt/ctg/ctg-display-scale.sh --fit-window  |  medium: --text-medium  |  large: --text-large  |  undo: --reset"
    log "Docs: docs/KALI_DISPLAY_SCALING.md"
    if [[ $ISSUES -gt 0 ]]; then
        err "Diagnose found $ISSUES issue(s)"
        exit 1
    fi
    log "Diagnose: OK — apply: bash /mnt/ctg/ctg-display-scale.sh --fit-window"
    exit 0
}

mode_label="fit-window"
if $RESET_MODE; then mode_label="reset"
elif $AGGRESSIVE; then mode_label="aggressive"
elif $TEXT_LARGE; then mode_label="text-large"
elif $TEXT_MEDIUM; then mode_label="text-medium"
elif $FONTS_ONLY; then mode_label="fonts-only"
elif $CURSOR_NEON && ! $FIT_WINDOW; then mode_label="cursor-neon"
fi
if $GREETER_SESSION; then
    if [[ $EUID -ne 0 ]]; then
        err "--greeter-session requires root (runs from GDM Init as root)"
        exit 1
    fi
    run_greeter_session_refresh
    exit $?
fi
if $LOGIN_SCALE; then
    fix_login_greeter_scale
    exit $?
fi

log "=== CTG display scale ($mode_label${CURSOR_NEON:+, cursor-neon}) ==="
check_crlf || true

if $DIAGNOSE_ONLY; then
    print_diagnose
fi

if ! detect_desktop_user; then
    exit 1
fi

if $CURSOR_NEON && ! $FIT_WINDOW && ! $RESET_MODE && ! $AGGRESSIVE && ! $TEXT_MEDIUM && ! $TEXT_LARGE && ! $FONTS_ONLY; then
    apply_cursor_neon
    exit $?
fi

res="$(get_current_resolution)"
read -r RES_W RES_H <<< "$res"
compute_target_dpi "$RES_W" "$RES_H"

log "Mode: $APPLY_MODE (use --help for --reset / --aggressive)"

run_optional "VBoxClient autoresize" fix_vbox_autoresize
run_optional "xrandr autoresize" fix_xrandr
run_optional "desktop DPI/font scale" fix_desktop_scale
if $CURSOR_NEON; then
    run_optional "neon lemon cursor" apply_cursor_neon
fi
if ! $RESET_MODE; then
    run_optional "autostart install" install_autostart
fi

log "Done — open a new terminal window if font size unchanged in existing tabs."
if [[ "$APPLY_MODE" == "fit-window" ]]; then
    log "Host: .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (AutoresizeGuest; clear bad LastGuestSizeHint)"
elif [[ "$APPLY_MODE" == "text-medium" ]]; then
    log "Host: .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (text-medium — xfconf saved in ~/.config/xfce4)"
elif [[ "$APPLY_MODE" == "text-large" ]]; then
    log "Host: .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (text-large — geometry should already be fit)"
elif [[ "$APPLY_MODE" == "fonts-only" ]]; then
    log "Host: .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui (fonts-only assumes fit-window already applied)"
else
    log "Host: .\\scripts\\windows\\Start-KaliSeamless.ps1 -DisplayMode Gui"
fi
log "Docs: docs/KALI_DISPLAY_SCALING.md"

if [[ $ISSUES -gt 0 ]]; then
    warn "Completed with $ISSUES non-fatal issue(s)"
    exit 1
fi
exit 0
