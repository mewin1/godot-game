"""Живность арены: сетки Hunyuan3D (покрашенные) → скелет + анимации → GLB для Godot.

Запуск (фоновый Blender, по одной модели):
  blender -b --factory-startup -P tools/blender/noir/creatures.py -- <id> [--preview]
id: crow_perch, crow_fly, bear_cub. Вход: source_art/noir_h3d/raw/<id>_paint.glb
(tools/concepts/creature_crops.py → h3d_gen.py → h3d_paint.py). Выход: assets/noir/creatures/<id>.glb,
кадры проверки — new_concept/creatures/renders/<id>_*.png.

Скелет простой (в кадре зверь — 30–60 пикселей): веса считаются по положению вершины относительно
частей тела, а не автоматическим «теплом» (сетки Hunyuan не всегда замкнуты). Модель смотрит в +Y Blender
(в Godot это −Z, «вперёд» для look_at), стоит на z = 0.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "source_art" / "noir_h3d" / "raw"
OUT = ROOT / "assets" / "noir" / "creatures"
RENDERS = ROOT / "new_concept" / "creatures" / "renders"
FPS = 30

# поворот сетки Hunyuan к «смотрит в +Y, вверх +Z», итоговая длина (м) вдоль Y, число треугольников
SPECS = {
    "crow_perch": {"rot": (0, 0, 90), "length": 0.84, "faces": 7000, "tex": 1024, "ground": True},
    "crow_fly": {"rot": (-90, 0, 0), "length": 0.84, "faces": 6000, "tex": 1024, "ground": False},
    "bear_cub": {"rot": (0, 0, 90), "length": 1.15, "faces": 12000, "tex": 2048, "ground": True},
}


def smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- сетка

def load_mesh(mid: str) -> bpy.types.Object:
    spec = SPECS[mid]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(RAW / f"{mid}_paint.glb"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # родители-пустышки из glTF — прочь, трансформ — в вершины
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)  # поворот импорта glTF
    rx, ry, rz = (math.radians(a) for a in spec["rot"])
    obj.rotation_mode = "XYZ"  # импорт glTF ставит кватернион — эйлер иначе молча не действует
    obj.rotation_euler = (rx, ry, rz)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    verts = obj.data.vertices
    ys = [v.co.y for v in verts]
    scale = spec["length"] / (max(ys) - min(ys))
    obj.scale = (scale,) * 3
    bpy.ops.object.transform_apply(scale=True)
    lo, hi = bbox(obj)
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z if spec["ground"] else -(lo.z + hi.z) / 2))
    obj.data.transform(Matrix.Translation(shift))
    obj.data.update()
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.ratio = min(1.0, spec["faces"] / max(1, len(obj.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    obj.name = mid
    obj.data.name = mid
    for mat in obj.data.materials:
        mat.name = f"{mid}_skin"
        mat.blend_method = "OPAQUE"
        # у сеток Hunyuan нормали местами внутрь: без двусторонности перо «в дырках»
        mat.use_backface_culling = False
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None:
                img = node.image
                img.name = f"{mid}_skin"
                if img.size[0] > spec["tex"]:
                    img.scale(spec["tex"], spec["tex"])
                if mid.startswith("crow"):
                    darken_feathers(img)
            if node.type == "BSDF_PRINCIPLED":
                # текстура Hunyuan прозрачна между островами развёртки — иначе сквозь перо видно фон
                for link in list(node.inputs["Alpha"].links):
                    mat.node_tree.links.remove(link)
                node.inputs["Alpha"].default_value = 1.0
                node.inputs["Roughness"].default_value = 0.8
                node.inputs["Metallic"].default_value = 0.0
                node.inputs["Specular IOR Level"].default_value = 0.25
    return obj


def darken_feathers(img: bpy.types.Image) -> None:
    """Hunyuan рисует по чёрному перу светлую рябь (блики концепта) — сводим к ровному иссиня-чёрному
    с лёгким следом рисунка: в игре ворона — тёмный силуэт."""
    import numpy as np

    px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    raven = np.array([0.035, 0.038, 0.05], dtype=np.float32)
    luma = px[:, :3] @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    trace = np.clip(luma, 0.0, 0.25)[:, None] * 0.35
    px[:, :3] = raven + trace * np.array([0.9, 0.95, 1.1], dtype=np.float32)
    img.pixels.foreach_set(px.ravel())
    img.update()


def bbox(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


# ---------------------------------------------------------------- скелет

def make_armature(name: str, bones: list[tuple[str, Vector, Vector, str | None]]) -> bpy.types.Object:
    data = bpy.data.armatures.new(f"{name}_rig")
    arm = bpy.data.objects.new(f"{name}_rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, head, tail, parent in bones:
        eb = data.edit_bones.new(bone_name)
        eb.head, eb.tail = head, tail
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind(obj: bpy.types.Object, arm: bpy.types.Object, weigh) -> None:
    """weigh(co) → {кость: вес}; веса нормируются."""
    for bone in arm.data.bones:
        obj.vertex_groups.new(name=bone.name)
    for v in obj.data.vertices:
        w = weigh(v.co)
        total = sum(w.values()) or 1.0
        for bone_name, value in w.items():
            if value > 1e-4:
                obj.vertex_groups[bone_name].add([v.index], value / total, "REPLACE")
    obj.parent = arm
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = arm


def animate(arm: bpy.types.Object, name: str, seconds: float, pose, loop: bool = True) -> None:
    """pose(t в 0..1) → {кость: (ось в пространстве скелета, угол, сдвиг)}; кадры через матрицы,
    чтобы не думать о локальных осях костей. Поворот — вокруг головы кости, наследуется детьми."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = action
    frames = max(2, round(seconds * FPS))
    order = []

    def visit(b):
        order.append(b)
        for c in b.children:
            visit(c)

    for b in arm.data.bones:
        if b.parent is None:
            visit(b)
    for f in range(frames + 1):
        t = f / frames
        spec = pose(t if not loop else t % 1.0)
        world = {}
        for b in order:
            pb = arm.pose.bones[b.name]
            pb.rotation_mode = "QUATERNION"
            axis, angle, offset, scale = spec.get(b.name, (Vector((1, 0, 0)), 0.0, Vector(), 1.0))
            head = b.head_local
            local = (Matrix.Translation(head + offset) @ Matrix.Rotation(angle, 4, axis)
                     @ Matrix.Scale(scale, 4) @ Matrix.Translation(-head))
            world[b.name] = (world[b.parent.name] if b.parent else Matrix()) @ local
            pb.matrix = world[b.name] @ b.matrix_local
            bpy.context.view_layer.update()
        for b in order:
            pb = arm.pose.bones[b.name]
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
            pb.keyframe_insert("location", frame=f + 1)
            pb.keyframe_insert("scale", frame=f + 1)
    arm.animation_data.action = None


