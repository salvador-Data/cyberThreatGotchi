#!/usr/bin/env bash
# CTG Gatekeeper — Firejail HTTPS sandbox browser launcher (Kali lab only).
# Authorized defensive lab use only · Hacker Planet LLC
set -euo pipefail

GK_ROOT="${CTG_GATEKEEPER_ROOT:-/opt/ctg/gatekeeper-tor}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_NAME="ctg-https-sandbox.profile"
PROFILE_SRC="${SCRIPT_DIR}/${PROFILE_NAME}"
PROFILE_ETC="/etc/firejail/${PROFILE_NAME}"
SANDBOX_TMP="/tmp/ctg-sandbox"
MOZ_PROFILE="${SANDBOX_TMP}/mozilla-profile"
MODE_FILE="${CTG_GATEKEEPER_MODE_FILE:-/var/lib/ctg/gatekeeper-mode}"
BROWSER="${CTG_SANDBOX_BROWSER:-}"

log() { printf '[ctg-https-sandbox] %s\n' "$*"; }

parse_args() {
    DIAGNOSE_ONLY=0
    LAUNCH_BROWSER=0
    for arg in "$@"; do
        case "$arg" in
            -DiagnoseOnly|--diagnose-only|-DiagnoseOnly) DIAGNOSE_ONLY=1 ;;
            -LaunchBrowser|--launch-browser|-LaunchBrowser) LAUNCH_BROWSER=1 ;;
            -h|--help)
                echo "Usage: $0 [-DiagnoseOnly] [-LaunchBrowser]"
                echo "  -DiagnoseOnly   Check firejail + profile (no browser)"
                echo "  -LaunchBrowser  firefox-esr under Firejail (HTTPS mode recommended)"
                exit 0
                ;;
        esac
    done
    if [[ "$DIAGNOSE_ONLY" -eq 0 && "$LAUNCH_BROWSER" -eq 0 ]]; then
        DIAGNOSE_ONLY=1
    fi
}

resolve_profile() {
    if [[ -f "$PROFILE_ETC" ]]; then
        echo "$PROFILE_ETC"
        return 0
    fi
    if [[ -f "$PROFILE_SRC" ]]; then
        echo "$PROFILE_SRC"
        return 0
    fi
    if [[ -f "${GK_ROOT}/kali/${PROFILE_NAME}" ]]; then
        echo "${GK_ROOT}/kali/${PROFILE_NAME}"
        return 0
    fi
    return 1
}

current_gatekeeper_mode() {
    if [[ -f "$MODE_FILE" ]]; then
        tr '[:upper:]' '[:lower:]' <"$MODE_FILE"
    else
        echo tor
    fi
}

detect_browser() {
    if [[ -n "$BROWSER" && -x "$BROWSER" ]]; then
        echo "$BROWSER"
        return 0
    fi
    for candidate in firefox-esr firefox; do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

diagnose() {
    log "=== CTG HTTPS sandbox diagnose ==="
    log "Gatekeeper root: $GK_ROOT"
    log "Scratch dir:     $SANDBOX_TMP (writable inside jail only)"
    if command -v firejail >/dev/null 2>&1; then
        log "  OK firejail: $(command -v firejail) ($(firejail --version 2>/dev/null | head -1 || true))"
    else
        log "  MISSING firejail — install: sudo apt install -y firejail"
        log "  Or: sudo $GK_ROOT/kali/install-gatekeeper-kali.sh --with-sandbox"
        return 1
    fi
    if prof="$(resolve_profile)"; then
        log "  OK profile: $prof"
    else
        log "  MISSING profile $PROFILE_NAME (expected $PROFILE_ETC or $PROFILE_SRC)"
        return 1
    fi
    mode="$(current_gatekeeper_mode)"
    log "  Gatekeeper mode: $mode"
    if [[ "$mode" != https && "$mode" != http && "$mode" != clearnet ]]; then
        log "  WARN: HTTPS mode not active — sandbox is for clearnet lab lane; run:"
        log "        sudo $GK_ROOT/gatekeeper-daemon.sh set-mode https"
    fi
    if [[ -f /var/lib/ctg/gatekeeper-tor/sandbox.env ]]; then
        log "  sandbox.env: $(tr '\n' ' ' </var/lib/ctg/gatekeeper-tor/sandbox.env)"
    fi
    if br="$(detect_browser)"; then
        log "  OK browser: $br"
    else
        log "  MISSING browser — apt install firefox-esr"
        return 1
    fi
    log "HTTPS protects the wire; Firejail contains the process. Not for banking over HTTP."
    return 0
}

launch_browser() {
    local prof br mode
    diagnose || return 1
    prof="$(resolve_profile)"
    br="$(detect_browser)"
    mode="$(current_gatekeeper_mode)"
    if [[ "$mode" != https && "$mode" != http && "$mode" != clearnet ]]; then
        log "Refusing launch: set HTTPS mode first (sudo $GK_ROOT/gatekeeper-daemon.sh set-mode https)"
        return 1
    fi
    mkdir -p "$SANDBOX_TMP" "$MOZ_PROFILE"
    chmod 700 "$SANDBOX_TMP" "$MOZ_PROFILE" 2>/dev/null || true
    export CTG_SANDBOX=1
    log "Launching $br under Firejail (profile $(basename "$prof"))"
    log "Profile dir: $MOZ_PROFILE"
    exec firejail --profile="$prof" "$br" -no-remote -profile "$MOZ_PROFILE" "$@"
}

parse_args "$@"
if [[ "$DIAGNOSE_ONLY" -eq 1 ]]; then
    diagnose
    exit $?
fi
if [[ "$LAUNCH_BROWSER" -eq 1 ]]; then
    launch_browser
fi
