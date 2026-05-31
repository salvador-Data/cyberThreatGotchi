"""Rules-first CTG event analyst summaries (no external API keys in repo).

Optional Pro cloud template is returned as structured text for upstream services;
this module never calls third-party LLM APIs.
"""

from __future__ import annotations

from typing import Any

# Template for optional Hacker Planet Pro cloud summarizer (host-side only).
PRO_CLOUD_TEMPLATE = (
    "Summarize this CTG defensive lab event in one sentence for a SOC analyst. "
    "Do not suggest offensive countermeasures. Event JSON: {event_json}"
)

_RULES: list[tuple[tuple[str, ...], str]] = [
    (("wifi.deauth",), "802.11 deauthentication/disassociation pattern detected — verify PMF, prefer wired or cellular failover."),
    (("wifi.jam", "wifi.disconnect_storm"), "Wi-Fi link instability (possible jam/deauth storm) — use wired backup; do not transmit counter-jam."),
    (("wifi.rogue_ap", "wifi.evil_twin"), "Possible rogue AP or evil-twin hint — verify BSSID, enable VPN, avoid captive portals."),
    (("wifi.lab_ap",), "Lab soft AP status change on authorized CTG-UTMS-LAB segment."),
    (("utms.pack", "utms.broadcast"), "UTMS threat pack broadcast ready for signed pull on lab devices."),
    (("ids.",), "IDS alert routed to CTG event bus — review SIEM JSON and local logs."),
    (("email.",), "Email bridge event — dedupe via Message-ID before notify."),
    (("system.",), "Host or lab system event logged to CTG bus."),
]


def _match_rule(event_type: str) -> str | None:
    et = event_type.lower()
    for needles, summary in _RULES:
        for needle in needles:
            if needle.endswith(".") and et.startswith(needle):
                return summary
            if needle in et or et == needle:
                return summary
    return None


def summarize_event(event: dict[str, Any]) -> str:
    """Return one-line analyst text for a CTGEvent dict."""
    etype = str(event.get("type", "system.unknown"))
    severity = str(event.get("severity", "info")).lower()
    message = str(event.get("message", "")).strip()
    ssid = str(event.get("ssid", "")).strip()
    bssid = str(event.get("bssid", "")).strip()
    source = str(event.get("source", "unknown"))

    rule = _match_rule(etype)
    if rule:
        base = rule
    else:
        base = f"CTG event ({etype}) from {source}."

    parts = [base]
    if ssid:
        parts.append(f"SSID={ssid}.")
    if bssid:
        parts.append(f"BSSID={bssid}.")
    if message and message not in base:
        short = message if len(message) <= 120 else message[:117] + "..."
        parts.append(short)

    prefix = {"critical": "CRITICAL:", "high": "HIGH:", "warn": "WARN:"}.get(severity, "")
    line = " ".join(parts)
    if prefix:
        line = f"{prefix} {line}"
    return line[:500]


def pro_cloud_prompt(event: dict[str, Any]) -> str:
    """Build optional Pro-tier cloud prompt (caller supplies API off-repo)."""
    import json

    return PRO_CLOUD_TEMPLATE.format(event_json=json.dumps(event, separators=(",", ":")))
