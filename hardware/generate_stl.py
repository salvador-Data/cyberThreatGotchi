#!/usr/bin/env python3
"""
Generate CyberThreatGotchi enclosure STL files.

Variants:
  eink  — Waveshare 2.13" window (default, also copied to hardware/stl/)
  lcd   — ILI9341 2.4" portrait window
  all   — both variants (6 STLs + 3 legacy copies)

Usage:
  python hardware/generate_stl.py
  python hardware/generate_stl.py --variant lcd
  python hardware/generate_stl.py --all
"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

ROOT = Path(__file__).resolve().parent
OPENSCAD = ROOT / "openscad"
LEGACY_OUT = ROOT / "stl"

W, H, D = 95.0, 110.0, 32.0
WALL = 2.0
USBC_W, USBC_H = 12.0, 6.0
STANDOFFS = [(12, 45), (53, 45), (12, 78), (53, 78)]
CATS = [(10, 88), (78, 88), (10, 28), (78, 28)]

VARIANT_DIMS = {
    "eink": {"display_w": 50.0, "display_h": 26.0, "display_z": 72.0},
    "lcd": {"display_w": 39.0, "display_h": 55.0, "display_z": 48.0},
}

SCAD_PARTS = (
    "ctg_front_shell.scad",
    "ctg_rear_shell.scad",
    "ctg_clip.scad",
)


@dataclass
class Tri:
    n: tuple[float, float, float]
    v1: tuple[float, float, float]
    v2: tuple[float, float, float]
    v3: tuple[float, float, float]


def _cross(a, b, c):
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    ln = (nx * nx + ny * ny + nz * nz) ** 0.5 or 1.0
    return (nx / ln, ny / ln, nz / ln)


def _box_tris(x: float, y: float, z: float, w: float, h: float, d: float) -> list[Tri]:
    p = [
        (x, y, z), (x + w, y, z), (x + w, y + h, z), (x, y + h, z),
        (x, y, z + d), (x + w, y, z + d), (x + w, y + h, z + d), (x, y + h, z + d),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    tris: list[Tri] = []
    for a, b, c, d in faces:
        tris.append(Tri(_cross(p[a], p[b], p[c]), p[a], p[b], p[c]))
        tris.append(Tri(_cross(p[a], p[c], p[d]), p[a], p[c], p[d]))
    return tris


def _cylinder_tris(cx: float, cy: float, z0: float, z1: float, r: float, seg: int = 16) -> list[Tri]:
    import math

    tris: list[Tri] = []
    for i in range(seg):
        a0 = 2 * math.pi * i / seg
        a1 = 2 * math.pi * (i + 1) / seg
        x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
        x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
        b0, p0, p1 = (cx, cy, z0), (x0, y0, z0), (x1, y1, z0)
        q0, q1 = (x0, y0, z1), (x1, y1, z1)
        tris.append(Tri(_cross(b0, p0, p1), b0, p0, p1))
        tris.append(Tri(_cross(q0, q1, p1), q0, q1, p1))
        tris.append(Tri(_cross(p0, q0, p1), p0, q0, p1))
        tris.append(Tri(_cross(p1, q0, q1), p1, q0, q1))
    return tris


def write_binary_stl(path: Path, tris: Iterable[Tri]) -> None:
    tri_list = list(tris)
    path.parent.mkdir(parents=True, exist_ok=True)
    header = b"CyberThreatGotchi enclosure STL"
    header = header + bytes(80 - len(header))
    with path.open("wb") as f:
        f.write(header)
        f.write(struct.pack("<I", len(tri_list)))
        for t in tri_list:
            f.write(struct.pack("<3f", *t.n))
            f.write(struct.pack("<3f", *t.v1))
            f.write(struct.pack("<3f", *t.v2))
            f.write(struct.pack("<3f", *t.v3))
            f.write(struct.pack("<H", 0))


def mesh_front_shell(display_w: float, display_h: float, display_z: float) -> list[Tri]:
    tris: list[Tri] = []
    tris += _box_tris(0, 0, 0, W, D / 2, WALL)
    tris += _box_tris(0, D / 2, 0, W, D / 2, WALL)
    tris += _box_tris(0, 0, 0, WALL, D, H)
    tris += _box_tris(W - WALL, 0, 0, WALL, D, H)
    tris += _box_tris(0, 0, H - WALL, W, D, WALL)
    tris += _box_tris(0, 0, 0, W, WALL, H)
    x0 = (W - display_w) / 2
    yf = D - WALL
    tris += _box_tris(0, yf, display_z + display_h, W, WALL, H - (display_z + display_h))
    tris += _box_tris(0, yf, 0, W, WALL, display_z)
    tris += _box_tris(0, yf, display_z, x0, WALL, display_h)
    tris += _box_tris(x0 + display_w, yf, display_z, W - (x0 + display_w), WALL, display_h)
    tris += _box_tris(W / 2 - USBC_W / 2, yf, 2, USBC_W, WALL + 0.5, USBC_H)
    for sx, sz in STANDOFFS:
        tris += _cylinder_tris(sx, D / 2 + 2, sz, sz + 6, 2.25)
    for cx, cz in CATS:
        tris += _cylinder_tris(cx, D - 1.5, cz, cz + 2.5, 3.5, seg=12)
    return tris


def mesh_rear_shell() -> list[Tri]:
    tris: list[Tri] = []
    tris += _box_tris(0, 0, 0, W, D / 2, WALL)
    tris += _box_tris(0, 0, 0, WALL, D / 2, H)
    tris += _box_tris(W - WALL, 0, 0, WALL, D / 2, H)
    tris += _box_tris(0, 0, H - WALL, W, D / 2, WALL)
    tris += _box_tris(0, D / 2 - WALL, 0, W, WALL, H)
    tris += _box_tris(0, 0, 0, W, WALL, H)
    tris += _box_tris(WALL + 2, WALL, WALL + 2, W - 2 * WALL - 4, 3, 18)
    for i in range(4):
        tris += _box_tris(W / 2 - 7.5, 0, H / 2 - 12 + i * 7, 15, WALL + 1, 3)
    for gx in (24, W - 24):
        tris += _cylinder_tris(gx, -1, H / 2 - 8, H / 2 + 8, 4, seg=20)
    tris += _box_tris(W / 2 - USBC_W / 2, -0.5, 2, USBC_W, WALL + 1, USBC_H)
    for sx in (6, W - 16):
        tris += _box_tris(sx, D / 2 - 3, H / 2 - 7, 10, 3, 14)
    # Branding bars (emboss simulation)
    tris += _box_tris(18, -0.3, 12, 59, 0.9, 4)
    tris += _box_tris(24, -0.3, 6, 47, 0.6, 3)
    return tris


def mesh_clip() -> list[Tri]:
    tris: list[Tri] = []
    bar_w, arm_w, arm_h, dep = 52, 8, 16, 6
    x0 = (W - bar_w) / 2
    tris += _box_tris(x0, 0, arm_h - 2, bar_w, dep, 4)
    for ax in (x0 - arm_w + 2, x0 + bar_w - 2):
        tris += _box_tris(ax, 0, 0, arm_w, dep, arm_h)
        tris += _box_tris(ax + 1, dep - 1, arm_h - 5, arm_w - 2, 2, 5)
    tris += _box_tris(W / 2 - 8, dep - 1, arm_h + 2, 16, 8, 3)
    return tris


def export_openscad(out_dir: Path, variant: str) -> bool:
    exe = shutil.which("openscad") or shutil.which("openscad.com")
    if not exe:
        return False
    out_dir.mkdir(parents=True, exist_ok=True)
    defines = ["-Dvariant=" + variant] if variant == "lcd" else []
    for scad in SCAD_PARTS:
        stl_name = scad.replace(".scad", ".stl")
        dst = out_dir / stl_name
        cmd = [exe, "-o", str(dst), str(OPENSCAD / scad), *defines]
        if scad != "ctg_front_shell.scad":
            cmd = [exe, "-o", str(dst), str(OPENSCAD / scad)]
        print(f"OpenSCAD [{variant}]: {stl_name}")
        subprocess.run(cmd, check=True, cwd=str(OPENSCAD))
    return True


def export_python(out_dir: Path, variant: str) -> None:
    dims = VARIANT_DIMS[variant]
    out_dir.mkdir(parents=True, exist_ok=True)
    builders: dict[str, Callable[[], list[Tri]]] = {
        "ctg_front_shell.stl": lambda: mesh_front_shell(
            dims["display_w"], dims["display_h"], dims["display_z"]
        ),
        "ctg_rear_shell.stl": mesh_rear_shell,
        "ctg_clip.stl": mesh_clip,
    }
    for name, fn in builders.items():
        path = out_dir / name
        tris = fn()
        write_binary_stl(path, tris)
        print(f"Python [{variant}]: {path} ({len(tris)} tris)")


def generate_variant(variant: str, use_openscad: bool = True) -> None:
    out_dir = ROOT / "stl" / variant
    if use_openscad and export_openscad(out_dir, variant):
        pass
    else:
        export_python(out_dir, variant)
    if variant == "eink":
        LEGACY_OUT.mkdir(parents=True, exist_ok=True)
        for stl in out_dir.glob("*.stl"):
            shutil.copy2(stl, LEGACY_OUT / stl.name)
            print(f"Legacy copy: {LEGACY_OUT / stl.name}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate CTG enclosure STLs")
    parser.add_argument("--variant", choices=("eink", "lcd", "all"), default="eink")
    parser.add_argument("--python-only", action="store_true", help="Skip OpenSCAD attempt")
    args = parser.parse_args()
    variants = ("eink", "lcd") if args.variant == "all" else (args.variant,)
    print("CyberThreatGotchi — STL export")
    for v in variants:
        generate_variant(v, use_openscad=not args.python_only)
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
