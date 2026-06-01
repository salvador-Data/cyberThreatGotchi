# Gatekeeper HTTPS sandbox — honest security model

**Product:** Gatekeeper.TOR · **Scope:** Hacker Planet LLC **Kali lab VM** + **Windows 11 Pro host**  
**Related:** [GATEKEEPER_TOR.md](GATEKEEPER_TOR.md) · [CTG_TOR_HTTP_SCRAMBLER.md](CTG_TOR_HTTP_SCRAMBLER.md) · [CYBERSECURITY_ETHICS.md](CYBERSECURITY_ETHICS.md)

## Professor summary: is HTTPS + sandbox a good idea?

**Yes — for the right layer and the right threat.**

| Claim | Reality |
|-------|---------|
| “HTTPS mode is a sandbox” | **False.** TLS protects data **on the wire** (confidentiality + integrity in transit). It does **not** stop malware, malicious downloads, or a compromised browser from reading files you can access inside the VM or host profile. |
| “HTTP clearnet in a sandbox” | **Good lab pattern** when HTTP is required for **legacy/captive** targets — but only as an **isolated low-trust lane**, with **Firejail on Kali** or **Windows Sandbox / InPrivate fallback on Windows**. |
| “TOR mode” | **Different threat model:** anonymity and path separation via Tor — not application sandboxing. Use TOR for paths that should not touch clearnet directly. **Unchanged** by this feature. |
| **Windows host** | Gatekeeper sandbox is an **optional lane** — **DuckDuckGo VPN/DNS/Password Manager stay primary** when active. No conflicting system-wide routes. |

**Bottom line:** Combine **HTTPS (TLS 1.3 health probe in Gatekeeper)** with **browser sandboxing** for authorized lab browsing of untrusted or unknown sites. Do **not** use HTTP clearnet for banking, credential entry, or production secrets.

## What CTG implements

### Kali (Firejail)

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

### Windows 11 Pro (Windows Sandbox + fallback)

| Component | Role |
|-----------|------|
| `Start-CtgHttpsSandbox.ps1` | `-DiagnoseOnly`, `-EnableSandboxFeature` (Admin), `-LaunchSandboxBrowser`, `-LaunchHttpLabOnly` |
| Windows Sandbox (primary) | Ephemeral `.wsb` in `%USERPROFILE%\Backups\ctg-sandbox\` — mapped read-only launcher, Edge InPrivate inside VM |
| Edge InPrivate (fallback) | When Sandbox feature disabled — **weaker**; script warns loudly |
| `Start-GatekeeperTorTray.ps1` | Menu **Open HTTPS Sandbox Browser** when HTTPS (lit); sets `CTG_SANDBOX=1` |
| `core/gatekeeper_sandbox.py` | Shared allowlist check + HTTPS mode validation |

**Admin required:** `-EnableSandboxFeature` runs `Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM` via `Run-AsAdmin.ps1`. Reboot may be required.

**Hyper-V / WSL2:** Windows Sandbox uses Hyper-V. WSL2 on Win11 also uses Hyper-V — they **coexist**; CTG does not change DDG routes or disable mitigations.

## When NOT to use

- **Banking, payroll, email login, MFA, or any credential entry over HTTP** — use HTTPS on a trusted device; prefer TOR or bank app on iPhone with existing VPN posture.
- **Bypassing authorization** — sandbox does not grant permission to test third-party systems.
- **Disabling mitigations** — never turn off HVCI/VBS, DuckDuckGo VPN, or kernel mitigations for “performance.”
- **Replacing DDG on Windows** — Gatekeeper tray and sandbox are coexistence layers; DDG remains primary when active.

## HTTP allowlist (lab only)

- **Windows:** `%USERPROFILE%\Backups\ctg-sandbox\http-allowlist.txt` (created on first run; gitignored)
- **Template rules:** `scripts/gatekeeper-tor/templates/site-rules.gatekeeper.conf`
- **Kali scrambler copy:** `/opt/ctg/tor-http-scrambler/site-rules.conf` (mode `600`)

Default posture: **prefer HTTPS and TOR**; cleartext HTTP only for entries on the allowlist (captive portal lab AP, legacy HTTP-only lab targets).

## Commands

### Kali

Diagnose Firejail + profile:

```bash
bash /opt/ctg/gatekeeper-tor/kali/ctg-https-sandbox.sh -DiagnoseOnly
```

Launch sandboxed browser (HTTPS mode should be active):

```bash
sudo /opt/ctg/gatekeeper-tor/gatekeeper-daemon.sh set-mode https
bash /opt/ctg/gatekeeper-tor/kali/ctg-https-sandbox.sh -LaunchBrowser
```

Or from tray: **Open sandboxed browser (HTTPS mode)** when the HTTPS icon is lit.

### Windows

Diagnose:

```powershell
.\scripts\gatekeeper-tor\windows\Start-CtgHttpsSandbox.ps1 -DiagnoseOnly
```

Enable Windows Sandbox feature (Admin — UAC):

```powershell
.\scripts\gatekeeper-tor\windows\Start-CtgHttpsSandbox.ps1 -EnableSandboxFeature
```

Launch sandbox browser (HTTPS mode lit in tray):

```powershell
.\scripts\gatekeeper-tor\windows\Start-CtgHttpsSandbox.ps1 -LaunchSandboxBrowser
```

HTTP lab URL (allowlist only):

```powershell
.\scripts\gatekeeper-tor\windows\Start-CtgHttpsSandbox.ps1 -LaunchHttpLabOnly -Url "http://lab-ap.local/"
```

## NIST / defensive mapping

| Function | Control |
|----------|---------|
| **Protect** | Application containment (Firejail / Windows Sandbox), least-privilege browser profile |
| **Detect** | Gatekeeper health + SIEM hooks via scrambler (separate path) |
| **Recover** | Ephemeral sandbox — discard session scratch after use |

## Cross-references

- [GATEKEEPER_TOR.md](GATEKEEPER_TOR.md) — Tor/HTTPS modes, DDG coexistence
- [IPHONE_HARDENING.md](IPHONE_HARDENING.md) — iOS sandbox (no filesystem AV)
- [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) — Gatekeeper script index
