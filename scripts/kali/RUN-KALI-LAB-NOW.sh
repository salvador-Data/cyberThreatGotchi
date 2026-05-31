#!/usr/bin/env bash
# RUN-KALI-LAB-NOW.sh — one paste in Kali TTY (Ctrl+Alt+F2) when SSH from Windows fails.
# Windows host stages this file via ctg-backups share (C:\Users\Owner\Backups).
# Authorized defensive lab use only — Hacker Planet LLC · Philadelphia, PA
#
# Prereqs: VirtualBox VM "kali", user sal, shared folder ctg-backups -> Backups, VRAM 128 VMSVGA.
# Disable surprise reboot (SSH): export CTG_NO_REBOOT=1 before running this script.
set -euo pipefail

CTG_MOUNT="/mnt/ctg"
LOG="/var/log/ctg-run-kali-lab-now.log"

log() {
    local msg="[$(date -Iseconds)] [run-kali-lab] $*"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >>"$LOG"
}

die() {
    log "ERROR: $*"
    exit 1
}

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Re-run as root: sudo bash $0" >&2
    exit 1
fi

mkdir -p "$CTG_MOUNT" /var/lib/ctg "$(dirname "$LOG")"

mount_ctg_share() {
    if mountpoint -q "$CTG_MOUNT" 2>/dev/null; then
        log "Already mounted: $CTG_MOUNT"
        return 0
    fi
    for share in ctg-backups ctg; do
        if mount -t vboxsf "$share" "$CTG_MOUNT" 2>/dev/null; then
            log "Mounted vboxsf $share -> $CTG_MOUNT"
            return 0
        fi
    done
    for auto in /media/sf_ctg-backups /media/sf_ctg; do
        if [[ -d "$auto" && -f "$auto/ctg-lab-autorun.sh" ]]; then
            ln -sfn "$auto" "$CTG_MOUNT"
            log "Symlink $CTG_MOUNT -> $auto"
            return 0
        fi
    done
    return 1
}

log "=== CTG RUN-KALI-LAB-NOW start ==="
mount_ctg_share || die "Could not mount ctg-backups. Power off VM; ensure VirtualBox share ctg-backups -> C:\\Users\\Owner\\Backups"

need() {
    [[ -f "$CTG_MOUNT/$1" ]] || die "Missing $CTG_MOUNT/$1 — re-run Stage-KaliLabToBackups.ps1 on Windows"
}

need kali-boot-autopatch.sh
need ctg-lab-autorun.sh
need ctg-reboot-if-needed.sh
need kali-lab-bootstrap.sh

if [[ -f "$CTG_MOUNT/ctg-enable-ssh.sh" ]]; then
    log "Phase 0a: openssh-server (Windows SSH 127.0.0.1:2222)"
    bash "$CTG_MOUNT/ctg-enable-ssh.sh" || log "ctg-enable-ssh returned non-zero (continuing)"
fi

if [[ -f "$CTG_MOUNT/fix-kali-blank-screen.sh" ]]; then
    log "Phase 0: blank-screen / GDM X11 fix (non-fatal)"
    bash "$CTG_MOUNT/fix-kali-blank-screen.sh" || log "blank-screen fix returned non-zero (continuing)"
fi

if [[ ! -f /etc/ctg/lab-wifi.conf && -f "$CTG_MOUNT/lab-wifi.conf.example" ]]; then
    log "Seeding /etc/ctg/lab-wifi.conf from example (edit SSID/PSK before WiFi lab)"
    mkdir -p /etc/ctg
    cp "$CTG_MOUNT/lab-wifi.conf.example" /etc/ctg/lab-wifi.conf
    chmod 600 /etc/ctg/lab-wifi.conf
fi

if [[ ! -f /etc/ctg/lab-targets.conf && -f "$CTG_MOUNT/lab-targets.example" ]]; then
    log "Seeding /etc/ctg/lab-targets.conf from example"
    cp "$CTG_MOUNT/lab-targets.example" /etc/ctg/lab-targets.conf
    chmod 644 /etc/ctg/lab-targets.conf
fi

log "Phase 1: boot autopatch one-time install (Guest Additions, GDM, systemd unit)"
CTG_SKIP_AUTO_REBOOT=1 bash "$CTG_MOUNT/kali-boot-autopatch.sh" --install --wifi-lab --ids-ips --siem --optimize || \
    log "boot autopatch --install returned non-zero (continuing)"


CTG_DESKTOP_USER="${SUDO_USER:-sal}"
run_gui_as_user() {
    if ! id "$CTG_DESKTOP_USER" &>/dev/null; then
        log "Skip GUI helper (user $CTG_DESKTOP_USER missing)"
        return 0
    fi
    local home disp xauth
    home="$(getent passwd "$CTG_DESKTOP_USER" | cut -d: -f6)"
    disp="${DISPLAY:-:0}"
    xauth="${XAUTHORITY:-$home/.Xauthority}"
    sudo -u "$CTG_DESKTOP_USER" env DISPLAY="$disp" XAUTHORITY="$xauth" "$@" || log "GUI step returned non-zero (continuing)"
}

if [[ -f "$CTG_MOUNT/ctg-display-scale.sh" ]]; then
    log "Phase 1b: ctg-display-scale.sh --fit-window --cursor-neon"
    run_gui_as_user bash "$CTG_MOUNT/ctg-display-scale.sh" --fit-window --cursor-neon
    log "Phase 1c: ctg-display-scale.sh --login-scale (greeter)"
    bash "$CTG_MOUNT/ctg-display-scale.sh" --login-scale || log "login-scale non-fatal (continuing)"
else
    log "Skip display-scale - not on share"
fi

