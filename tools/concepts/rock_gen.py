"""Концепты камней опушки (разные формы) для конвейера Hunyuan3D.

python3 -I tools/concepts/rock_gen.py [id ...] [--seed N] → new_concept/rocks/<id>_<seed>.png (1024×1024).
Свет ровный, без ночного «нуара»: Hunyuan перенесёт рисунок в текстуру, а ночь даст сама сцена Godot.
Дальше: h3d_gen.py rocks <id> → h3d_paint.py rocks <id> → tools/blender/noir/rocks.py.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from redesign_gen import OUT, generate  # noqa: E402

FRAME = ("Single isolated object centered on a plain smooth light grey background, three-quarter view from above, "
         "the whole object fully visible with wide empty margin, nothing else in the frame, no ground plane, no shadow. "
         "Soft even overcast lighting, no dramatic shadows. ")
STYLE = ("Art style: painterly stylized 3D game asset render, hand-painted PBR texture with visible brushstrokes, "
         "chunky readable shapes, slightly exaggerated forms, muted natural colors: cool blue-grey granite, "
         "deep green moss, pale sage lichen. No text, no logo, no watermark.")

ROCKS = [
    ("rock_boulder", "a large rounded granite boulder, chunky faceted planes, thick cushion of dark green moss on top "
     "flowing down one side, pale lichen spots"),
    ("rock_slab", "a wide flat tilted slab of layered grey stone, sharp broken edges, strips of moss in the cracks, "
     "low and long"),
    ("rock_menhir", "a tall narrow ancient standing stone, weathered grey granite pillar leaning slightly, "
     "faint carved Slavic sun symbol worn by time, moss at the base"),
    ("rock_cluster", "a group of three grey granite stones of different sizes huddled together, one big, one medium, "
     "one small, moss between them"),
    ("rock_split", "a big grey boulder split in two halves by a deep crack, small ferns growing in the crack, "
     "moss on top"),
    ("rock_flat", "a few flat rounded river stones stacked low, wet dark grey and brown pebbles, a bit of moss"),
]


def main() -> None:
    args = sys.argv[1:]
    seed = 16
    if "--seed" in args:
        seed = int(args[args.index("--seed") + 1])
        del args[args.index("--seed"):args.index("--seed") + 2]
    for rid, text in ROCKS:
        if args and rid not in args:
            continue
        generate(f"Subject: {text}. {FRAME}{STYLE}", 1024, 1024, seed, OUT / "rocks" / f"{rid}_{seed}.png")


if __name__ == "__main__":
    main()
