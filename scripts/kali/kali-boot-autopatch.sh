#!/usr/bin/env bash
# CTG Kali boot autopatch — fix common VirtualBox/GNOME boot errors on every boot.
# Authorized lab use only — Hacker Planet LLC · Philadelphia, PA
#
# Usage:
#   sudo bash kali-boot-autopatch.sh              # fix-only (default)
#   sudo bash kali-boot-autopatch.sh --upgrade      # apt full-upgrade
#   sudo bash kali-boot-autopatch.sh --firmware     # firmware-linux-nonfree if driver errors
#   sudo bash kali-boot-autopatch.sh --wifi-lab     # Realtek dongle + lab WiFi + promisc/monitor
#   sudo bash kali-boot-autopatch.sh --ids-ips      # ClamAV + Suricata-primary (detect-only)
#   sudo bash kali-boot-autopatch.sh --siem         # JSON export to Backups/logs/siem/
#   sudo bash kali-boot-autopatch.sh --install      # install systemd unit for boot
#   sudo bash kali-boot-autopatch.sh --retbleed     # RETBleed diagnose + apply (see docs/KALI_RETBLEED.md)
set -euo pipefail

LOG_FILE="/var/log/ctg-boot-autopatch.log"
MARKER="/var/lib/ctg/kali-boot-autopatch.done"
DDG_PRIMARY="94.140.14.14"
DDG_SECONDARY="94.140.15.15"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBOOT_HELPER="${SCRIPT_DIR}/ctg-reboot-if-needed.sh"
SERVICE_NAME="ctg-kali-autopatch.service"
UNIT_DEST="/etc/systemd/system/${SERVICE_NAME}"

DO_UPGRADE=false
DO_FIRMWARE=false
DO_INSTALL=false
DO_WIFI_LAB=false
DO_IDS_IPS=false
DO_SIEM=false
DO_IDS_OPTIMIZE=false
DO_RETBLEED=false

log() {
    local msg="[$(date -Iseconds)] [ctg-boot-autopatch] $*"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

ctg_reboot_helper() {
    local helper="$REBOOT_HELPER"
    for candidate in /mnt/ctg/ctg-reboot-if-needed.sh /opt/ctg/ctg-reboot-if-needed.sh /media/sf_ctg-backups/ctg-reboot-if-needed.sh; do
        if [[ -f "$candidate" ]]; then
            helper="$candidate"
            break
        fi
    done
    [[ -f "$helper" ]] || return 0
    bash "$helper" "$@" || true
}

usage() {
    cat <<EOF
CTG Kali boot autopatch — authorized defensive lab use only.

  sudo bash $0                 Fix common boot errors (default)
  sudo bash $0 --upgrade       Also run apt update && apt full-upgrade -y
  sudo bash $0 --firmware      Install firmware-linux-nonfree if driver errors seen
  sudo bash $0 --wifi-lab      Run ctg-wifi-lab-autorun after guest additions fix
  sudo bash $0 --ids-ips       Run ctg-ids-ips-autorun (Suricata-primary + ClamAV)
  sudo bash $0 --ids-ips --optimize  Pass --optimize to IDS autorun
  sudo bash $0 --siem          Run ctg-siem-autorun (JSON export for Windows tail)
  sudo bash $0 --install       Install ${SERVICE_NAME} for boot-time runs
  sudo bash $0 --retbleed      Run fix-retbleed-mitigation.sh (--apply if also --upgrade)
  sudo bash $0 --help

Log: ${LOG_FILE}
RETBleed log: /var/log/ctg-retbleed.log (see docs/KALI_RETBLEED.md)
DuckDuckGo DNS: preserved when 94.140.14.14/15.15 already in resolv.conf
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --upgrade) DO_UPGRADE=true ;;
        --firmware) DO_FIRMWARE=true ;;
        --install) DO_INSTALL=true ;;
        --wifi-lab) DO_WIFI_LAB=true ;;
        --ids-ips) DO_IDS_IPS=true ;;
        --optimize) DO_IDS_OPTIMIZE=true ;;
        --siem) DO_SIEM=true ;;
        --retbleed) DO_RETBLEED=true ;;
        --help|-h) usage; exit 0 ;;
        *) log "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

mkdir -p /var/lib/ctg "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "=== CTG Kali boot autopatch start (upgrade=$DO_UPGRADE firmware=$DO_FIRMWARE wifi_lab=$DO_WIFI_LAB ids_ips=$DO_IDS_IPS siem=$DO_SIEM optimize=$DO_IDS_OPTIMIZE retbleed=$DO_RETBLEED) ==="

