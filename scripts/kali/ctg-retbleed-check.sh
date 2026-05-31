#!/usr/bin/env bash
# CTG quick RETBleed / Spectre v2 posture readout (guest). Authorized lab use only.
# Hacker Planet LLC — Philadelphia, PA
#
# Usage:
#   bash ctg-retbleed-check.sh
#   sudo bash ctg-retbleed-check.sh   # optional; reads /sys without root
set -euo pipefail

vuln_dir="/sys/devices/system/cpu/vulnerabilities"
echo "=== CTG RETBleed / Spectre check ($(date -Iseconds)) ==="

for name in retbleed spectre_v2 spec_store_bypass l1tf mds; do
    f="${vuln_dir}/${name}"
    if [[ -r "$f" ]]; then
        printf '%-18s %s\n' "${name}:" "$(tr -d '\n' <"$f" 2>/dev/null || echo n/a)"
    else
        printf '%-18s %s\n' "${name}:" "(unavailable)"
    fi
done

if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -q 2>/dev/null; then
    echo "virt: $(systemd-detect-virt 2>/dev/null || echo unknown)"
else
    echo "virt: none (bare metal or unknown)"
fi

retbleed="$(cat "${vuln_dir}/retbleed" 2>/dev/null || true)"
if printf '%s' "$retbleed" | grep -qi 'vulnerable'; then
    echo
    echo "ACTION: If VirtualBox guest, power VM OFF on Windows host and run:"
    echo "  .\\scripts\\windows\\Harden-KaliVmCpu.ps1 -StopVmIfRunning -StartAfter"
    echo "Then reboot Kali and re-run this script."
    echo "See docs/KALI_RETBLEED_SPECTRE.md (repo) or /mnt/ctg/KALI_RETBLEED_SPECTRE.md"
    exit 1
fi

echo
echo "Posture: no RETBleed-vulnerable verdict in /sys (reboot after host changes if stale)."
exit 0