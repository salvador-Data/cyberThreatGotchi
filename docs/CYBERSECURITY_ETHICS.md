# Cybersecurity ethics — Hacker Planet LLC

Authorized defensive lab use · Andy Kowal · Philadelphia, PA

This page anchors **how** CyberThreatGotchi work stays ethical and legal. It is not legal advice; it aligns agent and human practice with widely adopted professional codes.

---

## Why this matters for CTG

CTG spans Windows SOC scripts, Kali lab tooling, Cardputer firmware, and a public security-education site. The same skills used to **harden and detect** can harm if applied without authorization. Hacker Planet LLC treats ethics as a **control**, not a disclaimer.

---

## Canonical sources (read the originals)

| Source | URL | Takeaway for CTG |
|--------|-----|------------------|
| **ISC2 Code of Ethics** | https://www.isc2.org/ethics | Four canons: protect society; act honorably and legally; provide competent service; advance the profession |
| **ISC2 Code of Professional Conduct** (2026) | https://www.isc2.org/Insights/2026/02/ISC2-Launches-Code-of-Professional-Conduct | Extends ethics to all practitioners — integrity, confidentiality, public safety |
| **ACM Code of Ethics** | https://www.acm.org/code-of-ethics | Public good is paramount; **no unauthorized access**; design for security and responsible disclosure |
| **NIST SP 800-115** | https://csrc.nist.gov/publications/detail/sp/800-115/final | Security testing methodology: authorization, scoping, execution, reporting |
| **NIST Privacy Framework** | https://www.nist.gov/privacy-framework | Privacy as a complement to security — relevant to vault/PII handling |
| **CIS Controls** | https://www.cisecurity.org/controls | Prioritized defensive controls — CTG scripts map here before offensive tooling |

---

## Authorized use in this repo

1. **Lab targets only** — hosts listed in `lab-targets.conf` (or Andy-owned VMs/devices).
2. **Written scope** — external pentests require explicit written authorization (client letter or internal ROE).
3. **Blue team default** — scripts diagnose, harden, log, and restore; they do not weaponize against third parties.
4. **Secrets** — [SECRET_VAULT.md](SECRET_VAULT.md), [no PII in git](../.cursor/rules/no-pii-in-repo.mdc); never commit credentials or customer data.
5. **Disclosure** — findings from lab work stay in local logs or private repos until responsibly published (kits, docs, Pro feed).

---

## What agents and operators refuse

- Attacks on systems Andy does not own or lacks scope for
- Credential stuffing, theft, or exfiltration recipes against real targets
- Disabling mitigations (HVCI, VBS, spec-ctrl) for convenience
- Replacing DuckDuckGo VPN/DNS/PM with weaker policies
- Storing PII or secrets in git, docs, or chat transcripts committed to the repo

---

## Mapping to CTG artifacts

| Artifact | Ethical framing |
|----------|-----------------|
| Kali lab / nmap / Suricata | Authorized lab segmentation; detect-only IDS where possible |
| Windows SOC / Defender ASR | Protect Andy’s workstation; audit before block mode |
| Cardputer / BLE scout | Owned hardware; passive or consented RF in lab |
| Website / shop | PCI stays on Stripe/PayPal; no PAN on our servers |
| Professor / CISO path | Teach defense with red-team *awareness*, not crime |

---

## Cursor rules

- `.cursor/rules/cybersecurity-ethics.mdc` — always-on agent ethics
- `.cursor/rules/ctg-install-status.mdc` — install state without breaking pass statuses
- `.cursor/rules/andy-professor-cybersec.mdc` — deep seminar mode when Andy asks

---

## Related docs

[SECURITY_HARDENING.md](SECURITY_HARDENING.md) · [SECRET_VAULT.md](SECRET_VAULT.md) · [LAB_MATURITY.md](LAB_MATURITY.md) · [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md)
