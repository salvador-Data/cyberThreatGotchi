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

    def ensure_dirs(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        HASH_DB_PATH.parent.mkdir(parents=True, exist_ok=True)


def load_settings() -> Settings:
    s = Settings()
    s.ensure_dirs()
    return s
