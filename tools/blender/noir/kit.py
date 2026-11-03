"""Общий набор «славянского нуара» для моделей Заставы (Blender 5.x, фоновый режим).

Модель строится кодом: build/<группа>.py вызывает функции отсюда.
Запуск: blender -b --factory-startup -P tools/blender/noir/run.py -- <id> [--no-export]
Масштаб: 1 единица = 1 м, клетка поля 2 м. Фронт модели смотрит на -Y (в Godot на +Z, к камере).
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
CELL = 2.0
PLATE_H = 0.26
# Высота постройки (от земли до макушки) по уровню: I ≈ 1 клетка, II ≈ 1,4, III ≈ 1,8.
TIER_HEIGHT = {1: 2.0, 2: 2.8, 3: 3.6}
HUMAN_H = 1.7   # рост юнита-человека
HERO_H = 2.0    # рост героя

# Свечение школ (линейный RGB) и цвет знака на плите.
SCHOOL_GLOW = {
    "perun": (0.3, 0.14, 1.0), "svarog": (1.0, 0.36, 0.08), "stribog": (0.25, 1.0, 0.55),
    "water": (0.1, 0.85, 0.9), "ice": (0.7, 0.9, 1.0), "war": (0.75, 0.08, 0.05),
    "curse": (0.62, 0.2, 1.0), "neutral": (1.0, 0.66, 0.22),
}

_MATS: dict = {}


# ---------------------------------------------------------------- сцена

def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    random.seed(7)


def mat(name: str, color=(0.5, 0.5, 0.5), rough: float = 0.8, metal: float = 0.0,
        emit=None, strength: float = 0.0, alpha: float = 1.0):
    """Материал библиотеки: одно имя — один материал на все модели."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit is not None:
        p.inputs["Emission Color"].default_value = (*emit, 1.0)
        p.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    _MATS[name] = m
    return m


def M(key: str):
    """Общая библиотека материалов (имена стабильные — их видно в Godot)."""
    lib = {
        "oak": dict(color=(0.14, 0.065, 0.035), rough=0.82),
        "oak_dark": dict(color=(0.075, 0.03, 0.022), rough=0.85),
        "oak_warm": dict(color=(0.2, 0.075, 0.035), rough=0.78),
        "oak_warm_dark": dict(color=(0.08, 0.03, 0.015), rough=0.8),
        "birch": dict(color=(0.75, 0.72, 0.64), rough=0.75),
        "shingle": dict(color=(0.055, 0.055, 0.065), rough=0.6),
        "stone": dict(color=(0.075, 0.075, 0.09), rough=0.85),
        "stone_b": dict(color=(0.045, 0.045, 0.055), rough=0.85),
        "stone_c": dict(color=(0.1, 0.095, 0.105), rough=0.85),
        "stone_warm": dict(color=(0.13, 0.05, 0.035), rough=0.85),
        "moss": dict(color=(0.07, 0.13, 0.03), rough=0.95),
        "iron": dict(color=(0.11, 0.11, 0.12), rough=0.5, metal=0.5),
        "steel": dict(color=(0.2, 0.2, 0.23), rough=0.35, metal=0.6),
        "silver": dict(color=(0.8, 0.8, 0.86), rough=0.2, metal=0.7, emit=(0.55, 0.55, 0.7), strength=0.35),
        "gold": dict(color=(0.75, 0.42, 0.1), rough=0.3, metal=0.7),
        "brass": dict(color=(0.55, 0.32, 0.1), rough=0.4, metal=0.6),
        "rope": dict(color=(0.32, 0.24, 0.13), rough=0.95),
        "leather": dict(color=(0.08, 0.04, 0.022), rough=0.7),
        "leather_dark": dict(color=(0.05, 0.03, 0.02), rough=0.7),
        "skin": dict(color=(0.5, 0.3, 0.21), rough=0.6),
        "hair_brown": dict(color=(0.08, 0.045, 0.025), rough=0.7),
        "cloth_red": dict(color=(0.26, 0.022, 0.018), rough=0.85),
        "cloth_red_dark": dict(color=(0.2, 0.02, 0.015), rough=0.85),
        "cloth_dark": dict(color=(0.04, 0.04, 0.045), rough=0.9),
        "cloth_white": dict(color=(0.36, 0.31, 0.24), rough=0.9),
        "chainmail": dict(color=(0.13, 0.13, 0.14), rough=0.5, metal=0.5),
        "helm_steel": dict(color=(0.45, 0.45, 0.5), rough=0.28, metal=0.85),
        "window": dict(color=(1.0, 0.45, 0.1), rough=0.5, emit=(1.0, 0.32, 0.03), strength=0.75),
        "window_core": dict(color=(1.0, 0.6, 0.2), rough=0.5, emit=(1.0, 0.55, 0.12), strength=1.3),
        "ember": dict(color=(1.0, 0.3, 0.05), rough=0.5, emit=(1.0, 0.3, 0.05), strength=8.0),
    }
    if key.startswith("glow_"):
        school = key[5:]
        c = SCHOOL_GLOW[school]
        return mat(key, color=c, rough=0.4, emit=c, strength=0.85)
    return mat(key, **lib[key])