def key(axis: tuple, angle_deg: float, offset: tuple = (0, 0, 0), scale: float = 1.0) -> tuple:
    return Vector(axis), math.radians(angle_deg), Vector(offset), scale


def wave(t: float, phase: float = 0.0) -> float:
    return math.sin((t + phase) * math.tau)


# ---------------------------------------------------------------- ворона сидит

def crow_perch(obj: bpy.types.Object) -> bpy.types.Object:
    lo, hi = bbox(obj)
    L, H = hi.y - lo.y, hi.z - lo.z

    def p(u: float, v: float) -> Vector:  # u: хвост 0 → клюв 1, v: лапы 0 → макушка 1
        return Vector((0.0, lo.y + u * L, lo.z + v * H))

    arm = make_armature("crow_perch", [
        ("root", p(0.6, 0.0), p(0.6, 0.2), None),
        ("body", p(0.58, 0.32), p(0.7, 0.62), "root"),
        ("head", p(0.72, 0.64), p(0.92, 0.86), "body"),
        ("tail", p(0.42, 0.34), p(0.05, 0.06), "body"),
    ])

    def weigh(co: Vector) -> dict:
        u, v = (co.y - lo.y) / L, (co.z - lo.z) / H
        legs = 1.0 - smooth(0.16, 0.26, v)
        head = smooth(0.64, 0.74, u) * smooth(0.52, 0.64, v) * (1 - legs)
        tail = (1.0 - smooth(0.3, 0.42, u)) * (1 - legs)
        body = max(0.0, 1.0 - legs - head - tail)
        return {"root": legs, "head": head, "tail": tail, "body": body}

    bind(obj, arm, weigh)
    side, fwd, up = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    animate(arm, "idle", 2.4, lambda t: {
        "body": key(side, 2.0 * wave(t)),
        "head": key(up, 6.0 * wave(t, 0.2)),
        "tail": key(side, -3.0 * wave(t, 0.1)),
    })
    animate(arm, "look", 3.2, lambda t: {
        "head": key(up, 42.0 * math.sin(t * math.tau) * smooth(0.0, 0.15, t) * (1 - smooth(0.85, 1.0, t))),
        "body": key(up, 8.0 * math.sin(t * math.tau)),
    })
    animate(arm, "peck", 1.4, lambda t: {
        "body": key(side, -30.0 * math.sin(math.pi * smooth(0.0, 1.0, t)) ** 2),
        "head": key(side, -28.0 * max(0.0, math.sin(t * math.pi * 3)) * (1 - smooth(0.7, 1.0, t))),
        "tail": key(side, 12.0 * math.sin(math.pi * t)),
    })
    animate(arm, "caw", 1.6, lambda t: {
        "head": key(side, 22.0 * math.sin(math.pi * smooth(0.0, 0.5, t)) * (1 - smooth(0.6, 1.0, t))),
        "body": key(side, 6.0 * math.sin(math.pi * t) + 4.0 * math.sin(t * math.tau * 3) * (1 - t),
                    (0, 0, 0.012 * math.sin(math.pi * t))),
        "tail": key(side, 10.0 * math.sin(t * math.tau * 3) * (1 - t)),
    })
    return arm


