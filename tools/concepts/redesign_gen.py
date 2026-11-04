"""Концепты редизайна (славянский нуар): по картинке на элемент + сборка листов.

Генерация: python3 -I tools/concepts/redesign_gen.py gen <группа|all> [id ...] [--seed N]
Листы:     python3 -I tools/concepts/redesign_gen.py sheet <группа|all> [--seed N]
Группы: heroes, units, buildings, ui. ComfyUI должен быть запущен на :8188.
Пачка 1 (согласованная детализация): герои seed 3, юниты 4, постройки 5.
Пачка 2 (свои палитры, женские юниты, стиль богов, стеклянный UI): seed 6;
копейщик взят из seed 12, знахарка из 15, UI — seed 11 и 7.
Пачка 3 (мрачнее, уровни I–III, идолы богов, арена): seed 16; леший, горыныч, илья, яга, разведчица — из 17;
терем — terem_5 (пачка 1); арена — arena_22 и arena_battle_22; UI собирает tools/concepts/ui_mockup.py.
"""
import json
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from zimage_gen import URL, post, workflow  # noqa: E402

OUT = Path("new_concept")

# Свет и манера общие; цвета одежды и материалов задаёт каждый элемент сам.
NOIR = (
    "Art style: painterly stylized 3D hero shooter render with visible brushstroke texture, angular stylized features, "
    "semi-realistic stylized proportions, dramatic chiaroscuro, "
    "hand-painted PBR textures, moderate level of detail but clean readable silhouette and no clutter. "
    "Slavic folklore noir mood: night scene lit by an off-screen warm amber light from one side, "
    "crisp shadows, colored rim light; the subject's own colors stay saturated and clearly readable against the dark. "
    "Only the objects described in the subject: no lanterns, lamps or torches unless described. "
    "No text, no letters, no logo, no watermark."
)

FIGURE_DETAIL = (
    "Details: visible fabric folds, stitched seams, worn edges, Slavic embroidery on the clothing. "
    "Expressive detailed face with strong character, dramatic pose. "
    "Clothing colors exactly as described, not black, but muted and desaturated noir tones: each costume keeps its own hue, "
    "darkened, dusty and weathered, deep shadows cover half of the figure. "
    "Mature grounded stylization like a dark fantasy hero shooter, not cartoon, not Pixar, not chibi, realistic proportions. "
    "Slightly more detail: worn fabric texture, scratches, small trinkets and charms. "
)

BACKDROP = "plain dark charcoal background with a faint teal gradient, soft ground shadow. "

CHAR = (
    "Hero character concept render for a 3D model: one single character, full body from head to feet, "
    "centered, front three-quarter view, whole figure visible with margin, " + BACKDROP + FIGURE_DETAIL
)

HERO_CREATURE = (
    "Hero creature concept render for a 3D model: one single creature, whole body from head to feet, centered, "
    "front three-quarter view, whole figure visible with margin, it wears NO clothes, NO robe, NO belts, NO armor. " + BACKDROP +
    "Mature grounded dark fantasy stylization, not cartoon; muted desaturated noir tones, deep shadows; "
    "detailed hand-painted surface: bark, moss, scales, scratches. "
)

UNIT = (
    "Enemy unit concept render for a 3D tower defense game: one single figure, full body from head to feet, "
    "centered, front three-quarter view, " + BACKDROP + FIGURE_DETAIL
)

CREATURE = (
    "Small enemy creature concept render for a 3D tower defense game: one single creature, whole body visible, "
    "centered, front three-quarter view, it is NOT a human and wears no clothes or armor, " + BACKDROP +
    "Details: expressive face, readable silhouette, hand-painted surface texture. "
)

BUILD = (
    "Isometric 3D game asset concept render: one single object placed directly on a flat square dark cobblestone tile, "
    "three-quarter top-down view, centered, whole object visible with margin, "
    "plain dark charcoal background with a faint teal gradient. "
    "The object stands directly on the tile with no pedestal, no column, no castle walls and no battlements. "
    "Details: weathered edges, chipped surfaces, moss in cracks. "
)

