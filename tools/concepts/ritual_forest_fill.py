"""Досадка леса, камней и травы вокруг двора «Обряда» → assets/noir/courtyard/ritual_fill.tres.
Запуск: python3 -I tools/concepts/ritual_forest_fill.py

«Обряд» ставит лес PvP-мастер-сцены, повёрнутый на −90° вокруг своего двора (ENV в
src/view/ritual_arena_3d.gd). Мастер-сцена не сажала деревьев там, куда PvP-камера не смотрит, —
в кадре «Обряда» это пустая земля справа за двором и внизу, ближе к камере. Скрипт досаживает:
1) ели и берёзы с шагом ~4,3 м (как forest_fill.py) в кадре вне поляны, с подлеском;
   у края поляны — ниже и чаще берёзы, у ближнего к камере края — ещё ниже, чтобы не закрыть двор;
2) группы камней «большой + спутники» на поляне и одиночные валуны на опушке;
3) куртины осоки, злака и папоротника на поляне, в том числе в «кармане» двора у терема.
Координаты считаются в мире «Обряда», а пишутся в координатах мастер-сцены PvP (игра переносит их ENV).
Поляна, двор и кадр должны совпадать с ritual_arena_3d.gd (CLEARINGS, TEREM).
"""
import math
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COURT = ROOT / "assets" / "noir" / "courtyard"
OUT = COURT / "ritual_fill.tres"
BOARD = ROOT / "data" / "ritual" / "board.tres"
TRIAL = ROOT / "data" / "ritual" / "trial.tres"

# Поляна без деревьев (x0, z0, x1, z1) — двор с полосой луга и площадка терема (ritual_arena_3d.gd).
CLEARINGS = [(-2.5, -23.0, 45.5, 15.0), (32.0, -6.0, 52.0, 17.0)]
TEREM = (37.0, -0.5, 47.0, 10.5)
# Земля в кадре «Обряда» (углы экрана 16:9 на земле, замер в Godot) с запасом под кроны и другие окна.
VIEW = [(-61.6, 6.4), (43.7, -73.6), (60.3, 4.1), (8.7, 43.2)]
VIEW_PAD = 14.0
# Русло ручья в мире PvP (как в forest_fill.py), переносится ENV.
PVP_STREAM = [(-72.0, 30.0), (-62.5, 26.4), (-53.7, 23.1), (-44.6, 19.8), (-37.0, 17.0), (-27.9, 13.7),
              (-20.2, 10.9), (-13.1, 8.8), (-4.5, 7.0), (3.3, 6.4), (11.4, 7.2), (19.1, 5.6), (22.9, 5.8),
              (26.9, 7.1), (30.5, 9.4), (33.6, 12.5), (36.4, 16.0)]
SPACING = 4.3
CELL = 2.0
YARD_PAD = 1.6


def to_ritual(x: float, z: float) -> tuple:
    """Мир PvP → мир «Обряда» (ENV: −90° вокруг вертикали и сдвиг)."""
    return (-z + 1.5, x - 18.0)


def to_pvp(x: float, z: float) -> tuple:
    return (z + 18.0, 1.5 - x)


def in_rect(r: tuple, x: float, z: float) -> bool:
    return r[0] < x < r[2] and r[1] < z < r[3]


def in_clearing(x: float, z: float) -> bool:
    return any(in_rect(r, x, z) for r in CLEARINGS)


def clearing_gap(x: float, z: float) -> float:
    best = 1e9
    for r in CLEARINGS:
        dx = max(r[0] - x, 0.0, x - r[2])
        dz = max(r[1] - z, 0.0, z - r[3])
        best = min(best, math.hypot(dx, dz))
    return best


def inside(poly: list, x: float, z: float) -> bool:
    hit = False
    for (ax, az), (bx, bz) in zip(poly, poly[1:] + poly[:1]):
        if (az > z) != (bz > z) and x < ax + (bx - ax) * (z - az) / (bz - az):
            hit = not hit
    return hit


def grown(poly: list, pad: float) -> list:
    cx = sum(p[0] for p in poly) / len(poly)
    cz = sum(p[1] for p in poly) / len(poly)
    result = []
    for x, z in poly:
        d = math.hypot(x - cx, z - cz)
        result.append((x + (x - cx) / d * pad, z + (z - cz) / d * pad))
    return result


def yard_cells() -> set:
    cells = set()
    for m in re.finditer(r"Vector2i\((-?\d+), (-?\d+)\)", re.search(r"path_cells = (.*)", BOARD.read_text()).group(1)):
        cells.add((int(m.group(1)), int(m.group(2))))
    regions = re.search(r"build_regions = (.*)", TRIAL.read_text()).group(1)
    for m in re.finditer(r"Rect2i\((\d+), (\d+), (\d+), (\d+)\)", regions):
        x0, y0, w, h = (int(v) for v in m.groups())
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                cells.add((x, y))
    return cells


