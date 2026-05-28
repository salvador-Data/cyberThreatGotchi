"""ASCII / monochrome sprite frames — Unicorn CISO + Guy Fawkes mask + suit + cats.

Cats represent mass-market targets and business-sector sentinels orbiting the unicorn.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class GotchiSpriteSet(str, Enum):
    IDLE = "idle"
    HAPPY = "happy"
    ALERT = "alert"
    ATTACK = "attack"
    SLEEP = "sleep"
    FEED = "feed"
    DEFEND = "defend"


# Each frame: unicorn center, mask (◆), suit (▓), cats (🐱 rendered as /\_/\)
MOOD_FRAMES: dict[str, list[str]] = {
    "idle": [
        r"""
     🐱       🐱
   /\_/\     /\_/\
  🐱   ╭─────────╮   🐱
      │  ♥ ♦ ♥  │      ← mask eyes
      │ ╔═══════╗ │
      │ ║ ▓▓▓▓▓ ║ │      ← business suit
      │ ║  \|/  ║ │
      ╰─╨─╨─╨─╨─╯
       ▲ unicorn horn
        """,
    ],
    "happy": [
        r"""
   🐱  ★  🐱  ★  🐱
      ╭─────────╮
      │ ◠ ◡ ◠  │
      │ ╔═══════╗ │
      │ ║ ▓▓▓▓▓ ║ │
      ╰─╨─╨─╨─╨─╯
   threats cleared!
        """,
    ],
    "alert": [
        r"""
   🐱!!    !!🐱
      ╭─────────╮
      │ ◉ ◉ ◉  │  ALERT
      │ ╔═══════╗ │
      │ ║ ▓!▓!▓ ║ │
      ╰─╨─╨─╨─╨─╯
   ears up — scanning
        """,
    ],
    "attack": [
        r"""
  🐱⚔ 🐱⚔ 🐱⚔
      ╭─────────╮
      │ ► ◆ ◄  │  BLOCK
      │ ╔═══════╗ │
      │ ║▓SHIELD▓║ │
      ╰─╨─╨─╨─╨─╯
   IPS ENGAGED
        """,
    ],
    "sleep": [
        r"""
   zzz 🐱 zzz 🐱
      ╭─────────╮
      │ - - -  │
      │ ╔═══════╗ │
      │ ║ ▓▓▓▓▓ ║ │
      ╰─╨─╨─╨─╨─╯
   low traffic
        """,
    ],
    "feed": [
        r"""
   🐱~nom~🐱
      ╭─────────╮
      │ ◕ ‿ ◕  │
      │ ╔═══════╗ │
      │ ║ PCAP! ║ │
      ╰─╨─╨─╨─╨─╯
   fed threat intel
        """,
    ],
    "defend": [
        r"""
 🐱BUS 🐱MASS 🐱
      ╭─────────╮
      │ ◆ CISO ◆│
      │ ╔═══════╗ │
      │ ║▓FIREWALL║
      ╰─╨─╨─╨─╨─╯
   cats on patrol
        """,
    ],
}

# Orbiting cats — business vs mass personas
CAT_FRAMES: dict[str, str] = {
    "business": r"""
  /\_/\  BUS-CAT
 ( o.o ) suit collar
  > ^ <  watches B2B VLAN
    """,
    "mass": r"""
  /\_/\  MASS-CAT
 ( ^.^ ) crowd shield
  > w <  protects users
    """,
    "sentinel": r"""
  /\_/\  SENTINEL
 ( @.@ ) YARA eyes
  > # <  hash patrol
    """,
}


def get_frame(mood: str, frame_index: int = 0) -> str:
    frames = MOOD_FRAMES.get(mood, MOOD_FRAMES["idle"])
    return frames[frame_index % len(frames)].strip()
