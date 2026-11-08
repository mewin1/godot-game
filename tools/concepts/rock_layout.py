"""Композиция камней арены → assets/noir/courtyard/rock_layout.tres (CourtyardForestLayout).

Запуск: python3 -I tools/concepts/rock_layout.py
Мировые координаты Godot (x, z), м. Поле — x 0…18, z −20…0; ворота — (3, 0); ручей идёт перед воротами
по z ≈ 6…7; полоса без деревьев — x −7,5…27, z −24,5…4,5; терем — за дальней стороной (z < −20).
1) GROUPS — нарочно поставленные группы: «большой + средний + мелкий», менгиры у ворот, брод.
2) Прежние места валунов леса из forest_layout.tres (мастер-сцена) — с разными формами и размерами,
   прореженные; к части добавлен камень-спутник. Валуны внутри полосы и в русле убраны.
"""
import math
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOREST = ROOT / "assets" / "noir" / "courtyard" / "forest_layout.tres"
OUT = ROOT / "assets" / "noir" / "courtyard" / "rock_layout.tres"

# (вид, x, z, масштаб, поворот в градусах)
GROUPS = [
    # ворота: два менгира по сторонам тропы к ручью — славянский знак входа
    ("rock_menhir", -0.4, 3.3, 0.95, 15), ("rock_flat", 0.5, 3.9, 0.45, 70),
    ("rock_menhir", 6.3, 3.5, 0.8, -20), ("rock_flat", 5.4, 4.1, 0.4, 10),
    # брод: плоские камни поперёк ручья напротив ворот
    ("rock_flat", 2.4, 5.2, 0.55, 30), ("rock_flat", 3.4, 6.3, 0.5, 100), ("rock_flat", 2.7, 7.5, 0.55, 200),
    # ближний правый угол двора
    ("rock_split", 22.6, 2.6, 1.05, 35), ("rock_cluster", 24.6, 0.6, 0.75, 120), ("rock_flat", 21.2, 4.0, 0.6, 0),
    # ближний левый угол
    ("rock_boulder", -4.4, 2.0, 1.0, 200), ("rock_flat", -2.9, 3.6, 0.55, 40), ("rock_slab", -6.4, 0.2, 0.6, 75),
    # левая сторона: длинная плита и группа
    ("rock_slab", -5.0, -9.8, 0.95, 80), ("rock_cluster", -6.2, -7.4, 0.7, 10), ("rock_flat", -3.6, -11.6, 0.5, 0),
    # дальний левый угол, у терема
    ("rock_boulder", -4.6, -21.4, 1.25, 60), ("rock_slab", -2.6, -23.6, 0.85, 150), ("rock_flat", -6.0, -19.4, 0.6, 0),
    # правая сторона
    ("rock_cluster", 24.4, -16.4, 1.05, 260), ("rock_boulder", 23.0, -18.9, 0.8, 30), ("rock_flat", 25.6, -14.2, 0.5, 0),
    ("rock_split", 25.4, -6.8, 0.8, 140), ("rock_flat", 24.0, -8.4, 0.45, 0),
    # берега ручья на изгибах
    ("rock_boulder", -13.0, 10.9, 1.3, 0), ("rock_flat", -11.4, 11.7, 0.6, 0),
    ("rock_slab", 11.0, 8.9, 0.9, 170), ("rock_flat", 15.6, 4.6, 0.6, 0), ("rock_cluster", 18.4, 3.6, 0.6, 210),
    ("rock_split", 28.3, 4.6, 1.0, 300), ("rock_cluster", -8.4, 5.4, 0.85, 45),
    ("rock_boulder", 33.0, 15.0, 1.2, 80),
]
STREAM = [(-13.1, 8.8), (-8.5, 7.7), (-4.5, 7.0), (-0.8, 6.5), (3.3, 6.4), (7.5, 6.8), (11.4, 7.2), (15.4, 6.6),
          (19.1, 5.6), (22.9, 5.8), (26.9, 7.1), (30.5, 9.4), (33.6, 12.5), (36.4, 16.0)]
CLEAR = (-7.5, -24.5, 27.0, 4.5)
FOREST_KINDS = [("rock_boulder", 0.35), ("rock_split", 0.15), ("rock_cluster", 0.2), ("rock_slab", 0.2),
                ("rock_flat", 0.1)]


def stream_distance(x: float, z: float) -> float:
    best = 1e9
    for (ax, az), (bx, bz) in zip(STREAM, STREAM[1:]):
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        best = min(best, math.hypot(x - (ax + dx * t), z - (az + dz * t)))
    return best


def forest_sites() -> list[tuple[float, float, float]]:
    text = FOREST.read_text()
    block = re.search(r'"moss_rock": Array\[Transform3D\]\(\[(.*?)\]\)', text, re.S).group(1)
    sites = []
    for m in re.finditer(r"Transform3D\(([^)]*)\)", block):
        v = [float(x) for x in m.group(1).split(",")]
        sites.append((v[9], v[11], math.hypot(v[0], v[1], v[2])))
    return sites


def transform(x: float, z: float, scale: float, yaw_deg: float, y: float = 0.0) -> str:
    a = math.radians(yaw_deg)
    c, s = math.cos(a) * scale, math.sin(a) * scale
    return f"Transform3D({c:.5f}, 0, {-s:.5f}, 0, {scale:.5f}, 0, {s:.5f}, 0, {c:.5f}, {x:.4f}, {y:.4f}, {z:.4f})"


def main() -> None:
    rnd = random.Random(31)
    placed: dict[str, list[str]] = {}
    spots: list[tuple[float, float]] = []

    def put(kind: str, x: float, z: float, scale: float, yaw: float) -> None:
        y = -0.12 if kind == "rock_flat" and stream_distance(x, z) < 1.3 else 0.0  # в воде — притоплен
        placed.setdefault(kind, []).append(transform(x, z, scale, yaw, y))
        spots.append((x, z))

    for kind, x, z, scale, yaw in GROUPS:
        put(kind, x, z, scale, yaw)
    for x, z, old_scale in forest_sites():
        inside = CLEAR[0] < x < CLEAR[2] and CLEAR[1] < z < CLEAR[3]
        if inside or stream_distance(x, z) < 2.2 or any(math.hypot(x - a, z - b) < 3.2 for a, b in spots):
            continue
        roll, kind = rnd.random(), FOREST_KINDS[-1][0]
        for name, share in FOREST_KINDS:
            if roll < share:
                kind = name
                break
            roll -= share
        scale = max(0.55, min(1.35, old_scale * rnd.uniform(0.9, 1.6)))
        put(kind, x, z, scale, rnd.uniform(0, 360))
        if rnd.random() < 0.45:
            a = rnd.uniform(0, math.tau)
            put("rock_flat", x + math.cos(a) * 1.3 * scale, z + math.sin(a) * 1.3 * scale, scale * 0.45,
                rnd.uniform(0, 360))
    lines = ['[gd_resource type="Resource" script_class="CourtyardForestLayout" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://src/view/courtyard_forest_layout.gd" id="1"]', "", "[resource]",
             'script = ExtResource("1")', "placements = Dictionary[String, Array]({"]
    kinds = sorted(placed)
    for i, kind in enumerate(kinds):
        sep = "," if i < len(kinds) - 1 else ""
        lines.append(f'"{kind}": Array[Transform3D]([' + ",\n".join(placed[kind]) + f"]){sep}")
    lines.append("})")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"[rocks] {OUT.relative_to(ROOT)}: " + ", ".join(f"{k} {len(v)}" for k, v in sorted(placed.items())))


if __name__ == "__main__":
    main()
