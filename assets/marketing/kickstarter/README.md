# Kickstarter email — backer preview (plain + HTML)

**Use:** Mail list "notify me" before launch · optional backer update tone reference  
**From:** Salvador Data · Hacker Planet LLC · salvadorData@proton.me  
**Preview page:** https://hackerplanet.dev/kickstarter.html

---

## Subject lines (A/B)

- A: `Cipherhorn goes live soon — CyberThreatGotchi Kickstarter`
- B: `Early Bird $149 (50 units) — open edge IPS from Philly`

---

## Plain text

```
Salvador Data · Hacker Planet LLC

You asked for a heads-up — CyberThreatGotchi is heading to Kickstarter.

Real edge IPS on Banana Pi BPI-R3 Mini: signatures, YARA, blocks, SQLite audit chain.
Cipherhorn on e-ink — mood for humans, logs for auditors.

Preview tiers:
  · Digital Defender — $15 (STLs + sprites)
  · Early Bird Core — $149 (50 units)
  · Field Pack — $219 (Core + M5 Cardputer remote)

Built in Philadelphia. Open source (MIT).
Defensive use on authorized networks only.

Preview: https://hackerplanet.dev/kickstarter.html
GitHub: https://github.com/salvador-Data/cyberThreatGotchi

Reply to this email if you want MSP Pilot details — limited to 10 backers.

— Salvador Data
Hacker Planet LLC · Philadelphia, PA
salvadorData@proton.me
```

---

## HTML template

Save as `kickstarter-preview.html` — inline CSS only (email client safe).

See file: [kickstarter-preview.html](kickstarter-preview.html)

**Design notes**

- Background `#0a0e14`, card `#121820`, text `#e6edf3`, links `#00b48c`
- Max width 600px
- No images required (optional hero 600×338 banner)
- Single CTA button: "View preview →"

---

*Internal · do not embed Stripe or payment forms in email*
