"""Дозаполнение леса там, куда смотрит камера, а мастер-сцена деревьев не ставила (левая половина кадра:
мир за ручьём и справа от двора) → assets/noir/courtyard/forest_fill.tres (CourtyardForestLayout).

Запуск: python3 -I tools/concepts/forest_fill.py
Ели и берёзы — с шагом ~4 м, как в мастер-лесу (forest_layout.tres), не ближе 3,8 м к его деревьям;
под деревьями — папоротник и осока, по краям — молодые ели. Не трогает полосу без деревьев вокруг двора,
терем и ручей. Область — что видит камера на уровнях I–IV (лучи из углов кадра на землю, замер в Godot).
"""
import math
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOREST = ROOT / "assets" / "noir" / "courtyard" / "forest_layout.tres"
OUT = ROOT / "assets" / "noir" / "courtyard" / "forest_fill.tres"

# земля в кадре (x, z): углы кадра на уровнях I и IV, обход по кругу; с запасом — кроны высоких елей
VIEW = [(18.0, 92.0), (-72.0, -28.0), (-62.0, -40.0), (16.0, -40.0), (56.0, 10.0), (40.0, 60.0)]
CLEAR = (-9.0, -26.0, 28.5, 6.0)  # полоса без деревьев вокруг двора (+ запас)
TEREM = (-2.0, -30.0, 20.0, -19.0)
STREAM = [(-72.0, 30.0), (-62.5, 26.4), (-53.7, 23.1), (-44.6, 19.8), (-37.0, 17.0), (-27.9, 13.7), (-20.2, 10.9),
          (-13.1, 8.8), (-4.5, 7.0), (3.3, 6.4), (11.4, 7.2), (19.1, 5.6), (22.9, 5.8), (26.9, 7.1), (30.5, 9.4),
          (33.6, 12.5), (36.4, 16.0)]
SPACING = 4.3


def inside(poly: list, x: float, z: float) -> bool:
    hit = False
    for (ax, az), (bx, bz) in zip(poly, poly[1:] + poly[:1]):
        if (az > z) != (bz > z) and x < ax + (bx - ax) * (z - az) / (bz - az):
            hit = not hit
    return hit


def stream_gap(x: float, z: float) -> float:
    best = 1e9
    for (ax, az), (bx, bz) in zip(STREAM, STREAM[1:]):
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        best = min(best, math.hypot(x - ax - dx * t, z - az - dz * t))
    return best


def in_rect(r: tuple, x: float, z: float) -> bool:
    return r[0] < x < r[2] and r[1] < z < r[3]


def transform(x: float, z: float, scale: float, yaw: float) -> str:
    c, s = math.cos(yaw) * scale, math.sin(yaw) * scale
    return f"Transform3D({c:.5f}, 0, {-s:.5f}, 0, {scale:.5f}, 0, {s:.5f}, 0, {c:.5f}, {x:.4f}, -0.06, {z:.4f})"


def main() -> None:
    rnd = random.Random(53)
    text = FOREST.read_text()
    old = []
    for sp in ("spruce", "birch"):
        block = re.search(r'"%s": Array\[Transform3D\]\(\[(.*?)\]\)' % sp, text, re.S).group(1)
        for m in re.finditer(r"Transform3D\(([^)]*)\)", block):
            v = [float(a) for a in m.group(1).split(",")]
            old.append((v[9], v[11]))
    trees: list[tuple[float, float]] = []
    placed: dict[str, list[str]] = {}

    def put(kind: str, x: float, z: float, scale: float, yaw: float) -> None:
        placed.setdefault(kind, []).append(transform(x, z, scale, yaw))

    # «пуассоновская» россыпь: случайные пробы, не ближе SPACING друг к другу
    for _ in range(40000):
        x, z = rnd.uniform(-75, 60), rnd.uniform(-42, 95)
        if not inside(VIEW, x, z) or in_rect(CLEAR, x, z) or in_rect(TEREM, x, z) or stream_gap(x, z) < 3.2:
            continue
        if any(math.hypot(x - a, z - b) < 3.8 for a, b in old):
            continue
        if any(math.hypot(x - a, z - b) < SPACING * rnd.uniform(0.85, 1.15) for a, b in trees):
            continue
        trees.append((x, z))
        # по краю полосы (у двора) — ниже и чаще берёзы: опушка светлее
        edge = in_rect((CLEAR[0] - 6, CLEAR[1] - 6, CLEAR[2] + 6, CLEAR[3] + 6), x, z)
        birch = rnd.random() < (0.35 if edge else 0.2)
        if birch:
            put("birch", x, z, rnd.uniform(7.0, 10.5), rnd.uniform(0, math.tau))
        else:
            put("spruce", x, z, rnd.uniform(6.0, 12.5) * (0.8 if edge else 1.0), rnd.uniform(0, math.tau))
        # подлесок под деревом
        for _k in range(rnd.randint(2, 5)):
            a, r = rnd.uniform(0, math.tau), rnd.uniform(0.8, 2.6)
            px, pz = x + math.cos(a) * r, z + math.sin(a) * r
            if in_rect(CLEAR, px, pz) or stream_gap(px, pz) < 1.8:
                continue
            roll = rnd.random()
            if roll < 0.5:
                put("fern", px, pz, rnd.uniform(0.8, 1.3), rnd.uniform(0, math.tau))
            elif roll < 0.85:
                put("sedge", px, pz, rnd.uniform(0.6, 1.0), rnd.uniform(0, math.tau))
            else:
                put("spruce", px, pz, rnd.uniform(1.4, 2.6), rnd.uniform(0, math.tau))
    lines = ['[gd_resource type="Resource" script_class="CourtyardForestLayout" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://src/view/courtyard_forest_layout.gd" id="1"]', "", "[resource]",
             'script = ExtResource("1")', "placements = Dictionary[String, Array]({"]
    kinds = sorted(placed)
    for i, kind in enumerate(kinds):
        sep = "," if i < len(kinds) - 1 else ""
        lines.append(f'"{kind}": Array[Transform3D]([' + ",\n".join(placed[kind]) + f"]){sep}")
    lines.append("})")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"[forest] {OUT.relative_to(ROOT)}: деревьев {len(trees)}; " +
          ", ".join(f"{k} {len(v)}" for k, v in sorted(placed.items())))


if __name__ == "__main__":
    main()
