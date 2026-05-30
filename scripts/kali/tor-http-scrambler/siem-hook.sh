#!/usr/bin/env bash
# CTG SIEM hook — tail Snort/syslog and prompt log rotate (v1: y/n, not silent WAN auto).
# Authorized defensive lab use only — Hacker Planet LLC.
set -euo pipefail

CTG_ROOT="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
LOG_DIR="${CTG_SIEM_LOG_DIR:-/var/log/ctg-siem}"
ROTATE_MARKER="$LOG_DIR/.last-rotate-prompt"
TAIL_LINES="${CTG_SIEM_TAIL:-20}"

mkdir -p "$LOG_DIR" 2>/dev/null || true

log() { printf '[ctg-siem] %s\n' "$*"; }

sources() {
    local f
    for f in /var/log/snort/snort.log /var/log/snort/alert /var/log/syslog /var/log/messages; do
        [[ -f "$f" ]] && echo "$f"
    done
}

show_alerts() {
    log "=== Last $TAIL_LINES IDS/syslog lines (lab WAN — prompt before rotate) ==="
    local found=false
    while IFS= read -r src; do
        found=true
        log "--- $src ---"
        tail -n "$TAIL_LINES" "$src" 2>/dev/null || true
    done < <(sources)
    if ! $found; then
        log "No Snort/syslog files yet — install passive Snort via kali-lab-bootstrap.sh"
    fi
}

prompt_rotate() {
    local ans
    log "Rotate/compress local CTG SIEM scratch logs? [y/N] (v1: manual confirm — no silent auto on WAN)"
    read -r -t 45 ans || ans="n"
    case "${ans,,}" in
        y|yes)
            find "$LOG_DIR" -maxdepth 1 -name '*.log' -mtime +0 -exec gzip -f {} \; 2>/dev/null || true
            date -Iseconds >"$ROTATE_MARKER"
            log "Rotate acknowledged — marker $ROTATE_MARKER"
            ;;
        *)
            log "Rotate skipped"
            ;;
    esac
}

show_alerts
prompt_rotate
