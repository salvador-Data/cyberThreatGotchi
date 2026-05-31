#!/usr/bin/env bash
# CTG Kali lab password policy — authorized defensive use only.
# Hacker Planet LLC · Philadelphia, PA
#
# - Max password age 120 days (chage)
# - pam_faillock: 10 failures → 30 min lockout
# - Preserves SSH public-key-only auth when already configured
#
# Usage:
#   sudo bash harden-password-policy.sh --diagnose-only
#   sudo bash harden-password-policy.sh --apply [--lab-user=sal]
set -euo pipefail

LOG_FILE="/var/log/ctg-password-policy.log"
DIAGNOSE_ONLY=true
LAB_USER="${CTG_LAB_USER:-sal}"
MAX_DAYS=120
DENY=10
UNLOCK_TIME=1800
FAIL_INTERVAL=900

log() {
    local msg="[$(date -Iseconds)] [ctg-password] $*"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

usage() {
    cat <<EOF
CTG Kali password policy — authorized lab use only.

  sudo bash $0 --diagnose-only
  sudo bash $0 --apply [--lab-user=USER]

Settings: maxdays=${MAX_DAYS} faillock deny=${DENY} unlock_time=${UNLOCK_TIME}s
Log: ${LOG_FILE}
Docs: docs/PASSWORD_HARDENING.md
Does NOT disable SSH key authentication.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --diagnose-only) DIAGNOSE_ONLY=true ;;
        --apply) DIAGNOSE_ONLY=false ;;
        --lab-user=*) LAB_USER="${1#*=}" ;;
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

ssh_keys_only() {
    local cfg="/etc/ssh/sshd_config"
    [[ -f "$cfg" ]] || return 1
    grep -qE '^[[:space:]]*PasswordAuthentication[[:space:]]+no' "$cfg" 2>/dev/null
}

report_state() {
    log "--- Password policy state ---"
    if id "$LAB_USER" &>/dev/null; then
        chage -l "$LAB_USER" 2>/dev/null | while read -r line; do log "  chage $LAB_USER: $line"; done
    else
        log "  Lab user '$LAB_USER' not found"
    fi
    if [[ -f /etc/security/faillock.conf ]]; then
        grep -vE '^#|^$' /etc/security/faillock.conf 2>/dev/null | while read -r line; do
            log "  faillock.conf: $line"
        done
    else
        log "  faillock.conf: not present"
    fi
    if ssh_keys_only; then
        log "  SSH: PasswordAuthentication no (keys-only preserved)"
    else
        log "  SSH: password auth may be enabled — faillock applies to console/GDM/SSH password"
    fi
    if command -v faillock &>/dev/null; then
        faillock --user "$LAB_USER" 2>/dev/null | while read -r line; do log "  faillock: $line"; done || true
    fi
}

apply_faillock() {
    log "Phase: pam_faillock (deny=$DENY unlock_time=${UNLOCK_TIME}s)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends libpam-modules 2>/dev/null || true

    cat >/etc/security/faillock.conf <<EOF
# CTG lab password lockout — Hacker Planet LLC
deny = ${DENY}
unlock_time = ${UNLOCK_TIME}
fail_interval = ${FAIL_INTERVAL}
audit
EOF
    chmod 644 /etc/security/faillock.conf

    # Ensure common-auth includes pam_faillock (Debian/Kali pattern)
    local common_auth="/etc/pam.d/common-auth"
    if [[ -f "$common_auth" ]] && ! grep -q 'pam_faillock.so' "$common_auth" 2>/dev/null; then
        log "Adding pam_faillock to $common_auth"
        sed -i '/^auth.*pam_unix.so/i auth    required      pam_faillock.so preauth' "$common_auth"
        sed -i '/^auth.*pam_unix.so/a auth    [default=die] pam_faillock.so authfail' "$common_auth"
    fi

    local common_account="/etc/pam.d/common-account"
    if [[ -f "$common_account" ]] && ! grep -q 'pam_faillock.so' "$common_account" 2>/dev/null; then
        echo 'account required pam_faillock.so' >>"$common_account"
    fi
}

apply_chage() {
    if ! id "$LAB_USER" &>/dev/null; then
        log "Skip chage — user $LAB_USER does not exist"
        return 0
    fi
    log "Phase: chage -M ${MAX_DAYS} for $LAB_USER"
    chage -M "$MAX_DAYS" "$LAB_USER"
    chage -W 14 "$LAB_USER" 2>/dev/null || true
}

log "=== CTG Kali password policy start (apply=$([[ $DIAGNOSE_ONLY == true ]] && echo false || echo true)) ==="
report_state

if [[ "$DIAGNOSE_ONLY" == true ]]; then
    log "Diagnose-only — pass --apply to enforce policy"
else
    apply_faillock
    apply_chage
    report_state
    log "Apply complete — store recovery in DuckDuckGo Password Manager (see docs/PASSWORD_HARDENING.md)"
fi

log "=== CTG Kali password policy complete ==="
