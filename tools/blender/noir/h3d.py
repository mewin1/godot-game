"""Модель по концепту из сетки Hunyuan3D-2: форма — нейросеть, покраска — проекция самого концепта.

blender -b --factory-startup -P tools/blender/noir/h3d.py -- <id> [<id> ...] [--tex 4096] [--no-export]
(обёртка: tools/blender/noir/h3d.sh <id> ...). Сетка: source_art/noir_h3d/raw/<id>.glb (tools/concepts/h3d_gen.py).

1. Ракурс концепта ищется перебором (силуэт вершин в numpy против маски концепта), затем точная подгонка
   ортокамеры рендером (project.fit_camera) → IoU и карта new_concept/compare/renders/<id>_h3d_sil.png.
2. Постановка: плита — по осям и ровно в клетку 2 м (постройки, идолы); персонаж — рост по макушке.
3. Покраска: концепт (с «растёкшимися» за силуэт цветами — без ореолов фона) проецируется камерой концепта
   на видимые и смотрящие на неё грани; у построек ещё тремя камерами, повёрнутыми на 90° вокруг оси
   (постройки почти симметричны), — у боковин нет растяжек. Остальное — размытая проекция (цвета без деталей).
   Яркое на концепте (пламя, разряды, окна) — в маску свечения.
4. Плита отрезается по верху плиты в <id>_plate (своя плита постройки), персонажам — общий скелет units.py
   с весами по близости к костям. GLB → assets/noir_h3d/<kind>/<id>.glb, .blend → source_art/noir_h3d/<kind>/.
"""
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import kit  # noqa: E402
import paint  # noqa: E402
import project  # noqa: E402

RAW = kit.ROOT / "source_art" / "noir_h3d" / "raw"
RENDERS = kit.ROOT / "new_concept" / "compare" / "renders"
GROUPS = {"buildings": "towers", "idols": "idols", "units": "units", "heroes": "heroes", "arena_props": "arena"}
SOURCES = {"terem": "buildings/terem_5.png"}  # концепты не из пачки 16
KIND_BY_ID = {"terem": "base"}
# азимут камеры концепта относительно фронта модели (как у прежних моделей): постройки и идолы — плита ромбом
TARGET_AZ = {"buildings": -40.0, "idols": -40.0, "units": -22.0, "heroes": -22.0, "arena_props": -30.0}
SEARCH = {  # (elevation от, до, шаг), (azimuth от, до, шаг) — где искать ракурс концепта
    "buildings": ((14, 56, 3), (-80, 0, 4)),
    "idols": ((14, 56, 3), (-80, 0, 4)),
    "units": ((-6, 24, 3), (-40, 40, 4)),
    "heroes": ((-6, 24, 3), (-40, 40, 4)),
    "arena_props": ((0, 45, 3), (-64, 32, 4)),
}
# рост до макушки (м) для персонажей; у существ — своё
HEIGHT = {"units": 1.7, "heroes": 2.0, "arena_props": 2.0}
HEIGHT_BY_ID = {"kolobok": 0.9, "bat": 1.3, "boss": 2.6, "gorynych": 3.2, "leshy": 2.6, "spirit": 1.8,
                "domovoy": 1.2, "koschei": 2.1,
                # реквизит арены: высота целиком
                "palisade": 2.3, "palisade_post": 2.9, "gate": 3.8, "fire_bowl": 1.5, "pine": 7.5, "birch": 6.5,
                "rock": 1.1, "fern": 0.9,
                "corner_tower": 3.0, "torch_post": 2.4}
CELL = 2.0
PLATE_BY_ID = {"terem": 3.4}  # терем на концепте арены — дом почти в две клетки
# предел треугольников: реквизит арены повторяется десятками (ели, частокол), юнитов на поле много
FACES_BY_GROUP = {"units": 30000, "arena_props": 12000}
FACES_BY_ID = {"pine": 16000, "birch": 16000, "rock": 4000, "fern": 4000, "palisade": 12000, "palisade_post": 8000,
               "gate": 30000, "fire_bowl": 20000, "corner_tower": 20000, "torch_post": 6000}


def decimate(ob, mid: str, group: str):
    limit = FACES_BY_ID.get(mid, FACES_BY_GROUP.get(group))
    n = len(ob.data.polygons)
    if limit is None or n <= limit:
        return
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.ratio = limit / n
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print(f"[h3d] упрощение: {n} → {len(ob.data.polygons)} граней")
BLUR_PX = 9


def concept_path(group: str, mid: str) -> Path:
    if mid in SOURCES:
        return kit.ROOT / "new_concept" / SOURCES[mid]
    return kit.ROOT / "new_concept" / group / f"{mid}_16.png"


def group_of(mid: str) -> str:
    if mid in SOURCES:
        return SOURCES[mid].split("/")[0]
    for g in GROUPS:
        if (kit.ROOT / "new_concept" / g / f"{mid}_16.png").exists():
            return g
    raise SystemExit(f"нет концепта для {mid}")


