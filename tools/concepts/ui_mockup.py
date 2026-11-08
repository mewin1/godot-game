"""Макет UI боя поверх концепта арены: тёмное дымчатое стекло, тонкие рамки, русский текст.

Запуск: python3 -I tools/concepts/ui_mockup.py [фон.png] [выход.jpg]
Миниатюры берутся из концептов в new_concept/.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("new_concept")
W, H = 1920, 1080
INTER = "/usr/share/fonts/inter/Inter.ttc"
SERIF = "/usr/share/fonts/noto/NotoSerif-Medium.ttf"
SYMBOL = "/usr/share/fonts/TTF/DejaVuSans.ttf"

TEXT = (236, 230, 218)
MUTED = (158, 160, 152)
AMBER = (232, 176, 92)
RED = (214, 72, 72)
SCHOOL_COLORS = {
    "perun": (150, 120, 255), "svarog": (255, 128, 48), "stribog": (90, 220, 150), "water": (40, 210, 210),
    "ice": (190, 235, 255), "war": (200, 50, 50), "curse": (170, 80, 230), "neutral": (232, 176, 92),
}


def font(size: int, weight: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(INTER, size, index=weight)


def serif(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(SERIF, size)


def symbol(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(SYMBOL, size)


def rounded_mask(size: tuple, radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def glass(canvas: Image.Image, box: tuple, radius: int = 16, alpha: int = 120, border: int = 34,
          accent: tuple | None = None) -> None:
    """Тёмное матовое стекло: размытие фона, тёмная тонировка, тонкая светлая рамка."""
    x0, y0, x1, y1 = box
    size = (x1 - x0, y1 - y0)
    region = canvas.crop(box).filter(ImageFilter.GaussianBlur(22))
    tint = Image.new("RGB", size, (10, 13, 16))
    region = Image.blend(region, tint, alpha / 255)
    canvas.paste(region, (x0, y0), rounded_mask(size, radius))
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    edge = accent + (150,) if accent else (255, 255, 255, border)
    draw.rounded_rectangle(box, radius, outline=edge, width=1)
    draw.line((x0 + radius, y0 + 1, x1 - radius, y0 + 1), fill=(255, 255, 255, border + 18), width=1)
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), overlay).convert("RGB"))


def thumb(path: Path, crop: tuple, size: tuple, radius: int) -> tuple:
    image = Image.open(path).convert("RGB").crop(crop).resize(size, Image.LANCZOS)
    return image, rounded_mask(size, radius)


def circle_thumb(path: Path, crop: tuple, diameter: int) -> tuple:
    image = Image.open(path).convert("RGB").crop(crop).resize((diameter, diameter), Image.LANCZOS)
    mask = Image.new("L", (diameter, diameter), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, diameter - 1, diameter - 1), fill=255)
    return image, mask


BUILD_CROP = (110, 170, 658, 780)
FACE_CROP = (250, 40, 520, 310)
UNIT_CROP = (190, 60, 580, 450)


def draw_heart(draw: ImageDraw.ImageDraw, xy: tuple, size: int, color: tuple) -> None:
    draw.text(xy, "♥", font=symbol(size), fill=color)


def draw_coin(draw: ImageDraw.ImageDraw, xy: tuple, size: int) -> None:
    x, y = xy
    draw.ellipse((x, y, x + size, y + size), fill=(214, 160, 70), outline=(255, 214, 140))
    inner = size // 4
    draw.rectangle((x + inner + 1, y + inner + 1, x + size - inner - 1, y + size - inner - 1), outline=(120, 80, 30))


def main() -> None:
    background = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "arena" / "arena_battle_22.png"
    target = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "04_battle_ui.jpg"
    canvas = Image.open(background).convert("RGB").resize((W, H), Image.LANCZOS)

    # Лёгкая виньетка, чтобы края под панелями были темнее.
    vignette = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vignette).ellipse((-300, -250, W + 300, H + 250), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(160))
    canvas = Image.composite(canvas, Image.new("RGB", (W, H), (4, 6, 8)), vignette)

    # 1. Раунд и темп — слева сверху.
    glass(canvas, (24, 20, 420, 72), radius=26)
    draw = ImageDraw.Draw(canvas)
    draw.text((48, 30), "Раунд 7", font=serif(24), fill=AMBER)
    draw.text((160, 37), "бой  ·  0:39", font=font(17), fill=TEXT)
    for i, label in enumerate(("II", "×1", "×2")):
        bx = 292 + i * 40
        active = label == "×1"
        draw.rounded_rectangle((bx, 32, bx + 32, 60), 9, fill=(232, 176, 92, 255) if active else None,
                               outline=(255, 255, 255) if not active else None, width=1)
        draw.text((bx + 16, 46), label, font=font(13, 1), fill=(20, 16, 10) if active else MUTED, anchor="mm")

    # 2. Игроки — по центру сверху.
    players = [("Вы", "baba_yaga", 40, True), ("Бот 1", "babushka", 38, False), ("Бот 2", "cosmonaut", 31, False),
               ("Бот 3", "gorynych", 27, False), ("Бот 4", "vasilisa", 12, False)]
    chip_w, gap = 132, 8
    start = (W - (len(players) * chip_w + (len(players) - 1) * gap)) // 2
    for i, (name, hero, hp, me) in enumerate(players):
        x = start + i * (chip_w + gap)
        glass(canvas, (x, 20, x + chip_w, 68), radius=24, accent=AMBER if me else None)
        image, mask = circle_thumb(ROOT / "heroes" / f"{hero}_16.png", FACE_CROP, 36)
        canvas.paste(image, (x + 7, 26), mask)
        draw = ImageDraw.Draw(canvas)
        draw.text((x + 52, 27), name, font=font(13, 1 if me else 0), fill=AMBER if me else TEXT)
        draw_heart(draw, (x + 52, 44), 13, RED if hp > 15 else (255, 110, 90))
        draw.text((x + 68, 44), str(hp), font=font(13), fill=TEXT)

    # 3. Ресурсы — справа сверху.
    glass(canvas, (W - 330, 20, W - 24, 72), radius=26)
    draw = ImageDraw.Draw(canvas)
    draw_heart(draw, (W - 306, 31), 22, RED)
    draw.text((W - 278, 31), "40", font=font(22, 1), fill=TEXT)
    draw_coin(draw, (W - 216, 35), 22)
    draw.text((W - 186, 31), "46", font=font(22, 1), fill=AMBER)
    draw.text((W - 146, 37), "+10 / раунд", font=font(14), fill=MUTED)

    # 4. Лавка и армия — тонкая колонка слева.
    panel = (24, 92, 300, 780)
    glass(canvas, panel, radius=18)
    draw = ImageDraw.Draw(canvas)
    draw.text((44, 108), "Лавка", font=serif(22), fill=TEXT)
    draw.rounded_rectangle((188, 110, 282, 136), 13, outline=(255, 255, 255), width=1)
    draw.text((235, 123), "обновить · 2", font=font(12), fill=MUTED, anchor="mm")
    shop = [("thunder", "Грозовой столб", "II", "perun", 6), ("brazier", "Жаровня", "I", "svarog", 3),
            ("rime", "Иней", "I", "ice", 3), ("water", "Водяной желоб", "II", "water", 6),
            ("doom", "Чёрный обелиск", "III", "curse", 10), ("bolt", "Самострел", "I", "war", 3)]
    card_w, card_h = 122, 150
    for i, (bid, name, tier, school, price) in enumerate(shop):
        cx = 40 + (i % 2) * (card_w + 12)
        cy = 150 + (i // 2) * (card_h + 12)
        glass(canvas, (cx, cy, cx + card_w, cy + card_h), radius=12, alpha=90)
        image, mask = thumb(ROOT / "buildings" / f"{bid}_16.png", BUILD_CROP, (card_w - 8, 92), 9)
        canvas.paste(image, (cx + 4, cy + 4), mask)
        draw = ImageDraw.Draw(canvas)
        color = SCHOOL_COLORS[school]
        draw.ellipse((cx + 10, cy + 10, cx + 18, cy + 18), fill=color)
        draw.text((cx + card_w - 10, cy + 10), tier, font=font(12, 1), fill=TEXT, anchor="ra")
        draw.text((cx + 8, cy + 102), name, font=font(12), fill=TEXT)
        draw_coin(draw, (cx + 8, cy + 125), 14)
        draw.text((cx + 27, cy + 124), str(price), font=font(13, 1), fill=AMBER)
    draw = ImageDraw.Draw(canvas)
    draw.line((40, 650, 284, 650), fill=(255, 255, 255), width=1)
    draw.text((44, 662), "Армия", font=serif(18), fill=TEXT)
    army = [("send_unit", "Копейщики ×6", 4), ("knight", "Витязи ×2", 7)]
    for i, (uid, name, price) in enumerate(army):
        ry = 696 + i * 40
        image, mask = circle_thumb(ROOT / "units" / f"{uid}_16.png", UNIT_CROP, 32)
        canvas.paste(image, (44, ry), mask)
        draw = ImageDraw.Draw(canvas)
        draw.text((86, ry + 7), name, font=font(13), fill=TEXT)
        draw_coin(draw, (240, ry + 9), 14)
        draw.text((258, ry + 7), str(price), font=font(13, 1), fill=AMBER)

    # 5. Герой и навык — слева снизу.
    glass(canvas, (24, H - 116, 300, H - 24), radius=46)
    image, mask = circle_thumb(ROOT / "heroes" / "baba_yaga_16.png", FACE_CROP, 76)
    canvas.paste(image, (32, H - 108), mask)
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((31, H - 109, 109, H - 31), outline=AMBER, width=2)
    draw.text((124, H - 102), "Баба-Яга", font=serif(18), fill=TEXT)
    draw.rounded_rectangle((124, H - 70, 284, H - 38), 16, fill=(232, 176, 92))
    draw.text((204, H - 54), "Варево  ·  Q", font=font(14, 1), fill=(24, 18, 10), anchor="mm")

    # 6. Идолы и резерв — тонкая полоса снизу по центру.
    idols = [("idol_perun", "Перун"), ("idol_svarog", "Сварог"), ("idol_empty", "пусто")]
    reserve = ["spark", "brazier", "dew", None, None, None, None]
    bar_x0, bar_x1 = 560, 1500
    glass(canvas, (bar_x0, H - 108, bar_x1, H - 24), radius=22)
    draw = ImageDraw.Draw(canvas)
    for i, (iid, label) in enumerate(idols):
        ix = bar_x0 + 18 + i * 86
        image, mask = circle_thumb(ROOT / "idols" / f"{iid}_16.png", (200, 120, 570, 490), 56)
        canvas.paste(image, (ix + 8, H - 102), mask)
        draw = ImageDraw.Draw(canvas)
        ring = AMBER if iid != "idol_empty" else (110, 110, 110)
        draw.ellipse((ix + 7, H - 103, ix + 65, H - 45), outline=ring, width=1)
        draw.text((ix + 36, H - 40), label, font=font(11), fill=MUTED, anchor="mt")
    divider = bar_x0 + 18 + 3 * 86 + 6
    draw.line((divider, H - 96, divider, H - 36), fill=(255, 255, 255), width=1)
    draw.text((divider + 18, H - 101), "Резерв", font=font(11), fill=MUTED)
    for i, bid in enumerate(reserve):
        sx = divider + 18 + i * 92
        box = (sx, H - 84, sx + 80, H - 34)
        draw.rounded_rectangle(box, 10, outline=(255, 255, 255), width=1)
        if bid:
            image, mask = thumb(ROOT / "buildings" / f"{bid}_16.png", (150, 330, 618, 622), (78, 48), 9)
            canvas.paste(image, (sx + 1, H - 83), mask)
            draw = ImageDraw.Draw(canvas)

    # 7. Подсказка над башней на поле.
    tip = (1440, 330, 1730, 430)
    glass(canvas, tip, radius=14, accent=SCHOOL_COLORS["curse"])
    draw = ImageDraw.Draw(canvas)
    draw.text((1458, 342), "Чёрный обелиск", font=serif(17), fill=TEXT)
    draw.text((1712, 346), "III", font=font(13, 1), fill=SCHOOL_COLORS["curse"], anchor="ra")
    draw.text((1458, 372), "Порча · финишер", font=font(12), fill=SCHOOL_COLORS["curse"])
    draw.text((1458, 392), "Взрыв через 2 с; лёд усиливает урон", font=font(12), fill=MUTED)
    draw.line((1430, 432, 1404, 468), fill=(170, 80, 230), width=1)

    canvas.save(target, quality=92)
    print(target)


if __name__ == "__main__":
    main()
