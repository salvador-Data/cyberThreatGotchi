"""Parse tshark exports and detect basic IDS patterns (authorized lab use only)."""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from rules.signatures import match_payload  # noqa: E402

SCAN_DST_PORT_THRESHOLD = 15
SCAN_PACKET_THRESHOLD = 40
SYN_FLOOD_THRESHOLD = 200
DNS_QNAME_LEN_THRESHOLD = 80
ARP_DUP_IP_THRESHOLD = 2

SEVERITY_ORDER = {"info": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}


@dataclass
class FlowRow:
    time_epoch: float = 0.0
    src_ip: str = ""
    dst_ip: str = ""
    src_port: int | None = None
    dst_port: int | None = None
    protocol: str = ""
    frame_len: int = 0
    tcp_flags: str = ""
    dns_qname: str = ""
    arp_ip: str = ""
    arp_mac: str = ""
    payload_text: str = ""


@dataclass
class Alert:
    alert_type: str
    severity: str
    summary: str
    src_ip: str = ""
    dst_ip: str = ""
    evidence: dict[str, Any] = field(default_factory=dict)
    source: str = "ctg_tshark"

    def to_dict(self) -> dict[str, Any]:
        return {
            "alert_type": self.alert_type,
            "severity": self.severity,
            "summary": self.summary,
            "src_ip": self.src_ip,
            "dst_ip": self.dst_ip,
            "evidence": self.evidence,
            "source": self.source,
        }


def _safe_int(value: str) -> int | None:
    value = (value or "").strip()
    if not value:
        return None
    try:
        return int(value)
    except ValueError:
        return None


def _safe_float(value: str) -> float:
    value = (value or "").strip()
    if not value:
        return 0.0
    try:
        return float(value)
    except ValueError:
        return 0.0


def parse_tshark_csv_line(line: str) -> FlowRow | None:
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    parts = line.split("\t")
    while len(parts) < 14:
        parts.append("")
    src_port = _safe_int(parts[3]) or _safe_int(parts[5])
    dst_port = _safe_int(parts[4]) or _safe_int(parts[6])
    return FlowRow(
        time_epoch=_safe_float(parts[0]),
        src_ip=parts[1].strip(),
        dst_ip=parts[2].strip(),
        src_port=src_port,
        dst_port=dst_port,
        protocol=parts[7].strip(),
        frame_len=_safe_int(parts[8]) or 0,
        tcp_flags=parts[9].strip(),
        dns_qname=parts[10].strip(),
        arp_ip=parts[11].strip() if len(parts) > 11 else "",
        arp_mac=parts[12].strip() if len(parts) > 12 else "",
        payload_text=parts[13].strip() if len(parts) > 13 else "",
    )


def parse_tshark_csv_text(text: str) -> list[FlowRow]:
    rows: list[FlowRow] = []
    for line in text.splitlines():
        row = parse_tshark_csv_line(line)
        if row:
            rows.append(row)
    return rows


def _max_severity(current: str, candidate: str) -> str:
    if SEVERITY_ORDER.get(candidate, 0) > SEVERITY_ORDER.get(current, 0):
        return candidate
    return current


def detect_port_scans(rows: list[FlowRow]) -> list[Alert]:
    by_src: dict[str, set[int]] = defaultdict(set)
    counts: dict[str, int] = defaultdict(int)
    alerts: list[Alert] = []
    for row in rows:
        if not row.src_ip or not row.dst_port:
            continue
        by_src[row.src_ip].add(row.dst_port)
        counts[row.src_ip] += 1
    for src, ports in by_src.items():
        if len(ports) >= SCAN_DST_PORT_THRESHOLD or counts[src] >= SCAN_PACKET_THRESHOLD:
            sev = "high" if len(ports) >= SCAN_DST_PORT_THRESHOLD * 2 else "medium"
            alerts.append(
                Alert(
                    alert_type="port_scan",
                    severity=sev,
                    summary=f"Possible port scan from {src} ({len(ports)} distinct dst ports)",
                    src_ip=src,
                    evidence={"distinct_dst_ports": len(ports), "packet_count": counts[src]},
                )
            )
    return alerts


def detect_syn_flood(rows: list[FlowRow]) -> list[Alert]:
    syn_counts: dict[tuple[str, str, int | None], int] = defaultdict(int)
    alerts: list[Alert] = []
    for row in rows:
        if row.protocol.upper() not in {"TCP", "6"}:
            continue
        flags = row.tcp_flags.lower()
        if "syn" in flags and "ack" not in flags:
            key = (row.src_ip, row.dst_ip, row.dst_port)
            syn_counts[key] += 1
    for (src, dst, dport), count in syn_counts.items():
        if count >= SYN_FLOOD_THRESHOLD:
            alerts.append(
                Alert(
                    alert_type="syn_flood",
                    severity="high",
                    summary=f"Possible SYN flood {src} -> {dst}:{dport} ({count} SYN)",
                    src_ip=src,
                    dst_ip=dst,
                    evidence={"syn_count": count, "dst_port": dport},
                )
            )
    return alerts