TIERS = {
    1: "Tier I humble starter version: small and low, rough raw materials, simple crude construction, faint glow, plain tile. ",
    2: "Tier II improved version: medium size, sturdier crafted construction with metal fittings and carvings, brighter glow, "
       "the tile has a carved stone border. ",
    3: "Tier III legendary version: large, tall and imposing, ornate with gold or silver trim and glowing runes, "
       "intense glow with floating magic particles and an aura, the tile has a gilded glowing rune border. ",
}

# Каждый бог/стихия: свой цвет свечения, материал и язык форм + знак на плите.
SCHOOLS = {
    "perun": "Perun the thunder god style: dark oak and polished silver steel with gold inlay, electric blue-violet glow, "
             "sharp jagged zigzag lightning shapes, axe and thunder wheel motifs. "
             "A glowing electric blue-violet lightning sigil is carved into the stone tile. ",
    "svarog": "Svarog the fire and forge god style: red brick, blackened bronze and hot copper, orange-red fire glow, "
              "heavy rounded domed shapes, sun disk and hammer motifs. "
              "A glowing orange sun sigil is carved into the stone tile. ",
    "stribog": "Stribog the wind god style: pale bleached birch wood, white canvas and feathers, soft jade-green glow, "
               "light airy spiral curved shapes, ribbons fluttering. "
               "A glowing jade-green spiral wind sigil is carved into the stone tile. ",
    "water": "water spirit style: wet blue-grey stone and dark driftwood, deep turquoise glow, smooth flowing wave shapes, "
             "fish scale and wave motifs, dripping water and puddles. "
             "A glowing turquoise wave sigil is carved into the stone tile. ",
    "ice": "Morozko frost style: frosted white wood and pale cyan crystal ice, cold white-cyan glow, sharp angular icicle shapes, "
           "snowflake motifs, snow caps. "
           "A glowing pale cyan snowflake sigil is carved into the stone tile. ",
    "war": "war machine style, no magic: dark riveted iron, old oak beams, crimson cloth banners, gears and chains, "
           "practical heavy blocky shapes. "
           "A painted crimson crossed-swords sign on the stone tile. ",
    "curse": "Chernobog curse style: black twisted dead wood and obsidian, sickly purple and toxic green glow, "
             "crooked asymmetric thorny shapes, bones, skulls and crow feathers. "
             "A glowing purple evil eye sigil is carved into the stone tile. ",
    "neutral": "neutral style: polished oak and brass with warm golden glow, Slavic carved ornament. ",
}

