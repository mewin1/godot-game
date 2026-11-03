"""Идол: ОДНА сетка для всех богов. Варианты — только материалы слотов idol_* и эффекты в Godot.

Слоты: idol_wood (ствол), idol_carve (тёмная резьба лица/рук), idol_eyes (глаза),
idol_runes (желобки-руны на стволе), idol_band (обручи). Камни и плита — общие.
"""
import math
import random

import bpy
from mathutils import Matrix

import kit
from kit import M, box, cyl, plate, prism, sphere, tube, mat, join_all, TIER_HEIGHT

# Варианты: материалы слотов (цвет дерева, резьбы, глаз/рун со свечением, обручей).
VARIANTS = {
    "empty": dict(wood=(0.3, 0.16, 0.075), carve=(0.12, 0.05, 0.02), eyes=None, runes=None, band=(0.2, 0.09, 0.04)),
    "perun": dict(wood=(0.16, 0.07, 0.035), carve=(0.07, 0.03, 0.015), eyes="perun", runes="perun", band=(0.75, 0.75, 0.82)),
    "svarog": dict(wood=(0.03, 0.025, 0.022), carve=(0.02, 0.015, 0.01), eyes="svarog", runes="svarog", band=(0.55, 0.3, 0.1)),
    "stribog": dict(wood=(0.62, 0.6, 0.52), carve=(0.25, 0.24, 0.2), eyes="stribog", runes="stribog", band=(0.4, 0.38, 0.3)),
    "water": dict(wood=(0.06, 0.07, 0.07), carve=(0.02, 0.03, 0.03), eyes="water", runes="water", band=(0.1, 0.2, 0.2)),
    "ice": dict(wood=(0.55, 0.65, 0.72), carve=(0.3, 0.4, 0.5), eyes="ice", runes="ice", band=(0.75, 0.88, 0.95)),
    "war": dict(wood=(0.14, 0.06, 0.03), carve=(0.05, 0.02, 0.01), eyes=None, runes="war", band=(0.2, 0.2, 0.22)),
    "curse": dict(wood=(0.025, 0.02, 0.025), carve=(0.01, 0.01, 0.012), eyes="curse", runes="curse", band=(0.05, 0.12, 0.03)),
}


def slot_materials(variant: str) -> dict:
    v = VARIANTS[variant]

    def glow_or(school, fallback):
        if school is None:
            return dict(color=fallback, rough=0.85)
        c = kit.SCHOOL_GLOW[school]
        return dict(color=c, rough=0.4, emit=c, strength=3.0)

    return {
        "idol_wood": dict(color=v["wood"], rough=0.8),
        "idol_carve": dict(color=v["carve"], rough=0.85),
        "idol_eyes": glow_or(v["eyes"], (0.02, 0.01, 0.005)),
        "idol_runes": glow_or(v["runes"], v["carve"]),
        "idol_band": dict(color=v["band"], rough=0.4, metal=0.5),
    }


def _slots(variant):
    return {name: mat(name, **spec) for name, spec in slot_materials(variant).items()}


