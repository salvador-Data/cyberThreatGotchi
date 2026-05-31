"""Tests for CTG event summarizer (core/ctg_event_summarize.py)."""

from __future__ import annotations

from core.ctg_event_summarize import pro_cloud_prompt, summarize_event


def test_summarize_deauth():
    line = summarize_event(
        {
            "type": "wifi.deauth",
            "source": "kali",
            "severity": "high",
            "message": "Threshold 50/min",
            "ssid": "YourLabSSID",
            "bssid": "aa:bb:cc:dd:ee:ff",
        }
    )
    assert "deauth" in line.lower() or "802.11" in line
    assert "YourLabSSID" in line
    assert "HIGH:" in line


def test_summarize_utms_pack():
    line = summarize_event(
        {
            "type": "utms.broadcast",
            "source": "windows",
            "severity": "info",
            "message": "Pack v2 staged",
        }
    )
    assert "UTMS" in line or "threat pack" in line.lower()


def test_summarize_unknown_type():
    line = summarize_event(
        {
            "type": "system.heartbeat",
            "source": "cardputer",
            "severity": "info",
            "message": "poll ok",
        }
    )
    assert "system.heartbeat" in line or "Host or lab" in line


def test_pro_cloud_prompt_no_secrets():
    prompt = pro_cloud_prompt(
        {
            "type": "wifi.jam",
            "source": "windows",
            "severity": "warn",
            "message": "gateway unreachable",
        }
    )
    assert "Do not suggest offensive" in prompt
    assert "wifi.jam" in prompt
