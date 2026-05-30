#!/usr/bin/env bash
# CyberThreatGotchi — Kali lab bootstrap (authorized defensive use only).
# Hacker Planet LLC · Philadelphia, PA · https://github.com/salvador-Data/cyberThreatGotchi
#
# Run on Kali after gold install: sudo ./kali-lab-bootstrap.sh [--wifi-profile=company-lab|home-conservative]
# No secrets in this script — OSINT API keys via /etc/environment.d/ctg-osint.env (mode 600).
#
# WiFi Option 2 (company-lab, DEFAULT): legal regdomain + lab-isolated RF tuning only.
# Does NOT bypass FCC/ETSI limits, illegal TX power, or regulatory domain evasion.

set -euo pipefail

WIFI_PROFILE="${WIFI_PROFILE:-company-lab}"
SKIP_SNORT=false
SKIP_REALTEK=false
DRY_RUN=false

usage() {
    cat <<'EOF'
Usage: kali-lab-bootstrap.sh [OPTIONS]

Options:
  --wifi-profile=PROFILE   company-lab (default) | home-conservative
  --skip-snort             Skip passive Snort install
  --skip-realtek           Skip Realtek USB driver detection/install
  --dry-run                Print planned actions only
  -h, --help               Show this help

Authorized use: systems and RF you own or have written scope to test (Hacker Planet lab VLAN).
EOF
}

for arg in "$@"; do
    case "$arg" in
        --wifi-profile=*) WIFI_PROFILE="${arg#*=}" ;;
        --skip-snort) SKIP_SNORT=true ;;
        --skip-realtek) SKIP_REALTEK=true ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
    esac
done

if [[ "$WIFI_PROFILE" != "company-lab" && "$WIFI_PROFILE" != "home-conservative" ]]; then
    echo "Invalid --wifi-profile=$WIFI_PROFILE (use company-lab or home-conservative)" >&2
    exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $0 $*" >&2
    exit 1
fi

log() { printf '[ctg-kali] %s\n' "$*"; }
run() {
    if $DRY_RUN; then
        log "[dry-run] $*"
    else
        log "+ $*"
        "$@"
    fi
}

CTG_ENV="/etc/environment.d/ctg-osint.env"
CTG_WIFI_BASE="/usr/local/sbin/wifi-lab-baseline.sh"

log "CyberThreatGotchi Kali lab bootstrap — wifi-profile=$WIFI_PROFILE"

# --- harden ---
log "Phase: harden"
run apt-get update -qq
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    fail2ban unattended-upgrades lynis ufw \
    apt-listchanges needrestart

if ! $DRY_RUN; then
    dpkg-reconfigure -plow unattended-upgrades || true
fi

run systemctl enable --now fail2ban || true

if ! $DRY_RUN && command -v ufw >/dev/null; then
    ufw default deny incoming || true
    ufw default allow outgoing || true
    ufw allow 22/tcp comment 'SSH lab' || true
    ufw --force enable || true
fi

# --- clamav ---
log "Phase: clamav"
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq clamav clamav-daemon
run systemctl stop clamav-freshclam 2>/dev/null || true
run freshclam || log "freshclam may need retry after mirror sync"
run systemctl enable --now clamav-freshclam clamav-daemon || true

for d in /home/*/samples /home/*/downloads; do
    if [[ -d "$d" ]]; then
        run clamscan -r --infected --remove=no "$d" || true
    fi
done

# --- passive snort (optional) ---
if ! $SKIP_SNORT; then
    log "Phase: passive snort (detect-only, not inline perimeter)"
    run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq snort snort-rules-default || true
    if ! $DRY_RUN && [[ -f /etc/snort/snort.conf ]]; then
        sed -i 's/^ipvar HOME_NET .*/ipvar HOME_NET 10.0.0.0\/8,172.16.0.0\/12,192.168.0.0\/16/' /etc/snort/snort.conf || true
        systemctl disable snort 2>/dev/null || true
        log "Snort installed but not enabled inline — use SPAN/tap lab exercises only"
    fi
fi

# --- osint tier 1/2 packages ---
log "Phase: osint (apt packages; Maltego CE is manual — EULA)"
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    theharvester amass recon-ng whois dnsutils curl jq \
    spiderfoot maltego-teeth 2>/dev/null || \
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    theharvester amass recon-ng whois dnsutils curl jq

if ! $DRY_RUN && [[ ! -f "$CTG_ENV" ]]; then
    cat >"$CTG_ENV" <<'ENVEOF'
