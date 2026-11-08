"""Атлас падающих листьев для частиц арены: 2×2 листа (берёза, осина, дуб, ольха) на прозрачном фоне.

Запуск: python3 -I tools/concepts/leaf_atlas.py → assets/noir/ambience/leaves.png (512×512).
Рисуем сами (PIL), а не нейросетью: на экране лист — 8–12 пикселей, важны силуэт и тёплый осенний тон.
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "noir" / "ambience" / "leaves.png"
CELL = 256
SS = 4  # рисуем крупнее и уменьшаем — гладкий край


def outline(kind: str) -> list[tuple[float, float]]:
    """Контур листа в единицах: черешок внизу (0,-1), кончик вверху (0,1)."""
    pts = []
    n = 120
    for i in range(n + 1):
        t = i / n * math.pi * 2
        y = -math.cos(t)
        side = math.sin(t)
        if kind == "birch":  # треугольно-яйцевидный, пильчатый край
            w = 0.62 * math.sin(math.acos(max(-1.0, min(1.0, y)))) * (1.15 - 0.45 * (y + 1) / 2)
            w *= 1.0 + 0.07 * (1 if (i % 6) < 3 else -1)
        elif kind == "aspen":  # почти круглый, городчатый
            w = 0.78 * math.sin(math.acos(max(-1.0, min(1.0, y)))) * (1.0 - 0.15 * y)
            w *= 1.0 + 0.05 * math.sin(i * 0.9)
        elif kind == "oak":  # лопасти
            w = 0.55 * math.sin(math.acos(max(-1.0, min(1.0, y)))) * (0.85 + 0.15 * y)
            w *= 1.0 + 0.32 * math.sin((y + 1) * math.pi * 2.5) ** 2
        else:  # alder — обратнояйцевидный, с выемкой на кончике
            w = 0.66 * math.sin(math.acos(max(-1.0, min(1.0, y)))) * (0.8 + 0.25 * y)
        pts.append((side * w, y * 0.92))
    return pts


def leaf(kind: str, base: tuple[int, int, int], edge: tuple[int, int, int], seed: int) -> Image.Image:
    rnd = random.Random(seed)
    size = CELL * SS
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    scale = size * 0.42
    cx, cy = size / 2, size / 2 + size * 0.03
    bend = rnd.uniform(-0.12, 0.12)

    def to_px(p: tuple[float, float]) -> tuple[float, float]:
        x, y = p
        x += bend * (y + 1) ** 2 * 0.5
        return cx + x * scale, cy - y * scale

    poly = [to_px(p) for p in outline(kind)]
    draw.polygon(poly, fill=base + (255,))
    # тон к краю и пятна увядания
    shade = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for _ in range(14):
        x, y = rnd.uniform(-0.5, 0.5), rnd.uniform(-0.8, 0.8)
        r = rnd.uniform(0.05, 0.18) * scale
        px, py = to_px((x, y))
        sd.ellipse((px - r, py - r, px + r, py + r), fill=edge + (rnd.randint(60, 140),))
    shade = shade.filter(ImageFilter.GaussianBlur(size * 0.012))
    mask = img.split()[3]
    img = Image.composite(Image.alpha_composite(img, shade), img, mask)
    veins = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(veins)
    vein = tuple(max(0, c - 55) for c in base) + (200,)
    draw.line([to_px((0, -0.95)), to_px((0, 0.85))], fill=vein, width=int(size * 0.012))
    for k in range(5):
        y = -0.6 + k * 0.3
        for s in (-1, 1):
            draw.line([to_px((0, y)), to_px((s * 0.38, y + 0.28))], fill=vein, width=int(size * 0.006))
    # жилки только внутри листа
    clipped = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    clipped.paste(veins, (0, 0), Image.fromarray(np.minimum(np.asarray(veins.split()[3]), np.asarray(mask))))
    img = Image.alpha_composite(img, clipped)
    draw = ImageDraw.Draw(img)
    # черешок
    draw.line([to_px((0, -1.25)), to_px((0, -0.9))], fill=vein, width=int(size * 0.012))
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(rim).polygon(poly, outline=tuple(max(0, c - 70) for c in base) + (255,), width=int(size * 0.01))
    img = Image.alpha_composite(img, rim)
    return img.resize((CELL, CELL), Image.LANCZOS)


def main() -> None:
    atlas = Image.new("RGBA", (CELL * 2, CELL * 2), (0, 0, 0, 0))
    sets = [("birch", (214, 168, 58), (150, 92, 30)), ("aspen", (196, 98, 42), (120, 46, 24)),
            ("oak", (150, 98, 52), (92, 60, 32)), ("alder", (164, 150, 62), (98, 104, 40))]
    for i, (kind, base, edge) in enumerate(sets):
        atlas.paste(leaf(kind, base, edge, i * 7 + 3), ((i % 2) * CELL, (i // 2) * CELL))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT)
    print(f"[leaves] {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
