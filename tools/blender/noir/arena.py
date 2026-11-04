"""Окружение арены «нуар» по new_concept/05_arena.jpg: частокол, ворота в чащу с глазами, жаровни по углам,
ели и берёзы, замшелые камни, тёмная земля. Масштаб игры: клетка 2 м, поле X 0..18, Y 0..20 (Blender).

blender -b --factory-startup -P tools/blender/noir/arena.py -- [--render]
Экспорт: assets/noir/arena/noir_arena.glb (без камер/света; свет жаровен — OmniLight3D в Godot, точки печатаются).
Следующий шаг (ночная сессия): подключить в scenes/match_arena_3d.tscn вместо forest_arena, единая сцена двух арен.
"""
import math
import random
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit  # noqa: E402
from kit import M, box, cyl, sphere, tube, join_all  # noqa: E402

BOARD = (0.0, 0.0, 18.0, 20.0)  # x0, y0, x1, y1
MARGIN = 1.2                     # частокол — в метре с лишним от края поля
GATE_X = 3.0                     # ворота сверху слева (вход дороги, как на концепте)


def palisade():
    x0, y0, x1, y1 = BOARD[0] - MARGIN, BOARD[1] - MARGIN, BOARD[2] + MARGIN, BOARD[3] + MARGIN
    rnd = random.Random(11)
    sides = [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]
    k = 0
    for (ax, ay), (bx, by) in sides:
        length = math.hypot(bx - ax, by - ay)
        n = int(length / 0.34)
        for i in range(n):
            t = (i + 0.5) / n
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            if abs(y - y1) < 0.01 and abs(x - GATE_X) < 1.6:
                continue  # проём ворот
            big = i % 12 == 0
            h = (2.3 if big else rnd.uniform(1.45, 1.8))
            cyl(f"pal_{k}", 0.17 if big else 0.14, 0.15 if big else 0.13, h, (x, y, h / 2), M("oak_dark"), 7)
            cyl(f"pal_tip_{k}", 0.14, 0.0, 0.3, (x, y, h + 0.15), M("oak_dark"), 7)
            if big:
                box(f"pal_cap_{k}", (0.36, 0.36, 0.08), (x, y, h - 0.25), M("oak"), 0.02)
            k += 1
        for z in (0.5, 1.1):  # поперечные жерди
            tube(f"rail_{k}_{z}", [(ax, ay, z), (bx, by, z)], 0.05, M("oak"), 5)


def gate():
    y = BOARD[3] + MARGIN
    for sx in (-1, 1):
        cyl(f"gate_post_{sx}", 0.22, 0.2, 3.2, (GATE_X + sx * 1.5, y, 1.6), M("oak_dark"), 8)
        sphere(f"gate_skull_{sx}", 0.16, (GATE_X + sx * 1.5, y - 0.18, 2.9), M("cloth_white"), 8, 6)
    box("gate_beam", (3.6, 0.3, 0.3), (GATE_X, y, 3.15), M("oak_dark"), 0.03)
    box("gate_roof", (3.9, 0.7, 0.12), (GATE_X, y, 3.4), M("shingle"), 0.02)
    # чаща за воротами: тёмные ели и светящиеся глаза
    rnd = random.Random(5)
    for k in range(7):
        ex, ez = GATE_X + rnd.uniform(-1.2, 1.2), rnd.uniform(0.8, 2.2)
        for sx in (-1, 1):
            sphere(f"eye_{k}_{sx}", 0.05, (ex + sx * 0.09, y + 2.0 + rnd.uniform(0, 1.5), ez), M("ember"), 6, 4)


def brazier(name, x, y):
    cyl(f"{name}_leg", 0.12, 0.18, 1.0, (x, y, 0.5), M("iron"), 8)
    cyl(f"{name}_bowl", 0.22, 0.45, 0.35, (x, y, 1.15), M("iron"), 12)
    cyl(f"{name}_coals", 0.4, 0.4, 0.05, (x, y, 1.3), M("ember"), 12)
    cyl(f"{name}_flame", 0.3, 0.0, 0.7, (x, y, 1.65), M("glow_svarog"), 10)
    return (x, y, 1.7)


