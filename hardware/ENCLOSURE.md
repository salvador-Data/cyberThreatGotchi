# CyberThreatGotchi — 3D Printable Enclosure

Tamagotchi-style **desktop-portable** shell for Banana Pi BPI-R3 Mini + 2.13" e-ink (or 2.4" LCD).

## STL files (print these)

### E-ink variant (Waveshare 2.13")

| File | Path |
|------|------|
| Front shell | `stl/eink/ctg_front_shell.stl` |
| Rear shell | `stl/eink/ctg_rear_shell.stl` |
| Snap clip | `stl/eink/ctg_clip.stl` |

Legacy copies also live in `stl/` (same as e-ink).

### LCD variant (ILI9341 2.4" portrait)

| File | Path |
|------|------|
| Front shell | `stl/lcd/ctg_front_shell.stl` |
| Rear shell | `stl/lcd/ctg_rear_shell.stl` |
| Snap clip | `stl/lcd/ctg_clip.stl` |

Rear shell includes embossed **HACKER PLANET LLC** branding (best with OpenSCAD export).

Regenerate:

```bash
python hardware/generate_stl.py          # e-ink
python hardware/generate_stl.py --variant lcd
python hardware/generate_stl.py --all    # both
```

If [OpenSCAD](https://openscad.org/) is installed, exports use the parametric sources in `openscad/` (higher quality). Otherwise a built-in Python mesh builder writes valid binary STL.

## Overall dimensions

| Dimension | mm | Notes |
|-----------|-----|-------|
| Width | 95 | Pocketable, fits palm |
| Height | 110 | Classic Tamagotchi oval height |
| Depth | 32 | Board + display + battery |
| Wall thickness | 2.0 | PLA/PETG |
| Button bore | 6.0 | Reset access (rear shell) |

## Assembly

1. Print all **3 STL** parts (see settings below).
2. Press-fit **M2.5×8 mm** screws through BPI-R3 Mini into front-shell standoffs.
3. Mount e-ink behind front window (optional 1 mm acrylic lens).
4. Slide USB-C PD battery into rear tray; route cable through bottom slot.
5. Mate front + rear at center seam; install **snap clip** on left/right slots.
6. Ethernet: pass cables through rear grommet holes.

## Internal layout (top view)

```
┌─────────────────────────────────────┐
│  [CAT]                    [CAT]     │  ← bezel cat icons (embossed)
│       ┌───────────────┐             │
│       │  E-INK 2.13"  │             │  ← window 50×26 mm
│       └───────────────┘             │
│  [CAT]     BPI-R3 Mini     [CAT]    │  ← 65×65 mm board
│         [USB-C PD in]               │
│         [2.5GbE×2 rear]             │
└─────────────────────────────────────┘
```

## OpenSCAD sources (parametric)

| Source | Output |
|--------|--------|
| `openscad/ctg_front_shell.scad` | Front shell |
| `openscad/ctg_rear_shell.scad` | Rear shell |
| `openscad/ctg_clip.scad` | Snap clip |
| `openscad/ctg_params.scad` | Shared dimensions |

Manual export:

```bash
cd hardware/openscad
openscad -o ../stl/ctg_front_shell.stl ctg_front_shell.scad
openscad -o ../stl/ctg_rear_shell.stl ctg_rear_shell.scad
openscad -o ../stl/ctg_clip.stl ctg_clip.scad
```

## Print settings

- **Material:** PETG (durability) or PLA+ (prototype)
- **Layer:** 0.2 mm
- **Infill:** 20% gyroid
- **Supports:** Front shell only under cat emboss if needed
- **Brim:** Recommended for rear shell (large flat face)

## Branding

Deboss pocket on rear shell for `HACKER PLANET LLC` label or 2 mm embossed text in OpenSCAD.

---

*Hacker Planet LLC — desk guardian.*
