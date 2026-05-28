"""Central configuration for CyberThreatGotchi."""

from __future__ import annotations

import os
import platform
from dataclasses import dataclass, field
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.environ.get("CTG_DATA_DIR", PROJECT_ROOT / "data"))
DB_PATH = Path(os.environ.get("CTG_DB_PATH", DATA_DIR / "threats.db"))
RULES_DIR = PROJECT_ROOT / "rules"
ASSETS_DIR = PROJECT_ROOT / "assets"
HASH_DB_PATH = Path(os.environ.get("CTG_HASH_DB", DATA_DIR / "malware_hashes.txt"))

# Network
DEFAULT_INTERFACE = os.environ.get("CTG_INTERFACE", "")
SNIFF_FILTER = os.environ.get("CTG_SNIFF_FILTER", "tcp or udp or icmp")
PACKET_BATCH_SIZE = int(os.environ.get("CTG_BATCH_SIZE", "50"))
SIMULATION_MODE = os.environ.get("CTG_SIMULATION", "").lower() in ("1", "true", "yes") or (
    platform.system() == "Windows" and not os.environ.get("CTG_FORCE_LIVE")
)

# IPS
IPS_ENABLED = os.environ.get("CTG_IPS", "true").lower() in ("1", "true", "yes")
IPS_BLOCK_DURATION_SEC = int(os.environ.get("CTG_BLOCK_DURATION", "300"))
IPS_AUTO_BLOCK_THRESHOLD = int(os.environ.get("CTG_BLOCK_THRESHOLD", "7"))

# Antivirus
CLAMAV_HOST = os.environ.get("CLAMAV_HOST", "127.0.0.1")
CLAMAV_PORT = int(os.environ.get("CLAMAV_PORT", "3310"))
YARA_RULES_PATH = Path(os.environ.get("CTG_YARA_RULES", RULES_DIR / "custom_rules.yar"))

# Gotchi
GOTCHI_TICK_SEC = float(os.environ.get("CTG_TICK_SEC", "2.0"))
GOTCHI_HUNGER_DECAY = int(os.environ.get("CTG_HUNGER_DECAY", "1"))
GOTCHI_HAPPINESS_DECAY = int(os.environ.get("CTG_HAPPINESS_DECAY", "1"))

# Display: terminal | eink | lcd
DISPLAY_BACKEND = os.environ.get("CTG_DISPLAY", "terminal").lower()
EINK_WIDTH = int(os.environ.get("CTG_EINK_WIDTH", "250"))
EINK_HEIGHT = int(os.environ.get("CTG_EINK_HEIGHT", "122"))
SPI_DEVICE = os.environ.get("CTG_SPI_DEVICE", "0,0")

# Hardware target
TARGET_PLATFORM = os.environ.get("CTG_PLATFORM", "bpi-r3-mini")
EINK_REFRESH_SEC = float(os.environ.get("CTG_EINK_REFRESH_SEC", "8"))

# Web
WEB_HOST = os.environ.get("CTG_WEB_HOST", "0.0.0.0")
WEB_PORT = int(os.environ.get("CTG_WEB_PORT", "8765"))

# Config file
CONFIG_PATH = Path(os.environ.get("CTG_CONFIG", PROJECT_ROOT / "config" / "default.yaml"))

# Integrations
WEBHOOK_URL = os.environ.get("CTG_WEBHOOK_URL", "").strip()
WEBHOOK_SECRET = os.environ.get("CTG_WEBHOOK_SECRET", "").strip()
WEBHOOK_TIMEOUT_SEC = float(os.environ.get("CTG_WEBHOOK_TIMEOUT", "5"))


@dataclass
class ThreatWeights:
    port_scan: int = 3
    suspicious_payload: int = 5
    known_bad_hash: int = 10
    yara_match: int = 8
    clamav_hit: int = 10
    signature_match: int = 6


@dataclass
class Settings:
    project_root: Path = field(default_factory=lambda: PROJECT_ROOT)
    data_dir: Path = field(default_factory=lambda: DATA_DIR)
    db_path: Path = field(default_factory=lambda: DB_PATH)
    simulation: bool = field(default_factory=lambda: SIMULATION_MODE)
    interface: str = field(default_factory=lambda: DEFAULT_INTERFACE)
    ips_enabled: bool = field(default_factory=lambda: IPS_ENABLED)
    display_backend: str = field(default_factory=lambda: DISPLAY_BACKEND)
    weights: ThreatWeights = field(default_factory=ThreatWeights)
    webhook_url: str = field(default_factory=lambda: WEBHOOK_URL)
    webhook_secret: str = field(default_factory=lambda: WEBHOOK_SECRET)
    webhook_timeout: float = field(default_factory=lambda: WEBHOOK_TIMEOUT_SEC)
    eink_refresh_sec: float = field(default_factory=lambda: EINK_REFRESH_SEC)
    gotchi_name: str = "Cipherhorn"
    web_host: str = field(default_factory=lambda: WEB_HOST)
    web_port: int = field(default_factory=lambda: WEB_PORT)

    def ensure_dirs(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        HASH_DB_PATH.parent.mkdir(parents=True, exist_ok=True)


def _apply_yaml(settings: Settings, data: dict) -> None:
    if not data:
        return
    if "simulation" in data:
        settings.simulation = bool(data["simulation"])
    if data.get("interface"):
        settings.interface = str(data["interface"])
    display = data.get("display") or {}
    if display.get("backend"):
        settings.display_backend = str(display["backend"]).lower()
    if "eink_refresh_sec" in display:
        settings.eink_refresh_sec = float(display["eink_refresh_sec"])
    ips = data.get("ips") or {}
    if "enabled" in ips:
        settings.ips_enabled = bool(ips["enabled"])
    gotchi = data.get("gotchi") or {}
    if gotchi.get("name"):
        settings.gotchi_name = str(gotchi["name"])
    webhook = data.get("webhook") or {}
    if webhook.get("url"):
        settings.webhook_url = str(webhook["url"])
    if webhook.get("secret"):
        settings.webhook_secret = str(webhook["secret"])
    web = data.get("web") or {}
    if web.get("host"):
        settings.web_host = str(web["host"])
    if web.get("port"):
        settings.web_port = int(web["port"])


def load_settings(config_path: Path | None = None) -> Settings:
    s = Settings()
    path = Path(config_path) if config_path else CONFIG_PATH
    if path.is_file():
        try:
            import yaml

            raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            _apply_yaml(s, raw)
        except Exception:
            pass
    if os.environ.get("CTG_SIMULATION"):
        s.simulation = os.environ.get("CTG_SIMULATION", "").lower() in ("1", "true", "yes")
    elif platform.system() == "Windows" and not os.environ.get("CTG_FORCE_LIVE"):
        s.simulation = True
    s.ensure_dirs()
    return s
