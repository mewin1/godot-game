"""Shared, UV-addressed finish atlas. Run with the system Python (Pillow and NumPy)."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "source_art/noir/textures"
OUT = ROOT / "assets/ritual/town"
SIZE = 256
# The order is also the surface key in the Blender builder and the Godot shader.
SWATCHES = [
    ("oak", "wood", "74503a"), ("carving", "wood", "b68958"), ("heartwood", "wood", "49362d"),
    ("plaster", "plaster", "dbba8e"), ("stone", "courses", "969493"), ("brick", "brick", "9f5744"),
    ("lime", "courses", "d3c6ae"), ("plinth", "courses", "716e62"),
    ("svarog", "shingle", "8d493d"), ("ice", "shingle", "435e78"), ("water", "shingle", "849fa9"),
    ("stribog", "shingle", "508f83"), ("war", "shingle", "a18250"), ("perun", "shingle", "c1c0bf"),
    ("curse", "shingle", "504653"), ("linen", "cloth", "dac8a3"),
    ("iron", "patina", "4a4948"), ("copper", "patina", "af7755"), ("brass", "patina", "b89b68"),
    ("verdigris", "patina", "5d8b80"), ("pottery", "plaster", "775678"), ("slate", "courses", "48434e"),
    ("glass", "plaster", "f4bb70"), ("soot", "plaster", "342c2a"),
    ("ember", "ember", "ff9252"), ("frost", "crystal", "9ddbed"), ("pool", "liquid", "65bec7"),
    ("charge", "crystal", "ceb2fa"), ("rune", "plaster", "be82b8"), ("rope", "cloth", "a58d69"),
    ("bone", "plaster", "d6c7a6"), ("steel", "patina", "9da2a2"),
]


def luminance(kind):
    src = {"plaster": "stone", "courses": "stone", "brick": "stone", "patina": "metal",
           "ember": "stone", "crystal": "metal", "liquid": "cloth"}.get(kind, kind)
    plane = Image.open(SOURCE / (src + ".png")).convert("L")
    if kind not in ("wood", "shingle", "cloth"):
        plane = plane.crop((52, 54, 174, 176))
    plane = np.asarray(plane.resize((SIZE, SIZE), Image.Resampling.LANCZOS), dtype=float)
    return (plane - plane.mean()) / max(plane.std(), 1.0)


def masonry(kind, seed):
    rng = np.random.default_rng(seed)
    mortar = Image.new("L", (SIZE, SIZE), 140)
    draw = ImageDraw.Draw(mortar)
    rows, count = (8, 4) if kind == "brick" else (5, 3)
    for row in range(rows):
        y = round(row * SIZE / rows)
        for col in range(-1, count + 1):
            x = round((col + (row % 2) * 0.5) * SIZE / count)
            end = (x + round(SIZE / count) - 2, round((row + 1) * SIZE / rows) - 2)
            draw.rounded_rectangle((x, y, *end), radius=3, fill=int(rng.integers(206, 241)))
            draw.line((x + 4, y + 2, end[0] - 3, y + 2), fill=243, width=2)
    return np.asarray(mortar.filter(ImageFilter.GaussianBlur(0.5))) / 222.0


def main():
    atlas = Image.new("RGB", (8 * SIZE, 4 * SIZE))
    yy, xx = np.mgrid[:SIZE, :SIZE]
    for index, (_, kind, color) in enumerate(SWATCHES):
        grain = luminance(kind)
        strength = {"wood": .21, "shingle": .27, "ember": .24, "plaster": .055,
                    "patina": .08, "liquid": .04}.get(kind, .09)
        shade = 1 + np.clip(grain * strength, -.55, .45)
        if kind in ("brick", "courses"):
            shade *= masonry(kind, index)
        if kind == "liquid":
            radius = np.hypot((xx - 125) / 1.4, yy - 143)
            shade += .13 * np.maximum(0, np.cos(radius * .28)) ** 6
        if kind == "ember":
            shade += .12 * np.sin(yy * .075 + np.sin(xx * .09))
        rgb = np.array(list(bytes.fromhex(color)))
        tile = Image.fromarray(np.uint8(np.clip(shade[:, :, None] * rgb, 0, 255)))
        # Four-pixel bleed at all edges keeps distant mip sampling clean.
        padded = np.pad(np.asarray(tile.resize((248, 248))), ((4, 4), (4, 4), (0, 0)), mode="edge")
        atlas.paste(Image.fromarray(padded), ((index % 8) * SIZE, (index // 8) * SIZE))
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / "finishes.jpg", quality=94, subsampling=0)


if __name__ == "__main__":
    main()
