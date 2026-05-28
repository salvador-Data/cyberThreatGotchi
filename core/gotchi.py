"""CyberThreatGotchi — Tamagotchi pet tied to live security posture."""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

from assets.sprites.frames import CAT_FRAMES, get_frame
from config.settings import GOTCHI_HAPPINESS_DECAY, GOTCHI_HUNGER_DECAY, GOTCHI_TICK_SEC
from core.detector import ThreatEvent


class GotchiMood(str, Enum):
    IDLE = "idle"
    HAPPY = "happy"
    ALERT = "alert"
    ATTACK = "attack"
    SLEEP = "sleep"
    FEED = "feed"
    DEFEND = "defend"


@dataclass
class GotchiState:
    name: str = "Cipherhorn"
    mood: GotchiMood = GotchiMood.IDLE
    hunger: int = 80
    happiness: int = 80
    security_xp: int = 0
    level: int = 1
    threats_blocked: int = 0
    threats_seen: int = 0
    cats_active: int = 3
    frame_index: int = 0
    last_tick: float = field(default_factory=time.time)
    status_line: str = "Standing guard for Hacker Planet LLC"


class CyberGotchi:
    """Unicorn CISO mascot — mood reacts to threats, IPS blocks, and care actions."""

    XP_PER_THREAT = 5
    XP_PER_BLOCK = 12
    HUNGER_FEED = 25
    HAPPY_PET = 15

    def __init__(self, name: str = "Cipherhorn") -> None:
        self.state = GotchiState(name=name)
        self._tick_interval = GOTCHI_TICK_SEC
        self._anim_counter = 0

    def tick(self, idle_traffic: bool = False) -> GotchiState:
        now = time.time()
        if now - self.state.last_tick < self._tick_interval:
            return self.state

        self.state.last_tick = now
        self.state.hunger = max(0, self.state.hunger - GOTCHI_HUNGER_DECAY)
        self.state.happiness = max(0, self.state.happiness - GOTCHI_HAPPINESS_DECAY)

        if idle_traffic and self.state.mood not in (GotchiMood.ATTACK, GotchiMood.ALERT):
            self.state.mood = GotchiMood.SLEEP
            self.state.status_line = "Low traffic — napping on the SIEM"
        elif self.state.hunger < 30:
            self.state.mood = GotchiMood.FEED
            self.state.status_line = "Hungry for PCAPs and threat feeds"
        elif self.state.happiness > 70 and self.state.threats_blocked == 0:
            self.state.mood = GotchiMood.HAPPY
            self.state.status_line = "All quiet — cats purring"
        elif self.state.mood not in (GotchiMood.ATTACK, GotchiMood.ALERT, GotchiMood.DEFEND):
            self.state.mood = GotchiMood.IDLE
            self.state.status_line = "Patrolling the perimeter"

        self._anim_counter += 1
        self.state.frame_index = self._anim_counter
        return self.state

    def on_threat(self, event: ThreatEvent, action: str) -> None:
        self.state.threats_seen += 1
        self.state.security_xp += self.XP_PER_THREAT
        self._level_up()

        if action == "blocked":
            self.state.threats_blocked += 1
            self.state.security_xp += self.XP_PER_BLOCK
            self.state.mood = GotchiMood.ATTACK
            self.state.happiness = min(100, self.state.happiness + 10)
            self.state.status_line = f"Blocked {event.source_ip} — IPS engaged!"
        elif event.severity in ("critical", "high"):
            self.state.mood = GotchiMood.ALERT
            self.state.status_line = f"ALERT: {event.category} from {event.source_ip}"
        else:
            self.state.mood = GotchiMood.DEFEND
            self.state.status_line = f"Defending against {event.category}"

        self._level_up()

    def feed(self) -> None:
        self.state.hunger = min(100, self.state.hunger + self.HUNGER_FEED)
        self.state.mood = GotchiMood.FEED
        self.state.status_line = "Fed fresh threat intelligence"

    def pet(self) -> None:
        self.state.happiness = min(100, self.state.happiness + self.HAPPY_PET)
        self.state.mood = GotchiMood.HAPPY
        self.state.status_line = "CISO unicorn appreciates the headpat"

    def render_sprite(self) -> str:
        mood_key = self.state.mood.value
        body = get_frame(mood_key, self.state.frame_index)
        cats = self._render_cats()
        stats = self._render_stats()
        return f"{cats}\n{body}\n{stats}"

    def _render_cats(self) -> str:
        keys = ["business", "mass", "sentinel"][: self.state.cats_active]
        lines = ["  — Cat Sentinels (Business / Mass / SOC) —"]
        for key in keys:
            cat = CAT_FRAMES.get(key, "").strip().split("\n")
            lines.extend("  " + line for line in cat)
        return "\n".join(lines)

    def _render_stats(self) -> str:
        s = self.state
        bar_h = self._bar(s.hunger, "Hunger")
        bar_p = self._bar(s.happiness, "Happy")
        return (
            f"\n  {s.name} Lv.{s.level} | XP:{s.security_xp} | "
            f"Blocked:{s.threats_blocked} | Seen:{s.threats_seen}\n"
            f"  {bar_h}  {bar_p}\n"
            f"  Mood: {s.mood.value.upper()} — {s.status_line}"
        )

    def _level_up(self) -> None:
        needed = self.state.level * 50
        while self.state.security_xp >= needed:
            self.state.security_xp -= needed
            self.state.level += 1
            self.state.cats_active = min(3, 1 + self.state.level // 3)
            needed = self.state.level * 50

    @staticmethod
    def _bar(value: int, label: str, width: int = 12) -> str:
        filled = int((value / 100) * width)
        return f"{label:7} [{'█' * filled}{'░' * (width - filled)}] {value:3}"
