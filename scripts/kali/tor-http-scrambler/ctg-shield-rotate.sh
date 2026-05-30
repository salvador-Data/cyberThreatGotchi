#!/usr/bin/env bash
# CTG Shield — display and rotate lab USB WiFi IP/MAC (authorized defensive lab only).
# Hacker Planet LLC · Philadelphia, PA · CyberThreatGotchi
#
# IP refresh: DuckDuckGo VPN reconnect (if present) → scrambler tor/http cycle → dhclient renew.
# MAC rotate: macchanger or ip link — USB wlan adapters only (never blind eth0 spoof).
# Preserves DuckDuckGo DNS (94.140.14.14 / 94.140.15.15) in resolv.conf when configured.
# v1: always manual or SIEM y/n prompt — no silent WAN auto-rotate on production sessions.
set -euo pipefail

CTG_ROOT="${CTG_SCRAMBLER_ROOT:-/opt/ctg/tor-http-scrambler}"
DAEMON="${CTG_ROOT}/scrambler-daemon.sh"
MODE_FILE="${CTG_SCRAMBLER_MODE_FILE:-/var/lib/ctg/scrambler-mode}"
STATE_DIR="${CTG_SHIELD_STATE_DIR:-/var/lib/ctg/shield}"
LAST_ALERT_FILE="$STATE_DIR/last-alert.txt"
LAST_ROTATE_FILE="$STATE_DIR/last-rotate.txt"
LOG_FILE="${CTG_SHIELD_LOG:-/var/log/ctg-shield.log}"
DDG_PRIMARY="94.140.14.14"
DDG_SECONDARY="94.140.15.15"
LAB_IFACE="${CTG_LAB_WLAN_IFACE:-}"

log() {
    printf '[ctg-shield] %s\n' "$*" | tee -a "$LOG_FILE" 2>/dev/null || printf '[ctg-shield] %s\n' "$*"
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/ctg-shield.log"
}

resolv_has_ddg() {
    [[ -f /etc/resolv.conf ]] && grep -qE '94\.140\.(14\.14|15\.15)' /etc/resolv.conf
}

preserve_ddg_dns() {
    if resolv_has_ddg; then
        log "preserve-ddg-dns: DuckDuckGo nameservers unchanged in /etc/resolv.conf"
        return 0
    fi
    if [[ -f "$STATE_DIR/resolv.conf.ddg-backup" ]]; then
        log "Restoring DDG resolv.conf from lab backup marker"
        cp -f "$STATE_DIR/resolv.conf.ddg-backup" /etc/resolv.conf 2>/dev/null || true
        return 0
    fi
    log "preserve-ddg-dns: no DDG in resolv.conf — leaving resolver as-is (use bootstrap --ddg-dns-only if needed)"
}

backup_ddg_resolv_if_needed() {
    if resolv_has_ddg && [[ ! -f "$STATE_DIR/resolv.conf.ddg-backup" ]]; then
        cp -f /etc/resolv.conf "$STATE_DIR/resolv.conf.ddg-backup" 2>/dev/null || true
        log "Backed up resolv.conf with DDG entries to $STATE_DIR/resolv.conf.ddg-backup"
    fi
}

is_usb_wlan() {
    local iface="$1"
    local devpath real
    [[ "$iface" =~ ^wlan ]] || return 1
    devpath="/sys/class/net/$iface/device"
    [[ -e "$devpath" ]] || return 1
    real="$(readlink -f "$devpath" 2>/dev/null)" || return 1
    [[ "$real" == *usb* ]]
}

detect_lab_iface() {
    if [[ -n "$LAB_IFACE" ]]; then
        echo "$LAB_IFACE"
        return
    fi
    local iface devpath real
    for iface in /sys/class/net/wlan*; do
        [[ -e "$iface" ]] || continue
        iface="${iface##*/}"
        if is_usb_wlan "$iface"; then
            echo "$iface"
            return
        fi
    done
    for iface in /sys/class/net/wlan*; do
        [[ -e "$iface" ]] || continue
        echo "${iface##*/}"
        return
    done
    echo ""
}

iface_ip() {
    local iface="$1"
    ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1
}

iface_mac() {
    local iface="$1"
    ip link show "$iface" 2>/dev/null | awk '/link\/ether/ {print $2; exit}'
}

record_rotate() {
    ensure_state_dir
    date -Iseconds >"$LAST_ROTATE_FILE"
}

