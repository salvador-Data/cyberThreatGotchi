#!/usr/bin/env python3
"""Render Mr. Pac-Bot pocket shell STLs into website product images."""

from __future__ import annotations

import argparse
import sys
import urllib.request
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import trimesh
from matplotlib.figure import Figure
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_STL_DIR = ROOT / ".cache" / "crackbot-stl"
DEFAULT_OUT_DIR = ROOT / "website" / "images" / "products"

STL_URLS = {
    "mcb_front_shell.stl": (
        "https://raw.githubusercontent.com/salvador-Data/Mr.-CrackBot-AI-Nano/"
        "main/hardware/stl/pocket/mcb_front_shell.stl"
    ),
    "mcb_rear_shell.stl": (
        "https://raw.githubusercontent.com/salvador-Data/Mr.-CrackBot-AI-Nano/"
        "main/hardware/stl/pocket/mcb_rear_shell.stl"
    ),
    "mcb_clip.stl": (
        "https://raw.githubusercontent.com/salvador-Data/Mr.-CrackBot-AI-Nano/"
        "main/hardware/stl/pocket/mcb_clip.stl"
    ),
}


def ensure_stls(stl_dir: Path) -> dict[str, Path]:
    stl_dir.mkdir(parents=True, exist_ok=True)
    paths: dict[str, Path] = {}
    for name, url in STL_URLS.items():
        dest = stl_dir / name
        if not dest.is_file() or dest.stat().st_size < 100:
            print(f"Downloading {name}...")
            urllib.request.urlretrieve(url, dest)
        paths[name] = dest
    return paths


def load_mesh(path: Path) -> trimesh.Trimesh:
    mesh = trimesh.load(path, force="mesh")
    if isinstance(mesh, trimesh.Scene):
        mesh = trimesh.util.concatenate(tuple(mesh.dump().values()))
    mesh.apply_translation(-mesh.centroid)
    return mesh


def combine_shells(front: trimesh.Trimesh, rear: trimesh.Trimesh, clip: trimesh.Trimesh) -> trimesh.Trimesh:
    """Assemble pocket shell parts for a product hero angle."""
    front = front.copy()
    rear = rear.copy()
    clip = clip.copy()

    gap = max(front.extents[2], rear.extents[2]) * 0.55
    front.apply_translation([gap * 0.35, 0.0, gap * 0.15])
    rear.apply_translation([-gap * 0.45, 0.0, -gap * 0.08])
    clip.apply_translation([gap * 0.9, gap * 0.35, gap * 0.25])
    clip.apply_scale(0.85)

    combined = trimesh.util.concatenate([front, rear, clip])
    combined.apply_translation(-combined.centroid)
    return combined


def face_colors(mesh: trimesh.Trimesh, base_rgb: tuple[float, float, float]) -> np.ndarray:
    """Simple directional shading from face normals."""
    normals = mesh.face_normals
    light = np.array([0.35, 0.55, 0.75], dtype=float)
    light /= np.linalg.norm(light)
    intensity = 0.42 + 0.58 * np.clip(normals @ light, 0.0, 1.0)
    colors = np.zeros((len(mesh.faces), 4), dtype=float)
    colors[:, 0] = base_rgb[0] * intensity
    colors[:, 1] = base_rgb[1] * intensity
    colors[:, 2] = base_rgb[2] * intensity
    colors[:, 3] = 1.0
    return colors


def render_product_image(
    mesh: trimesh.Trimesh,
    out_png: Path,
    out_jpg: Path | None = None,
    *,
    elev: float = 22,
    azim: float = -48,
    width: int = 1440,
    height: int = 1080,
    max_jpg_kb: int = 480,
) -> None:
    base = np.array([0.0, 0.71, 0.55])  # HackerPlanet accent teal
    accent = np.array([0.82, 0.66, 1.0])  # magenta highlight on clip faces
    colors = face_colors(mesh, tuple(base))
    # Tint top-facing clip region slightly magenta
    z_norm = mesh.face_normals[:, 2]
    colors[z_norm > 0.65, :3] = colors[z_norm > 0.65, :3] * 0.55 + accent * 0.45

    fig = Figure(figsize=(width / 100, height / 100), dpi=100)
    ax = fig.add_subplot(111, projection="3d")
    ax.set_facecolor("#0a0e14")
    fig.patch.set_facecolor("#0a0e14")

    verts = mesh.vertices
    faces = mesh.faces
    polys = [[verts[i] for i in tri] for tri in faces]
    collection = Poly3DCollection(
        polys,
        facecolors=colors,
        edgecolors=(0.0, 0.0, 0.0, 0.06),
        linewidths=0.12,
    )
    ax.add_collection3d(collection)

    scale = mesh.extents.max() * 0.62
    ax.set_xlim(-scale, scale)
    ax.set_ylim(-scale, scale)
    ax.set_zlim(-scale, scale)
    ax.view_init(elev=elev, azim=azim)
    ax.set_axis_off()
    ax.set_box_aspect([1, 1, 1])
    fig.subplots_adjust(0, 0, 1, 1)

    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, dpi=100, facecolor=fig.get_facecolor(), transparent=False)
    plt.close(fig)

    print(f"Wrote {out_png} ({out_png.stat().st_size // 1024} KB)")
    if out_jpg is None:
        return
    img = Image.open(out_png).convert("RGB")
    quality = 92
    while quality >= 68:
        img.save(out_jpg, format="JPEG", quality=quality, optimize=True, progressive=True)
        if out_jpg.stat().st_size <= max_jpg_kb * 1024:
            break
        quality -= 4
    print(f"Wrote {out_jpg} ({out_jpg.stat().st_size // 1024} KB, q={quality})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stl-dir", type=Path, default=DEFAULT_STL_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args(argv)

    paths = ensure_stls(args.stl_dir)
    front = load_mesh(paths["mcb_front_shell.stl"])
    rear = load_mesh(paths["mcb_rear_shell.stl"])
    clip = load_mesh(paths["mcb_clip.stl"])
    combined = combine_shells(front, rear, clip)

    hero_png = args.out_dir / "mr-pac-bot-product.png"
    hero_jpg = args.out_dir / "mr-pac-bot-stl-product.jpg"
    render_product_image(combined, hero_png, hero_jpg, elev=24, azim=-52)

    pocket_png = args.out_dir / "direct-crackbot-cyd.png"
    pocket_jpg = args.out_dir / "direct-crackbot-cyd.jpg"
    render_product_image(combined, pocket_png, pocket_jpg, elev=12, azim=-28)
    return 0


if __name__ == "__main__":
    sys.exit(main())
