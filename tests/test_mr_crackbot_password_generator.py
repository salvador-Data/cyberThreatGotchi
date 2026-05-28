"""Tests for scripts/mr_crackbot/password_generator.py (heuristic path; no GPT-2 load)."""

from __future__ import annotations

import importlib.util
import logging
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULE_PATH = ROOT / "scripts" / "mr_crackbot" / "password_generator.py"


def _load_module(*, fresh_name: str = "password_generator"):
    spec = importlib.util.spec_from_file_location(fresh_name, MODULE_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[fresh_name] = mod
    spec.loader.exec_module(mod)
    return mod


def test_validate_metadata_requires_ssid():
    pg = _load_module()
    pg.validate_metadata({"ssid": "Lab_AP"})
    try:
        pg.validate_metadata({"location": "office"})
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_validate_password_complexity():
    pg = _load_module()
    assert pg.validate_password_complexity("hello1234")
    assert pg.validate_password_complexity("trial-admin1-admin")
    assert not pg.validate_password_complexity("short1")
    assert not pg.validate_password_complexity("longpassword")
    assert not pg.validate_password_complexity("no-digits-here")


def test_generate_verizon_router_passwords_nonempty():
    pg = _load_module()
    patterns = pg.generate_verizon_router_passwords()
    assert patterns
    assert all(pg.validate_password_complexity(p) for p in patterns)


def test_extract_password_candidates_strips_prompt_echo():
    pg = _load_module()
    noisy = (
        "SSID: Test_Network\nLocation: Office\n"
        "trial-admin3-network admin-default2-hello"
    )
    found = pg.extract_password_candidates(noisy)
    assert "trial-admin3-network" in found
    assert all("SSID" not in c for c in found)


def test_generate_password_guesses_heuristic_only(monkeypatch):
    monkeypatch.delenv("MR_CRACKBOT_USE_AI", raising=False)
    pg = _load_module(fresh_name="password_generator_heuristic")
    guesses = pg.generate_password_guesses({"ssid": "Lab_AP"})
    assert guesses
    assert all(pg.validate_password_complexity(g) for g in guesses)


def test_ai_disabled_without_env(monkeypatch):
    monkeypatch.delenv("MR_CRACKBOT_USE_AI", raising=False)
    pg = _load_module(fresh_name="password_generator_no_ai")
    assert pg.generate_ai_passwords({"ssid": "Lab_AP"}) == []


def test_default_log_path_uses_ctg_data_dir(monkeypatch, tmp_path):
    monkeypatch.setenv("CTG_DATA_DIR", str(tmp_path))
    monkeypatch.delenv("MR_CRACKBOT_LOG_PATH", raising=False)
    pg = _load_module(fresh_name="password_generator_logpath")
    assert pg.default_log_path() == tmp_path / "logs" / "mr_crackbot_ai.log"


def test_reimport_does_not_duplicate_handlers():
    pg1 = _load_module(fresh_name="password_generator_reimport_a")
    count_after_first = len(pg1.logger.handlers)
    pg2 = _load_module(fresh_name="password_generator_reimport_b")
    assert len(pg2.logger.handlers) == count_after_first
    assert count_after_first >= 1


def test_logging_module_name_stable():
    pg = _load_module(fresh_name="password_generator_logname")
    assert pg.logger.name == "password_generator"
    assert isinstance(pg.logger, logging.Logger)
