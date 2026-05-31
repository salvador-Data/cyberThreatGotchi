# Kali on VirtualBox — seamless mode

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

Seamless mode integrates the Kali guest desktop with your Windows host: Kali windows appear on the host without the VirtualBox frame. This is the preferred way to run the CTG lab VM named **kali** day to day.

## Quick start (Windows host)

From the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
.\scripts\windows\Start-KaliSeamless.ps1
```

Log: `C:\Users\Owner\Backups\logs\kali-seamless.log`

CTG Lab Playground option **7**, `Start-CTGLab.ps1`, and `Deploy-KaliLab.ps1 -StartVmIfStopped` all call this script for the **kali** VM.

## Professor note: seamless vs full screen

| Mode | What you see | Toggle (Windows host) |
|------|----------------|------------------------|
| **Seamless** | Guest apps float on the host desktop; no VM window chrome | **Host + L** |
| **Full screen** | Entire monitor is the guest display | **Host + F** |
| **Scaled / normal window** | Guest inside a resizable VirtualBox window | **Host + L** or View menu |

Seamless is best when you want Kali terminals and browsers beside Windows Wireshark and Cursor. Full screen is better for long in-guest-only sessions (e.g. Burp on a single monitor).

**Host key** defaults to **Right Ctrl** unless you changed it in VirtualBox → File → Preferences → Input.

## Requirements

1. **Oracle VirtualBox** 6.1+ (7.x supported; script sets optional `GUI/SeamlessMode` extradata).
2. **Guest Additions** in Kali — packages `virtualbox-guest-x11`, `virtualbox-guest-utils`, `dkms`.
3. Guest logged in to a graphical session (GDM/X11; autopatch sets `WaylandEnable=false` for VirtualBox stability).

Without Guest Additions, seamless start fails. The host script falls back to a normal GUI window and logs fix steps.

## Fix missing Guest Additions

**In Kali** (after mounting the share):

```bash
sudo mkdir -p /mnt/ctg
sudo mount -t vboxsf ctg-backups /mnt/ctg
sudo bash /mnt/ctg/kali-boot-autopatch.sh --install
# or blank-screen one-shot:
sudo bash /mnt/ctg/fix-kali-blank-screen.sh
```

Reboot Kali, then on Windows:

```powershell
.\scripts\windows\Start-KaliSeamless.ps1
```

**From Windows** (deploy autopatch over SSH):

```powershell
.\scripts\windows\Deploy-KaliBootAutopatch.ps1
```

Boot autopatch installs `virtualbox-guest-x11` on every boot via `ctg-kali-autopatch.service`.

## Manual VirtualBox commands

VirtualBox **7.x** removed `--type seamless` and `controlvm seamless on`. Use extradata + GUI start:

```powershell
VBoxManage setextradata kali GUI/Seamless on
VBoxManage startvm kali --type gui
```

VirtualBox **6.x** (legacy):

```powershell
VBoxManage startvm kali --type seamless
VBoxManage controlvm kali seamless on
```

Toggle anytime: **Host + L** (Host key defaults to Right Ctrl).

## Related docs

- [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) — master lab autorun
- [CTG_LAB_PLAYGROUND.md](CTG_LAB_PLAYGROUND.md) — playground menu option 7
- Blank screen after login: `fix-kali-blank-screen.sh` / `Fix-KaliBlankScreen.ps1`
