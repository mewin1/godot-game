"""Итоговые сравнения для автора: «референс | старый метод | Hunyuan3D» с совпадением силуэта (IoU).

python3 -I tools/blender/noir/final_sheet.py [id ...]  → new_concept/final/<id>.jpg и общий лист new_concept/final/all.jpg
IoU старого метода считается по его карте силуэта (серое / (серое + красное + зелёное)).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
NC = ROOT / "new_concept"
R = NC / "compare" / "renders"
FINAL = NC / "final"
SOURCES = {"terem": "buildings/terem_5.png"}
GROUPS = ["buildings", "units", "heroes", "idols", "arena_props"]
FONT = "/usr/share/fonts/TTF/DejaVuSans.ttf"


def concept(mid: str):
    if mid in SOURCES:
        return NC / SOURCES[mid]
    for g in GROUPS:
        p = NC / g / f"{mid}_16.png"
        if p.exists():
            return p
    return None


def sil_iou(path: Path):
    if not path.exists():
        return None
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    gray = (np.abs(a[..., 0] - 89) < 12) & (np.abs(a[..., 1] - 89) < 12)
    red = (a[..., 0] > 180) & (a[..., 1] < 60)
    green = (a[..., 1] > 170) & (a[..., 0] < 60)
    union = gray.sum() + red.sum() + green.sum()
    return gray.sum() / union if union else None


def old_render(mid: str):
    for name in (mid, {"idol_empty": "idol", "terem": "terem"}.get(mid, mid)):
        p = R / f"{name}.png"
        if p.exists():
            return p, sil_iou(R / f"{name}_sil.png")
    return None, None


def panel(mid: str, h: int = 560) -> Image.Image:
    font = ImageFont.truetype(FONT, 22)
    small = ImageFont.truetype(FONT, 18)
    old, old_iou = old_render(mid)
    new = R / f"{mid}_h3d.png"
    new_iou = None
    if (R / f"{mid}_h3d.iou").exists():
        new_iou = float((R / f"{mid}_h3d.iou").read_text())
    cols = [("референс", concept(mid), None), ("старый метод", old, old_iou), ("Hunyuan3D", new if new.exists() else None, new_iou)]
    ims = []
    for label, path, iou in cols:
        if path is None:
            im = Image.new("RGB", (int(h * 0.75), h), (14, 16, 20))
            ImageDraw.Draw(im).text((20, h // 2), "нет", fill=(120, 120, 120), font=font)
        else:
            im = Image.open(path).convert("RGB")
            im = im.resize((int(im.width * h / im.height), h))
        ims.append((label, im, iou))
    w = sum(i.width for _, i, _ in ims) + 8 * (len(ims) - 1)
    c = Image.new("RGB", (w, h + 40), (8, 10, 12))
    d = ImageDraw.Draw(c)
    x = 0
    for label, im, iou in ims:
        c.paste(im, (x, 40))
        text = f"{mid} · {label}" + (f" · IoU {iou:.2f}" if iou is not None else "")
        d.text((x + 8, 8), text, fill=(232, 176, 92), font=small)
        x += im.width + 8
    return c


def main() -> None:
    FINAL.mkdir(parents=True, exist_ok=True)
    ids = sys.argv[1:] or sorted(p.name[: -len("_h3d.png")] for p in R.glob("*_h3d.png"))
    panels = []
    for mid in ids:
        p = panel(mid)
        p.save(FINAL / f"{mid}.jpg", quality=86)
        panels.append(p)
    if not sys.argv[1:]:
        thumbs = [p.resize((p.width * 300 // p.height, 300)) for p in panels]
        per_row = 3
        rows = [thumbs[i:i + per_row] for i in range(0, len(thumbs), per_row)]
        w = max(sum(t.width for t in r) + 10 * (len(r) - 1) for r in rows)
        sheet = Image.new("RGB", (w, len(rows) * 310), (8, 10, 12))
        for ri, r in enumerate(rows):
            x = 0
            for t in r:
                sheet.paste(t, (x, ri * 310))
                x += t.width + 10
        sheet.save(FINAL / "all.jpg", quality=84)
        print(FINAL / "all.jpg", len(panels))


if __name__ == "__main__":
    main()
