"""Mr. CrackBot AI Nano — authorized-lab wordlist generation (SSID metadata + heuristics).

Run only on networks you own or have explicit written permission to test.
Heuristic Verizon-style patterns work offline. Optional GPT-2 path requires
``transformers`` + ``torch`` and ``MR_CRACKBOT_USE_AI=1`` (downloads model on first use).

Logs under CTG data dir (never committed); override with ``MR_CRACKBOT_LOG_PATH``.
"""

from __future__ import annotations

import logging
import os
import re
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any

# Lazy GPT-2 singletons (loaded only when AI path is enabled)
# Pinned Hugging Face commit for gpt2 (bandit B615 — immutable revision).
_GPT2_HF_REVISION = "607a30d783dfa663caf39e06633721c8d4cfcd7e"
_model: Any = None
_tokenizer: Any = None

_LOG_CONFIGURED = False
_PASSWORD_TOKEN = re.compile(r"\b[A-Za-z0-9][A-Za-z0-9\-]{6,62}[A-Za-z0-9]\b")
_PROMPT_MARKERS = ("SSID:", "Location:", "Known Parameters:")


def _project_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def default_log_path() -> Path:
    """Configurable log file path (gitignored via *.log)."""
    override = os.environ.get("MR_CRACKBOT_LOG_PATH", "").strip()
    if override:
        return Path(override)
    data_root = os.environ.get("CTG_DATA_DIR", "").strip()
    base = Path(data_root) if data_root else _project_root() / "data"
    return base / "logs" / "mr_crackbot_ai.log"


