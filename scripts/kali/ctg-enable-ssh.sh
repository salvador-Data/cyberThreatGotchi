#!/usr/bin/env bash
# CTG Kali — enable openssh-server for VirtualBox NAT 2222->22 (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
#
# Windows: Ensure-CtgNatSsh in Deploy-KaliBootAutopatch.ps1 (port 2222).
# Sync password: kali-vm-credentials.txt OR Protect-CtgSecrets.ps1 -SetSecret KALI_SSH_PASSWORD
#
# Usage:
#   sudo bash /mnt/ctg/ctg-enable-ssh.sh
set -euo pipefail

LOG_FILE="/var/log/ctg-enable-ssh.log"

log() {
    local msg="[$(date -Iseconds)] [ctg-enable-ssh] $*"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo bash $0" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "=== CTG enable openssh-server start ==="
export DEBIAN_FRONTEND=noninteractive

if ! dpkg -s openssh-server >/dev/null 2>&1; then
    log "Installing openssh-server"
    apt-get update -qq
    apt-get install -y --no-install-recommends openssh-server
else
    log "openssh-server package present"
fi

systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null || true

st="$(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null || echo unknown)"
log "sshd status: $st"
if [[ "$st" != active ]]; then
    log "WARNING: sshd not active — check journalctl -u ssh"
    exit 1
fi

log "SSH ready for NAT forward — Windows: ssh -p 2222 USER@127.0.0.1"
log "=== CTG enable openssh-server complete ==="
