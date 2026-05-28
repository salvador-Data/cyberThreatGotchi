# Hardware — 3D printed enclosure

CyberThreatGotchi ships as a **Tamagotchi-style portable appliance**. You print **three STL parts** per display variant, assemble with the BPI-R3 Mini, e-ink or LCD, and a USB-C PD battery.

## Quick start

```bash
# E-ink (2.13") — default
python hardware/generate_stl.py

# Color LCD (2.4" ILI9341) — taller window
python hardware/generate_stl.py --variant lcd

# Both variants + legacy copies
python hardware/generate_stl.py --all
```

## STL locations

| Variant | Directory | Front window |
|---------|-----------|--------------|
| **E-ink** | `hardware/stl/eink/` | 50 × 26 mm |
| **LCD** | `hardware/stl/lcd/` | 39 × 55 mm (portrait) |
| Legacy | `hardware/stl/` | Same as e-ink (auto-copied) |

Each folder contains:

| File | Role |
|------|------|
| `ctg_front_shell.stl` | Display bezel, cat emboss, M2.5 standoffs |
| `ctg_rear_shell.stl` | Battery tray, vents, **HACKER PLANET LLC** branding |
| `ctg_clip.stl` | Snap clip joining halves |

## Print settings

| Setting | Value |
|---------|-------|
| Material | PETG (production) or PLA+ (prototype) |
| Layer height | 0.2 mm |
| Infill | 20% gyroid |
| Supports | Front shell — under cat bumps only if needed |
| Brim | Rear shell — recommended |

### Orientation

| Part | Bed contact |
|------|-------------|
| Front shell | **Back/internal face down** (display window facing up) |
| Rear shell | **Outer back face down** ( branding reads correctly ) |
| Clip | Flat |

## Assembly (step-by-step)

### Tools & parts

- Printed front, rear, clip (one variant set)
- Banana Pi BPI-R3 Mini + case screws
- M2.5 × 8 mm screws (×4) for board standoffs
- Waveshare 2.13" e-ink **or** 2.4" ILI9341 SPI LCD
- 5000 mAh USB-C PD power bank (12V profile) or 20W PD trigger
- Optional: 1 mm clear acrylic for display lens
- Double-sided tape or M2 standoffs for display

### Steps

1. **Test fit** — dry-fit front and rear; seam should meet at mid-depth (~16 mm).
2. **Mount board** — screw BPI-R3 Mini onto front-shell standoffs (verify hole pattern for your revision).
3. **Display** — align panel behind front window; secure with tape/standoffs; route SPI ribbon through left channel.
4. **Power** — place battery in rear tray; USB-C cable through bottom slot to BPI input.
5. **Ethernet** — pass patch cables through rear grommets if using wired WAN/LAN.
6. **Close** — mate rear shell; install snap clip in left/right slots until click.
7. **Flash software** — `sudo bash scripts/install.sh` on the Pi image; `systemctl start cyberthreatgotchi`.

### First boot checklist

- [ ] Web UI loads at `http://<device-ip>:8765/`
- [ ] E-ink/LCD shows Cipherhorn sprite
- [ ] Simulation or live traffic moves mood to ALERT/BLOCK
- [ ] `/api/export/report.json` returns statistics

## OpenSCAD customization

Edit `hardware/openscad/ctg_params.scad` for dimensions, then re-export:

```bash
cd hardware/openscad
openscad -o ../stl/eink/ctg_front_shell.stl ctg_front_shell.scad
openscad -Dvariant=lcd -o ../stl/lcd/ctg_front_shell.stl ctg_front_shell.scad
```

Rear shell includes embossed **HACKER PLANET LLC** and **CyberThreatGotchi** text (requires OpenSCAD export for crisp lettering).

## Troubleshooting

| Issue | Likely cause | Fix |
|-------|--------------|-----|
| Board holes don't align | BPI revision drift | Measure and adjust `standoff_positions` in params |
| Display too thick | Panel + acrylic stack | Sand bezel lip or omit acrylic |
| Clip too tight | PETG shrink | Scale clip XY 102% in slicer |
| Weak snap | Low infill | Print clip at 30% infill |

Full dimensional spec: [ENCLOSURE.md](ENCLOSURE.md).
