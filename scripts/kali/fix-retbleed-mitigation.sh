#!/usr/bin/env bash
# CTG RETBleed / Spectre-v2 mitigation helper — authorized lab use only.
# Hacker Planet LLC · Philadelphia, PA
#
# Addresses RETBleed warnings in dmesg/journal at Kali boot (VirtualBox guest).
# Host CPU microcode and kernel mitigations matter; VM cannot fully hide host gaps.
#
# Usage:
#   sudo bash fix-retbleed-mitigation.sh --diagnose-only
#   sudo bash fix-retbleed-mitigation.sh --apply
set -euo pipefail

LOG_FILE="/var/log/ctg-retbleed.log"
DIAGNOSE_ONLY=true
DO_APPLY=false

log() {
    local msg="[$(date -Iseconds)] [ctg-retbleed] $*"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

usage() {
    cat <<EOF
CTG RETBleed mitigation — authorized defensive lab use only.

  sudo bash $0 --diagnose-only   Log kernel mitigation state (default)
  sudo bash $0 --apply           Install microcode, kernel upgrade, verify GRUB

Log: ${LOG_FILE}
See: docs/KALI_RETBLEED.md (repo) or /mnt/ctg/KALI_RETBLEED.md (share)
Never use mitigations=off on lab or production systems.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --diagnose-only) DIAGNOSE_ONLY=true; DO_APPLY=false ;;
        --apply) DO_APPLY=true; DIAGNOSE_ONLY=false ;;
        --help|-h) usage; exit 0 ;;
        *) log "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

