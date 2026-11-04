"""Фактуры деревьев арены (ComfyUI :8188, Z-Image Turbo): карточки веток с прозрачностью и кора.

python3 -I tools/concepts/foliage_gen.py [имя ...] [--seed N] -> source_art/noir/foliage/<имя>.png
Карточки (ветка ели, ветки берёзы) рисуются на чёрном, прозрачность — по отличию от фона;
кора — бесшовная (как texture_gen). Деревья собирает tools/blender/noir/trees.py.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import redesign_gen as rg  # noqa: E402
import texture_gen  # noqa: E402

OUT = Path("source_art/noir/foliage")
CARD = ("Hand-painted stylized dark fantasy game asset texture, even soft light, muted cold colors, "
        "the object fills the frame, isolated on a pure flat black background, no ground, no shadow, no text. Subject: ")
TILE = texture_gen.STYLE
CARDS = {
    "spruce_branch": "one long flat drooping spruce fir branch seen from directly above, the main stem goes "
                     "horizontally from the left edge to the right edge, dense short dark blue-green needles on many "
                     "side twigs, slightly lighter needle tips",
    "birch_leaves": "a single leafy birch twig spray without trunk: thin dark twigs fanning out with many small "
                    "oval leaves in muted olive green and dull autumn gold, seen from the front, filling the frame",
}
TILES = {
    "pine_bark": "dark grey-brown spruce tree bark with long vertical scaly plates, deep cracks and a little moss",
    "birch_bark": "close-up flat surface of pale grey-white birch bark covering the entire image, short black "
                  "horizontal dashes and lenticels, a few dark knots, no tree trunks, no background",
}


def cut_alpha(path: Path) -> None:
    """Прозрачность по яркости над чёрным фоном; цвет под полупрозрачными краями растягивается (без чёрных каёмок)."""
    im = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    lum = im.max(axis=2)
    alpha = np.clip((lum - 0.05) / 0.12, 0.0, 1.0)
    rgb = im / np.maximum(alpha[..., None], 0.25)
    out = np.dstack([np.clip(rgb, 0, 1), alpha])
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(path)


def main() -> None:
    args = sys.argv[1:]
    seed = 31
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i : i + 2]
    names = args or list(CARDS) + list(TILES)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names:
        target = OUT / f"{name}.png"
        if name in CARDS:
            rg.generate(CARD + CARDS[name] + ".", 1024, 1024, seed, target)
            cut_alpha(target)
        else:
            rg.generate(TILE + TILES[name] + ".", 1024, 1024, seed, target)
            texture_gen.make_tileable(target)
        print(target)


if __name__ == "__main__":
    main()
