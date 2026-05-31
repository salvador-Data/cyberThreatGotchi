#!/usr/bin/env bash
# CTG Wazuh agent install stub for Kali lab guest (authorized defensive use only).
# Requires CTG_WAZUH_MANAGER env or /etc/ctg/wazuh-manager.conf (local, not in git).
set -euo pipefail

MANAGER="${CTG_WAZUH_MANAGER:-}"
CONF="/etc/ctg/wazuh-manager.conf"
LOG="${HOME}/ctg-wazuh-agent-install.log"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

if [[ -z "$MANAGER" && -f "$CONF" ]]; then
  # shellcheck source=/dev/null
  source "$CONF"
  MANAGER="${CTG_WAZUH_MANAGER:-}"
fi

if [[ -z "$MANAGER" ]]; then
  log "Set CTG_WAZUH_MANAGER or create $CONF with CTG_WAZUH_MANAGER=<host-ip>"
  log "Windows host: Install-CtgWazuhLab.ps1 -ApplySafe then wazuh_agent_setup.ps1"
  exit 1
fi

log "Wazuh manager target: $MANAGER (agent install requires root + package manager)"

if command -v wazuh-agent >/dev/null 2>&1; then
  log "wazuh-agent already installed"
  systemctl is-active wazuh-agent 2>/dev/null || true
  exit 0
fi

log "DiagnoseOnly: install wazuh-agent from Wazuh packages (see docs/LAB_MATURITY.md)"
log "  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg"
log "  WAZUH_MANAGER=$MANAGER apt install wazuh-agent"
log "No automatic install — run manually after reviewing manager IP and scope."