try_ddg_vpn_reconnect() {
    if command -v nmcli >/dev/null 2>&1; then
        local uuid name
        while IFS= read -r line; do
            name="${line%%:*}"
            uuid="${line##*:}"
            if [[ "$name" =~ [Dd]uck[Dd]uck[Gg]o|[Dd][Dd][Gg] ]]; then
                log "Reconnecting NetworkManager profile: $name"
                nmcli connection down "$uuid" 2>/dev/null || true
                sleep 2
                nmcli connection up "$uuid" 2>/dev/null || true
                return 0
            fi
        done < <(nmcli -t -f NAME,UUID connection show 2>/dev/null | grep -iE 'duck|ddg' || true)
    fi
    if command -v wg-quick >/dev/null 2>&1; then
        for conf in /etc/wireguard/*.conf; do
            [[ -f "$conf" ]] || continue
            if grep -qi duck "$conf" 2>/dev/null; then
                local ifn
                ifn="$(basename "$conf" .conf)"
                log "Cycling WireGuard interface $ifn (DDG-style profile)"
                wg-quick down "$ifn" 2>/dev/null || true
                sleep 1
                wg-quick up "$ifn" 2>/dev/null || true
                return 0
            fi
        done
    fi
    return 1
}

cycle_scrambler_mode() {
    if [[ ! -x "$DAEMON" ]]; then
        return 1
    fi
    local mode newmode
    mode="tor"
    if [[ -f "$MODE_FILE" ]]; then
        mode="$(tr -d '[:space:]' <"$MODE_FILE")"
    fi
    case "$mode" in
        tor) newmode="http" ;;
        http) newmode="tor" ;;
        *) newmode="tor" ;;
    esac
    "$DAEMON" set-mode "$newmode"
    sleep 2
    "$DAEMON" set-mode "$mode"
    log "Scrambler path cycled $mode → $newmode → $mode (lab routing refresh)"
}

renew_dhcp() {
    local iface="$1"
    if command -v dhclient >/dev/null; then
        dhclient -r "$iface" 2>/dev/null || true
        sleep 1
        dhclient -v "$iface" 2>/dev/null || dhclient "$iface" 2>/dev/null || true
        log "dhclient renew on $iface"
        return 0
    fi
    if command -v nmcli >/dev/null; then
        nmcli device reapply "$iface" 2>/dev/null || nmcli device connect "$iface" 2>/dev/null || true
        log "nmcli reapply/connect on $iface"
        return 0
    fi
    return 1
}

cmd_status() {
    ensure_state_dir
    local iface ip mac usb
    iface="$(detect_lab_iface)"
    if [[ -z "$iface" ]]; then
        echo "iface=none"
        echo "note=No wlan interface — attach USB WiFi or set CTG_LAB_WLAN_IFACE"
        exit 0
    fi
    ip="$(iface_ip "$iface" || true)"
    mac="$(iface_mac "$iface" || true)"
    usb="no"
    is_usb_wlan "$iface" && usb="yes"
    echo "iface=$iface"
    echo "usb_wlan=$usb"
    echo "ip=${ip:-—}"
    echo "mac=${mac:-—}"
    if resolv_has_ddg; then echo "ddg_dns=preserved"; else echo "ddg_dns=none"; fi
    echo "scrambler_mode=$(cat "$MODE_FILE" 2>/dev/null || echo tor)"
    if [[ -f "$LAST_ROTATE_FILE" ]]; then
        echo "last_rotate=$(cat "$LAST_ROTATE_FILE")"
    fi
    if [[ -f "$LAST_ALERT_FILE" ]]; then
        echo "last_alert_file=$LAST_ALERT_FILE"
        echo "--- last_alert ---"
        tail -n 3 "$LAST_ALERT_FILE" 2>/dev/null || true
    fi
}

rotate_mac() {
    local iface="$1"
    if [[ -z "$iface" ]]; then
        log "MAC rotate skipped — no lab wlan interface"
        return 1
    fi
    if ! is_usb_wlan "$iface"; then
        log "BLOCKED: $iface is not a USB wlan adapter — MAC rotate refused (lab USB only)"
        log "Override only for owned lab hardware: export CTG_LAB_WLAN_IFACE=$iface after USB attach"
        return 1
    fi
    ip link set "$iface" down 2>/dev/null || true
    if command -v macchanger >/dev/null; then
        macchanger -r "$iface" 2>/dev/null || macchanger -A "$iface" 2>/dev/null || true
        log "macchanger applied on $iface"
    else
        local rnd
        rnd="$(printf '02:%02x:%02x:%02x:%02x:%02x' \
            $(( RANDOM % 256 )) $(( RANDOM % 256 )) $(( RANDOM % 256 )) \
            $(( RANDOM % 256 )) $(( RANDOM % 256 )) $(( RANDOM % 256 )))"
        ip link set "$iface" address "$rnd" 2>/dev/null || true
        log "ip link random MAC (locally administered) on $iface"
    fi
    ip link set "$iface" up 2>/dev/null || true
    log "MAC after rotate: $(iface_mac "$iface" || echo unknown)"
}

rotate_ip() {
    local iface="$1"
    backup_ddg_resolv_if_needed
    try_ddg_vpn_reconnect || log "No DDG VPN profile on guest — trying scrambler/dhclient path"
    cycle_scrambler_mode || true
    if [[ -n "$iface" ]]; then
        renew_dhcp "$iface" || true
    fi
    preserve_ddg_dns
}

cmd_rotate() {
    ensure_state_dir
    local iface
    iface="$(detect_lab_iface)"
    log "=== CTG Shield rotate (authorized lab USB wlan) iface=${iface:-none} ==="
    rotate_ip "$iface"
    rotate_mac "$iface" || true
    record_rotate
    cmd_status
}

cmd_record_alert() {
    ensure_state_dir
    if [[ -n "${2:-}" ]]; then
        printf '%s\n' "$2" >"$LAST_ALERT_FILE"
    elif [[ ! -t 0 ]]; then
        cat >"$LAST_ALERT_FILE"
    fi
    log "Recorded last alert snippet to $LAST_ALERT_FILE"
}

usage() {
    cat <<EOF
Usage: $0 {status|rotate|record-alert [line]}

  status       Show lab USB wlan IP/MAC, DDG DNS preserve state, last rotate
  rotate       Refresh IP path + rotate MAC on USB wlan only (manual / SIEM y/n)
  record-alert Store last high-severity IDS line for GUI/SIEM

Environment:
  CTG_LAB_WLAN_IFACE   Force lab wlan (must be USB wlan for MAC rotate unless lab-owned)
  CTG_SCRAMBLER_ROOT   Default /opt/ctg/tor-http-scrambler

Authorized defensive lab only — Hacker Planet LLC. v1 requires prompt; no silent WAN evasion.
EOF
}

main() {
    local cmd="${1:-status}"
    case "$cmd" in
        status) cmd_status ;;
        rotate) cmd_rotate ;;
        record-alert) cmd_record_alert "$@" ;;
        -h|--help) usage ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
