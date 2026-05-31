# Kali display scaling — fit window + readable text

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

See also: [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) (seamless/scaled window modes).

## Symptom

Terminal text, panel labels, and GTK dialogs are **too small** in the Kali guest, but the **whole desktop** may already look correct-sized or **too large** after prior fixes.

| What you want | What to use |
|---------------|-------------|
| Guest resolution **fits the VM window** (autoresize) | `VBoxClient` + host `AutoresizeGuest` + `-DisplayMode Gui` |
| **Larger text only** (terminal, menus) | `ctg-display-scale.sh --fonts-only` (DPI 108–112, not 144) |
| Undo **everything oversized** | `ctg-display-scale.sh --reset` then `--fonts-only` |
| Whole desktop intentionally larger | `--aggressive` only in lab edge cases — **not** with host `Scaled` |

## What went wrong before (2026-05-31)

Combining **host `-DisplayMode Scaled`**, **guest Xft DPI 120/144**, and **xrandr cap to 1920×1080** made the entire VM UI huge. Andy’s fix path: **Gui + autoresize + fonts-only**.

## Quick fix (Kali — one command per step)

**1. Mount share** (if needed):

```bash
sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
```

**2. Reset over-scaling** (if desktop/fonts are huge):

```bash
bash /mnt/ctg/ctg-display-scale.sh --reset
```

**3. Apply fonts-only** (after Xfce login):

```bash
bash /mnt/ctg/ctg-display-scale.sh --fonts-only
```

**4. Windows host** — windowed autoresize, not Scaled:

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

## Root causes

| Cause | Effect |
|-------|--------|
| `GUI/LastGuestSizeHint` saved at **3428×1660** (or similar) | Guest resolution inflated → tiny UI until hint cleared |
| `GUI/AutoresizeGuest=false` | Guest does not track the host window |
| XFCE default **96 DPI** | Fonts stay small on dense displays |
| `VBoxClient --display` / `--vmsvga` not running | No dynamic resize after login |
| Host **Scaled** + guest **DPI 144** | Entire desktop and chrome look huge |

## If step 1 fails — troubleshooting tree

| What you ran | Error / symptom | Try next |
|--------------|-----------------|----------|
| `bash /mnt/ctg/ctg-display-scale.sh` | `No such file or directory` | Mount share first; re-stage on Windows |
| `sudo mount -t vboxsf ctg-backups /mnt/ctg` | `protocol error` | Guest Additions — `kali-boot-autopatch.sh --install`, reboot |
| `ctg-display-scale.sh` | `No graphical (:N) desktop user` | **Log into Xfce GUI** first |
| `ctg-display-scale.sh` | `$'\r': command not found` | `Stage-KaliLabToBackups.ps1`, remount |
| Desktop **too big** after old script | Over-scaled | `--reset` then `--fonts-only`; host `-DisplayMode Gui` |

**Correct order:** GUI login → mount share → `--reset` (if needed) → `--fonts-only`.

## Permanent fix (autopatch + host)

**Kali** — boot autopatch runs **fonts-only** by default:

```bash
sudo bash /mnt/ctg/kali-boot-autopatch.sh --install
```

**Windows** — stage LF scripts, clear bad size hint, prefer Gui for text-small:

```powershell
.\scripts\windows\Stage-KaliLabToBackups.ps1
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DisplayMode Gui
```

Do **not** use `-DisplayMode Scaled` when the only problem is small terminal text.

## What the scripts do

### `ctg-display-scale.sh` (default: `--fonts-only`)

| Flag | Behavior |
|------|----------|
| *(default)* / `--fonts-only` | `VBoxClient` autoresize; Xft DPI **108** or **112**; terminal **Monospace 13–14**; Gtk **Sans 11–12**; **no** panel blow-up; **no** xrandr force 1920 |
| `--reset` | DPI **96**, default fonts, `xrandr --auto`, panel size 30 |
| `--aggressive` | Legacy: DPI 120/144, panel scale, xrandr cap if width > 3200 |
| `--diagnose-only` | Resolution, DPI, fonts, VBoxClient status |

Autostart at login: `ctg-display-scale.sh --fonts-only`.

### `kali-boot-autopatch.sh`

Runs `ctg-display-scale.sh --fonts-only` when GUI session on `:0`.

### `Start-KaliSeamless.ps1`

- Always: `GUI/AutoresizeGuest=true`, clear bad `GUI/LastGuestSizeHint`
- **Gui** (recommended for text-small): `GUI/Scale=false`, seamless off
- **Scaled**: `GUI/Scale=true` — do not pair with guest DPI 120/144; use `--fonts-only` in guest instead

## On next boot (after `--install`)

1. `ctg-kali-autopatch.service` runs `kali-boot-autopatch.sh`
2. Guest additions + VBoxClient autostart ensured
3. After GUI login: seamless helper + **fonts-only** display scale
4. Per-user autostart re-applies `--fonts-only` at login

## Manual DPI override (XFCE)

Modest bump only:

```bash
xfconf-query -c xsettings -p /Xft/DPI -s 108
```

```bash
xfce4-panel -r
```

Open a **new** terminal window after font changes.
