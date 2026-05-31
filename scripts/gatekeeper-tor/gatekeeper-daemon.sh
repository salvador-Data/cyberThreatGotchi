#!/usr/bin/env bash
# Gatekeeper.TOR daemon — wraps scrambler-daemon; safest client Tor config.
# Authorized defensive lab use only · Hacker Planet LLC · CyberThreatGotchi
set -euo pipefail

GK_ROOT="${CTG_GATEKEEPER_ROOT:-/opt/ctg/gatekeeper-tor}"
SCRAMBLER="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
SCRAMBLER_DAEMON="${SCRAMBLER}/scrambler-daemon.sh"
MODE_FILE="${CTG_GATEKEEPER_MODE_FILE:-/var/lib/ctg/gatekeeper-mode}"
LOG_FILE="/var/log/ctg-gatekeeper.log"
TORRC_SNIPPET="/etc/tor/torrc.d/gatekeeper.conf"
DEFAULT_MODE="tor"

log() { printf '[gatekeeper-tor] %s\n' "$*" | tee -a "$LOG_FILE" 2>/dev/null || printf '[gatekeeper-tor] %s\n' "$*"; }

ensure_dirs() {
    mkdir -p "$(dirname "$MODE_FILE")" /var/lib/ctg/gatekeeper-tor 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/ctg-gatekeeper.log"
}

current_mode() {
    if [[ -f "$MODE_FILE" ]]; then
        cat "$MODE_FILE"
    else
        echo "$DEFAULT_MODE"
    fi
}

normalize_mode() {
    case "${1,,}" in
        tor) echo tor ;;
        https|http|clearnet) echo https ;;
        *) return 1 ;;
    esac
}

scrambler_alias() {
    case "$(current_mode)" in
        https) echo http ;;
        *) echo tor ;;
    esac
}

set_mode() {
    local m
    m="$(normalize_mode "${1:-}")" || { echo "Invalid mode: $1 (use tor|https)" >&2; return 1; }
    ensure_dirs
    echo "$m" >"$MODE_FILE"
    log "Gatekeeper mode: $m"
    if [[ -x "$SCRAMBLER_DAEMON" ]]; then
        "$SCRAMBLER_DAEMON" set-mode "$(scrambler_alias)" || true
    fi
    case "$m" in
        tor) apply_tor_service ;;
        https) apply_https_hint ;;
    esac
}

apply_tor_service() {
    if command -v systemctl >/dev/null; then
        systemctl start tor 2>/dev/null || true
        systemctl enable tor 2>/dev/null || true
    fi
    if [[ -f "$TORRC_SNIPPET" ]]; then
        log "Tor client config: $TORRC_SNIPPET (client-only ExitPolicy reject *:*)"
    fi
    log "Tor SOCKS 127.0.0.1:9050 — browser/lab apps opt-in; not a system VPN"
}

apply_https_hint() {
    log "HTTPS mode: clearnet for authorized lab targets only"
    log "Health probe uses TLS 1.3 preference (Gatekeeper curl check — not system-wide)"
    log "Do NOT use for unauthorized scanning, credential attacks, or illegal evasion"
}

apply_torrc_template() {
    local src="${GK_ROOT}/templates/gatekeeper.conf"
    if [[ ! -f "$src" ]]; then
        src="$(dirname "$0")/templates/gatekeeper.conf"
    fi
    if [[ ! -f "$src" ]]; then
        log "gatekeeper.conf template missing — skip torrc install"
        return 0
    fi
    mkdir -p /etc/tor/torrc.d
    install -m 644 "$src" "$TORRC_SNIPPET"
    log "Installed $TORRC_SNIPPET"
}

run_python_health() {
    local py="${CTG_GATEKEEPER_PYTHON:-python3}"
    local mod=""
    for candidate in \
        "/opt/ctg/core/gatekeeper_tor.py" \
        "$(dirname "$0")/../../core/gatekeeper_tor.py"; do
        if [[ -f "$candidate" ]]; then
            mod="$candidate"
            break
        fi
    done
    if [[ -z "$mod" ]]; then
        echo "gatekeeper_tor.py not found"
        return 1
    fi
    "$py" "$mod" health "$(current_mode)" 2>/dev/null || true
}

cmd="${1:-status}"
case "$cmd" in
    install-torrc) apply_torrc_template ;;
    start)
        ensure_dirs
        apply_torrc_template
        apply_tor_service
        if [[ -x "$SCRAMBLER_DAEMON" ]]; then
            "$SCRAMBLER_DAEMON" set-mode "$(scrambler_alias)" || true
        fi
        log "Gatekeeper started mode=$(current_mode)"
        ;;
    stop)
        log "Gatekeeper stop (Tor service left running for other lab tools)"
        ;;
    status)
        echo "mode=$(current_mode)"
        echo "scrambler=$(scrambler_alias)"
        if command -v systemctl >/dev/null; then
            echo "tor_service=$(systemctl is-active tor 2>/dev/null || echo unknown)"
        fi
        ;;
    set-mode)
        set_mode "${2:-tor}"
        ;;
    health)
        run_python_health
        ;;
    *)
        echo "Usage: $0 {start|stop|status|set-mode tor|https|install-torrc|health}" >&2
        exit 1
        ;;
esac
