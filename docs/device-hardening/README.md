# CTG device hardening

**Hacker Planet LLC / CyberThreatGotchi** â€” defensive device and host hardening for **authorized lab use only**.

Focused collection of iPhone laptop-connection guidance, Windows/Kali exploit-mitigation helpers, IDS/IPS documentation cross-links, Signal alert references, and vulnerability feed sync â€” split from the [cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi) monorepo for labs that want hardening without the full Tamagotchi stack.

## What this repo contains

| Area | Contents |
|------|----------|
| **iPhone + laptop** | Honest scope docs (no MAC spoofing from Windows); read-only checklist; tether egress IDS |
| **IDS/IPS** | Links to Snort/Suricata stacks; network vs RAM exploit table |
| **CPU mitigations** | Windows `Enforce-CtgRamMitigations.ps1`, `Update-CtgExploitMitigations.ps1`, Kali `ctg-ram-mitigation-enforcer.sh` |
| **Patch intelligence** | CISA KEV sync to local cache (no auto-install) |
| **Alerts** | Signal-first IDS alerts â€” see `docs/SIGNAL_ALERTS.md` in monorepo |

## iPhone â€” honest limits

Apple does **not** let Windows scripts rewrite iPhone MAC addresses, UDID, or Settings without **MDM**. CTG provides:

- Manual Settings checklists (Private Wiâ€‘Fi Address, Limit IP Tracking, USB Restricted Mode)
- **Preserve DuckDuckGo VPN/DNS** and DuckDuckGo Password Manager
- Read-only USB detection: `scripts/iphone/iphone_tethering_privacy_checklist.ps1`

See `docs/IPHONE_LAPTOP_CONNECTION.md` and `docs/IPHONE_TETHER_MONITORING.md`.

## IDS vs RAM exploits

| Layer | Snort/Suricata | Microcode + OS patches |
|-------|----------------|------------------------|
| Network shellcode, C2, scans | Detect / alert | Firewall + patch |
| Spectre, RETBleed, Meltdown | **Not blocked** | Windows Update, Kali kernel, VBox `--spec-ctrl on` |

**RAM IPS** in CTG = host enforcer (`Enforce-CtgRamMitigations.ps1`), not packet IPS. See `docs/RAM_MITIGATION_IPS.md`.

Signal/IDS scripts alert on network and RAM-mit exposure; mitigation is host patching.

## Quick start (Windows SOC)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\ctg-device-hardening
```

```powershell
.\scripts\iphone\iphone_tethering_privacy_checklist.ps1 -DetectUsb
```

```powershell
.\scripts\windows\Start-CtgIphoneTetherIds.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Enforce-CtgRamMitigations.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Update-CtgExploitMitigations.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Sync-CtgVulnerabilityFeeds.ps1 -DiagnoseOnly
```

## Sync from monorepo

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\publish\Sync-CtgDeviceHardeningRepo.ps1
```

Commit and push this repo after sync.

## Private lab repos

Use `scripts/publish/Set-CtgPrivateRepos.ps1 -DiagnoseOnly` in the monorepo to review which salvador-Data hardening repos should be private. `-Apply` only affects names in the **committed allowlist**.

## License

MIT â€” same as CyberThreatGotchi monorepo.

## Author

[Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/) Â· Philadelphia, PA
