# Lab VLAN segmentation

Authorized defensive use — **Hacker Planet LLC** home/lab network design.

**Related:** [LAB_MATURITY.md](LAB_MATURITY.md) · [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) · [OPNSENSE_LAB_DNS.md](OPNSENSE_LAB_DNS.md)

---

## Why VLANs matter

A **flat LAN** (one subnet for laptops, IoT, lab VMs, and guests) increases blast radius: a compromised IoT device can reach your Windows SOC host, Kali share, and management interfaces. VLANs implement **CIS Control 12** (network infrastructure management) and NIST CSF **PR.AC** (access control).

---

## Recommended zones (placeholders)

Copy `scripts/kali/lab-vlan.conf.example` to `%USERPROFILE%\Backups\lab-vlan.conf` (gitignored) and adjust:

| VLAN ID | Name | Purpose | Example CIDR |
|---------|------|---------|--------------|
| 10 | ctg-mgmt | Windows SOC, admin | 192.168.10.0/24 |
| 20 | ctg-lab | Kali, targets, IDS tap | 192.168.20.0/24 |
| 30 | ctg-guest-iot | Guest Wi‑Fi, IoT | 192.168.30.0/24 |

---

## Platform options

| Platform | CTG notes |
|----------|-----------|
| **OPNsense** | CTG stub in lab autorun; DNS/VPN docs in [OPNSENSE_LAB_DNS.md](OPNSENSE_LAB_DNS.md) |
| **pfSense** | Equivalent VLAN + firewall rules |
| **Consumer router** | Often no VLAN — use guest SSID + VirtualBox host-only for minimum isolation |

---

## VirtualBox Kali (minimum viable)

Even without hardware VLANs:

- **NAT** — guest outbound only
- **Host-only** — `192.168.56.0/24` for ctg-backups share and SSH
- Avoid bridged-to-LAN for untrusted lab targets

---

## Diagnose flat network

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Test-CtgLabNetworkSegment.ps1 -DiagnoseOnly
```

---

## Firewall rule sketch

- **LAB → WAN:** deny by default; allow DNS/NTP as needed
- **MGMT → LAB:** allow TCP 22 (SSH), 1514 (Wazuh), 445 (ctg-backups SMB/share)
- **GUEST_IOT → LAB/MGMT:** deny
- **IDS tap:** mirror port or SPAN to Suricata host on LAB VLAN only

No real SSIDs, PSKs, or management passwords in this doc — store in gitignored `lab-wifi.conf` on Kali per [SECRET_VAULT.md](SECRET_VAULT.md).
