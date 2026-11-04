"""Деревья и частокол арены кодом (не нейросетью): ель, берёза, звено частокола, столб, папоротник.

blender -b --factory-startup -P tools/blender/noir/trees.py -- [pine birch palisade palisade_post fern] [--no-export]
Ель — ствол с корой и мутовки веток-карточек (ветка ели с прозрачностью, крест из двух карточек),
ветки к верхушке короче и круче. Берёза — белый ствол с изгибом, тонкие сучья и пучки листвы-карточек.
Частокол — заострённые брёвна разной высоты на двух поперечинах. Фактуры — tools/concepts/foliage_gen.py
и texture_gen.py. Нормали карточек — «от оси дерева», чтобы крона освещалась объёмно, а не плоскими листами.
GLB → assets/noir_h3d/arena/<id>.glb (их берёт NoirArena3D), превью — new_concept/compare/renders/<id>_tree.png.
"""
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import kit  # noqa: E402

FOLIAGE = kit.ROOT / "source_art" / "noir" / "foliage"
TEXTURES = kit.ROOT / "source_art" / "noir" / "textures"
OUT = kit.ROOT / "assets" / "noir_h3d" / "arena"
RENDERS = kit.ROOT / "new_concept" / "compare" / "renders"


def image_mat(name: str, path: Path, tint=(1, 1, 1), alpha: bool = False, rough: float = 0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(str(path), check_existing=False)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(t.outputs["Color"], mix.inputs["A"])
    mix.inputs["B"].default_value = (*tint, 1.0)
    nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rough
    if alpha:
        nt.links.new(t.outputs["Alpha"], p.inputs["Alpha"])
        m.blend_method = "CLIP" if hasattr(m, "blend_method") else None
        try:
            m.surface_render_method = "DITHERED"
        except AttributeError:
            pass
        m.use_backface_culling = False
    return m


class Builder:
    """Сетка из четырёхугольников с UV и своими нормалями (нормаль задаётся на вершину)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.normals = []  # по петлям, в порядке граней
        self.mat_index = []

    def quad(self, pts, uvs, normals, mat: int = 0):
        verts = [self.bm.verts.new(p) for p in pts]
        face = self.bm.faces.new(verts)
        face.material_index = mat
        for loop, uv in zip(face.loops, uvs):
            loop[self.uv].uv = uv
        self.normals.append(normals)

    def finish(self, name: str, mats):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        for m in mats:
            me.materials.append(m)
        loops = []
        for poly in me.polygons:
            loops.extend(self.normals[poly.index])
        if hasattr(me, "use_auto_smooth"):
            me.use_auto_smooth = True
        me.normals_split_custom_set([tuple(n) for n in loops])
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def trunk(b: Builder, points, radii, mat: int, sides: int = 9, v_scale: float = 0.6):
    """Ствол/сук: кольца по точкам оси, UV — вокруг и вдоль (кора повторяется)."""
    along = 0.0
    rings = []
    for i, (p, r) in enumerate(zip(points, radii)):
        if i > 0:
            along += (Vector(p) - Vector(points[i - 1])).length
        d = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        side = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))).normalized()
        up = side.cross(d).normalized()
        ring = []
        for k in range(sides + 1):
            a = 2 * math.pi * k / sides
            n = side * math.cos(a) + up * math.sin(a)
            ring.append((Vector(p) + n * r, n, (k / sides * max(1.0, r * 6), along * v_scale)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            a, bb, c, d = rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]
            b.quad([a[0], bb[0], c[0], d[0]], [a[2], bb[2], c[2], d[2]], [a[1], bb[1], c[1], d[1]], mat)


def card(b: Builder, root: Vector, direction: Vector, length: float, width: float, roll: float, axis_n,
         mat: int, uv_box=(0, 0, 1, 1), droop: float = 0.0):
    """Карточка ветки: от корня вдоль direction, ширина поперёк; roll — поворот вокруг своей оси.
    Нормали — наружу от оси дерева с подъёмом (axis_n — функция точки)."""
    d = direction.normalized()
    side = d.cross(Vector((0, 0, 1))).normalized() if abs(d.z) < 0.98 else Vector((1, 0, 0))
    side = Matrix.Rotation(roll, 3, d) @ side
    u0, v0, u1, v1 = uv_box
    segs = 3
    rows = []
    for s in range(segs + 1):
        t = s / segs
        c = root + d * length * t - Vector((0, 0, droop * t * t * length))
        rows.append((c - side * width * 0.5, c + side * width * 0.5, u0 + (u1 - u0) * t))
    for s in range(segs):
        a0, a1, ua = rows[s]
        b0, b1, ub = rows[s + 1]
        pts = [a0, b0, b1, a1]
        b.quad(pts, [(ua, v1), (ub, v1), (ub, v0), (ua, v0)], [axis_n(p) for p in pts], mat)


def pine(seed: int = 3, height: float = 10.5):
    rnd = random.Random(seed)
    b = Builder()
    pts = [(0, 0, z) for z in (0.0, 0.6, 2.5, 5.0, 7.5, height)]
    trunk(b, pts, [0.32, 0.26, 0.21, 0.15, 0.09, 0.02], 0, sides=10)

    def normal_at(p):
        out = Vector((p.x, p.y, 0.0))
        out = out.normalized() if out.length > 1e-4 else Vector((1, 0, 0))
        return (out * 0.75 + Vector((0, 0, 0.65))).normalized()

    z = 1.4
    whorl = 0
    # ветка на текстуре идёт от левого края вправо и свисает: u — вдоль ветки, v — поперёк
    while z < height - 0.4:
        h = (z - 1.4) / (height - 1.8)
        length = 0.5 + 3.0 * (1.0 - h) ** 1.05
        count = 7 if h < 0.7 else 5
        for k in range(count):
            a = 2 * math.pi * k / count + whorl * 2.4 + rnd.uniform(-0.25, 0.25)
            tilt = math.radians(rnd.uniform(4, 14) - 10 * h)
            d = Vector((math.cos(a) * math.cos(tilt), math.sin(a) * math.cos(tilt), -math.sin(tilt)))
            root = Vector((0, 0, z)) + d * 0.08
            ln = length * rnd.uniform(0.85, 1.1)
            w = ln * 0.55
            card(b, root, d, ln, w, rnd.uniform(-0.25, 0.25), normal_at, 1, droop=0.22)
            card(b, root, d, ln * 0.9, w * 0.7, math.pi / 2, normal_at, 1, droop=0.22)
        z += 0.42 + 0.15 * (1.0 - h) + rnd.uniform(-0.06, 0.06)
        whorl += 1
    for k in range(3):  # макушка — пучок вертикальных карточек
        a = k * math.pi / 3
        d = Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 1.0))
        card(b, Vector((0, 0, height - 1.2)), d, 1.5, 0.6, a, normal_at, 1)
    bark = image_mat("pine_bark", FOLIAGE / "pine_bark.png", tint=(0.7, 0.66, 0.62))
    needles = image_mat("spruce_needles", FOLIAGE / "spruce_branch.png", tint=(0.85, 0.95, 0.95), alpha=True)
    return b.finish("pine", [bark, needles])


def birch(seed: int = 5, height: float = 9.0):
    rnd = random.Random(seed)
    b = Builder()
    lean = Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0))
    axis = [Vector((0, 0, 0)) + lean * (t * t) + Vector((0, 0, height * t)) for t in (0, 0.15, 0.35, 0.55, 0.75, 1.0)]
    trunk(b, [tuple(p) for p in axis], [0.2, 0.17, 0.14, 0.11, 0.07, 0.02], 0, sides=9, v_scale=0.35)
    crown = []
    for k in range(9):  # сучья из верхней половины
        t = rnd.uniform(0.4, 0.75)
        base = axis[0].lerp(axis[-1], t) + lean * (t * t - t)
        a = rnd.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), rnd.uniform(0.5, 1.1))).normalized()
        ln = rnd.uniform(0.8, 1.4)
        tip = base + d * ln
        trunk(b, [tuple(base), tuple(base.lerp(tip, 0.5)), tuple(tip)], [0.045, 0.03, 0.01], 0, sides=5)
        crown.append(tip)
    center = axis[0].lerp(axis[-1], 0.66)

    def normal_at(p):
        out = p - center
        return out.normalized() if out.length > 1e-4 else Vector((0, 0, 1))

    for k in range(72):  # пучки листвы по овалу кроны (берёза на концепте — высокая узкая крона)
        a = rnd.uniform(0, 2 * math.pi)
        e = rnd.uniform(-0.8, 1.0)
        r = Vector((math.cos(a) * math.cos(e) * 2.0, math.sin(a) * math.cos(e) * 2.0, math.sin(e) * 3.0))
        at = center + r * rnd.uniform(0.45, 1.0)
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.6))).normalized()
        size = rnd.uniform(1.4, 2.2)
        # карточка «стоит»: текстура пучка растёт снизу вверх — корень внизу карточки
        root = at - Vector((0, 0, size * 0.5))
        card(b, root, Vector((d.x * 0.3, d.y * 0.3, 1.0)), size, size, rnd.uniform(0, math.pi), normal_at, 1,
             uv_box=(0, 1, 1, 0))
    bark = image_mat("birch_bark", FOLIAGE / "birch_bark.png", tint=(0.9, 0.9, 0.88))
    leaves = image_mat("birch_leaves", FOLIAGE / "birch_leaves.png", tint=(0.78, 0.8, 0.72), alpha=True)
    return b.finish("birch", [bark, leaves])


def _log(b: Builder, x: float, y: float, h: float, r: float, rnd, mat: int):
    lean = (rnd.uniform(-0.02, 0.02), rnd.uniform(-0.02, 0.02))
    pts = [(x, y, 0.0), (x + lean[0] * h, y + lean[1] * h, h)]
    tip = (x + lean[0] * (h + r * 2.4), y + lean[1] * (h + r * 2.4), h + r * 2.4)
    trunk(b, pts + [tip], [r, r * 0.95, 0.01], mat, sides=8, v_scale=0.45)


def palisade(seed: int = 9, length: float = 2.2):
    """Звено частокола вдоль X: заострённые брёвна вплотную и две поперечины изнутри (+Y — внутрь двора)."""
    rnd = random.Random(seed)
    b = Builder()
    n = 9
    for i in range(n):
        x = -length / 2 + length * (i + 0.5) / n
        _log(b, x, 0.0, rnd.uniform(1.75, 2.05), length / n * 0.56, rnd, 0)
    for z in (0.55, 1.45):
        trunk(b, [(-length / 2, 0.16, z), (length / 2, 0.16, z)], [0.07, 0.07], 0, sides=6, v_scale=0.4)
    wood = image_mat("palisade_wood", TEXTURES / "bark.png", tint=(0.52, 0.42, 0.34))
    return b.finish("palisade", [wood])


def palisade_post(seed: int = 4):
    rnd = random.Random(seed)
    b = Builder()
    _log(b, 0, 0, 2.35, 0.2, rnd, 0)
    for z in (0.7, 1.7):  # железные обручи
        trunk(b, [(0, 0, z), (0, 0, z + 0.07)], [0.215, 0.215], 1, sides=10)
    wood = image_mat("post_wood", TEXTURES / "bark.png", tint=(0.42, 0.34, 0.28))
    iron = kit.mat("post_iron", (0.08, 0.08, 0.09), rough=0.5, metal=0.8)
    return b.finish("palisade_post", [wood, iron])


def color_mat(name: str, color, rough: float = 0.8, emit: float = 0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Roughness"].default_value = rough
    if emit > 0:
        p.inputs["Emission Color"].default_value = (*color, 1.0)
        p.inputs["Emission Strength"].default_value = emit
    return m


def frond(b: Builder, yaw: float, length: float, rise: float, droop: float, mat: int, twist: float = 0.0):
    """Вайя: изогнутая полоса от центра куста — поднимается и свисает к кончику (стебель — по V текстуры)."""
    out = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    side = Vector((-out.y, out.x, 0.0))
    side = Matrix.Rotation(twist, 3, out) @ side
    width = length * 0.56
    segs = 6
    rows = []
    for s in range(segs + 1):
        t = s / segs
        c = out * length * t + Vector((0, 0, rise * t - droop * t * t))
        # лист шире к середине — полоса прямая, форму даёт прозрачность текстуры
        rows.append((c - side * width * 0.5, c + side * width * 0.5, t))
    for s in range(segs):
        a0, a1, va = rows[s]
        b0, b1, vb = rows[s + 1]
        pts = [a0, b0, b1, a1]
        n = (out * 0.25 + Vector((0, 0, 1))).normalized()
        b.quad(pts, [(0, va), (0, vb), (1, vb), (1, va)], [n] * 4, mat)


def fern(seed: int = 11):
    """Куст папоротника как на концепте арены: ~1,7 м в ширину, вайи веером, пара рыжих грибов."""
    rnd = random.Random(seed)
    b = Builder()
    rings = ((15, 0.85, 1.05, 0.7, 0.9, 0.75, 0.95),   # внешний круг — длинные, пологие, свисают
             (10, 0.7, 0.9, 1.0, 1.25, 0.6, 0.8),      # средний
             (7, 0.5, 0.65, 1.4, 1.7, 0.45, 0.6))      # внутренний — короче и круче, держат объём сверху
    for ring, (count, l0, l1, r0, r1, d0, d1) in enumerate(rings):
        for k in range(count):
            yaw = 2 * math.pi * (k + ring * 0.37) / count + rnd.uniform(-0.15, 0.15)
            ln = rnd.uniform(l0, l1)
            frond(b, yaw, ln, ln * rnd.uniform(r0, r1), ln * rnd.uniform(d0, d1), 0, rnd.uniform(-0.4, 0.4))
    for k in range(3):  # грибы у корня
        a = rnd.uniform(0, 2 * math.pi)
        at = Vector((math.cos(a), math.sin(a), 0)) * rnd.uniform(0.5, 0.62)
        h = rnd.uniform(0.08, 0.14)
        trunk(b, [tuple(at), tuple(at + Vector((0, 0, h)))], [0.022, 0.018], 1, sides=6)
        cap = at + Vector((0, 0, h))
        trunk(b, [tuple(cap - Vector((0, 0, 0.02))), tuple(cap + Vector((0, 0, 0.03))), tuple(cap + Vector((0, 0, 0.06)))],
              [0.07, 0.06, 0.005], 2, sides=8)
    leaf = image_mat("fern_frond", FOLIAGE / "fern_frond.png", tint=(0.85, 0.92, 0.8), alpha=True)
    stem = color_mat("fern_stem", (0.82, 0.72, 0.55))
    cap = color_mat("fern_cap", (0.75, 0.33, 0.1), emit=0.15)
    return b.finish("fern", [leaf, stem, cap])


BUILD = {"pine": pine, "birch": birch, "palisade": palisade, "palisade_post": palisade_post, "fern": fern}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    no_export = "--no-export" in argv
    ids = [a for a in argv if not a.startswith("--")] or list(BUILD)
    for mid in ids:
        kit.reset()
        ob = BUILD[mid]()
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        h = max((ob.matrix_world @ Vector(c)).z for c in ob.bound_box)
        kit.setup_render(res=(600, 800), elevation=24.0, azimuth=-35.0, ortho=h * 1.15 + 1.0, look_z=h * 0.5)
        kit.render(RENDERS / f"{mid}_tree.png")
        print(f"[trees] {mid}: {tris} треуг., высота {h:.1f} м")
        if not no_export:
            OUT.mkdir(parents=True, exist_ok=True)
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            out = OUT / f"{mid}.glb"
            bpy.ops.export_scene.gltf(filepath=str(out), use_selection=True, export_apply=True, export_cameras=False,
                                      export_lights=False, export_yup=True, export_animations=False,
                                      export_image_format="AUTO")
            print("[trees] ->", out)


main()
