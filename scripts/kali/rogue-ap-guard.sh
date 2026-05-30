#!/usr/bin/env bash
# rogue-ap-guard.sh — passive WiFi rogue AP / evil-twin detector (authorized lab only).
# Does NOT deauth, jam, or attack — scan, compare, warn.
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
INSTALL_DIR="${CTG_KALI_BACKUPS:-$HOME/Backups}/kali-wifi-guard"
LOG_DIR="${CTG_KALI_BACKUPS:-$HOME/Backups}/logs"
LOG_FILE="$LOG_DIR/rogue-ap-guard.log"
SCAN_CSV=""
KNOWN_SSIDS="${CTG_KNOWN_SSIDS:-}"

usage() {
  cat <<EOF
Usage: sudo $SCRIPT_NAME [options]

Passive scan for duplicate SSIDs, open networks, and evil-twin hints
(same ESSID, different BSSID, large signal delta).

Options:
  -i IFACE     WiFi interface (default: auto from iw dev)
  -o DIR       Install copy to DIR (default: $INSTALL_DIR)
  -k SSIDS     Comma-separated known-good SSIDs (or env CTG_KNOWN_SSIDS)
  -h           Help

Authorized defensive lab / home networks you own or administer only.
Do not run against third-party networks without written permission.
EOF
}

log_msg() {
  mkdir -p "$LOG_DIR"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $SCRIPT_NAME $*" >&2
    exit 1
  fi
}

detect_iface() {
  if command -v iw >/dev/null 2>&1; then
    iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}'
    return
  fi
  ip link show 2>/dev/null | awk -F': ' '/wlan/ {print $2; exit}'
}

install_self() {
  local dest="$1"
  mkdir -p "$dest"
  cp -f "$0" "$dest/$SCRIPT_NAME"
  chmod +x "$dest/$SCRIPT_NAME"
  log_msg "Installed to $dest/$SCRIPT_NAME"
}

run_scan() {
  local iface="$1"
  local out
  out="$(mktemp /tmp/rogue-ap-XXXXXX)"
  trap 'rm -f "$out" "$SCAN_CSV"' EXIT

  log_msg "--- rogue-ap-guard scan on $iface ---"

  if ! command -v nmcli >/dev/null 2>&1; then
    log_msg "ERROR: nmcli not found. Install: apt install network-manager"
    exit 1
  fi

  nmcli dev wifi rescan ifname "$iface" 2>/dev/null || true
  sleep 3
  nmcli -f SSID,BSSID,SECURITY,SIGNAL,CHAN dev wifi list ifname "$iface" >"$out"

  SCAN_CSV="$(mktemp /tmp/rogue-ap-csv-XXXXXX)"
  awk 'NR>1 && $1 != "--" {print}' "$out" >"$SCAN_CSV"

  declare -A essid_count
  declare -A essid_bssids
  local warnings=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ssid="$(echo "$line" | awk '{print $1}')"
    bssid="$(echo "$line" | awk '{print $2}')"
    sec="$(echo "$line" | awk '{print $3}')"
    sig="$(echo "$line" | awk '{print $4}')"
    [[ -z "$ssid" || "$ssid" == "--" ]] && continue

    essid_count["$ssid"]=$(( ${essid_count["$ssid"]:-0} + 1 ))
    essid_bssids["$ssid"]+="${bssid}:${sig};"

    if [[ "$sec" == "--" || "$sec" == "" ]]; then
      log_msg "WARN: Open network: SSID=$ssid BSSID=$bssid SIGNAL=$sig — do not auto-join; use VPN if you must connect."
      warnings=$((warnings + 1))
    fi
  done <"$SCAN_CSV"

  for ssid in "${!essid_count[@]}"; do
    count="${essid_count[$ssid]}"
    if [[ "$count" -gt 1 ]]; then
      log_msg "WARN: Duplicate SSID '$ssid' seen $count times (possible evil twin): ${essid_bssids[$ssid]}"
      warnings=$((warnings + 1))
      IFS=';' read -ra parts <<< "${essid_bssids[$ssid]}"
      local best_sig=-999 worst_sig=999
      for p in "${parts[@]}"; do
        [[ -z "$p" ]] && continue
        s="${p##*:}"
        [[ "$s" =~ ^[0-9]+$ ]] || continue
        (( s > best_sig )) && best_sig=$s
        (( s < worst_sig )) && worst_sig=$s
      done
      if [[ "$best_sig" -ne -999 && "$worst_sig" -ne 999 && $((best_sig - worst_sig)) -ge 25 ]]; then
        log_msg "WARN: Evil-twin hint for '$ssid' — signal spread $((best_sig - worst_sig)) dBm between BSSIDs. Prefer wired or known BSSID."
      fi
    fi
  done

  if [[ -n "$KNOWN_SSIDS" ]]; then
    IFS=',' read -ra known <<< "$KNOWN_SSIDS"
    for k in "${known[@]}"; do
      k="$(echo "$k" | xargs)"
      [[ -z "$k" ]] && continue
      if [[ -z "${essid_count[$k]:-}" ]]; then
        log_msg "INFO: Known SSID '$k' not visible this scan (may be out of range)."
      else
        log_msg "OK: Known SSID '$k' visible (${essid_count[$k]} AP(s))."
      fi
    done
  fi

  log_msg "Scan complete. Warnings: $warnings"
  log_msg "Never enter credentials on unexpected captive portals. Do not attack back."
  log_msg "Log: $LOG_FILE"

  if [[ "$warnings" -gt 0 ]]; then
    exit 2
  fi
  exit 0
}

IFACE=""
INSTALL_ONLY=""

while getopts "i:o:k:h" opt; do
  case "$opt" in
    i) IFACE="$OPTARG" ;;
    o) INSTALL_DIR="$OPTARG"; INSTALL_ONLY=1 ;;
    k) KNOWN_SSIDS="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

require_root

if [[ -n "$INSTALL_ONLY" ]]; then
  install_self "$INSTALL_DIR"
  exit 0
fi

install_self "$INSTALL_DIR"

[[ -z "$IFACE" ]] && IFACE="$(detect_iface || true)"
if [[ -z "$IFACE" ]]; then
  log_msg "ERROR: No WiFi interface found."
  exit 1
fi

run_scan "$IFACE"
