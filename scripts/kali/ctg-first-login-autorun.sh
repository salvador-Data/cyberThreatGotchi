#!/usr/bin/env bash
# CTG Kali first GUI login autorun — zero-touch lab chain (authorized use only).
# Hacker Planet LLC · Philadelphia, PA
#
# Runs on Xfce login (autostart) or when Windows drops CTG_TRIGGER_AUTORUN on Backups share.
# Idempotent: ~/.config/ctg/first-run-done (override: CTG_FORCE_AUTORUN=1 or trigger file).
#
# Log: /var/log/ctg-first-login.log (no secrets)
set -uo pipefail

LOG_FILE="/var/log/ctg-first-login.log"
FLAG_FILE="${HOME}/.config/ctg/first-run-done"
CTG_MOUNT="${CTG_MOUNT:-/mnt/ctg}"
FORCE="${CTG_FORCE_AUTORUN:-0}"

log() {
    local msg="[$(date -Iseconds)] [ctg-first-login] $*"
    printf '%s\n' "$msg"
    if [[ -w "$(dirname "$LOG_FILE")" ]] || [[ "$(id -u)" -eq 0 ]]; then
        printf '%s\n' "$msg" >>"$LOG_FILE" 2>/dev/null || true
    fi
}

resolve_share() {
    local d
    for d in "$CTG_MOUNT" /media/sf_ctg-backups /media/sf_ctg; do
        if [[ -f "$d/ctg-mount-share.sh" || -f "$d/kali-boot-autopatch.sh" ]]; then
            CTG_MOUNT="$d"
            return 0
        fi
    done
    return 1
}

sudo_ctg() {
    if sudo -n true 2>/dev/null; then
        sudo -n "$@"
        return $?
    fi
    log "sudo requires password — run once in terminal: sudo bash $CTG_MOUNT/kali-boot-autopatch.sh --install"
    return 1
}

mount_share() {
    local m="$CTG_MOUNT/ctg-mount-share.sh"
    if mountpoint -q "$CTG_MOUNT" 2>/dev/null || [[ -d /media/sf_ctg-backups ]]; then
        log "Share accessible at $CTG_MOUNT or /media/sf_ctg-backups"
        return 0
    fi
    if [[ -f "$m" ]]; then
        sudo_ctg bash "$m" && return 0
    fi
    sudo_ctg mkdir -p "$CTG_MOUNT" 2>/dev/null || true
    sudo_ctg mount -t vboxsf ctg-backups "$CTG_MOUNT" 2>/dev/null && return 0
    return 1
}

run_chain() {
    log "=== CTG first-login lab chain start (user=$USER mount=$CTG_MOUNT) ==="

    resolve_share || {
        log "ERROR: ctg-backups share not found — stage scripts on Windows, log into Xfce"
        return 1
    }


    if [[ -f "$CTG_MOUNT/kali-boot-autopatch.sh" ]]; then
        log "Phase: kali-boot-autopatch.sh --install (nmap-ask, systemd, sudoers)"
        if sudo_ctg bash "$CTG_MOUNT/kali-boot-autopatch.sh" --install; then
            log "kali-boot-autopatch --install complete"
        else
            log "kali-boot-autopatch --install skipped (sudo password once)"
        fi
    fi
    mount_share || log "Mount skipped — using /media/sf_ctg-backups if present"

    if [[ -x "$CTG_MOUNT/ctg-display-scale.sh" ]] || [[ -f "$CTG_MOUNT/ctg-display-scale.sh" ]]; then
        log "Phase: ctg-display-scale.sh --fit-window (before seamless)"
        bash "$CTG_MOUNT/ctg-display-scale.sh" --fit-window || log "display-scale non-fatal"
    else
        log "Skip display-scale — script not on share"
    fi

    if [[ -f "$CTG_MOUNT/ctg-seamless-guest.sh" ]]; then
        log "Phase: ctg-seamless-guest.sh"
        bash "$CTG_MOUNT/ctg-seamless-guest.sh" || log "seamless-guest non-fatal"
    fi

    if [[ -f "$CTG_MOUNT/ctg-enable-ssh.sh" ]]; then
        log "Phase: ctg-enable-ssh.sh"
        sudo_ctg bash "$CTG_MOUNT/ctg-enable-ssh.sh" || log "enable-ssh skipped (needs sudo --install once)"
    fi

    if [[ -f "$CTG_MOUNT/RUN-KALI-LAB-NOW.sh" ]]; then
        log "Phase: RUN-KALI-LAB-NOW.sh CTG_NO_REBOOT=1"
        if sudo_ctg env CTG_NO_REBOOT=1 CTG_SKIP_AUTO_REBOOT=1 bash "$CTG_MOUNT/RUN-KALI-LAB-NOW.sh"; then
            log "RUN-KALI-LAB-NOW complete"
        else
            log "RUN-KALI-LAB-NOW skipped or failed (sudo/kali-boot-autopatch --install once)"
        fi
    fi

    if [[ -f "$CTG_MOUNT/ctg-retbleed-check.sh" ]]; then
        log "Phase: ctg-retbleed-check.sh"
        bash "$CTG_MOUNT/ctg-retbleed-check.sh" || log "retbleed check reported action (see log)"
    fi

    mkdir -p "$(dirname "$FLAG_FILE")"
    date -Iseconds >"$FLAG_FILE"
    if [[ -w "$CTG_MOUNT" ]]; then
        date -Iseconds >"$CTG_MOUNT/CTG_AUTORUN_DONE" 2>/dev/null || true
    fi
    log "Marked first-run done: $FLAG_FILE"
    log "=== CTG first-login lab chain complete ==="
    return 0
}

spawn_trigger_watch() {
    local root w
    for root in /mnt/ctg /media/sf_ctg-backups /media/sf_ctg; do
        w="$root/ctg-watch-trigger.sh"
        if [[ -f "$w" ]]; then
            if pgrep -f "ctg-watch-trigger.sh" >/dev/null 2>&1; then
                return 0
            fi
            log "Background trigger watch: $w"
            CTG_TRIGGER_MAX_LOOPS=0 nohup bash "$w" >>/var/log/ctg-watch-trigger.log 2>&1 &
            return 0
        fi
    done
    return 1
}

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
if [[ "$(id -u)" -eq 0 ]]; then
    log "WARNING: run as desktop user (autostart), not root"
fi

if [[ "$FORCE" == "1" ]]; then
    run_chain
    exit $?
fi

resolve_share 2>/dev/null || true
spawn_trigger_watch || true

if [[ -f "$FLAG_FILE" ]]; then
    log "First-run already done ($FLAG_FILE) — skip (set CTG_FORCE_AUTORUN=1 or drop CTG_TRIGGER_AUTORUN)"
    exit 0
fi

run_chain
