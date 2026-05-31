#!/usr/bin/env bash
# ctg-deauth-watch.sh — passive monitor-mode deauth/disassoc frame counter (defensive only).
# Does NOT transmit deauth, jam, or counter-jam. Authorized lab / owned networks only.
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_DIR="${CTG_KALI_BACKUPS:-$HOME/Backups}/logs"
LOG_FILE="$LOG_DIR/ctg-deauth-watch.log"
EVENT_DIR="${CTG_KALI_BACKUPS:-$HOME/Backups}/ctg-events/inbox"
IFACE=""
THRESHOLD="${CTG_DEAUTH_THRESHOLD:-50}"
WINDOW_SEC="${CTG_DEAUTH_WINDOW_SEC:-60}"
DIAGNOSE_ONLY=false
WATCH=false

usage() {
  cat <<EOF
Usage: sudo $SCRIPT_NAME [options]

Passive monitor-mode helper: count 802.11 deauthentication/disassociation frames
and emit CTGEvent JSON when threshold exceeded within window.

Options:
  -i IFACE       Monitor interface (wlan0mon or similar)
  --diagnose     Check tools + iface; no capture
  --watch        Continuous capture loop
  --threshold N  Frames per window (default: $THRESHOLD)
  --window SEC   Window seconds (default: $WINDOW_SEC)
  -h             Help

Legal: detection and failover only. FCC prohibits unauthorized jamming/deauth transmit.
EOF
}

log_msg() {
  mkdir -p "$LOG_DIR" "$EVENT_DIR"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $SCRIPT_NAME $*" >&2
    exit 1
  fi
}

emit_event() {
  local count="$1"
  local ssid="${2:-}"
  local bssid="${3:-}"
  local id
  id="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "kali-$(date +%s)")"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$EVENT_DIR/${id}.json" <<JSON
{
  "id": "$id",
  "type": "wifi.deauth",
  "source": "kali",
  "severity": "high",
  "message": "Deauth/disassoc frames $count in ${WINDOW_SEC}s on $IFACE (threshold $THRESHOLD)",
  "ssid": "$ssid",
  "bssid": "$bssid",
  "message_id": "",
  "timestamp": "$ts"
}
JSON
  log_msg "Emitted CTGEvent wifi.deauth count=$count -> $EVENT_DIR/${id}.json"
}

diagnose() {
  log_msg "--- ctg-deauth-watch diagnose ---"
  for cmd in iw tcpdump; do
    if command -v "$cmd" >/dev/null 2>&1; then
      log_msg "OK: $cmd present"
    else
      log_msg "WARN: $cmd missing (apt install $cmd)"
    fi
  done
  if [[ -n "$IFACE" ]]; then
    iw dev "$IFACE" info 2>/dev/null | head -5 | while read -r line; do log_msg "  $line"; done || log_msg "WARN: iface $IFACE not ready"
  else
    log_msg "INFO: pass -i wlan0mon after enabling monitor mode"
  fi
  log_msg "Honest limit: consumer radios miss encrypted management frames; threshold is heuristic."
}

run_capture_once() {
  [[ -n "$IFACE" ]] || { log_msg "ERROR: -i IFACE required"; exit 1; }
  local tmp count
  tmp="$(mktemp /tmp/ctg-deauth-XXXXXX.pcap)"
  trap 'rm -f "$tmp"' EXIT
  log_msg "Capture ${WINDOW_SEC}s on $IFACE (filter: deauth/disassoc)"
  timeout "$WINDOW_SEC" tcpdump -i "$IFACE" -n -w "$tmp" \
    'subtype deauth or subtype disassoc' 2>/dev/null || true
  if command -v tshark >/dev/null 2>&1; then
    count="$(tshark -r "$tmp" -Y 'wlan.fc.type_subtype==0x0c || wlan.fc.type_subtype==0x0a' 2>/dev/null | wc -l | tr -d ' ')"
  else
    count="$(tcpdump -r "$tmp" -n 2>/dev/null | wc -l | tr -d ' ')"
  fi
  log_msg "Frames counted: $count (threshold $THRESHOLD)"
  if [[ "$count" -ge "$THRESHOLD" ]]; then
    emit_event "$count"
    return 2
  fi
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) IFACE="$2"; shift 2 ;;
    --diagnose) DIAGNOSE_ONLY=true; shift ;;
    --watch) WATCH=true; shift ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --window) WINDOW_SEC="$2"; shift 2 ;;
    -h) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
done

require_root

if [[ "$DIAGNOSE_ONLY" == true ]]; then
  diagnose
  exit 0
fi

if [[ "$WATCH" == true ]]; then
  log_msg "Watch mode (Ctrl+C to stop)"
  while true; do
    run_capture_once || true
    sleep 5
  done
fi

run_capture_once
