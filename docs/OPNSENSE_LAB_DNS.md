# OPNsense Lab — DNS Forwarder Template (DuckDuckGo preserve)

**Author:** Andy Kowal · **Organization:** [Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/)  
**Companion:** [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) · [IPHONE_HARDENING.md](IPHONE_HARDENING.md)

---

## Preserve DuckDuckGo (mandatory)

Andy’s stack uses **DuckDuckGo VPN + DNS** on Windows, iPhone, and home router. The OPNsense **lab VM** must **respect** that choice:

- **Do NOT** stack NextDNS, Cloudflare `1.1.1.1`, or `9.9.9.9` as upstream forwarders when DuckDuckGo is already the household DNS strategy.
- **Do NOT** push OPNsense Unbound overrides to phones or Windows host adapters — lab VLAN clients only until explicitly tested.
- **Preferred upstream (optional):** DuckDuckGo DNS `94.140.14.14` and `94.140.15.15`, or DoH `https://dns.duckduckgo.com/dns-query`.

Same preserve rules as [IPHONE_HARDENING.md](IPHONE_HARDENING.md) — document baseline before changes; verify VPN/DNS unchanged after lab work.

---

## Lab VM placement (default)

| NIC | VirtualBox | Role |
|-----|------------|------|
| em0 | NAT | WAN (installer only — not production edge) |
| em1 | intnet `opn-lab` | Lab LAN — Kali bridged or host-only here |

Created by `scripts/windows/Install-OpnsenseLab.ps1` — **no `-EdgeMode`** unless ISP rollback is rehearsed.

---

## Unbound forwarder — DuckDuckGo (recommended for lab VLAN)

After OPNsense install on **OPNsense-Lab**:

1. **Services → Unbound DNS → General**
   - Enable Unbound on **LAN** (lab interface only).
   - **DNSSEC:** enable if desired (DDG supports DNSSEC).
2. **Services → Unbound DNS → Forwarding**
   - **Use forwarding mode:** yes.
   - **Forward primary:** `94.140.14.14`
   - **Forward secondary:** `94.140.15.15`
   - **Do not add** Cloudflare, NextDNS, or Quad9 rows when DDG is set.
3. **Optional DoH** (OPNsense 24+ plugin or manual): forward to `https://dns.duckduckgo.com/dns-query` only if you prefer encrypted upstream from the firewall — still **one** upstream family (DDG), not stacked resolvers.

### What NOT to configure

| Avoid | Why |
|-------|-----|
| LAN DHCP DNS = `1.1.1.1` while phones use DDG VPN | Split-brain DNS; breaks iPhone hardening baseline |
| NextDNS + DDG forwarders in same Unbound list | Stacked filtering — pick **one** upstream family |
| Forcing lab DNS on `LAN_HOME` | Family VLAN stays on existing router/DDG until P6 edge migration |

---

## Kali VM DNS (via bootstrap)

| Flag | Behavior |
|------|----------|
| `--preserve-ddg-dns` (default **on**) | Skip resolv.conf changes if DDG already present; warn before overwrite |
| `--ddg-dns-only` | Set Kali `resolv.conf` to DDG IPs; optional Unbound stub → DDG forward |

Run from Windows: `Deploy-KaliLab.ps1` passes these flags when `-PreserveDdgDns` / `-DdgDnsOnly` are set.

---

## Suricata / IDS note

When Suricata alerts on DNS (gaming, iCloud, **DuckDuckGo VPN on phone**), classify as false positive before block mode — see [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md#ips-detect-only-before-block).

---

## Backup

Export **System → Configuration → Backup** to `C:\Users\Owner\Backups\opnsense-config-YYYY-MM-DD.xml` (gitignored) before changing forwarders.

---

*Defensive security engineering — Hacker Planet LLC · Authorized lab use only.*
