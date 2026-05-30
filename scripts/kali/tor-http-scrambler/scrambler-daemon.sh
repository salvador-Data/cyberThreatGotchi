#!/usr/bin/env bash
# CTG Tor/HTTP scrambler daemon — authorized defensive lab use only.
# Hacker Planet LLC · Philadelphia, PA · https://github.com/salvador-Data/cyberThreatGotchi
#
# Modes: tor (default, browser-only Tor path), http (clearnet proxy off Tor), auto (site-rules).
# Does NOT bypass law enforcement, illegal reg domains, or attack third parties.
set -euo pipefail

CTG_ROOT="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
RULES="${CTG_SITE_RULES:-$CTG_ROOT/site-rules.conf}"
MODE_FILE="${CTG_SCRAMBLER_MODE_FILE:-/var/lib/ctg/scrambler-mode}"
PID_FILE="/var/run/ctg-scrambler.pid"
LOG_FILE="/var/log/ctg-scrambler.log"
DEFAULT_MODE="tor"

log() { printf '[ctg-scrambler] %s\n' "$*" | tee -a "$LOG_FILE" 2>/dev/null || printf '[ctg-scrambler] %s\n' "$*"; }

ensure_dirs() {
    mkdir -p "$(dirname "$MODE_FILE")" "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/ctg-scrambler.log"
}

current_mode() {
    if [[ -f "$MODE_FILE" ]]; then
        cat "$MODE_FILE"
    else
        echo "$DEFAULT_MODE"
    fi
}

set_mode() {
    local m="$1"
    case "$m" in
        tor|http|auto) ;;
        *) echo "Invalid mode: $m (use tor|http|auto)" >&2; return 1 ;;
    esac
    ensure_dirs
    echo "$m" >"$MODE_FILE"
    log "Mode set: $m"
}

lookup_site_mode() {
    local host="$1"
    local mode
    mode="$(current_mode)"
    if [[ "$mode" != "auto" ]]; then
        echo "$mode"
        return
    fi
    if [[ ! -f "$RULES" ]]; then
        echo "tor"
        return
    fi
    while read -r pattern rule _; do
        [[ -z "${pattern:-}" || "$pattern" =~ ^# ]] && continue
        if [[ "$host" == *"$pattern"* ]]; then
            echo "${rule:-tor}"
            return
        fi
    done <"$RULES"
    echo "tor"
}

prompt_glitch_domain() {
    local host="$1"
    local ans
    log "Glitch/unusual domain detected: $host — route via HTTP clearnet? [y/N]"
    read -r -t 30 ans || ans="n"
    case "${ans,,}" in
        y|yes) echo "http" ;;
        *) echo "tor" ;;
    esac
}

apply_tor_service() {
    if command -v systemctl >/dev/null; then
        systemctl start tor 2>/dev/null || true
        systemctl enable tor 2>/dev/null || true
    fi
    log "Tor SOCKS expected at 127.0.0.1:9050 (browser-only default; use Tor Browser for sensitive sites)"
}

apply_http_hint() {
    log "HTTP mode: use lab browser without Tor — only for site-rules / authorized clearnet lab targets"
    log "Do NOT use for unauthorized third-party scanning or credential attacks"
}

daemon_loop() {
    ensure_dirs
    apply_tor_service
    local mode
    mode="$(current_mode)"
    log "Daemon started — mode=$mode rules=$RULES"
    while true; do
        mode="$(current_mode)"
        case "$mode" in
            tor) apply_tor_service ;;
            http) apply_http_hint ;;
            auto)
                apply_tor_service
                log "auto: site-rules active ($(wc -l <"$RULES" 2>/dev/null || echo 0) lines)"
                ;;
        esac
        sleep 60
    done
}

cmd="${1:-status}"
case "$cmd" in
    start)
        ensure_dirs
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log "Already running (pid $(cat "$PID_FILE"))"
            exit 0
        fi
        daemon_loop &
        echo $! >"$PID_FILE"
        log "Started pid $(cat "$PID_FILE")"
        ;;
    stop)
        if [[ -f "$PID_FILE" ]]; then
            kill "$(cat "$PID_FILE")" 2>/dev/null || true
            rm -f "$PID_FILE"
            log "Stopped"
        else
            log "Not running"
        fi
        ;;
    status)
        echo "mode=$(current_mode)"
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "running pid=$(cat "$PID_FILE")"
        else
            echo "running=no"
        fi
        ;;
    set-mode)
        set_mode "${2:-tor}"
        ;;
    resolve)
        host="${2:-}"
        if [[ -z "$host" ]]; then echo "usage: $0 resolve <host>" >&2; exit 1; fi
        if [[ "$host" =~ glitch|unknown|\.local$ ]]; then
            prompt_glitch_domain "$host"
        else
            lookup_site_mode "$host"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status|set-mode tor|http|auto|resolve <host>}" >&2
        exit 1
        ;;
esac
