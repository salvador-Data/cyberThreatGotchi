# Kali display scaling — tiny terminal and UI fix

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

See also: [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) (seamless/scaled window modes).

## Symptom

Terminal text, panel icons, and dialog boxes are **too small** in the Kali guest. Common on Andy's
Windows 11 laptop with **150% display scaling** and VirtualBox seamless/scaled mode.

## Root causes

| Cause | Effect |
|-------|--------|
| `GUI/LastGuestSizeHint` saved at **3428×1660** (or similar) | Guest thinks the display is huge → UI renders tiny |
| `GUI/AutoresizeGuest=false` | Guest does not track the host window |
| XFCE default **96 DPI** | Fonts/panels stay small on dense resolutions |
| `VBoxClient --display` / `--vmsvga` not running | No dynamic resize after login |

## Immediate fix (Kali guest terminal)

Run after you are logged into the **Xfce desktop** (not SSH-only):

```bash
bash /mnt/ctg/ctg-display-scale.sh
```

If `/mnt/ctg` is not mounted:

```bash
sudo mkdir -p /mnt/ctg
```

```bash
sudo mount -t vboxsf ctg-backups /mnt/ctg
```

```bash
bash /mnt/ctg/ctg-display-scale.sh
```

Diagnose only (no changes):

```bash
bash /mnt/ctg/ctg-display-scale.sh --diagnose-only
```

## Permanent fix (autopatch + host)

**Kali** — install boot autopatch once (runs display scale after seamless setup on every boot):

```bash
sudo bash /mnt/ctg/kali-boot-autopatch.sh --install
```

**Windows** — stage scripts with LF line endings, set host extradata, clear bad size hint:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Stage-KaliLabToBackups.ps1
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DisplayMode Scaled
```

## What the scripts auto-do

### `ctg-display-scale.sh`

- Starts `VBoxClient --vmsvga` (fallback `--display`) for autoresize
- Runs `xrandr --auto`; caps absurd modes (>3200 px wide) to 1920×1080 when available
- Sets XFCE `/Xft/DPI` to **96**, **120**, or **144** based on detected resolution
- Enlarges XFCE panel size and **xfce4-terminal** font (`Monospace 11/12/14`)
- Optional GNOME: `text-scaling-factor` 1.0 / 1.25 / 1.5
- Installs per-user autostart `ctg-display-scale.desktop` for login

### `kali-boot-autopatch.sh` (every boot)

- Runs `ctg-seamless-guest.sh` then `ctg-display-scale.sh` when a GUI session exists on `:0`

### `Start-KaliSeamless.ps1` (Windows host)

- Sets `GUI/AutoresizeGuest=true`
- **Deletes** `GUI/LastGuestSizeHint` when width > 2560 or height > 1600 (fixes 3428×1660 hint)
- Scaled mode: `GUI/Scale=true`, `GUI/Seamless=off` (visible menu + scrollbars)

## On next boot (after `--install`)

1. `ctg-kali-autopatch.service` runs `kali-boot-autopatch.sh`
2. Guest additions + VBoxClient autostart are ensured
3. After GUI login, `ctg-seamless-guest.sh` and `ctg-display-scale.sh` run automatically
4. Per-user autostart re-applies scale fixes at each login

## Manual DPI override (XFCE)

```bash
xfconf-query -c xsettings -p /Xft/DPI -s 120
```

```bash
xfce4-panel -r
```

Open a **new** terminal tab/window after changing fonts.