if [[ -f "$CTG_MOUNT/ctg-seamless-guest.sh" ]]; then
    log "Phase 1d: ctg-seamless-guest.sh"
    run_gui_as_user bash "$CTG_MOUNT/ctg-seamless-guest.sh" || bash "$CTG_MOUNT/ctg-seamless-guest.sh" || log "seamless-guest non-fatal"
fi

log "Phase 1e: systemctl enable --now ssh"
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || log "ssh enable returned non-zero (continuing)"

if [[ -f "$CTG_MOUNT/tor-http-scrambler/install-scrambler.sh" ]]; then
    log "Phase 2: tor-http-scrambler install"
    bash "$CTG_MOUNT/tor-http-scrambler/install-scrambler.sh" || log "install-scrambler returned non-zero (continuing)"
fi

if [[ -f "$CTG_MOUNT/gatekeeper-tor/kali/install-gatekeeper-kali.sh" ]]; then
    log "Phase 2b: Gatekeeper.TOR install"
    bash "$CTG_MOUNT/gatekeeper-tor/kali/install-gatekeeper-kali.sh" || log "install-gatekeeper returned non-zero (continuing)"
fi

if [[ -f "$CTG_MOUNT/gatekeeper-tor/kali/install-gatekeeper-kali.sh" ]]; then
    log "Phase 2b: Gatekeeper.TOR install"
    bash "$CTG_MOUNT/gatekeeper-tor/kali/install-gatekeeper-kali.sh" || log "install-gatekeeper returned non-zero (continuing)"
fi

log "Phase 3: full lab autorun (bootstrap, WiFi/IDS/SIEM, tor, scrambler)"
export CTG_SKIP_AUTO_REBOOT=1
bash "$CTG_MOUNT/ctg-lab-autorun.sh" || die "ctg-lab-autorun.sh failed"


if [[ -f "$CTG_MOUNT/ctg-retbleed-check.sh" ]]; then
    log "Phase verify-a: ctg-retbleed-check.sh"
    bash "$CTG_MOUNT/ctg-retbleed-check.sh" || log "retbleed check reported action (continuing)"
fi
if [[ -f "$CTG_MOUNT/ctg-ram-mitigation-enforcer.sh" ]]; then
    log "Phase verify-b: ctg-ram-mitigation-enforcer.sh --diagnose-only"
    bash "$CTG_MOUNT/ctg-ram-mitigation-enforcer.sh" --diagnose-only || log "ram-mitigation diagnose non-fatal"
fi
if [[ -x /usr/local/bin/ctg-nmap-ask ]]; then
    log "Phase verify-c: ctg-nmap-ask --help"
    if /usr/local/bin/ctg-nmap-ask --help >/dev/null 2>&1; then
        log "nmap-ask --help: OK"
    else
        log "nmap-ask --help failed"
    fi
elif [[ -f "$CTG_MOUNT/ctg-nmap-ask.sh" ]]; then
    log "Phase verify-c: ctg-nmap-ask.sh --help (from share)"
    if bash "$CTG_MOUNT/ctg-nmap-ask.sh" --help >/dev/null 2>&1; then
        log "nmap-ask --help: OK"
    else
        log "nmap-ask --help failed"
    fi
fi
if [[ -f "$CTG_MOUNT/ctg-ids-ips-autorun.sh" ]]; then
    log "Phase verify-d: ctg-ids-ips-autorun (also via ctg-lab-autorun Phase 3)"
fi
if [[ -f "$CTG_MOUNT/ctg-wifi-event-emit.sh" ]]; then
    log "Phase verify-e: ctg-wifi-event-emit.sh --diagnose"
    bash "$CTG_MOUNT/ctg-wifi-event-emit.sh" --diagnose || log "wifi-event-emit diagnose non-fatal"
fi
if [[ -f "$CTG_MOUNT/ctg-deauth-watch.sh" ]]; then
    log "Phase verify-f: ctg-deauth-watch.sh --diagnose"
    bash "$CTG_MOUNT/ctg-deauth-watch.sh" --diagnose || log "deauth-watch diagnose non-fatal"
fi
if [[ -f "$CTG_MOUNT/ctg-lab-ap-setup.sh" ]]; then
    log "Phase verify-g: ctg-lab-ap-setup.sh --diagnose"
    bash "$CTG_MOUNT/ctg-lab-ap-setup.sh" --diagnose || log "lab-ap-setup diagnose non-fatal"
fi
log "=== Verify ==="
for svc in ctg-kali-autopatch.service tor ctg-wifi-lab.service ctg-ids-ips.service; do
    st="$(systemctl is-active "$svc" 2>/dev/null || echo inactive)"
    log "  $svc: $st"
done
if [[ -x /opt/ctg/tor-http-scrambler/scrambler-daemon.sh ]]; then
    log "  scrambler: $(/opt/ctg/tor-http-scrambler/scrambler-daemon.sh status 2>/dev/null || echo unknown)"
fi
if bash "$CTG_MOUNT/ctg-reboot-if-needed.sh" --check 2>/dev/null; then
    log "REBOOT RECOMMENDED — Ctrl+Alt+F1 GUI or: sudo reboot"
    if [[ "${CTG_NO_REBOOT:-}" != "1" ]]; then
        log "Scheduling reboot in 1 minute (CTG_NO_REBOOT=1 to skip)"
        bash "$CTG_MOUNT/ctg-reboot-if-needed.sh" --auto-reboot || true
    fi
else
    log "No reboot required"
fi

log "=== Done ==="
log "GUI:  python3 /opt/ctg/tor-http-scrambler/ctg-scrambler-gui.py"
log "Playground: sudo bash $CTG_MOUNT/ctg-lab-playground.sh"
log "Windows tail SIEM: Backups\\logs\\siem\\ctg-siem-latest.json"
log "Docs on share: $CTG_MOUNT/CTG_LAB_AUTORUN.md"
