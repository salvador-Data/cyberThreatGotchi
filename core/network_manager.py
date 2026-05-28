"""Network interface discovery and management."""

from __future__ import annotations

import platform
import subprocess
from dataclasses import dataclass
from typing import Optional

import psutil


@dataclass
class NetworkInterface:
    name: str
    addresses: list[str]
    is_up: bool
    bytes_sent: int
    bytes_recv: int


class NetworkManager:
    def __init__(self, preferred: str = "") -> None:
        self.preferred = preferred

    def list_interfaces(self) -> list[NetworkInterface]:
        stats = psutil.net_if_stats()
        addrs = psutil.net_if_addrs()
        io = psutil.net_io_counters(pernic=True)
        result: list[NetworkInterface] = []
        for name, stat in stats.items():
            if name.startswith(("lo", "Loopback")):
                continue
            ips = [
                a.address
                for a in addrs.get(name, [])
                if getattr(a, "family", None) and str(a.family).endswith("AF_INET")
            ]
            nic_io = io.get(name)
            result.append(
                NetworkInterface(
                    name=name,
                    addresses=ips,
                    is_up=stat.isup,
                    bytes_sent=nic_io.bytes_sent if nic_io else 0,
                    bytes_recv=nic_io.bytes_recv if nic_io else 0,
                )
            )
        return result

    def resolve_interface(self) -> str:
        if self.preferred:
            for iface in self.list_interfaces():
                if iface.name == self.preferred and iface.is_up:
                    return iface.name
        for iface in self.list_interfaces():
            if iface.is_up and iface.addresses:
                return iface.name
        ifaces = self.list_interfaces()
        return ifaces[0].name if ifaces else "eth0"

    def set_promiscuous(self, interface: str, enable: bool = True) -> bool:
        if platform.system() != "Linux":
            return False
        flag = "on" if enable else "off"
        try:
            subprocess.run(
                ["ip", "link", "set", interface, "promisc", flag],
                check=True,
                capture_output=True,
                timeout=10,
            )
            return True
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return False

    def interface_summary(self) -> str:
        lines = ["Network interfaces:"]
        for iface in self.list_interfaces():
            status = "UP" if iface.is_up else "DOWN"
            ips = ", ".join(iface.addresses) or "no IPv4"
            lines.append(f"  {iface.name} [{status}] {ips}")
        return "\n".join(lines)
