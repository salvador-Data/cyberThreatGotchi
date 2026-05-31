# Kali lab audit — printable checklist

**Hacker Planet LLC / CyberThreatGotchi** · VirtualBox Kali · **authorized lab only** · **no secrets on this page**

**Full refs:** [../CTG_LAB_AUTORUN.md](../CTG_LAB_AUTORUN.md) · [../KALI_RETBLEED_SPECTRE.md](../KALI_RETBLEED_SPECTRE.md) · [../KALI_VIRTUALBOX_SEAMLESS.md](../KALI_VIRTUALBOX_SEAMLESS.md) · [../KALI_DISPLAY_SCALING.md](../KALI_DISPLAY_SCALING.md) · [../NMAP_ASK_ANALYSIS.md](../NMAP_ASK_ANALYSIS.md)

---

## PRESERVE — DuckDuckGo (Windows host + iPhone)

CTG Kali runs on Windows SOC. **Do not** change host DuckDuckGo VPN/DNS while tuning the VM.

- [ ] Windows DDG VPN/DNS verified before/after Kali session — see [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md)

---

## Run order (recommended)

1. Windows: stage scripts to share (`Stage-KaliLabToBackups.ps1`)
2. Boot Kali VM → log into Xfce
3. **CLICK-ME** one-shot lab chain
4. Display scale + seamless (if UI tiny)
5. RETBleed / memory diagnose
6. Deauth watch + lab AP diagnose (lab-only)
7. `a$k` gate verify

---

## CLICK-ME — one-action lab chain

- [ ] Share mounted: `/media/sf_ctg-backups` or `/mnt/ctg`
- [ ] Double-click **CTG Run Lab (click me)** in Thunar, or:

```bash
bash /media/sf_ctg-backups/CLICK-ME-RUN-IN-KALI.sh
```

- [ ] Enter sudo password once when prompted
- [ ] Chain completes without fatal errors (note skips in log)

Fallback if SSH/autopatch fails:

```bash
sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh
```

---

## Display scale (tiny UI fix)

- [ ] Read [../KALI_DISPLAY_SCALING.md](../KALI_DISPLAY_SCALING.md)
- [ ] Settings → Appearance → **200%** or **240%** if 1080p host
- [ ] Optional: `ctg-fix-kali-display-scale.sh --diagnose-only`

---

## Seamless mode (host integration)

- [ ] VM powered off before host CPU flags change
- [ ] [../KALI_SEAMLESS_MODE.md](../KALI_SEAMLESS_MODE.md) — Host+Home / toolbar
- [ ] [../KALI_VIRTUALBOX_SEAMLESS.md](../KALI_VIRTUALBOX_SEAMLESS.md) — guest additions
- [ ] Accept **green turtle** if VBS/HVCI enabled on host (CTG policy — do not disable HVCI for speed)

Host (Windows, VM off):

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Harden-KaliVmCpu.ps1 -DiagnoseOnly
```

---

## RETBleed / memory diagnose

- [ ] Host: `VBoxManage modifyvm kali --spec-ctrl on` (VM **off**)
- [ ] Reboot Kali guest after spec-ctrl change
- [ ] In guest:

```bash
bash /mnt/ctg/ctg-retbleed-check.sh
```

```bash
bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh --diagnose-only
```

- [ ] **Never** `mitigations=off` or `--spec-ctrl off`
- [ ] Print companion: [MEMORY_PROTECTION_AUDIT_PRINT.md](MEMORY_PROTECTION_AUDIT_PRINT.md)

---

## Deauth watch (detect-only)

- [ ] Kali: `ctg-deauth-watch.sh --diagnose` (no counter-jam)
- [ ] Windows: `Detect-CtgWifiJam.ps1 -DiagnoseOnly`
- [ ] Log disconnect storms; failover = wired/cellular/VPN — **not** RF jam-back

---

## Lab AP — CTG-UTMS-LAB (lab-only gate)

**Never** evil twin · **never** clone production SSIDs · authorized isolated lab only.

- [ ] `/etc/ctg/lab-wifi.conf` exists (mode 600) — placeholders in git only
- [ ] `/etc/ctg/lab-targets.conf` scoped to owned targets

Diagnose:

```bash
sudo bash /mnt/ctg/ctg-lab-ap-setup.sh --diagnose
```

Apply (requires explicit ack + real lab-wifi.conf):

```bash
sudo bash /mnt/ctg/ctg-lab-ap-setup.sh --apply --i-understand-lab-only
```

- [ ] SSID distinct: **CTG-UTMS-LAB** (not home/production name)
- [ ] Full doc: [../LAB_AP_UTMS.md](../LAB_AP_UTMS.md)

---

## a$k gate — defensive nmap wrapper

- [ ] `a$k --help` works after boot autopatch
- [ ] `ctg-nmap-ask` installed to `/usr/local/bin/`
- [ ] Scans respect `lab-targets.conf` — no out-of-scope IPs
- [ ] State under `/var/log/ctg/nmap-ask/` (JSON — no passwords)

Quick verify:

```bash
a$k --help
```

```bash
a$k --list
```

---

## Golden snapshot (after clean CLICK-ME)

- [ ] Windows: `Snapshot-CtgKaliGolden.ps1` when chain is clean
- [ ] Credentials from vault only — `Invoke-CtgKaliGuestFlash.ps1 -UseSecretVault` (no passwords in git)

---

## End-of-session VERIFY

- [ ] RETBleed check not **Vulnerable** (or documented exception with microcode plan)
- [ ] Windows DDG VPN/DNS unchanged from baseline
- [ ] Lab AP stopped if not needed (`hostapd` down)
- [ ] Notes in [../CTG_NEXT_STEPS.md](../CTG_NEXT_STEPS.md) for skipped Admin items

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · Kali lab · authorized scope only · no passwords on paper