# ---------------------------------------------------------------- ворона летит

def crow_fly(obj: bpy.types.Object) -> bpy.types.Object:
    lo, hi = bbox(obj)
    span = hi.x - lo.x
    L = hi.y - lo.y
    # плечо: где крыло шире всего вдоль хода (середина размаха по передней кромке)
    near = [v.co for v in obj.data.vertices if abs(v.co.x) > span * 0.2 and abs(v.co.x) < span * 0.3]
    shoulder_y = sum(c.y for c in near) / max(1, len(near))
    half = span * 0.5
    sy = shoulder_y
    bones = [("body", Vector((0, sy - 0.12 * L, 0)), Vector((0, sy + 0.1 * L, 0)), None),
             ("head", Vector((0, sy + 0.1 * L, 0)), Vector((0, hi.y, 0)), "body"),
             ("tail", Vector((0, sy - 0.12 * L, 0)), Vector((0, lo.y, 0)), "body")]
    for s, n in ((1, "L"), (-1, "R")):
        bones.append((f"wing1.{n}", Vector((s * 0.06 * span, sy, 0)), Vector((s * 0.5 * half, sy, 0)), "body"))
        bones.append((f"wing2.{n}", Vector((s * 0.5 * half, sy, 0)), Vector((s * half, sy - 0.05 * L, 0)),
                      f"wing1.{n}"))
    arm = make_armature("crow_fly", bones)

    def weigh(co: Vector) -> dict:
        ax = abs(co.x) / half
        n = "L" if co.x >= 0 else "R"
        wing = smooth(0.08, 0.2, ax)
        outer = smooth(0.42, 0.6, ax) * wing
        inner = wing - outer
        rest = 1.0 - wing
        head = rest * smooth(sy + 0.08 * L, sy + 0.16 * L, co.y)
        tail = rest * (1 - smooth(sy - 0.2 * L, sy - 0.1 * L, co.y))
        return {f"wing1.{n}": inner, f"wing2.{n}": outer, "head": head, "tail": tail,
                "body": max(0.0, rest - head - tail)}

    bind(obj, arm, weigh)
    fwd = (0, 1, 0)

    def flap(t: float) -> dict:
        a = wave(t, 0.0)
        b = wave(t, -0.12)
        return {"body": key((1, 0, 0), 4.0 * a, (0, 0, -0.03 * a)),
                "wing1.L": key(fwd, -38.0 * a - 6.0), "wing1.R": key(fwd, 38.0 * a + 6.0),
                "wing2.L": key(fwd, -26.0 * b), "wing2.R": key(fwd, 26.0 * b),
                "tail": key((1, 0, 0), 5.0 * a), "head": key((1, 0, 0), -3.0 * a)}

    def glide(t: float) -> dict:
        a = wave(t)
        return {"body": key(fwd, 4.0 * a, (0, 0, 0.012 * a)),
                "wing1.L": key(fwd, -9.0 - 2.0 * a), "wing1.R": key(fwd, 9.0 - 2.0 * a),
                "wing2.L": key(fwd, 6.0 + 3.0 * wave(t, 0.3)), "wing2.R": key(fwd, -6.0 - 3.0 * wave(t, 0.3)),
                "tail": key(fwd, 6.0 * wave(t, 0.2)), "head": key((0, 0, 1), 8.0 * wave(t, 0.4))}

    animate(arm, "flap", 0.42, flap)
    animate(arm, "glide", 2.4, glide)
    return arm


