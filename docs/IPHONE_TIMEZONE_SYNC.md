# iPhone timezone sync for CTG daily alerts

**Hacker Planet LLC · CyberThreatGotchi · authorized defensive lab use only**

Windows **cannot** pull live GPS or timezone data from an iPhone without **user action on the device**. Apple’s iOS sandbox does not expose a remote GPS API to a Windows SOC laptop. **Find My** shows location in Apple’s apps — it is **not** a programmatic feed for scheduled tasks.

This doc describes the **approved v1 path**: an **Apple Shortcuts** automation on your iPhone writes a small JSON file that Windows reads for “6 AM local” UTMS alerts when you travel.

**Related:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) · [SIGNAL_ALERTS.md](SIGNAL_ALERTS.md) · [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) · [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md)

---

## What Windows reads

| Path | Purpose |
|------|---------|
| `%USERPROFILE%\Backups\iphone-location\timezone.json` | Primary — IANA timezone + optional coords (gitignored) |
| `%USERPROFILE%\Backups\iphone-location\iphone-timezone.json` | Alias filename (same schema) |
| `%USERPROFILE%\Backups\iphone-location\daily-alert-state.json` | Last sent date (auto-written by alert scripts) |

Example shape (no real coordinates in repo):

```json
{
  "timezone": "America/New_York",
  "lat": null,
  "lon": null,
  "updated": "2026-06-01T10:00:00-04:00"
}
```

Scripts:

- `Update-CtgTimezoneFromIphone.ps1 -DiagnoseOnly` — validate file
- `Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1` — hourly gate (6:00–6:04 local)
- `Send-CtgDailyUtmsAlert.ps1` — UTMS status Signal message
- `Register-CtgDailyUtmsAlertTask.ps1` — register `HackerPlanet-CTG-Daily-Utms-6AM`

---

## Honest limits

| Approach | Works? | Notes |
|----------|--------|-------|
| Windows → iPhone GPS API | **No** | No supported remote API |
| Find My polling | **No** | Not a developer GPS feed |
| Apple Shortcuts → file/cloud | **Yes** | User automation on device |
| Manual copy of JSON | **Yes** | Fine for lab testing |
| `tzutil /s` on Windows | Admin only | Changes **system** TZ, not iPhone |

**v1 design:** Scheduled task runs **every hour**. The checker converts UTC to the IANA timezone from `timezone.json` and sends the UTMS alert **once per local calendar day** when local time is **6:00–6:04**. If no iPhone file exists, fallback is **`America/New_York`** (handles EST/EDT via .NET IANA mapping).

---

## Apple Shortcuts setup (summary)

Full recipe: `scripts/iphone/shortcut-timezone-export.example.json`

1. **Shortcuts → Automation → Time of Day** (e.g. every day 5:55 AM) *or* **When leaving/arriving* (optional).
2. Actions:
   - **Get Current Location** (optional — do not commit real coords to git)
   - **Get Time Zone** / format as IANA if available, else use `America/New_York` when at home lab
   - **Text** — build JSON with `timezone` and ISO8601 `updated`
   - **Save File** to iCloud Drive folder synced to PC, **or** **Send Email** to yourself and save attachment to `Backups\iphone-location\`
3. On Windows: ensure `timezone.json` lands at `%USERPROFILE%\Backups\iphone-location\timezone.json` (OneDrive/iCloud sync or manual save).

Verify:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Update-CtgTimezoneFromIphone.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1 -DiagnoseOnly
```

---

## Signal + scheduled task

1. Configure Signal (vault only — no numbers in git): `Install-CtgSignalCli.ps1`
2. Test: `Send-CtgDailyUtmsAlert.ps1 -DiagnoseOnly`
3. Register (Admin):

```powershell
.\scripts\windows\Register-CtgDailyUtmsAlertTask.ps1
```

Task: **`HackerPlanet-CTG-Daily-Utms-6AM`** — Interactive logon + Highest, hourly checker, no password in XML.

---

## Privacy

- Do **not** commit `timezone.json`, phone numbers, or Signal tokens.
- Optional `lat`/`lon` in JSON stay gitignored under `Backups\iphone-location\`.
- Alert body includes IDS/Gatekeeper/lab maturity **labels only** — no secrets.
