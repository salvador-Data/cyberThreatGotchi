#!/usr/bin/env python3
"""
CTG Tor/HTTP Scrambler — local Tkinter GUI (authorized lab use only).
Hacker Planet LLC · Philadelphia, PA · CyberThreatGotchi

Modes: tor (default), http, auto. MAC rotate: USB wlan only (stub).
Does not automate attacks against third parties.
"""
from __future__ import annotations

import os
import socket
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox, ttk

CTG_ROOT = os.environ.get("CTG_SCRAMBLER_ROOT", "/opt/ctg/tor-http-scrambler")
DAEMON = os.path.join(CTG_ROOT, "scrambler-daemon.sh")
MODE_FILE = os.environ.get("CTG_SCRAMBLER_MODE_FILE", "/var/lib/ctg/scrambler-mode")
SIEM_HOOK = os.path.join(CTG_ROOT, "siem-hook.sh")


def run_cmd(args: list[str], timeout: int = 15) -> str:
    try:
        r = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return (r.stdout or r.stderr or "").strip()
    except (OSError, subprocess.TimeoutExpired) as e:
        return str(e)


def read_mode() -> str:
    if os.path.isfile(MODE_FILE):
        with open(MODE_FILE, encoding="utf-8") as f:
            return f.read().strip() or "tor"
    return "tor"


def write_mode(mode: str) -> None:
    if os.path.isfile(DAEMON):
        run_cmd(["sudo", DAEMON, "set-mode", mode])
    else:
        os.makedirs(os.path.dirname(MODE_FILE), exist_ok=True)
        with open(MODE_FILE, "w", encoding="utf-8") as f:
            f.write(mode)


def local_ip_mac() -> tuple[str, str]:
    ip = "—"
    mac = "—"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.0.2.2", 1))
        ip = s.getsockname()[0]
        s.close()
    except OSError:
        pass
    out = run_cmd(["ip", "link", "show"])
    for line in out.splitlines():
        if "link/ether" in line:
            parts = line.split()
            if len(parts) >= 2:
                mac = parts[1]
                break
    return ip, mac


def tail_ids_alerts(n: int = 8) -> str:
    for path in (
        "/var/log/snort/alert",
        "/var/log/snort/snort.log",
        "/var/log/syslog",
    ):
        if os.path.isfile(path):
            return run_cmd(["tail", "-n", str(n), path], timeout=5) or "(empty)"
    return "(no Snort/syslog yet — run bootstrap)"


def leak_check_stub() -> str:
    return (
        "Leak check (stub): verify Tor Browser + DDG DNS per docs/KALI_LAB_ARCHITECTURE.md\n"
        "1. https://check.torproject.org (Tor Browser)\n"
        "2. resolv.conf has 94.140.14.14/15.15 if using DDG preserve\n"
        "3. No WebRTC leaks in browser settings"
    )


class CtgScramblerApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("CTG .TOR/HTTP Scrambler — Hacker Planet LLC (authorized lab)")
        self.geometry("520x420")
        self.minsize(480, 380)

        hdr = ttk.Label(
            self,
            text="Authorized defensive lab only — no third-party attack automation",
            wraplength=480,
        )
        hdr.pack(pady=6)

        mode_frame = ttk.LabelFrame(self, text="Routing mode (browser Tor default)")
        mode_frame.pack(fill="x", padx=10, pady=4)
        self.mode_var = tk.StringVar(value=read_mode())
        for m, label in (
            ("tor", "Tor (default)"),
            ("http", "HTTP clearnet"),
            ("auto", "Auto (site-rules)"),
        ):
            ttk.Radiobutton(
                mode_frame,
                text=label,
                variable=self.mode_var,
                value=m,
                command=self.on_mode_change,
            ).pack(anchor="w", padx=8)

        shield = ttk.LabelFrame(self, text="Shield status")
        shield.pack(fill="x", padx=10, pady=4)
        ip, mac = local_ip_mac()
        ttk.Label(shield, text=f"Lab IP: {ip}").pack(anchor="w", padx=8)
        ttk.Label(shield, text=f"MAC (primary): {mac}").pack(anchor="w", padx=8)
        ttk.Label(
            shield,
            text="MAC rotate: USB wlan adapters only (manual — not automated on built-in NIC)",
            wraplength=460,
        ).pack(anchor="w", padx=8)

        ids_frame = ttk.LabelFrame(self, text="IDS last alerts (tail)")
        ids_frame.pack(fill="both", expand=True, padx=10, pady=4)
        self.ids_text = tk.Text(ids_frame, height=6, wrap="word")
        self.ids_text.pack(fill="both", expand=True, padx=4, pady=4)
        self.ids_text.insert("1.0", tail_ids_alerts())
        self.ids_text.configure(state="disabled")

        btn_row = ttk.Frame(self)
        btn_row.pack(pady=6)
        ttk.Button(btn_row, text="Refresh IDS", command=self.refresh_ids).pack(side="left", padx=4)
        ttk.Button(btn_row, text="Leak check (stub)", command=self.show_leak).pack(side="left", padx=4)
        ttk.Button(btn_row, text="SIEM rotate prompt", command=self.run_siem).pack(side="left", padx=4)
        ttk.Button(btn_row, text="Start daemon", command=self.start_daemon).pack(side="left", padx=4)

    def on_mode_change(self) -> None:
        write_mode(self.mode_var.get())

    def refresh_ids(self) -> None:
        self.ids_text.configure(state="normal")
        self.ids_text.delete("1.0", "end")
        self.ids_text.insert("1.0", tail_ids_alerts(12))
        self.ids_text.configure(state="disabled")

    def show_leak(self) -> None:
        messagebox.showinfo("Leak check (stub)", leak_check_stub())

    def run_siem(self) -> None:
        if os.path.isfile(SIEM_HOOK):
            subprocess.Popen(["x-terminal-emulator", "-e", "sudo", SIEM_HOOK])
        else:
            messagebox.showwarning("SIEM", f"Not installed: {SIEM_HOOK}")

    def start_daemon(self) -> None:
        if os.path.isfile(DAEMON):
            out = run_cmd(["sudo", DAEMON, "start"])
            messagebox.showinfo("Daemon", out or "started")
        else:
            messagebox.showerror("Daemon", f"Missing {DAEMON} — run install-scrambler.sh")


def main() -> int:
    if not os.environ.get("DISPLAY"):
        print("DISPLAY not set — run from desktop session", file=sys.stderr)
        return 1
    app = CtgScramblerApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
