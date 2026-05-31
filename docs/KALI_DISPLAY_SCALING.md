# Kali display scaling — fit window + readable text

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

See also: [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) (seamless/scaled window modes).

## Symptom → cause → control (NIST-style)

| Symptom | Likely cause | Control (defensive lab) |
|---------|--------------|------------------------|
| Desktop **cut off** at edges; scroll/wrap | Guest resolution **larger** than VM window | `--fit-window` + host `GUI/AutoresizeGuest=true` + `-DisplayMode Gui` |
| Whole UI **blown out / huge** | Host **Scaled** + guest Xft DPI 120–144 + bad `LastGuestSizeHint` | `--reset` then `--fit-window`; host `-DisplayMode Gui` (`Scale=false`) |
| Terminal text **too small** only | Fit-window fixed geometry but **Xft DPI still 96** or tiny Gtk/terminal fonts | `--fit-window` (medium DPI 108) or `--text-medium` |
| Text **too big** after prior bump | DPI 112–120 / large Gtk/terminal from last pass | `--fit-window` or `--text-medium` (medium defaults); `--reset` if huge |
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
5. **Xft DPI + Gtk/terminal fonts** adjust the **text layer only** after resolution fits — not whole-desktop 144 DPI with host Scaled.

## Professor: display pipeline (blue team layers)

Defensive operators should know **which layer** they are tuning — mis-tuning the host or xrandr layer blows up the whole desktop (prior **Scaled + DPI 144** incident); mis-tuning only the text layer fixes menus and terminals without clipping.

| Layer | Component | What CTG changes | What to avoid |
|-------|-----------|------------------|---------------|
| 1 — Host viewport | VM window, `GUI/AutoresizeGuest`, `GUI/Scale`, `LastGuestSizeHint` | `Start-KaliSeamless.ps1 -DisplayMode **Gui**` (`Scale=false`) | **Scaled** + guest DPI 144 → entire UI huge |
| 2 — GA autoresize | `VBoxClient --vmsvga` / `--display` | Started by `--fit-window` | Stale GA → guest stops tracking window |
| 3 — X11 geometry | `xrandr --auto`, downscale if >2560×1600 | `--fit-window` only; **never** largest mode | Forcing oversized modes → cut-off |
| 4 — Xft DPI | `xfconf-query` `/Xft/DPI` | **108** (medium — between 96 and 120) | Reset to **96** → tiny; 120+ without need → huge |
| 5 — Toolkit fonts | Gtk `FontName`, xfce4-terminal profiles | Sans **11**, Monospace **12** (`--fit-window` / `--text-medium`) | Changing layer 3 instead of 4–5 |
| 6 — Panel (optional) | `xfce4-panel` size ~30 | Default with medium; **36** only for `--text-large` | `--aggressive` panel 48 with host Scaled |

**Why text got small again after fit-window:** geometry fit (`xrandr --auto` + VBoxClient) succeeded, but a prior **`--reset`**, fresh profile, or an older script pass left **Xft/DPI at 96** and terminal fonts at 10–11pt. Fit-window must apply **both** geometry and the text layer every login (autostart).

## Quick fix (Kali — one command per step)

**1. Mount share** (if needed):

```bash
sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
```

**2. Reset over-scaling** (if desktop/fonts are huge):

```bash
bash /mnt/ctg/ctg-display-scale.sh --reset
```

**3. Fit window + medium fonts** (after Xfce login — **default**; geometry + text; **persists** in `~/.config/xfce4`):

```bash
bash /mnt/ctg/ctg-display-scale.sh --fit-window
```

**4. Medium text only** (geometry unchanged — re-apply saved medium tier):

```bash
bash /mnt/ctg/ctg-display-scale.sh --text-medium
```

**5. Larger text** (when medium still feels small):

```bash
bash /mnt/ctg/ctg-display-scale.sh --text-large
```

**6. Smaller text** (lighter than medium):

```bash
bash /mnt/ctg/ctg-display-scale.sh --fonts-only
```

**7. Windows host** — windowed autoresize, not Scaled:

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

The **cut-off** symptom almost always means the **guest framebuffer exceeds the VM window**, not that fonts are too large. VirtualBox saves `GUI/LastGuestSizeHint` from prior sessions; values like **3428×1660** (logical pixels on a 150% Windows display) push `xrandr` beyond the visible window. An older CTG path also picked the **largest** xrandr mode in `ctg-seamless-guest.sh`, which worsened clipping. Layered on top, **Xft DPI 120–144** with host **Scaled** mode makes the entire chrome look blown out.

**Text too small after fit-window** is layer 4–5: **DPI 96** remains. **Medium** defaults (autorun every login): **DPI 108**, **Sans 11**, **Monospace 12** — between tiny 96 and large 120/14pt. **Persist:** `xfconf-query` writes `~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` (and terminal profiles); **`/etc/xdg/autostart/ctg-display-scale.desktop`** after `kali-boot-autopatch.sh --install` re-applies `--fit-window` at login.

Fix order: **host Gui → `--fit-window`** (medium). If still small: **`--text-large`**. If too big: **`--text-medium`** or **`--fit-window`** again (not `--aggressive` with host Scaled).

## What the scripts do

### `ctg-display-scale.sh`

| Flag | Behavior |
|------|----------|
| *(default)* / `--fit-window` | `VBoxClient` + `xrandr` fit; medium DPI **108**, Sans **11**, Monospace **12**, panel **30**; xfconf **saved**; **never** oversized resolution |
| `--text-medium` | Medium text only (same values as fit-window fonts); no geometry change |
| `--text-large` | Larger: DPI **120**, Sans **13**, Monospace **15**, panel ~36 |
| `--fonts-only` | Smaller: DPI **105**, Sans **10**, Monospace **11** |
| `--reset` | DPI **96**, default fonts, `xrandr --auto`, panel size 30 |
| `--aggressive` | Legacy: DPI 120/144, panel scale — **not** with host Scaled |
| `--diagnose-only` | Resolution, DPI, fonts, VBoxClient, cut-off warnings |

Autostart at login: `ctg-display-scale.sh --fit-window` (medium fonts; sleep 2, **before** seamless).

**Persist / save:** xfconf in `~/.config/xfce4/`; system autostart `/etc/xdg/autostart/ctg-display-scale.desktop` via `sudo bash /mnt/ctg/kali-boot-autopatch.sh --install`; per-user copy in `~/.config/autostart/` when script runs as desktop user or root.

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
| Still huge | `--reset` then `--fit-window`; avoid Scaled + DPI ≥144 |
| Text too big | `--fit-window` or `--text-medium` (DPI 108); avoid re-running `--text-large` |
| Text still small after fit | `--text-large`; or `--fonts-only` only if medium is too big |
| Seamless breaks display | Run `--fit-window` **before** `ctg-seamless-guest.sh` |

Open a **new** terminal window after font changes.
