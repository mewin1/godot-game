"""Рисованные текстуры-фактуры для запекания моделей (ComfyUI :8188, Z-Image Turbo).

python3 -I tools/concepts/texture_gen.py [имя ...]  ->  source_art/noir/textures/<имя>.png (1024², бесшовная склейка краёв)
В запекании (tools/blender/noir/paint.py) берётся яркость фактуры поверх цвета материала.
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parent))
import redesign_gen as rg  # noqa: E402

OUT = Path("source_art/noir/textures")
STYLE = ("Seamless tileable texture, flat orthographic top-down view filling the whole frame edge to edge, "
         "even flat lighting, no shadows from outside, no perspective, no objects, no border. "
         "Hand-painted stylized game texture like a dark fantasy hero shooter, visible brush strokes, "
         "painted highlights on edges and dark crevices, muted desaturated colors. Subject: ")
TEXTURES = {
    "wood": "vertical dark oak wooden planks with deep wood grain, knots, cracks and worn painted edges, reddish brown",
    "shingle": "rows of overlapping dark wooden roof shingles with rounded scalloped ends, slate grey-black, worn edges",
    "stone": "dark grey cobblestones of irregular rounded shapes with dark mortar gaps, chips and cracks, a little moss",
    "cloth": "coarse woven linen fabric with subtle folds, stitched seams and a little dirt, mid grey",
    "metal": "worn dark forged iron plate with scratches, dents, hammer marks and bright worn edges, grey",
    "bark": "carved weathered wooden log surface with long vertical grain, cracks and chisel marks, warm brown",
    "courtyard": "square dark grey-blue stone flagstone tiles of a medieval courtyard laid in a neat grid, about four by four "
                 "tiles, thin dark gaps between tiles, worn chipped edges, cracks, small tufts of moss in the gaps, wet sheen",
    "road": "packed light brown dirt road surface with small pebbles, wheel ruts and dry dust, warm ochre-grey",
    "forest_floor": "dark forest floor: fallen pine needles, dark soil, small moss patches and dead leaves, dark green-brown",
    "mail": "dense chainmail rings pattern, small interlocking iron rings, dark grey with bright highlights",
}


def make_tileable(path: Path) -> None:
    """Сдвиг на половину и смешивание с оригиналом по маске — швы уходят в середину и размываются."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    shifted = ImageChops.offset(im, w // 2, h // 2)
    mask = Image.new("L", (w, h))
    px = mask.load()
    for y in range(h):
        for x in range(w):
            dx = min(x, w - 1 - x) / (w / 2)
            dy = min(y, h - 1 - y) / (h / 2)
            px[x, y] = int(255 * max(0.0, min(1.0, min(dx, dy) * 3.0)))
    Image.composite(im, shifted, mask).save(path)


def main() -> None:
    names = sys.argv[1:] or list(TEXTURES)
    for name in names:
        target = OUT / f"{name}.png"
        rg.generate(STYLE + TEXTURES[name] + ".", 1024, 1024, 21, target)
        make_tileable(target)


if __name__ == "__main__":
    main()