def clean_mask(cmask: np.ndarray, concept: Path) -> np.ndarray:
    """Маска концепта без замкнутых «окон» фона (между копьём и телом): крупные плавные места цвета фона строки."""
    px = project._load_pixels(concept)[:, :, :3]
    small = px[::2, ::2]
    g = np.zeros(small.shape[:2], dtype=np.float32)
    g[:, 1:] = np.maximum(g[:, 1:], np.abs(small[:, 1:] - small[:, :-1]).max(axis=2))
    g[1:, :] = np.maximum(g[1:, :], np.abs(small[1:] - small[:-1]).max(axis=2))
    edge = np.concatenate([small[:, :6], small[:, -6:]], axis=1).mean(axis=1, keepdims=True)
    cand = (g < 0.012) & (np.abs(small - edge).max(axis=2) < 0.035) & cmask[::2, ::2]
    seen = np.zeros_like(cand)
    holes = np.zeros_like(cand)
    for y0, x0 in zip(*np.nonzero(cand)):
        if seen[y0, x0]:
            continue
        comp, stack = [], [(y0, x0)]
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < cand.shape[0] and 0 <= nx < cand.shape[1] and cand[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(comp) >= 150:
            ys, xs = zip(*comp)
            holes[list(ys), list(xs)] = True
    big = np.repeat(np.repeat(holes, 2, axis=0), 2, axis=1)[: cmask.shape[0], : cmask.shape[1]]
    return cmask & ~big


def drop_floor(ob):
    """Персонажи: нейросеть иногда дорисовывает под ногами тонкий «пол» — срезать его."""
    co = verts(ob)
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    h = z1 - z0

    def area(a, b):
        sl = co[(co[:, 2] >= z0 + a * h) & (co[:, 2] < z0 + b * h)]
        if len(sl) < 4:
            return 0.0
        return (sl[:, 0].max() - sl[:, 0].min()) * (sl[:, 1].max() - sl[:, 1].min())

    ref = area(0.04, 0.08)
    cut = 0.0
    for c in np.arange(0.0, 0.04, 0.003):
        if area(c, c + 0.006) < 1.5 * ref:
            cut = float(c)
            break
    if cut <= 0:
        return
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-6,
                           plane_co=(0, 0, z0 + cut * h), plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(ob.data)
    bm.free()
    print(f"[h3d] срезан пол под ногами: {cut * 100:.1f}% высоты")


# ---------- загрузка ----------

PAINT = {"on": False}  # --paint: текстура Hunyuan3D со всех сторон (tools/concepts/h3d_paint.py) вместо проекции
PAINTED = {}


def load(mid: str):
    kit.reset()
    src = RAW / (f"{mid}_paint.glb" if PAINT["on"] else f"{mid}.glb")
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = mid
    ob.data.name = mid
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(ob.data)
    bm.free()
    PAINTED.pop(mid, None)
    for m in ob.data.materials:
        if PAINT["on"] and m is not None and m.use_nodes:
            for node in m.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image is not None:
                    PAINTED[mid] = node.image
                    break
    for m in list(ob.data.materials):
        bpy.data.materials.remove(m)
    ob.data.materials.clear()
    return ob


def verts(ob) -> np.ndarray:
    co = np.empty(len(ob.data.vertices) * 3, dtype=np.float32)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(ob.matrix_world, dtype=np.float32)
    return co @ mw[:3, :3].T + mw[:3, 3]


def tris(ob) -> np.ndarray:
    ob.data.calc_loop_triangles()
    t = np.empty(len(ob.data.loop_triangles) * 3, dtype=np.int32)
    ob.data.loop_triangles.foreach_get("vertices", t)
    return t.reshape(-1, 3)


# ---------- поиск ракурса по силуэту ----------

def cam_axes(el: float, az: float):
    e, a = math.radians(el), math.radians(az)
    back = np.array([math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)])  # от объекта к камере
    f = -back
    right = np.cross(f, [0, 0, 1.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, f)
    return right, up


def raster(co2: np.ndarray, tri: np.ndarray, w: int, h: int) -> np.ndarray:
    """Силуэт треугольников (координаты в пикселях) — заливка по барицентрическим, грубо и быстро."""
    m = np.zeros((h, w), dtype=bool)
    p = co2[tri]  # (n, 3, 2)
    x0 = np.clip(np.floor(p[..., 0].min(1)).astype(int), 0, w - 1)
    x1 = np.clip(np.ceil(p[..., 0].max(1)).astype(int), 0, w - 1)
    y0 = np.clip(np.floor(p[..., 1].min(1)).astype(int), 0, h - 1)
    y1 = np.clip(np.ceil(p[..., 1].max(1)).astype(int), 0, h - 1)
    small = (x1 - x0 <= 1) & (y1 - y0 <= 1)
    cx = np.clip(np.round(p[small, :, 0].mean(1)).astype(int), 0, w - 1)
    cy = np.clip(np.round(p[small, :, 1].mean(1)).astype(int), 0, h - 1)
    m[cy, cx] = True
    for i in np.nonzero(~small)[0]:
        a, b, c = p[i]
        xs, ys = np.meshgrid(np.arange(x0[i], x1[i] + 1), np.arange(y0[i], y1[i] + 1))
        px, py = xs + 0.5, ys + 0.5
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9:
            continue
        l1 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / d
        l2 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / d
        inside = (l1 >= -0.01) & (l2 >= -0.01) & (l1 + l2 <= 1.01)
        m[ys[inside], xs[inside]] = True
    return m


def bbox(mask: np.ndarray, thr: int = 2):
    rows = np.nonzero(mask.sum(axis=1) > thr)[0]
    cols = np.nonzero(mask.sum(axis=0) > thr)[0]
    return cols.min(), cols.max(), rows.min(), rows.max()


def samples(ob) -> np.ndarray:
    """Точки поверхности для быстрого силуэта: вершины, центры граней и середины рёбер треугольников."""
    co = verts(ob)
    t = tris(ob)
    p = co[t]
    return np.concatenate([co, p.mean(1), (p[:, 0] + p[:, 1]) / 2, (p[:, 1] + p[:, 2]) / 2, (p[:, 0] + p[:, 2]) / 2])


def fit2d(pts: np.ndarray, cm: np.ndarray, el: float, az: float, smul: float = 1.0):
    """Силуэт точек с ракурса (el, az), вписанный в рамку маски cm: (IoU, масштаб px/м, центр px, центр в м)."""
    h, w = cm.shape
    cx0, cx1, cy0, cy1 = bbox(cm)
    right, up = cam_axes(el, az)
    x, y = pts @ right, pts @ up
    sh = (cy1 - cy0) / max(y.max() - y.min(), 1e-6)
    sw = (cx1 - cx0) / max(x.max() - x.min(), 1e-6)
    s = (sh + sw) / 2 * smul
    xc, yc = (x.max() + x.min()) / 2, (y.max() + y.min()) / 2
    ox, oy = (cx0 + cx1) / 2, (cy0 + cy1) / 2
    px = np.round((x - xc) * s + ox).astype(int)
    py = np.round((yc - y) * s + oy).astype(int)
    ok = (px >= 0) & (px < w) & (py >= 0) & (py < h)
    m = np.zeros((h, w), dtype=bool)
    m[py[ok], px[ok]] = True
    m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    iou = (m & cm).sum() / max((m | cm).sum(), 1)
    return iou, s, (ox, oy), (xc, yc)


def search_view(pts: np.ndarray, cmask: np.ndarray, group: str, around=None):
    """Перебор ракурса по силуэту. around=(el, az) — уточнение рядом с известным."""
    if around is None:
        (e0, e1, es), (a0, a1, as_) = SEARCH[group]
        k = 4
    else:
        e0, e1, es = around[0] - 3, around[0] + 3, 1.0
        a0, a1, as_ = around[1] - 8, around[1] + 8, 1.0
        k = 2
    cm = cmask[::k, ::k]
    best = (-1, 0.0, 0.0, 1.0)
    for el in np.arange(e0, e1 + 0.01, es):
        for az in np.arange(a0, a1 + 0.01, as_):
            sc = fit2d(pts, cm, el, az)[0]
            if sc > best[0]:
                best = (sc, el, az, 1.0)
    if around is None:  # шаг поиска крупный — уточнить по градусу
        _, el_b, az_b, _ = best
        for el in np.arange(el_b - es, el_b + es + 0.01, 1.0):
            for az in np.arange(az_b - as_, az_b + as_ + 0.01, 1.0):
                sc = fit2d(pts, cm, el, az)[0]
                if sc > best[0]:
                    best = (sc, el, az, 1.0)
    else:
        for smul in (0.94, 0.96, 0.98, 1.02, 1.04, 1.06):
            sc = fit2d(pts, cm, best[1], best[2], smul)[0]
            if sc > best[0]:
                best = (sc, best[1], best[2], smul)
    print(f"[h3d] ракурс: elevation {best[1]:.0f}, azimuth {best[2]:.0f}, масштаб x{best[3]:.2f}, IoU точек {best[0]:.3f}")
    return float(best[1]), float(best[2]), float(best[3])


def place_camera(pts: np.ndarray, cmask: np.ndarray, el: float, az: float, smul: float):
    """Ортокамера ровно так, как вписан силуэт точек в маску концепта (полное разрешение)."""
    _, s, (ox, oy), (xc, yc) = fit2d(pts, cmask, el, az, smul)
    right, up = cam_axes(el, az)
    back = np.cross(right, up)
    # центр кадра (W/2, H/2) — точка мира
    cxw = xc + (project.W / 2 - ox) / s
    cyw = yc - (project.H / 2 - oy) / s
    centre = right * cxw + up * cyw
    cam = bpy.context.scene.camera
    cam.data.type = "ORTHO"
    cam.data.sensor_fit = "AUTO"
    cam.data.ortho_scale = max(project.W, project.H) / s
    cam.location = Vector(centre + back * 30.0)
    rot = Matrix((right, up, back)).transposed()
    cam.rotation_euler = rot.to_euler()
    cam.data.clip_end = 100.0
    bpy.context.view_layer.update()


# ---------- постановка ----------

def rotate_z(ob, deg: float):
    ob.matrix_world = Matrix.Rotation(math.radians(deg), 4, "Z") @ ob.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def plate_angle(co: np.ndarray) -> float:
    """Угол (0–90°), на который повернуть, чтобы края нижней плиты легли по осям (минимум площади рамки)."""
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    low = co[co[:, 2] < z0 + 0.06 * (z1 - z0)][:, :2]
    best = (1e9, 0.0)
    for a in np.arange(0, 90, 0.5):
        r = math.radians(a)
        rx = low[:, 0] * math.cos(r) - low[:, 1] * math.sin(r)
        ry = low[:, 0] * math.sin(r) + low[:, 1] * math.cos(r)
        area = (rx.max() - rx.min()) * (ry.max() - ry.min())
        if area < best[0]:
            best = (area, a)
    return best[1]


def stand(ob, group: str, mid: str, az_found: float) -> float:
    """Повернуть к фронту, поставить на землю и привести к масштабу. Возвращает азимут камеры концепта."""
    # поворот объекта на phi сдвигает азимут камеры относительно него на +phi
    phi = TARGET_AZ[group] - az_found
    rotate_z(ob, phi)
    cam_az = TARGET_AZ[group]
    if group in ("buildings", "idols"):
        a = plate_angle(verts(ob))
        a = min((a, a - 90), key=abs)  # из равносильных поворотов плиты — наименьший
        rotate_z(ob, a)
        cam_az += a
    co = verts(ob)
    if group in ("buildings", "idols"):
        z0 = co[:, 2].min()
        low = co[co[:, 2] < z0 + 0.06 * (co[:, 2].max() - z0)]
        span = max(low[:, 0].max() - low[:, 0].min(), low[:, 1].max() - low[:, 1].min())
        s = PLATE_BY_ID.get(mid, CELL) / span
        cx, cy = (low[:, 0].max() + low[:, 0].min()) / 2, (low[:, 1].max() + low[:, 1].min()) / 2
    else:
        z0, z1 = co[:, 2].min(), co[:, 2].max()
        top = z1 if group == "arena_props" else head_top(co)
        s = HEIGHT_BY_ID.get(mid, HEIGHT[group]) / max(top - z0, 1e-6)
        body = co[co[:, 2] < z0 + 0.25 * (z1 - z0)]
        cx, cy = np.median(body[:, 0]), np.median(body[:, 1])
    ob.matrix_world = Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -z0)) @ ob.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print(f"[h3d] постановка: поворот {phi:.0f}°, масштаб {s:.3f}, габарит {tuple(round(v, 2) for v in ob.dimensions)}")
    return cam_az