HEROES = [
    ("baba_yaga", "Баба-Яга", "an old Slavic forest witch Baba Yaga, hunched, long hooked nose, wild grey hair under a rust-orange patterned headscarf, "
     "patchwork coat of moss green and rust brown rags, bone bead necklace, standing in a large wooden mortar, "
     "holding a long plain wooden pestle like a staff, nothing burning on it, glowing amber eyes"),
    ("domovoy", "Домовой", "a tiny house spirit Domovoy, knee-high, round body hidden in a huge shaggy straw-blond beard, small bright eyes, "
     "felt boots, homespun mustard-yellow shirt with brick-red embroidery, holding a small brass oil lamp and a big ring of old keys"),
    ("cosmonaut", "Космонавт", "a retro 1930s dieselpunk cosmonaut, bulky rounded riveted cream-white spacesuit with bright red panels, "
     "round glass fishbowl helmet, polished brass oxygen tanks on the back, brass collar ring, folk ornament patch, heroic stance"),
    ("ilya", "Илья Муромец", "a giant Slavic bogatyr warrior Ilya Muromets, massive broad build, golden pointed helmet, long dark beard, "
     "shining silver scale armor over a deep royal blue kaftan, long royal blue cloak with gold embroidery covering most of the figure, the outfit is clearly blue and silver, resting a huge iron spiked mace on his shoulder"),
    ("leshy", "Леший", "a tall forest spirit Leshy made entirely of living wood, not wearing clothes: brown bark body, bright moss green beard and shoulders, "
     "branch antlers with autumn orange leaves, long thin branch arms, two glowing yellow-green eyes, mushrooms growing on him", HERO_CREATURE),
    ("babushka", "Бабушка у подъезда", "a stout stern old Slavic grandmother, bright orange headscarf with big flower print, plum purple padded coat, "
     "grey felt boots, arms crossed, a wicker basket of pies covered with a white embroidered towel on her arm, suspicious squinting look"),
    ("solovey", "Соловей-Разбойник", "a lean Slavic forest bandit Solovey the Robber, wild grin, whistling with two fingers in his mouth, "
     "brown fur hat with a long red feather, forest green ragged caftan, tan leather trousers, red sash, curved knife, crouching ready to jump"),
    ("gorynych", "Змей Горыныч", "a three-headed Slavic dragon Zmey Gorynych, no harness and no clothes, compact chunky body, "
     "emerald green scales with a golden yellow belly, three long necks with horned heads, embers glowing in throats, "
     "smoke from nostrils, folded leathery wings with red membranes, heavy clawed feet", HERO_CREATURE),
    ("koschei", "Кощей Бессмертный", "Koschei the Deathless, very tall and skeletally thin undead tsar, bone-white skull-like face with glowing green eyes, "
     "tarnished gold spiked crown, long deep purple royal robe with gold trim and high collar, bony hands, a golden needle pendant"),
    ("skomorokh", "Скоморох", "a Slavic jester Skomorokh, harlequin caftan of bright red and yellow diamonds, soft pointed two-tailed cap with bells, "
     "white half-mask, acrobatic pose, holding a small wooden wheel of fortune with painted segments, ribbons on sleeves"),
    ("vasilisa", "Василиса Премудрая", "Vasilisa the Wise, a calm slender young woman, tall white and silver pearl kokoshnik headdress, very long golden braid, "
     "long sky blue sarafan with silver ornament, white sleeves, holding an open glowing old book, a small green frog on her shoulder"),
]

UNITS = [
    ("basic", "Ополченец", "an old short stout bearded peasant militiaman, faded olive quilted jacket, brown fur cap with earflaps, "
     "bast shoes with white leg wraps, tired face, holding a wooden pitchfork with both hands"),
    ("send_unit", "Копейщик", "a tall lean young Slavic spearman, bright red caftan over chainmail, conical steel helmet, "
     "round wooden shield painted with a black sun, very long spear upright with a plain cold steel tip, nothing burning"),
    ("fast", "Разведчица", "a slim young woman scout, long ochre-yellow hooded cloak and ochre tunic as the main color, auburn braid, light brown leather gear, "
     "short bow on her back, wide mid-run dynamic pose leaning forward"),
    ("armored", "Латник", "a hulking huge armored warrior, very wide and bulky, cold blue-grey steel lamellar plate armor, "
     "helmet with a full steel face mask, massive pauldrons, big two-handed battle axe"),
    ("knight", "Витязь со щитом", "a Slavic knight vityaz, golden pointed helmet with chainmail aventail, white cloak with blue trim, "
     "huge red teardrop shield with a golden sun sign held in front, short sword"),
    ("healer", "Знахарка", "a young village herbalist woman, white linen dress with red embroidery, wreath of wildflowers on her head, "
     "bunches of dried herbs on the belt, holding a big bundle of green healing herbs in one hand and a small clay bowl of ointment in the other, empty-handed otherwise, no staff, no fire, kind face"),
    ("courier", "Гонец", "a skinny teenage boy messenger, short emerald green caftan, cap with a long feather, leather scroll tube on the back, "
     "brass horn at the belt, sprinting pose"),
    ("stealth", "Лазутчица", "a stealthy woman spy wrapped in a deep violet hooded cloak, dark mask over the lower face, sharp eyes, "
     "two short curved knives, low sneaking crouch, half dissolving into shadow"),
    ("bat", "Нетопырь", "a giant night bat beast: leathery wide wings spread, furry dark body, huge pointed ears, "
     "glowing red eyes, small fangs, flying in the air", CREATURE),
    ("kolobok", "Колобок", "Kolobok, a single round living loaf of bread, golden-brown baked crust with cracks and flour dust, "
     "cheeky mischievous face on the bread itself, tiny stubby legs, no body other than the bread ball", CREATURE),
    ("spirit", "Дух", "a floating elemental ghost spirit with no legs: translucent pale teal wispy body, trailing smoke tail, "
     "hollow glowing eyes, ragged shroud fading into mist, small orbs of fire, water, ice and lightning circling it", CREATURE),
    ("robber", "Разбойник", "a fat pot-bellied forest robber, red bandana, torn blue-white striped shirt, patched brown trousers, "
     "heavy knotted wooden club, sack of stolen gold coins over the shoulder, sly gap-toothed grin"),
    ("boss", "Осадный воевода", "a huge siege warlord boss, twice as big as soldiers, dark plate armor with gold trim, "
     "brown bear fur cloak, horned helmet, giant iron war hammer, battle-scarred face"),
]