resolv_has_ddg() {
    [[ -f /etc/resolv.conf ]] && grep -qE '94\.140\.(14\.14|15\.15)' /etc/resolv.conf
}

preserve_ddg_dns() {
    if resolv_has_ddg; then
        log "DDG preserve: DuckDuckGo DNS in /etc/resolv.conf — no DNS changes"
        return 0
    fi
    if [[ -f /etc/unbound/unbound.conf.d/ctg-ddg-forward.conf ]]; then
        log "DDG preserve: Unbound ctg-ddg-forward.conf present — no DNS changes"
        return 0
    fi
    log "DDG preserve: no DDG in resolv.conf — leaving upstream unchanged"
}

disable_broken_ctg_profiled() {
    log "Phase: disable broken CTG profile.d autostart hooks"
    local f disabled=0
    for f in /etc/profile.d/ctg-scrambler-autostart.sh /etc/profile.d/ctg-lab-autorun.sh; do
        if [[ -f "$f" ]] && [[ ! "$f" =~ \.disabled- ]]; then
            mv -f "$f" "${f}.disabled-$(date +%Y%m%d)"
            log "Disabled login hook: $f"
            disabled=$((disabled + 1))
        fi
    done
    if [[ $disabled -eq 0 ]]; then
        log "No active CTG profile.d hooks found (OK)"
    fi
    mkdir -p /etc/ctg
    touch /etc/ctg/scrambler-manual-only
    chmod 644 /etc/ctg/scrambler-manual-only
}

fix_virtualbox_seamless_guest() {
    # Guest-side prerequisites for VirtualBox seamless (Host+L on Windows host).
    # Host script Start-KaliSeamless.ps1 sets GUI/Seamless=on after desktop login.
    # See docs/KALI_VIRTUALBOX_SEAMLESS.md
    log "Phase: VirtualBox seamless guest (vboxservice, VBoxClient, X11 autostart)"
    local svc
    for svc in vboxadd-service vboxadd; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
            systemctl enable "${svc}.service" 2>/dev/null || true
            systemctl start "${svc}.service" 2>/dev/null || true
            log "systemctl: ${svc}.service enabled/started"
        fi
    done
    if command -v VBoxClient >/dev/null 2>&1; then
        log "VBoxClient present ($(VBoxClient --version 2>/dev/null || echo unknown))"
    else
        log "VBoxClient missing — virtualbox-guest-x11 not fully installed"
    fi
    install -d -m 0755 /etc/X11/xorg.conf.d
    local xorg_conf=/etc/X11/xorg.conf.d/60-vboxguest.conf
    if [[ ! -f "$xorg_conf" ]]; then
        cat >"$xorg_conf" <<'XEOF'
Section "Device"
    Identifier "VBoxVideo"
    Driver "vboxvideo"
    Option "IgnoreDisplayDevices" "true"
EndSection
XEOF
        log "Created $xorg_conf (VMSVGA seamless helper)"
    else
        log "Xorg vboxguest conf present: $xorg_conf"
    fi
    install -d -m 0755 /etc/xdg/autostart
    local autostart=/etc/xdg/autostart/vboxclient-seamless.desktop
    cat >"$autostart" <<'DESK'
[Desktop Entry]
Type=Application
Name=VirtualBox Seamless Client
Comment=CTG lab — vmsvga + seamless (prevents glitch-revert on Host+L)
Exec=sh -c 'VBoxClient --vmsvga 2>/dev/null || VBoxClient --display 2>/dev/null; VBoxClient --seamless'
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
    chmod 644 "$autostart"
    log "Installed $autostart (VBoxClient vmsvga+seamless at login)"
    local guest_fix="${SCRIPT_DIR}/ctg-seamless-guest.sh"
    for candidate in /mnt/ctg/ctg-seamless-guest.sh /opt/ctg/ctg-seamless-guest.sh; do
        if [[ -f "$candidate" ]]; then
            guest_fix="$candidate"
            break
        fi
    done
    if [[ -f "$guest_fix" ]] && who 2>/dev/null | grep -q ':0'; then
        log "Running guest panel/VBoxClient fix: $guest_fix"
        bash "$guest_fix" || log "ctg-seamless-guest returned non-zero (login may still be in progress)"
    else
        log "Guest seamless helper: bash /mnt/ctg/ctg-seamless-guest.sh after GUI login"
    fi
    local scale_fix="${SCRIPT_DIR}/ctg-display-scale.sh"
    for candidate in /mnt/ctg/ctg-display-scale.sh /opt/ctg/ctg-display-scale.sh; do
        if [[ -f "$candidate" ]]; then
            scale_fix="$candidate"
            break
        fi
    done
    if [[ -f "$scale_fix" ]] && who 2>/dev/null | grep -q ':0'; then
        log "Running display scale (DPI/terminal): $scale_fix"
        bash "$scale_fix" || log "ctg-display-scale returned non-zero (login may still be in progress)"
    else
        log "Display scale: bash /mnt/ctg/ctg-display-scale.sh after GUI login"
    fi
    log "Seamless toggle on Windows host: Host+L; menu: Host+Home; toolbar: docs/KALI_SEAMLESS_MODE.md"
    log "Display scale: docs/KALI_DISPLAY_SCALING.md"
}

