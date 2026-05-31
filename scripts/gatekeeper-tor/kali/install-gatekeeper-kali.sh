#!/usr/bin/env bash
# Install Gatekeeper.TOR on Kali — tray autostart, torrc, daemon, scrambler bridge.
# Authorized defensive lab use only · Hacker Planet LLC
set -euo pipefail

DIAGNOSE_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --diagnose-only|-DiagnoseOnly) DIAGNOSE_ONLY=1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GK_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ASSETS="$(cd "$GK_SRC/../.." && pwd)/assets/gatekeeper-tor"
INSTALL_ROOT="/opt/ctg/gatekeeper-tor"
CORE_DEST="/opt/ctg/core"

log() { printf '[install-gatekeeper-kali] %s\n' "$*"; }

diag() {
    log "=== Gatekeeper.TOR diagnose ==="
    log "Source: $GK_SRC"
    for f in gatekeeper-daemon.sh templates/gatekeeper.conf kali/gatekeeper-tray.py; do
        if [[ -f "$GK_SRC/$f" ]]; then
            log "  OK $f"
        else
            log "  MISSING $f"
        fi
    done
    if [[ -f "$REPO_ASSETS/logo-tor-on.png" ]]; then
        log "  OK assets/logo-tor-on.png (lit)"
    elif [[ -f "$REPO_ASSETS/logo.svg" ]]; then
        log "  OK assets/logo.svg"
    else
        log "  MISSING lit PNGs — run generate_gatekeeper_icons.py"
    fi
    if command -v tor >/dev/null; then
        log "  tor binary: $(command -v tor)"
    else
        log "  tor: not installed (apt install tor)"
    fi
    if [[ -x "$INSTALL_ROOT/gatekeeper-daemon.sh" ]]; then
        "$INSTALL_ROOT/gatekeeper-daemon.sh" status || true
    else
        log "  not installed under $INSTALL_ROOT"
    fi
    exit 0
}

if [[ "$DIAGNOSE_ONLY" -eq 1 ]]; then
    diag
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

log "Installing Gatekeeper.TOR (authorized lab — preserves DDG on Windows hosts)"
mkdir -p "$INSTALL_ROOT/templates" "$CORE_DEST" /var/lib/ctg/gatekeeper-tor

install -m 755 "$GK_SRC/gatekeeper-daemon.sh" "$INSTALL_ROOT/"
install -m 644 "$GK_SRC/templates/gatekeeper.conf" "$INSTALL_ROOT/templates/"
install -m 755 "$GK_SRC/kali/gatekeeper-tray.py" "$INSTALL_ROOT/"

for py in "$GK_SRC/../../core/gatekeeper_tor.py" "$GK_SRC/core/gatekeeper_tor.py"; do
    if [[ -f "$py" ]]; then
        install -m 644 "$py" "$CORE_DEST/gatekeeper_tor.py"
        break
    fi
done

ASSETS_DEST="$INSTALL_ROOT/assets"
mkdir -p "$ASSETS_DEST"
for asset_dir in "$REPO_ASSETS" "$GK_SRC/assets" "$GK_SRC/../assets/gatekeeper-tor"; do
    if [[ -d "$asset_dir" ]]; then
        cp -a "$asset_dir/." "$ASSETS_DEST/" 2>/dev/null || true
        break
    fi
done

if [[ -f "$ASSETS_DEST/logo-tor-on.png" ]]; then
    TRAY_ICON="$ASSETS_DEST/logo-tor-on.png"
elif [[ -f "$REPO_ASSETS/logo.svg" ]]; then
    TRAY_ICON="$INSTALL_ROOT/logo.svg"
    install -m 644 "$REPO_ASSETS/logo.svg" "$INSTALL_ROOT/logo.svg"
else
    TRAY_ICON="$INSTALL_ROOT/logo.svg"
fi

# Bridge scrambler if present on share
SCRAMBLER_INSTALL="/opt/ctg/tor-http-scrambler/install-scrambler.sh"
if [[ -f "$GK_SRC/../../kali/tor-http-scrambler/install-scrambler.sh" ]]; then
    bash "$GK_SRC/../../kali/tor-http-scrambler/install-scrambler.sh" || true
elif [[ -x "$SCRAMBLER_INSTALL" ]]; then
    log "Scrambler already at $SCRAMBLER_INSTALL"
fi

export CTG_GATEKEEPER_ROOT="$INSTALL_ROOT"
"$INSTALL_ROOT/gatekeeper-daemon.sh" install-torrc
"$INSTALL_ROOT/gatekeeper-daemon.sh" start

# Xfce autostart + systray (user must pin icon to panel if desired)
for u in kali sal; do
    if ! id "$u" &>/dev/null; then
        continue
    fi
    home="$(getent passwd "$u" | cut -d: -f6)"
    autostart="$home/.config/autostart"
    mkdir -p "$autostart"
    cat >"$autostart/gatekeeper-tor-tray.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Gatekeeper.TOR
Comment=CTG Tor/HTTPS mode tray (authorized lab)
Exec=/usr/bin/env python3 ${INSTALL_ROOT}/gatekeeper-tray.py
Icon=${TRAY_ICON:-${INSTALL_ROOT}/assets/logo-tor-on.png}
Terminal=false
Categories=Network;Security;
X-GNOME-Autostart-enabled=true
DESK
    chown -R "$u:$u" "$home/.config/autostart" 2>/dev/null || true
    log "Autostart: $autostart/gatekeeper-tor-tray.desktop (pin to Xfce panel systray manually)"
done

log "Installed $INSTALL_ROOT"
log "Tray: python3 $INSTALL_ROOT/gatekeeper-tray.py"
log "Daemon: sudo $INSTALL_ROOT/gatekeeper-daemon.sh status"
log "Optional deps: apt install -y tor python3-pil python3-pystray"
