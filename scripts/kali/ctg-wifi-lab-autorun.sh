#!/usr/bin/env bash
# CTG WiFi + Ethernet lab autorun — Realtek USB dongle, lab WPA3-SAE (WPA2 fallback), promisc/monitor.
# Authorized lab / own network only — Hacker Planet LLC · Philadelphia, PA
#
# Usage:
#   sudo bash ctg-wifi-lab-autorun.sh
#   sudo bash ctg-wifi-lab-autorun.sh --monitor
#   sudo bash ctg-wifi-lab-autorun.sh --install
#   sudo bash ctg-wifi-lab-autorun.sh --ddg-dns-only
set -euo pipefail

LOG_FILE="/var/log/ctg-wifi-lab.log"
CONF="/etc/ctg/lab-wifi.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBOOT_HELPER="${SCRIPT_DIR}/ctg-reboot-if-needed.sh"
SERVICE_NAME="ctg-wifi-lab.service"
UNIT_DEST="/etc/systemd/system/${SERVICE_NAME}"
DDG_PRIMARY="94.140.14.14"
DDG_SECONDARY="94.140.15.15"

DO_MONITOR=false
DO_INSTALL=false
DO_DDG_DNS_ONLY=false

# Known Realtek USB IDs → rtl8812au family (company-lab profile)
REALTEK_KNOWN_VIDPIDS=(
    0bda:8812 0bda:881a 0bda:881b 0bda:8821
    0bda:8179 0bda:818b 0bda:818c 0bda:b812
)

log() {
    local msg="[$(date -Iseconds)] [ctg-wifi-lab] $*"
    printf '%s\n' "$msg"
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s\n' "$msg" >>"$LOG_FILE"
}

ctg_reboot_helper() {
    local helper="$REBOOT_HELPER"
    for candidate in /mnt/ctg/ctg-reboot-if-needed.sh /opt/ctg/ctg-reboot-if-needed.sh; do
        if [[ -f "$candidate" ]]; then
            helper="$candidate"
            break
        fi
    done
    [[ -f "$helper" ]] || return 0
    bash "$helper" "$@" || true
}

usage() {
    cat <<EOF
CTG WiFi lab autorun — authorized defensive lab use only.

  sudo bash $0                    Detect dongle, connect lab WiFi, eth promisc if cabled
  sudo bash $0 --monitor          Also start airmon-ng monitor on USB wlan
  sudo bash $0 --install          Install ${SERVICE_NAME} for boot
  sudo bash $0 --ddg-dns-only     Set resolv.conf to DuckDuckGo (default: preserve existing)
  sudo bash $0 --help

Config: ${CONF} (from lab-wifi.conf.example, mode 600)
Log: ${LOG_FILE}
Docs: docs/KALI_WIFI_ETH_PROMISC.md
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --monitor) DO_MONITOR=true ;;
        --install) DO_INSTALL=true ;;
        --ddg-dns-only) DO_DDG_DNS_ONLY=true ;;
        --help|-h) usage; exit 0 ;;
        *) log "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "${CTG_WIFI_MONITOR:-0}" == "1" ]]; then
    DO_MONITOR=true
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

mkdir -p /etc/ctg "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "=== CTG WiFi lab autorun start (monitor=$DO_MONITOR) ==="

resolv_has_ddg() {
    [[ -f /etc/resolv.conf ]] && grep -qE '94\.140\.(14\.14|15\.15)' /etc/resolv.conf
}