fix_virtualbox_guest_packages() {
    # virtualbox-guest-x11 is required for VirtualBox seamless mode (Host+L on Windows).
    # See docs/KALI_VIRTUALBOX_SEAMLESS.md
    log "Phase: VirtualBox guest packages (x11, utils, dkms) — seamless + blank-screen fix"
    export DEBIAN_FRONTEND=noninteractive
    local missing=()
    for pkg in virtualbox-guest-x11 virtualbox-guest-utils dkms; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "Installing missing: ${missing[*]}"
        apt-get update -qq
        apt-get install -y --no-install-recommends \
            virtualbox-guest-x11 virtualbox-guest-utils dkms \
            build-essential "linux-headers-$(uname -r)" 2>/dev/null || \
            apt-get install -y --no-install-recommends \
                virtualbox-guest-x11 virtualbox-guest-utils dkms build-essential
        ctg_reboot_helper --mark
    else
        log "VirtualBox guest packages present"
    fi
}

fix_gdm_wayland_blank_screen() {
    log "Phase: GDM WaylandEnable=false (VirtualBox blank screen)"
    install -d -m 0755 /etc/gdm3
    local gdm_custom=/etc/gdm3/custom.conf
    local gdm_changed=false
    if [[ -f "$gdm_custom" ]]; then
        if grep -q '^WaylandEnable=' "$gdm_custom"; then
            if ! grep -q '^WaylandEnable=false' "$gdm_custom"; then
                sed -i 's/^WaylandEnable=.*/WaylandEnable=false/' "$gdm_custom"
                log "Updated WaylandEnable=false in $gdm_custom"
                gdm_changed=true
            else
                log "WaylandEnable=false already set"
            fi
        elif grep -q '^\[daemon\]' "$gdm_custom"; then
            sed -i '/^\[daemon\]/a WaylandEnable=false' "$gdm_custom"
            log "Added WaylandEnable=false under [daemon]"
            gdm_changed=true
        else
            printf '\n[daemon]\nWaylandEnable=false\n' >>"$gdm_custom"
            log "Appended [daemon] WaylandEnable=false"
            gdm_changed=true
        fi
    else
        cat >"$gdm_custom" <<'EOF'
[daemon]
WaylandEnable=false
EOF
        log "Created $gdm_custom with WaylandEnable=false"
        gdm_changed=true
    fi
    chmod 644 "$gdm_custom"
    if $gdm_changed; then
        ctg_reboot_helper --mark-gdm
    fi
}

ensure_ctg_backups_mount_hint() {
    log "Phase: ctg-backups shared folder mount hint"
    if mountpoint -q /mnt/ctg 2>/dev/null; then
        log "/mnt/ctg mounted (OK)"
        return 0
    fi
    if [[ -d /media/sf_ctg-backups ]]; then
        log "VirtualBox auto-mount at /media/sf_ctg-backups — symlink hint only"
        mkdir -p /mnt
        if [[ ! -e /mnt/ctg ]]; then
            ln -sf /media/sf_ctg-backups /mnt/ctg 2>/dev/null || true
            log "Linked /mnt/ctg -> /media/sf_ctg-backups"
        fi
        return 0
    fi
    if grep -q vboxsf /etc/fstab 2>/dev/null; then
        log "vboxsf in fstab — attempting mount -a"
        mount -a 2>/dev/null || true
    else
        log "ctg-backups not mounted — manual: sudo bash /mnt/ctg/ctg-mount-share.sh (or /media/sf_ctg-backups/ctg-mount-share.sh)"
    fi
}

