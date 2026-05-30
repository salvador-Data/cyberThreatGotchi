# Nightly Automation & SOC — LinkedIn / About blurb

**Andy Kowal** · Hacker Planet LLC · [salvador-Data](https://github.com/salvador-Data)

---

Built **unattended Windows SOC automation** for a founder laptop: scheduled task **HackerPlanet-CTG-Nightly-4AM** runs `ctg_nightly_4am.ps1` at 4 AM—**selective SSD + OneDrive backup** (honest fallbacks when D: shows **No Media**), mandatory **hackerplanet.dev** backup/sync/health checks via `ctg_website_nightly.ps1`, portfolio export, Defender quick scan, Windows Update audit (no auto-reboot default), Sysmon/Wazuh status, and **DuckDuckGo VPN preserve**. Triplicate logging (`nightly-*.log`, Desktop `ctg-soc-run-log.txt`, OneDrive + SSD mirrors). Flag-gated deploy (`-DeployWebsite`, `-ApplyUpdates`, `-SkipBackup`); elevated hardening stays in `ctg_soc_run_once.ps1` (UAC/740/Sysmon documented). DevSecOps: no secrets in scripts—authorized defensive use only. MSP/kits narrative for Hacker Planet Year 1.

**Repo:** [cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi)

**Deep dive:** [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md) · Hardening companion: [PORTFOLIO_SYSTEM_HARDENING.md](PORTFOLIO_SYSTEM_HARDENING.md) · Firmware/OS: [PORTFOLIO_FIRMWARE_OS.md](PORTFOLIO_FIRMWARE_OS.md)
