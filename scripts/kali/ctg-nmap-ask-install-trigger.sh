#!/usr/bin/env bash
# CTG Kali — host-triggered nmap-ask install (CTG_TRIGGER_NMAP_INSTALL on share).
# Authorized lab use only — Hacker Planet LLC.
set -uo pipefail
CTG_MOUNT="${CTG_MOUNT:-/media/sf_ctg-backups}"
for d in /media/sf_ctg-backups /mnt/ctg /media/sf_ctg; do
  if [[ -f "$d/kali-boot-autopatch.sh" ]]; then CTG_MOUNT="$d"; break; fi
done
LOG_FILE="${HOME}/ctg-nmap-install-trigger.log"
log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"; }
sudo_ctg() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; return $?; fi
  return 1
}
log "CTG nmap-ask install trigger (mount=$CTG_MOUNT user=$USER)"
if mountpoint -q /mnt/ctg 2>/dev/null || [[ -d /media/sf_ctg-backups ]]; then
  :
elif [[ -f "$CTG_MOUNT/ctg-mount-share.sh" ]]; then
  sudo_ctg bash "$CTG_MOUNT/ctg-mount-share.sh" || log "mount-share needs password"
fi
if sudo_ctg bash "$CTG_MOUNT/kali-boot-autopatch.sh" --install; then
  log "kali-boot-autopatch --install OK"
  date -Iseconds >"$CTG_MOUNT/CTG_NMAP_INSTALL_DONE" 2>/dev/null || true
  rm -f "$CTG_MOUNT/CTG_TRIGGER_NMAP_INSTALL" 2>/dev/null || true
  exit 0
fi
log "sudo required — run once in Kali terminal: sudo bash $CTG_MOUNT/kali-boot-autopatch.sh --install"
exit 1
