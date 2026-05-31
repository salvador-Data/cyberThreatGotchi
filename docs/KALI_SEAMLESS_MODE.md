# Kali seamless mode — toolbar, host keys, guest panel

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

Seamless mode works when Guest Additions and a graphical login are present. The most common “no toolbar” report is **not broken seamless** — it is **hidden host chrome** or a **guest panel set to autohide**.

See also: [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md) (install, autopatch, diagnose).

## Why the toolbar was invisible (Andy workstation, VB 7.0.18)

| Layer | Cause | Fix |
|-------|--------|-----|
| **Host VirtualBox** | `GUI/ShowMiniToolBar` was **false** | `Start-KaliSeamless.ps1` sets `GUI/ShowMiniToolBar=true` by default; live: already applied on VM **kali** |
| **Host menu** | In seamless, the full VM menu bar is hidden until you use the Host key | **Right Ctrl + Home** (Host+Home) opens the menu |
| **Mini toolbar** | VB often only auto-shows it at the **top screen edge** in seamless; Windows taskbar can steal the edge | Move mouse to top edge; **pin** with the thumbtack; or use Host+Home |
| **Guest XFCE panel** | Panel autohide hides the Kali top bar in seamless | `bash /mnt/ctg/ctg-seamless-guest.sh` |

VirtualBox 7 does **not** support `VBoxManage controlvm kali seamless on`. Toggle with **Host+L** after login.

## Host key shortcuts (default Host = Right Ctrl)

| Shortcut | Action |
|----------|--------|
| **Host + L** | Toggle seamless ↔ normal/scaled window |
| **Host + Home** | Show VirtualBox menu (File, Machine, View, …) when chrome is hidden |
| **Host + F** | Full screen |
| **Top edge of screen** | Reveal mini toolbar (if `GUI/ShowMiniToolBar=true`) |

Change Host key: VirtualBox → **File → Preferences → Input**.

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

- **`-DisplayMode Scaled`** — normal resizable window (`GUI/Seamless=off`)
- **`-DisplayMode Seamless`** — default; sets `GUI/Seamless=on` and `GUI/ShowMiniToolBar=true`
- **`-NoShowHostToolbar`** — do not set mini-toolbar extradata
- **`-DiagnoseOnly`** — lists VM state, session, all `GUI/*` extradata, issues

Log: `C:\Users\Owner\Backups\logs\kali-seamless.log`

## Guest one-liner (panel still missing)

After graphical login (not from TTY-only):

```bash
bash /mnt/ctg/ctg-seamless-guest.sh
```

Boot-time: `kali-boot-autopatch.sh` installs `VBoxClient --seamless` autostart and guest packages.

## Manual extradata (VirtualBox 7)

```powershell
VBoxManage setextradata kali GUI/Seamless on
```

```powershell
VBoxManage setextradata kali GUI/ShowMiniToolBar true
```

`GUI/Seamless` accepts **on** or **true** (both treated as enabled by CTG scripts).
