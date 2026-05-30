#!/usr/bin/env bash
# CTG SIEM hook — tail Snort/Suricata/syslog; on high severity prompt shield rotate (v1 y/n).
# Also prompts local CTG SIEM scratch log compression (not silent WAN auto-rotate).
# Authorized defensive lab use only — Hacker Planet LLC.
set -euo pipefail

CTG_ROOT="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
SHIELD="${CTG_SHIELD_SCRIPT:-$CTG_ROOT/ctg-shield-rotate.sh}"
LOG_DIR="${CTG_SIEM_LOG_DIR:-/var/log/ctg-siem}"
ROTATE_MARKER="$LOG_DIR/.last-rotate-prompt"
TAIL_LINES="${CTG_SIEM_TAIL:-20}"
HIGH_SEV_FILE="$LOG_DIR/.last-high-severity"

mkdir -p "$LOG_DIR" 2>/dev/null || true

log() { printf '[ctg-siem] %s\n' "$*"; }

sources() {
    local f
    for f in \
        /var/log/snort/snort.log \
        /var/log/snort/alert \
        /var/log/suricata/fast.log \
        /var/log/suricata/eve.json \
        /var/log/ctg-siem/alerts.log \
        /var/log/syslog \
        /var/log/messages; do
        [[ -f "$f" ]] && echo "$f"
    done
}

collect_tail() {
    local buf=""
    while IFS= read -r src; do
        buf+=$(tail -n "$TAIL_LINES" "$src" 2>/dev/null || true)
        buf+=$'\n'
    done < <(sources)
    printf '%s' "$buf"
}

show_alerts() {
    log "=== Last $TAIL_LINES IDS/syslog lines (lab — prompt before shield rotate) ==="
    local found=false
    while IFS= read -r src; do
        found=true
        log "--- $src ---"
        tail -n "$TAIL_LINES" "$src" 2>/dev/null || true
    done < <(sources)
    if ! $found; then
        log "No Snort/Suricata/syslog files yet — install passive IDS via kali-lab-bootstrap.sh"
    fi
}

detect_high_severity() {
    local data="$1"
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ [Pp]riority:\ *[01][^0-9] ]] \
            || [[ "$line" =~ [Ss]everity:\ *(1|2|critical|high) ]] \
            || [[ "$line" =~ \[1: ]] \
            || [[ "$line" =~ (CRITICAL|HIGH|ALERT) ]] \
            || [[ "$line" =~ snort.*\[1: ]] \
            || [[ "$line" =~ suricata.*\"severity\":\ *(1|2) ]]; then
            printf '%s\n' "$line"
            return 0
        fi
    done <<<"$data"
    return 1
}

prompt_shield_rotate() {
    local hit="$1"
    local ans
    if [[ ! -x "$SHIELD" ]]; then
        log "Shield script missing: $SHIELD — run install-scrambler.sh"
        return 1
    fi
    log "HIGH severity IDS line detected:"
    log "$hit"
    printf '%s\n' "$hit" >"$HIGH_SEV_FILE"
    "$SHIELD" record-alert "$hit" 2>/dev/null || true
    log "Rotate lab USB wlan IP/MAC via CTG Shield? [y/N] (v1 — manual confirm; not for production banking without approval)"
    read -r -t 60 ans || ans="n"
    case "${ans,,}" in
        y|yes)
            log "Operator confirmed — running CTG Shield rotate"
            "$SHIELD" rotate
            ;;
        *)
            log "Shield rotate skipped by operator"
            ;;
    esac
}

prompt_log_rotate() {
    local ans
    log "Compress local CTG SIEM scratch logs older than 24h? [y/N]"
    read -r -t 45 ans || ans="n"
    case "${ans,,}" in
        y|yes)
            find "$LOG_DIR" -maxdepth 1 -name '*.log' -mtime +0 -exec gzip -f {} \; 2>/dev/null || true
            date -Iseconds >"$ROTATE_MARKER"
            log "SIEM scratch log rotate acknowledged — marker $ROTATE_MARKER"
            ;;
        *)
            log "SIEM scratch log rotate skipped"
            ;;
    esac
}

main() {
    local blob hit
    show_alerts
    blob="$(collect_tail)"
    if hit="$(detect_high_severity "$blob")"; then
        prompt_shield_rotate "$hit"
    else
        log "No high-severity line in last $TAIL_LINES rows — shield rotate not offered"
    fi
    prompt_log_rotate
}

main "$@"
