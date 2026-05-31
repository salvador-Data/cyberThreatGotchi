# Kali display scaling — fit window + readable text

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

See also: [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) (seamless/scaled window modes).

## Symptom → cause → control (NIST-style)

| Symptom | Likely cause | Control (defensive lab) |
|---------|--------------|------------------------|
| Desktop **cut off** at edges; scroll/wrap | Guest resolution **larger** than VM window | `--fit-window` + host `GUI/AutoresizeGuest=true` + `-DisplayMode Gui` |
| Whole UI **blown out / huge** | Host **Scaled** + guest Xft DPI 120–144 + bad `LastGuestSizeHint` | `--reset` then `--fit-window`; host `-DisplayMode Gui` (`Scale=false`) |
| Terminal text **too small** only | Fit-window fixed geometry but **Xft DPI still 96** or tiny Gtk/terminal fonts | `--fit-window` (medium DPI 110) or `--text-medium` / `--text-plus15` |
| Text **too big** after prior bump | DPI 112–120 / large Gtk/terminal from last pass | `--fit-window` or `--text-medium` (medium defaults); `--reset` if huge |
| **Sign-in / login** screen tiny (box OK) | GDM greeter uses default DPI; runs **before** `--fit-window` autostart | `sudo bash …/ctg-display-scale.sh --login-scale` (greeter ~15%; do not bump `-LoginWindowScale`) |
| **Mouse cursor** hard to see | Default X11 theme small / low contrast | `--cursor-neon` (neon lemon + black ring, size 26) |
| Seamless reverts / no panel | Wayland session or `VBoxClient --seamless` dead | `ctg-seamless-guest.sh`; GDM `WaylandEnable=false` |

**Detect:** `bash /mnt/ctg/ctg-display-scale.sh --diagnose-only`  
**Contain:** `--reset` if over-scaled; host clears bad `GUI/LastGuestSizeHint`  
**Recover:** `--fit-window --cursor-neon` at every login (autostart + first-login chain)

## VirtualBox guest display pipeline

Understanding the stack prevents “fixing” the wrong layer:

```text
Windows host (150% scaling optional)
  └─ VirtualBox VM window size + extradata
       GUI/AutoresizeGuest, GUI/Scale, GUI/LastGuestSizeHint
  └─ Guest Additions (VBoxClient --vmsvga / --display)
  └─ X11 xrandr (Virtual1 output, --auto, mode list)
  └─ Xfce xsettings /Xft/DPI, Gtk/FontName, terminal fonts, cursor theme
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
| 4 — Xft DPI | `xfconf-query` `/Xft/DPI` | **110** (~15% over 96; medium) | Reset to **96** → tiny; 120+ without need → huge |
| 5 — Toolkit fonts | Gtk `FontName`, xfce4-terminal profiles | Sans **12**, Monospace **12** (`--fit-window` / `--text-medium`) | Changing layer 3 instead of 4–5 |
| 6 — Cursor (X11) | `Gtk/CursorThemeName`, `CursorThemeSize` | **CTG-Neon-Lemon**, size **26** (~10% over 24) | Wayland greeter (VBox uses X11) |
| 7 — Panel (optional) | `xfce4-panel` size ~30 | Default with medium; **36** only for `--text-large` | `--aggressive` panel 48 with host Scaled |

**Greeter vs desktop text:** `--login-scale` bumps **sign-in screen only** (~15%: GDM `text-scaling-factor=1.15`, lightdm/SDDM Sans 12). Post-login `--fit-window` applies **DPI 110 / Sans 12** — slightly larger than the old “tiny baseline” (96 / Sans 10). If greeter looks right but desktop still feels small, use `--text-plus15` (alias for `--text-medium`) or `--text-large`.

## Quick fix (Kali — one command per step)

**One-liner after mount + GUI login:**

```bash
bash /mnt/ctg/ctg-display-scale.sh --fit-window --cursor-neon
```

**1. Mount share** (if needed):

```bash
sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
```

**2. Reset over-scaling** (if desktop/fonts are huge):

```bash
bash /mnt/ctg/ctg-display-scale.sh --reset
```

**3. Fit window + medium fonts + neon cursor** (after Xfce login — **default** autostart):

```bash
bash /mnt/ctg/ctg-display-scale.sh --fit-window --cursor-neon
```

**4. Medium text only** (geometry unchanged — re-apply saved medium tier):

```bash
bash /mnt/ctg/ctg-display-scale.sh --text-medium
```

Same as `--text-plus15` (~15% over tiny baseline: DPI 110, Sans 12).

**5. Larger text** (when medium still feels small):

```bash
bash /mnt/ctg/ctg-display-scale.sh --text-large
```

**6. Smaller text** (lighter than medium):

```bash
bash /mnt/ctg/ctg-display-scale.sh --fonts-only
```

**7. Neon cursor only** (X11/Xfce):

```bash
bash /mnt/ctg/ctg-display-scale.sh --cursor-neon
```

**8. Windows host** — windowed autoresize, not Scaled:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DisplayMode Gui
```

