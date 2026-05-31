#!/usr/bin/env bash
# CTG email notification consumer for Kali guest — reads ctg-email-notify JSON from share.
# Dedup again on guest using Message-ID / content_hash (defense in depth).
set -euo pipefail

NOTIFY_DIR="${CTG_EMAIL_NOTIFY_DIR:-}"
LOG="${HOME}/ctg-email-notify.log"
STATE="${HOME}/.cache/ctg-email-notify-seen.json"

for d in /media/sf_ctg-backups/ctg-email-notify /mnt/ctg/ctg-email-notify; do
  if [[ -d "$d" ]]; then NOTIFY_DIR="$d"; break; fi
done

if [[ -z "$NOTIFY_DIR" ]]; then
  NOTIFY_DIR="${HOME}/ctg-email-notify"
fi

mkdir -p "$(dirname "$STATE")" "$(dirname "$LOG")"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

is_seen() {
  local key="$1"
  [[ -f "$STATE" ]] && grep -Fxq "$key" "$STATE" 2>/dev/null
}

mark_seen() {
  local key="$1"
  echo "$key" >> "$STATE"
}

process_file() {
  local f="$1"
  local mid hash subj from_addr
  mid=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('message_id') or '')" "$f" 2>/dev/null || echo "")
  hash=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('content_hash') or '')" "$f" 2>/dev/null || echo "")
  subj=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('subject') or 'Email')" "$f" 2>/dev/null || echo "Email")
  from_addr=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('from') or '')" "$f" 2>/dev/null || echo "")

  local key="${mid:-$hash}"
  [[ -z "$key" ]] && key="$(basename "$f")"

  if is_seen "$key"; then
    log "SKIP duplicate: $subj"
    return 0
  fi

  mark_seen "$key"
  log "NEW email: $subj (from: $from_addr)"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal "CTG Email" "$subj"
  fi
  echo "======== CTG EMAIL ========"
  echo "Subject: $subj"
  echo "From:    $from_addr"
  echo "File:    $f"
  echo "=========================="
}

log "Watching: $NOTIFY_DIR"

if [[ ! -d "$NOTIFY_DIR" ]]; then
  log "Directory missing — Windows host should run Start-CtgEmailNotifyBridge.ps1"
  exit 0
fi

shopt -s nullglob
files=("$NOTIFY_DIR"/email-*.json)
if [[ ${#files[@]} -eq 0 ]]; then
  log "No pending notifications"
  exit 0
fi

for f in "${files[@]}"; do
  process_file "$f"
done

log "Done (${#files[@]} file(s) scanned)"