# CTG OSINT API placeholders — set values locally; never commit secrets.
# CTG_SHODAN_API_KEY=
# CTG_CENSYS_API_ID=
# CTG_CENSYS_API_SECRET=
# CTG_VT_API_KEY=
ENVEOF
    chmod 600 "$CTG_ENV"
    log "Created $CTG_ENV (edit API keys locally)"
fi

# --- realtek USB driver detection ---
if ! $SKIP_REALTEK; then
    log "Phase: realtek-driver (conditional on lsusb)"
    run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        dkms build-essential linux-headers-"$(uname -r)" git usbutils

    if lsusb 2>/dev/null | grep -qiE 'realtek|0bda:'; then
        log "Realtek USB device detected:"
        lsusb | grep -iE 'realtek|0bda:' || true
        VIDPID="$(lsusb | grep -iE '0bda:' | head -1 | awk '{print $6}' || true)"
        case "${VIDPID:-}" in
            0bda:8812|0bda:881a|0bda:881b|0bda:8821|0bda:8179|0bda:818b|0bda:818c)
                log "Known Realtek chipset $VIDPID — attempting rtl88xxau DKMS (lab use)"
                if [[ ! -d /usr/src/rtl88xxau ]]; then
                    run git clone --depth 1 https://github.com/aircrack-ng/rtl8812au.git /usr/src/rtl88xxau || true
                    if [[ -d /usr/src/rtl88xxau ]]; then
                        run make -C /usr/src/rtl88xxau dkms_install || log "DKMS build failed — verify headers and chipset"
                    fi
                fi
                ;;
            *)
                log "Realtek present ($VIDPID) but no automated driver role — document in lab journal"
                ;;
        esac
    else
        log "No Realtek USB dongle attached — skip driver (pass through from VirtualBox when ready)"
    fi
fi

# --- wifi-lab-tune ---
log "Phase: wifi-lab-tune (profile=$WIFI_PROFILE)"
run DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wireless-tools iw wpasupplicant wireshark tshark

if ! $DRY_RUN; then
    mkdir -p "$(dirname "$CTG_WIFI_BASE")"
    cat >"$CTG_WIFI_BASE" <<'WIFIEOF'
#!/usr/bin/env bash
# CTG WiFi lab baseline — legal regdomain only. Authorized lab SSIDs.
set -euo pipefail
REG="${CTG_WIFI_REGDOMAIN:-US}"
echo "[wifi-lab] Setting legal regdomain: $REG"
iw reg set "$REG"
for dev in $(iw dev 2>/dev/null | awk '/Interface/ {print $2}'); do
    ip link set "$dev" up 2>/dev/null || true
    iw dev "$dev" set power_save off 2>/dev/null || true
done
echo "[wifi-lab] Current reg:"
iw reg get
WIFIEOF
    chmod 755 "$CTG_WIFI_BASE"

    mkdir -p /etc/environment.d
    if [[ "$WIFI_PROFILE" == "company-lab" ]]; then
        cat >/etc/environment.d/ctg-wifi.conf <<'EOF'
# Hacker Planet lab — Option 2: company lab VLAN / owned AP only
CTG_WIFI_REGDOMAIN=US
CTG_WIFI_PROFILE=company-lab
EOF
        log "Option 2 company-lab: regdomain US, power_save off, lab AP/VLAN only"
    else
        cat >/etc/environment.d/ctg-wifi.conf <<'EOF'
CTG_WIFI_REGDOMAIN=US
CTG_WIFI_PROFILE=home-conservative
EOF
        log "Option 1 home-conservative profile"
    fi
    CTG_WIFI_REGDOMAIN=US CTG_WIFI_PROFILE="$WIFI_PROFILE" "$CTG_WIFI_BASE" || true
fi

# --- wireshark permissions (analyst group) ---
if ! $DRY_RUN && getent group wireshark >/dev/null; then
    for u in kali sal; do
        if id "$u" &>/dev/null; then
            usermod -aG wireshark "$u" 2>/dev/null || true
        fi
    done
fi

# --- lynis audit (non-fatal) ---
log "Phase: lynis audit (report only)"
run lynis audit system --quick --quiet || true

log "Bootstrap complete. Next: snapshot VM, attach Realtek USB in VirtualBox, edit $CTG_ENV for OSINT keys."
log "Maltego CE: manual install from vendor .deb (EULA). Suricata primary IDS belongs on OPNsense, not Kali."
