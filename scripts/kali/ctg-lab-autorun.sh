#!/usr/bin/env bash
# CTG Lab one-shot autorun (in-guest) — authorized defensive use only.
# Hacker Planet LLC · Philadelphia, PA
#
# Runs bootstrap if not complete, starts tor + scrambler daemon, prints GUI command.
set -euo pipefail

MARKER="/var/lib/ctg/kali-bootstrap.done"
BOOTSTRAP="/mnt/ctg/kali-lab-bootstrap.sh"
REPO_BOOT="$(dirname "$0")/kali-lab-bootstrap.sh"
AUTOPATCH="/mnt/ctg/kali-boot-autopatch.sh"
REPO_AUTOPATCH="$(dirname "$0")/kali-boot-autopatch.sh"
SCRAMBLER_INSTALL="/mnt/ctg/tor-http-scrambler/install-scrambler.sh"
AUTORUN_WIFI="${CTG_WIFI_PROFILE:-company-lab}"

log() { printf '[ctg-lab-autorun] %s\n' "$*"; }

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

mkdir -p /var/lib/ctg /mnt/ctg 2>/dev/null || true

if [[ ! -f "$AUTOPATCH" && -f "$REPO_AUTOPATCH" ]]; then
    AUTOPATCH="$REPO_AUTOPATCH"
fi
if [[ -f "$AUTOPATCH" ]]; then
    log "Running boot autopatch: $AUTOPATCH"
    bash "$AUTOPATCH" || log "Autopatch returned non-zero (continuing lab autorun)"
else
    log "Autopatch script not found (optional) — mount ctg-backups share for kali-boot-autopatch.sh"
fi

if [[ ! -f "$BOOTSTRAP" && -f "$REPO_BOOT" ]]; then
    BOOTSTRAP="$REPO_BOOT"
fi
if [[ ! -f "$BOOTSTRAP" && -f /tmp/kali-lab-bootstrap.sh ]]; then
    BOOTSTRAP="/tmp/kali-lab-bootstrap.sh"
fi

if [[ ! -f "$MARKER" ]]; then
    if [[ -f "$BOOTSTRAP" ]]; then
        log "Bootstrap not complete — running $BOOTSTRAP"
        bash "$BOOTSTRAP" \
            --wifi-profile="$AUTORUN_WIFI" \
            --preserve-ddg-dns \
            --lab-anonymity \
            --install-scrambler
        date -Iseconds >"$MARKER"
        log "Bootstrap marked complete: $MARKER"
    else
        log "BLOCKED: kali-lab-bootstrap.sh not found (mount ctg share: sudo mount -t vboxsf ctg /mnt/ctg)"
        exit 2
    fi
else
    log "Bootstrap already done ($MARKER) — skipping full bootstrap"
    if [[ -x /opt/ctg/tor-http-scrambler/scrambler-daemon.sh ]]; then
        /opt/ctg/tor-http-scrambler/scrambler-daemon.sh start || true
    elif [[ -f "$SCRAMBLER_INSTALL" ]]; then
        bash "$SCRAMBLER_INSTALL"
        /opt/ctg/tor-http-scrambler/scrambler-daemon.sh start || true
    fi
fi

log "Starting tor service"
systemctl enable tor 2>/dev/null || true
systemctl start tor 2>/dev/null || true

if [[ -x /opt/ctg/tor-http-scrambler/scrambler-daemon.sh ]]; then
    /opt/ctg/tor-http-scrambler/scrambler-daemon.sh start || true
    log "Scrambler mode: $(/opt/ctg/tor-http-scrambler/scrambler-daemon.sh status 2>/dev/null || echo unknown)"
fi

log "=== CTG Lab autorun complete ==="
log "GUI:  python3 /opt/ctg/tor-http-scrambler/ctg-scrambler-gui.py"
log "      (or desktop: CTG .TOR/HTTP Scrambler)"
log "SIEM: sudo /opt/ctg/tor-http-scrambler/siem-hook.sh"
log "Shield: sudo /opt/ctg/tor-http-scrambler/ctg-shield-rotate.sh status"
log "Tor Browser: launch manually (torbrowser-launcher) — browser-only Tor default"
log "Targets: /etc/ctg/lab-targets.conf (from lab-targets.example)"
log "DDG preserve: --preserve-ddg-dns ON by default — see docs/IPHONE_HARDENING.md"
