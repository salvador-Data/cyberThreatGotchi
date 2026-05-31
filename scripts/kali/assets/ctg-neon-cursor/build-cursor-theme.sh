#!/usr/bin/env bash
# Build CTG-Neon-Lemon Xcursor theme from PNG sources (authorized lab only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="CTG-Neon-Lemon"
INSTALL_ROOT="${1:-/opt/ctg/cursors/${THEME_NAME}}"

log() { printf '[ctg-neon-cursor] %s\n' "$*"; }

if ! command -v xcursorgen >/dev/null 2>&1; then
    log "Installing x11-apps (xcursorgen)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends x11-apps python3-pil 2>/dev/null || \
        apt-get install -y --no-install-recommends x11-apps
fi

PNG_DIR="${SCRIPT_DIR}/png"
if [[ ! -f "${PNG_DIR}/left_ptr-32.png" ]]; then
    log "Generating PNG sources..."
    python3 "${SCRIPT_DIR}/gen-neon-cursor-png.py"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "${WORK}/cursors"

cfg="${WORK}/left_ptr.cfg"
: >"$cfg"
for size in 24 32 48 56 64; do
    png="${PNG_DIR}/left_ptr-${size}.png"
    [[ -f "$png" ]] || { log "Missing $png"; exit 1; }
    hotspot=$((size / 2))
    printf '%s %s %s %s left_ptr-%s.png\n' "$size" "$hotspot" "$hotspot" "$size" "$size" >>"$cfg"
    cp "$png" "${WORK}/left_ptr-${size}.png"
done
xcursorgen "$cfg" "${WORK}/cursors/left_ptr"

# Symlink common cursor names to left_ptr (minimal theme)
for name in default pointer hand1 hand2 ibeam xterm right_ptr; do
    ln -sf left_ptr "${WORK}/cursors/${name}"
done

install -d -m 0755 "${INSTALL_ROOT}/cursors"
cp -a "${WORK}/cursors/"* "${INSTALL_ROOT}/cursors/"
install -m 0644 "${SCRIPT_DIR}/index.theme" "${INSTALL_ROOT}/index.theme"
log "Installed ${THEME_NAME} -> ${INSTALL_ROOT}"
printf '%s\n' "${INSTALL_ROOT}"
