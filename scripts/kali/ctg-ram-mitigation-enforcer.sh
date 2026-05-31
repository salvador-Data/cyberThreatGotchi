#!/usr/bin/env bash
# CTG RAM / memory protection enforcer — CPU/RAM side-channels (guest).
# Network IPS (Snort/Suricata) does NOT block Spectre/RETBleed/Meltdown — patch microcode/kernel.
# Hacker Planet LLC — authorized lab use only.
#
# Usage:
#   bash ctg-ram-mitigation-enforcer.sh
#   bash ctg-ram-mitigation-enforcer.sh --diagnose-only
#   sudo bash ctg-ram-mitigation-enforcer.sh --apply-safe          # dry-run security upgrades
#   sudo bash ctg-ram-mitigation-enforcer.sh --apply-safe --apply # install listed security packages
#   sudo bash ctg-ram-mitigation-enforcer.sh --setup-cryptswap     # diagnose encrypted swap
#   sudo bash ctg-ram-mitigation-enforcer.sh --setup-cryptswap --apply  # opt-in cryptswap setup
set -euo pipefail

APPLY_SAFE=0
APPLY=0
DIAGNOSE_ONLY=1
SETUP_CRYPTSWAP=0
LOG_DIR="${CTG_LOG_DIR:-/var/log/ctg}"
LOG_FILE="${LOG_DIR}/ctg-ram-mitigation-enforcer.log"

for arg in "$@"; do
  case "$arg" in
    --apply-safe) APPLY_SAFE=1; DIAGNOSE_ONLY=0 ;;
    --apply) APPLY=1 ;;
    --diagnose-only) DIAGNOSE_ONLY=1; APPLY_SAFE=0 ;;
    --setup-cryptswap) SETUP_CRYPTSWAP=1 ;;
  esac
done

mkdir -p "$LOG_DIR" 2>/dev/null || true
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== CTG memory protection enforcer ($(date -Iseconds)) ==="
echo "NOTE: Snort/Suricata IPS blocks network-layer attacks — NOT RAM side-channels."
echo "Host enforcer: microcode + kernel mitigations + VirtualBox spec-ctrl on Windows host."
echo "See docs/MEMORY_PROTECTION.md — no user-mode tool can encrypt all RAM."

vuln_dir="/sys/devices/system/cpu/vulnerabilities"
vulnerable=0

echo
echo "--- /sys/devices/system/cpu/vulnerabilities/* ---"
if [[ -d "$vuln_dir" ]]; then
  while IFS= read -r -d '' f; do
    name="$(basename "$f")"
    val="$(tr -d '\n' <"$f" 2>/dev/null || echo n/a)"
    printf '%-24s %s\n' "${name}:" "$val"
    if printf '%s' "$val" | grep -qi 'vulnerable'; then
      vulnerable=1
    fi
  done < <(find "$vuln_dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
else
  echo "vulnerabilities sysfs unavailable"
fi

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
echo "--- Vault / secrets in RAM (mlock note) ---"
echo "CTG credential vault (Windows): session TTL via CTG_VAULT_SESSION_TTL; lock when idle."
echo "Linux mlock(2)/mlockall(2) can pin sensitive pages — requires CAP_IPC_LOCK and ulimit -l."
echo "mlock does NOT stop suspend-to-RAM or kernel swap under memory pressure without encrypted swap."
if grep -q '^MemAvailable:' /proc/meminfo 2>/dev/null; then
  ulimit -l 2>/dev/null | xargs -r echo "ulimit -l (max locked memory KB):" || true
fi

diagnose_cryptswap() {
  echo
  echo "--- Encrypted swap (cryptswap) — opt-in ---"
  if [[ ! -r /etc/crypttab ]]; then
    echo "crypttab missing — install cryptsetup"
    return 0
  fi
  if grep -E '^[^#].*\s+swap' /etc/crypttab 2>/dev/null | grep -qv '^#'; then
    echo "OK: /etc/crypttab appears to configure encrypted swap"
    grep -E '^[^#].*\s+swap' /etc/crypttab 2>/dev/null || true
    if command -v cryptsetup >/dev/null 2>&1; then
      while read -r line; do
        target="${line%% *}"
        [[ -n "$target" && -e "/dev/mapper/$target" ]] || continue
        cryptsetup status "$target" 2>/dev/null | head -n 3 || true
      done < <(grep -E '^[^#].*\s+swap' /etc/crypttab 2>/dev/null || true)
    fi
    return 0
  fi
  echo "DIAGNOSE: swap not encrypted in crypttab — secrets may reach disk if paged"
  swapon --show 2>/dev/null || true
  echo "Opt-in: sudo bash $0 --setup-cryptswap --apply (random key per boot; breaks hibernate)"
  echo "Reference: https://cryptsetup-team.pages.debian.net/cryptsetup/README.Debian.html"
  if [[ "$SETUP_CRYPTSWAP" -eq 1 && "$APPLY" -eq 1 ]]; then
    setup_cryptswap_apply
  fi
}

setup_cryptswap_apply() {
  echo
  echo "=== cryptswap setup (destructive — review swap devices first) ==="
  if ! command -v cryptsetup >/dev/null 2>&1; then
    echo "Installing cryptsetup..."
    apt-get update -qq
    apt-get install -y cryptsetup
  fi
  mapfile -t swap_devs < <(swapon --show=NAME --noheadings 2>/dev/null | grep -E '^/dev/' || true)
  if [[ ${#swap_devs[@]} -eq 0 ]]; then
    echo "No active swap partition found — configure swap first or use zram-tools"
    return 1
  fi
  for dev in "${swap_devs[@]}"; do
    dev="${dev// /}"
    [[ -b "$dev" ]] || continue
    target="ctgcryptswap-$(basename "$dev")"
    if grep -q "^${target} " /etc/crypttab 2>/dev/null; then
      echo "Already in crypttab: $target"
      continue
    fi
    echo "Will configure encrypted swap for $dev -> /dev/mapper/$target"
    swapoff "$dev" || { echo "swapoff $dev failed"; return 1; }
    if ! grep -q "^${target} " /etc/crypttab 2>/dev/null; then
      echo "${target} ${dev} /dev/urandom swap,cipher=aes-xts-plain64,size=256" >>/etc/crypttab
    fi
    if grep -q "^${dev}[[:space:]]" /etc/fstab 2>/dev/null; then
      sed -i "s|^${dev}[[:space:]].*|/dev/mapper/${target} none swap sw 0 0|" /etc/fstab
    fi
    if command -v systemd-cryptsetup >/dev/null 2>&1; then
      systemctl start "systemd-cryptsetup@${target}.service" 2>/dev/null || cryptdisks_start "$target" 2>/dev/null || true
    else
      cryptdisks_start "$target" 2>/dev/null || true
    fi
    swapon "/dev/mapper/${target}" 2>/dev/null || swapon -a
    echo "Encrypted swap active: /dev/mapper/${target}"
  done
  if [[ -d /etc/initramfs-tools/conf.d ]]; then
    echo 'RESUME=none' >/etc/initramfs-tools/conf.d/resume
    update-initramfs -u 2>/dev/null || true
  fi
  echo "cryptswap setup complete — reboot recommended"
}

if [[ "$SETUP_CRYPTSWAP" -eq 1 || "$DIAGNOSE_ONLY" -eq 1 ]]; then
  diagnose_cryptswap
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
  echo "See docs/MEMORY_PROTECTION.md and docs/KALI_RETBLEED_SPECTRE.md"
  exit 1
fi

echo
echo "Posture: no Vulnerable verdict in /sys (reboot after host/guest patches if stale)."
exit 0