preserve_or_set_ddg_dns() {
    if $DO_DDG_DNS_ONLY; then
        log "DDG DNS: --ddg-dns-only — setting nameservers to DuckDuckGo"
        cat >/etc/resolv.conf <<EOF
# CTG lab WiFi autorun — DuckDuckGo DNS
nameserver ${DDG_PRIMARY}
nameserver ${DDG_SECONDARY}
EOF
        chmod 644 /etc/resolv.conf
        return 0
    fi
    if resolv_has_ddg; then
        log "DDG preserve: DuckDuckGo already in resolv.conf — no change"
        return 0
    fi
    if [[ -f /etc/unbound/unbound.conf.d/ctg-ddg-forward.conf ]]; then
        log "DDG preserve: Unbound ctg-ddg-forward.conf present — no change"
        return 0
    fi
    log "DDG preserve: no DDG detected — leaving resolv.conf unchanged"
}

load_lab_wifi_config() {
    CTG_LAB_WIFI_SSID="${CTG_LAB_WIFI_SSID:-}"
    CTG_LAB_WIFI_PSK="${CTG_LAB_WIFI_PSK:-}"
    CTG_LAB_WIFI_KEY_MGMT="${CTG_LAB_WIFI_KEY_MGMT:-wpa3}"
    if [[ -f "$CONF" ]]; then
        # shellcheck source=/dev/null
        source "$CONF"
        chmod 600 "$CONF" 2>/dev/null || true
        log "Loaded lab WiFi config from $CONF"
    else
        log "No $CONF — skip WPA connect (copy lab-wifi.conf.example)"
    fi
}

realtek_lsusb_present() {
    lsusb 2>/dev/null | grep -qiE 'realtek|0bda:'
}

get_realtek_vidpid() {
    lsusb 2>/dev/null | grep -iE '0bda:' | head -1 | awk '{print $6}' || true
}

vidpid_is_known() {
    local vidpid="$1" known
    for known in "${REALTEK_KNOWN_VIDPIDS[@]}"; do
        [[ "$vidpid" == "$known" ]] && return 0
    done
    if [[ -f "$SCRIPT_DIR/ansible/group_vars/realtek.yml" ]]; then
        local yml_vid
        yml_vid="$(grep -E '^realtek_vidpid:' "$SCRIPT_DIR/ansible/group_vars/realtek.yml" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || true)"
        [[ -n "$yml_vid" && "$vidpid" == "$yml_vid" ]] && return 0
    fi
    return 1
}

install_realtek_oot_driver() {
    local vidpid="$1"
    if ! vidpid_is_known "$vidpid"; then
        log "Realtek $vidpid — no automated OOT driver mapping"
        return 0
    fi
    log "Known Realtek $vidpid — ensuring rtl88xxau DKMS (company-lab)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -qq dkms build-essential "linux-headers-$(uname -r)" git usbutils \
        wireless-tools iw wpasupplicant 2>/dev/null || true
    if lsmod 2>/dev/null | grep -qE '88xxau|8812au|rtl88'; then
        log "Realtek driver module already loaded"
        return 0
    fi
    if [[ ! -d /usr/src/rtl88xxau ]]; then
        git clone --depth 1 https://github.com/aircrack-ng/rtl8812au.git /usr/src/rtl88xxau 2>/dev/null || \
            log "rtl8812au clone failed — check network and headers"
    fi
    if [[ -d /usr/src/rtl88xxau ]]; then
        if make -C /usr/src/rtl88xxau dkms_install 2>/dev/null; then
            ctg_reboot_helper --mark
        else
            log "DKMS install failed — verify linux-headers-$(uname -r)"
        fi
        modprobe 88xxau 2>/dev/null || modprobe rtl8812au 2>/dev/null || true
    fi
}