def head_top(co: np.ndarray) -> float:
    """Макушка: самый верхний срез, где фигура шире тонких предметов (копьё, посох)."""
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    hgt = z1 - z0
    n = 100
    for i in range(n - 1, 0, -1):
        lo, hi = z0 + hgt * i / n, z0 + hgt * (i + 1) / n
        sl = co[(co[:, 2] >= lo) & (co[:, 2] < hi)]
        if len(sl) < 4:
            continue
        wx = sl[:, 0].max() - sl[:, 0].min()
        wy = sl[:, 1].max() - sl[:, 1].min()
        if min(wx, wy) > 0.06 * hgt:
            return hi
    return z1


# ---------- покраска ----------

def bleed(px: np.ndarray, mask: np.ndarray, iters: int = 96) -> np.ndarray:
    """Цвета силуэта «растекаются» за его край: на краях модели нет фона концепта."""
    out = px.copy()
    known = mask.copy()
    out[~known] = 0
    for _ in range(iters):
        if known.all():
            break
        acc = np.zeros_like(out)
        cnt = np.zeros(known.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += np.roll(np.roll(out, dy, 0), dx, 1) * k[..., None]
            cnt += k
        new = (~known) & (cnt > 0)
        out[new] = acc[new] / cnt[new][:, None]
        known = known | new
    return out


def box_blur(px: np.ndarray, r: int) -> np.ndarray:
    out = px.copy()
    for axis in (0, 1):
        c = np.cumsum(np.pad(out, [(r + 1, r) if a == axis else (0, 0) for a in range(3)], mode="edge"), axis=axis)
        n = out.shape[axis]
        hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
        lo = np.take(c, np.arange(0, n), axis=axis)
        out = (hi - lo) / (2 * r + 1)
    return out


def np_image(name: str, arr: np.ndarray):
    h, w = arr.shape[:2]
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = arr[..., :3] if arr.ndim == 3 else arr[..., None]
    im = bpy.data.images.new(name, w, h)  # байтовая sRGB, как сам концепт
    im.pixels[:] = rgba[::-1].ravel()
    return im


def proj_cams(cam, group: str):
    """Камеры проекции: концепт, а у построек/идолов ещё три, повёрнутые вокруг оси на 90°."""
    cams = [cam]
    if group in ("buildings", "idols"):
        for k in (1, 2, 3):
            c = cam.copy()
            c.data = cam.data
            c.matrix_world = Matrix.Rotation(math.radians(90 * k), 4, "Z") @ cam.matrix_world
            bpy.context.scene.collection.objects.link(c)
            cams.append(c)
    bpy.context.view_layer.update()
    return cams


def unwrap(ob):
    """Своя развёртка "UVMap" для запекания; развёртку покраски Hunyuan (если есть) сохраняем как "huv"."""
    if PAINT["on"] and len(ob.data.uv_layers) > 0:
        ob.data.uv_layers[0].name = "huv"
        ob.data.uv_layers.new(name="UVMap")
        ob.data.uv_layers.active = ob.data.uv_layers["UVMap"]
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.002, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.data.uv_layers.active.name = "UVMap"
    ob.data.uv_layers["UVMap"].active_render = True


def paint_model(ob, concept: Path, cmask: np.ndarray, group: str, size: int, painted=None):
    """painted — текстура Hunyuan3D (развёртка "huv"): спереди рисунок концепта, всё, что камера концепта
    не видит, — покраска Hunyuan вместо размытой проекции и повёрнутых камер (гибрид, без растяжек)."""
    sc = bpy.context.scene
    cam = sc.camera
    px = project._load_pixels(concept)[:, :, :3]
    inner = cmask.copy()
    for _ in range(project.ERODE_PX):
        sh = inner.copy()
        sh[1:] &= inner[:-1]
        sh[:-1] &= inner[1:]
        sh[:, 1:] &= inner[:, :-1]
        sh[:, :-1] &= inner[:, 1:]
        inner = sh
    sharp = bleed(px, inner)
    soft = box_blur(sharp, BLUR_PX)
    glow = ((px.max(axis=2) > project.GLOW_THRESHOLD) & inner).astype(np.float32)
    img_sharp, img_soft, img_glow = np_image("_c_sharp", sharp), np_image("_c_soft", soft), np_image("_c_glow", glow)
    unwrap(ob)
    cams = [cam] if painted is not None else proj_cams(cam, group)
    for i, c in enumerate(cams):
        project._proj_uv(ob, c, f"p{i}")
        project._visibility([ob], c, f"vis{i}")
    sc.render.engine = "CYCLES"
    project.use_gpu()
    sc.cycles.samples = 1
    sc.render.bake.margin = 16
    mat = bpy.data.materials.new("_bake")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes.new, nt.links.new

    def tex(img, uv):
        u = N("ShaderNodeUVMap")
        u.uv_map = uv
        t = N("ShaderNodeTexImage")
        t.image = img
        t.extension = "EXTEND"
        L(u.outputs[0], t.inputs["Vector"])
        return t.outputs["Color"]

    def math_node(op, a, b=None, clamp=False):
        m = N("ShaderNodeMath")
        m.operation = op
        m.use_clamp = clamp
        for idx, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                m.inputs[idx].default_value = v
            else:
                L(v, m.inputs[idx])
        return m.outputs[0]

    def vmath(op, a, b):
        m = N("ShaderNodeVectorMath")
        m.operation = op
        L(a, m.inputs[0])
        if op == "SCALE":
            if isinstance(b, (int, float)):
                m.inputs["Scale"].default_value = b
            else:
                L(b, m.inputs["Scale"])
        else:
            L(b, m.inputs[1])
        return m.outputs[0]

    geo = N("ShaderNodeNewGeometry")
    weights = []
    for i, c in enumerate(cams):
        d = (c.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized()
        dot = N("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        L(geo.outputs["Normal"], dot.inputs[0])
        dot.inputs[1].default_value = tuple(-d)
        f = math_node("MULTIPLY", math_node("SUBTRACT", dot.outputs["Value"], 0.15), 2.2, clamp=True)
        f = math_node("POWER", f, 2.0)
        vis = N("ShaderNodeVertexColor")
        vis.layer_name = f"vis{i}"
        w = math_node("MULTIPLY", f, vis.outputs["Color"])
        if i > 0:  # повёрнутые камеры — только там, где камера концепта грань не видит
            w = math_node("MULTIPLY", w, math_node("SUBTRACT", 1.0, math_node("MULTIPLY", weights[0], 3.0), clamp=True))
        weights.append(w)

    def blend(images):
        total = weights[0]
        for w in weights[1:]:
            total = math_node("ADD", total, w)
        acc = None
        for i, w in enumerate(weights):
            term = vmath("SCALE", tex(images[0], f"p{i}"), w)
            acc = term if acc is None else vmath("ADD", acc, term)
        denom = math_node("MAXIMUM", total, 1.0)
        acc = vmath("SCALE", acc, math_node("DIVIDE", 1.0, denom))
        rest = math_node("SUBTRACT", 1.0, math_node("MINIMUM", total, 1.0))
        if images[1] is None:
            fb = None
        elif images[1] is painted:
            fb = vmath("SCALE", tex(painted, "huv"), rest)
        else:
            fb = vmath("SCALE", tex(images[1], "p0"), rest)
        return vmath("ADD", acc, fb) if fb is not None else acc

    em = N("ShaderNodeEmission")
    out = N("ShaderNodeOutputMaterial")
    L(em.outputs[0], out.inputs["Surface"])
    target = N("ShaderNodeTexImage")
    nt.nodes.active = target
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    color_img = bpy.data.images.new(f"{ob.name}_h3d", size, size)
    target.image = color_img
    L(blend([img_sharp, painted if painted is not None else img_soft]), em.inputs["Color"])
    bpy.ops.object.bake(type="EMIT")
    glow_img = bpy.data.images.new(f"{ob.name}_h3d_glow", size, size)
    target.image = glow_img
    L(blend([img_glow, None]), em.inputs["Color"])
    bpy.ops.object.bake(type="EMIT")
    for c in cams[1:]:
        bpy.data.objects.remove(c)
    color_img.pack()
    em_img = paint.emission_image(color_img, glow_img, f"{ob.name}_h3d_emit")
    final = bpy.data.materials.new(f"{ob.name}_h3d")
    final.use_nodes = True
    p = final.node_tree.nodes["Principled BSDF"]
    t = final.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = color_img
    final.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    te = final.node_tree.nodes.new("ShaderNodeTexImage")
    te.image = em_img
    final.node_tree.links.new(te.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = paint.GLOW_STRENGTH
    p.inputs["Roughness"].default_value = 0.82
    ob.data.materials.clear()
    ob.data.materials.append(final)
    bpy.data.materials.remove(mat)
    for name in ("p0", "p1", "p2", "p3", "huv"):
        layer = ob.data.uv_layers.get(name)
        if layer is not None:
            ob.data.uv_layers.remove(layer)
    for i in range(len(cams)):
        a = ob.data.color_attributes.get(f"vis{i}")
        if a is not None:
            ob.data.color_attributes.remove(a)
    sc.render.engine = "BLENDER_EEVEE"
    out_dir = kit.ROOT / "source_art" / "noir_h3d" / "tex"
    out_dir.mkdir(parents=True, exist_ok=True)
    color_img.filepath_raw = str(out_dir / f"{ob.name}.png")
    color_img.file_format = "PNG"
    color_img.save()


def use_painted(ob, img):
    """Материал из текстуры Hunyuan3D: та же схема, что у проекции (база + слабое свечение рисунка,
    яркое — пламя, разряды — светится сильнее)."""
    img.pack()
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    glow = (px[..., :3].max(axis=2) > project.GLOW_THRESHOLD).astype(np.float32)
    mask_img = np_image(f"{ob.name}_h3d_glow", np.dstack([glow, glow, glow])[::-1])  # np_image ждёт строки сверху вниз
    em_img = paint.emission_image(img, mask_img, f"{ob.name}_h3d_emit")
    img.name = f"{ob.name}_h3d"
    final = bpy.data.materials.new(f"{ob.name}_h3d")
    final.use_nodes = True
    p = final.node_tree.nodes["Principled BSDF"]
    t = final.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    final.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    te = final.node_tree.nodes.new("ShaderNodeTexImage")
    te.image = em_img
    final.node_tree.links.new(te.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = paint.GLOW_STRENGTH
    p.inputs["Roughness"].default_value = 0.82
    ob.data.materials.clear()
    ob.data.materials.append(final)
    print(f"[h3d] покраска Hunyuan3D {w}×{h}")


# ---------- плита и скелет ----------

def plate_top(ob) -> float:
    co = verts(ob)
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    n = 120
    base = None
    for i in range(n):
        lo, hi = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
        sl = co[(co[:, 2] >= lo) & (co[:, 2] < hi)]
        if len(sl) < 8:
            continue
        area = (sl[:, 0].max() - sl[:, 0].min()) * (sl[:, 1].max() - sl[:, 1].min())
        if base is None:
            base = area
        elif area < 0.55 * base and lo > z0 + 0.05:
            return lo
    return z0 + 0.3


def plate_image(ob):
    for m in ob.data.materials:
        if m is not None and m.node_tree is not None:
            for node in m.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image is not None:
                    return node.image
    return None


def patch_holes(bm, image=None):
    """Вырез под башней в плите: у двухклеточных построек плита кладётся под каждую клетку, а башня
    стоит между ними — вырез виден чёрной дырой. Латка заливается ровным цветом камня с угла плиты."""
    uv = bm.loops.layers.uv.active
    old = set(bm.faces)
    boundary = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
    if uv is None:
        return
    # ровный цвет камня: типичный (медианный) цвет верха плиты; берётся UV точки, ближайшей к нему по цвету
    top = max(v.co.z for v in bm.verts)
    uvs = [lp[uv].uv.copy() for v in bm.verts if v.co.z > top - 0.08
           for lp in v.link_loops if lp.face in old]
    stone = uvs[0]
    if image is not None and uvs:
        w, h = image.size
        px = np.empty(w * h * 4, dtype=np.float32)
        image.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)[..., :3]
        cols = np.array([px[min(int(u.y * h), h - 1) % h, min(int(u.x * w), w - 1) % w] for u in uvs])
        med = np.median(cols, axis=0)
        stone = uvs[int(np.argmin(np.abs(cols - med).sum(axis=1)))]
    for f in bm.faces:
        if f in old:
            continue
        for loop in f.loops:
            loop[uv].uv = stone


def split_plate(ob, mid: str):
    zt = plate_top(ob)
    pl = ob.copy()
    pl.data = ob.data.copy()
    pl.name = f"{mid}_plate"
    bpy.context.scene.collection.objects.link(pl)
    for target, keep_below in ((ob, False), (pl, True)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                               plane_co=(0, 0, zt), plane_no=(0, 0, 1),
                               clear_inner=not keep_below, clear_outer=keep_below)
        if keep_below:
            patch_holes(bm, plate_image(target))
        bm.to_mesh(target.data)
        bm.free()
    print(f"[h3d] плита до {zt:.2f} м")
    return pl


def cap_top(ob) -> float:
    """Верх шапки столба: снизу вверх от середины высоты — где ширина падает ниже 0,7 от самой широкой
    части над серединой (шапка шире столба, то, что торчит над ней, — уже)."""
    co = verts(ob)
    z0, z1 = co[:, 2].min(), co[:, 2].max()

    def extent(lo, hi):
        sl = co[(co[:, 2] >= lo) & (co[:, 2] < hi)]
        return 0.0 if len(sl) < 8 else float(max(np.ptp(sl[:, 0]), np.ptp(sl[:, 1])))

    step = (z1 - z0) / 150
    z = z0 + (z1 - z0) * 0.5
    widest = 0.0
    while z < z1:
        e = extent(z, z + step)
        widest = max(widest, e)
        if widest > 0 and e < 0.7 * widest and z > z0 + (z1 - z0) * 0.7:
            return z
        z += step
    return z1


def thunder_bolt(ob, mid: str):
    """Молния над столбом кодом: нейросеть рисует её вилкой (лишний зубец — «артефакт сверху»).
    Всё выше шапки срезается, на его место — зигзаг-молния к камере концепта и вторая поперёк."""
    co = verts(ob)
    z1 = float(co[:, 2].max())
    zc = cap_top(ob)
    band = co[(co[:, 2] > zc - 0.05) & (co[:, 2] <= zc)]
    cx, cy = float(band[:, 0].mean()), float(band[:, 1].mean())
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                           plane_co=(0, 0, zc + 0.01), plane_no=(0, 0, 1), clear_outer=True)
    bm.to_mesh(ob.data)
    bm.free()
    h = (z1 - zc) * 1.05
    # зигзаг как на концепте: широкий верх, излом, острый низ (x — поперёк взгляда, z — вверх), доли высоты
    outline = [(-0.1, 1.0), (0.13, 1.0), (0.03, 0.6), (0.17, 0.6), (-0.07, -0.12), (0.0, 0.45), (-0.15, 0.45)]
    cam = bpy.context.scene.camera
    look = cam.matrix_world.to_3x3() @ Vector((0, 0, -1))
    side = Vector((-look.y, look.x, 0)).normalized()
    depth = Vector((look.x, look.y, 0)).normalized()
    th = h * 0.045
    me = bpy.data.meshes.new(f"{mid}_bolt")
    bm = bmesh.new()
    # две молнии крестом: башню в игре можно повернуть, плоская сбоку видна ребром («палкой»)
    for sd, dp in ((side, depth), (depth, -side)):
        rows = []
        for d in (-th, th):
            rows.append([bm.verts.new(Vector((cx, cy, zc)) + sd * (x * h) + dp * d + Vector((0, 0, z * h)))
                         for x, z in outline])
        bm.faces.new(rows[0][::-1])
        bm.faces.new(rows[1])
        n = len(outline)
        for i in range(n):
            bm.faces.new([rows[0][i], rows[0][(i + 1) % n], rows[1][(i + 1) % n], rows[1][i]])
    # фаски: грани ловят лунный свет, молния выглядит металлической, а не вырезанной из бумаги
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=th * 0.8, segments=1, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.new(f"{mid}_bolt")
    mat.use_nodes = True
    pr = mat.node_tree.nodes["Principled BSDF"]
    pr.inputs["Base Color"].default_value = (0.74, 0.72, 0.92, 1.0)
    pr.inputs["Metallic"].default_value = 0.4
    pr.inputs["Roughness"].default_value = 0.35
    pr.inputs["Emission Color"].default_value = (0.8, 0.74, 1.0, 1.0)
    pr.inputs["Emission Strength"].default_value = 0.9
    me.materials.append(mat)
    bolt = bpy.data.objects.new(f"{mid}_bolt", me)
    bpy.context.scene.collection.objects.link(bolt)
    bpy.ops.object.select_all(action="DESELECT")
    bolt.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    print(f"[h3d] {mid}: молния кодом над шапкой {zc:.2f} м, высота {h:.2f} м")


# доработки кодом после покраски: то, что нейросеть стабильно портит
EXTRAS = {"thunder": thunder_bolt}


def add_rig(ob, mid: str, group: str):
    import units
    co = verts(ob)
    s = HEIGHT_BY_ID.get(mid, HEIGHT[group]) / 1.7
    # руки опущены, как на концептах (общий скелет — в A-позе 40°)
    j = units.skeleton(1.0)
    for side, sx in (("L", 1), ("R", -1)):
        sh = j[f"upper_arm.{side}"]
        d = Vector((sx * math.sin(math.radians(12)), 0, -math.cos(math.radians(12))))
        j[f"forearm.{side}"] = sh + d * 0.29
        j[f"hand.{side}"] = sh + d * 0.55
        j[f"hand_end.{side}"] = sh + d * 0.66
    arm = units.rig(ob, s=s, name="rig", joints=j)
    # плавные веса тепловой диффузией Blender (жёсткие «по близости» рвали полы одежды в «простыни»)
    for mod in list(ob.modifiers):
        ob.modifiers.remove(mod)
    ob.parent = None
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except RuntimeError as error:
        print("[h3d] веса тепла не вышли:", error)
    weighted = sum(1 for v in ob.data.vertices if v.groups)
    if weighted > 0.95 * len(ob.data.vertices):
        print(f"[h3d] скелет: веса тепловой диффузией ({weighted}/{len(ob.data.vertices)} вершин)")
        _legs_off_weapons(ob, arm, s)
        return arm
    print("[h3d] скелет: запасные веса по близости")
    if not ob.modifiers:
        ob.parent = arm
        ob.modifiers.new("rig", "ARMATURE").object = arm
    # веса по близости: каждая вершина — двум ближайшим костям (по расстоянию до отрезка кости)
    bones = [(b.name, Vector(b.head_local), Vector(b.tail_local)) for b in arm.data.bones]
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    groups = {name: ob.vertex_groups.new(name=name) for name, _, _ in bones}
    heads = np.array([h for _, h, _ in bones])
    tails = np.array([t for _, _, t in bones])
    seg = tails - heads
    seg_len2 = np.maximum((seg ** 2).sum(1), 1e-9)
    P = co[:, None, :] - heads[None]
    t = np.clip((P * seg[None]).sum(2) / seg_len2[None], 0, 1)
    closest = heads[None] + t[..., None] * seg[None]
    dist = np.linalg.norm(co[:, None, :] - closest, axis=2)
    order = np.argsort(dist, axis=1)[:, :2]
    for vi in range(len(co)):
        a, b = order[vi]
        da, db = dist[vi, a], dist[vi, b]
        wa = 1.0 if db - da > 0.2 * s else 0.5 + 0.5 * (db - da) / (0.2 * s)
        groups[bones[a][0]].add([vi], wa, "REPLACE")
        if wa < 1.0:
            groups[bones[b][0]].add([vi], 1.0 - wa, "REPLACE")
    return arm


def _legs_off_weapons(ob, arm, s: float):
    """Вершины далеко в стороне от ноги (копьё, посох, щит у земли) не должны идти за ногой — их вес ног → таз."""
    legs = {}
    for side in ("L", "R"):
        a = arm.data.bones[f"thigh.{side}"].head_local
        b = arm.data.bones[f"foot.{side}"].head_local
        c = arm.data.bones[f"foot.{side}"].tail_local  # носок
        legs[side] = ((np.array(a[:2]), np.array(b[:2])), (np.array(b[:2]), np.array(c[:2])))
    names = {g.index: g.name for g in ob.vertex_groups}
    hips = ob.vertex_groups["hips"]
    moved = 0
    for v in ob.data.vertices:
        leg_w = 0.0
        far = True
        for g in v.groups:
            name = names[g.group]
            if name.split(".")[0] in ("thigh", "shin", "foot") and g.weight > 0:
                side = name.split(".")[1]
                p = np.array(v.co[:2])
                dist = 1e9
                for a, b in legs[side]:
                    d = b - a
                    t = np.clip(np.dot(p - a, d) / max(np.dot(d, d), 1e-9), 0, 1)
                    dist = min(dist, float(np.linalg.norm(p - (a + t * d))))
                # у земли стопа узкая: копьё рядом с сапогом не должно идти за ногой
                limit = 0.12 * s if v.co.z < 0.3 * s else 0.22 * s
                if dist < limit:
                    far = False
                leg_w += g.weight
        if leg_w > 0 and far:
            for g in list(v.groups):
                if names[g.group].split(".")[0] in ("thigh", "shin", "foot"):
                    ob.vertex_groups[names[g.group]].remove([v.index])
            hips.add([v.index], leg_w, "ADD")
            moved += 1
    print(f"[h3d] скелет: {moved} вершин оружия/посохов сняты с ног")
    _rigid_islands(ob)


def _rigid_islands(ob):
    """Отдельные куски сетки (копьё, щит, посох) — целиком на одной кости (рука/таз), без изгиба."""
    n = len(ob.data.vertices)
    parent = np.arange(n)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for e in ob.data.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    roots = np.array([find(i) for i in range(n)])
    ids, counts = np.unique(roots, return_counts=True)
    main = ids[np.argmax(counts)]
    names = {g.index: g.name for g in ob.vertex_groups}
    fixed = 0
    for root, count in zip(ids, counts):
        if root == main or count < 30:
            continue
        members = np.nonzero(roots == root)[0]
        totals = {}
        for vi in members:
            for g in ob.data.vertices[vi].groups:
                name = names[g.group]
                if name.split(".")[0] in ("thigh", "shin", "foot"):
                    continue
                totals[name] = totals.get(name, 0.0) + g.weight
        bone = max(totals, key=totals.get) if totals else "hips"
        idx = [int(v) for v in members]
        for vg in ob.vertex_groups:
            vg.remove(idx)
        ob.vertex_groups[bone].add(idx, 1.0, "REPLACE")
        fixed += 1
    print(f"[h3d] скелет: {fixed} отдельных кусков (оружие и т. п.) — жёстко на одной кости")


# ---------- выход ----------

def export(objs, kind: str, name: str):
    out = kit.ROOT / "assets" / "noir_h3d" / kind / f"{name}.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for ch in o.children_recursive:
            ch.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out), use_selection=True, export_apply=True, export_cameras=False,
                              export_lights=False, export_yup=True, export_animations=False,
                              export_image_format="JPEG", export_jpeg_quality=92)
    return out


def build(mid: str, size: int, no_export: bool):
    group = group_of(mid)
    kind = KIND_BY_ID.get(mid, GROUPS[group])
    concept = concept_path(group, mid)
    ob = load(mid)
    cmask = clean_mask(project.concept_mask(concept), concept)
    if group in ("units", "heroes", "arena_props"):
        drop_floor(ob)
    decimate(ob, mid, group)
    el, az, _ = search_view(samples(ob), cmask, group)
    cam_az = stand(ob, group, mid, az)
    kit.setup_render(res=(project.W, project.H), elevation=el, azimuth=cam_az, ortho=4.0, look_z=1.0)
    pts = samples(ob)
    el, cam_az, smul = search_view(pts, cmask, group, around=(el, cam_az))
    place_camera(pts, cmask, el, cam_az, smul)
    tmp = RENDERS / f"{mid}__h3dmask.png"
    mmask = project.render_mask(tmp)
    iou = project.silhouette_report(cmask, mmask, RENDERS / f"{mid}_h3d_sil.png")
    tmp.unlink(missing_ok=True)
    print(f"[h3d] {mid}: силуэт IoU {iou:.3f}")
    (RENDERS / f"{mid}_h3d.iou").write_text(f"{iou:.3f}")
    if PAINT["on"] and mid in PAINTED and "--paint-only" in sys.argv:
        use_painted(ob, PAINTED[mid])
    else:
        paint_model(ob, concept, cmask, group, size, PAINTED.get(mid) if PAINT["on"] else None)
    objs = [ob]
    plate = None
    if group in ("buildings", "idols"):
        plate = split_plate(ob, mid)
    if mid in EXTRAS:
        EXTRAS[mid](ob, mid)
    kit.render(RENDERS / f"{mid}_h3d.png")
    if group in ("units", "heroes"):
        arm = add_rig(ob, mid, group)
        objs = [arm]
    if no_export:
        return
    print("[h3d] ->", export(objs, kind, mid))
    if plate is not None:
        print("[h3d] ->", export([plate], kind, f"{mid}_plate"))
    blend = kit.ROOT / "source_art" / "noir_h3d" / kind / f"{mid}.blend"
    blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), copy=True, compress=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    size = 4096
    if "--tex" in argv:
        size = int(argv[argv.index("--tex") + 1])
        argv = [a for a in argv if a not in ("--tex", str(size))]
    no_export = "--no-export" in argv
    PAINT["on"] = "--paint" in argv
    for mid in [a for a in argv if not a.startswith("--")]:
        build(mid, size, no_export)


main()