# Пачка 2: нетопырь, колобок и дух автору понравились — их не перерисовываем (копируются из seed 4).
KEEP_UNITS = {"bat", "kolobok", "spirit"}

# (id, подпись, описание, школа, уровень). Уровни — из data/towers/*.tres.
BUILDINGS = [
    ("spark", "Искровик · I", "an oak stump with a silver coil wound around a crooked iron rod on top, small sparks", "perun", 1),
    ("thunder", "Грозовой столб · II", "a carved oak pillar with a big thunder wheel symbol, topped with a forked silver lightning rod, "
     "crackling electric arcs", "perun", 2),
    ("storm", "Грозовая решётка · III", "a grand steel lattice spire with three tall silver electrode spikes and a hovering storm orb, "
     "electric arcs jumping between them", "perun", 3),
    ("brazier", "Жаровня · I", "a brick pedestal with a bronze fire bowl on three legs, flames", "svarog", 1),
    ("furnace", "Горнило · II", "a round brick blacksmith furnace like a beehive, glowing open mouth, chimney with sparks, "
     "anvil and hammer beside it", "svarog", 2),
    ("cinder", "Огненный венец · III", "a huge crown of seven tall bronze spikes around a blazing fire pit, each spike tip burning", "svarog", 3),
    ("wind", "Ветродуй · I", "a little birch windmill hut with four canvas sail blades and a weather vane", "stribog", 1),
    ("gale", "Свистящий столб · II", "a tall birch pole with many bone whistles and long white and green ribbons streaming in the wind", "stribog", 2),
    ("vortex", "Ветряной круг · III", "a circle of tall birch posts with feather fans around a big swirling wind tornado", "stribog", 3),
    ("dew", "Росник · I", "a wet boulder with a glass-like water lily flower collecting glowing dew drops", "water", 1),
    ("water", "Водяной желоб · II", "a driftwood water trough on stilts with a turning water wheel and a carved fish-head spout pouring water", "water", 2),
    ("rain", "Дождевой круг · III", "a round open gazebo with a dark rain cloud above its roof, rain falling into a round pool", "water", 3),
    ("rime", "Иней · I", "a roadside shrine box covered in thick hoarfrost, icicles hanging from its roof", "ice", 1),
    ("glacier", "Ледник · II", "a jagged chunk of glacier ice with a carved white wooden door frame set into it", "ice", 2),
    ("ice_lance", "Ледяное копьё · III", "a heavy frosted ballista loaded with a long jagged ice spear", "ice", 3),
    ("bolt", "Самострел · I", "a crossbow on a rotating log stand, heavy bolt loaded, crimson pennant", "war", 1),
    ("war_engine", "Осадный станок · II", "a siege catapult on wheels with a long throwing arm, ropes, chains and an iron counterweight", "war", 2),
    ("war_rocket", "Ракетница · III", "an armored war wagon with a big angled rack of many fire-arrow rockets", "war", 3),
    ("hex", "Чёрная метка · I", "a crooked dead-wood post with a bone mask nailed to it, crow feathers, a glowing hand mark", "curse", 1),
    ("plague", "Моровой колокол · II", "a twisted dead-wood gallows frame with a cracked bell, miasma pouring out", "curse", 2),
    ("doom", "Чёрный обелиск · III", "a tall obsidian obelisk with carved runes and a glowing crack down its middle, thorns at its base", "curse", 3),
    ("beacon", "Маяк · I", "a tall oak beacon on four stilts with a big brass searchlight casting a warm golden light beam", "neutral", 1),
]