# USB wlan: type wlan, not typical VM eth names; prefer interface with Realtek phy
detect_usb_wlan_iface() {
    local dev phy bus
    while read -r dev; do
        [[ -z "$dev" ]] && continue
        [[ "$dev" =~ ^(eth|enp|eno|ens|em|docker|veth|lo|virbr|vb|wlan0$) ]] && continue
        if iw dev "$dev" info 2>/dev/null | grep -q 'type managed'; then
            phy="$(readlink -f "/sys/class/net/${dev}/device" 2>/dev/null || true)"
            bus="$(readlink -f "/sys/class/net/${dev}/device/../.." 2>/dev/null || true)"
            if [[ "$phy" == *usb* ]] || [[ "$bus" == *usb* ]]; then
                echo "$dev"
                return 0
            fi
        fi
    done < <(iw dev 2>/dev/null | awk '/Interface/ {print $2}')
    # Fallback: second+ wlan* (wlan0 often = VirtualBox NAT)
    local n=0
    while read -r dev; do
        [[ -z "$dev" ]] && continue
        n=$((n + 1))
        if [[ $n -ge 2 ]]; then
            echo "$dev"
            return 0
        fi
    done < <(iw dev 2>/dev/null | awk '/Interface/ {print $2}')
    iw dev 2>/dev/null | awk '/Interface/ {print $2}' | grep -E '^wlan' | tail -1
}

detect_wired_iface() {
    local dev
    for dev in eth0 enp0s3 enp0s8 ens33; do
        if [[ -d "/sys/class/net/$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done
    ip -o link show 2>/dev/null | awk -F': ' '{gsub(/@.*/,"",$2); print $2}' | \
        grep -E '^(eth|enp|eno|ens)' | head -1
}

iface_link_up() {
    local dev="$1"
    [[ -n "$dev" ]] && ip link show "$dev" 2>/dev/null | grep -q 'state UP'
}

normalize_key_mgmt_mode() {
    local raw="${1:-wpa3}"
    raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' _-')"
    case "$raw" in
        wpa3|wpa3sae|sae) echo "wpa3" ;;
        wpa2|wpa2psk|psk) echo "wpa2" ;;
        wpa2wpa3|transition) echo "wpa2wpa3" ;;
        *)
            log "Unknown CTG_LAB_WIFI_KEY_MGMT=$1 — defaulting to wpa3"
            echo "wpa3"
            ;;
    esac
}

phy_supports_sae() {
    local wlan="$1"
    local wiphy phy_name
    wiphy="$(iw dev "$wlan" info 2>/dev/null | awk '/wiphy/ {print $2}' || true)"
    if [[ -n "$wiphy" ]]; then
        phy_name="phy${wiphy}"
        if iw phy "$phy_name" info 2>/dev/null | grep -qiE 'SAE|Device supports SAE'; then
            return 0
        fi
    fi
    if iw phy 2>/dev/null | grep -qiE 'SAE|Device supports SAE'; then
        return 0
    fi
    return 1
}

write_wpa_supplicant_conf() {
    local wpa_conf="$1" ssid="$2" psk="$3" mode="$4"
    if [[ "$mode" == "sae" ]]; then
        cat >"$wpa_conf" <<EOF
network={
    ssid="${ssid}"
    psk="${psk}"
    key_mgmt=SAE
    ieee80211w=2
}
EOF
    else
        cat >"$wpa_conf" <<EOF
network={
    ssid="${ssid}"
    psk="${psk}"
    key_mgmt=WPA-PSK
}
EOF
    fi
    chmod 600 "$wpa_conf"
}

connect_wifi_nmcli() {
    local wlan="$1" ssid="$2" psk="$3" mode="$4"
    if ! command -v nmcli >/dev/null 2>&1; then
        return 1
    fi
    if ! systemctl is-active NetworkManager >/dev/null 2>&1; then
        return 1
    fi
    if [[ "$mode" == "sae" ]]; then
        nmcli dev wifi connect "$ssid" password "$psk" ifname "$wlan" \
            802-11-wireless-security.key-mgmt sae 2>/dev/null
    else
        nmcli dev wifi connect "$ssid" password "$psk" ifname "$wlan" 2>/dev/null
    fi
}

