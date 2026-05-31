#!/usr/bin/env bash
# CTG Kali guest — mount VirtualBox share ctg-backups at /mnt/ctg (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Run before any /mnt/ctg/*.sh step (display-scale, seamless-guest, lab autorun):
#   sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
#   sudo bash /mnt/ctg/ctg-mount-share.sh
# Pre-flight only (no mount):
#   bash /media/sf_ctg-backups/ctg-mount-share.sh --check-only
set -uo pipefail

SHARE_PRIMARY="${CTG_VBOX_SHARE:-ctg-backups}"
SHARE_FALLBACK="${CTG_VBOX_SHARE_ALT:-ctg}"
MOUNT_POINT="${CTG_MOUNT:-/mnt/ctg}"
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --check-only|--check) CHECK_ONLY=true ;;
        -h|--help)
            echo "Usage: sudo bash $(basename "$0") [--check-only]"
            echo "  Mounts vboxsf $SHARE_PRIMARY (or $SHARE_FALLBACK) at $MOUNT_POINT."
            echo "  --check-only  Report mount/share state; do not mount."
            exit 0
            ;;
    esac
done

log() { printf '[ctg-mount-share] %s\n' "$*"; }
err() { printf '[ctg-mount-share] ERROR: %s\n' "$*" >&2; }

need_root_to_mount() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

vboxsf_available() {
    grep -q vboxsf /proc/filesystems 2>/dev/null || [[ -d /media/sf_ctg-backups || -d /media/sf_ctg ]]
}

try_mount_vboxsf() {
    local share="$1"
    if ! need_root_to_mount; then
        err "Need root to mount: sudo bash $0"
        return 1
    fi
    mkdir -p "$MOUNT_POINT"
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        log "Already mounted: $MOUNT_POINT"
        return 0
    fi
    if mount -t vboxsf "$share" "$MOUNT_POINT" 2>/dev/null; then
        log "Mounted vboxsf $share -> $MOUNT_POINT"
        return 0
    fi
    return 1
}

try_automount_symlink() {
    local auto
    for auto in /media/sf_ctg-backups /media/sf_ctg; do
        if [[ -d "$auto" ]]; then
            if [[ -f "$auto/ctg-lab-autorun.sh" || -f "$auto/ctg-mount-share.sh" || -f "$auto/kali-boot-autopatch.sh" ]]; then
                if need_root_to_mount; then
                    ln -sfn "$auto" "$MOUNT_POINT" 2>/dev/null && log "Linked $MOUNT_POINT -> $auto (VBox auto-mount)" && return 0
                elif [[ -r "$auto/ctg-lab-autorun.sh" ]]; then
                    log "VBox auto-mount OK at $auto (use: bash $auto/...)"
                    return 0
                fi
            fi
        fi
    done
    return 1
}

verify_staged_scripts() {
    local missing=0
    for f in ctg-display-scale.sh ctg-seamless-guest.sh kali-boot-autopatch.sh ctg-first-login-autorun.sh ctg-watch-trigger.sh; do
        if [[ ! -f "$MOUNT_POINT/$f" && ! -f "/media/sf_ctg-backups/$f" ]]; then
            err "Missing on share: $f — on Windows run Stage-KaliLabToBackups.ps1"
            missing=$((missing + 1))
        fi
    done
    [[ $missing -eq 0 ]]
}

print_check() {
    log "=== CTG mount pre-flight ==="
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        log "mountpoint $MOUNT_POINT: YES"
        ls -la "$MOUNT_POINT/ctg-display-scale.sh" "$MOUNT_POINT/ctg-seamless-guest.sh" 2>/dev/null \
            || err "Share mounted but ctg-display-scale.sh / ctg-seamless-guest.sh not found (re-stage on Windows)"
    elif [[ -L "$MOUNT_POINT" && -d "$(readlink -f "$MOUNT_POINT" 2>/dev/null)" ]]; then
        log "Symlink $MOUNT_POINT -> $(readlink -f "$MOUNT_POINT")"
    elif [[ -d /media/sf_ctg-backups ]]; then
        log "VBox auto-mount: /media/sf_ctg-backups (run: sudo bash /media/sf_ctg-backups/ctg-mount-share.sh)"
    else
        err "Not mounted. Guest Additions + share ctg-backups required."
        err "Windows: VM must be running; share -> C:\\Users\\Owner\\Backups"
        err "Then: sudo bash /media/sf_ctg-backups/ctg-mount-share.sh"
    fi
    if ! vboxsf_available; then
        err "vboxsf not available — install Guest Additions: sudo bash $MOUNT_POINT/kali-boot-autopatch.sh --install"
    fi
    who | grep -qE '\(:[0-9]+\)' && log "GUI session: yes ($(who | awk '/\(:[0-9]+\)/{print $1; exit}'))" \
        || err "No GUI login yet — log into Xfce before ctg-display-scale / ctg-seamless-guest"
}

if $CHECK_ONLY; then
    print_check
    exit 0
fi

if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    verify_staged_scripts || exit 1
    log "OK: $MOUNT_POINT ready"
    exit 0
fi

if try_automount_symlink; then
    verify_staged_scripts || exit 1
    exit 0
fi

if try_mount_vboxsf "$SHARE_PRIMARY"; then
    verify_staged_scripts || exit 1
    exit 0
fi

if try_mount_vboxsf "$SHARE_FALLBACK"; then
    verify_staged_scripts || exit 1
    exit 0
fi

err "Mount failed for $SHARE_PRIMARY and $SHARE_FALLBACK."
if ! vboxsf_available; then
    err "Protocol error / unknown filesystem type vboxsf → install VirtualBox Guest Additions, reboot, retry."
fi
err "No such file on $MOUNT_POINT → run Stage-KaliLabToBackups.ps1 on Windows (VM can stay running)."
err "Permission denied → use: sudo bash ... not ./script.sh"
print_check
exit 1
