#!/usr/bin/env bash
# ctg-event-notify.sh — watch Backups ctg-events and notify-send once per event id.
set -euo pipefail

EVENT_DIR="${CTG_KALI_BACKUPS:-$HOME/Backups}/ctg-events"
INBOX="$EVENT_DIR/inbox"
PROCESSED="$EVENT_DIR/processed"
STATE="$EVENT_DIR/.notify-seen.ids"
POLL_SEC="${CTG_EVENT_NOTIFY_POLL:-15}"

usage() {
  cat <<EOF
Usage: $0 [--once] [--diagnose]

Watch $INBOX for CTGEvent JSON; notify-send once per event id.
Dedupe state: $STATE (local file, not committed).
EOF
}

log_msg() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

load_seen() {
  mkdir -p "$PROCESSED"
  touch "$STATE"
  cat "$STATE" 2>/dev/null || true
}

mark_seen() {
  echo "$1" >>"$STATE"
}

notify_event() {
  local file="$1"
  local id type sev msg summary
  id="$(python3 -c "import json;print(json.load(open('$file'))['id'])" 2>/dev/null || basename "$file" .json)"
  if load_seen | grep -qx "$id" 2>/dev/null; then
    return 0
  fi
  type="$(python3 -c "import json;print(json.load(open('$file')).get('type',''))" 2>/dev/null || echo wifi)"
  sev="$(python3 -c "import json;print(json.load(open('$file')).get('severity','info'))" 2>/dev/null || echo info)"
  msg="$(python3 -c "import json;print(json.load(open('$file')).get('message',''))" 2>/dev/null || echo CTG event)"
  summary="$(python3 -c "import json;print(json.load(open('$file')).get('analyst_summary',''))" 2>/dev/null || true)"
  [[ -n "$summary" ]] && msg="$summary"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal "CTG $sev" "$type: $msg"
  else
    log_msg "notify-send missing; $type: $msg"
  fi
  mark_seen "$id"
  mv -f "$file" "$PROCESSED/" 2>/dev/null || true
}

diagnose() {
  log_msg "Inbox: $INBOX"
  log_msg "Processed: $PROCESSED"
  log_msg "Poll: ${POLL_SEC}s"
  if command -v notify-send >/dev/null 2>&1; then
    log_msg "OK: notify-send"
  else
    log_msg "WARN: install libnotify-bin for desktop toasts"
  fi
}

ONCE=false
DIAGNOSE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --once) ONCE=true; shift ;;
    --diagnose) DIAGNOSE=true; shift ;;
    -h) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p "$INBOX" "$PROCESSED"
[[ "$DIAGNOSE" == true ]] && { diagnose; exit 0; }

poll_once() {
  shopt -s nullglob
  for f in "$INBOX"/*.json; do
    notify_event "$f"
  done
}

if [[ "$ONCE" == true ]]; then
  poll_once
  exit 0
fi

log_msg "Watching $INBOX (Ctrl+C to stop)"
while true; do
  poll_once
  sleep "$POLL_SEC"
done
