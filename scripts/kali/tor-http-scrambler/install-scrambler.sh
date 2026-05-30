#!/usr/bin/env bash
# Install CTG Tor/HTTP scrambler to /opt/ctg/tor-http-scrambler — authorized lab use only.
# Hacker Planet LLC · Philadelphia, PA
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="/opt/ctg/tor-http-scrambler"
DESKTOP_NAME="CTG .TOR/HTTP Scrambler"

log() { printf '[ctg-install-scrambler] %s\n' "$*"; }

log "Installing CTG Tor/HTTP scrambler (authorized defensive lab — Hacker Planet LLC)"
mkdir -p "$INSTALL_ROOT" /var/lib/ctg
install -m 755 "$SCRIPT_DIR/scrambler-daemon.sh" "$INSTALL_ROOT/"
install -m 755 "$SCRIPT_DIR/siem-hook.sh" "$INSTALL_ROOT/"
install -m 644 "$SCRIPT_DIR/site-rules.example" "$INSTALL_ROOT/"
if [[ ! -f "$INSTALL_ROOT/site-rules.conf" ]]; then
    install -m 600 "$SCRIPT_DIR/site-rules.example" "$INSTALL_ROOT/site-rules.conf"
fi
if [[ -f "$SCRIPT_DIR/ctg-scrambler-gui.py" ]]; then
    install -m 755 "$SCRIPT_DIR/ctg-scrambler-gui.py" "$INSTALL_ROOT/"
fi

echo "tor" >/var/lib/ctg/scrambler-mode
chmod 644 /var/lib/ctg/scrambler-mode

# Desktop entry for lab user
for u in kali sal; do
    if id "$u" &>/dev/null; then
        home="$(getent passwd "$u" | cut -d: -f6)"
        desk="$home/Desktop"
        mkdir -p "$desk"
        cat >"$desk/${DESKTOP_NAME}.desktop" <<DESK
[Desktop Entry]
Name=${DESKTOP_NAME}
Comment=CTG lab Tor/HTTP mode toggle (authorized use only)
Exec=python3 ${INSTALL_ROOT}/ctg-scrambler-gui.py
Icon=network-vpn
Terminal=false
Type=Application
Categories=Network;Security;
DESK
        chown "$u:$u" "$desk/${DESKTOP_NAME}.desktop" 2>/dev/null || true
        chmod 755 "$desk/${DESKTOP_NAME}.desktop"
        log "Desktop entry: $desk/${DESKTOP_NAME}.desktop"
    fi
done

# Do NOT hook login shells (profile.d read prompts can blank GNOME in VirtualBox).
# Remove legacy autostart if upgrading an existing lab VM.
if [[ -f /etc/profile.d/ctg-scrambler-autostart.sh ]]; then
    mv -f /etc/profile.d/ctg-scrambler-autostart.sh \
        "/etc/profile.d/ctg-scrambler-autostart.sh.disabled-$(date +%Y%m%d)" 2>/dev/null || true
    log "Disabled legacy /etc/profile.d/ctg-scrambler-autostart.sh (use GUI/desktop entry only)"
fi

log "Installed to $INSTALL_ROOT"
log "Daemon (manual): sudo $INSTALL_ROOT/scrambler-daemon.sh start"
log "GUI (manual):    python3 $INSTALL_ROOT/ctg-scrambler-gui.py"
log "Desktop:         CTG .TOR/HTTP Scrambler"
log "SIEM:  sudo $INSTALL_ROOT/siem-hook.sh"
