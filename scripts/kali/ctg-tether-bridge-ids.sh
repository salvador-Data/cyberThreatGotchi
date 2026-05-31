#!/usr/bin/env bash
# CTG Kali — iPhone tether bridge IDS notes (passive / doc-first).
# Authorized defensive lab use only — Hacker Planet LLC · Philadelphia, PA
#
# HONEST SCOPE: Kali cannot emulate iPhone cellular, BLE, or Wi-Fi MAC from this VM.
# When Windows host is tethered via iPhone (hotspot or USB), bridged Kali sees the same
# NAT'd IP egress as the host — optional Suricata on the bridge iface mirrors Windows IDS.
#
# Usage:
#   bash ctg-tether-bridge-ids.sh              Print bridge guidance (default)
#   bash ctg-tether-bridge-ids.sh --diagnose   List links + default route (no capture)
#
# Windows primary: Start-CtgIphoneTetherIds.ps1
# Docs: docs/IPHONE_TETHER_MONITORING.md
set -euo pipefail

LOG_FILE="/var/log/ctg-tether-bridge-ids.log"
DO_DIAG=false

log() {
    local msg="[$(date -Iseconds)] [ctg-tether-bridge-ids] $*"
    printf '%s\n' "$msg"
    if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null || mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then
        printf '%s\n' "$msg" >>"$LOG_FILE"
    fi
}

usage() {
    cat <<EOF
CTG iPhone tether bridge IDS — documentation and optional diagnose (lab only).

  bash $0                 Show bridge / passive mirror guidance
  bash $0 --diagnose      List UP interfaces and default route

Cannot: emulate phone cellular/BLE/Wi-Fi identity from Kali.
Can: Suricata on bridged iface when VM shares host tether NAT path.

VirtualBox: attach Kali NIC to "Bridged Adapter" = Windows tether interface
  (Wi-Fi when on Personal Hotspot, or "Apple Mobile Device Ethernet" for USB).

Passive mirror (advanced lab): span/tap on host tether adapter — out of scope for
  automated CTG scripts; document only.

Windows IDS: scripts/windows/Start-CtgIphoneTetherIds.ps1
EVE staging: ctg-suricata-ips-sms.sh + Start-CtgKaliSuricataSmsBridge.ps1
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --diagnose) DO_DIAG=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log "Unknown arg: $1"; usage; exit 1 ;;
    esac
done

log "=== CTG tether bridge IDS (doc-first) ==="
log "Monitor tether egress only — no radio spoofing."

cat <<'NOTES'

Bridge checklist (manual):
  1. iPhone Personal Hotspot or USB tether active on Windows host.
  2. VirtualBox Kali: Settings -> Network -> Adapter 1 -> Bridged -> host tether NIC.
  3. Inside Kali: ip route | grep default  (gateway often 172.20.10.1 on phone tether).
  4. Optional: ctg-ids-ips-autorun.sh on eth0/enp0s3 when bridge is UP.
  5. Preserve DuckDuckGo VPN on iPhone — do not disable for IDS tests.

BLE / cellular: remain on phone; Kali sees IP after NAT only.

NOTES

if [[ "$DO_DIAG" == true ]]; then
    log "--- diagnose: links ---"
    ip -br link 2>/dev/null || true
    log "--- diagnose: default route ---"
    ip route show default 2>/dev/null || true
fi

log "Done. See docs/IPHONE_TETHER_MONITORING.md on Windows host repo."
