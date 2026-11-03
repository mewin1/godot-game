"""Соответствие концепту: камера концепта, сверка силуэтов и проекция рисунка концепта в текстуру.

1. concept_mask — силуэт на концепте (отличие от фона, фон берётся по краям каждой строки).
2. fit_camera — ортокамера с ракурса концепта подгоняется так, чтобы рамки силуэтов совпали.
3. silhouette_report — карта несовпадений (красное — есть на концепте, нет у модели; зелёное — наоборот)
   и IoU; по ней правится геометрия.
4. project_bake — рисунок концепта проецируется с этой камеры на видимые с неё грани и запекается
   поверх рисованной фактуры (невидимые стороны — фактура или зеркальная проекция для симметричных).
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import kit

W, H = 768, 1024


def _load_pixels(path: Path) -> np.ndarray:
    img = bpy.data.images.load(str(path), check_existing=False)
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    bpy.data.images.remove(img)
    return arr[::-1]  # сверху вниз


def concept_mask(path: Path, thr: float = 0.012) -> np.ndarray:
    """Фон — связная от краёв область плавного градиента (заливка по малым перепадам соседей)."""
    px = _load_pixels(path)[:, :, :3]
    small = px[::2, ::2]
    g = np.zeros(small.shape[:2], dtype=np.float32)
    g[:, 1:] = np.maximum(g[:, 1:], np.abs(small[:, 1:] - small[:, :-1]).max(axis=2))
    g[1:, :] = np.maximum(g[1:, :], np.abs(small[1:] - small[:-1]).max(axis=2))
    smooth = g < thr
    bg = np.zeros_like(smooth)
    bg[0, :] = bg[-1, :] = bg[:, 0] = bg[:, -1] = True
    bg &= smooth
    while True:
        grown = bg.copy()
        grown[1:] |= bg[:-1]
        grown[:-1] |= bg[1:]
        grown[:, 1:] |= bg[:, :-1]
        grown[:, :-1] |= bg[:, 1:]
        grown &= smooth
        if (grown == bg).all():
            break
        bg = grown
    # убрать шумовые точки: размыкание (сжать, потом расширить) на 3 пикселя
    obj = ~bg

    def shift_all(m, op):
        r = m.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            r = op(r, np.roll(np.roll(m, dy, axis=0), dx, axis=1))
        return r

    for _ in range(3):
        obj = shift_all(obj, np.logical_and)
    for _ in range(3):
        obj = shift_all(obj, np.logical_or)
    big = np.repeat(np.repeat(obj, 2, axis=0), 2, axis=1)
    return big[:H, :W]


def setup_camera(view: dict):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = 100
    cam = sc.camera
    return cam


def render_mask(out: Path) -> np.ndarray:
    sc = bpy.context.scene
    prev = (sc.render.film_transparent, sc.view_layers[0].material_override, sc.render.engine)
    white = bpy.data.materials.get("_mask") or bpy.data.materials.new("_mask")
    sc.render.film_transparent = True
    sc.view_layers[0].material_override = white
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    sc.render.film_transparent, sc.view_layers[0].material_override, sc.render.engine = prev
    return _load_pixels(out)[:, :, 3] > 0.5


def _bbox(mask: np.ndarray):
    """Рамка без шумовых точек: строки/столбцы, где силуэт шире нескольких пикселей."""
    rows = np.nonzero(mask.sum(axis=1) > 10)[0]
    cols = np.nonzero(mask.sum(axis=0) > 10)[0]
    return cols.min(), cols.max(), rows.min(), rows.max()


def fit_camera(cmask: np.ndarray, out: Path, passes: int = 6):
    """Ортомасштаб — по высоте силуэта, сдвиг камеры — по центру рамки."""
    cam = bpy.context.scene.camera
    right = cam.matrix_world.to_3x3() @ Vector((1, 0, 0))
    up = cam.matrix_world.to_3x3() @ Vector((0, 1, 0))
    cx0, cx1, cy0, cy1 = _bbox(cmask)
    for k in range(passes):
        m = render_mask(out)
        mx0, mx1, my0, my1 = _bbox(m)
        # если модель упёрлась в край кадра, её размер не измерить — сначала отдалить
        clipped = mx0 <= 1 or my0 <= 1 or mx1 >= W - 2 or my1 >= H - 2
        scale = 1.25 if clipped else max((my1 - my0) / max(cy1 - cy0, 1), (mx1 - mx0) / max(cx1 - cx0, 1) * 0.0 + 0.0)
        print(f"[fit] pass {k}: model {mx0}-{mx1} x {my0}-{my1}, concept {cx0}-{cx1} x {cy0}-{cy1}, scale {scale:.3f}")
        cam.data.ortho_scale *= scale
        bpy.context.view_layer.update()
        m = render_mask(out)
        mx0, mx1, my0, my1 = _bbox(m)
        px_m = cam.data.ortho_scale / H
        dx = ((mx0 + mx1) - (cx0 + cx1)) / 2 * px_m
        dy = ((my0 + my1) - (cy0 + cy1)) / 2 * px_m
        cam.location += right * dx - up * dy
        bpy.context.view_layer.update()
    return render_mask(out)


def silhouette_report(cmask, mmask, out: Path) -> float:
    inter = (cmask & mmask).sum()
    union = (cmask | mmask).sum()
    img = np.zeros((H, W, 4), dtype=np.float32)
    img[..., 3] = 1
    img[cmask & mmask] = (0.35, 0.35, 0.35, 1)
    img[cmask & ~mmask] = (0.9, 0.1, 0.1, 1)
    img[~cmask & mmask] = (0.1, 0.85, 0.2, 1)
    im = bpy.data.images.new("_sil", W, H)
    im.pixels[:] = img[::-1].ravel()
    im.filepath_raw = str(out)
    im.file_format = "PNG"
    im.save()
    return float(inter) / max(float(union), 1.0)


def _proj_uv(ob, cam, name: str, mirror: bool = False):
    sc = bpy.context.scene
    me = ob.data
    uv = me.uv_layers.get(name) or me.uv_layers.new(name=name)
    mw = ob.matrix_world
    for loop in me.loops:
        co = world_to_camera_view(sc, cam, mw @ me.vertices[loop.vertex_index].co)
        u = 1.0 - co.x if mirror else co.x
        uv.data[loop.index].uv = (u, co.y)


def _visibility(objects, cam, attr: str):
    """Видна ли вершина с камеры (луч от камеры не упирается в другое раньше)."""
    dg = bpy.context.evaluated_depsgraph_get()
    trees = [BVHTree.FromObject(o, dg) for o in objects]
    d = (cam.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized()
    for ob in objects:
        me = ob.data
        mw = ob.matrix_world
        imw = mw.inverted()
        col = me.color_attributes.get(attr) or me.color_attributes.new(attr, "FLOAT_COLOR", "POINT")
        for v in me.vertices:
            p = mw @ v.co
            origin = p - d * 60.0
            best = None
            for o2, t in zip(objects, trees):
                lo = o2.matrix_world.inverted() @ origin
                ld = (o2.matrix_world.inverted().to_3x3() @ d).normalized()
                hit = t.ray_cast(lo, ld)
                if hit[0] is not None:
                    hw = o2.matrix_world @ hit[0]
                    dist = (hw - origin).length
                    best = dist if best is None else min(best, dist)
            seen = 1.0 if best is None or best > (p - origin).length - 0.03 else 0.0
            col.data[v.index].color = (seen, seen, seen, 1.0)
        _ = imw


def _mask_image(cmask: np.ndarray, name: str):
    im = bpy.data.images.new(name, W, H)
    arr = np.zeros((H, W, 4), dtype=np.float32)
    arr[..., :3] = cmask[..., None].astype(np.float32)
    arr[..., 3] = 1
    im.pixels[:] = arr[::-1].ravel()
    return im


def project_bake(objects, concept: Path, cmask: np.ndarray, mirror_back: bool = False, size: int = 2048,
                 emission: float = 0.4):
    """Запечь проекцию концепта поверх рисованной фактуры в новую текстуру (слот 0 каждого объекта)."""
    sc = bpy.context.scene
    cam = sc.camera
    d = (cam.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized()
    concept_img = bpy.data.images.load(str(concept), check_existing=True)
    mask_img = _mask_image(cmask, "_cmask")
    for ob in objects:
        _proj_uv(ob, cam, "proj")
        if mirror_back:
            back = cam.copy()
            back.data = cam.data
            pivot = Vector((0, 0, cam.location.z))
            rel = cam.location - pivot
            back.location = pivot + Vector((-rel.x, -rel.y, rel.z))
            back.rotation_euler = cam.rotation_euler.copy()
            back.rotation_euler.z += math.pi
            sc.collection.objects.link(back)
            bpy.context.view_layer.update()
            _proj_uv(ob, back, "proj_back", mirror=True)
            bpy.data.objects.remove(back)
    _visibility(objects, cam, "vis")
    sc.render.engine = "CYCLES"
    use_gpu()
    sc.cycles.samples = 4
    for ob in objects:
        paint_mat = ob.data.materials[0]
        paint_img = next((n.image for n in paint_mat.node_tree.nodes if n.type == "TEX_IMAGE"), None)
        out_img = bpy.data.images.new(f"{ob.name}_proj", size, size)
        tmp = bpy.data.materials.new(f"_proj_{ob.name}")
        tmp.use_nodes = True
        nt = tmp.node_tree
        nt.nodes.clear()
        N, L = nt.nodes.new, nt.links.new

        def tex(img, uvname, clip=False):
            uvn = N("ShaderNodeUVMap")
            uvn.uv_map = uvname
            t = N("ShaderNodeTexImage")
            t.image = img
            if clip:
                t.extension = "CLIP"
            L(uvn.outputs[0], t.inputs["Vector"])
            return t

        def facing(sign):
            geo = N("ShaderNodeNewGeometry")
            dot = N("ShaderNodeVectorMath")
            dot.operation = "DOT_PRODUCT"
            L(geo.outputs["Normal"], dot.inputs[0])
            dot.inputs[1].default_value = tuple(-d * sign)
            mr = N("ShaderNodeMapRange")
            L(dot.outputs["Value"], mr.inputs["Value"])
            mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = 0.05, 0.35
            return mr.outputs["Result"]

        def mul(a, b):
            m = N("ShaderNodeMath")
            m.operation = "MULTIPLY"
            L(a, m.inputs[0])
            L(b, m.inputs[1])
            return m.outputs[0]

        base = tex(paint_img, "UVMap").outputs["Color"]
        front = tex(concept_img, "proj", True)
        fmask = tex(mask_img, "proj", True)
        vis = N("ShaderNodeVertexColor")
        vis.layer_name = "vis"
        m1 = mul(mul(facing(1), fmask.outputs["Color"]), vis.outputs["Color"])
        mix = N("ShaderNodeMix")
        mix.data_type = "RGBA"
        L(m1, mix.inputs[0])
        L(base, mix.inputs[6])
        L(front.outputs["Color"], mix.inputs[7])
        result = mix.outputs[2]
        if mirror_back:
            backt = tex(concept_img, "proj_back", True)
            bmask = tex(mask_img, "proj_back", True)
            m2 = mul(facing(-1), bmask.outputs["Color"])
            mix2 = N("ShaderNodeMix")
            mix2.data_type = "RGBA"
            L(m2, mix2.inputs[0])
            L(result, mix2.inputs[6])
            L(backt.outputs["Color"], mix2.inputs[7])
            result = mix2.outputs[2]
        em = N("ShaderNodeEmission")
        L(result, em.inputs["Color"])
        out = N("ShaderNodeOutputMaterial")
        L(em.outputs[0], out.inputs["Surface"])
        target = N("ShaderNodeTexImage")
        target.image = out_img
        nt.nodes.active = target
        ob.data.materials[0] = tmp
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        sc.render.bake.margin = 6
        bpy.ops.object.bake(type="EMIT")
        # итог: рисунок концепта — и цвет, и слабое свечение (нарисованный свет читается и в тёмной сцене)
        final = bpy.data.materials.new(f"{ob.name}_final")
        final.use_nodes = True
        p = final.node_tree.nodes["Principled BSDF"]
        t = final.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = out_img
        final.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
        import paint
        mask = bpy.data.images.get(ob.get("glow_mask", ""))
        if mask is not None:
            out_img.pack()
            em_img = paint.emission_image(out_img, mask, f"{ob.name}_proj_emit")
            te = final.node_tree.nodes.new("ShaderNodeTexImage")
            te.image = em_img
            final.node_tree.links.new(te.outputs["Color"], p.inputs["Emission Color"])
            p.inputs["Emission Strength"].default_value = paint.GLOW_STRENGTH
        else:
            final.node_tree.links.new(t.outputs["Color"], p.inputs["Emission Color"])
            p.inputs["Emission Strength"].default_value = emission
        p.inputs["Roughness"].default_value = 0.8
        ob.data.materials[0] = final
        bpy.data.materials.remove(tmp)
        out_path = kit.ROOT / "source_art" / "noir" / "proj" / f"{ob.name}_proj.png"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_img.filepath_raw = str(out_path)
        out_img.file_format = "PNG"
        out_img.save()
    sc.render.engine = "BLENDER_EEVEE"


_GPU_READY = []


def use_gpu() -> None:
    """Cycles на видеокарте (OptiX, иначе CUDA); без неё — процессор. Устройства настраиваются один раз."""
    _GPU_READY.append("CPU")  # GPU в одном процессе с EEVEE падает (CUDA context) — запекание на CPU быстрое
    if _GPU_READY:
        bpy.context.scene.cycles.device = _GPU_READY[0]
        return
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
            except TypeError:
                continue
            prefs.get_devices()
            gpus = [d for d in prefs.devices if d.type == kind]
            if gpus:
                for d in prefs.devices:
                    d.use = d.type == kind
                bpy.context.scene.cycles.device = "GPU"
                _GPU_READY.append("GPU")
                print("[gpu]", kind, [d.name for d in gpus])
                return
    except Exception as error:  # noqa: BLE001
        print("[gpu] нет:", error)
    bpy.context.scene.cycles.device = "CPU"
    _GPU_READY.append("CPU")
