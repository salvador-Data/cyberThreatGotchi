# UTMS Wi‑Fi AI audit — printable checklist

**Hacker Planet LLC / CyberThreatGotchi** · detect + failover only · **no RF counter-jam** · **no secrets on this page**

**Full refs:** [../UTMS_WIFI_AI.md](../UTMS_WIFI_AI.md) · [../LAB_AP_UTMS.md](../LAB_AP_UTMS.md) · [../CARDPUTER_UTMS_WIFI.md](../CARDPUTER_UTMS_WIFI.md) · [../DEFENSE_DDOS_ROGUE_WIFI.md](../DEFENSE_DDOS_ROGUE_WIFI.md)

---

## PRESERVE — DuckDuckGo (mobile + Windows)

Wi‑Fi hardening must **not** replace DuckDuckGo VPN, Wi‑Fi DNS, or Password Manager.

- [ ] iPhone: [../IPHONE_AUDIT_PRINT.md](../IPHONE_AUDIT_PRINT.md) Phase 1 verify complete
- [ ] Windows: [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md) BEFORE/AFTER pass

---

## Architecture checklist

### Event bus (Windows SOC)

- [ ] `Start-CtgEventBus.ps1` — listen `127.0.0.1:8766` when testing
- [ ] `core/ctg_event_bus.py` — emit + dedupe + persist
- [ ] `core/ctg_event_summarize.py` — rules-first analyst line (no on-device LLM on ESP32)
- [ ] Dedupe window ~5 min — no alert storms

### Jam / deauth detect (NOT counter-jam)

- [ ] Windows: `Detect-CtgWifiJam.ps1 -DiagnoseOnly`
- [ ] Kali: `ctg-deauth-watch.sh --diagnose`
- [ ] Kali: `rogue-ap-guard.sh` → `ctg-wifi-event-emit.sh`
- [ ] Failover plan: wired / cellular / VPN — **never** jam-back (illegal / out of scope)
- [ ] Heuristic limits documented — encrypted WPA3 may hide mgmt frames

### Threat pack OTA

- [ ] `scripts/utms/threat_pack.example.json` reviewed
- [ ] `utms_threat_pack.py` stages to `Backups\ctg-utms-broadcast`
- [ ] Kali pull from `/mnt/ctg` share
- [ ] Cardputer SD path `/utms/` or firmware repo OTA path documented

### Cardputer bridge

- [ ] `scripts/cardputer/ctg_event_client.py` polls bus
- [ ] M5_OS-Cardputer firmware repo — promisc / alert tile (separate repo)
- [ ] COM13 upload manual — not nightly 4 AM task
- [ ] Honest limit: ESP32 promisc ≠ enterprise WIDS

### Lab AP (isolated)

- [ ] `ctg-lab-ap-setup.sh --diagnose` clean before `--apply`
- [ ] `--apply` requires `--i-understand-lab-only` + `/etc/ctg/lab-wifi.conf`
- [ ] SSID **CTG-UTMS-LAB** — never production clone

---

## Windows diagnose batch

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Detect-CtgWifiJam.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Test-CtgLabNetworkSegment.ps1 -DiagnoseOnly
```

---

## Kali diagnose (in guest)

```bash
sudo bash /mnt/ctg/ctg-lab-ap-setup.sh --diagnose
```

```bash
bash /mnt/ctg/ctg-deauth-watch.sh --diagnose
```

---

## MITRE / NIST mapping (awareness)

- [ ] T1498 Network DoS → detect + ISP/lab failover documented
- [ ] T1557 AiTM → BSSID verify + VPN preserved
- [ ] NIST CSF **DE** — event bus + IDS; **RS** — Signal once (deduped)

---

## End-of-session VERIFY

- [ ] No counter-jam tooling installed or enabled
- [ ] Event bus test event deduped correctly
- [ ] DDG VPN/DNS unchanged on Windows and iPhone
- [ ] UTMS broadcast folder timestamp noted: ___________

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · authorized lab · detect-only Wi‑Fi · no passwords on paper