scan_journal_boot_errors() {
    log "Phase: journalctl scan (last boot errors/failed)"
    local journal_tmp
    journal_tmp="$(mktemp)"
    {
        echo "--- systemctl --failed ---"
        systemctl --failed --no-legend 2>/dev/null || true
        echo "--- journalctl -b -p err..alert (last 80) ---"
        journalctl -b -p err..alert --no-pager -n 80 2>/dev/null || true
        echo "--- journalctl -b -u gdm3 -p warning..alert (last 40) ---"
        journalctl -b -u gdm3 -p warning..alert --no-pager -n 40 2>/dev/null || true
    } >"$journal_tmp"
    cat "$journal_tmp" >>"$LOG_FILE"
    if grep -qiE 'firmware|driver|module.*fail|nouveau|i915|realtek' "$journal_tmp"; then
        log "Driver/firmware errors detected in journal"
        echo "DRIVER_ERRORS=1" >>"$journal_tmp"
    fi
    rm -f "$journal_tmp"
}

safe_reset_failed_units() {
    log "Phase: systemctl failed units — safe reset/restart"
    local units=() unit base
    mapfile -t units < <(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' || true)
    if [[ ${#units[@]} -eq 0 ]]; then
        log "No failed systemd units"
        return 0
    fi
    local skip_re='^(dbus|systemd-|network|NetworkManager|ssh|sshd|gdm|gdm3|lightdm|display-manager|getty@|user@|session-|polkit|rsyslog|cron|tor)\.'
    for unit in "${units[@]}"; do
        [[ -z "$unit" ]] && continue
        base="${unit%%.service}"
        if [[ "$unit" =~ $skip_re ]]; then
            log "Skip restart (critical): $unit"
            continue
        fi
        log "Attempting restart: $unit"
        systemctl restart "$unit" 2>/dev/null || log "Restart failed for $unit (logged only)"
    done
    systemctl reset-failed 2>/dev/null || true
    log "systemctl reset-failed completed"
}

maybe_install_firmware() {
    if ! $DO_FIRMWARE; then
        if journalctl -b -p err..alert --no-pager 2>/dev/null | grep -qiE 'firmware|driver|module.*fail'; then
            log "Driver errors in journal — run with --firmware to install firmware-linux-nonfree"
        fi
        return 0
    fi
    log "Phase: firmware-linux-nonfree (--firmware)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends firmware-linux-nonfree 2>/dev/null || \
        log "firmware-linux-nonfree install skipped or unavailable"
}

run_optional_upgrade() {
    if ! $DO_UPGRADE; then
        log "Skipping apt full-upgrade (pass --upgrade to enable)"
        return 0
    fi
    log "Phase: apt update && apt full-upgrade -y"
    preserve_ddg_dns
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get full-upgrade -y
    preserve_ddg_dns
    if [[ -f /var/run/reboot-required ]]; then
        ctg_reboot_helper --mark
    fi
}

run_ids_ips_autorun() {
    log "Phase: ctg-ids-ips-autorun (--ids-ips)"
    local ids_script="$SCRIPT_DIR/ctg-ids-ips-autorun.sh"
    for candidate in /mnt/ctg/ctg-ids-ips-autorun.sh /opt/ctg/ctg-ids-ips-autorun.sh /media/sf_ctg-backups/ctg-ids-ips-autorun.sh; do
        if [[ -f "$candidate" ]]; then
            ids_script="$candidate"
            break
        fi
    done
    if [[ ! -f "$ids_script" ]]; then
        log "ctg-ids-ips-autorun.sh not found — skip IDS/IPS phase"
        return 0
    fi
    local ids_args=(--skip-snort)
    if $DO_IDS_OPTIMIZE; then
        ids_args+=(--optimize)
    fi
    if $DO_INSTALL; then
        ids_args+=(--install)
    fi
    bash "$ids_script" "${ids_args[@]}" || log "IDS/IPS autorun returned non-zero (continuing boot autopatch)"
}

run_siem_autorun() {
    log "Phase: ctg-siem-autorun (--siem)"
    local siem_script="$SCRIPT_DIR/ctg-siem-autorun.sh"
    for candidate in /mnt/ctg/ctg-siem-autorun.sh /opt/ctg/ctg-siem-autorun.sh /media/sf_ctg-backups/ctg-siem-autorun.sh; do
        if [[ -f "$candidate" ]]; then
            siem_script="$candidate"
            break
        fi
    done
    if [[ ! -f "$siem_script" ]]; then
        log "ctg-siem-autorun.sh not found — skip SIEM phase"
        return 0
    fi
    local siem_args=(--skip-wazuh)
    if $DO_INSTALL; then
        siem_args+=(--install)
    fi
    bash "$siem_script" "${siem_args[@]}" || log "SIEM autorun returned non-zero (continuing boot autopatch)"
}

run_retbleed_mitigation() {
    log "Phase: RETBleed mitigation (retbleed=$DO_RETBLEED upgrade=$DO_UPGRADE)"
    local rb_script="$SCRIPT_DIR/fix-retbleed-mitigation.sh"
    for candidate in /mnt/ctg/fix-retbleed-mitigation.sh /opt/ctg/fix-retbleed-mitigation.sh /media/sf_ctg-backups/fix-retbleed-mitigation.sh; do
        if [[ -f "$candidate" ]]; then
            rb_script="$candidate"
            break
        fi
    done
    if [[ ! -f "$rb_script" ]]; then
        log "fix-retbleed-mitigation.sh not found — skip RETBleed phase"
        return 0
    fi
    if $DO_RETBLEED || $DO_UPGRADE; then
        bash "$rb_script" --apply || log "RETBleed apply returned non-zero (continuing)"
    else
        bash "$rb_script" --diagnose-only || log "RETBleed diagnose returned non-zero (continuing)"
    fi
}

run_wifi_lab_autorun() {
    log "Phase: ctg-wifi-lab-autorun (--wifi-lab)"
    local wifi_script="$SCRIPT_DIR/ctg-wifi-lab-autorun.sh"
    for candidate in /mnt/ctg/ctg-wifi-lab-autorun.sh /opt/ctg/ctg-wifi-lab-autorun.sh /media/sf_ctg-backups/ctg-wifi-lab-autorun.sh; do
        if [[ -f "$candidate" ]]; then
            wifi_script="$candidate"
            break
        fi
    done
    if [[ ! -f "$wifi_script" ]]; then
        log "ctg-wifi-lab-autorun.sh not found — skip WiFi lab phase"
        return 0
    fi
    local wifi_args=()
    if [[ "${CTG_WIFI_MONITOR:-0}" == "1" ]]; then
        wifi_args+=(--monitor)
    fi
    if $DO_INSTALL; then
        wifi_args+=(--install)
    fi
    bash "$wifi_script" "${wifi_args[@]}" || log "WiFi lab autorun returned non-zero (continuing boot autopatch)"
}

install_systemd_unit() {
    log "Phase: install ${SERVICE_NAME}"
    local script_src="$SCRIPT_DIR/kali-boot-autopatch.sh"
    if [[ ! -f "$script_src" ]]; then
        for candidate in /mnt/ctg/kali-boot-autopatch.sh /media/sf_ctg-backups/kali-boot-autopatch.sh; do
            if [[ -f "$candidate" ]]; then
                script_src="$candidate"
                break
            fi
        done
    fi
    install -d -m 0755 /opt/ctg
    if [[ -f "$script_src" ]]; then
        install -m 0755 "$script_src" /opt/ctg/kali-boot-autopatch.sh
        log "Installed /opt/ctg/kali-boot-autopatch.sh"
    else
        log "WARNING: source script not found — unit will reference /opt/ctg/kali-boot-autopatch.sh"
    fi
    cat >"$UNIT_DEST" <<'UNITEOF'
[Unit]
Description=CTG Kali boot autopatch (VirtualBox/GNOME fixes)
After=network-online.target vboxadd-service.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/ctg/kali-boot-autopatch.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNITEOF
    chmod 644 "$UNIT_DEST"
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    log "Enabled ${SERVICE_NAME} — runs on every boot"
}

# --- main ---
preserve_ddg_dns
disable_broken_ctg_profiled
fix_virtualbox_guest_packages
fix_virtualbox_seamless_guest
if $DO_WIFI_LAB; then
    run_wifi_lab_autorun
fi
if $DO_IDS_IPS; then
    run_ids_ips_autorun
fi
if $DO_SIEM; then
    run_siem_autorun
fi
fix_gdm_wayland_blank_screen
ensure_ctg_backups_mount_hint
run_retbleed_mitigation
run_optional_upgrade
scan_journal_boot_errors
maybe_install_firmware
safe_reset_failed_units

if $DO_INSTALL; then
    install_systemd_unit
fi

date -Iseconds >"$MARKER"
log "=== CTG Kali boot autopatch complete ==="
if [[ "${CTG_SKIP_AUTO_REBOOT:-}" != "1" ]]; then
    ctg_reboot_helper --auto-reboot
fi
log "GUI scrambler (manual): python3 /opt/ctg/tor-http-scrambler/ctg-scrambler-gui.py"
log "One-shot lab: sudo bash /mnt/ctg/ctg-lab-autorun.sh"
log "Seamless (host): .\\scripts\\windows\\Start-KaliSeamless.ps1 — toggle Host+L after GNOME login"
