"""Идол: ОДНА сетка для всех богов. Варианты — только материалы слотов idol_* и эффекты в Godot.

Слоты: idol_wood (ствол), idol_carve (тёмная резьба лица/рук), idol_eyes (глаза),
idol_runes (желобки-руны на стволе), idol_band (обручи). Камни и плита — общие.
"""
import math
import random

import kit
from kit import M, box, cyl, plate, sphere, mat, join_all, TIER_HEIGHT

# Варианты: материалы слотов (цвет дерева, резьбы, глаз/рун со свечением, обручей).
VARIANTS = {
    "empty": dict(wood=(0.2, 0.1, 0.05), carve=(0.12, 0.05, 0.02), eyes=None, runes=None, band=(0.2, 0.09, 0.04)),
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
        sphere(f"ring_{k}", 0.12, (r * math.cos(a), r * math.sin(a), top + 0.04), rnd.choice([M("stone"), M("stone_c")]),
               7, 5, (1.0, 0.8, 0.6), (0, 0, a))
    h = TIER_HEIGHT[2] - top
    z0 = top
    # ствол: расширяется книзу, круглый плоский верх (шапка)
    cyl("trunk_foot", 0.42, 0.33, 0.3, (0, 0, z0 + 0.15), S["idol_wood"], 14)
    cyl("trunk", 0.33, 0.26, h - 0.55, (0, 0, z0 + 0.3 + (h - 0.55) / 2), S["idol_wood"], 14)
    hat_z = z0 + h - 0.25
    cyl("hat", 0.34, 0.34, 0.25, (0, 0, hat_z + 0.125), S["idol_wood"], 14, bev=0.03)
    cyl("hat_rings", 0.26, 0.26, 0.01, (0, 0, hat_z + 0.251), S["idol_carve"], 14)
    cyl("band_hat", 0.345, 0.345, 0.05, (0, 0, hat_z + 0.02), S["idol_band"], 14)
    # лицо: надбровье, глаза, нос, усы, борода — на фронте (-Y)
    fz = hat_z - 0.3
    fy = -0.27
    box("brow", (0.4, 0.12, 0.08), (0, fy - 0.04, fz + 0.14), S["idol_wood"], 0.02)
    for sx in (-1, 1):
        box(f"socket_{sx}", (0.13, 0.06, 0.07), (sx * 0.09, fy - 0.01, fz + 0.06), S["idol_carve"], 0.01)
        box(f"eye_{sx}", (0.09, 0.04, 0.035), (sx * 0.09, fy - 0.035, fz + 0.06), S["idol_eyes"], 0.008)
        box(f"stache_{sx}", (0.2, 0.09, 0.07), (sx * 0.1, fy - 0.07, fz - 0.1), S["idol_wood"], 0.015,
            (0, sx * math.radians(-20), 0))
    box("nose", (0.11, 0.16, 0.2), (0, fy - 0.07, fz - 0.01), S["idol_wood"], 0.025)
    box("mouth", (0.14, 0.04, 0.025), (0, fy - 0.03, fz - 0.16), S["idol_carve"])
    box("beard", (0.32, 0.12, 0.3), (0, fy - 0.03, fz - 0.32), S["idol_wood"], 0.03)
    for k in range(5):  # пряди бороды
        box(f"beard_line_{k}", (0.015, 0.02, 0.22), (-0.12 + k * 0.06, fy - 0.095, fz - 0.32), S["idol_carve"])
    # руки, прижатые к стволу, кисти сходятся спереди
    az = fz - 0.7
    for sx in (-1, 1):
        box(f"arm_{sx}", (0.13, 0.2, 0.55), (sx * 0.29, -0.06, az + 0.12), S["idol_wood"], 0.03, (0, sx * math.radians(12), 0))
        box(f"hand_{sx}", (0.2, 0.13, 0.13), (sx * 0.13, fy - 0.01, az - 0.16), S["idol_wood"], 0.025)
        for k in range(3):
            box(f"finger_{sx}_{k}", (0.12, 0.02, 0.015), (sx * 0.13, fy - 0.08, az - 0.12 - k * 0.035), S["idol_carve"])
    # обручи и руны на стволе
    cyl("band_low", 0.315, 0.315, 0.06, (0, 0, z0 + 0.42), S["idol_band"], 14)
    for k, (zz, ang) in enumerate([(az - 0.4, -0.5), (az - 0.62, 0.6), (az - 0.3, 2.2), (az - 0.55, 3.6)]):
        x, y = 0.3 * math.sin(ang), -0.3 * math.cos(ang)
        box(f"rune_{k}", (0.03, 0.02, 0.24), (x, y, zz), S["idol_runes"], 0, (0, 0, ang))
        box(f"rune_t_{k}", (0.09, 0.02, 0.025), (x, y, zz + 0.08), S["idol_runes"], 0, (math.radians(30), 0, ang))
    for k in range(6):  # мох у подножия
        a = rnd.uniform(0, 2 * math.pi)
        sphere(f"imoss_{k}", 0.06, (0.33 * math.cos(a), 0.33 * math.sin(a), z0 + 0.06), M("moss"), 6, 4, (1.4, 1, 0.5))
    return join_all(f"idol_{variant}" if variant != "empty" else "idol")


VIEW = dict(res=(600, 760), elevation=30.0, azimuth=0.0, ortho=4.0, look_z=1.35)


def _builder(variant):
    return lambda: idol(variant)


MODELS = {"idol": dict(build=_builder("empty"), kind="idols", concept="idols/idol_empty_16.png", view=VIEW)}
for _v in VARIANTS:
    if _v != "empty":
        MODELS[f"idol_{_v}"] = dict(build=_builder(_v), kind="idols", concept=f"idols/idol_{_v}_16.png", view=VIEW,
                                    no_export=True)
