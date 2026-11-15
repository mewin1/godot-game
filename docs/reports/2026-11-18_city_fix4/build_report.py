"""Лист было/стало по critique_4: один HTML, кадры внутри (base64).

python3 -I docs/reports/2026-11-18_city_fix4/build_report.py → docs/reports/2026-11-18_city_fix4.html
Кадры — папки before/ и after/ рядом (shots.sh), цифры — README.md.
"""
import base64
import html
import io
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
TARGET = HERE.parent / "2026-11-18_city_fix4.html"

# (пункты, заголовок, что сделано, файл кадра, обрезка (доли x0, y0, x1, y1) или None)
ENTRIES = [
    ("1, 3", "Ночь, город 4: крыши и машины",
     "Крыши ночью светлее (тёс x1,3, лунный блеск): маска крыш 33 → 50 при рамке 29. Машины в покое тише, ядро "
     "не белее 0,6 — ледяное лезвие больше не ярче врагов.", "l4_night_1920x1080_game.jpg", (0.25, 0.08, 0.85, 0.7)),
    ("5, 6, 61", "Ворота: пламя, жаровни, фонари",
     "Край квада пламени исчез (fog_disabled). Жаровен у ворот нет — вход отмечают фонари на столбах: тёплый короб "
     "в раме, шатровый колпак, крюк.", "l1_evening_1920x1080_gatewest.jpg", None),
    ("4", "Вечер, город 2: настил кладок",
     "Настил тоном дороги (1,6 → 1,15), а не самое светлое пятно кадра.", "l2_evening_1920x1080_pier.jpg", None),
    ("15", "Мостовая без швов",
     "Булыжник строится в шейдере (ячейки Вороного): камни непрерывны, сетки клеток 2 м нет.",
     "l1_evening_1920x1080_plazatop.jpg", None),
    ("10, 54", "Сторожка",
     "Проезд вдоль дороги под шатром со светлой обвязкой и навершием, сторона к камере открыта, фонарь у проёма. "
     "Герой — перед проёмом, виден целиком (0,9 м до столба).", "l1_evening_1920x1080_gatehouse.jpg", None),
    ("10, 54", "Сторожка с игровой камеры (1280×720)",
     "Не «шкаф» и не доска поперёк дороги.", "l1_spawn_1280x720_game.jpg", (0.35, 0.1, 0.9, 0.65)),
    ("11", "Подклет терема",
     "Подклет до низа сруба, облицован булыжником мостовой; три ступени к дороге, крыльцо-настил, окладной венец. "
     "Остатки плиты спрятаны.", "l1_evening_1920x1080_terem.jpg", None),
    ("12", "Огонь идолов",
     "Кострище из камней и поленьев на плите вместо серой чаши-«улья»; пламя пустого идола 0,6.",
     "l1_evening_1920x1080_idols.jpg", None),
    ("14", "Площадь",
     "Колодец, поленница, коновязь и телега (ниже 0,8 м) вместо пустого плаца.", "l4_evening_1920x1080_plazatop.jpg", None),
    ("25, 26, 29, 31, 32", "Выбор дома",
     "Контур только по стенам и крыше (без машины и плиты); выбранный вдвое толще и пульсирует, родня тонко. "
     "Круг дальности — на земле, как у призрака; «↑» только у выбранного; стрелка ветра 3 px со свечением.",
     "l2_day_1920x1080_select_ui.jpg", (0.3, 0.08, 0.8, 0.55)),
    ("29", "Alt: уровни всех домов", "Щиток-ромб с цифрой Kurale вместо «I ↑».",
     "l2_day_1920x1080_select-alt_ui.jpg", (0.1, 0.08, 0.8, 0.55)),
    ("30", "Износ", "Ослабшие дома темнее и серее, с крупными пятнами копоти — видно без бейджа.",
     "l2_day_1920x1080_damaged_ui.jpg", (0.1, 0.08, 0.8, 0.55)),
    ("27, 28, 33", "Постройка",
     "Свободные участки — мягкие пятна без рамок; призрак тёмный с цветным краем, круг цветом стихии по краю; "
     "связи — знак самой реакции.", "l2_day_1920x1080_place-half_ui.jpg", (0.15, 0.05, 0.75, 0.5)),
    ("45, 52", "Окно идола", "Семь пунктов одного вида: знак стихии её цветом и имя стихии; идол выбран контуром фигуры.",
     "l1_day_1920x1080_idol_ui.jpg", (0.45, 0.2, 1.0, 0.75)),
    ("46", "Рассвет: усиления", "Свой знак у каждого усиления, имя Kurale 22, эффект Fira 17.",
     "l1_dawn_1920x1080_ui.jpg", (0.2, 0.15, 0.8, 0.75)),
    ("47", "Поражение", "Разбивка трат сходится с суммой; «Ещё забег» 26 px.",
     "l1_night_1920x1080_defeat_ui.jpg", (0.15, 0.15, 0.85, 0.85)),
    ("48", "Легенда «?»", "Таблица «знак → имя»: нарисованные метки статусов, износ, уровень; реакции со знаками.",
     "l1_day_1920x1080_legend_ui.jpg", (0.2, 0.0, 0.8, 1.0)),
    ("42, 43", "Каталог, тир II", "Замок — знак, «город 2» — бейджем вместо эмодзи 🔒; «Свистящий столб» без многоточия.",
     "l1_day_1920x1080_tier2_ui.jpg", (0.2, 0.8, 0.85, 1.0)),
    ("36, 37, 38, 53", "Док ночью (1280×720)",
     "Наценка — луна у цены, «Починить дом» — молоток и цена: док 146 и с выбором; «урон 48/с»; «ур. I (дерево)».",
     "l3_night_1280x720_select_ui.jpg", (0.45, 0.78, 1.0, 1.0)),
    ("50", "Панель города", "«Новая улица» янтарным текстом, «Завалить · 15» со знаком частокола.",
     "l4_night_1440x1080_ui.jpg", (0.55, 0.82, 1.0, 1.0)),
    ("2, 51, 55", "День", "Поле днём 100,4 (было 96,8); фонари ворот днём x0,3; окна вечером x0,7.",
     "l1_day_1920x1080_ui.jpg", None),
    ("7, 56", "Ночь босса", "Красная луна и туман вполсилы, у открытых ворот красная дымка; не сепия на весь кадр.",
     "l1_boss_1920x1080_game.jpg", None),
    ("21", "Враг ночью", "Контур тёпло-белый: голубой остался статусу «холод».", "l1_night_1920x1080_enemy.jpg", None),
    ("16, 17, 58", "Пруд вечером", "Плетень — толстые прутья через колья; лодка с банками; перила кладок с двух сторон.",
     "l2_evening_1920x1080_pondclose.jpg", None),
    ("23", "Пруд ночью", "Гладь тёмная: гребни тише, блики огней только у берега.", "l2_night_1920x1080_pondnight.jpg", None),
    ("24", "Ручей днём", "Дно только у берегов, глубина темнее, небо сильнее.", "l1_day_1920x1080_stream.jpg", None),
    ("8", "Город 1 ночью", "Фонари стоят только у открытых входов. Поляна по уровню города не сделана.",
     "l1_night_1920x1080_game.jpg", None),
    ("9", "21:9", "Кадр крупнее, город к середине: частокол 0,69 ширины (было 0,58).", "l4_night_2520x1080_ui.jpg", None),
    ("34, 35", "Портрет (607×1080)", "Тост виден целиком; «Свободно: 0 · домов: 10»; правый край каталога затухает.",
     "l1_day_607x1080_place-toast_ui.jpg", None),
    ("60", "Тост (1440×1080)", "Под шапкой у левого края, по ширине текста — северные ворота открыты.",
     "l4_night_1440x1080_toast_ui.jpg", None),
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
    parts = ["<!DOCTYPE html><html lang='ru'><head><meta charset='utf-8'><title>«Городище»: critique_4 — было/стало</title>",
             "<style>body{background:#101317;color:#e8dfcf;font:16px/1.5 'Fira Sans',sans-serif;max-width:1700px;"
             "margin:auto;padding:24px}h1,h2{font-family:Kurale,serif;color:#f0c27a}h2{margin-top:36px}"
             "img{width:100%;border:1px solid #333;border-radius:6px}.pts{color:#9fb4c0;font-size:14px}"
             ".lbl{display:flex;justify-content:space-around;color:#9fb4c0;font-size:14px}"
             "pre{white-space:pre-wrap;background:#171b21;padding:16px;border-radius:8px}</style></head><body>",
             "<h1>«Городище»: четвёртый проход по critique_4 — было / стало</h1>",
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
    parts.append("<h2>README: цифры и что не сделано</h2><pre>" + html.escape(readme) + "</pre></body></html>")
    TARGET.write_text("\n".join(parts), encoding="utf-8")
    print(TARGET, round(TARGET.stat().st_size / 1e6, 1), "МБ")


if __name__ == "__main__":
    main()