def _configure_logging() -> logging.Logger:
    """Attach a single rotating handler; safe across re-import."""
    global _LOG_CONFIGURED
    log = logging.getLogger("password_generator")
    if _LOG_CONFIGURED or log.handlers:
        _LOG_CONFIGURED = True
        return log
    log_path = default_log_path()
    log_path.parent.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(
        log_path,
        maxBytes=1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"))
    log.addHandler(handler)
    log.setLevel(logging.INFO)
    log.propagate = False
    _LOG_CONFIGURED = True
    return log


logger = _configure_logging()


def ai_enabled() -> bool:
    return os.environ.get("MR_CRACKBOT_USE_AI", "").strip().lower() in ("1", "true", "yes")


def get_model():
    """Load GPT-2 once; raises ImportError if optional deps missing."""
    global _model, _tokenizer
    if _model is not None and _tokenizer is not None:
        return _model, _tokenizer
    try:
        from transformers import GPT2LMHeadModel, GPT2Tokenizer
    except ImportError as exc:
        raise ImportError(
            "transformers/torch not installed — use heuristic mode or "
            "pip install transformers torch"
        ) from exc
    _tokenizer = GPT2Tokenizer.from_pretrained("gpt2", revision=_GPT2_HF_REVISION)
    _model = GPT2LMHeadModel.from_pretrained("gpt2", revision=_GPT2_HF_REVISION)
    if _tokenizer.pad_token_id is None:
        _tokenizer.pad_token_id = _tokenizer.eos_token_id
    return _model, _tokenizer


def validate_metadata(metadata: dict[str, Any]) -> bool:
    if not isinstance(metadata, dict):
        raise ValueError("metadata must be a dict")
    if "ssid" not in metadata or not str(metadata["ssid"]).strip():
        raise ValueError("Missing required metadata fields")
    return True


def validate_password_complexity(password: str) -> bool:
    """Sensible checks for router/heuristic wordlist entries (not enterprise policy)."""
    if not password or len(password) < 8 or len(password) > 64:
        return False
    if any(c.isspace() for c in password):
        return False
    if not any(c.isdigit() for c in password):
        return False
    if not any(c.isalpha() for c in password):
        return False
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
    return all(c in allowed for c in password)


def prepare_metadata_input(metadata: dict[str, Any]) -> str:
    validate_metadata(metadata)
    params = metadata.get("parameters") or {}
    param_lines = ", ".join(f"{key}: {value}" for key, value in params.items())
    input_text = (
        f"SSID: {metadata['ssid']}\n"
        f"Location: {metadata.get('location', 'unknown')}\n"
        f"Known Parameters: {param_lines or 'none'}\n"
        "Password candidates:"
    )
    logger.info("Prepared metadata input for AI (ssid=%s)", metadata["ssid"])
    return input_text


def extract_password_candidates(text: str) -> list[str]:
    """Pull password-like tokens from model output; drop prompt/metadata echo."""
    if not text:
        return []
    cleaned = text
    for marker in _PROMPT_MARKERS:
        if marker in cleaned:
            cleaned = cleaned.split(marker, 1)[-1]
    candidates: list[str] = []
    seen: set[str] = set()
    for match in _PASSWORD_TOKEN.finditer(cleaned):
        token = match.group(0).strip("-")
        if token in seen:
            continue
        if validate_password_complexity(token):
            seen.add(token)
            candidates.append(token)
    return candidates


def generate_ai_passwords(metadata: dict[str, Any]) -> list[str]:
    if not ai_enabled():
        logger.info("AI wordlist path disabled (set MR_CRACKBOT_USE_AI=1 to enable)")
        return []
    try:
        model, tokenizer = get_model()
    except ImportError as exc:
        logger.warning("%s", exc)
        return []
    input_text = prepare_metadata_input(metadata)
    try:
        inputs = tokenizer(
            input_text,
            return_tensors="pt",
            truncation=True,
            max_length=100,
        )
        input_len = int(inputs["input_ids"].shape[1])
        outputs = model.generate(
            inputs["input_ids"],
            max_new_tokens=24,
            num_return_sequences=8,
            do_sample=True,
            top_p=0.92,
            pad_token_id=tokenizer.pad_token_id,
        )
        guesses: list[str] = []
        seen: set[str] = set()
        for output in outputs:
            new_ids = output[input_len:]
            fragment = tokenizer.decode(new_ids, skip_special_tokens=True)
            for candidate in extract_password_candidates(fragment):
                if candidate not in seen:
                    seen.add(candidate)
                    guesses.append(candidate)
        logger.info("Generated %d AI-based password candidates", len(guesses))
        return guesses
    except Exception as exc:
        logger.error("Error generating AI passwords: %s", exc)
        return []


def generate_verizon_router_passwords() -> list[str]:
    """Verizon-style default router patterns (authorized lab / owned hardware only)."""
    words = ["trial", "admin", "default", "hello", "network"]
    numbers = range(1, 10)
    patterns: list[str] = []
    try:
        for word1 in words:
            for number in numbers:
                for word2 in words:
                    pattern = f"{word1}-{word2}{number}-{word2}"
                    if validate_password_complexity(pattern):
                        patterns.append(pattern)
        logger.info("Generated %d Verizon router patterns", len(patterns))
    except Exception as exc:
        logger.error("Error generating Verizon router patterns: %s", exc)
    return patterns


def generate_password_guesses(metadata: dict[str, Any]) -> list[str]:
    try:
        validate_metadata(metadata)
        verizon_passwords = generate_verizon_router_passwords()
        ai_guesses = generate_ai_passwords(metadata)
        all_guesses = list(dict.fromkeys(verizon_passwords + ai_guesses))
        logger.info("Combined %d unique password guesses", len(all_guesses))
        return all_guesses
    except Exception as exc:
        logger.error("Error combining password guesses: %s", exc)
        return []


def _demo_metadata() -> dict[str, Any]:
    return {
        "ssid": "Test_Network",
        "location": "Office",
        "parameters": {"type": "router", "brand": "Verizon"},
    }


if __name__ == "__main__":
    meta = _demo_metadata()
    patterns = generate_verizon_router_passwords()
    print(f"Verizon heuristic samples ({len(patterns)} total): {patterns[:5]}")
    if ai_enabled():
        combined = generate_password_guesses(meta)
        print(f"With AI enabled: {len(combined)} combined guesses (showing 5): {combined[:5]}")
    else:
        print(
            "AI path skipped (heuristic-only). Set MR_CRACKBOT_USE_AI=1 and install "
            "transformers+torch to enable GPT-2 candidates."
        )
        validate_metadata(meta)
        print(f"Metadata OK for ssid={meta['ssid']!r}")
