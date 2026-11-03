"""Сравнения «концепт | рендер» для отрендеренных моделей: python3 -I tools/blender/noir/compare.py <id> ..."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
NC = ROOT / "new_concept"


def compare(model_id: str) -> Path:
    render = NC / "compare" / "renders" / f"{model_id}.png"
    concept = NC / (render.with_suffix(".txt").read_text().strip())
    a = Image.open(concept).convert("RGB")
    b = Image.open(render).convert("RGB")
    extra = sorted((NC / "compare" / "renders").glob(f"{model_id}__*.png"))  # кадры Godot и др.
    h = 640
    ims = [a, b] + [Image.open(p).convert("RGB") for p in extra]
    ims = [i.resize((int(i.width * h / i.height), h)) for i in ims]
    c = Image.new("RGB", (sum(i.width for i in ims) + 8 * (len(ims) - 1), h + 34), (8, 10, 12))
    x = 0
    for i in ims:
        c.paste(i, (x, 34))
        x += i.width + 8
    font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans.ttf", 20)
    labels = ["концепт", "Blender"] + [p.stem.split("__")[1] for p in extra]
    x = 0
    for i, lab in zip(ims, labels):
        ImageDraw.Draw(c).text((x + 8, 6), f"{model_id} · {lab}", fill=(230, 180, 100), font=font)
        x += i.width + 8
    out = NC / "compare" / f"{model_id}.jpg"
    c.save(out, quality=84)
    return out


if __name__ == "__main__":
    for mid in sys.argv[1:]:
        print(compare(mid))
