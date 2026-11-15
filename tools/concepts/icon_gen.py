"""Иконки «Городища» одной семьи (critique_4 п. 28, 45, 46, 48 и хвосты critique_3: роли, знаки богов, умения).

Генерация (ComfyUI с Z-Image на :8188):
    python3 -I tools/concepts/icon_gen.py gen [id ...] [--seed N]   → new_concept/icons/<id>_<seed>.png (768×768)
Сборка в игру:
    python3 -I tools/concepts/icon_gen.py build [--seed N]           → assets/ui/ritual/icons/<id>.png (128×128, RGBA)
Манера: белая резная эмблема-силуэт на чёрном; в игре — маска альфы, цвет задаёт интерфейс (одна семья знаков).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from redesign_gen import generate  # noqa: E402

OUT = Path("new_concept/icons")
GAME = Path("assets/ui/ritual/icons")

STYLE = (
    "Flat game UI icon: one bold simple solid white emblem silhouette centered on a pure black background, "
    "like a carved Slavic folk woodcut stamp, thick clean shapes, no thin lines, no outline, no shading, no gradient, "
    "no texture, no frame, no circle around it, high contrast, readable at 24 pixels, big margins. "
    "No text, no letters, no numbers, no watermark."
)

ICONS = [
    # Реакции стихий (значок на связи домов и в легенде).
    ("rx_steam", "three wavy curls of steam rising from a water droplet"),
    ("rx_chain", "a lightning bolt jumping between three small round dots in a chain"),
    ("rx_conservation", "a skull inside a square block of ice"),
    ("rx_execute", "a heavy axe blade striking down"),
    ("rx_freeze", "a six-pointed snowflake inside a water droplet"),
    ("rx_infection", "a water droplet with a small skull inside it"),
    ("rx_melt", "an icicle melting into falling drops"),
    ("rx_roast", "a flame with a lightning bolt inside it"),
    ("rx_shatter", "an ice crystal broken into sharp shards flying apart"),
    ("rx_surge", "a big curling wave pushing to the left"),
    ("rx_blizzard", "a big snowflake blown to the right by three horizontal wind lines on its left"),
    ("rx_wildfire", "a flame blown sideways to the right by three horizontal wind lines on its left"),
    # Усиления рассвета (свои значки вместо одного амулета).
    ("boon_merchants", "a merchant coin purse tied with a string"),
    ("boon_tar", "a wooden barrel with dripping thick tar"),
    ("boon_rain_bowl", "a round bowl with rain drops falling into it"),
    ("boon_charm", "a Slavic protective amulet charm, a ring with a solar cross inside"),
    ("boon_stakes", "three sharpened wooden stakes stuck in the ground"),
    ("boon_craft", "a crossed hammer and chisel"),
    ("boon_strong_gate", "a small wooden gate tower with a tent roof and a shield on it"),
    ("boon_carpenters", "a carpenter axe crossed with a saw"),
    ("boon_keen_eye", "a single wide open eye with rays around it"),
    ("boon_vigor", "a strong fist raised up"),
    # Знаки богов, упрощённые для 24 px.
    ("god_war", "two crossed swords"),
    ("god_svarog", "a single big flame"),
    ("god_ice", "a six-pointed snowflake"),
    ("god_water", "a single water droplet"),
    ("god_stribog", "three horizontal curved wind gust lines curling at the ends, nothing else"),
    ("god_perun", "a single zigzag lightning bolt"),
    ("god_curse", "a horned skull"),
    # Роли домов.
    ("role_single", "an arrow with a crossbow bolt tip pointing up-right"),
    ("role_area", "an explosion burst star"),
    ("role_control", "a heavy iron chain of three big oval links, diagonal"),
    ("role_status", "a hand sprinkling three drops"),
    ("role_finisher", "a heavy executioner axe"),
    # Замок запертого тира в каталоге (вместо эмодзи 🔒).
    ("lock", "a closed heavy padlock"),
    # Умения героев.
    ("skill_ilya", "a heavy spiked mace"),
    ("skill_solovei", "a whistle blowing a strong gust of air"),
    ("skill_yaga", "a witch broom crossed with a mortar pestle"),
]


def main() -> None:
    args = sys.argv[1:]
    seed = 41
    if "--seed" in args:
        seed = int(args[args.index("--seed") + 1])
        del args[args.index("--seed"):args.index("--seed") + 2]
    mode = args.pop(0) if args else "gen"
    if mode == "gen":
        for icon_id, text in ICONS:
            if args and icon_id not in args:
                continue
            generate(f"Subject: {text}. {STYLE}", 768, 768, seed, OUT / f"{icon_id}_{seed}.png")
    elif mode == "build":
        build(seed, args)


# Удачные кадры с другим сидом (первые варианты: бегущий человек, повтор огня и капли).
PICKED = {"role_control": 45, "rx_infection": 43, "rx_blizzard": 43, "rx_wildfire": 42, "god_stribog": 42}


def build(seed: int, only: list) -> None:
    """Белое на чёрном → белый знак с альфой по яркости, без рамки у края кадра, обрезка по знаку,
    128×128 с полем."""
    from PIL import Image, ImageDraw, ImageFilter, ImageOps

    GAME.mkdir(parents=True, exist_ok=True)
    for icon_id, _ in ICONS:
        if only and icon_id not in only:
            continue
        source = OUT / f"{icon_id}_{PICKED.get(icon_id, seed)}.png"
        if not source.exists():
            print(f"{source}: нет файла")
            continue
        gray = ImageOps.grayscale(Image.open(source))
        # Порог с мягким краем: фон в ноль, знак в единицу.
        alpha = gray.point(lambda v: 0 if v < 70 else (255 if v > 150 else int((v - 70) * 255 / 80)))
        # Рамка-плашка, которую модель рисует у края кадра: связная область у краевой полосы, которая
        # тянется почти на весь кадр, — в ноль (знак у края, как шар пара, остаётся).
        binary = alpha.point(lambda v: 255 if v > 40 else 0)
        width, height = binary.size
        band = int(width * 0.09)
        seeds = [(x, y) for x in range(0, width, 3) for y in list(range(0, band, 3)) + list(range(height - band, height, 3))]
        seeds += [(x, y) for y in range(0, height, 3) for x in list(range(0, band, 3)) + list(range(width - band, width, 3))]
        for point in seeds:
            if binary.getpixel(point) != 255:
                continue
            ImageDraw.floodfill(binary, point, 100)
            region = binary.point(lambda v: 255 if v == 100 else 0)
            left, top, right, bottom = region.getbbox()
            large = right - left > width * 0.75 and bottom - top > height * 0.75
            binary = Image.composite(Image.new("L", binary.size, 128 if large else 200), binary, region)
        frame = binary.point(lambda v: 255 if v == 128 else 0).filter(ImageFilter.MaxFilter(5))
        alpha = Image.composite(Image.new("L", alpha.size, 0), alpha, frame)
        alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))
        box = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
        if box is None:
            print(f"{icon_id}: пусто")
            continue
        alpha = alpha.crop(box)
        side = int(max(alpha.size) * 1.12)
        square = Image.new("L", (side, side), 0)
        square.paste(alpha, ((side - alpha.width) // 2, (side - alpha.height) // 2))
        mask = square.resize((128, 128), Image.LANCZOS)
        icon = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
        icon.putalpha(mask)
        icon.save(GAME / f"{icon_id}.png")
        print(f"{GAME / icon_id}.png")


if __name__ == "__main__":
    main()
