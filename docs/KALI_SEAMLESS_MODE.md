# Kali seamless mode â€” toolbar, host keys, guest panel

**Hacker Planet LLC Â· Philadelphia, PA Â· authorized lab use only**

See also: [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md) (install, autopatch, diagnose).

## Glitch and revert when selecting Seamless

**Symptom:** View â†’ Seamless Mode (or Host+L) flashes, then returns to windowed/scaled.

**Root cause (guest):** VirtualBox seamless needs an **X11** session with **`VBoxClient --seamless`**
running. If the guest is on **Wayland**, or VBoxClient crashed, the host enables seamless and the
guest cannot report window regions â€” VirtualBox immediately reverts.

| Cause | Fix |
|-------|-----|
| **Wayland session** | `WaylandEnable=false` in `/etc/gdm3/custom.conf`, log out, log in as **Xfce** (Xorg) |
| **VBoxClient not running** | `bash /mnt/ctg/ctg-seamless-guest.sh` (restarts `--vmsvga` + `--seamless`) |
| **GUI/Scale still true** | Host: `Start-KaliSeamless.ps1 -DisplayMode Seamless` sets `GUI/Scale=false` |
| **No GUI login** | Log in at Kali console first |

**Verify seamless stays on:** after the guest fix, press **Host+L** once. `VBoxManage showvminfo kali`
should show `Facility "Seamless Mode": active`.

**Scaled mode still works** â€” use `-DisplayMode Scaled` when you want menu/scrollbars; seamless is separate.

## ROOT CAUSE: seamless mode has no toolbar by design

After setting `GUI/ShowMiniToolBar=true` the toolbar still did not appear. The real reason:

> **VirtualBox seamless mode deliberately removes ALL window chrome** â€” no menu bar, no
> status bar, no scrollbars. Its *only* chrome is the floating **mini toolbar**, and on
> **VirtualBox 7 the mini toolbar frequently fails to render in seamless mode** (known
> upstream bug: tickets #19150, #22216). It works reliably only in **full-screen** mode.

So no extradata key can make a usable toolbar/scrollbar appear *in seamless*. If you want a
**visible toolbar + scrollbars** (what Andy is asking for), do not use seamless â€” use
**Scaled** or **Normal windowed** mode, which keep the full VirtualBox menu bar and scroll.

### What we auto-set live on VM `kali` (VB 7.0.18)

| Extradata key | Value | Why |
|---------------|-------|-----|
| `GUI/Seamless` | `off` | leave seamless so chrome (menu/scroll) is visible |
| `GUI/Scale` | `true` | Scaled window â€” guest fits the window, no clipping/wrap |
| `GUI/AutoresizeGuest` | `true` | guest tracks window size (was `false` â†’ caused wrap/clip at 3428Ã—1660) |
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
| **Host + L** | seamless â†” normal |
| **Host + C** | scaled â†” normal |
| **Host + Home** | show the VM menu bar |
| **Host + F** | full screen (mini toolbar works here) |

VirtualBox 7 does **not** support `VBoxManage controlvm kali seamless on`. Host key defaults to
**Right Ctrl** (change in VirtualBox â†’ **File â†’ Preferences â†’ Input**).

## If step 1 fails â€” troubleshooting tree

| Step / command | Error / symptom | Try next |
|----------------|-----------------|----------|
| `bash /mnt/ctg/ctg-seamless-guest.sh` | `No such file` | Mount share first: `sudo bash /media/sf_ctg-backups/ctg-mount-share.sh` |
| `sudo mount -t vboxsf ctg-backups /mnt/ctg` | `protocol error` | Install Guest Additions via `kali-boot-autopatch.sh --install`, reboot |
| `ctg-seamless-guest.sh --diagnose-only` | `No graphical (:N) desktop user` | Open VM window, **log into Xfce**, then re-run |
| Seamless reverts (Host+L) | Wayland session | Script sets `WaylandEnable=false` â€” log out, log in on **X11/Xfce**, re-run guest script |
| `VBoxClient not found` | Missing guest utils | `sudo bash /mnt/ctg/kali-boot-autopatch.sh --install` |

**Correct order:** GUI login â†’ mount share â†’ seamless guest script.

## Kali guest fix (panel visible + autoresize, no wrap)

The guest helper forces the desktop panel visible (XFCE or GNOME), disables autohide, reserves
screen space, starts `VBoxClient --vmsvga`/`--seamless` for dynamic resize, and installs a
per-user autostart so it persists across logins.

**Step 1 â€” mount:**

```bash
sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
```

**Step 2 â€” after GUI login:**

```bash
bash /mnt/ctg/ctg-seamless-guest.sh
```

`kali-boot-autopatch.sh` runs this automatically when a graphical session is present.

## Seamless mode text (smaller while seamless, medium after)

Medium post-login default (**DPI 108 / Sans 11 / Monospace 12**) is restored at every session login via autostart. While **seamless is active**, text is temporarily reduced so panels and terminals fit the host viewport.

**Flow:**

1. Log in â†’ autostart `--restore-medium` (108/11/12)
2. Host+L into seamless â†’ run `--enter-seamless` (or `ctg-seamless-guest.sh`, which calls it at the end)
3. Host+L out of seamless â†’ run `--exit-seamless`

**In Kali after Host+L into seamless:**

```bash
bash /mnt/ctg/ctg-seamless-text-toggle.sh --enter-seamless
```

**After Host+L back to windowed/scaled:**

```bash
bash /mnt/ctg/ctg-seamless-text-toggle.sh --exit-seamless
```

| Preset | DPI | Gtk | Terminal | When |
|--------|-----|-----|----------|------|
| **Medium** (default) | 108 | Sans 11 | Monospace 12 | Login, windowed, scaled, after `--exit-seamless` |
| **Seamless reduce** | 100 | Sans 10 | Monospace 11 | Active seamless (`--enter-seamless`) |

**Windows host** (prints toggle hints after you press Host+L):

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -AfterSeamlessToggle
```

See [KALI_DISPLAY_SCALING.md](KALI_DISPLAY_SCALING.md) for greeter vs desktop text layers.

## Windows â€” start / diagnose

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Start-KaliSeamless.ps1
```

Parameters:

- **`-DisplayMode Scaled`** â€” scaled window, full menu bar visible (recommended for visible chrome)
- **`-DisplayMode Gui`** â€” normal window with menu bar **and** scrollbars
- **`-DisplayMode Seamless`** â€” default; no chrome by design (see root cause above)
- **`-NoShowHostToolbar`** â€” do not set mini-toolbar extradata
- **`-AfterSeamlessToggle`** â€” print guest `--enter-seamless` / `--exit-seamless` commands (after Host+L)
- **`-DiagnoseOnly`** â€” lists VM state, session, all `GUI/*` extradata, issues

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
