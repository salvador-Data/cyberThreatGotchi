#!/usr/bin/env bash
# CTG Kali - poll vboxsf share for Windows host trigger files (no SSH/password).
# Hacker Planet LLC - authorized lab use only.
#
# Windows (no guest password):
#   New-Item C:\Users\Owner\Backups\CTG_RUN_AUTORUN_NOW -ItemType File -Force
#   (legacy: CTG_TRIGGER_AUTORUN still polled)
#
# Guest must be logged into Xfce (vboxsf readable at /media/sf_ctg-backups).
set -uo pipefail

POLL_SEC="${CTG_TRIGGER_POLL_SEC:-8}"
MAX_LOOPS="${CTG_TRIGGER_MAX_LOOPS:-0}"
LOG_FILE="/var/log/ctg-watch-trigger.log"
TRIGGER_NAMES=(CTG_TRIGGER_NMAP_INSTALL CTG_TRIGGER_AUTORUN CTG_RUN_AUTORUN_NOW)

log() {
    local msg="[$(date -Iseconds)] [ctg-watch-trigger] $*"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >>"$LOG_FILE" 2>/dev/null || true
}

find_share_root() {
    local d
    for d in /media/sf_ctg-backups /media/sf_ctg /mnt/ctg; do
        if [[ -d "$d" && ( -f "$d/ctg-first-login-autorun.sh" || -f "$d/kali-boot-autopatch.sh" ) ]]; then
            printf '%s\n' "$d"
            return 0
        fi
    done
    return 1
}

find_trigger() {
    local root="$1" name path
    for name in "${TRIGGER_NAMES[@]}"; do
        path="$root/$name"
        if [[ -f "$path" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
    done
    return 1
}

remove_trigger() {
    local path="$1"
    if rm -f "$path" 2>/dev/null; then
        log "Removed trigger: $path"
        return 0
    fi
    log "Could not remove trigger (read-only share?): $path"
    return 1
}


run_nmap_install_trigger() {
    local root="$1"
    local helper="$root/ctg-nmap-ask-install-trigger.sh"
    if [[ ! -f "$helper" ]]; then
        log "Missing $helper - re-stage: Stage-KaliLabToBackups.ps1"
        return 1
    fi
    log "Running ctg-nmap-ask-install-trigger.sh (CTG_TRIGGER_NMAP_INSTALL)"
    bash "$helper"
}



run_minimal_share_trigger() {
    local root="$1"
    local helper="$root/ctg-run-on-share-trigger.sh"
    if [[ ! -f "$helper" ]]; then
        log "Missing $helper"
        return 1
    fi
    log "Running ctg-run-on-share-trigger.sh (CTG_RUN_AUTORUN_NOW)"
    bash "$helper"
}

run_autorun_chain() {
    local root="$1"
    local autorun="$root/ctg-first-login-autorun.sh"
    if [[ ! -f "$autorun" ]]; then
        log "Missing $autorun - re-stage on Windows: Stage-KaliLabToBackups.ps1"
        return 1
    fi
    log "Running ctg-first-login-autorun.sh (triggered from share)"
    CTG_FORCE_AUTORUN=1 bash "$autorun"
}

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

share="$(find_share_root)" || {
    log "Share not visible yet - waiting for /media/sf_ctg-backups (log in + Guest Additions)"
    share=""
}

loops=0
while true; do
    loops=$((loops + 1))
    if [[ -z "$share" ]]; then
        share="$(find_share_root)" || share=""
    fi
    if [[ -n "$share" ]]; then
        trigger="$(find_trigger "$share")" || trigger=""
        if [[ -n "$trigger" ]]; then
            log "Trigger detected: $trigger"
            if [[ "$(basename "$trigger")" == "CTG_TRIGGER_NMAP_INSTALL" ]]; then
                if run_nmap_install_trigger "$share"; then
                    remove_trigger "$trigger" || true
                else
                    log "nmap-ask install trigger failed (sudo/password)"
                fi
            elif [[ "$(basename "$trigger")" == "CTG_RUN_AUTORUN_NOW" ]]; then
                if run_minimal_share_trigger "$share"; then
                    remove_trigger "$trigger" || true
                else
                    log "CTG_RUN_AUTORUN_NOW handler failed (trigger kept for retry)"
                fi
            elif run_autorun_chain "$share"; then
                remove_trigger "$trigger" || true
            else
                log "Autorun chain returned non-zero (trigger kept for retry)"
            fi
        fi
    fi
    if [[ "$MAX_LOOPS" -gt 0 && "$loops" -ge "$MAX_LOOPS" ]]; then
        break
    fi
    sleep "$POLL_SEC"
done
