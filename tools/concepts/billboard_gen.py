"""Рисованные деревья и подлесок арены (ComfyUI :8188, Z-Image Turbo) — картинки с прозрачностью для билбордов.

python3 -I tools/concepts/billboard_gen.py [имя ...] [--seeds 11,23,37] [--show] [--recut] [--style clean]
--final — лес арены (выбор автора: B «силуэт» + мягкие кусты C «перья»): сырьё из styles/, ночная гамма концепта,
  итог в assets/noir_h3d/arena/forest/.
--style <стиль> — пробный стиль из STYLES: картинки идут в output/billboard_styles/<стиль>/, игровые не трогаются.
Каждое имя × каждый сид → assets/noir_h3d/arena/billboards/<имя>_<сид>.png (RGBA, низ картинки — земля).
Нейросеть рисует объект на пурпурном фоне (хромакей) — по цвету вырезаются и просветы между ветками. --show — только лист превью в output/billboards_sheet.jpg.
Расставляет NoirArena3D (MultiMesh вертикальных картинок, повёрнутых к камере).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import redesign_gen as rg  # noqa: E402

OUT = Path("assets/noir_h3d/arena/billboards")
RAW = Path("source_art/noir/billboards")
STYLE = ("Dark Slavic folk noir fantasy game art, soft painterly brush strokes, semi-realistic, night lighting, "
         "muted dark olive and forest green with warm moss tones, gentle soft cool rim light on one side, no ink "
         "outlines, no hard black contours, soft edges, readable silhouette, "
         "isolated on a solid flat pure bright magenta chroma key background (#FF00FF) filling everything around "
         "and between the branches, nothing else in the picture, no ground, no sky, "
         "the whole object fits the frame with a small margin. Subject: ")
# Пробные стили (автор: лес v4 «острый, мрачный и грязный»; в концепте — чистый, мрачный, средняя детализация)
CHROMA = ("isolated on a solid flat pure saturated bright magenta chroma key background (#FF00FF, no texture, no "
          "gradient, not pink, not grey) filling everything around "
          "and between the branches, nothing else in the picture, no ground, no sky, "
          "the whole object fits the frame with a small margin. Subject: ")
STYLES = {
    "clean": ("Stylized 3D game environment asset render, dark fantasy night scene, clean simplified shapes, medium "
              "level of detail, smooth soft shading, large readable forms, no fine noisy texture, no sharp spikes, "
              "deep muted green with a slight olive tint, soft moonlight from above, gentle ambient occlusion, "),
    "silhouette": ("Moody stylized game art, the plant as a clean graphic silhouette with soft volume, simple "
                   "layered shapes, minimal inner detail, smooth gradients, deep desaturated dark green, faint soft "
                   "moonlight on the top edges, calm and tidy, "),
    "feather": ("Moody stylized game art, the plant as a clean silhouette with soft volume, layered drooping branch "
                "tiers with soft feathery edges, medium detail, smooth gradients, no noise, no outlines, deep "
                "desaturated dark green, faint soft moonlight on the top edges, calm and tidy, "),
    # автор: ели «силуэта» плоские — нужен объём (светотень), но без мультяшности и мелкой грязи
    "volume": ("Stylized 3D rendered game asset of a dark night forest, the plant has strong 3D volume: each branch "
               "tier is a soft rounded mass with dark ambient occlusion shadow underneath and between tiers, soft "
               "cool moonlight from above catching the top surfaces of the boughs, needles grouped into soft clumps, "
               "medium detail, clean readable shape, no outlines, no noise, deep desaturated dark green, "),
    "painted": ("Painterly stylized environment art of a dark night forest like a high quality fantasy game, the "
                "plant is a solid volumetric 3D form with clear light and shadow: lit upper boughs, deep shadowed "
                "core near the trunk, layered drooping boughs with soft feathery needle edges, medium detail, "
                "smooth brushwork, no outlines, no noise, deep desaturated dark green, "),
    "semi": ("Semi-realistic stylized 3D environment asset of a modern dark fantasy RPG, medium detail: needles "
             "grouped into soft rounded clumps, clean readable shape, smooth soft shading, no noise, no outlines, "
             "natural deep green, soft overcast light, "),
    "gouache": ("Hand-painted stylized game art, clean gouache painting with large confident brush shapes, medium "
                "detail, no tiny strokes, no noise, no outlines, soft edges, deep muted forest green with warm olive "
                "accents, dim night light, "),
}
# упрощённые формы для пробных стилей: ярусы, чистые стволы, без веточек
SUBJECTS_CLEAN = {
    "spruce": ("one very tall old spruce tree, straight clean dark trunk bare in the lower third, above it a crown of "
               "distinct soft layered drooping tiers with small gaps between them, narrow pointed top", 576, 1536),
    "birch": ("one very tall old birch tree, long clean white trunk with a few dark marks, bare in the lower half, "
              "a high narrow soft crown made of rounded clusters of small leaves", 576, 1536),
    "grass": ("a low wide soft clump of dark green grass blades, tidy rounded shape, no twigs, no flowers, seen from "
              "the side", 1024, 640),
    "fern": ("one classic forest fern bush, arching fronds with many small leaflets along each frond, dark green, "
             "tidy, seen from the side", 1024, 768),
    "sapling": ("a young spruce about two meters tall with soft layered tiers down to the ground, dark green, seen "
                "from the side", 768, 1024),
}
# Лес арены: вид → стиль (автор 2026-11-04: «B + куст из C»; ели «силуэта» — «не объёмные» → «painted»).
# Сид 23 у Z-Image не держит пурпурный фон.
FINAL = {"spruce": "painted", "birch": "silhouette", "fern": "silhouette", "sapling": "painted",
         "grass": "feather"}
FINAL_SEEDS = {"spruce": [11, 37, 52, 64], "birch": [11, 37, 52], "fern": [37, 52, 64], "sapling": [11, 37, 52, 64],
               "grass": [11, 37, 52]}
FOREST = Path("assets/noir_h3d/arena/forest")
# Ночная гамма (замер концепта: яркость елей 0.10–0.21, насыщенность до 0.4)
NIGHT_SAT = 0.45
NIGHT_GAMMA = 1.35
NIGHT_GAIN = 0.55


def night(rgb: np.ndarray) -> np.ndarray:
    """Приглушить зелень, чуть к оливе, тени глубже — как ночной лес концепта (rgb 0..1)."""
    lum = (rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32))[..., None]
    out = lum + (rgb - lum) * NIGHT_SAT
    out = out * np.array([0.92, 1.0, 0.95], dtype=np.float32)
    v = np.clip(lum, 1e-4, 1.0)
    return np.clip(out / v * v ** NIGHT_GAMMA * NIGHT_GAIN, 0.0, 1.0)


# имя → (описание, ширина, высота)
SUBJECTS = {
    "spruce": ("one very tall old spruce tree of an ancient taiga forest, straight dark brown trunk bare of branches "
               "in the lower third, above it sparse drooping layered branches with gaps between the tiers, dark olive "
               "green needles with soft rounded clumps, narrow pointed top", 576, 1536),
    "birch": ("one very tall old birch tree of an ancient forest, long straight white trunk with black horizontal marks "
              "and dark cracks, bare of branches in the lower half, a high narrow crown of thin drooping twigs with "
              "small dark olive leaves", 576, 1536),
    "grass": ("a low wide soft rounded clump of dark forest grass tufts and moss, muted olive green, no bare twigs, "
              "no branches, seen from the side", 1024, 640),
    "fern": ("a single soft dark forest fern bush, arching fronds, muted olive green, seen from the side", 1024, 768),
    "sapling": ("a young bushy spruce sapling about two meters tall, dense soft branches down to the ground, dark olive "
                "green, seen from the side", 768, 1024),
}


def islands(mask: np.ndarray, limit: int) -> np.ndarray:
    """Связные части маски меньше limit пикселей (обход в ширину, 4-связность)."""
    from collections import deque
    h, w = mask.shape
    seen = np.zeros_like(mask)
    small = np.zeros_like(mask)
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        comp = [(y0, x0)]
        queue = deque(comp)
        seen[y0, x0] = True
        while queue:
            y, x = queue.popleft()
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
                    comp.append((ny, nx))
        if len(comp) < limit:
            ys, xs = zip(*comp)
            small[list(ys), list(xs)] = True
    return small


def cut(src: Path, dst: Path, grade: bool = False) -> None:
    """Хромакей: пурпурный фон (и просветы между ветками) прозрачный, кайма — без пурпурного оттенка."""
    img = Image.open(src).convert("RGB")
    px = np.asarray(img, dtype=np.float32) / 255.0
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    # «пурпурность»: красный и синий заметно выше зелёного
    key = np.minimum(r, b) - g
    alpha = np.clip(1.0 - (key - 0.12) / 0.25, 0.0, 1.0)
    mask = alpha > 0.5
    # оторванные клочки (островки меньше ~150 пикселей) — прозрачные; край альфы чуть размыт
    small = islands(mask, 150)
    alpha[small] = 0.0
    mask &= ~small
    soft = alpha.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        soft += np.roll(np.roll(alpha, dy, 0), dx, 1)
    alpha = np.minimum(alpha, soft / 5.0 * 1.25)
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # пурпурный отсвет фона: где и красный, и синий выше зелёного — излишек вычитается из обоих
    # (холодная бирюза хвои — синий выше, красный ниже — не трогается)
    spill = np.clip(np.minimum(r, b) - g, 0.0, 1.0)
    despill = px.copy()
    despill[..., 0] = r - spill
    despill[..., 2] = b - spill
    rgba = np.dstack([(despill * 255).astype(np.uint8), (alpha * 255).astype(np.uint8)])[y0:y1, x0:x1]
    # цвет под прозрачными краями — ближайший непрозрачный (без серой каймы при мип-картах)
    rgb = rgba[..., :3].astype(np.float32)
    solid = rgba[..., 3] > 0
    for _ in range(12):
        grown = solid.copy()
        acc = np.zeros_like(rgb)
        cnt = np.zeros(solid.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(solid, dy, 0), dx, 1)
            acc += np.roll(np.roll(rgb, dy, 0), dx, 1) * sh[..., None]
            cnt += sh
        fill = ~solid & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][:, None]
        grown |= fill
        solid = grown
    if grade:
        rgb = night(rgb / 255.0) * 255.0
    rgba[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    out.thumbnail((512, 1024) if out.height > out.width else (768, 512), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)


def sheet(paths: list[Path], out: str = "output/billboards_sheet.jpg") -> None:
    tiles = []
    for p in paths:
        im = Image.open(p)
        bg = Image.new("RGBA", im.size, (24, 30, 34, 255))
        bg.alpha_composite(im)
        tiles.append(bg.convert("RGB").resize((int(im.width * 420 / im.height), 420)))
    w = sum(t.width + 8 for t in tiles)
    s = Image.new("RGB", (w, 420), (12, 15, 17))
    x = 0
    for t in tiles:
        s.paste(t, (x, 0))
        x += t.width + 8
    s.save(out, quality=88)
    print(out, s.size)


def main() -> None:
    args = sys.argv[1:]
    seeds = [11, 23, 37]
    if "--seeds" in args:
        i = args.index("--seeds")
        seeds = [int(v) for v in args[i + 1].split(",")]
        del args[i : i + 2]
    show = "--show" in args
    if "--final" in args:
        made = []
        for name, style in FINAL.items():
            for seed in FINAL_SEEDS[name]:
                raw = RAW / "styles" / style / f"{name}_{seed}.png"
                if not raw.exists():
                    subject, w, h = SUBJECTS_CLEAN[name]
                    raw.parent.mkdir(parents=True, exist_ok=True)
                    rg.generate(STYLES[style] + CHROMA + subject + ".", w, h, seed, raw)
                dst = FOREST / f"{name}_{seed}.png"
                cut(raw, dst, grade=True)
                made.append(dst)
        sheet(made, "output/forest_sheet.jpg")
        return
    recut = "--recut" in args  # только вырезать заново из source_art/noir/billboards
    style = ""
    if "--style" in args:
        i = args.index("--style")
        style = args[i + 1]
        del args[i : i + 2]
    subjects = SUBJECTS_CLEAN if style else SUBJECTS
    prefix = STYLES[style] + CHROMA if style else STYLE
    raw_dir = RAW / "styles" / style if style else RAW
    out_dir = Path("output/billboard_styles") / style if style else OUT
    names = [a for a in args if not a.startswith("--")] or list(subjects)
    made = []
    for name in names:
        subject, w, h = subjects[name]
        for seed in seeds:
            raw = raw_dir / f"{name}_{seed}.png"
            dst = out_dir / f"{name}_{seed}.png"
            if not show:
                raw.parent.mkdir(parents=True, exist_ok=True)
                if not (recut and raw.exists()):
                    rg.generate(prefix + subject + ".", w, h, seed, raw)
                cut(raw, dst)
            made.append(dst)
    sheet(made, str(out_dir / "sheet.jpg") if style else "output/billboards_sheet.jpg")


if __name__ == "__main__":
    main()
