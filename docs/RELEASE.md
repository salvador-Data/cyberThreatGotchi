# GitHub Releases

CyberThreatGotchi uses **tag-triggered auto-release**.

## Cut a release

```bash
git add -A
git commit -m "Your message"
git push origin main

git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions workflow `release.yml` will:

1. Run tests
2. Generate sprites + marketing graphics + STL files
3. Create a GitHub Release with attached assets

## Release assets

| Asset | Description |
|-------|-------------|
| `marketing-graphics.zip` | OG images + social squares |
| `sprites.zip` | Cipherhorn PNG mood frames |
| `enclosure-stl-eink.zip` | 3 printable STLs (e-ink window) |
| `enclosure-stl-lcd.zip` | 3 printable STLs (LCD window) |

## Pre-release checklist

- [ ] CI green on `main`
- [ ] README hero image loads
- [ ] `docs/social/LAUNCH.md` reviewed
- [ ] Version in tag matches changelog note
- [ ] No secrets in repo (.env gitignored)

## Social announcement after tag

See [docs/social/LAUNCH.md](social/LAUNCH.md) — post to Reddit/Facebook after release is live so links hit the Releases page.
