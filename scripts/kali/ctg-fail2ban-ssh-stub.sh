#!/usr/bin/env bash
# Fail2ban SSH stub for Kali lab — diagnose only unless CTG_FAIL2BAN_APPLY=1.
# Authorized defensive use: protect SSH when port 22 is exposed beyond lab VLAN.
set -euo pipefail

LOG="${HOME}/ctg-fail2ban-ssh.log"
JAIL_LOCAL="/etc/fail2ban/jail.local"
SSH_PORT="${CTG_SSH_PORT:-22}"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

log "=== CTG fail2ban SSH stub ==="

if ! command -v fail2ban-client >/dev/null 2>&1; then
  log "fail2ban not installed. DiagnoseOnly:"
  log "  sudo apt install fail2ban"
  log "  sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local"
  log "  Enable [sshd] jail — maxretry=5, bantime=3600"
  exit 0
fi

if [[ -f "$JAIL_LOCAL" ]]; then
  log "jail.local exists — review [sshd] enabled=true"
  grep -E '^\[sshd\]|^enabled|^port' "$JAIL_LOCAL" 2>/dev/null | head -20 | tee -a "$LOG" || true
else
  log "No jail.local — use jail.d/sshd.local with enabled=true for port $SSH_PORT"
fi

if [[ "${CTG_FAIL2BAN_APPLY:-}" == "1" ]]; then
  log "CTG_FAIL2BAN_APPLY=1 — manual step: sudo systemctl enable --now fail2ban"
  log "Verify: sudo fail2ban-client status sshd"
else
  log "DiagnoseOnly — set CTG_FAIL2BAN_APPLY=1 after reviewing docs/LAB_MATURITY.md"
fi