CELLS = yard_cells()


def in_yard(x: float, z: float) -> bool:
    """Двор с частоколом и терем: открытые клетки поля с запасом под ограду."""
    if in_rect(TEREM, x, z):
        return True
    cx, cy = math.floor(x / CELL), math.floor((z + 20.0) / CELL)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cell = (cx + dx, cy + dy)
            if cell not in CELLS:
                continue
            x0, z0 = cell[0] * CELL - YARD_PAD, cell[1] * CELL - 20.0 - YARD_PAD
            if x0 < x < x0 + CELL + 2 * YARD_PAD and z0 < z < z0 + CELL + 2 * YARD_PAD:
                return True
    return False


STREAM = [to_ritual(x, z) for x, z in PVP_STREAM]


def stream_gap(x: float, z: float) -> float:
    best = 1e9
    for (ax, az), (bx, bz) in zip(STREAM, STREAM[1:]):
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        best = min(best, math.hypot(x - ax - dx * t, z - az - dz * t))
    return best


def old_trees() -> list:
    """Деревья мастер-сцены и forest_fill, которые останутся в кадре «Обряда»."""
    result = []
    for name in ("forest_layout.tres", "forest_fill.tres"):
        text = (COURT / name).read_text()
        for species in ("spruce", "birch"):
            block = re.search(r'"%s": Array\[Transform3D\]\(\[(.*?)\]\)' % species, text, re.S).group(1)
            for m in re.finditer(r"Transform3D\(([^)]*)\)", block):
                v = [float(a) for a in m.group(1).split(",")]
                x, z = to_ritual(v[9], v[11])
                if not in_clearing(x, z):
                    result.append((x, z))
    return result


class Grid:
    """Сетка для быстрой проверки «не ближе r к соседу»."""

    def __init__(self, size: float) -> None:
        self.size = size
        self.cells: dict = {}

    def add(self, x: float, z: float) -> None:
        self.cells.setdefault((math.floor(x / self.size), math.floor(z / self.size)), []).append((x, z))

    def near(self, x: float, z: float, r: float) -> bool:
        cx, cz = math.floor(x / self.size), math.floor(z / self.size)
        for dz in (-1, 0, 1):
            for dx in (-1, 0, 1):
                for a, b in self.cells.get((cx + dx, cz + dz), ()):
                    if math.hypot(x - a, z - b) < r:
                        return True
        return False


def transform(x: float, z: float, scale: float, yaw: float, y: float) -> str:
    """Точка мира «Обряда» → строка Transform3D в координатах мастер-сцены PvP."""
    px, pz = to_pvp(x, z)
    c, s = math.cos(yaw) * scale, math.sin(yaw) * scale
    return f"Transform3D({c:.5f}, 0, {-s:.5f}, 0, {scale:.5f}, 0, {s:.5f}, 0, {c:.5f}, {px:.4f}, {y:.2f}, {pz:.4f})"


