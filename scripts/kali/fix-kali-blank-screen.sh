#!/usr/bin/env bash
# CTG Kali blank-screen recovery — run from TTY (Ctrl+Alt+F2) as root or with sudo.
# Authorized lab use only (Hacker Planet LLC).
# Fixes: Guest Additions X11, force X11 in GDM, disable CTG login hooks, restart display manager.
set -euo pipefail

log() { printf '[ctg-fix-blank] %s\n' "$*"; }

if [[ "$(id -u)" -ne 0 ]]; then
    log 'Re-run with: sudo bash fix-kali-blank-screen.sh'
    exit 1
fi

log '=== CTG Kali blank-screen fix ==='

log 'Phase 1: disable CTG login-shell hooks (profile.d can hang GNOME in VirtualBox)'
for f in /etc/profile.d/ctg-scrambler-autostart.sh /etc/profile.d/ctg-lab-autorun.sh; do
    if [[ -f "$f" ]]; then
        mv -f "$f" "${f}.disabled-$(date +%Y%m%d)"
        log "Disabled: $f"
    fi
done
mkdir -p /etc/ctg
touch /etc/ctg/scrambler-manual-only
chmod 644 /etc/ctg/scrambler-manual-only

log 'Phase 2: VirtualBox guest packages (X11 + utils)'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    virtualbox-guest-x11 virtualbox-guest-utils \
    build-essential dkms linux-headers-"$(uname -r)" 2>/dev/null || \
    apt-get install -y --no-install-recommends virtualbox-guest-x11 virtualbox-guest-utils

log 'Phase 3: force X11 in GDM (Wayland often blanks in VirtualBox GNOME)'
install -d -m 0755 /etc/gdm3
GDM_CUSTOM=/etc/gdm3/custom.conf
if [[ -f "$GDM_CUSTOM" ]]; then
    if grep -q '^WaylandEnable=' "$GDM_CUSTOM"; then
        sed -i 's/^WaylandEnable=.*/WaylandEnable=false/' "$GDM_CUSTOM"
    elif grep -q '^\[daemon\]' "$GDM_CUSTOM"; then
        sed -i '/^\[daemon\]/a WaylandEnable=false' "$GDM_CUSTOM"
    else
        printf '\n[daemon]\nWaylandEnable=false\n' >>"$GDM_CUSTOM"
    fi
else
    cat >"$GDM_CUSTOM" <<'EOF'
[daemon]
WaylandEnable=false
EOF
fi
chmod 644 "$GDM_CUSTOM"
log "GDM: WaylandEnable=false in $GDM_CUSTOM"

log 'Phase 4: optional — reinstall Guest Additions from mounted ISO (if host CD attached)'
if mountpoint -q /media/cdrom 2>/dev/null && [[ -x /media/cdrom/VBoxLinuxAdditions.run ]]; then
    log 'Running VBoxLinuxAdditions.run from /media/cdrom'
    sh /media/cdrom/VBoxLinuxAdditions.run --nox11 || true
fi

log 'Phase 5: restart display manager'
if systemctl is-active --quiet gdm3 2>/dev/null; then
    systemctl restart gdm3
    log 'Restarted gdm3'
elif systemctl is-active --quiet gdm 2>/dev/null; then
    systemctl restart gdm
    log 'Restarted gdm'
elif systemctl is-active --quiet lightdm 2>/dev/null; then
    systemctl restart lightdm
    log 'Restarted lightdm'
else
    log 'No gdm3/gdm/lightdm active — reboot recommended: sudo reboot'
fi

log '=== Done ==='
log 'After login: GUI manually — python3 /opt/ctg/tor-http-scrambler/ctg-scrambler-gui.py'
log 'Or desktop: CTG .TOR/HTTP Scrambler'
log 'Re-enable CTG hooks only after stable desktop (not recommended in VB): remove *.disabled-* under /etc/profile.d/'
