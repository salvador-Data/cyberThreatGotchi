# Kali seamless mode — toolbar, host keys, guest panel

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

See also: [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md) (install, autopatch, diagnose).

## Glitch and revert when selecting Seamless

**Symptom:** View → Seamless Mode (or Host+L) flashes, then returns to windowed/scaled.

**Root cause (guest):** VirtualBox seamless needs an **X11** session with **`VBoxClient --seamless`**
running. If the guest is on **Wayland**, or VBoxClient crashed, the host enables seamless and the
guest cannot report window regions — VirtualBox immediately reverts.

| Cause | Fix |
|-------|-----|
| **Wayland session** | `WaylandEnable=false` in `/etc/gdm3/custom.conf`, log out, log in as **Xfce** (Xorg) |
| **VBoxClient not running** | `bash /mnt/ctg/ctg-seamless-guest.sh` (restarts `--vmsvga` + `--seamless`) |
| **GUI/Scale still true** | Host: `Start-KaliSeamless.ps1 -DisplayMode Seamless` sets `GUI/Scale=false` |
| **No GUI login** | Log in at Kali console first |

**Verify seamless stays on:** after the guest fix, press **Host+L** once. `VBoxManage showvminfo kali`
should show `Facility "Seamless Mode": active`.

**Scaled mode still works** — use `-DisplayMode Scaled` when you want menu/scrollbars; seamless is separate.

## ROOT CAUSE: seamless mode has no toolbar by design

After setting `GUI/ShowMiniToolBar=true` the toolbar still did not appear. The real reason:

> **VirtualBox seamless mode deliberately removes ALL window chrome** — no menu bar, no
> status bar, no scrollbars. Its *only* chrome is the floating **mini toolbar**, and on
> **VirtualBox 7 the mini toolbar frequently fails to render in seamless mode** (known
> upstream bug: tickets #19150, #22216). It works reliably only in **full-screen** mode.

So no extradata key can make a usable toolbar/scrollbar appear *in seamless*. If you want a
**visible toolbar + scrollbars** (what Andy is asking for), do not use seamless — use
**Scaled** or **Normal windowed** mode, which keep the full VirtualBox menu bar and scroll.

### What we auto-set live on VM `kali` (VB 7.0.18)

| Extradata key | Value | Why |
|---------------|-------|-----|
| `GUI/Seamless` | `off` | leave seamless so chrome (menu/scroll) is visible |
| `GUI/Scale` | `true` | Scaled window — guest fits the window, no clipping/wrap |
| `GUI/AutoresizeGuest` | `true` | guest tracks window size (was `false` → caused wrap/clip at 3428×1660) |
| `GUI/ShowMiniToolBar` | `true` | mini toolbar (only helps full-screen) |
| `GUI/MiniToolBarAutoHide` | `false` | keep mini toolbar pinned when it does show |
| `GUI/MiniToolBarAlignment` | `top` | mini toolbar at top edge |

The original wrap/clip was driven by `GUI/AutoresizeGuest=false` + a large `GUI/LastGuestSizeHint`
(`3428,1660`). With autoresize on and Scaled mode, the guest no longer wraps off-screen.

## Recommended: Scaled or Normal window (visible chrome + scroll)

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DisplayMode Scaled
```

`-DisplayMode Scaled` = guest scaled to fit the window (menu bar visible, no scrollbars needed).
`-DisplayMode Gui` = normal window (menu bar **and** real scrollbars when guest > window).

On the **running** VM window you can switch instantly:

| Shortcut | Mode |
|----------|------|
| **Host + L** | seamless ↔ normal |
| **Host + C** | scaled ↔ normal |
| **Host + Home** | show the VM menu bar |
| **Host + F** | full screen (mini toolbar works here) |

VirtualBox 7 does **not** support `VBoxManage controlvm kali seamless on`. Host key defaults to
**Right Ctrl** (change in VirtualBox → **File → Preferences → Input**).

## Kali guest fix (panel visible + autoresize, no wrap)

The guest helper forces the desktop panel visible (XFCE or GNOME), disables autohide, reserves
screen space, starts `VBoxClient --vmsvga`/`--seamless` for dynamic resize, and installs a
per-user autostart so it persists across logins.

```bash
bash /mnt/ctg/ctg-seamless-guest.sh
```

`kali-boot-autopatch.sh` runs this automatically when a graphical session is present.

## Windows — start / diagnose

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1
```

Parameters:

- **`-DisplayMode Scaled`** — scaled window, full menu bar visible (recommended for visible chrome)
- **`-DisplayMode Gui`** — normal window with menu bar **and** scrollbars
- **`-DisplayMode Seamless`** — default; no chrome by design (see root cause above)
- **`-NoShowHostToolbar`** — do not set mini-toolbar extradata
- **`-DiagnoseOnly`** — lists VM state, session, all `GUI/*` extradata, issues

Log: `C:\Users\Owner\Backups\logs\kali-seamless.log`

## Manual extradata (VirtualBox 7)

Visible chrome (scaled window):

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" setextradata kali GUI/Seamless off
```

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" setextradata kali GUI/Scale true
```

Prevent wrap/clip:

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" setextradata kali GUI/AutoresizeGuest true
```

`GUI/Seamless` accepts **on** or **true** (both treated as enabled by CTG scripts).
