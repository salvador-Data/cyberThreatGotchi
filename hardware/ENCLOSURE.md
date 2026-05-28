# CyberThreatGotchi — 3D Printable Enclosure Spec

Tamagotchi-style **desktop-portable** shell for Banana Pi BPI-R3 Mini + 2.13" e-ink (or 2.4" LCD).

## Overall dimensions

| Dimension | mm | Notes |
|-----------|-----|-------|
| Width | 95 | Pocketable, fits palm |
| Height | 110 | Classic Tamagotchi oval height |
| Depth | 32 | Board + display + battery |
| Wall thickness | 2.0 | PLA/PETG |
| Button bore | 6.0 | Reset access |

## Internal layout (top view)

```
┌─────────────────────────────────────┐
│  [CAT]                    [CAT]     │  ← bezel cat icons (embossed)
│       ┌───────────────┐             │
│       │  E-INK 2.13"  │             │  ← window cutout 27×27 mm active
│       │   250×122     │             │
│       └───────────────┘             │
│  [CAT]     BPI-R3 Mini     [CAT]    │  ← 65×65 mm board standoffs
│            (65×65)                  │
│         [USB-C PD in]               │  ← bottom edge port slot 12×6 mm
│         [2.5GbE×2]                  │  ← rear grommet holes
└─────────────────────────────────────┘
```

## Component stack (front → back)

1. Front shell + display bezel (e-ink glued behind 1 mm acrylic window optional)
2. SPI ribbon route channel (2 mm height under display)
3. BPI-R3 Mini on M2.5 standoffs (height 6 mm)
4. 5000 mAh USB-C PD power bank (slid-in tray, velcro strap)
5. Rear vent slots (2×15 mm × 3 mm) for Wi-Fi/heat

## Standoffs

| Post | Position (from bottom-left, mm) | Height |
|------|----------------------------------|--------|
| P1 | (12, 45) | 6 |
| P2 | (53, 45) | 6 |
| P3 | (12, 78) | 6 |
| P4 | (53, 78) | 6 |

Use **M2.5×8 mm** screws; board mounting matches BPI-R3 Mini corner pattern (verify against your revision).

## Display cutout

| Panel | Active area (mm) | Cutout (mm) |
|-------|------------------|-------------|
| Waveshare 2.13" | 48.55 × 23.7 | 50 × 26 |
| ILI9341 2.4" | 36.7 × 52 | 39 × 55 |

## SPI wiring pocket

Leave **8×20 mm** channel along left inner wall for SPI HAT ribbon (5V, GND, DIN, CLK, CS, DC, RST, BUSY).

## Export files (to generate in CAD)

- `ctg_front_shell.stl` — bezel + cat emboss + display window
- `ctg_rear_shell.stl` — battery tray + vents + USB-C cutout
- `ctg_clip.stl` — snap clip or 4× M3 thumb screws

## Print settings

- Material: PETG (durability) or PLA+ (prototype)
- Layer: 0.2 mm
- Infill: 20% gyroid
- Supports: only under cat emboss if >45° overhang

## Branding

Emboss text on rear: `HACKER PLANET LLC` — 2 mm height, 8 pt equivalent.

---

OpenSCAD starter sketch: see `hardware/enclosure.scad` (parametric preview).
