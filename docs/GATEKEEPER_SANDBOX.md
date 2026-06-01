# Gatekeeper HTTPS sandbox — honest security model

**Product:** Gatekeeper.TOR · **Scope:** Hacker Planet LLC **Kali lab VM** only  
**Related:** [GATEKEEPER_TOR.md](GATEKEEPER_TOR.md) · [CTG_TOR_HTTP_SCRAMBLER.md](CTG_TOR_HTTP_SCRAMBLER.md) · [CYBERSECURITY_ETHICS.md](CYBERSECURITY_ETHICS.md)

## Professor summary: is HTTPS + sandbox a good idea?

**Yes — for the right layer and the right threat.**

| Claim | Reality |
|-------|---------|
| “HTTPS mode is a sandbox” | **False.** TLS protects data **on the wire** (confidentiality + integrity in transit). It does **not** stop malware, malicious downloads, or a compromised browser from reading files you can access inside the VM. |
| “HTTP clearnet in a sandbox” | **Good lab pattern** when HTTP is required for **legacy/captive** targets — but only as an **isolated low-trust lane** inside the **Kali VM**, with **Firejail** (namespaces, seccomp, restricted writes). |
| “TOR mode” | **Different threat model:** anonymity and path separation via Tor — not the same as application sandboxing. Use TOR for paths that should not touch clearnet directly. |
| **iPhone / Windows host** | Already sandboxed by the OS (iOS sandbox, Windows app isolation). Gatekeeper on Windows **documents** Windows Sandbox / Edge isolation for untrusted links — it does **not** replace **DuckDuckGo VPN/DNS/Password Manager**. |

**Bottom line:** Combine **HTTPS (TLS 1.3 health probe in Gatekeeper)** with **Firejail browser sandbox on Kali** for authorized lab browsing of untrusted or unknown sites. Do **not** use HTTP clearnet for banking, credential entry, or production secrets.

## What CTG implements (Kali)

| Component | Role |
|-----------|------|
| `ctg-https-sandbox.profile` | Firejail: `noroot`, `seccomp`, `private-dev`, writes limited to `/tmp/ctg-sandbox` |
| `ctg-https-sandbox.sh` | `-DiagnoseOnly` / `-LaunchBrowser` (firefox-esr or lab browser) |
| `gatekeeper-daemon.sh` | HTTPS mode sets `CTG_SANDBOX=1` in `/var/lib/ctg/gatekeeper-tor/sandbox.env` |
| `gatekeeper-tray.py` | Menu: **Open sandboxed browser (HTTPS mode)** when HTTPS is lit |
| `site-rules.gatekeeper.conf` | Documents **block HTTP except allowlist** (lab captive/legacy only) |

Install optional Firejail:

```bash
sudo bash /opt/ctg/gatekeeper-tor/kali/install-gatekeeper-kali.sh --with-sandbox
```

## When NOT to use

- **Banking, payroll, email login, MFA, or any credential entry over HTTP** — use HTTPS on a trusted device; prefer TOR or bank app on iPhone with existing VPN posture.
- **Bypassing authorization** — sandbox does not grant permission to test third-party systems.
- **Disabling mitigations** — never turn off HVCI/VBS, DuckDuckGo VPN, or kernel mitigations for “performance.”
- **Replacing DDG on Windows** — Gatekeeper tray is coexistence + optional local Tor SOCKS; DDG remains primary when active.

## Windows (document only)

Gatekeeper does **not** auto-install Windows Sandbox or Hyper-V.

| Option | Use |
|--------|-----|
| **Windows Sandbox** | One-off untrusted link or attachment — ephemeral desktop, no persistence |
| **Microsoft Edge — Browse in Microsoft Defender Application Guard** | Enterprise/isolated browsing window (if licensed and enabled) |
| **DuckDuckGo VPN** | Stays **primary** system VPN when active — do not stack conflicting routes |

Diagnose (no tray):

```powershell
.\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1 -DiagnoseOnly
```

HTTPS health on Windows uses the same **TLS 1.3–preferring curl probe** in `core/gatekeeper_tor.py` — not a system-wide TLS policy.

## HTTP allowlist (lab only)

Template: `scripts/gatekeeper-tor/templates/site-rules.gatekeeper.conf`

- Default posture: **prefer HTTPS and TOR**; cleartext HTTP only for entries on the allowlist (captive portal lab AP, legacy HTTP-only lab targets).
- Scrambler copy path: `/opt/ctg/tor-http-scrambler/site-rules.conf` (mode `600`)

## Kali commands (after install)

Diagnose Firejail + profile:

```bash
bash /opt/ctg/gatekeeper-tor/kali/ctg-https-sandbox.sh -DiagnoseOnly
```

Launch sandboxed browser (HTTPS mode should be active; sets `CTG_SANDBOX=1` in jail):

```bash
sudo /opt/ctg/gatekeeper-tor/gatekeeper-daemon.sh set-mode https
bash /opt/ctg/gatekeeper-tor/kali/ctg-https-sandbox.sh -LaunchBrowser
```

Or from tray: **Open sandboxed browser (HTTPS mode)** when the HTTPS icon is lit.

## NIST / defensive mapping

| Function | Control |
|----------|---------|
| **Protect** | Application containment (Firejail), least-privilege browser profile under `/tmp/ctg-sandbox` |
| **Detect** | Gatekeeper health + SIEM hooks via scrambler (separate path) |
| **Recover** | Ephemeral sandbox profile — discard `/tmp/ctg-sandbox` after session |

## Cross-references

- [GATEKEEPER_TOR.md](GATEKEEPER_TOR.md) — Tor/HTTPS modes, DDG coexistence
- [IPHONE_HARDENING.md](IPHONE_HARDENING.md) — iOS sandbox (no filesystem AV)
- [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) — Gatekeeper script index