# ---------------------------------------------------------------- примитивы

def _obj(name: str, bm: bmesh.types.BMesh, material, loc, rot, parent=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if material is not None:
        ob.data.materials.append(material)
    ob.location = loc
    ob.rotation_euler = Euler(rot)
    if parent is not None:
        ob.parent = parent
    return ob


def bevel(ob, width: float, segments: int = 1):
    if width <= 0:
        return ob
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = False
    return ob


def box(name, size, loc=(0, 0, 0), material=None, bev: float = 0.0, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    return bevel(_obj(name, bm, material, loc, rot), bev)


def cyl(name, r1, r2, depth, loc=(0, 0, 0), material=None, verts: int = 12, rot=(0, 0, 0), bev: float = 0.0,
        cap: bool = True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=verts, radius1=r1, radius2=r2, depth=depth)
    ob = _obj(name, bm, material, loc, rot)
    for f in ob.data.polygons:
        f.use_smooth = len(f.vertices) == 4 and verts >= 10
    return bevel(ob, bev)


def sphere(name, r, loc=(0, 0, 0), material=None, seg: int = 12, rings: int = 8, scale=(1, 1, 1), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = _obj(name, bm, material, loc, rot)
    for f in ob.data.polygons:
        f.use_smooth = True
    return ob


def prism(name, points2d, depth, loc=(0, 0, 0), material=None, rot=(0, 0, 0), bev: float = 0.0):
    """Плоская фигура по контуру (в плоскости XY), выдавленная по Z на depth."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for x, y in points2d]
    face = bm.faces.new(vs)
    if face.normal.z < 0:
        face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, depth), verts=top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bevel(_obj(name, bm, material, loc, rot), bev)


def tube(name, points3d, radius, material=None, sides: int = 6, taper: float = 1.0):
    """Трубка по ломаной (ленты, верёвки, разряды)."""
    bm = bmesh.new()
    rings = []
    n = len(points3d)
    for i, p in enumerate(points3d):
        p = Vector(p)
        d = (Vector(points3d[min(i + 1, n - 1)]) - Vector(points3d[max(i - 1, 0)])).normalized()
        up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        a = d.cross(up).normalized()
        b = d.cross(a).normalized()
        r = radius * (1.0 + (taper - 1.0) * i / max(n - 1, 1))
        rings.append([bm.verts.new(p + (a * math.cos(t) + b * math.sin(t)) * r)
                      for t in [2 * math.pi * k / sides for k in range(sides)]])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, material, (0, 0, 0), (0, 0, 0))


def zigzag(start, end, steps: int, amp: float, seed: int = 1):
    """Ломаная молнии между двумя точками."""
    rnd = random.Random(seed)
    s, e = Vector(start), Vector(end)
    d = e - s
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    pts = [s]
    for i in range(1, steps):
        t = i / steps
        pts.append(s + d * t + side * amp * (1 if i % 2 else -1) * rnd.uniform(0.5, 1.0))
    pts.append(e)
    return pts


# ---------------------------------------------------------------- плита и знаки

def _voronoi_cells(sites, half):
    """Многоугольники Вороного в квадрате [-half, half]^2 (отсечение полуплоскостями)."""
    cells = []
    for i, p in enumerate(sites):
        poly = [(-half, -half), (half, -half), (half, half), (-half, half)]
        for j, q in enumerate(sites):
            if i == j:
                continue
            mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
            nx, ny = q[0] - p[0], q[1] - p[1]
            out = []
            for k in range(len(poly)):
                a, b = poly[k], poly[(k + 1) % len(poly)]
                da = (a[0] - mx) * nx + (a[1] - my) * ny
                db = (b[0] - mx) * nx + (b[1] - my) * ny
                if da <= 0:
                    out.append(a)
                if (da < 0) != (db < 0):
                    t = da / (da - db)
                    out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            poly = out
            if not poly:
                break
        cells.append(poly)
    return cells


def cobble(name, poly, inset, z0, z1, material, bev=0.035):
    """Булыжник: многоугольник, сжатый к центру, выдавленный и скруглённый."""
    cx = sum(x for x, _ in poly) / len(poly)
    cy = sum(y for _, y in poly) / len(poly)
    pts = [(cx + (x - cx) * inset, cy + (y - cy) * inset) for x, y in poly]
    ob = prism(name, pts, z1 - z0, (0, 0, z0), material)
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = bev
    mod.segments = 1
    mod.limit_method = "ANGLE"
    return ob


def plate(tier: int, school: str, sign: bool = True, size: float = CELL):
    """Плита постройки ровно в клетку: I — булыжник, II — + каменный бортик, III — + золотая рунная рамка."""
    rnd = random.Random(tier * 31 + len(school))
    half = size / 2
    shades = [M("stone"), M("stone_b"), M("stone_c"), M("stone"), M("stone_b"), M("stone_warm")]
    # тело плиты: тёмный раствор + ряды кирпича по бокам
    box("plate_core", (size - 0.04, size - 0.04, PLATE_H - 0.06), (0, 0, (PLATE_H - 0.06) / 2), M("stone_b"))
    rows, per = 2, 6
    bh = (PLATE_H - 0.07) / rows
    for side in range(4):
        for r in range(rows):
            off = 0.5 if r % 2 else 0.0
            for k in range(per + (1 if off else 0)):
                c = -half + size * (k + 0.5 - off) / per
                lo, hi = max(c - size / per / 2, -half), min(c + size / per / 2, half)
                if hi - lo < 0.05:
                    continue
                w, mid = hi - lo - 0.025, (lo + hi) / 2
                z = 0.01 + bh * (r + 0.5)
                d = 0.07
                if side < 2:
                    y = (-1 if side == 0 else 1) * (half - d / 2 + 0.005)
                    box(f"plate_brick_{side}_{r}_{k}", (w, d, bh - 0.022), (mid, y, z), rnd.choice(shades))
                else:
                    x = (-1 if side == 2 else 1) * (half - d / 2 + 0.005)
                    box(f"plate_brick_{side}_{r}_{k}", (d, w, bh - 0.022), (x, mid, z), rnd.choice(shades))
    # верх: булыжник неправильной формы (ячейки Вороного по сетке с разбросом)
    n = 6
    step = size / n
    sites = [(-half + step * (i + 0.5) + rnd.uniform(-0.3, 0.3) * step,
              -half + step * (j + 0.5) + rnd.uniform(-0.3, 0.3) * step) for i in range(n) for j in range(n)]
    for k, poly in enumerate(_voronoi_cells(sites, half - 0.01)):
        if len(poly) < 3:
            continue
        top_z = PLATE_H + rnd.uniform(-0.02, 0.012)
        cobble(f"plate_{k}", poly, rnd.uniform(0.84, 0.9), PLATE_H - 0.09, top_z, rnd.choice(shades))
    # мох в швах
    for k in range(7):
        x, y = rnd.uniform(-0.85, 0.85), rnd.uniform(-0.85, 0.85)
        sphere(f"moss_{k}", 0.06, (x, y, PLATE_H - 0.01), M("moss"), 6, 4, (1.8, 1.0, 0.4), (0, 0, rnd.uniform(0, 3)))
    top = PLATE_H
    if tier >= 2:
        # каменный бортик: кольцо крупных блоков по краю
        bh2 = 0.14
        seg = 5
        bs = size / seg
        for s in range(seg):
            for side in range(4):
                c = -half + bs * (s + 0.5)
                pos = [(c, -half + 0.11), (c, half - 0.11), (-half + 0.11, c), (half - 0.11, c)][side]
                dims = (bs - 0.04, 0.22, bh2) if side < 2 else (0.22, bs - 0.04, bh2)
                box(f"rim_{side}_{s}", dims, (pos[0], pos[1], top + bh2 / 2 - 0.02), rnd.choice(shades[:3]), 0.035)
        top += bh2 - 0.02
    if tier >= 3:
        # золотая рамка с рунами по углам
        t = 0.06
        for side in range(4):
            if side < 2:
                y = (-1 if side == 0 else 1) * (half - 0.02)
                box(f"gold_{side}", (size, t, 0.1), (0, y, top - 0.02), M("gold"), 0.01)
            else:
                x = (-1 if side == 2 else 1) * (half - 0.02)
                box(f"gold_{side}", (t, size, 0.1), (x, 0, top - 0.02), M("gold"), 0.01)
        for cx in (-1, 1):
            for cy in (-1, 1):
                box(f"rune_{cx}_{cy}", (0.16, 0.16, 0.05), (cx * (half - 0.12), cy * (half - 0.12), top + 0.02),
                    M("gold"), 0.01, (0, 0, math.pi / 4))
                box(f"runeg_{cx}_{cy}", (0.07, 0.07, 0.03), (cx * (half - 0.12), cy * (half - 0.12), top + 0.05),
                    M(f"glow_{school}" if school in SCHOOL_GLOW else "glow_neutral"), 0, (0, 0, math.pi / 4))
    if sign and school in SCHOOL_GLOW:
        # знак школы — на передней кромке плиты, к камере
        sign_mesh(school, (0.0, -half + 0.36, PLATE_H + 0.004), 0.42)
    return top


def _circle(r, n=16, cx=0.0, cy=0.0, a0=0.0):
    return [(cx + r * math.cos(a0 + 2 * math.pi * k / n), cy + r * math.sin(a0 + 2 * math.pi * k / n)) for k in range(n)]


def _bar(x0, y0, x1, y1, w):
    d = Vector((x1 - x0, y1 - y0))
    n = Vector((-d.y, d.x)).normalized() * w / 2
    return [(x0 + n.x, y0 + n.y), (x1 + n.x, y1 + n.y), (x1 - n.x, y1 - n.y), (x0 - n.x, y0 - n.y)]


def sign_shapes(school: str):
    """Контуры знака школы в квадрате [-0.5, 0.5]."""
    if school == "perun":
        return [[(0.12, 0.5), (-0.22, 0.02), (0.02, 0.02), (-0.14, -0.5), (0.24, 0.08), (0.0, 0.08), (0.18, 0.5)]]
    if school == "svarog":
        shapes = [_circle(0.2, 16)]
        for k in range(8):
            a = 2 * math.pi * k / 8
            shapes.append(_bar(0.27 * math.cos(a), 0.27 * math.sin(a), 0.46 * math.cos(a), 0.46 * math.sin(a), 0.08))
        return shapes
    if school == "stribog":
        pts = [(0.04 * t * math.cos(t * 0.9), 0.04 * t * math.sin(t * 0.9)) for t in [i * 0.5 for i in range(2, 22)]]
        return [_bar(*a, *b, 0.07) for a, b in zip(pts, pts[1:])]
    if school == "water":
        out = []
        for row in (-0.16, 0.16):
            pts = [(-0.46 + 0.92 * i / 12, row + 0.1 * math.sin(i / 12 * 2 * math.pi * 1.5)) for i in range(13)]
            out += [_bar(*a, *b, 0.09) for a, b in zip(pts, pts[1:])]
        return out
    if school == "ice":
        out = []
        for k in range(3):
            a = math.pi * k / 3 + math.pi / 2
            out.append(_bar(-0.46 * math.cos(a), -0.46 * math.sin(a), 0.46 * math.cos(a), 0.46 * math.sin(a), 0.07))
            for sgn in (-1, 1):
                bx, by = sgn * 0.28 * math.cos(a), sgn * 0.28 * math.sin(a)
                for t in (-0.6, 0.6):
                    out.append(_bar(bx, by, bx + sgn * 0.14 * math.cos(a + t), by + sgn * 0.14 * math.sin(a + t), 0.05))
        return out
    if school == "war":
        out = []
        for sgn in (-1, 1):
            out.append(_bar(-0.38 * sgn, -0.38, 0.34 * sgn, 0.4, 0.08))
            out.append(_bar(-0.3 * sgn - 0.12, -0.18, -0.3 * sgn + 0.12 * 1, -0.3 - 0.06 * sgn, 0.06))
        return out
    if school == "curse":
        top = [(-0.48 + 0.96 * i / 10, 0.26 * math.sin(math.pi * i / 10)) for i in range(11)]
        bot = [(0.48 - 0.96 * i / 10, -0.26 * math.sin(math.pi * i / 10)) for i in range(1, 10)]
        ring = _circle(0.13, 12)
        return [_bar(*a, *b, 0.06) for a, b in zip(top, top[1:])] + \
               [_bar(*a, *b, 0.06) for a, b in zip([top[-1]] + bot + [top[0]], bot + [top[0]])] + [ring]
    return []


def sign_mesh(school: str, loc, size: float, lift: float = 0.03):
    """Эмиссивный знак, лежащий на плите."""
    for k, pts in enumerate(sign_shapes(school)):
        prism(f"sign_{k}", [(x * size, y * size) for x, y in pts], lift, loc, M(f"glow_{school}"))


# ---------------------------------------------------------------- финал: сборка, рендер, экспорт

PLATE_PREFIXES = ("plate_", "rim_", "gold_", "rune_", "runeg_", "sign_", "moss_")


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob


def join_all(name: str, split_plate: bool = True):
    """Применить модификаторы и слить меши в один объект (один меш — несколько материалов).
    Плита (детали plate()) сливается отдельно в <name>_plate: в игре её ставят под каждую клетку фигуры."""
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.parent is None]
    plate_objs = [o for o in meshes if split_plate and o.name.startswith(PLATE_PREFIXES)]
    model = [o for o in meshes if o not in plate_objs]
    if plate_objs and model:
        _join(plate_objs, f"{name}_plate")
    return _join(model or plate_objs, name)


def tri_count(ob) -> int:
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def setup_render(res=(600, 800), elevation: float = 35.0, azimuth: float = -38.0, target_h: float = 1.5,
                 ortho: float = 4.2, look_z: float = None):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("noir")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.018, 0.02, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = world
    try:
        sc.eevee.use_shadows = True
        sc.eevee.use_raytracing = False
    except AttributeError:
        pass
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    el, az = math.radians(elevation), math.radians(azimuth)
    look = Vector((0, 0, target_h if look_z is None else look_z))
    d = 20.0
    cam.location = look + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * d
    cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    # свет: тёплый ключевой сбоку-спереди, лунный бирюзовый заполняющий, цветной контровой
    _light("key", "SUN", 2.2, (1.0, 0.7, 0.42), (math.radians(50), 0, math.radians(-60)))
    _light("fill", "SUN", 0.3, (0.3, 0.62, 0.75), (math.radians(60), 0, math.radians(70)))
    _light("rim", "SUN", 2.2, (0.45, 0.62, 1.0), (math.radians(-55), 0, math.radians(30)))


def _light(name, kind, energy, color, rot):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "SUN":
        ld.angle = math.radians(3)
    lo = bpy.data.objects.new(name, ld)
    lo.rotation_euler = rot
    bpy.context.scene.collection.objects.link(lo)


def render(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def export(ob, kind: str, name: str):
    out = ROOT / "assets" / "noir" / kind / f"{name}.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for child in ob.children_recursive:
        child.select_set(True)
    if ob.parent is not None:
        ob.parent.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out), use_selection=True, export_apply=True,
                              export_cameras=False, export_lights=False, export_yup=True,
                              export_animations=False, export_image_format="JPEG", export_jpeg_quality=88)
    if kind == "plates":  # плиты пересобираются кодом за секунды — .blend не храним
        return out
    blend = ROOT / "source_art" / "noir" / kind / f"{name}.blend"
    blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), copy=True, compress=True)
    return out


def gable(name, width, height, length, center, material, rotz: float = 0.0, overhang: float = 0.0, thick: float = 0.05):
    """Двускатная кровля: два наклонных ската (с толщиной) вдоль оси X (после поворота rotz)."""
    cx, cy, cz = center
    slope = math.atan2(height, width / 2)
    run = math.hypot(width / 2, height) + overhang
    parts = []
    for sgn in (-1, 1):
        mx = sgn * (width / 4 + overhang * math.cos(slope) / 2)
        mz = height / 2 - overhang * math.sin(slope) / 2
        ob = box(f"{name}_{sgn}", (run, length, thick), (0, 0, 0), material, 0.01)
        ob.rotation_euler = (0, sgn * slope, 0)
        ob.location = (mx, 0, mz)
        parts.append(ob)
    # фронтоны (треугольники стен) — заполняются стеной из того же материала
    rot = Matrix.Rotation(rotz, 4, "Z")
    for ob in parts:
        ob.location = rot @ ob.location + Vector((cx, cy, cz))
        ob.rotation_euler = (rot @ ob.rotation_euler.to_matrix().to_4x4()).to_euler()
    return parts


def gable_wall(name, width, height, length, center, material, rotz: float = 0.0):
    """Треугольная призма под кровлей (фронтоны)."""
    cx, cy, cz = center
    ob = prism(name, [(-width / 2, 0), (width / 2, 0), (0, height)], length, (0, 0, 0), material,
               (math.pi / 2, 0, 0))
    ob.location = Vector((0, length / 2, 0))
    rot = Matrix.Rotation(rotz, 4, "Z")
    ob.location = rot @ ob.location + Vector((cx, cy, cz))
    ob.rotation_euler = (rot @ ob.rotation_euler.to_matrix().to_4x4()).to_euler()
    return ob


def loft(name, rings, material, sides: int = 16, arc=None, cap_top: bool = True, cap_bottom: bool = True,
         smooth: bool = True, weight=None, folds: int = 0, fold_amp: float = 0.0):
    """Тело вращения по сечениям-эллипсам: rings = [(z, rx, ry[, cx, cy]), ...] снизу вверх.
    arc=(a0, a1) — открытая дуга (градусы, 0 = +X, -90 = фронт -Y). weight(z) -> имя кости для вершины."""
    bm = bmesh.new()
    rows = []
    if arc is None:
        angles = [2 * math.pi * k / sides for k in range(sides)]
    else:
        a0, a1 = math.radians(arc[0]), math.radians(arc[1])
        angles = [a0 + (a1 - a0) * k / (sides - 1) for k in range(sides)]
    for ring in rings:
        z, rx, ry = ring[:3]
        cx, cy = (ring[3], ring[4]) if len(ring) > 3 else (0.0, 0.0)
        amp = fold_amp * (ring[5] if len(ring) > 5 else 1.0)
        rows.append([bm.verts.new((cx + rx * math.cos(a) * (1 + amp * math.sin(folds * a)),
                                   cy + ry * math.sin(a) * (1 + amp * math.sin(folds * a)), z)) for a in angles])
    n = len(angles)
    span = n if arc is None else n - 1
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(span):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    if arc is None:
        if cap_bottom:
            bm.faces.new(rows[0][::-1])
        if cap_top:
            bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj(name, bm, material, (0, 0, 0), (0, 0, 0))
    for f in ob.data.polygons:
        f.use_smooth = smooth
    if weight is not None:
        groups = {}
        for v in ob.data.vertices:
            bone = weight(v.co.z)
            groups.setdefault(bone, []).append(v.index)
        for bone, idx in groups.items():
            ob.vertex_groups.new(name=bone).add(idx, 1.0, "REPLACE")
    return ob


def limb_tube(name, points, radii, material, sides: int = 10):
    """Конечность по точкам с переменным радиусом (гладкая)."""
    bm = bmesh.new()
    rings = []
    n = len(points)
    for i, p in enumerate(points):
        p = Vector(p)
        d = (Vector(points[min(i + 1, n - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        up = Vector((0, -1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        a = d.cross(up).normalized()
        b = d.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(t) + b * math.sin(t)) * radii[i])
                      for t in [2 * math.pi * k / sides for k in range(sides)]])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj(name, bm, material, (0, 0, 0), (0, 0, 0))
    for f in ob.data.polygons:
        f.use_smooth = True
    return ob


def point_light(name, loc, color=(1.0, 0.5, 0.15), energy=30.0, radius=0.1):
    """Свет для рендера сравнения (в GLB не экспортируется; в Godot ставится OmniLight3D в той же точке)."""
    ld = bpy.data.lights.new(name, "POINT")
    ld.energy = energy
    ld.color = color
    ld.shadow_soft_size = radius
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    bpy.context.scene.collection.objects.link(lo)
    return lo
