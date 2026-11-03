"""«Рисованная» текстура модели: процедурный шейдер по типу материала запекается в одну картинку.

Что даёт вид концепта вместо пластилина: волокно дерева, трещины камня, пятна и износ,
светлые кромки (как мазок кистью), тёмные щели (AO), нарисованный свет сверху, грязь у земли.
Светящиеся материалы (эмиссия) не запекаются — остаются своими слотами.
"""
import json
from pathlib import Path

import bpy

TEX_DIR = Path(__file__).resolve().parents[3] / "source_art" / "noir" / "textures"
TEX_MEAN = json.loads((TEX_DIR / "means.json").read_text()) if (TEX_DIR / "means.json").exists() else {}
# тип материала -> (фактура, метров на повтор, сила)
TEXTURE = {"wood": ("wood", 1.2, 0.75), "bark": ("bark", 1.4, 0.8), "shingle": ("shingle", 0.9, 0.85),
           "stone": ("stone", 0.9, 0.35), "metal": ("metal", 0.7, 0.6), "mail": ("mail", 0.22, 0.9),
           "cloth": ("cloth", 0.6, 0.2), "leather": ("cloth", 0.5, 0.2)}

KINDS = [  # префикс имени материала -> тип
    ("glow_", "glow"), ("idol_eyes", "glow"), ("idol_runes", "glow"), ("window", "glow"), ("window_core", "glow"), ("ember", "glow"),
    ("oak", "wood"), ("birch", "wood"), ("idol_wood", "bark"), ("idol_carve", "bark"), ("shingle", "shingle"),
    ("stone", "stone"), ("moss", "moss"),
    ("iron", "metal"), ("steel", "metal"), ("silver", "keep"), ("helm", "keep"), ("gold", "keep"), ("brass", "keep"),
    ("chainmail", "mail"), ("idol_band", "metal"),
    ("cloth", "cloth"), ("rope", "cloth"), ("hair", "cloth"),
    ("leather", "leather"), ("skin", "skin"),
]

# тип: (крупные пятна min..max, мелкая фактура min..max, масштаб фактуры, сила кромки, сила AO)
RECIPE = {
    "wood": ((0.8, 1.15), (0.55, 1.2), 3.0, 0.55, 0.65),
    "bark": ((0.85, 1.15), (0.7, 1.15), 3.0, 0.6, 0.7),
    "shingle": ((0.75, 1.2), (0.6, 1.15), 5.0, 0.6, 0.7),
    "stone": ((0.7, 1.2), (0.8, 1.12), 30.0, 0.5, 0.7),
    "moss": ((0.6, 1.3), (0.7, 1.3), 25.0, 0.2, 0.5),
    "metal": ((0.75, 1.1), (0.75, 1.1), 40.0, 0.6, 0.6),
    "mail": ((0.8, 1.1), (0.45, 1.25), 160.0, 0.35, 0.6),
    "cloth": ((0.8, 1.12), (0.88, 1.06), 70.0, 0.35, 0.6),
    "leather": ((0.75, 1.15), (0.8, 1.1), 20.0, 0.55, 0.6),
    "skin": ((0.92, 1.06), (0.96, 1.04), 8.0, 0.25, 0.4),
}


def kind_of(material) -> str:
    name = material.name if material else ""
    for prefix, kind in KINDS:
        if name.startswith(prefix):
            return kind
    p = material.node_tree.nodes.get("Principled BSDF") if material and material.node_tree else None
    if p is not None and p.inputs["Emission Strength"].default_value > 0.0:
        return "glow"
    return "cloth"


def _base_color(material):
    p = material.node_tree.nodes.get("Principled BSDF")
    return tuple(p.inputs["Base Color"].default_value)[:3] if p else (0.5, 0.5, 0.5)


