#!/usr/bin/env bash
# Double-click in Thunar (one GUI action). Opens terminal; sudo password once if needed.
set -uo pipefail
ROOT=""
for d in /media/sf_ctg-backups /mnt/ctg /media/sf_ctg; do
  if [[ -f "$d/RUN-KALI-LAB-NOW.sh" ]]; then ROOT="$d"; break; fi
done
if [[ -z "$ROOT" ]]; then
  xterm -hold -e 'echo "CTG share not found. Log into Xfce and ensure Guest Additions share ctg-backups."; read' 2>/dev/null || echo "CTG share not found" >&2
  exit 1
fi
export CTG_FORCE_AUTORUN=1
exec xterm -hold -e "bash -lc 'set -x; sudo bash \"$ROOT/ctg-mount-share.sh\"; sudo bash \"$ROOT/kali-boot-autopatch.sh\" --install; sudo CTG_NO_REBOOT=1 bash \"$ROOT/RUN-KALI-LAB-NOW.sh\"; bash \"$ROOT/ctg-display-scale.sh\" --fit-window; bash \"$ROOT/ctg-seamless-text-toggle.sh\" --enter-seamless; ctg-nmap-ask --help 2>/dev/null || bash \"$ROOT/ctg-nmap-ask.sh\" --help; echo DONE; read'"