# Идол: пустой и пробуждённый каждым богом (заговоры data/rites, god = school).
IDOL_BASE = ("a pagan wooden idol: a single tall carved log pillar with a stern bearded face carved near the top, round flat hat, "
             "arms carved flat on the trunk, standing in a low ring of stones")
IDOLS = [
    ("idol_empty", "Идол · пустой", IDOL_BASE + ", dormant, plain weathered wood, no glow", "neutral"),
    ("idol_perun", "Идол · Перун", IDOL_BASE + ", awakened by Perun: wood turned dark with silver inlay, eyes and carved lines "
     "glowing blue-violet, small lightning arcs crawl over it, storm clouds swirl above", "perun"),
    ("idol_svarog", "Идол · Сварог", IDOL_BASE + ", awakened by Svarog: wood charred black with glowing molten orange cracks, "
     "eyes burning, embers rising, a sun disk halo behind the head", "svarog"),
    ("idol_stribog", "Идол · Стрибог", IDOL_BASE + ", awakened by Stribog: wood bleached white like birch, glowing jade-green eyes "
     "and spiral carvings, ribbons and feathers whirling around it in the wind", "stribog"),
    ("idol_water", "Идол · Вода", IDOL_BASE + ", awakened by water spirits: wood dark and wet with turquoise glowing lines, "
     "water streaming down from its eyes into a glowing pool, fish scales on the trunk", "water"),
    ("idol_ice", "Идол · Мороз", IDOL_BASE + ", awakened by Morozko: wood covered in hoarfrost and ice crystals, "
     "glowing pale cyan eyes, snowflakes swirling, icicle crown", "ice"),
    ("idol_war", "Идол · Война", IDOL_BASE + ", awakened for war: iron-bound with riveted plates, crimson war paint, "
     "swords and shields nailed around it, crimson banners", "war"),
    ("idol_curse", "Идол · Порча", IDOL_BASE + ", awakened by Chernobog: wood rotten black with purple glowing eyes, "
     "toxic green ooze, crows perched on it, bones at its base", "curse"),
]

TEREM_SOURCE = OUT / "buildings" / "terem_5.png"  # тёмный терем из пачки 1 — автору понравился

ARENA_PROMPT = (
    "Cinematic in-game screenshot of a premium PC 3D tower defense game at night, camera close above the arena at a 55 degree angle, "
    "the square courtyard fills most of the 16:9 frame. "
    "The courtyard floor is a grid of square dark cobblestone building tiles separated by thin seams. "
    "One single serpentine dirt road snakes through it like the letter S: it enters at the top left from a dark forest gate "
    "with glowing eyes in the thicket, runs down the left side, makes a U-turn at the bottom, runs up through the middle, "
    "makes a U-turn at the top, runs down the right side and ends at the bottom right at a tall dark wooden terem house "
    "with warm glowing windows and an onion roof. "
    "Low dark log palisade walls with carved posts frame the courtyard, iron braziers burning at the four corners, "
    "a few small lanterns along the road. Outside the walls: dark pine forest, birches, mossy rocks, mist. "
    "Cold teal moonlight, warm amber firelight pools, deep noir shadows, volumetric fog, painterly stylized 3D, "
    "rich but clean detail, Slavic folklore noir mood. The tiles are empty. No text, no UI, no letters."
)

