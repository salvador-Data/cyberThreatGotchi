#!/usr/bin/env bash
# CTG RAM mitigation enforcer — CPU/RAM side-channels (guest).
# Network IPS (Snort/Suricata) does NOT block Spectre/RETBleed/Meltdown — patch microcode/kernel.
# Hacker Planet LLC — authorized lab use only.
#
# Usage:
#   bash ctg-ram-mitigation-enforcer.sh
#   bash ctg-ram-mitigation-enforcer.sh --diagnose-only
#   sudo bash ctg-ram-mitigation-enforcer.sh --apply-safe          # dry-run security upgrades
#   sudo bash ctg-ram-mitigation-enforcer.sh --apply-safe --apply # install listed security packages
set -euo pipefail

APPLY_SAFE=0
APPLY=0
DIAGNOSE_ONLY=1
LOG_DIR="${CTG_LOG_DIR:-/var/log/ctg}"
LOG_FILE="${LOG_DIR}/ctg-ram-mitigation-enforcer.log"

for arg in "$@"; do
  case "$arg" in
    --apply-safe) APPLY_SAFE=1; DIAGNOSE_ONLY=0 ;;
    --apply) APPLY=1 ;;
    --diagnose-only) DIAGNOSE_ONLY=1; APPLY_SAFE=0 ;;
  esac
done

mkdir -p "$LOG_DIR" 2>/dev/null || true
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== CTG RAM mitigation enforcer ($(date -Iseconds)) ==="
echo "NOTE: Snort/Suricata IPS blocks network-layer attacks — NOT RAM side-channels."
echo "Host enforcer: microcode + kernel mitigations + VirtualBox spec-ctrl on Windows host."

vuln_dir="/sys/devices/system/cpu/vulnerabilities"
vulnerable=0

for name in retbleed spectre_v1 spectre_v2 meltdown spec_store_bypass l1tf mds tsx_async_abort srbds; do
  f="${vuln_dir}/${name}"
  if [[ -r "$f" ]]; then
    val="$(tr -d '\n' <"$f" 2>/dev/null || echo n/a)"
    printf '%-20s %s\n' "${name}:" "$val"
    if printf '%s' "$val" | grep -qi 'vulnerable'; then
      vulnerable=1
    fi
  else
    printf '%-20s %s\n' "${name}:" "(unavailable)"
  fi
done

if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -q 2>/dev/null; then
  echo "virt: $(systemd-detect-virt 2>/dev/null || echo unknown)"
  echo "VirtualBox guest: Windows host must run Harden-KaliVmCpu.ps1 --spec-ctrl on (VM powered off)"
else
  echo "virt: none (bare metal or unknown)"
fi

echo
echo "--- Kernel cmdline mitigations=auto ---"
if [[ -r /proc/cmdline ]]; then
  cmdline="$(tr '\0' ' ' </proc/cmdline)"
  echo "cmdline: $cmdline"
  if printf '%s' "$cmdline" | grep -q 'mitigations=off'; then
    echo "ACTION: mitigations=off detected — set mitigations=auto in GRUB and reboot"
    vulnerable=1
  elif ! printf '%s' "$cmdline" | grep -q 'mitigations='; then
    echo "INFO: default kernel mitigations=auto expected (no explicit mitigations= in cmdline)"
  else
    echo "INFO: explicit mitigations= parameter present"
  fi
else
  echo "/proc/cmdline unreadable"
fi

echo
echo "--- Security-related apt packages ---"
if command -v apt >/dev/null 2>&1; then
  if [[ "$APPLY_SAFE" -eq 1 ]]; then
    echo "ApplySafe: refreshing apt indexes"
    sudo apt-get update -qq || apt-get update -qq || true
  fi
  mapfile -t upgrades < <(apt list --upgradable 2>/dev/null | grep -Ei 'security|linux-image|linux-headers|microcode|firmware' || true)
  if [[ ${#upgrades[@]} -eq 0 ]]; then
    echo "(none listed or apt stale — run with --apply-safe)"
  else
    printf '%s\n' "${upgrades[@]}"
    if [[ "$APPLY_SAFE" -eq 1 && "$APPLY" -eq 0 ]]; then
      echo
      echo "DRY-RUN: listed packages NOT installed. Re-run with --apply-safe --apply to install."
    fi
    if [[ "$APPLY" -eq 1 ]]; then
      pkgs=()
      for line in "${upgrades[@]}"; do
        pkg="${line%%/*}"
        [[ -n "$pkg" ]] && pkgs+=("$pkg")
      done
      if [[ ${#pkgs[@]} -gt 0 ]]; then
        echo "Installing: ${pkgs[*]}"
        sudo apt-get install -y "${pkgs[@]}"
        echo "Reboot guest after linux-image/microcode install."
      fi
    fi
  fi
else
  echo "apt not available on this host"
fi

if [[ "$vulnerable" -eq 1 ]]; then
  echo
  echo "VULNERABLE: one or more /sys/.../vulnerabilities entries report Vulnerable."
  echo "Windows host (VM OFF): .\\scripts\\windows\\Harden-KaliVmCpu.ps1 -StopVmIfRunning -StartAfter"
  echo "Guest: sudo apt install intel-microcode amd64-microcode; reboot."
  echo "See docs/RAM_MITIGATION_IPS.md and docs/KALI_RETBLEED_SPECTRE.md"
  exit 1
fi

echo
echo "Posture: no Vulnerable verdict in /sys (reboot after host/guest patches if stale)."
exit 0