**Login / sign-in screen** (before Xfce session — greeter only, not post-login fonts):

```bash
sudo bash /mnt/ctg/ctg-display-scale.sh --login-scale
```

When the **login box size is already good**, use guest `--login-scale` only — **do not** raise `-LoginWindowScale` (that enlarges the whole sign-in window). Optional host scale only if both box and text are tiny:

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DisplayMode Gui -LoginWindowScale 1.25
```

Applied automatically on every boot via `kali-boot-autopatch.sh` (calls `--login-scale`). Post-login autostart runs `--fit-window --cursor-neon` (DPI 110, Sans 12, CTG-Neon-Lemon size 26).

Diagnose (no changes):

```bash
bash /mnt/ctg/ctg-display-scale.sh --diagnose-only
```

## Root causes (professor summary)

The **cut-off** symptom almost always means the **guest framebuffer exceeds the VM window**, not that fonts are too large. VirtualBox saves `GUI/LastGuestSizeHint` from prior sessions; values like **3428×1660** (logical pixels on a 150% Windows display) push `xrandr` beyond the visible window. An older CTG path also picked the **largest** xrandr mode in `ctg-seamless-guest.sh`, which worsened clipping. Layered on top, **Xft DPI 120–144** with host **Scaled** mode makes the entire chrome look blown out.

**Text too small after fit-window** is layer 4–5: **DPI 96** remains. **Medium** defaults (autorun every login): **DPI 110**, **Sans 12**, **Monospace 12** — ~15% over the tiny 96 / 10–11pt baseline. **Persist:** `xfconf-query` writes `~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` (and terminal profiles); **`/etc/xdg/autostart/ctg-display-scale.desktop`** after `kali-boot-autopatch.sh --install` re-applies `--fit-window --cursor-neon` at login.

Fix order: **host Gui → `--fit-window --cursor-neon`**. If still small: **`--text-large`**. If too big: **`--text-medium`** or **`--fit-window`** again (not `--aggressive` with host Scaled).

## What the scripts do

### `ctg-display-scale.sh`

| Flag | Behavior |
|------|----------|
| *(default)* / `--fit-window` | `VBoxClient` + `xrandr` fit; medium DPI **110**, Sans **12**, Monospace **12**, panel **30**; xfconf **saved**; **never** oversized resolution |
| `--text-medium` / `--text-plus15` | Medium text only (~15% over tiny baseline; same values as fit-window fonts); no geometry change |
| `--text-large` | Larger: DPI **120**, Sans **13**, Monospace **15**, panel ~36 |
| `--fonts-only` | Smaller: DPI **105**, Sans **10**, Monospace **11** |
| `--reset` | DPI **96**, default fonts, `xrandr --auto`, panel size 30 |
| `--aggressive` | Legacy: DPI 120/144, panel scale — **not** with host Scaled |
| `--diagnose-only` | Resolution, DPI, fonts, VBoxClient, cut-off warnings |
| `--login-scale` | GDM `text-scaling-factor=1.15`, `cursor-size=12`; lightdm-gtk `Sans 12` (root; greeter only) |
| `--cursor-neon` | Install **CTG-Neon-Lemon** theme (yellow circle + black ring), xfconf size **26** (X11 only) |

Autostart at login: `ctg-display-scale.sh --fit-window --cursor-neon` (sleep 2, **before** seamless).

### Neon cursor (`--cursor-neon`)

| Property | Value |
|----------|--------|
| Theme name | `CTG-Neon-Lemon` |
| Look | Neon **lemon-yellow** fill (`#FFFF00`) with **black outline** ring; small arrow tip at hotspot |
| Size | **26** px (~10% over default 24) |
| Install path | `/opt/ctg/cursors/CTG-Neon-Lemon` + `~/.icons/CTG-Neon-Lemon` |
| Build | `assets/ctg-neon-cursor/build-cursor-theme.sh` (PNG via Pillow, `xcursorgen`) |
| Session | **X11 only** — VirtualBox Kali lab uses Xfce on X11; Wayland greeter not targeted |