UI_PROMPT = (
    "Full-bleed in-game screenshot of a modern 3D tower defense battle with a sleek HUD, 16:9, edge to edge, no border, no device frame. "
    "The whole background is a beautiful 3D night battlefield seen from above at an angle: soft volumetric light, warm amber lamps, "
    "a winding dirt road through a dark pine forest, small wooden towers beside it, a glowing wooden terem house at the end of the road. "
    "HUD style: soft translucent frosted glass panels with strong background blur, large rounded corners, thin light 1px borders, "
    "subtle inner glow, the glass is dark smoked tinted glass like black sunglasses (not milky, not white), "
    "warm amber highlight buttons and gold numbers, tiny blood red accents, cinematic noir mood, "
    "elegant modern minimal typography and clean line icons, a very thin Slavic ornament line as decoration. "
    "Layout: a floating glass panel on the left with six rounded building cards in a 2-column grid and three army cards; "
    "a slim floating glass top bar with a round hero portrait, gold counter, health counter and round timer; "
    "three round glass idol slots floating under the battlefield; a row of seven small rounded glass reserve slots along the bottom. "
    "Clean, airy, premium, readable."
)

GROUPS = {
    "heroes": (HEROES, CHAR),
    "units": (UNITS, UNIT),
    "buildings": (BUILDINGS, BUILD),
    "idols": (IDOLS, BUILD),
}


def prompt_for(group: str, item: tuple) -> str:
    framing = GROUPS[group][1]
    extra = ""
    if len(item) > 3:
        if item[3] in SCHOOLS:
            extra = SCHOOLS[item[3]]
        else:
            framing = item[3]
    if len(item) > 4:
        extra = TIERS[item[4]] + extra
    return f"{framing}Subject: {item[2]}. {extra}{NOIR}"


def generate(prompt: str, width: int, height: int, seed: int, target: Path) -> None:
    started = time.time()
    prompt_id = post("/prompt", {"prompt": workflow(prompt, width, height, seed, "concepts/redesign")})["prompt_id"]
    while True:
        history = json.load(urllib.request.urlopen(f"{URL}/history/{prompt_id}"))
        if prompt_id in history:
            break
        time.sleep(0.5)
    entry = history[prompt_id]
    if entry["status"].get("status_str") != "success":
        print(f"{target.name}: ОШИБКА", json.dumps(entry["status"])[:400])
        return
    image = entry["outputs"]["10"]["images"][0]
    query = f"filename={image['filename']}&subfolder={image['subfolder']}&type=output"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(urllib.request.urlopen(f"{URL}/view?{query}").read())
    print(f"{target} ({time.time() - started:.0f} с)")