start_wpa_supplicant_dhcp() {
    local wlan="$1" wpa_conf="$2"
    pkill -f "wpa_supplicant.*${wlan}" 2>/dev/null || true
    wpa_supplicant -B -i "$wlan" -c "$wpa_conf" -D nl80211,wext 2>/dev/null || \
        wpa_supplicant -B -i "$wlan" -c "$wpa_conf" 2>/dev/null || return 1
    dhclient "$wlan" 2>/dev/null || dhcpcd "$wlan" 2>/dev/null || true
    return 0
}

connect_lab_wifi() {
    local wlan="$1"
    local ssid="${CTG_LAB_WIFI_SSID:-}"
    local psk="${CTG_LAB_WIFI_PSK:-}"
    local key_mgmt_mode
    local wpa_conf="/etc/ctg/lab-wifi-wpa.conf"
    local try_wpa3=false

    if [[ -z "$ssid" || -z "$psk" ]]; then
        log "Lab WiFi SSID/PSK not set — skip connect"
        return 0
    fi
    if [[ "$psk" == *"your-wpa2"* || "$ssid" == *"YourLabSSID"* ]]; then
        log "Lab WiFi still has placeholder values — edit $CONF"
        return 0
    fi

    key_mgmt_mode="$(normalize_key_mgmt_mode "${CTG_LAB_WIFI_KEY_MGMT:-wpa3}")"
    if [[ "$key_mgmt_mode" == "wpa3" || "$key_mgmt_mode" == "wpa2wpa3" ]]; then
        try_wpa3=true
    fi

    log "Connecting $wlan to lab SSID (authorized AP only, key_mgmt=$key_mgmt_mode)"
    ip link set "$wlan" up 2>/dev/null || true

    if $try_wpa3; then
        if phy_supports_sae "$wlan"; then
            log "iw phy: SAE supported — attempting WPA3-SAE (PMF required)"
            if connect_wifi_nmcli "$wlan" "$ssid" "$psk" sae; then
                log "Connected via NetworkManager (WPA3-SAE)"
                return 0
            fi
            write_wpa_supplicant_conf "$wpa_conf" "$ssid" "$psk" sae
            if start_wpa_supplicant_dhcp "$wlan" "$wpa_conf"; then
                log "Connected via wpa_supplicant (WPA3-SAE, ieee80211w=2)"
                return 0
            fi
            log "WPA3-SAE connect failed — falling back to WPA2-PSK (AP or Realtek driver may lack SAE)"
        else
            log "iw phy: SAE not advertised on $wlan — skipping WPA3, using WPA2-PSK"
        fi
    fi

    log "Attempting WPA2-PSK (transition-mode friendly)"
    if connect_wifi_nmcli "$wlan" "$ssid" "$psk" wpa2; then
        log "Connected via NetworkManager (WPA2-PSK)"
        return 0
    fi
    write_wpa_supplicant_conf "$wpa_conf" "$ssid" "$psk" wpa2
    if start_wpa_supplicant_dhcp "$wlan" "$wpa_conf"; then
        log "Connected via wpa_supplicant (WPA2-PSK)"
        return 0
    fi
    log "All WiFi connect attempts failed for $wlan"
    return 1
}

set_wlan_promisc() {
    local wlan="$1"
    log "WiFi: ip link promisc on $wlan (may be insufficient for 802.11 — see docs)"
    ip link set "$wlan" promisc on 2>/dev/null || log "promisc on $wlan failed (driver may not support)"
}

start_wifi_monitor() {
    local wlan="$1"
    if ! command -v airmon-ng >/dev/null 2>&1; then
        log "Installing aircrack-ng for airmon-ng"
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y -qq aircrack-ng 2>/dev/null || true
    fi
    if command -v airmon-ng >/dev/null 2>&1; then
        log "Starting monitor mode: airmon-ng start $wlan"
        airmon-ng check kill 2>/dev/null || true
        airmon-ng start "$wlan" 2>/dev/null || log "airmon-ng start failed — check driver supports monitor"
        iw dev 2>/dev/null | tee -a "$LOG_FILE" || true
    else
        log "airmon-ng not available — install aircrack-ng"
    fi
}

