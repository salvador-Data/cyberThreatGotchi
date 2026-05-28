#!/usr/bin/env bash
# Save current iptables rules (baseline + CTG IPS blocks) for boot persistence.
#
# Debian: installs to /etc/iptables/rules.v4 when the iptables-persistent path exists.
# OpenWrt: prints instructions — use /etc/firewall.user or fw4 include as appropriate.
#
set -euo pipefail

SAVE_PATH="${CTG_IPTABLES_SAVE_PATH:-/etc/iptables/rules.v4}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if ! command -v iptables-save >/dev/null 2>&1; then
  echo "iptables-save not found" >&2
  exit 1
fi

mkdir -p "$(dirname "$SAVE_PATH")"
iptables-save >"$SAVE_PATH"
echo "==> Saved iptables rules to ${SAVE_PATH}"

if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save || true
  echo "==> netfilter-persistent save invoked"
elif [[ -d /etc/openwrt ]]; then
  cat <<'EOF'
OpenWrt: add to /etc/firewall.user (or fw4 include) so rules load on boot:
  iptables-restore < /etc/iptables/rules.v4
Or re-run scripts/firewall-baseline.sh from a hotplug/procd init script after CTG starts.
EOF
else
  echo "Install iptables-persistent (Debian) or add iptables-restore to systemd on boot."
fi
