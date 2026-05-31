#!/usr/bin/env bash
# CTG Kali - minimal share-trigger runner (mount + lab chain). Hacker Planet LLC lab only.
set -euo pipefail
LOG_FILE="/var/log/ctg-run-on-share-trigger.log"
TRIGGER_NAME="${CTG_SHARE_TRIGGER_NAME:-CTG_RUN_AUTORUN_NOW}"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" 2>/dev/null || printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

find_share_root() {
  local d
  for d in /mnt/ctg /media/sf_ctg-backups /media/sf_ctg; do
    if [[ -f "$d/RUN-KALI-LAB-NOW.sh" || -f "$d/ctg-mount-share.sh" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

run_minimal_chain() {
  local root="$1"
  log "=== minimal chain start (root=$root) ==="
  if [[ -f "$root/ctg-mount-share.sh" ]]; then
    sudo bash "$root/ctg-mount-share.sh" || log "mount-share non-fatal"
  fi
  local m=/mnt/ctg
  if [[ -f "$m/kali-boot-autopatch.sh" ]]; then
    sudo bash "$m/kali-boot-autopatch.sh" --install || log "autopatch --install needs sudo password once"
  fi
  if [[ -f "$m/RUN-KALI-LAB-NOW.sh" ]]; then
    sudo CTG_NO_REBOOT=1 bash "$m/RUN-KALI-LAB-NOW.sh" || log "RUN-KALI-LAB-NOW failed"
  fi
  [[ -f "$m/ctg-display-scale.sh" ]] && bash "$m/ctg-display-scale.sh" --fit-window || true
  [[ -f "$m/ctg-seamless-text-toggle.sh" ]] && bash "$m/ctg-seamless-text-toggle.sh" --enter-seamless || true
  command -v ctg-nmap-ask >/dev/null 2>&1 && ctg-nmap-ask --help || [[ -f "$m/ctg-nmap-ask.sh" ]] && bash "$m/ctg-nmap-ask.sh" --help || true
  date -Iseconds >"$root/CTG_AUTORUN_DONE" 2>/dev/null || true
  log "=== minimal chain done ==="
}

main() {
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  local root trigger
  root="$(find_share_root)" || { log "share not visible"; exit 1; }
  trigger="$root/$TRIGGER_NAME"
  if [[ ! -f "$trigger" ]]; then
    log "no trigger $trigger - exit 0"
    exit 0
  fi
  log "trigger found: $trigger"
  run_minimal_chain "$root"
  rm -f "$trigger" 2>/dev/null || log "could not remove trigger (ro share?)"
}

main "$@"
