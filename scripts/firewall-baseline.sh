#!/usr/bin/env bash
# CyberThreatGotchi — default-deny iptables baseline for BPI-R3 Mini (Debian / OpenWrt).
#
# Static allow-list lives in chain CTG_BASELINE. CyberThreatGotchi IPS (core/ips.py) inserts
# dynamic DROP rules at the top of INPUT via: iptables -I INPUT -s <ip> -j DROP
# Re-applying this script rebuilds CTG_BASELINE only; IPS blocks are preserved.
#
# Usage:
#   sudo CTG_WEB_PORT=8765 ./scripts/firewall-baseline.sh
#   sudo ./scripts/firewall-baseline.sh --dry-run
#   sudo ./scripts/firewall-baseline.sh --restore /etc/iptables/rules.v4
#
set -euo pipefail

CHAIN="CTG_BASELINE"
JUMP_COMMENT="CTG-firewall-baseline-jump"
CTG_WEB_PORT="${CTG_WEB_PORT:-8765}"
CTG_ALLOW_ICMP="${CTG_ALLOW_ICMP:-1}"
CTG_SSH_LAN_ONLY="${CTG_SSH_LAN_ONLY:-0}"
CTG_EXTRA_TCP_PORTS="${CTG_EXTRA_TCP_PORTS:-}"

DRY_RUN=0
RESTORE_FILE=""

usage() {
  cat <<'EOF'
CyberThreatGotchi firewall baseline — default-deny INPUT with service allow-list.

Environment:
  CTG_WEB_PORT          Web dashboard port (default 8765)
  CTG_EXTRA_TCP_PORTS   Comma-separated extra TCP ports (e.g. 9090,9091)
  CTG_ALLOW_ICMP=0      Disable inbound ICMP echo (ping)
  CTG_SSH_LAN_ONLY=1    Restrict SSH (22/tcp) to RFC1918 + link-local only

Options:
  --dry-run             Print iptables commands without applying
  --restore FILE        Restore full ruleset from iptables-save output (replaces live rules)
  -h, --help            Show this help

Persistence: run scripts/firewall-baseline-save.sh after applying.
EOF
}

log() {
  echo "==> $*"
}

run_iptables() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'iptables '
    printf '%q ' "$@"
    echo
  else
    iptables "$@"
  fi
}

ensure_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
  fi
}

have_iptables() {
  command -v iptables >/dev/null 2>&1
}

build_tcp_ports() {
  local ports=(
    22 25 53 80 443 465 5222 5269 5280
    8999:9003
    "${CTG_WEB_PORT}"
  )
  if [[ -n "$CTG_EXTRA_TCP_PORTS" ]]; then
    local IFS=','
    read -ra extra <<<"$CTG_EXTRA_TCP_PORTS"
    ports+=("${extra[@]}")
  fi
  local joined=""
  local p
  for p in "${ports[@]}"; do
    p="${p// /}"
    [[ -z "$p" ]] && continue
    if [[ -n "$joined" ]]; then
      joined+=",$p"
    else
      joined="$p"
    fi
  done
  echo "$joined"
}

remove_jump_rule() {
  while iptables -C INPUT -m comment --comment "$JUMP_COMMENT" -j "$CHAIN" 2>/dev/null; do
    run_iptables -D INPUT -m comment --comment "$JUMP_COMMENT" -j "$CHAIN"
  done
}

apply_baseline() {
  local tcp_ports
  tcp_ports="$(build_tcp_ports)"

  log "Rebuilding chain ${CHAIN} (TCP allow: ${tcp_ports})"

  run_iptables -N "$CHAIN" 2>/dev/null || true
  run_iptables -F "$CHAIN"

  run_iptables -A "$CHAIN" -m state --state ESTABLISHED,RELATED \
    -m comment --comment "CTG: established/related" -j ACCEPT
  run_iptables -A "$CHAIN" -i lo -m comment --comment "CTG: loopback" -j ACCEPT

  if [[ "$CTG_ALLOW_ICMP" != "0" ]]; then
    run_iptables -A "$CHAIN" -p icmp -m comment --comment "CTG: ping" -j ACCEPT
  fi

  if [[ "$CTG_SSH_LAN_ONLY" == "1" ]]; then
    run_iptables -A "$CHAIN" -p tcp --dport 22 -s 10.0.0.0/8 \
      -m comment --comment "CTG: SSH LAN only" -j ACCEPT
    run_iptables -A "$CHAIN" -p tcp --dport 22 -s 172.16.0.0/12 \
      -m comment --comment "CTG: SSH LAN only" -j ACCEPT
    run_iptables -A "$CHAIN" -p tcp --dport 22 -s 192.168.0.0/16 \
      -m comment --comment "CTG: SSH LAN only" -j ACCEPT
    run_iptables -A "$CHAIN" -p tcp --dport 22 -s 169.254.0.0/16 \
      -m comment --comment "CTG: SSH LAN only" -j ACCEPT
    local ssh_ports="${tcp_ports}"
    ssh_ports="${ssh_ports//22,/}"
    ssh_ports="${ssh_ports//,22/}"
    ssh_ports="${ssh_ports//22/}"
    if [[ -n "$ssh_ports" ]]; then
      run_iptables -A "$CHAIN" -p tcp -m multiport --dports "$ssh_ports" \
        -m comment --comment "CTG: baseline TCP services" -j ACCEPT
    fi
  else
    run_iptables -A "$CHAIN" -p tcp -m multiport --dports "$tcp_ports" \
      -m comment --comment "CTG: baseline TCP services" -j ACCEPT
  fi

  run_iptables -A "$CHAIN" -p tcp -s 127.0.0.1 --dport 3310 \
    -m comment --comment "CTG: ClamAV localhost" -j ACCEPT
  run_iptables -A "$CHAIN" -p udp -m multiport --dports 53 \
    -m comment --comment "CTG: DNS UDP" -j ACCEPT

  if [[ "$DRY_RUN" -eq 1 ]]; then
    run_iptables -A INPUT -m comment --comment "$JUMP_COMMENT" -j "$CHAIN"
  elif ! iptables -C INPUT -m comment --comment "$JUMP_COMMENT" -j "$CHAIN" 2>/dev/null; then
    run_iptables -A INPUT -m comment --comment "$JUMP_COMMENT" -j "$CHAIN"
  fi

  run_iptables -P INPUT DROP
  run_iptables -P FORWARD DROP
  run_iptables -P OUTPUT ACCEPT
}

restore_rules() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Restore file not found: $file" >&2
    exit 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would restore iptables rules from $file"
    head -n 20 "$file"
    echo "..."
    return
  fi
  log "Restoring iptables rules from $file"
  iptables-restore <"$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --restore)
      RESTORE_FILE="${2:-}"
      if [[ -z "$RESTORE_FILE" ]]; then
        echo "--restore requires a file path" >&2
        exit 1
      fi
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  ensure_root
fi

if ! have_iptables; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "iptables not installed — dry-run will print commands only"
  else
    echo "iptables not found — install iptables package" >&2
    exit 1
  fi
fi

if [[ -n "$RESTORE_FILE" ]]; then
  restore_rules "$RESTORE_FILE"
  exit 0
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  remove_jump_rule
fi

apply_baseline

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry run complete — no rules applied"
else
  log "Baseline applied. IPS dynamic blocks (iptables -I INPUT -s IP -j DROP) stack above this chain."
  log "Persist with: sudo $(dirname "$0")/firewall-baseline-save.sh"
fi
