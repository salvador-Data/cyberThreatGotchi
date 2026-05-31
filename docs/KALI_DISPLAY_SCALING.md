# Kali display scaling — fit window + readable text

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

See also: [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) (seamless/scaled window modes).

## Symptom → cause → control (NIST-style)

| Symptom | Likely cause | Control (defensive lab) |
|---------|--------------|------------------------|
| Desktop **cut off** at edges; scroll/wrap | Guest resolution **larger** than VM window | `--fit-window` + host `GUI/AutoresizeGuest=true` + `-DisplayMode Gui` |
| Whole UI **blown out / huge** | Host **Scaled** + guest Xft DPI 120–144 + bad `LastGuestSizeHint` | `--reset` then `--fit-window`; host `-DisplayMode Gui` (`Scale=false`) |
| Terminal text **too small** only | 96 DPI default on dense display | `--fit-window` (includes DPI 105–112) or `--fonts-only` after fit |
| Seamless reverts / no panel | Wayland session or `VBoxClient --seamless` dead | `ctg-seamless-guest.sh`; GDM `WaylandEnable=false` |

**Detect:** `bash /mnt/ctg/ctg-display-scale.sh --diagnose-only`  
**Contain:** `--reset` if over-scaled; host clears bad `GUI/LastGuestSizeHint`  
**Recover:** `--fit-window` at every login (autostart + first-login chain)

## VirtualBox guest display pipeline

Understanding the stack prevents “fixing” the wrong layer:

```text
Windows host (150% scaling optional)
  └─ VirtualBox VM window size + extradata
       GUI/AutoresizeGuest, GUI/Scale, GUI/LastGuestSizeHint
  └─ Guest Additions (VBoxClient --vmsvga / --display)
  └─ X11 xrandr (Virtual1 output, --auto, mode list)
  └─ Xfce xsettings /Xft/DPI, Gtk/FontName, terminal fonts
```

1. **Host window** defines the visible viewport. `AutoresizeGuest=true` tells GA to match guest resolution to that window.
2. **Bad `LastGuestSizeHint`** (e.g. 3428×1660 from a prior full-screen capture) inflates the guest framebuffer → **cut-off** even when fonts look tiny.
3. **`VBoxClient --vmsvga`** must run after GUI login or autoresize stops.
4. **`xrandr --auto`** fits the virtual output; CTG **never** selects the “largest” mode (that caused blow-up).
5. **Xft DPI 105–112** adjusts text only after resolution fits — not whole-desktop 144 DPI with host Scaled.

## Quick fix (Kali — one command per step)

**1. Mount share** (if needed):

```bash
sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
```

**2. Reset over-scaling** (if desktop/fonts are huge):

```bash
bash /mnt/ctg/ctg-display-scale.sh --reset
```

**3. Fit window + modest fonts** (after Xfce login — **default**):

```bash
bash /mnt/ctg/ctg-display-scale.sh --fit-window
```

**4. Text-only bump** (optional, after step 3):

```bash
bash /mnt/ctg/ctg-display-scale.sh --fonts-only
```

**5. Windows host** — windowed autoresize, not Scaled:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DisplayMode Gui
```

Diagnose (no changes):

```bash
bash /mnt/ctg/ctg-display-scale.sh --diagnose-only
```

## Root causes (professor summary)

The **cut-off** symptom almost always means the **guest framebuffer exceeds the VM window**, not that fonts are too large. VirtualBox saves `GUI/LastGuestSizeHint` from prior sessions; values like **3428×1660** (logical pixels on a 150% Windows display) push `xrandr` beyond the visible window. An older CTG path also picked the **largest** xrandr mode in `ctg-seamless-guest.sh`, which worsened clipping. Layered on top, **Xft DPI 120–144** with host **Scaled** mode makes the entire chrome look blown out. The fix order is always: **host autoresize + clear hint → guest fit-window → fonts-only if needed**.

## What the scripts do

### `ctg-display-scale.sh`

| Flag | Behavior |
|------|----------|
| *(default)* / `--fit-window` | `VBoxClient` autoresize; `xrandr --auto`; downscale if >2560×1600; Xft DPI **105–112**; terminal/Gtk fonts; **never** force oversized resolution |
| `--fonts-only` | Modest DPI/fonts only; minimal xrandr (`--auto`); use after `--fit-window` |
| `--reset` | DPI **96**, default fonts, `xrandr --auto`, panel size 30 |
| `--aggressive` | Legacy: DPI 120/144, panel scale — **not** with host Scaled |
| `--diagnose-only` | Resolution, DPI, fonts, VBoxClient, cut-off warnings |

Autostart at login: `ctg-display-scale.sh --fit-window` (sleep 2, **before** seamless autostart).

### Autorun chain (next GUI login)

1. `ctg-display-scale.desktop` → `--fit-window` (sleep 2)
2. `vboxclient-seamless.desktop` → VBoxClient (sleep 5)
3. `ctg-first-login-autorun.desktop` → mount, `--fit-window`, seamless, SSH, lab chain (first run only)
4. `ctg-watch-trigger.sh` → Windows `CTG_TRIGGER_AUTORUN` on Backups share

### `Start-KaliSeamless.ps1`

- Always: `GUI/AutoresizeGuest=true`, clear bad `GUI/LastGuestSizeHint` (>2560×1600)
- **Gui** (recommended for cut-off / blown-out): `GUI/Scale=false`, seamless off
- **Scaled**: `GUI/Scale=true` — pair with guest `--fit-window`, not `--aggressive`
- Running VM + Gui: optional `setvideomodehint` from current hint (VB7 GA refresh)

## Permanent fix

**Kali:**

```bash
sudo bash /mnt/ctg/kali-boot-autopatch.sh --install
```

**Windows:**

```powershell
.\scripts\windows\Stage-KaliLabToBackups.ps1
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DisplayMode Gui
```

```powershell
.\scripts\windows\Invoke-CtgKaliGuestFlash.ps1
```

Do **not** use `-DisplayMode Scaled` when the problem is cut-off or blown-out desktop.

## Troubleshooting tree

| Symptom | Try next |
|---------|----------|
| `$'\r': command not found` | `Stage-KaliLabToBackups.ps1`, remount share |
| `No graphical (:N) desktop user` | Log into **Xfce GUI** first |
| Still cut off after fit-window | Host `-DisplayMode Gui`; resize VM window once; re-run `--fit-window` |
| Still huge | `--reset` then `--fit-window`; check Xft DPI ≤112 |
| Seamless breaks display | Run `--fit-window` **before** `ctg-seamless-guest.sh` |

Open a **new** terminal window after font changes.