capture_mitigation_state() {
    local label="$1"
    {
        echo "=== $label ==="
        echo "--- /proc/cmdline ---"
        cat /proc/cmdline 2>/dev/null || true
        echo "--- uname ---"
        uname -a 2>/dev/null || true
        echo "--- /sys/devices/system/cpu/vulnerabilities (if present) ---"
        if compgen -G "/sys/devices/system/cpu/vulnerabilities/*" >/dev/null 2>&1; then
            for f in /sys/devices/system/cpu/vulnerabilities/*; do
                printf '%s: %s\n' "$(basename "$f")" "$(cat "$f" 2>/dev/null || echo n/a)"
            done
        else
            echo "(vulnerability sysfs not available)"
        fi
        echo "--- dmesg RETBleed/Spectre (last 40) ---"
        dmesg 2>/dev/null | grep -iE 'retbleed|spectre|mitigation|microcode|mds|tsx' | tail -40 || true
        echo "--- journalctl -b RETBleed/Spectre (last 40) ---"
        journalctl -b --no-pager 2>/dev/null | grep -iE 'retbleed|spectre|mitigation|microcode' | tail -40 || true
        echo "--- VirtualBox guest hint ---"
        if systemd-detect-virt -q 2>/dev/null; then
            echo "virt=$(systemd-detect-virt 2>/dev/null || echo unknown)"
            echo "Guest sees host CPU features; host BIOS/microcode updates required for full mitigation."
        else
            echo "virt=none or undetected"
        fi
        echo "--- microcode packages ---"
        dpkg -l 'intel-microcode' 'amd64-microcode' 2>/dev/null | grep -E '^ii|^rc' || echo "(none installed)"
        echo ""
    } >>"$LOG_FILE"
}

analyze_and_recommend() {
    # Read the kernel's own verdict and, in a VM, point to the host-side spec-ctrl fix.
    local vuln_dir="/sys/devices/system/cpu/vulnerabilities"
    local retbleed="n/a" spectre_v2="n/a"
    [[ -r "$vuln_dir/retbleed" ]] && retbleed="$(cat "$vuln_dir/retbleed" 2>/dev/null || echo n/a)"
    [[ -r "$vuln_dir/spectre_v2" ]] && spectre_v2="$(cat "$vuln_dir/spectre_v2" 2>/dev/null || echo n/a)"
    log "retbleed: ${retbleed}"
    log "spectre_v2: ${spectre_v2}"

    local in_vm=false virt="none"
    if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -q 2>/dev/null; then
        in_vm=true
        virt="$(systemd-detect-virt 2>/dev/null || echo unknown)"
    fi

    # IBRS/IBPB-based spectre_v2 mitigation needs the IA32_SPEC_CTRL/PRED_CMD MSRs.
    # In VirtualBox these are only present when the host set: VBoxManage modifyvm <vm> --spec-ctrl on
    if printf '%s' "$retbleed" | grep -qi 'vulnerable'; then
        log "ASSESSMENT: kernel reports RETBleed VULNERABLE"
        if $in_vm; then
            log "VM detected (virt=${virt}). Most likely cause: hypervisor does not expose IA32_SPEC_CTRL/PRED_CMD MSRs."
            log "HOST FIX (VirtualBox, VM powered OFF): VBoxManage modifyvm <vm> --spec-ctrl on"
            log "  Windows helper: scripts\\windows\\Harden-KaliVmCpu.ps1 -StopVmIfRunning -StartAfter"
            log "Then ensure Windows HOST BIOS + Intel/AMD microcode are current (primary mitigation)."
        else
            log "Bare metal: update CPU microcode (intel-microcode/amd64-microcode) + BIOS, then reboot."
        fi
    elif printf '%s' "$retbleed" | grep -qiE 'mitigation|not affected'; then
        log "ASSESSMENT: RETBleed mitigated or CPU not affected — posture OK"
    fi

    if printf '%s' "$spectre_v2" | grep -qi 'retbleed'; then
        log "NOTE: spectre_v2 line references RETBleed — Spectre v2 mitigation alone leaves RETBleed exposure; see HOST FIX above."
    fi
}

audit_grub_cmdline() {
    local grub_default="/etc/default/grub"
    local issues=0
    if [[ -f "$grub_default" ]]; then
        if grep -qE '(^|[[:space:]])mitigations=off([[:space:]]|$)' "$grub_default" 2>/dev/null; then
            log "CRITICAL: mitigations=off found in $grub_default — remove immediately"
            issues=$((issues + 1))
        fi
        if grep -qE '(^|[[:space:]])retbleed=off([[:space:]]|$)' "$grub_default" 2>/dev/null; then
            log "WARNING: retbleed=off in $grub_default — prefer retbleed=auto or kernel default"
            issues=$((issues + 1))
        fi
        if ! grep -q 'retbleed=' "$grub_default" 2>/dev/null; then
            log "GRUB: retbleed not set — kernel default (usually auto) is OK; see docs/KALI_RETBLEED.md"
        fi
    fi
    if grep -qE '(^|[[:space:]])mitigations=off([[:space:]]|$)' /proc/cmdline 2>/dev/null; then
        log "CRITICAL: mitigations=off active in running kernel cmdline"
        issues=$((issues + 1))
    fi
    return "$issues"
}

install_cpu_microcode() {
    export DEBIAN_FRONTEND=noninteractive
    local vendor=""
    if grep -qi 'GenuineIntel' /proc/cpuinfo 2>/dev/null; then
        vendor="intel"
    elif grep -qi 'AuthenticAMD' /proc/cpuinfo 2>/dev/null; then
        vendor="amd"
    fi
    log "CPU vendor detected: ${vendor:-unknown}"
    apt-get update -qq
    case "$vendor" in
        intel)
            apt-get install -y --no-install-recommends intel-microcode || log "intel-microcode install failed"
            ;;
        amd)
            apt-get install -y --no-install-recommends amd64-microcode || log "amd64-microcode install failed"
            ;;
        *)
            log "Unknown CPU vendor — attempting both microcode metapackages"
            apt-get install -y --no-install-recommends intel-microcode amd64-microcode 2>/dev/null || true
            ;;
    esac
}

run_kernel_upgrade() {
    export DEBIAN_FRONTEND=noninteractive
    log "Phase: apt full-upgrade (kernel + mitigations)"
    apt-get update -qq
    apt-get full-upgrade -y
    if [[ -f /var/run/reboot-required ]]; then
        log "Reboot required after kernel upgrade — run: sudo reboot"
    fi
}

ensure_grub_mitigations_on() {
    local grub_default="/etc/default/grub"
    [[ -f "$grub_default" ]] || return 0
    if grep -qE '(^|[[:space:]])mitigations=off([[:space:]]|$)' "$grub_default"; then
        log "Removing mitigations=off from GRUB_CMDLINE_LINUX_DEFAULT"
        sed -i -E 's/[[:space:]]*mitigations=off//g' "$grub_default"
        update-grub 2>/dev/null || true
        log "update-grub completed after mitigations=off removal"
    fi
}

log "=== CTG RETBleed mitigation start (apply=$DO_APPLY) ==="
capture_mitigation_state "BEFORE"
analyze_and_recommend
audit_grub_cmdline || true

if $DO_APPLY; then
    install_cpu_microcode
    run_kernel_upgrade
    ensure_grub_mitigations_on
    capture_mitigation_state "AFTER"
    analyze_and_recommend
    log "Apply complete — reboot guest; also update Windows HOST BIOS + microcode if warnings persist in VirtualBox"
    log "If still RETBleed-vulnerable in VirtualBox: power VM off and set --spec-ctrl on (scripts\\windows\\Harden-KaliVmCpu.ps1)"
else
    log "Diagnose-only — pass --apply to install microcode and kernel upgrade"
    if audit_grub_cmdline; then
        log "GRUB/cmdline audit: OK (no mitigations=off)"
    else
        log "GRUB/cmdline audit: issues found — see log above"
    fi
fi

log "=== CTG RETBleed mitigation complete ==="