### Login / sign-in screen

The **GDM3** (or **lightdm-gtk**) greeter runs **before** any user Xfce session, so `--fit-window` autostart does not apply there. CTG sets:

| Display manager | File | Change |
|-----------------|------|--------|
| **gdm3** / **gdm** | `/etc/gdm3/greeter.dconf-defaults` + `/etc/dconf/db/gdm.d/` | `text-scaling-factor=1.15`, `cursor-size=12`; `dconf update` + locks |
| **gdm3** Init/PostSession | `/etc/gdm3/Init/Default/01-ctg-greeter-display` | `xrandr --auto` + `--greeter-session` every greeter (logout included) |
| **gdm3** PostSession | `/etc/gdm3/PostSession/Default/01-ctg-greeter-host-refresh` | Writes `CTG_GREETER_REFRESH` on Backups share after logout |
| **lightdm** (gtk greeter) | `/etc/lightdm/lightdm-gtk-greeter.conf.d/50-ctg-login-scale.conf` | `theme-font-name` / `clock-font-name` = Sans 12 |
| **sddm** | `/etc/sddm.conf.d/50-ctg-login-scale.conf` | Theme font Sans 12 |

Detection: `detect_ctg_display_manager()` in `ctg-display-scale.sh` (default-display-manager symlink + `systemctl is-enabled`). **Reboot or log out** to see greeter changes.

**Logout greeter small again (root cause):** First boot applies host `setvideomodehint` + guest `--login-scale` once; after desktop login `GUI/LastGuestSizeHint` reflects the session (often oversized or drops to 800×600 on logout). CTG fixes: GDM **Init** re-runs `--greeter-session` on every greeter display; **PostSession** signals the host; `Watch-CtgGreeterLogout.ps1` (started by `Start-KaliSeamless.ps1 -DisplayMode Gui`) restores `CTG/GreeterSizeHint` and re-applies `setvideomodehint` when `LoggedInUsers` → 0.

**Host (optional):** `-LoginWindowScale 1.25` bumps `setvideomodehint` while `LoggedInUsers=0` — enlarges the **whole** sign-in window. Skip when the box size is already good; use guest `--login-scale` for text only. Does not replace medium post-login fonts.

**Host (recommended):** `-DisplayMode Gui` starts the greeter logout watcher and saves/restores greeter size hints across logouts.

**Persist / save:** xfconf in `~/.config/xfce4/`; system autostart `/etc/xdg/autostart/ctg-display-scale.desktop` via `sudo bash /mnt/ctg/kali-boot-autopatch.sh --install`; per-user copy in `~/.config/autostart/` when script runs as desktop user or root.

### Autorun chain (next GUI login)

1. `ctg-display-scale.desktop` → `--fit-window --cursor-neon` (sleep 2)
2. `vboxclient-seamless.desktop` → VBoxClient (sleep 5)
3. `ctg-first-login-autorun.desktop` → mount, `--fit-window --cursor-neon`, seamless, SSH, lab chain (first run only)
4. `ctg-watch-trigger.sh` → Windows `CTG_TRIGGER_AUTORUN` on Backups share

### `Start-KaliSeamless.ps1`

- Always: `GUI/AutoresizeGuest=true`, clear bad `GUI/LastGuestSizeHint` (>2560×1600)
- **Gui** (recommended for cut-off / blown-out): `GUI/Scale=false`, seamless off
- **Scaled**: `GUI/Scale=true` — pair with guest `--fit-window`, not `--aggressive`
- Running VM + Gui: optional `setvideomodehint` from current hint (VB7 GA refresh)
- **Gui/Scaled:** background `Watch-CtgGreeterLogout.ps1` — on logout (`LoggedInUsers=0`) or `CTG_GREETER_REFRESH`, clears stale `LastGuestSizeHint` and re-applies greeter `setvideomodehint`

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
| Text too big | `--fit-window` or `--text-medium` (DPI 110); avoid re-running `--text-large` |
| Text still small after fit | `--text-large`; or `--text-plus15` if between tiny and medium |
| Cursor unchanged | Re-run `--cursor-neon`; log out/in; confirm X11 session |
| Seamless breaks display | Run `--fit-window` **before** `ctg-seamless-guest.sh` |

Open a **new** terminal window after font changes.
