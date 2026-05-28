#!/usr/bin/env python3
"""
CyberThreatGotchi — portable network security Tamagotchi for Hacker Planet LLC.

Run: python main.py
     python main.py --display eink
     python main.py --simulation
"""

from __future__ import annotations

import argparse
import signal
import sys
import threading
import time
from pathlib import Path

# Ensure project root on path
ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.settings import load_settings
from core.detector import ThreatDetector, ThreatEvent
from core.gotchi import CyberGotchi
from core.ips import IntrusionPreventionSystem
from core.network_manager import NetworkManager
from core.sniffer import PacketSniffer
from core.state_bus import GotchiSnapshot, StateBus
from core.webhook import WebhookDispatcher
from dashboard.cli import CyberThreatDashboard
from dashboard.web_server import WebDashboard
from db.audit_chain import AuditChain
from db.logger import GotchiRecord, ThreatLogger, ThreatRecord
from display.factory import create_display


class CyberThreatGotchiApp:
    def __init__(self, args: argparse.Namespace) -> None:
        self.settings = load_settings()
        if args.simulation:
            self.settings.simulation = True
        if args.interface:
            self.settings.interface = args.interface

        self.net = NetworkManager(self.settings.interface)
        iface = self.net.resolve_interface()
        self.settings.interface = iface

        self.logger = ThreatLogger(self.settings.db_path)
        self.audit = AuditChain(self.settings.audit_db_path, secret=self.settings.audit_secret)
        self.gotchi = CyberGotchi(name=args.name or self.settings.gotchi_name)
        self.ips = IntrusionPreventionSystem(enabled=not args.no_ips)
        self.detector = ThreatDetector(settings=self.settings, on_threat=self._on_threat)
        self.sniffer = PacketSniffer(
            interface=iface,
            simulation=self.settings.simulation,
        )
        self.display = create_display(args.display)
        self.dashboard = CyberThreatDashboard(self.gotchi, self.logger, self.ips)
        self.bus = StateBus()
        self.webhook = WebhookDispatcher(
            self.settings.webhook_url,
            secret=self.settings.webhook_secret,
            timeout=self.settings.webhook_timeout,
        )
        self.web: WebDashboard | None = None
        if args.web:
            self.web = WebDashboard(
                self.bus,
                self.gotchi,
                logger=self.logger,
                audit=self.audit,
                host=getattr(args, "web_host", self.settings.web_host),
                port=getattr(args, "web_port", self.settings.web_port),
            )
        self._stop = threading.Event()
        self._idle_packets = 0
        self._last_sprite_render = 0.0
        self._sprite_interval = self.settings.eink_refresh_sec

    def _on_threat(self, event: ThreatEvent) -> None:
        action = self.ips.process_threat(event)
        self.gotchi.on_threat(event, action)
        ts = ThreatLogger.utc_now()
        self.logger.log_threat(
            ThreatRecord(
                timestamp=ts,
                severity=event.severity,
                category=event.category,
                source_ip=event.source_ip,
                dest_ip=event.dest_ip,
                description=event.description,
                score=event.score,
                action_taken=action,
                metadata=event.metadata,
            )
        )
        self.audit.append(
            "threat",
            {
                "severity": event.severity,
                "category": event.category,
                "source_ip": event.source_ip,
                "dest_ip": event.dest_ip,
                "description": event.description,
                "score": event.score,
                "action_taken": action,
            },
            ts,
        )
        row = {
            "severity": event.severity,
            "source_ip": event.source_ip,
            "dest_ip": event.dest_ip,
            "category": event.category,
            "action_taken": action,
            "description": event.description,
            "score": event.score,
        }
        self.dashboard.push_threat_row(row)
        self.bus.push_threat(row)
        self._sync_bus()
        if self.webhook.enabled:
            gs = self.gotchi.state
            self.webhook.notify(
                self.webhook.build_threat_payload(
                    timestamp=ThreatLogger.utc_now(),
                    event=row,
                    gotchi={
                        "name": gs.name,
                        "mood": gs.mood.value,
                        "level": gs.level,
                        "threats_blocked": gs.threats_blocked,
                        "threats_seen": gs.threats_seen,
                        "status_line": gs.status_line,
                    },
                )
            )
        compact = (
            f"[{event.severity.upper()}] {event.source_ip} -> {event.dest_ip} "
            f"({action}) score={event.score}"
        )
        if hasattr(self.display, "render_sprite"):
            self.display.render_sprite(
                self.gotchi.state.mood.value,
                title=compact,
                frame=self.gotchi.state.frame_index,
            )
        else:
            self.display.render_text(self.gotchi.render_sprite(), title=compact)
        self._last_sprite_render = time.time()

    def _maybe_refresh_display(self, force: bool = False) -> None:
        if not hasattr(self.display, "render_sprite"):
            return
        now = time.time()
        if not force and now - self._last_sprite_render < self._sprite_interval:
            return
        self._last_sprite_render = now
        s = self.gotchi.state
        self.display.render_sprite(
            s.mood.value,
            title=s.status_line[:28],
            frame=s.frame_index,
        )

    def _engine_loop(self) -> None:
        self.sniffer.start()
        if not self.settings.simulation:
            self.net.set_promiscuous(self.settings.interface, True)

        while not self._stop.is_set():
            packet = self.sniffer.get_packet(timeout=1.0)
            if packet:
                self._idle_packets = 0
                self.detector.inspect_packet(packet)
            else:
                self._idle_packets += 1

            idle = self._idle_packets >= 5
            self.gotchi.tick(idle_traffic=idle)
            self._sync_bus()
            self._maybe_refresh_display()

            if self._idle_packets % 10 == 0:
                self.logger.log_gotchi(
                    GotchiRecord(
                        timestamp=ThreatLogger.utc_now(),
                        mood=self.gotchi.state.mood.value,
                        hunger=self.gotchi.state.hunger,
                        happiness=self.gotchi.state.happiness,
                        security_xp=self.gotchi.state.security_xp,
                        threats_blocked=self.gotchi.state.threats_blocked,
                        note=self.gotchi.state.status_line,
                    )
                )

        self.sniffer.stop()

    def _sync_bus(self) -> None:
        if self.web:
            self.web.sync_from_gotchi()
        self.bus.set_blocks(
            [
                {"ip": b.ip, "reason": b.reason, "score": b.score}
                for b in self.ips.active_blocks()
            ]
        )
        self.bus.set_runtime(
            mode="SIMULATION" if self.settings.simulation else "LIVE",
            interface=self.settings.interface,
            av_status=self.detector.av.status(),
            scanned=self.detector.total_scanned,
            threats=self.detector.total_threats,
        )

    def run(self, live_dashboard: bool = True, web: bool = False) -> int:
        self.display.initialize()
        print(self.net.interface_summary())
        print(f"Mode: {'SIMULATION' if self.settings.simulation else 'LIVE'} | Interface: {self.settings.interface}")
        print(f"AV status: {self.detector.av.status()}")
        if self.webhook.enabled:
            print(f"Webhook: {self.settings.webhook_url}")

        if self.web:
            self.web.start()
            print(f"Web dashboard: http://127.0.0.1:{self.web.port}/")
            self._sync_bus()
            self._maybe_refresh_display(force=True)

        engine = threading.Thread(target=self._engine_loop, name="ctg-engine", daemon=True)
        engine.start()

        def _handle_sig(*_args: object) -> None:
            self._stop.set()

        signal.signal(signal.SIGINT, _handle_sig)
        if hasattr(signal, "SIGTERM"):
            signal.signal(signal.SIGTERM, _handle_sig)

        try:
            if web and not live_dashboard:
                while not self._stop.is_set():
                    time.sleep(0.5)
            elif live_dashboard:
                self.dashboard.run_live(refresh_hz=2.0, stop_flag=self._stop.is_set)
            else:
                while not self._stop.is_set():
                    self.dashboard.print_once()
                    time.sleep(2.0)
        finally:
            self._stop.set()
            engine.join(timeout=5.0)
            self.display.shutdown()
        return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="CyberThreatGotchi — Hacker Planet LLC")
    p.add_argument("--simulation", action="store_true", help="Force simulation traffic")
    p.add_argument("--interface", "-i", default="", help="Network interface")
    p.add_argument("--display", "-d", choices=["terminal", "eink", "lcd"], default="terminal")
    p.add_argument("--name", default="Cipherhorn", help="Gotchi name")
    p.add_argument("--no-ips", action="store_true", help="Disable IPS blocking")
    p.add_argument("--no-live", action="store_true", help="Static refresh instead of Rich Live")
    p.add_argument("--cli", action="store_true", help="With --web, also show Rich terminal dashboard")
    p.add_argument("--web", action="store_true", help="Start web dashboard (Flask)")
    p.add_argument("--web-host", default="0.0.0.0", help="Web bind host")
    p.add_argument("--web-port", type=int, default=8765, help="Web port")
    return p


def main() -> int:
    args = build_parser().parse_args()
    app = CyberThreatGotchiApp(args)
    # --web alone → browser UI; add --cli for Rich terminal too
    live = not args.no_live
    if args.web and not args.cli:
        live = False
    return app.run(live_dashboard=live, web=args.web)


if __name__ == "__main__":
    raise SystemExit(main())
