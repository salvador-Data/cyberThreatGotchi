# Lab AP — CTG-UTMS-LAB soft AP (authorized isolated lab)

**Hacker Planet LLC** — defensive training access point only. **Never** evil twin, **never** spoof production SSIDs, **never** credential harvesting captive portals.

**Parent:** [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) · **Defense:** [DEFENSE_DDOS_ROGUE_WIFI.md](DEFENSE_DDOS_ROGUE_WIFI.md)

---

## Purpose

Provide an **isolated** Wi-Fi segment for Cardputer UTMS demos and Kali exercises:

- SSID default: **`CTG-UTMS-LAB`** (distinct from home/production)
- VLAN **99** (conceptual) — document on OPNSENSE/homelab; no bridge to trusted LAN without explicit firewall rules
- WPA2-PSK + **802.11w (PMF)** in generated `hostapd` profile

---

## Prerequisites

| Item | Location |
|------|----------|
| Lab Wi-Fi secrets | `/etc/ctg/lab-wifi.conf` (mode 600) — from `lab-wifi.conf.example` on share |
| Lab targets gate | `/etc/ctg/lab-targets.conf` |
| Kali packages | `hostapd`, `iw`, `network-manager` |

Example placeholders in git (edit on Kali only):

```ini
LAB_WIFI_IFACE=wlan0
LAB_WIFI_CHANNEL=6
LAB_WIFI_PSK=your-psk
```

---

## Setup (diagnose first)

```bash
sudo bash /mnt/ctg/ctg-lab-ap-setup.sh --diagnose
```

Apply (requires acknowledgment + real `lab-wifi.conf`):

```bash
sudo bash /mnt/ctg/ctg-lab-ap-setup.sh --apply --i-understand-lab-only
```

Manual start after apply:

```bash
sudo hostapd /etc/ctg/hostapd-lab.conf
```

---

## VLAN tie-in

Document on your OPNSENSE/pfsense:

1. Create VLAN 99 interface for lab Wi-Fi
2. Firewall: deny VLAN99 → LAN except explicit lab targets in `lab-targets.conf`
3. Allow VLAN99 → Kali SIEM JSON export path only if needed

---

## Cardputer join

1. Flash M5 firmware with lab SSID placeholder in config (M5_OS-Cardputer repo)
2. Point `CTG_HOST` at Windows SOC or Kali gateway IP
3. Poll event bus — see [CARDPUTER_UTMS_WIFI.md](CARDPUTER_UTMS_WIFI.md)

---

## Legal

FCC Part 15 unlicensed limits apply. Lab AP must use **your** channel plan and **non-deceptive** SSID. Deauth/jam **detection** is separate — see `ctg-deauth-watch.sh`; do not transmit countermeasures.
