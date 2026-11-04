"""Картинки интерфейса из одобренных концептов (пачка 3, seed 16): лавка и герои.

python3 -I tools/concepts/ui_art.py
- new_concept/buildings/<id>_16.png → assets/ui/towers/<id>.jpg (карточка лавки, 3:4);
- new_concept/heroes/<id>_16.png  → assets/ui/heroes/<id>.jpg (во весь рост, 3:4)
  и data/visuals/portraits/<id>.tres — портрет: кадр лица на той же картинке (AtlasTexture).
Кадр лица задан вручную в FACES: центр головы (доли ширины/высоты) и сторона квадрата (доля ширины).
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CONCEPTS = ROOT / "new_concept"
TOWERS = ROOT / "assets/ui/towers"
HEROES = ROOT / "assets/ui/heroes"
PORTRAITS = ROOT / "data/visuals/portraits"
TOWER_SIZE = (360, 480)
HERO_SIZE = (540, 720)
# центр головы x, y и сторона квадрата портрета — доли ширины картинки
FACES = {
    "baba_yaga": (0.53, 0.21, 0.44),
    "domovoy": (0.52, 0.2, 0.46),
    "cosmonaut": (0.53, 0.14, 0.42),
    "ilya": (0.57, 0.14, 0.42),
    "leshy": (0.43, 0.18, 0.46),
    "babushka": (0.52, 0.18, 0.42),
    "solovey": (0.48, 0.18, 0.42),
    "gorynych": (0.5, 0.2, 0.62),
    "koschei": (0.5, 0.14, 0.42),
    "skomorokh": (0.5, 0.17, 0.44),
    "vasilisa": (0.5, 0.14, 0.4),
}
PORTRAIT_TRES = """[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/ui/heroes/{id}.jpg" id="1"]

[resource]
atlas = ExtResource("1")
region = Rect2({x:.1f}, {y:.1f}, {side:.1f}, {side:.1f})
filter_clip = true
"""


def main() -> None:
    TOWERS.mkdir(parents=True, exist_ok=True)
    HEROES.mkdir(parents=True, exist_ok=True)
    for path in sorted((CONCEPTS / "buildings").glob("*_16.png")):
        tower_id = path.stem.removesuffix("_16")
        Image.open(path).convert("RGB").resize(TOWER_SIZE, Image.LANCZOS).save(
            TOWERS / f"{tower_id}.jpg", quality=90)
    for hero_id, (cx, cy, side) in FACES.items():
        image = Image.open(CONCEPTS / "heroes" / f"{hero_id}_16.png").convert("RGB")
        image = image.resize(HERO_SIZE, Image.LANCZOS)
        image.save(HEROES / f"{hero_id}.jpg", quality=90)
        width, height = HERO_SIZE
        pixels = side * width
        x = min(max(cx * width - pixels / 2, 0), width - pixels)
        y = min(max(cy * height - pixels * 0.45, 0), height - pixels)
        (PORTRAITS / f"{hero_id}.tres").write_text(
            PORTRAIT_TRES.format(id=hero_id, x=x, y=y, side=pixels), encoding="utf-8")
    print("towers", len(list(TOWERS.glob("*.jpg"))), "heroes", len(FACES))


if __name__ == "__main__":
    main()
