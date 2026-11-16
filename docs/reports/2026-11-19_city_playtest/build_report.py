"""Лист было/стало по плейтесту автора 19 ноября: один HTML, кадры внутри (base64).

python3 -I docs/reports/2026-11-19_city_playtest/build_report.py → docs/reports/2026-11-19_city_playtest.html
Кадры — папки before/ и after/ рядом (shots.sh), цифры — README.md.
"""
import base64
import html
import io
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
TARGET = HERE.parent / "2026-11-19_city_playtest.html"

# (пункты, заголовок, что сделано, файл кадра, обрезка (доли x0, y0, x1, y1) или None)
ENTRIES = [
    ("2, 7", "Город 4 сверху: участки на всей мостовой",
     "Участки 13/26/39/40: у ворот, у терема, северо-запад, углы пруда у моста, вдоль южной стены. Герой — перед "
     "крыльцом терема.", "l4_day_1920x1080_top.jpg", None),
    ("8, 12, 13, 14", "Город 4 ночью (1920×1080)",
     "Кадр не заходит под шапку; шапка — «Ночь N ☾ 1:30», разведка значками, кнопка умения — знак и Q.",
     "l4_night_1920x1080_ui.jpg", None),
    ("12", "Ночь босса (1280×720)", "Босс — череп, номер ночи и знак неуязвимости; подробности в подсказке.",
     "l3_night_1280x720_ui.jpg", None),
    ("15", "Окно идола", "Короче: строка стихии и подсказки вместо абзацев.", "l1_day_1920x1080_idol_ui.jpg",
     (0.45, 0.2, 1.0, 0.75)),
    ("9, 10", "Вечер, город 2", "Без жёлтого листопада; вороны прилетают из-за города.",
     "l2_evening_1920x1080_game.jpg", None),
    ("11", "Подход нежити", "Фантомы на тропе шагают (кадр — момент выхода).", "l1_spawn_1280x720_spawn.jpg", None),
    ("8", "Портрет (607×1080)", "Город целиком между шапкой и доком.", "l1_day_607x1080_ui.jpg", None),
    ("8", "21:9", "Кадр по экрану.", "l4_night_2520x1080_ui.jpg", None),
]

# Только «после»: новые состояния, которых до правки не было.
AFTER_ONLY = [
    ("1", "Проулок: мост и дома у моста", "Завала нет; дома на углах пруда достают до моста.",
     "l2_night_1920x1080_bridge.jpg"),
    ("6", "Улица куплена днём", "Вход откроется через полный день — есть время построиться.",
     "l1_day_1920x1080_street_ui.jpg"),
    ("4", "Частоколы-заслоны", "Два частокола на главной дороге: держат любого врага 6 с и ломаются.",
     "l2_spawn_1920x1080_walls_ui.jpg"),
    ("12", "Шапка ночью босса (1280×720)", "Значки вместо строк.", "l3_boss_1280x720_ui.jpg"),
]


def pair(name: str, crop) -> str:
    """Было слева, стало справа — один JPEG ~1600 px шириной."""
    images = []
    for side in ("before", "after"):
        path = HERE / side / name
        if not path.exists():
            return ""
        image = Image.open(path).convert("RGB")
        if crop:
            w, h = image.size
            image = image.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
        images.append(image)
    width = 800
    scaled = [im.resize((width, max(1, round(im.height * width / im.width))), Image.LANCZOS) for im in images]
    height = max(im.height for im in scaled)
    sheet = Image.new("RGB", (width * 2 + 8, height), (14, 16, 20))
    sheet.paste(scaled[0], (0, 0))
    sheet.paste(scaled[1], (width + 8, 0))
    buffer = io.BytesIO()
    sheet.save(buffer, "JPEG", quality=80)
    return base64.b64encode(buffer.getvalue()).decode()


def main() -> None:
    readme = (HERE / "README.md").read_text(encoding="utf-8") if (HERE / "README.md").exists() else ""
    parts = ["<!DOCTYPE html><html lang='ru'><head><meta charset='utf-8'><title>«Городище»: плейтест 19 ноября</title>",
             "<style>body{background:#101317;color:#e8dfcf;font:16px/1.5 'Fira Sans',sans-serif;max-width:1700px;"
             "margin:auto;padding:24px}h1,h2{font-family:Kurale,serif;color:#f0c27a}h2{margin-top:36px}"
             "img{width:100%;border:1px solid #333;border-radius:6px}.pts{color:#9fb4c0;font-size:14px}"
             ".lbl{display:flex;justify-content:space-around;color:#9fb4c0;font-size:14px}"
             "pre{white-space:pre-wrap;background:#171b21;padding:16px;border-radius:8px}</style></head><body>",
             "<h1>«Городище»: правка по плейтесту автора 19 ноября — было / стало</h1>",
             "<p>Слева — до (кадры <code>before/</code>), справа — после (<code>after/</code>), те же камеры пробника "
             "<code>shots.sh</code>. Цифры яркости, дампа и бота, «не сделано и почему» — в конце (README).</p>"]
    for points, title, note, name, crop in ENTRIES:
        data = pair(name, crop)
        if not data:
            print("нет кадра:", name, file=sys.stderr)
            continue
        parts.append(f"<h2>{html.escape(title)}</h2><div class='pts'>п. {points} · {html.escape(name)}</div>"
                     f"<p>{html.escape(note)}</p><div class='lbl'><span>было</span><span>стало</span></div>"
                     f"<img src='data:image/jpeg;base64,{data}'>")
    for points, title, note, name in AFTER_ONLY:
        path = HERE / "after" / name
        if not path.exists():
            print("нет кадра:", name, file=sys.stderr)
            continue
        image = Image.open(path).convert("RGB")
        image = image.resize((1600, round(image.height * 1600 / image.width)), Image.LANCZOS)
        buffer = io.BytesIO()
        image.save(buffer, "JPEG", quality=80)
        data = base64.b64encode(buffer.getvalue()).decode()
        parts.append(f"<h2>{html.escape(title)}</h2><div class='pts'>п. {points} · {html.escape(name)}</div>"
                     f"<p>{html.escape(note)}</p><img src='data:image/jpeg;base64,{data}'>")
    parts.append("<h2>README: цифры и что не сделано</h2><pre>" + html.escape(readme) + "</pre></body></html>")
    TARGET.write_text("\n".join(parts), encoding="utf-8")
    print(TARGET, round(TARGET.stat().st_size / 1e6, 1), "МБ")


if __name__ == "__main__":
    main()
