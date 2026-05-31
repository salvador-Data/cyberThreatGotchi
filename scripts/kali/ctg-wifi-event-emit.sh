#!/usr/bin/env bash
# ctg-wifi-event-emit.sh — wrap rogue-ap-guard → CTGEvent JSON on share inbox.
# Passive scan only. Authorized lab / owned networks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="${SCRIPT_DIR}/rogue-ap-guard.sh"
EVENT_DIR="${CTG_KALI_BACKUPS:-$HOME/Backups}/ctg-events/inbox"
KNOWN_SSIDS="${CTG_KNOWN_SSIDS:-YourLabSSID}"
IFACE=""
DIAGNOSE_ONLY=false

usage() {
  cat <<EOF
Usage: sudo $0 [options]

Runs rogue-ap-guard.sh and emits CTGEvent JSON when warnings occur.

Options:
  -i IFACE        WiFi interface for nmcli scan
  -k SSIDS        Comma-separated known-good SSIDs (default: YourLabSSID)
  --diagnose      Run guard diagnose only; no event emit
  -h              Help
EOF
}

log_msg() {
  mkdir -p "$EVENT_DIR"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

emit_from_log() {
  local warnings="$1"
  local id ts
  id="$(uuidgen 2>/dev/null || echo "kali-wifi-$(date +%s)")"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$EVENT_DIR/${id}.json" <<JSON
{
  "id": "$id",
  "type": "wifi.rogue_ap",
  "source": "kali",
  "severity": "warn",
  "message": "rogue-ap-guard reported $warnings warning(s) for known SSIDs: $KNOWN_SSIDS",
  "ssid": "$KNOWN_SSIDS",
  "bssid": "",
  "message_id": "",
  "timestamp": "$ts"
}
JSON
  log_msg "Emitted CTGEvent -> $EVENT_DIR/${id}.json"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) IFACE="$2"; shift 2 ;;
    -k) KNOWN_SSIDS="$2"; shift 2 ;;
    --diagnose) DIAGNOSE_ONLY=true; shift ;;
    -h) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -x "$GUARD" ]] || { echo "Missing $GUARD" >&2; exit 1; }

args=()
[[ -n "$IFACE" ]] && args+=(-i "$IFACE")
[[ -n "$KNOWN_SSIDS" ]] && args+=(-k "$KNOWN_SSIDS")

if [[ "$DIAGNOSE_ONLY" == true ]]; then
  exec bash "$GUARD" "${args[@]}"
fi

set +e
bash "$GUARD" "${args[@]}"
rc=$?
set -e

if [[ "$rc" -eq 2 ]]; then
  emit_from_log "1+"
  exit 2
fi
exit "$rc"
