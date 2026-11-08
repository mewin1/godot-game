"""Вырезка существ из листов-концептов автора (пергамент с рунами) на белый фон для Hunyuan3D.

Запуск: ~/ComfyUI/.venv/bin/python -I tools/concepts/creature_crops.py (нужен OpenCV для медведя)
Вход: new_concept/creatures/sheets/*.png. Выход: new_concept/creatures/<id>_16.png
(формат, который ждут tools/concepts/h3d_gen.py и h3d_paint.py) и <id>_mask.png для проверки глазами.
Фон пергамента неровный, поэтому маска — по отличию от цвета бумаги + самая крупная связная часть
(руны и карандашные наброски отпадают) + заливка дыр.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "new_concept" / "creatures"
# id: (лист, рамка вырезки, порог отличия от бумаги, срезать светлую тень снизу)
CROPS = {
    "crow_perch": ("crow_sheet", (30, 25, 320, 295), 0.22, False),
    "crow_fly": ("crow_flight_sheet", (15, 20, 455, 275), 0.22, False),
    "bear_cub": ("bear_cub_sheet", (48, 62, 338, 234), 0.16, True),
}


def components(mask: np.ndarray) -> np.ndarray:
    """Метки связных частей (4-связность), 0 — фон."""
    label = np.zeros(mask.shape, dtype=np.int32)
    cur = 0
    for y0, x0 in zip(*np.nonzero(mask)):
        if label[y0, x0]:
            continue
        cur += 1
        label[y0, x0] = cur
        stack = [(y0, x0)]
        while stack:
            y, x = stack.pop()
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not label[ny, nx]:
                    label[ny, nx] = cur
                    stack.append((ny, nx))
    return label


def grabcut(img: Image.Image) -> np.ndarray:
    """Шерсть по тону близка к бумаге: маску делит OpenCV GrabCut по рамке (фигура внутри, края — фон)."""
    import cv2

    bgr = cv2.cvtColor(np.asarray(img), cv2.COLOR_RGB2BGR)
    mask = np.zeros(bgr.shape[:2], np.uint8)
    h, w = mask.shape
    rect = (3, 3, w - 6, h - 6)
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(bgr, mask, rect, bgd, fgd, 8, cv2.GC_INIT_WITH_RECT)
    return (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)


def cut(sheet: str, box: tuple, thr: float, drop_shadow: bool) -> tuple[Image.Image, Image.Image]:
    img = Image.open(DIR / "sheets" / f"{sheet}.png").convert("RGB").crop(box)
    px = np.asarray(img, dtype=np.float32) / 255.0
    border = np.concatenate([px[:4].reshape(-1, 3), px[-4:].reshape(-1, 3), px[:, :4].reshape(-1, 3),
                             px[:, -4:].reshape(-1, 3)])
    paper = np.median(border, axis=0)
    diff = np.abs(px - paper).max(axis=2)
    mask = diff > thr
    if drop_shadow:
        mask = grabcut(img)
    m = Image.fromarray((mask * 255).astype(np.uint8))
    m = m.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    mask = np.asarray(m) > 127
    # «размыкание»: тонкие перемычки к пятнам бумаги и полоски тени рвутся, ядро фигуры остаётся
    core = Image.fromarray((mask * 255).astype(np.uint8))
    if drop_shadow:
        core = core.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))
    label = components(np.asarray(core) > 127)
    sizes = np.bincount(label.ravel())
    sizes[0] = 0
    keep = Image.fromarray(((label == sizes.argmax()) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    mask &= np.asarray(keep) > 127
    # дыры внутри фигуры (блики, просветы между перьями) — заливаем
    outside = components(~mask)
    edge_labels = set(np.unique(np.concatenate([outside[0], outside[-1], outside[:, 0], outside[:, -1]])))
    edge_labels.discard(0)
    holes = (~mask) & ~np.isin(outside, list(edge_labels))
    small_holes = holes.copy()
    hole_lab = components(holes)
    for lab, n in enumerate(np.bincount(hole_lab.ravel())):
        if lab and n > 400:  # большие просветы (между лап, под крылом) — настоящий фон
            small_holes[hole_lab == lab] = False
    mask |= small_holes
    alpha = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    return img, alpha


def main() -> None:
    for mid, (sheet, box, thr, shadow) in CROPS.items():
        img, alpha = cut(sheet, box, thr, shadow)
        a = np.asarray(alpha) > 127
        rows, cols = np.nonzero(a.any(axis=1))[0], np.nonzero(a.any(axis=0))[0]
        y0, y1, x0, x1 = rows.min(), rows.max() + 1, cols.min(), cols.max() + 1
        side = int(max(x1 - x0, y1 - y0) / 0.76)
        canvas = Image.new("RGB", (side, side), (255, 255, 255))
        canvas.paste(img.crop((x0, y0, x1, y1)), ((side - (x1 - x0)) // 2, (side - (y1 - y0)) // 2),
                     alpha.crop((x0, y0, x1, y1)))
        canvas.resize((1024, 1024), Image.LANCZOS).save(DIR / f"{mid}_16.png")
        alpha.save(DIR / f"{mid}_mask.png")
        print(f"[crop] {mid}: {x1 - x0}×{y1 - y0} px")


if __name__ == "__main__":
    main()