def detect_dns_tunnel_hints(rows: list[FlowRow]) -> list[Alert]:
    alerts: list[Alert] = []
    long_names: dict[str, list[str]] = defaultdict(list)
    for row in rows:
        q = row.dns_qname.strip(".")
        if not q:
            continue
        if len(q) >= DNS_QNAME_LEN_THRESHOLD:
            long_names[row.src_ip].append(q[:120])
    for src, names in long_names.items():
        if names:
            alerts.append(
                Alert(
                    alert_type="dns_tunnel_hint",
                    severity="medium",
                    summary=f"Long DNS query names from {src} (possible DNS tunneling)",
                    src_ip=src,
                    evidence={"sample_qnames": names[:5], "count": len(names)},
                )
            )
    return alerts


def detect_arp_spoof_hints(rows: list[FlowRow]) -> list[Alert]:
    ip_to_macs: dict[str, set[str]] = defaultdict(set)
    alerts: list[Alert] = []
    for row in rows:
        if row.arp_ip and row.arp_mac:
            ip_to_macs[row.arp_ip].add(row.arp_mac.lower())
    for ip, macs in ip_to_macs.items():
        if len(macs) >= ARP_DUP_IP_THRESHOLD:
            alerts.append(
                Alert(
                    alert_type="arp_spoof_hint",
                    severity="high",
                    summary=f"ARP anomaly: IP {ip} seen with {len(macs)} MAC addresses",
                    src_ip=ip,
                    evidence={"mac_addresses": sorted(macs)},
                )
            )
    return alerts


def detect_signature_matches(rows: list[FlowRow]) -> list[Alert]:
    alerts: list[Alert] = []
    for row in rows:
        if not row.payload_text:
            continue
        for sig in match_payload(row.payload_text):
            alerts.append(
                Alert(
                    alert_type=f"sig_{sig.sid.lower()}",
                    severity=sig.severity,
                    summary=f"{sig.name}: {sig.description}",
                    src_ip=row.src_ip,
                    dst_ip=row.dst_ip,
                    evidence={"sid": sig.sid, "category": sig.category},
                    source="ctg_signature",
                )
            )
    return alerts


def parse_snort_alert_line(line: str) -> Alert | None:
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    m = re.search(
        r"\[(?P<gid>\d+):(?P<sid>\d+):(?P<rev>\d+)\]\s*(?P<msg>[^\[]+)",
        line,
    )
    if not m:
        return None
    msg = m.group("msg").strip()
    if msg.endswith("[**]"):
        msg = msg[:-4].strip()
    src_ip = ""
    dst_ip = ""
    ip_match = re.search(
        r"(?P<src>\d+\.\d+\.\d+\.\d+):\d+\s+->\s+(?P<dst>\d+\.\d+\.\d+\.\d+)",
        line,
    )
    if ip_match:
        src_ip = ip_match.group("src")
        dst_ip = ip_match.group("dst")
    sev = "medium"
    lower = msg.lower()
    if any(k in lower for k in ("exploit", "shellcode", "trojan", "backdoor")):
        sev = "critical"
    elif any(k in lower for k in ("scan", "nmap", "attack")):
        sev = "high"
    return Alert(
        alert_type="snort_alert",
        severity=sev,
        summary=msg,
        src_ip=src_ip,
        dst_ip=dst_ip,
        evidence={"gid": m.group("gid"), "sid": m.group("sid"), "raw": line[:500]},
        source="snort",
    )


def parse_snort_log_text(text: str) -> list[Alert]:
    alerts: list[Alert] = []
    for line in text.splitlines():
        alert = parse_snort_alert_line(line)
        if alert:
            alerts.append(alert)
    return alerts


def analyze_flow_rows(rows: list[FlowRow]) -> list[dict[str, Any]]:
    merged: list[Alert] = []
    merged.extend(detect_port_scans(rows))
    merged.extend(detect_syn_flood(rows))
    merged.extend(detect_dns_tunnel_hints(rows))
    merged.extend(detect_arp_spoof_hints(rows))
    merged.extend(detect_signature_matches(rows))
    return dedupe_alerts([a.to_dict() for a in merged])


def dedupe_alerts(alerts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[tuple[str, str, str]] = set()
    out: list[dict[str, Any]] = []
    for alert in alerts:
        key = (
            alert.get("alert_type", ""),
            alert.get("src_ip", ""),
            alert.get("summary", "")[:80],
        )
        if key in seen:
            continue
        seen.add(key)
        out.append(alert)
    return out


def merge_alert_lists(*lists: list[dict[str, Any]]) -> list[dict[str, Any]]:
    combined: list[dict[str, Any]] = []
    for lst in lists:
        combined.extend(lst)
    return dedupe_alerts(combined)


def is_high_severity(alert: dict[str, Any]) -> bool:
    return alert.get("severity") in {"high", "critical"}


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Analyze tshark CSV export for CTG IDS alerts")
    parser.add_argument("--csv", type=Path, help="tshark fields export (tab-separated)")
    parser.add_argument("--snort-log", type=Path, help="Snort alert log file")
    parser.add_argument("--json-out", type=Path, help="Write alerts JSON array")
    args = parser.parse_args()

    alerts: list[dict[str, Any]] = []
    if args.csv and args.csv.is_file():
        text = args.csv.read_text(encoding="utf-8", errors="replace")
        alerts.extend(analyze_flow_rows(parse_tshark_csv_text(text)))
    if args.snort_log and args.snort_log.is_file():
        snort_text = args.snort_log.read_text(encoding="utf-8", errors="replace")
        alerts.extend([a.to_dict() for a in parse_snort_log_text(snort_text)])

    merged = dedupe_alerts(alerts)
    payload = json.dumps(merged, indent=2)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(payload + "\n", encoding="utf-8")
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