def idol(variant: str = "empty"):
    S = _slots(variant)
    top = plate(1, "neutral", sign=False)
    rnd = random.Random(5)
    # кольцо камней
    for k in range(11):
        a = 2 * math.pi * k / 11 + rnd.uniform(-0.1, 0.1)
        r = 0.46
        sphere(f"ring_{k}", 0.13, (0.55 * math.cos(a), 0.55 * math.sin(a), top + 0.05), rnd.choice([M("stone_c"), M("stone_c"), M("stone")]),
               7, 5, (1.0, 0.8, 0.6), (0, 0, a))
    h = IDOL_HEIGHT - top
    z0 = top
    # ствол: заметно шире книзу, плоская круглая шапка с годичными кольцами
    cyl("trunk_foot", 0.5, 0.38, 0.32, (0, 0, z0 + 0.16), S["idol_wood"], 16)
    cyl("trunk", 0.38, 0.3, h - 0.6, (0, 0, z0 + 0.32 + (h - 0.6) / 2), S["idol_wood"], 16)
    hat_z = z0 + h - 0.28
    cyl("hat", 0.34, 0.34, 0.28, (0, 0, hat_z + 0.14), S["idol_wood"], 16, bev=0.03)
    for k in range(3):
        cyl(f"hat_ring_{k}", 0.27 - k * 0.08, 0.27 - k * 0.08, 0.008, (0, 0, hat_z + 0.281 + k * 0.002),
            S["idol_carve"], 16, cap=False)
    cyl("band_hat", 0.345, 0.345, 0.05, (0, 0, hat_z + 0.02), S["idol_band"], 16)
    # лицо: тяжёлые нахмуренные брови, глубокие глазницы, крупный нос, вислые усы, борода клином
    fz = hat_z - 0.3
    r_face = 0.31

    def on_trunk(x, z, out=0.0):
        return (x, -math.sqrt(max(r_face ** 2 - x * x, 0.0)) - out, z)

    brow = [on_trunk(x, fz + 0.15 - 0.07 * (1 - abs(x) / 0.24), 0.05) for x in (-0.25, -0.15, -0.05, 0.0, 0.05, 0.15, 0.25)]
    tube("brow", brow, 0.065, S["idol_wood"], 8)
    for sx in (-1, 1):
        sphere(f"socket_{sx}", 0.08, on_trunk(sx * 0.11, fz + 0.06, -0.005), S["idol_carve"], 10, 6, (1.25, 0.7, 0.8))
        box(f"eye_{sx}", (0.09, 0.04, 0.035), on_trunk(sx * 0.11, fz + 0.055, 0.045), S["idol_eyes"], 0.008,
            (0, sx * math.radians(-12), 0))
        stache = [on_trunk(sx * 0.02, fz - 0.07, 0.1), on_trunk(sx * 0.09, fz - 0.09, 0.08),
                  on_trunk(sx * 0.16, fz - 0.17, 0.05), on_trunk(sx * 0.19, fz - 0.29, 0.03)]
        tube(f"stache_{sx}", [(x * 1.15, y - 0.02, z) for x, y, z in stache], 0.058, S["idol_wood"], 8, 0.45)
        sphere(f"cheek_{sx}", 0.07, on_trunk(sx * 0.13, fz - 0.02, 0.0), S["idol_wood"], 8, 6, (1, 0.6, 0.8))
    nose = box("nose", (0.14, 0.17, 0.25), on_trunk(0, fz - 0.0, 0.1), S["idol_wood"], 0.035)
    nose.rotation_euler = (math.radians(-14), 0, 0)
    box("mouth", (0.14, 0.04, 0.03), on_trunk(0, fz - 0.15, 0.03), S["idol_carve"])
    prism("beard", [(-0.2, 0), (0.2, 0), (0.08, -0.46), (0.0, -0.5), (-0.08, -0.46)], 0.17,
          (0, -r_face + 0.06, fz - 0.17), S["idol_wood"], (math.pi / 2, 0, 0), 0.03)
    for k in range(5):  # пряди бороды
        x = -0.1 + k * 0.05
        box(f"beard_line_{k}", (0.016, 0.02, 0.3 - abs(x) * 0.9), (x * 1.2, -r_face - 0.115, fz - 0.35 + abs(x) * 0.4),
            S["idol_carve"])
    # толстые руки охватывают ствол, кисти сходятся спереди на животе
    az = fz - 0.68
    for sx in (-1, 1):
        arm = [(sx * 0.31, 0.08, az + 0.24), (sx * 0.39, -0.08, az + 0.08), (sx * 0.3, -0.27, az - 0.06),
               (sx * 0.14, -0.36, az - 0.1)]
        tube(f"arm_{sx}", arm, 0.09, S["idol_wood"], 10, 0.85)
        box(f"hand_{sx}", (0.17, 0.11, 0.15), (sx * 0.1, -0.37, az - 0.12), S["idol_wood"], 0.03)
        for k in range(3):
            box(f"finger_{sx}_{k}", (0.13, 0.02, 0.016), (sx * 0.1, -0.43, az - 0.08 - k * 0.04), S["idol_carve"])
    # обручи и руны на стволе
    cyl("band_low", 0.375, 0.375, 0.06, (0, 0, z0 + 0.42), S["idol_band"], 14)
    for k, (zz, ang) in enumerate([(az - 0.4, -0.5), (az - 0.62, 0.6), (az - 0.3, 2.2), (az - 0.55, 3.6)]):
        x, y = 0.34 * math.sin(ang), -0.34 * math.cos(ang)
        box(f"irune_{k}", (0.03, 0.02, 0.24), (x, y, zz), S["idol_runes"], 0, (0, 0, ang))
        box(f"irune_t_{k}", (0.09, 0.02, 0.025), (x, y, zz + 0.08), S["idol_runes"], 0, (math.radians(30), 0, ang))
    for k in range(6):  # мох у подножия
        a = rnd.uniform(0, 2 * math.pi)
        sphere(f"imoss_{k}", 0.06, (0.33 * math.cos(a), 0.33 * math.sin(a), z0 + 0.06), M("moss"), 6, 4, (1.4, 1, 0.5))
    # лицо концепта смотрит в камеру, а плита стоит ромбом: ствол повёрнут относительно плиты на 40°
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.parent is None and not o.name.startswith(kit.PLATE_PREFIXES) \
                and not o.name.startswith("ring_"):
            o.matrix_world = Matrix.Rotation(math.radians(FACE_YAW), 4, "Z") @ o.matrix_world
    return join_all(f"idol_{variant}" if variant != "empty" else "idol")


FACE_YAW = -40.0
IDOL_HEIGHT = 3.4  # по силуэту концепта: идол выше башни II
VIEW = dict(res=(600, 760), elevation=30.0, azimuth=-40.0, ortho=4.0, look_z=1.35)


def _builder(variant):
    return lambda: idol(variant)


MODELS = {"idol": dict(build=_builder("empty"), kind="idols", concept="idols/idol_empty_16.png", view=VIEW)}
for _v in VARIANTS:
    if _v != "empty":
        MODELS[f"idol_{_v}"] = dict(build=_builder(_v), kind="idols", concept=f"idols/idol_{_v}_16.png", view=VIEW,
                                    no_export=True)
