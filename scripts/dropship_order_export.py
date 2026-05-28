#!/usr/bin/env python3
"""
Export drop-ship order packets from website/js/catalog.config.js + shipping-tracker.config.js.

PCI / ToS safe: generates CSV and text packets for manual Etsy/AliExpress ordering — no marketplace API charges.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website" / "js"
CATALOG = WEB / "catalog.config.js"
TRACKER = WEB / "shipping-tracker.config.js"


def _extract_object_blocks(text: str, key: str) -> list[str]:
    """Return inner bodies of `key: { ... },` at top level of a JS object."""
    pattern = rf"{re.escape(key)}:\s*\{{"
    blocks: list[str] = []
    for m in re.finditer(pattern, text):
        start = m.end() - 1
        depth = 0
        for i in range(start, len(text)):
            ch = text[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    blocks.append(text[start + 1 : i])
                    break
    return blocks


def _field(block: str, name: str) -> str | None:
    m = re.search(rf'{name}:\s*"([^"]*)"', block)
    if m:
        return m.group(1)
    m = re.search(rf"{name}:\s*(\d+(?:\.\d+)?)", block)
    return m.group(1) if m else None


def _block_for_stripe_key(text: str, stripe_key: str) -> str | None:
    needle = f'stripeKey: "{stripe_key}"'
    pos = text.find(needle)
    if pos < 0:
        return None
    start = text.rfind("{", 0, pos)
    if start < 0:
        return None
    depth = 0
    for i in range(start, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    return None


def _iter_product_blocks(text: str):
    """Yield each catalog product object that declares a stripeKey."""
    for m in re.finditer(r'stripeKey:\s*"(ds\w+)"', text):
        block = _block_for_stripe_key(text, m.group(1))
        if block:
            yield block


def parse_catalog() -> list[dict[str, str | int | float | None]]:
    text = CATALOG.read_text(encoding="utf-8")
    products: list[dict[str, str | int | float | None]] = []
    seen: set[str] = set()
    for block in _iter_product_blocks(text):
        if 'fulfillment: "dropship"' not in block:
            continue
        stripe = _field(block, "stripeKey")
        if not stripe or stripe in seen:
            continue
        seen.add(stripe)
        retail = _field(block, "retailPrice")
        products.append(
            {
                "id": _field(block, "id"),
                "name": _field(block, "name"),
                "stripeKey": stripe,
                "retailUsd": float(retail) if retail else None,
                "supplier": _field(block, "supplier"),
                "supplierUrl": _field(block, "supplierUrl"),
                "buildType": _field(block, "buildType"),
            }
        )
    return products


def parse_tracker() -> dict[str, dict]:
    text = TRACKER.read_text(encoding="utf-8")
    out: dict[str, dict] = {}
    m = re.search(r"products:\s*\{", text)
    if not m:
        return out
    body = text[m.end() :]
    for key_match in re.finditer(r"(ds\w+):\s*\{", body):
        key = key_match.group(1)
        start = key_match.end() - 1
        depth = 0
        block = ""
        for i in range(start, len(body)):
            ch = body[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    block = body[start + 1 : i]
                    break
        min_d = _field(block, "min")
        max_d = _field(block, "max")
        lead = ""
        lt = re.search(r"leadTimeDays:\s*\{\s*min:\s*(\d+),\s*max:\s*(\d+)", block)
        if lt:
            lead = f"{lt.group(1)}-{lt.group(2)} business days"
        checklist = re.findall(r'"([^"]+)"', block.split("orderChecklist:")[-1]) if "orderChecklist" in block else []
        out[key] = {
            "supplier": _field(block, "supplier"),
            "channel": _field(block, "channel"),
            "supplierCostUsd": _field(block, "supplierCostUsd"),
            "supplierUrl": _field(block, "supplierUrl"),
            "buildType": _field(block, "buildType"),
            "leadTime": lead,
            "checklist": checklist[:8],
        }
    return out


def merge_rows(
    catalog: list[dict],
    tracker: dict[str, dict],
    *,
    stripe_key: str | None = None,
    ship_to: str = "",
    status: str = "ready_to_order",
) -> list[dict]:
    rows: list[dict] = []
    for p in catalog:
        sk = str(p.get("stripeKey") or "")
        if stripe_key and sk != stripe_key:
            continue
        t = tracker.get(sk, {})
        retail = p.get("retailUsd")
        cost = t.get("supplierCostUsd")
        margin = ""
        if retail is not None and cost is not None:
            try:
                margin = f"{float(retail) - float(cost):.2f}"
            except (TypeError, ValueError):
                margin = ""
        rows.append(
            {
                "stripe_key": sk,
                "product_id": p.get("id") or "",
                "product_name": p.get("name") or "",
                "retail_usd": retail,
                "supplier_cost_usd": cost,
                "est_margin_usd": margin,
                "supplier": p.get("supplier") or t.get("supplier"),
                "channel": t.get("channel") or "",
                "build_type": p.get("buildType") or t.get("buildType") or "",
                "lead_time": t.get("leadTime") or "",
                "supplier_url": p.get("supplierUrl") or t.get("supplierUrl") or "",
                "ship_to": ship_to,
                "fulfillment_status": status,
                "order_checklist": " | ".join(t.get("checklist") or []),
            }
        )
    return rows


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


def write_packet(path: Path, row: dict) -> None:
    lines = [
        "Hacker Planet LLC — manual drop-ship order packet",
        f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        f"Product: {row.get('product_name')}",
        f"Stripe key: {row.get('stripe_key')}",
        f"Retail (customer paid HPL): ${row.get('retail_usd')}",
        f"Est. supplier cost: ${row.get('supplier_cost_usd')}",
        f"Est. margin before fees: ${row.get('est_margin_usd')}",
        f"Supplier: {row.get('supplier')}",
        f"Channel: {row.get('channel')} — place order manually in marketplace portal",
        f"Build type: {row.get('build_type')}",
        f"Lead time: {row.get('lead_time')}",
        f"Supplier URL: {row.get('supplier_url')}",
        f"Ship to: {row.get('ship_to') or '[paste from Stripe]'}",
        f"Status: {row.get('fulfillment_status')}",
        "",
        "Checklist:",
    ]
    for i, item in enumerate(str(row.get("order_checklist") or "").split(" | "), 1):
        if item.strip():
            lines.append(f"  {i}. {item.strip()}")
    lines.extend(
        [
            "",
            "Do NOT automate card charges on Etsy/AliExpress — operator checkout only.",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Export HPL drop-ship order packets (manual fulfillment).")
    ap.add_argument("--stripe-key", help="Single stripeKey (e.g. dsMeshtasticHeltec)")
    ap.add_argument("--ship-to", default="", help="Customer ship-to one-liner")
    ap.add_argument("--status", default="ready_to_order", help="Fulfillment status id")
    ap.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=ROOT / "data" / "dropship_exports",
        help="Output directory for CSV and packets",
    )
    ap.add_argument("--json", action="store_true", help="Print merged rows as JSON to stdout")
    args = ap.parse_args()

    if not CATALOG.is_file() or not TRACKER.is_file():
        print("Missing catalog.config.js or shipping-tracker.config.js", file=sys.stderr)
        return 2

    catalog = parse_catalog()
    tracker = parse_tracker()
    rows = merge_rows(
        catalog,
        tracker,
        stripe_key=args.stripe_key,
        ship_to=args.ship_to,
        status=args.status,
    )
    if not rows:
        print("No matching drop-ship products.", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(rows, indent=2))
        return 0

    args.output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    csv_path = args.output_dir / f"dropship_orders_{stamp}.csv"
    write_csv(csv_path, rows)
    print(f"Wrote {csv_path} ({len(rows)} rows)")

    for row in rows:
        sk = row["stripe_key"]
        pkt = args.output_dir / f"packet_{sk}_{stamp}.txt"
        write_packet(pkt, row)
        print(f"Wrote {pkt}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
