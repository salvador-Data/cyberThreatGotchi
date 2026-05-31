# Nmap Ask (`a$k`) — Adaptive Defensive Recon

**Hacker Planet LLC · Philadelphia, PA · Authorized lab use only**

`ctg-nmap-ask` (shell alias **`a$k`**) is a Kali lab wrapper around **nmap** that runs a **defensive scan ladder** against targets you own or hold **written scope** to test. It persists IP, MAC, hostname, OS guess, and open ports so you can **reconnect** after a VM reboot without retyping identifiers.

---

## NIST CSF mapping (blue team)

| Phase | Nmap feature | CSF function |
|-------|--------------|--------------|
| Host discovery | `-sn` on CIDR | **Identify** — asset inventory |
| Port scan | `-sS` / `-sT`, top 1000 | **Identify** — exposure surface |
| Service/version | `-sV` | **Identify** — software baseline |
| OS fingerprint | `-O` (root) | **Identify** — patch prioritization |
| Safe NSE | `default,safe,vuln` | **Detect** — misconfig / CVE hints (no exploit scripts) |
| State JSON | `/var/log/ctg/nmap-ask/` | **Protect** — audit trail for lab ROE |

---

## Adaptive scan ladder

The wrapper chooses phases based on target shape and privileges:

1. **Subnet (CIDR)** — ping sweep (`-sn`) first to find live hosts.
2. **Single host** — TCP SYN scan (`-sS`) if root, else connect scan (`-sT`).
3. **Local LAN** — ARP ping (`-PR`) when target is RFC1918 and you run as root (MAC/vendor capture).
4. **Services** — `-sV --version-intensity 5`.
5. **OS** — `-O --osscan-guess` when root.
6. **NSE** — `default,safe,vuln` plus optional `ctg-ask-recon.nse` (HTTP titles, SSH banners).

Each phase writes `-oA` output under `/var/log/ctg/nmap-ask/scans/`. The latest XML feeds a per-target JSON state file.

---

## Lab scope gate

Before any scan, the script checks **`/etc/ctg/lab-targets.conf`** (copy from `scripts/kali/lab-targets.example`). Targets outside that list are **refused** unless you pass **`-i`** with an explicit authorization warning.

This mirrors the pentest policy in [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md): no public internet sweeps, no neighbor WiFi, no production SaaS without ROE.

---

## Install and boot persistence

On every boot, `kali-boot-autopatch.sh` **installs** (idempotent) to `/opt/ctg/nmap-ask/`, symlinks `/usr/local/bin/ctg-nmap-ask` and `/usr/local/bin/a$k`, and runs a **`--help` dry run** — no network scan at login.

One-time systemd + nmap package install:

```bash
sudo bash /mnt/ctg/kali-boot-autopatch.sh --install
```

---

## Invocation

| Command | Action |
|---------|--------|
| `a$k 192.168.50.10` | Adaptive scan of lab host |
| `a$k 192.168.50.0/24` | Discovery + scan ladder on subnet |
| `a$k -` or `a$k --reconnect` | Reload last target from state, re-scan |
| `a$k --dump 192.168.50.10` | Print saved IP/MAC/ports (no scan) |
| `a$k --list` | Table of saved targets |
| `ctg-nmap-ask --help` | Usage (safe verify) |

After login, `a$k` is also available via `/etc/profile.d/ctg-nmap-ask.sh`.

---

## State paths

| Path | Contents |
|------|----------|
| `/var/log/ctg/nmap-ask/<target-key>.json` | IP, MAC, vendor, hostname, OS, open ports, last scan ISO |
| `/var/log/ctg/nmap-ask/last-target` | Last scanned target for reconnect |
| `/var/log/ctg/nmap-ask/scans/` | nmap `-oA` XML/gnmap/normal output |
| `/var/log/ctg/nmap-ask.log` | Redacted operational log |

Non-root runs use `~/.config/ctg/nmap-ask/` instead.

---

## Reconnect vs new target

Use **`a$k -`** when the same lab VM came back with the same IP but you want fresh port/service data — state JSON still shows the last known MAC and hostname for comparison.

Use a **new IP/CIDR** when you pivot to another authorized lab asset; a new JSON file is created keyed by the target string.

---

## MITRE ATT&CK (defensive lens)

| ATT&CK | Lab use |
|--------|---------|
| T1046 Network Service Discovery | Port scan phase — validate IDS alerts |
| T1082 System Information Discovery | OS/service version — asset baseline |
| T1590 Gather Victim Network Information | CIDR discovery — inventory only in owned lab |

Red-team techniques are discussed here only to **tune detection** on systems Hacker Planet LLC owns.

---

## Related docs

- [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) — lab VLAN and pentest scope
- [CTG_LAB_PLAYGROUND.md](CTG_LAB_PLAYGROUND.md) — menu option 10 for help/list/optional scan
- [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) — `ctg-nmap-ask.sh` entry