# ---------------------------------------------------------------- медвежонок

def bear_cub(obj: bpy.types.Object) -> bpy.types.Object:
    lo, hi = bbox(obj)
    L, H, W = hi.y - lo.y, hi.z - lo.z, hi.x - lo.x

    def p(u: float, v: float, x: float = 0.0) -> Vector:  # u: зад 0 → нос 1
        return Vector((x, lo.y + u * L, lo.z + v * H))

    # ступни — четыре скопления нижних вершин (k-средние): в позе шага лапы почти на средней линии
    bottom = [v.co.copy() for v in obj.data.vertices if (v.co.z - lo.z) / H < 0.08]
    centers = [p(u, 0.0, sx * W * 0.2) for u in (0.2, 0.7) for sx in (1, -1)]
    for _ in range(12):
        groups = [[] for _ in centers]
        for c in bottom:
            k = min(range(4), key=lambda i: (c.xy - centers[i].xy).length)
            groups[k].append(c)
        centers = [sum(g, Vector()) / len(g) if g else centers[i] for i, g in enumerate(groups)]
    by_y = sorted(centers, key=lambda c: c.y)
    feet = {}
    for part, pair in (("hind", by_y[:2]), ("front", by_y[2:])):
        left, right = sorted(pair, key=lambda c: -c.x)
        feet[f"{part}.L"], feet[f"{part}.R"] = left, right
    bones = [("hips", p(0.22, 0.62), p(0.5, 0.68), None),
             ("chest", p(0.5, 0.68), p(0.74, 0.7), "hips"),
             ("head", p(0.74, 0.66), p(1.0, 0.56), "chest")]
    legs = {}
    for leg, foot in feet.items():
        parent = "hips" if leg.startswith("hind") else "chest"
        base_y = lo.y + (0.24 if leg.startswith("hind") else 0.64) * L
        top = Vector((foot.x * 0.8, (foot.y + base_y) * 0.5, lo.z + 0.58 * H))
        bottom_pt = Vector((foot.x, foot.y, lo.z))
        knee = top.lerp(bottom_pt, 0.55)
        legs[leg] = (top, bottom_pt)
        bones.append((f"{leg}.up", top, knee, parent))
        bones.append((f"{leg}.low", knee, bottom_pt, f"{leg}.up"))
    arm = make_armature("bear_cub", bones)

    def seg_dist(c: Vector, a: Vector, b: Vector) -> float:
        ab = b - a
        t = max(0.0, min(1.0, (c - a).dot(ab) / ab.length_squared))
        return (c - (a + ab * t)).length

    def weigh(co: Vector) -> dict:
        u, v = (co.y - lo.y) / L, (co.z - lo.z) / H
        w = {}
        below = 1.0 - smooth(0.36, 0.5, v)
        leg_total = 0.0
        if below > 0:
            leg, d = min(((n, seg_dist(co, *legs[n])) for n in legs), key=lambda x: x[1])
            leg_w = below * (1.0 - smooth(0.07 * L, 0.12 * L, d))
            low = (1.0 - smooth(0.2, 0.34, v)) * leg_w
            w[f"{leg}.low"] = low
            w[f"{leg}.up"] = leg_w - low
            leg_total = leg_w
        body = 1.0 - leg_total
        head = body * smooth(0.72, 0.8, u)
        chest = (body - head) * smooth(0.4, 0.6, u)
        w["head"] = head
        w["chest"] = chest
        w["hips"] = body - head - chest
        return w

    bind(obj, arm, weigh)
    side = (1, 0, 0)
    up = (0, 0, 1)
    cub_head = 1.28  # крупная голова — медвежонок, а не взрослый медведь

    def walk(t: float) -> dict:
        pose = {"head": key(side, 4.0 * wave(t, 0.25) * 0.5, scale=cub_head),
                "hips": key((0, 1, 0), 3.0 * wave(t), (0, 0, 0.012 * abs(wave(t)))),
                "chest": key((0, 1, 0), -3.0 * wave(t))}
        for leg, phase in (("hind.L", 0.0), ("front.R", 0.0), ("hind.R", 0.5), ("front.L", 0.5)):
            s = wave(t, phase)
            lift = max(0.0, math.cos((t + phase) * math.tau))
            pose[f"{leg}.up"] = key(side, 20.0 * s)
            pose[f"{leg}.low"] = key(side, (-22.0 if leg.startswith("front") else 18.0) * lift ** 2)
        return pose

    def idle(t: float) -> dict:
        return {"head": key(up, 22.0 * wave(t) * smooth(0.0, 0.2, t), scale=cub_head),
                "chest": key(side, 1.5 * wave(t * 2), (0, 0, 0.006 * wave(t * 2))),
                "hips": key(side, 0.0)}

    def sniff(t: float) -> dict:
        down = math.sin(math.pi * smooth(0.0, 1.0, t))
        return {"chest": key(side, -12.0 * down),
                "head": key(side, -34.0 * down + 5.0 * wave(t * 6) * down, scale=cub_head)}

    animate(arm, "walk", 1.0, walk)
    animate(arm, "idle", 3.6, idle)
    animate(arm, "sniff", 2.6, sniff)
    return arm