set_eth_promisc_if_cabled() {
    local eth="$1"
    if [[ -z "$eth" ]]; then
        log "No wired interface detected — skip eth promisc"
        return 0
    fi
    if iface_link_up "$eth"; then
        log "Ethernet $eth link UP — enabling classic promiscuous mode (CAT5 LAN segment)"
        ip link set dev "$eth" promisc on 2>/dev/null || log "promisc on $eth failed"
    else
        log "Ethernet $eth not UP — skip promisc (plug CAT5 for wired sniff)"
    fi
}

install_systemd_unit() {
    log "Installing ${SERVICE_NAME}"
    local script_src="$SCRIPT_DIR/ctg-wifi-lab-autorun.sh"
    for candidate in /mnt/ctg/ctg-wifi-lab-autorun.sh /media/sf_ctg-backups/ctg-wifi-lab-autorun.sh; do
        if [[ -f "$candidate" ]]; then
            script_src="$candidate"
            break
        fi
    done
    install -d -m 0755 /opt/ctg
    if [[ -f "$script_src" ]]; then
        install -m 0755 "$script_src" /opt/ctg/ctg-wifi-lab-autorun.sh
    fi
    local monitor_env=""
    $DO_MONITOR && monitor_env="Environment=CTG_WIFI_MONITOR=1"
    cat >"$UNIT_DEST" <<UNITEOF
[Unit]
Description=CTG lab WiFi/Ethernet autorun (Realtek, promisc/monitor)
After=network-online.target vboxadd-service.service
Wants=network-online.target

[Service]
Type=oneshot
${monitor_env}
ExecStart=/opt/ctg/ctg-wifi-lab-autorun.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNITEOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    log "Enabled ${SERVICE_NAME}"
}

# --- main ---
preserve_or_set_ddg_dns
load_lab_wifi_config

if realtek_lsusb_present; then
    vidpid="$(get_realtek_vidpid)"
    log "Realtek USB detected: ${vidpid:-unknown}"
    install_realtek_oot_driver "${vidpid:-}"
else
    log "No Realtek USB in lsusb — wlan may be built-in or not passed through"
fi

usb_wlan="$(detect_usb_wlan_iface || true)"
wired="$(detect_wired_iface || true)"

if [[ -n "$usb_wlan" ]]; then
    log "USB wlan interface: $usb_wlan"
    connect_lab_wifi "$usb_wlan"
    set_wlan_promisc "$usb_wlan"
    if $DO_MONITOR; then
        start_wifi_monitor "$usb_wlan"
    fi
else
    log "No USB wlan interface found — attach Realtek dongle via VirtualBox USB filter"
fi

set_eth_promisc_if_cabled "$wired"

# Passive IDS on same lab interface (detect-only; optional IPS via ctg-ids-ips-autorun --EnableIPS)
IDS_SCRIPT="$SCRIPT_DIR/ctg-ids-ips-autorun.sh"
for candidate in /mnt/ctg/ctg-ids-ips-autorun.sh /opt/ctg/ctg-ids-ips-autorun.sh; do
    if [[ -f "$candidate" ]]; then
        IDS_SCRIPT="$candidate"
        break
    fi
done
if [[ -f "$IDS_SCRIPT" ]]; then
    log "Chaining ctg-ids-ips-autorun (Snort/Suricata detect-only + ClamAV ensure)"
    bash "$IDS_SCRIPT" || log "IDS/IPS autorun returned non-zero (WiFi/promisc phase complete)"
else
    log "ctg-ids-ips-autorun.sh not on share — stage for network IDS + ClamAV"
fi

if $DO_INSTALL; then
    install_systemd_unit
fi

log "=== CTG WiFi lab autorun complete ==="
log "Eth vs WiFi capture: docs/KALI_WIFI_ETH_PROMISC.md"
