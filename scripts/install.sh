#!/usr/bin/env bash
# CyberThreatGotchi installer — Banana Pi BPI-R3 Mini (OpenWrt / Debian)
set -euo pipefail

INSTALL_DIR="${CTG_INSTALL_DIR:-/opt/cyberThreatGotchi}"
PY="${PYTHON:-python3}"
USER_SERVICE="cyberthreatgotchi"

echo "==> CyberThreatGotchi installer for BPI-R3 Mini"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

apt-get update -qq
apt-get install -y \
  python3 python3-pip python3-venv \
  libpcap-dev tcpdump \
  clamav-daemon clamav-freshclam \
  yara \
  iptables \
  git \
  spi-tools python3-spidev python3-pil \
  fonts-dejavu-core || true

systemctl enable clamav-daemon || true
systemctl start clamav-daemon || true

mkdir -p "$INSTALL_DIR"
if [[ -d "$(dirname "$0")/.." ]]; then
  rsync -a --exclude '.git' --exclude 'data' "$(dirname "$0")/../" "$INSTALL_DIR/"
else
  echo "Copy project files to $INSTALL_DIR manually."
fi

cd "$INSTALL_DIR"
$PY -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install yara-python pyclamd scapy || true
python assets/sprites/generate_sprites.py || true

# Optional Waveshare e-paper (SPI)
pip install waveshare-epd 2>/dev/null || echo "waveshare-epd optional — use CTG_DISPLAY=terminal if missing"

mkdir -p /etc/cyberthreatgotchi
mkdir -p /var/lib/cyberthreatgotchi
chmod 755 /var/lib/cyberthreatgotchi
cat >/etc/cyberthreatgotchi/env <<EOF
CTG_PLATFORM=bpi-r3-mini
CTG_DISPLAY=eink
CTG_INTERFACE=eth0
CTG_SIMULATION=false
CTG_DATA_DIR=/var/lib/cyberthreatgotchi
CLAMAV_HOST=127.0.0.1
CLAMAV_PORT=3310
EOF

cat >/etc/systemd/system/${USER_SERVICE}.service <<EOF
[Unit]
Description=CyberThreatGotchi Network Guardian
After=network-online.target clamav-daemon.service

[Service]
Type=simple
EnvironmentFile=/etc/cyberthreatgotchi/env
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/.venv/bin/python main.py --display eink --web --web-port 8765
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${USER_SERVICE}"

echo ""
echo "Installed to ${INSTALL_DIR}"
echo "  systemctl start ${USER_SERVICE}"
echo "  journalctl -u ${USER_SERVICE} -f"
echo ""
echo "Hardware: wire 2.13\" SPI e-paper to SPI0; 12V USB-C PD battery pack for portable mode."
echo "Set CTG_DISPLAY=lcd for ILI9341 color panel instead of e-ink."