# ---------------------------------------------------------------- выход

def export(mid: str, arm: bpy.types.Object) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{mid}.glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS",
                              export_force_sampling=True, export_image_format="JPEG", export_jpeg_quality=88)
    print(f"[creature] {mid}: {(OUT / f'{mid}.glb').relative_to(ROOT)} "
          f"{(OUT / f'{mid}.glb').stat().st_size // 1024} КБ, действия: {[a.name for a in bpy.data.actions]}")


def preview(mid: str, arm: bpy.types.Object) -> None:
    """Кадры каждой анимации сбоку и сверху-сбоку (как камера игры) — проверить веса глазами."""
    RENDERS.mkdir(parents=True, exist_ok=True)
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x = scn.render.resolution_y = 360
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.73, 0.68, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
    scn.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.type = "ORTHO"
    lo, hi = bbox(bpy.data.objects[mid])
    size = max(hi - lo) * 1.35
    cam.data.ortho_scale = size
    center = (lo + hi) / 2
    for action in [a for a in bpy.data.actions]:
        arm.animation_data.action = action
        start, end = action.frame_range
        for i, frac in enumerate((0.0, 0.25, 0.5, 0.75)):
            scn.frame_set(int(start + frac * (end - start)))
            for j, d in enumerate((Vector((1, 0, 0)), Vector((1, -0.8, 1.1)).normalized())):
                cam.location = center + d * size * 3
                cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
                scn.render.filepath = str(RENDERS / f"{mid}_{action.name}_{j}{i}.png")
                bpy.ops.render.render(write_still=True)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    mid = args[0]
    obj = load_mesh(mid)
    arm = {"crow_perch": crow_perch, "crow_fly": crow_fly, "bear_cub": bear_cub}[mid](obj)
    export(mid, arm)
    if "--preview" in args:
        preview(mid, arm)


if __name__ == "__main__":
    main()
