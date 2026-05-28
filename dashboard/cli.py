"""Rich CLI dashboard — Tamagotchi face + threat feed."""

from __future__ import annotations

import time
from typing import Callable, Optional

from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

from core.gotchi import CyberGotchi
from core.ips import IntrusionPreventionSystem
from db.logger import ThreatLogger


class CyberThreatDashboard:
    def __init__(
        self,
        gotchi: CyberGotchi,
        logger: ThreatLogger,
        ips: IntrusionPreventionSystem,
    ) -> None:
        self.gotchi = gotchi
        self.logger = logger
        self.ips = ips
        self.console = Console()
        self._recent_threats: list[dict] = []

    def push_threat_row(self, row: dict) -> None:
        self._recent_threats.insert(0, row)
        self._recent_threats = self._recent_threats[:12]

    def build_layout(self) -> Layout:
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=3),
            Layout(name="body"),
            Layout(name="footer", size=3),
        )
        layout["body"].split_row(
            Layout(name="gotchi", ratio=2),
            Layout(name="threats", ratio=3),
        )
        layout["header"].update(
            Panel(
                Text(
                    "CyberThreatGotchi | Hacker Planet LLC | Unicorn CISO + Cat Sentinels",
                    style="bold cyan",
                    justify="center",
                ),
                style="cyan",
            )
        )
        layout["gotchi"].update(
            Panel(
                self.gotchi.render_sprite(),
                title="[bold magenta]Cipherhorn[/]",
                border_style="magenta",
            )
        )
        layout["threats"].update(Panel(self._threat_table(), title="Threat Feed", border_style="red"))
        blocks = self.ips.active_blocks()
        footer = f"IPS: {'ON' if self.ips.enabled else 'OFF'} | Active blocks: {len(blocks)} | DB events: {self.logger.threat_count()}"
        layout["footer"].update(Panel(footer, style="dim"))
        return layout

    def _threat_table(self) -> Table:
        table = Table(show_header=True, header_style="bold")
        table.add_column("Sev", width=8)
        table.add_column("Source", width=16)
        table.add_column("Category", width=14)
        table.add_column("Action", width=10)
        table.add_column("Description", overflow="fold")
        if not self._recent_threats:
            table.add_row("-", "-", "-", "-", "Awaiting traffic...")
            return table
        for row in self._recent_threats:
            sev = row.get("severity", "?")
            style = "red" if sev in ("critical", "high") else "yellow"
            table.add_row(
                f"[{style}]{sev}[/]",
                row.get("source_ip", ""),
                row.get("category", ""),
                row.get("action_taken", ""),
                row.get("description", "")[:60],
            )
        return table

    def run_live(
        self,
        refresh_hz: float = 2.0,
        stop_flag: Optional[Callable[[], bool]] = None,
    ) -> None:
        interval = 1.0 / refresh_hz
        with Live(self.build_layout(), console=self.console, refresh_per_second=refresh_hz) as live:
            while stop_flag is None or not stop_flag():
                live.update(self.build_layout())
                time.sleep(interval)

    def print_once(self) -> None:
        self.console.print(self.build_layout())
