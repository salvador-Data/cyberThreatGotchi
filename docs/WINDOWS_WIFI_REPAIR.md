# Windows Wi-Fi repair (conservative)

Authorized use on **Andy-owned** Windows SOC laptops. Does not attack networks or delete saved SSIDs.

## Script

`scripts/windows/Repair-WindowsWifi.ps1`

| Mode | What it does |
|------|----------------|
| Default / `-DiagnoseOnly` | WlanSvc, adapters, netsh WLAN state, profile **count** (names preview), DDG DNS check, DDG VPN preserve |
| `-ApplyFixes` (Admin) | Restart **WlanSvc**, **enable** disabled Wi-Fi adapters, **`ipconfig /flushdns`** only |
| `-ResetStack` (with `-ApplyFixes`) | **Explicit only:** `netsh winsock reset` + `netsh int ip reset` — reboot required; may disturb VPN until reconnect |

**Never from this script:** mass profile deletion, changing DNS servers, installing alternate VPNs, router changes.

## DuckDuckGo preserve

- DNS: `94.140.14.14` / `94.140.15.15` on an adapter is reported; flush clears cache, not server list.
- VPN: dot-sources `Preserve-DuckDuckGoVpn.ps1` (Defender exclusions; no Cloudflare/NextDNS install).

## WPA3 (documentation)

**Home router (manual):**

- Use WPA3-Personal (SAE) or WPA2/WPA3 transition mode on your AP.
- Enable 802.11w (PMF) when the AP supports it.
- Unique PSK; rotate after travel if you used untrusted hotspots.

**Optional lab profile (Windows):**

1. Export on a trusted machine: `netsh wlan export profile name="LabSsid" folder=%USERPROFILE%\Backups`
2. Import one file: `Repair-WindowsWifi.ps1 -ApplyFixes -LabWpa3ProfileXml C:\Users\Owner\Backups\LabSsid.xml`
3. Connect: `netsh wlan connect name="LabSsid"`

Kali guest WiFi (WPA3-SAE): see [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md).

## Run

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
.\scripts\windows\Repair-WindowsWifi.ps1 -DiagnoseOnly
```

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
.\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Repair-WindowsWifi.ps1 -TargetArguments '-ApplyFixes'
```

Log: `%USERPROFILE%\Backups\logs\repair-windows-wifi.log`

## Related

- [DEFENSE_DDOS_ROGUE_WIFI.md](DEFENSE_DDOS_ROGUE_WIFI.md)
- [IPHONE_HARDENING.md](IPHONE_HARDENING.md) (DDG policy)