def pine(name, x, y, s):
    cyl(f"{name}_trunk", 0.18 * s, 0.12 * s, 2.0 * s, (x, y, 1.0 * s), M("oak_dark"), 6)
    for k, (z, r) in enumerate(((1.4, 1.5), (2.5, 1.2), (3.5, 0.9), (4.4, 0.6), (5.1, 0.32))):
        cyl(f"{name}_c{k}", r * s, 0.05 * s, 1.5 * s, (x, y, z * s), M("moss"), 8)


def birch(name, x, y, s):
    cyl(f"{name}_trunk", 0.12 * s, 0.08 * s, 4.0 * s, (x, y, 2.0 * s), M("birch"), 8)
    for k in range(3):
        sphere(f"{name}_leaf{k}", 0.9 * s, (x + (k - 1) * 0.5 * s, y, (3.6 + k * 0.5) * s), M("moss"), 8, 6,
               (1.0, 1.0, 0.8))


def forest():
    rnd = random.Random(3)
    x0, y0, x1, y1 = BOARD[0] - 3, BOARD[1] - 3, BOARD[2] + 3, BOARD[3] + 3
    k = 0
    for ring in range(3):
        pad = 3 + ring * 3.5
        n = 22 + ring * 8
        for i in range(n):
            t = i / n
            per = 2 * ((x1 - x0) + (y1 - y0))
            d = t * per
            if d < x1 - x0:
                x, y = x0 + d, y0 - pad
            elif d < (x1 - x0) + (y1 - y0):
                x, y = x1 + pad, y0 + d - (x1 - x0)
            elif d < 2 * (x1 - x0) + (y1 - y0):
                x, y = x1 - (d - (x1 - x0) - (y1 - y0)), y1 + pad
            else:
                x, y = x0 - pad, y1 - (d - 2 * (x1 - x0) - (y1 - y0))
            x += rnd.uniform(-1.2, 1.2)
            y += rnd.uniform(-1.2, 1.2)
            s = rnd.uniform(0.8, 1.35)
            (birch if rnd.random() < 0.22 else pine)(f"tree_{k}", x, y, s)
            k += 1
    for j in range(40):  # замшелые камни вдоль частокола
        x = rnd.uniform(x0 - 2, x1 + 2)
        y = rnd.choice([rnd.uniform(y0 - 2, y0), rnd.uniform(y1, y1 + 2)])
        sphere(f"rock_{j}", rnd.uniform(0.3, 0.8), (x, y, 0.1), rnd.choice([M("stone"), M("stone_c"), M("moss")]),
               8, 6, (1.3, 1.0, 0.6))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    kit.reset()
    box("ground", (90, 90, 0.2), (9, 10, -0.12), M("stone_b"))
    palisade()
    gate()
    lights = [brazier(f"brz_{i}", x, y) for i, (x, y) in enumerate(
        [(BOARD[0] - 0.6, BOARD[1] - 0.6), (BOARD[2] + 0.6, BOARD[1] - 0.6),
         (BOARD[0] - 0.6, BOARD[3] + 0.6), (BOARD[2] + 0.6, BOARD[3] + 0.6)])]
    forest()
    ob = join_all("noir_arena", split_plate=False)
    print("[arena] треугольников:", kit.tri_count(ob), "жаровни (Blender XYZ):", lights)
    out = kit.ROOT / "assets" / "noir" / "arena" / "noir_arena.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out), use_selection=True, export_apply=True, export_cameras=False,
                              export_lights=False, export_yup=True)
    print("[arena] ->", out)
    if "--render" in argv:
        kit.setup_render(res=(1536, 864), elevation=55.0, azimuth=0.0, ortho=34.0, look_z=0.0)
        bpy.context.scene.camera.location.x += 9
        bpy.context.scene.camera.location.y += 10
        for i, p in enumerate(lights):
            kit.point_light(f"brz_light_{i}", (p[0], p[1], p[2] + 0.6), (1.0, 0.5, 0.15), 300.0, 0.3)
        kit.render(kit.ROOT / "new_concept" / "compare" / "renders" / "arena_preview.png")


main()