def sheet(group: str, seed: int) -> None:
    from PIL import Image, ImageDraw, ImageFont

    items = GROUPS[group][0]
    cols = 6 if len(items) > 11 else 4
    cell_w, cell_h, label_h = 384, 512, 44
    rows = (len(items) + cols - 1) // cols
    title_h = 70
    canvas = Image.new("RGB", (cols * cell_w, title_h + rows * (cell_h + label_h)), (14, 18, 20))
    draw = ImageDraw.Draw(canvas)
    font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
    try:
        font = ImageFont.truetype(font_path, 24)
        title_font = ImageFont.truetype(font_path, 36)
    except OSError:
        font = title_font = ImageFont.load_default()
    titles = {"heroes": "Герои", "units": "Юниты", "buildings": "Постройки", "idols": "Идолы"}
    draw.text((20, 16), f"Застава — {titles[group]} (славянский нуар, seed {seed})", fill=(226, 170, 90), font=title_font)
    for index, (item_id, name, *_) in enumerate(items):
        path = OUT / group / f"{item_id}_{seed}.png"
        x = (index % cols) * cell_w
        y = title_h + (index // cols) * (cell_h + label_h)
        if path.exists():
            canvas.paste(Image.open(path).convert("RGB").resize((cell_w, cell_h)), (x, y))
        draw.text((x + 12, y + cell_h + 8), name, fill=(230, 222, 205), font=font)
    target = OUT / f"sheet_{group}_{seed}.jpg"
    canvas.save(target, quality=90)
    print(target)


SCHOOL_ROWS = [
    ("Перун · молния", "perun"), ("Сварог · огонь", "svarog"), ("Стрибог · ветер", "stribog"), ("Вода", "water"),
    ("Мороз · лёд", "ice"), ("Война · механизмы", "war"), ("Порча", "curse"),
]


def grid_sheet(title: str, rows: list, target: Path, row_label_w: int = 0) -> None:
    """rows: [(подпись строки, [(путь, подпись), ...]), ...]."""
    from PIL import Image, ImageDraw, ImageFont

    font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
    font, big = ImageFont.truetype(font_path, 22), ImageFont.truetype(font_path, 34)
    cell_w, cell_h, label_h, title_h = 300, 400, 38, 70
    cols = max(len(cells) for _, cells in rows)
    canvas = Image.new("RGB", (row_label_w + cols * cell_w, title_h + len(rows) * (cell_h + label_h)), (14, 18, 20))
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 16), title, fill=(226, 170, 90), font=big)
    for r, (row_title, cells) in enumerate(rows):
        y = title_h + r * (cell_h + label_h)
        if row_label_w:
            draw.text((16, y + cell_h // 2 - 12), row_title, fill=(226, 170, 90), font=font)
        for c, (path, label) in enumerate(cells):
            x = row_label_w + c * cell_w
            if Path(path).exists():
                canvas.paste(Image.open(path).convert("RGB").resize((cell_w, cell_h)), (x, y))
            draw.text((x + 10, y + cell_h + 6), label, fill=(230, 222, 205), font=font)
    canvas.save(target, quality=90)
    print(target)


def buildings_sheet(seed: int) -> None:
    rows = []
    for row_title, school in SCHOOL_ROWS:
        items = sorted((b for b in BUILDINGS if b[3] == school), key=lambda b: b[4])
        rows.append((row_title, [(OUT / "buildings" / f"{b[0]}_{seed}.png", b[1]) for b in items]))
    rows.append(("База и поддержка", [(TEREM_SOURCE, "Терем (база)"),
                                      (OUT / "buildings" / f"beacon_{seed}.png", "Маяк · I"),
                                      (OUT / "idols" / f"idol_empty_{seed}.png", "Идол · пустой")]))
    grid_sheet("Застава — Постройки: школа по строкам, уровень I → II → III", rows,
               OUT / f"sheet_buildings_{seed}.jpg", row_label_w=230)


def idols_sheet(seed: int) -> None:
    cells = [(OUT / "idols" / f"{i[0]}_{seed}.png", i[1]) for i in IDOLS]
    grid_sheet("Застава — Идол: пустой и пробуждённый богами", [("", cells[:4]), ("", cells[4:])],
               OUT / f"sheet_idols_{seed}.jpg")


def main() -> None:
    args = sys.argv[1:]
    seed = 1
    if "--seed" in args:
        seed = int(args[args.index("--seed") + 1])
        del args[args.index("--seed"):args.index("--seed") + 2]
    mode, group, ids = args[0], args[1], set(args[2:])
    groups = ["heroes", "units", "buildings", "idols"] if group == "all" else [group]
    if mode == "sheet":
        for name in groups:
            if name == "buildings":
                buildings_sheet(seed)
            elif name == "idols":
                idols_sheet(seed)
            else:
                sheet(name, seed)
        return
    if group == "ui":
        generate(UI_PROMPT, 1536, 864, seed, OUT / "ui" / f"battle_ui_{seed}.png")
        return
    if group == "arena":
        generate(ARENA_PROMPT, 1536, 864, seed, OUT / "arena" / f"arena_{seed}.png")
        return
    for name in groups:
        for item in GROUPS[name][0]:
            if ids and item[0] not in ids:
                continue
            if name == "units" and item[0] in KEEP_UNITS and not ids:
                kept = OUT / name / f"{item[0]}_4.png"
                if kept.exists():
                    (OUT / name / f"{item[0]}_{seed}.png").write_bytes(kept.read_bytes())
                    continue
            generate(prompt_for(name, item), 768, 1024, seed, OUT / name / f"{item[0]}_{seed}.png")


if __name__ == "__main__":
    main()
