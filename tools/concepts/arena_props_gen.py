"""Концепты реквизита арены (по new_concept/05_arena.jpg) для конвейера Hunyuan3D: по предмету на кадр.

python3 -I tools/concepts/arena_props_gen.py [id ...] [--seed N] → new_concept/arena_props/<id>_<seed>.png (768×1024).
Дальше: tools/concepts/h3d_gen.py arena_props <id> → tools/blender/noir/h3d.py <id> → арена (arena.py).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from redesign_gen import NOIR, OUT, generate  # noqa: E402

FRAME = ("Single isolated object centered on a plain smooth dark blue-grey background, three-quarter view from slightly above, "
         "the whole object fully visible with empty margin around it, nothing else in the frame, no ground, no pedestal, no tile. ")

PROPS = [
    ("palisade", "a straight section of a dark Slavic wooden palisade wall, eight tall sharpened vertical dark oak logs "
     "tied together with rope and two horizontal beams, weathered wood, a little moss at the bottom, seen from the front-left"),
    ("palisade_post", "a single tall thick carved wooden pagan post of a palisade, sharpened top, carved stern Slavic face and "
     "runes, dark weathered oak, a little moss at the bottom"),
    ("gate", "a dark wooden Slavic fortress gate of a palisade: two thick carved posts with a heavy crossbeam and a small "
     "wooden shingle roof on top, two pale animal skulls nailed to the posts, wide open passage between the posts"),
    ("fire_bowl", "a large black forged iron brazier: a wide round bowl on a thick pedestal with three clawed feet, "
     "full of glowing coals with a big roaring orange fire and flying sparks"),
    ("pine", "a single tall dark spruce fir tree, dense dark blue-green needles, conical shape, whole tree visible from roots to top"),
    ("birch", "a single slender white birch tree with black marks on the bark and a sparse crown of yellow-green leaves, "
     "whole tree visible from roots to top"),
    ("rock", "a single large mossy grey granite boulder with green moss on top and small ferns at its base"),
    ("fern", "a single dense dark green fern bush with a few small mushrooms"),
]


def main() -> None:
    args = sys.argv[1:]
    seed = 16
    if "--seed" in args:
        seed = int(args[args.index("--seed") + 1])
        del args[args.index("--seed"):args.index("--seed") + 2]
    for pid, text in PROPS:
        if args and pid not in args:
            continue
        prompt = f"Subject: {text}. {FRAME}{NOIR}"
        generate(prompt, 768, 1024, seed, OUT / "arena_props" / f"{pid}_{seed}.png")


if __name__ == "__main__":
    main()