def main() -> None:
    rnd = random.Random(61)
    placed: dict = {}

    def put(kind: str, x: float, z: float, scale: float, yaw: float, y: float = -0.06) -> None:
        placed.setdefault(kind, []).append(transform(x, z, scale, yaw, y))

    view = grown(VIEW, VIEW_PAD)
    lo_x, hi_x = min(p[0] for p in view), max(p[0] for p in view)
    lo_z, hi_z = min(p[1] for p in view), max(p[1] for p in view)
    old = Grid(4.0)
    for x, z in old_trees():
        old.add(x, z)
    trees = Grid(5.0)
    count = 0

    # 1) деревья с подлеском
    for _ in range(90000):
        x, z = rnd.uniform(lo_x, hi_x), rnd.uniform(lo_z, hi_z)
        if not inside(view, x, z) or in_clearing(x, z) or stream_gap(x, z) < 3.2:
            continue
        if old.near(x, z, 3.8) or trees.near(x, z, SPACING * rnd.uniform(0.85, 1.15)):
            continue
        trees.add(x, z)
        count += 1
        gap = clearing_gap(x, z)
        edge = gap < 6.0
        # ближе к камере (+x, +z) высокие кроны закрыли бы частокол — опушка там ниже
        near_camera = (z > 15.0 or x > 45.0) and gap < 11.0
        shrink = (0.62 if near_camera else 0.8) if edge or near_camera else 1.0
        if rnd.random() < (0.35 if edge else 0.2):
            put("birch", x, z, rnd.uniform(7.0, 10.5) * shrink, rnd.uniform(0, math.tau))
        else:
            put("spruce", x, z, rnd.uniform(6.0, 12.5) * shrink, rnd.uniform(0, math.tau))
        for _k in range(rnd.randint(2, 5)):
            a, r = rnd.uniform(0, math.tau), rnd.uniform(0.8, 2.6)
            px, pz = x + math.cos(a) * r, z + math.sin(a) * r
            if in_yard(px, pz) or stream_gap(px, pz) < 1.8:
                continue
            roll = rnd.random()
            if roll < 0.5:
                put("fern", px, pz, rnd.uniform(0.8, 1.3), rnd.uniform(0, math.tau))
            elif roll < 0.85:
                put("sedge", px, pz, rnd.uniform(0.6, 1.0), rnd.uniform(0, math.tau))
            else:
                put("spruce", px, pz, rnd.uniform(1.4, 2.6), rnd.uniform(0, math.tau))

    # 2) камни: группы на поляне и одиночные валуны на опушке
    stones = Grid(4.0)

    def free_ground(x: float, z: float, keep: float) -> bool:
        return not in_yard(x, z) and stream_gap(x, z) > 2.6 and not stones.near(x, z, keep)

    groups = 0
    for _ in range(4000):
        if groups >= 18:
            break
        x, z = rnd.uniform(-3.0, 53.0), rnd.uniform(-24.0, 18.0)
        if not in_clearing(x, z) or not free_ground(x, z, 7.0) or trees.near(x, z, 2.5):
            continue
        groups += 1
        main_kind = rnd.choice(["rock_boulder", "rock_boulder", "rock_split", "rock_slab", "rock_cluster"])
        put(main_kind, x, z, rnd.uniform(0.85, 1.3), rnd.uniform(0, math.tau), 0.0)
        stones.add(x, z)
        for _k in range(rnd.randint(1, 3)):
            a, r = rnd.uniform(0, math.tau), rnd.uniform(1.0, 1.9)
            px, pz = x + math.cos(a) * r, z + math.sin(a) * r
            if in_yard(px, pz) or stream_gap(px, pz) < 2.2:
                continue
            put(rnd.choice(["rock_flat", "rock_flat", "rock_cluster"]), px, pz, rnd.uniform(0.4, 0.75),
                rnd.uniform(0, math.tau), 0.0)
    singles = 0
    for _ in range(6000):
        if singles >= 34:
            break
        x, z = rnd.uniform(lo_x, hi_x), rnd.uniform(lo_z, hi_z)
        if in_clearing(x, z) or clearing_gap(x, z) > 16.0 or not inside(view, x, z):
            continue
        if not free_ground(x, z, 4.5) or trees.near(x, z, 1.6):
            continue
        singles += 1
        stones.add(x, z)
        put(rnd.choice(["rock_boulder", "rock_flat", "rock_split", "rock_cluster"]), x, z,
            rnd.uniform(0.6, 1.15), rnd.uniform(0, math.tau), 0.0)

    # 3) куртины травы на поляне, гуще у частокола и в «кармане» двора у терема
    clumps = 0
    for _ in range(8000):
        if clumps >= 150:
            break
        x, z = rnd.uniform(-3.0, 53.0), rnd.uniform(-24.0, 18.0)
        if not in_clearing(x, z) or in_yard(x, z) or stream_gap(x, z) < 1.6:
            continue
        clumps += 1
        radius = rnd.uniform(0.9, 2.3)
        ferny = rnd.random() < 0.25
        for _k in range(rnd.randint(10, 24)):
            a = rnd.uniform(0, math.tau)
            r = radius * math.sqrt(rnd.random())
            px, pz = x + math.cos(a) * r, z + math.sin(a) * r
            if in_yard(px, pz) or stream_gap(px, pz) < 1.5 or stones.near(px, pz, 0.7):
                continue
            if ferny and rnd.random() < 0.6:
                put("fern", px, pz, rnd.uniform(0.7, 1.2), rnd.uniform(0, math.tau))
            else:
                put("sedge" if rnd.random() < 0.6 else "seed_grass", px, pz, rnd.uniform(0.65, 1.25),
                    rnd.uniform(0, math.tau))

    lines = ['[gd_resource type="Resource" script_class="CourtyardForestLayout" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://src/view/courtyard_forest_layout.gd" id="1"]', "", "[resource]",
             'script = ExtResource("1")', "placements = Dictionary[String, Array]({"]
    kinds = sorted(placed)
    for i, kind in enumerate(kinds):
        sep = "," if i < len(kinds) - 1 else ""
        lines.append(f'"{kind}": Array[Transform3D]([' + ",\n".join(placed[kind]) + f"]){sep}")
    lines.append("})")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"[ritual fill] {OUT.relative_to(ROOT)}: деревьев {count}, групп камней {groups}, валунов {singles}, "
          f"куртин {clumps}; " + ", ".join(f"{k} {len(v)}" for k, v in sorted(placed.items())))


if __name__ == "__main__":
    main()