def _bake_tree(material, image, kind):
    """Пересобрать дерево узлов материала: цвет с фактурой -> Emission (для запекания EMIT)."""
    base = _base_color(material)
    nt = material.node_tree
    if kind == "glow":  # светящееся — ровный цвет свечения (сам блеск даёт маска свечения)
        nt.nodes.clear()
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*[min(1.0, c * 1.2) for c in base], 1.0)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.nodes.active = tex
        return
    big, fine, fine_scale, edge_k, ao_k = RECIPE.get(kind, RECIPE["cloth"])
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new
    tc = N("ShaderNodeTexCoord")
    geo = N("ShaderNodeNewGeometry")

    def rng(src, a, b, lo, hi):
        m = N("ShaderNodeMapRange")
        m.clamp = True
        L(src, m.inputs["Value"])
        m.inputs["From Min"].default_value, m.inputs["From Max"].default_value = a, b
        m.inputs["To Min"].default_value, m.inputs["To Max"].default_value = lo, hi
        return m.outputs["Result"]

    def mul(x, y):
        m = N("ShaderNodeMath")
        m.operation = "MULTIPLY"
        L(x, m.inputs[0])
        L(y, m.inputs[1])
        return m.outputs[0]

    noise_big = N("ShaderNodeTexNoise")
    noise_big.inputs["Scale"].default_value = 1.6
    noise_big.inputs["Detail"].default_value = 3.0
    L(tc.outputs["Object"], noise_big.inputs["Vector"])
    f = rng(noise_big.outputs["Fac"], 0.3, 0.7, *big)
    tex_spec = TEXTURE.get(kind)
    tex_path = TEX_DIR / f"{tex_spec[0]}.png" if tex_spec else None
    if tex_path is not None and tex_path.exists():
        img = bpy.data.images.get(tex_path.name) or bpy.data.images.load(str(tex_path))
        mp = N("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / tex_spec[1],) * 3
        L(tc.outputs["Object"], mp.inputs["Vector"])
        ti = N("ShaderNodeTexImage")
        ti.image = img
        ti.projection = "BOX"
        ti.projection_blend = 0.25
        L(mp.outputs["Vector"], ti.inputs["Vector"])
        bw = N("ShaderNodeRGBToBW")
        L(ti.outputs["Color"], bw.inputs[0])
        mean = TEX_MEAN.get(tex_spec[0], 0.4)
        f = mul(f, rng(bw.outputs[0], 0.0, 2 * mean, 1 - tex_spec[2], 1 + tex_spec[2]))
    elif kind in ("wood", "shingle"):
        wave = N("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "Z" if kind == "wood" else "X"
        wave.inputs["Scale"].default_value = fine_scale
        wave.inputs["Distortion"].default_value = 9.0
        wave.inputs["Detail"].default_value = 4.0
        L(tc.outputs["Object"], wave.inputs["Vector"])
        f = mul(f, rng(wave.outputs["Fac"], 0.0, 1.0, *fine))
    if tex_path is None or not tex_path.exists() or kind in ("stone", "cloth", "leather", "skin", "moss"):
        nf = N("ShaderNodeTexNoise")
        nf.inputs["Scale"].default_value = fine_scale
        nf.inputs["Detail"].default_value = 2.0
        L(tc.outputs["Object"], nf.inputs["Vector"])
        f = mul(f, rng(nf.outputs["Fac"], 0.3, 0.7, *fine))
    if kind == "stone":  # трещины и сколы
        vor = N("ShaderNodeTexVoronoi")
        vor.feature = "DISTANCE_TO_EDGE"
        vor.inputs["Scale"].default_value = 7.0
        L(tc.outputs["Object"], vor.inputs["Vector"])
        f = mul(f, rng(vor.outputs["Distance"], 0.0, 0.035, 0.45, 1.0))
    # тёмные щели (AO)
    ao = N("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.25
    f = mul(f, rng(ao.outputs["AO"], 0.0, 1.0, 1.0 - ao_k, 1.0))
    # нарисованный свет: верх светлее, низ темнее
    sep = N("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], sep.inputs[0])
    f = mul(f, rng(sep.outputs["Z"], -1.0, 1.0, 0.62, 1.22))
    # грязь у земли
    sep_p = N("ShaderNodeSeparateXYZ")
    L(tc.outputs["Object"], sep_p.inputs[0])
    f = mul(f, rng(sep_p.outputs["Z"], 0.0, 0.45, 0.72, 1.0))
    col = N("ShaderNodeRGB")
    col.outputs[0].default_value = (*base, 1.0)
    shaded = N("ShaderNodeVectorMath")
    shaded.operation = "SCALE"
    L(col.outputs[0], shaded.inputs[0])
    L(f, shaded.inputs["Scale"])
    # светлые кромки: AO «изнутри» с малым радиусом находит выпуклые рёбра
    edge_ao = N("ShaderNodeAmbientOcclusion")
    edge_ao.inside = True
    edge_ao.only_local = True
    edge_ao.inputs["Distance"].default_value = 0.035
    edge = rng(edge_ao.outputs["AO"], 1.0, 0.55, 0.0, edge_k)
    light = N("ShaderNodeVectorMath")
    light.operation = "MULTIPLY_ADD"
    L(col.outputs[0], light.inputs[0])
    light.inputs[1].default_value = (1.4, 1.35, 1.25)
    light.inputs[2].default_value = (0.05, 0.045, 0.04)
    scaled_light = N("ShaderNodeVectorMath")
    scaled_light.operation = "SCALE"
    L(light.outputs[0], scaled_light.inputs[0])
    L(edge, scaled_light.inputs["Scale"])
    total = N("ShaderNodeVectorMath")
    total.operation = "ADD"
    L(shaded.outputs[0], total.inputs[0])
    L(scaled_light.outputs[0], total.inputs[1])
    em = N("ShaderNodeEmission")
    L(total.outputs[0], em.inputs["Color"])
    out = N("ShaderNodeOutputMaterial")
    L(em.outputs[0], out.inputs["Surface"])
    tex = N("ShaderNodeTexImage")
    tex.image = image
    nt.nodes.active = tex


def bake(ob, size: int = 1024, path=None):
    """Запечь все незаметные (не светящиеся) материалы объекта в одну текстуру <имя>_paint."""
    mats = list(ob.data.materials)
    painted = [m for m in mats if kind_of(m) != "keep"]
    if not painted:
        return
    sc = bpy.context.scene
    prev_engine = sc.render.engine
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 12
    import project
    project.use_gpu()
    # развёртка
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    if not ob.data.uv_layers:
        ob.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    image = bpy.data.images.new(f"{ob.name}_paint", size, size)
    # временные копии материалов под запекание
    temp = {}
    for i, m in enumerate(mats):
        if m in painted:
            t = m.copy()
            t.name = f"_bake_{m.name}"
            _bake_tree(t, image, kind_of(m))
            temp[i] = t
            ob.data.materials[i] = t
    sc.render.bake.margin = 4
    sc.render.bake.use_clear = True
    bpy.ops.object.bake(type="EMIT")
    # маска свечения: белое там, где материал светится
    mask = bpy.data.images.new(f"{ob.name}_glowmask", size, size)
    for i, t in temp.items():
        glow = kind_of(mats[i]) == "glow"
        nt = t.node_tree
        nt.nodes.clear()
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (1, 1, 1, 1) if glow else (0, 0, 0, 1)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = mask
        nt.nodes.active = tn
    sc.cycles.samples = 1
    bpy.ops.object.bake(type="EMIT")
    ob["glow_mask"] = mask.name
    emission = emission_image(image, mask, f"{ob.name}_emit")
    if path is not None:
        path.parent.mkdir(parents=True, exist_ok=True)
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
    # итоговый материал: картинка + шероховатость; светящиеся слоты остаются
    paint = bpy.data.materials.new(f"{ob.name}_paint")
    paint.use_nodes = True
    p = paint.node_tree.nodes["Principled BSDF"]
    t = paint.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = image
    paint.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    te = paint.node_tree.nodes.new("ShaderNodeTexImage")
    te.image = emission
    paint.node_tree.links.new(te.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = GLOW_STRENGTH
    p.inputs["Roughness"].default_value = 0.78
    p.inputs["Metallic"].default_value = 0.0
    keep = [m for m in mats if m not in painted]
    new_mats = [paint] + keep
    remap = [0 if m in painted else 1 + keep.index(m) for m in mats]
    old_idx = [poly.material_index for poly in ob.data.polygons]
    for i, m in enumerate(new_mats):
        ob.data.materials[i] = m
    while len(ob.data.materials) > len(new_mats):
        ob.data.materials.pop(index=len(ob.data.materials) - 1)
    for poly, idx in zip(ob.data.polygons, old_idx):
        poly.material_index = remap[idx]
    for t in temp.values():
        bpy.data.materials.remove(t)
    sc.render.engine = prev_engine


GLOW_STRENGTH = 3.0
BASE_GLOW = 0.13  # доля свечения у несветящихся мест: 0,13 × 3 ≈ 0,4 — рисунок читается в темноте


def emission_image(color_img, mask_img, name: str):
    """Текстура свечения: цвет × (0,13 + 0,87 × маска); в материале сила 3 — светится нарисованное."""
    import numpy as np
    w, h = color_img.size
    c = np.array(color_img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    mw, mh = mask_img.size
    m = np.array(mask_img.pixels[:], dtype=np.float32).reshape(mh, mw, 4)[..., :1]
    if (mw, mh) != (w, h):
        m = np.zeros((h, w, 1), dtype=np.float32)
    out = c.copy()
    out[..., :3] = c[..., :3] * (BASE_GLOW + (1 - BASE_GLOW) * m)
    out[..., 3] = 1.0
    img = bpy.data.images.new(name, w, h)
    img.pixels[:] = out.ravel()
    img.pack()
    return img
