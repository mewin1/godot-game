"""Лист «было | стало» из облётов (tools/blender/noir/turn.py): концепт слева, справа два ряда ракурсов.

python3 -I tools/concepts/turn_sheet.py <out.jpg> <id>:<концепт.png>:<облёт.png> [...]
Облёт — 2 строки (сверху старая модель, снизу новая), 4 ракурса. Пустые поля по краям обрезаются,
тёмные рендеры немного осветляются для просмотра (только на листе).
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROW_H = 300
FONT = "/usr/share/fonts/TTF/DejaVuSans.ttf"


def trim_row(row: Image.Image) -> Image.Image:
    px = np.asarray(row.convert("L"), dtype=np.float32)
    bg = np.median(px)
    ys, xs = np.nonzero(np.abs(px - bg) > 10)
    if len(ys) == 0:
        return row
    return row.crop((max(xs.min() - 10, 0), max(ys.min() - 10, 0), xs.max() + 10, ys.max() + 10))


def main() -> None:
    out, items = sys.argv[1], sys.argv[2:]
    blocks = []
    for item in items:
        mid, concept, turn = item.split(":")
        c = Image.open(concept).convert("RGB")
        c = c.resize((int(c.width * ROW_H * 2 / c.height), ROW_H * 2))
        t = Image.open(turn).convert("RGB")
        rows = []
        for r in (0, 1):
            views = []
            for v in range(4):
                cell = trim_row(t.crop((v * t.width // 4, r * t.height // 2, (v + 1) * t.width // 4,
                                        (r + 1) * t.height // 2)))
                views.append(cell.resize((int(cell.width * ROW_H / cell.height), ROW_H)))
            row = Image.new("RGB", (sum(x.width for x in views) + 30, ROW_H), (12, 15, 17))
            x = 0
            for view in views:
                row.paste(view, (x, 0))
                x += view.width + 10
            rows.append(ImageEnhance.Brightness(row).enhance(1.6))
        w = c.width + max(r.width for r in rows) + 20
        block = Image.new("RGB", (w, ROW_H * 2 + 30), (12, 15, 17))
        block.paste(c, (0, 30))
        for i, r in enumerate(rows):
            block.paste(r, (c.width + 20, 30 + i * ROW_H))
        d = ImageDraw.Draw(block)
        d.text((8, 4), f"{mid}: концепт | сверху было, снизу стало (4 стороны)", fill=(230, 180, 90),
               font=ImageFont.truetype(FONT, 20))
        blocks.append(block)
    width = max(b.width for b in blocks)
    sheet = Image.new("RGB", (width, sum(b.height for b in blocks)), (12, 15, 17))
    y = 0
    for b in blocks:
        sheet.paste(b, (0, y))
        y += b.height
    sheet.save(out, quality=88)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
