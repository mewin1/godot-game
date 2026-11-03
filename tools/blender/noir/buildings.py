"""Постройки: башни школ, маяк, терем."""
import math
import random

from kit import M, point_light, gable, gable_wall, box, cyl, plate, prism, sphere, tube, zigzag, join_all, TIER_HEIGHT, PLATE_H

BUILD_VIEW = dict(res=(600, 760), elevation=34.0, azimuth=-40.0, ortho=4.3, look_z=1.25)


def rivets(prefix, center, half, z, count, material, r=0.035):
    """Заклёпки по передней и боковой граням квадратного блока."""
    cx, cy = center
    for k in range(count):
        t = -half + 2 * half * (k + 0.5) / count
        sphere(f"{prefix}_f{k}", r, (cx + t, cy - half - 0.005, z), material, 6, 4)
        sphere(f"{prefix}_s{k}", r, (cx - half - 0.005, cy + t, z), material, 6, 4)
        sphere(f"{prefix}_r{k}", r, (cx + half + 0.005, cy + t, z), material, 6, 4)


def thunder():
    """Грозовой столб (Перун, II): дубовый столб в железной оковке, громовое колесо, серебряная молния."""
    top = plate(2, "perun")
    h_total = TIER_HEIGHT[2]
    # железное основание
    box("base", (0.6, 0.6, 0.3), (0, 0, top + 0.15), M("steel"), 0.03)
    rivets("base_rv", (0, 0), 0.30, top + 0.16, 3, M("steel"))
    # дубовый столб с гранями
    pillar_h = 1.55
    z0 = top + 0.3
    box("pillar", (0.42, 0.42, pillar_h), (0, 0, z0 + pillar_h / 2), M("oak_warm"), 0.04)
    zig = [(0.0, 0.0), (0.05, 0.0), (0.0, 0.07), (0.05, 0.07), (-0.02, 0.17), (0.0, 0.09), (-0.05, 0.09)]
    for k, zz in enumerate((z0 + pillar_h * 0.72, z0 + pillar_h * 0.12)):  # золотые громовые знаки
        prism(f"zig_{k}", [(x * 1.3, y * 1.3) for x, y in zig], 0.025, (0.0, -0.215, zz), M("gold"),
              (math.pi / 2, 0, 0), 0.004)
    # железный оголовок с проёмом
    cap_z = z0 + pillar_h
    box("cap", (0.64, 0.64, 0.3), (0, 0, cap_z + 0.15), M("steel"), 0.03)
    cyl("cap_hole", 0.2, 0.2, 0.05, (0, 0, cap_z + 0.29), M("glow_perun"), 12)
    rivets("cap_rv", (0, 0), 0.32, cap_z + 0.15, 3, M("iron"))
    # серебряная молния-громоотвод: остаток высоты до TIER_HEIGHT
    bolt_h = h_total - (cap_z + 0.3)
    bolt_h = max(bolt_h, 0.75)
    from kit import sign_shapes
    bolt = [(x * 0.62, (y + 0.5) * bolt_h) for x, y in sign_shapes("perun")[0]]
    prism("bolt", bolt, 0.12, (0.0, 0.06, cap_z + 0.22), M("silver"), (math.pi / 2, 0, math.radians(-30)), 0.02)
    # громовое колесо на фасаде
    wz = z0 + pillar_h * 0.45
    cyl("wheel_rim", 0.17, 0.17, 0.04, (0, -0.23, wz), M("gold"), 16, (math.pi / 2, 0, 0))
    cyl("wheel_in", 0.13, 0.13, 0.05, (0, -0.23, wz), M("oak_warm_dark"), 16, (math.pi / 2, 0, 0))
    for k in range(6):
        a = math.pi * k / 3
        box(f"spoke_{k}", (0.025, 0.03, 0.26), (0, -0.245, wz), M("gold"), 0, (0, a, 0))
    cyl("wheel_hub", 0.04, 0.04, 0.06, (0, -0.25, wz), M("gold"), 8, (math.pi / 2, 0, 0))
    return join_all("thunder")


TEREM_LIGHTS = [(0.0, -0.75, 0.55), (0.0, -0.75, 1.55), (-0.85, 0.15, 1.2)]


def terem():
    """Терем (база, тёмный): резной дом-башня на каменном цоколе, тёплые окна, крутые тёмные кровли."""
    plate(1, "neutral", sign=False)
    top = PLATE_H
    # каменный цоколь
    box("plinth", (1.2, 1.1, 0.35), (0, 0.05, top + 0.175), M("stone_b"), 0.04)
    # сруб: этажи сужаются кверху
    floors = [(1.1, 1.0, 0.66), (1.04, 0.96, 0.62)]
    z = top + 0.35
    for i, (w, d, h) in enumerate(floors):
        box(f"floor_{i}", (w, d, h), (0, 0.05, z + h / 2), M("oak_dark"), 0.03)
        for k in range(int(h / 0.12)):  # бревенчатые венцы
            box(f"log_{i}_{k}", (w + 0.03, 0.04, 0.035), (0, 0.05 - d / 2 - 0.01, z + 0.06 + k * 0.12), M("oak"), 0.012)
        for sx in (-1, 1):  # угловые столбы
            box(f"corner_{i}_{sx}", (0.08, 0.08, h), (sx * (w / 2), 0.05 - d / 2, z + h / 2), M("oak"), 0.015)
        # окна с наличниками
        wins = [(-0.22,), (0.22,)]
        for (wx,) in wins:
            wz = z + h * 0.52
            box(f"win_{i}_{wx}", (0.2, 0.03, 0.28), (wx, 0.05 - d / 2 - 0.02, wz), M("window"))
            box(f"wincore_{i}_{wx}", (0.12, 0.03, 0.18), (wx, 0.05 - d / 2 - 0.028, wz), M("window_core"))
            box(f"winbar_{i}_{wx}", (0.025, 0.04, 0.28), (wx, 0.05 - d / 2 - 0.035, wz), M("oak_dark"))
            box(f"winbarh_{i}_{wx}", (0.2, 0.04, 0.025), (wx, 0.05 - d / 2 - 0.035, wz + 0.02), M("oak_dark"))
            box(f"frame_t_{i}_{wx}", (0.3, 0.06, 0.06), (wx, 0.05 - d / 2 - 0.035, wz + 0.17), M("oak"), 0.01)
            box(f"frame_b_{i}_{wx}", (0.28, 0.07, 0.04), (wx, 0.05 - d / 2 - 0.04, wz - 0.16), M("oak"), 0.01)
            prism(f"kokoshnik_{i}_{wx}", [(-0.15, 0), (0.15, 0), (0, 0.12)], 0.04,
                  (wx, 0.05 - d / 2 - 0.05, wz + 0.2), M("oak"), (math.pi / 2, 0, 0))
        # боковое окно
        box(f"winside_{i}", (0.03, 0.18, 0.24), (-w / 2 - 0.03, 0.1, z + h * 0.5), M("window"))
        # навес-кровля над этажом (полица)
        if i < 1:
            for sx in (-1, 1):
                box(f"eave_{i}_{sx}", (w * 0.62, d + 0.36, 0.06), (sx * w * 0.26, 0.05, z + h + 0.07), M("shingle"),
                    0.01, (0, sx * math.radians(-28), 0))
        z += h + (0.12 if i < 1 else 0.0)
    # кровля: два перекрещённых крутых фронтона, над ними шатёр с луковкой
    roof_h = 0.75
    w = 0.95
    for rz in (0.0, math.pi / 2):
        gable_wall(f"gw_{rz}", w * 0.92, roof_h * 0.92, w + 0.2, (0, 0.05, z), M("oak_dark"), rz)
        gable(f"gr_{rz}", w, roof_h, w + 0.2, (0, 0.05, z), M("shingle"), rz, 0.08)
        # ромбы-обереги на фронтонах
        for sgn in (-1, 1):
            off = (0, sgn * (w * 0.45 + 0.03)) if rz == 0.0 else (sgn * (w * 0.45 + 0.03), 0)
            box(f"rhomb_{rz}_{sgn}", (0.08, 0.08, 0.08), (off[0] * 1.25, 0.05 + off[1] * 1.25, z + 0.62), M("glow_curse"), 0,
                (0, math.pi / 4, rz))
    # окно во фронтоне (фасад и левый бок)
    box("gable_win", (0.2, 0.03, 0.26), (0, 0.05 - (w + 0.2) / 2 - 0.02, z + 0.3), M("window"))
    box("gable_win_bar", (0.02, 0.04, 0.26), (0, 0.05 - (w + 0.2) / 2 - 0.035, z + 0.3), M("oak_dark"))
    box("gable_win_l", (0.03, 0.2, 0.26), (-(w + 0.2) / 2 - 0.02, 0.05, z + 0.3), M("window"))
    for rz in (0.0, math.pi / 2):  # резные причелины: красноватые доски по кромке фронтонов
        for end in (-1, 1):
            for sgn in (-1, 1):
                ex = (w + 0.3) / 2 * end
                a0 = (sgn * (w / 2 + 0.1), ex, z - 0.06)
                a1 = (0.0, ex, z + roof_h + 0.04)
                pts = [a0, a1] if rz == 0.0 else [(a0[1], a0[0], a0[2]), (a1[1], a1[0], a1[2])]
                pts = [(px, 0.05 + py, pz) for px, py, pz in pts]
                tube(f"barge_{rz}_{end}_{sgn}", pts, 0.035, M("oak"), 4)
    rnd = random.Random(3)
    for k in range(6):  # мох на скатах
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.25, 0.5)
        sphere(f"roof_moss_{k}", 0.06, (rr * math.cos(a), 0.05 + rr * math.sin(a), z + roof_h * (1 - rr / 0.62) + 0.04),
               M("moss"), 6, 4, (1.5, 1.2, 0.45))
    cyl("tent", 0.22, 0.04, 0.6, (0, 0.05, z + roof_h + 0.15), M("shingle"), 8)
    cyl("tent_base", 0.3, 0.3, 0.1, (0, 0.05, z + roof_h - 0.12), M("oak_dark"), 8)
    sphere("onion", 0.13, (0, 0.05, z + roof_h + 0.5), M("shingle"), 10, 8, (1, 1, 1.4))
    cyl("spire", 0.035, 0.0, 0.35, (0, 0.05, z + roof_h + 0.78), M("iron"), 6)
    z_roof_top = z
    # боковой прируб с двускатной кровлей (слева) и крыльцо (справа спереди)
    for sx in (-1, 1):  # крылечки с маленькими фронтонами по бокам фасада
        px = sx * 0.42
        for k in range(2):
            box(f"porch_post_{sx}_{k}", (0.06, 0.06, 0.7), (px + (k - 0.5) * 0.3, -0.62, top + 0.35), M("oak"), 0.01)
        gable_wall(f"porch_gw_{sx}", 0.4, 0.22, 0.3, (px, -0.55, top + 0.72), M("oak_dark"), math.pi / 2 * 0)
        gable(f"porch_gr_{sx}", 0.4, 0.24, 0.42, (px, -0.55, top + 0.72), M("shingle"), math.pi / 2, 0.06)
    box("door", (0.26, 0.04, 0.42), (0.0, 0.05 - 0.48 - 0.02, top + 0.35 + 0.22), M("oak"), 0.01)
    for k in range(3):  # ступени крыльца
        box(f"step_{k}", (0.36, 0.14, 0.11), (0.0, -0.5 - 0.12 * (3 - k), top + 0.055 + 0.11 * k), M("oak"), 0.01)
    # знак-кокошник на фронтоне (фиолетовая искра — в концепте)
        # тёплый свет из окон и двери на плиту (в игре — OmniLight3D в тех же точках, см. NoirModels.TEREM_LIGHTS)
    for k, loc in enumerate(TEREM_LIGHTS):
        point_light(f"terem_light_{k}", loc, (1.0, 0.45, 0.12), 25.0)
    return join_all("terem")


def _plate_builder(tier, school):
    def build():
        plate(tier, school, sign=school != "neutral")
        return join_all(f"plate_{tier}_{school}", split_plate=False)
    return build


MODELS = {
    "thunder": dict(build=thunder, kind="towers", concept="buildings/thunder_16.png", view=BUILD_VIEW),
    "terem": dict(build=terem, kind="base", concept="buildings/terem_5.png", tex=2048,
                  view=dict(res=(600, 760), elevation=34.0, azimuth=-40.0, ortho=5.6, look_z=1.7)),
}

for _tier in (1, 2, 3):
    for _school in ("perun", "svarog", "stribog", "water", "ice", "war", "curse", "neutral"):
        MODELS[f"plate_{_tier}_{_school}"] = dict(build=_plate_builder(_tier, _school), kind="plates",
                                                  concept="buildings/thunder_16.png", view=BUILD_VIEW, no_render=True, tex=512)


# ---------------------------------------------------------------- силуэты по концептам (детали — проекция)

def spark():
    """Искровик (Перун, I): дубовый пень с корнями, серебряная катушка-штырь сверху."""
    top = plate(1, "perun")
    cyl("stump_foot", 0.5, 0.36, 0.3, (0, 0, top + 0.15), M("oak_warm"), 12)
    cyl("stump", 0.36, 0.3, 0.75, (0, 0, top + 0.3 + 0.375), M("oak_warm"), 12)
    for k in range(5):  # корни
        a = 2 * math.pi * k / 5 + 0.3
        tube(f"root_{k}", [(0.3 * math.cos(a), 0.3 * math.sin(a), top + 0.35),
                           (0.55 * math.cos(a), 0.55 * math.sin(a), top + 0.03)], 0.08, M("oak_warm"), 6, 0.5)
    cyl("stump_cap", 0.4, 0.38, 0.14, (0, 0, top + 1.12), M("oak_warm"), 14)
    cyl("rod", 0.035, 0.035, 0.7, (0, 0, top + 1.5), M("silver"), 8)
    for k in range(6):
        cyl(f"coil_{k}", 0.08, 0.08, 0.035, (0, 0, top + 1.3 + k * 0.07), M("silver"), 10)
    sphere("rod_tip", 0.05, (0, 0, top + 1.86), M("silver"), 8, 6)
    return join_all("spark")


def storm():
    """Грозовая решётка (Перун, III): стальной решётчатый шпиль с электродами и шаром бури."""
    top = plate(3, "perun")
    box("storm_base", (0.8, 0.8, 0.4), (0, 0, top + 0.2), M("steel"), 0.03)
    cyl("lattice", 0.5, 0.17, 2.1, (0, 0, top + 0.4 + 1.05), M("steel"), 4, (0, 0, math.pi / 4))
    box("storm_mid", (0.52, 0.52, 0.12), (0, 0, top + 1.3), M("gold"), 0.01)
    cyl("storm_spire", 0.14, 0.0, 0.75, (0, 0, top + 2.5 + 0.37), M("steel"), 4, (0, 0, math.pi / 4))
    sphere("storm_orb", 0.15, (0, 0, top + 3.3), M("glow_perun"), 12, 8)
    for sx in (-1, 1):
        cyl(f"electrode_{sx}", 0.03, 0.0, 0.5, (sx * 0.3, -0.05, top + 2.15), M("silver"), 6)
    return join_all("storm")


def brazier():
    """Жаровня (Сварог, I): кирпичный постамент, бронзовая чаша, пламя."""
    top = plate(1, "svarog")
    box("brz_ped", (0.62, 0.62, 0.6), (0, 0, top + 0.3), M("stone_warm"), 0.02)
    box("brz_ped_cap", (0.7, 0.7, 0.08), (0, 0, top + 0.62), M("stone_warm"), 0.02)
    cyl("brz_bowl", 0.28, 0.5, 0.38, (0, 0, top + 0.66 + 0.19), M("brass"), 18)
    cyl("brz_rim", 0.52, 0.52, 0.06, (0, 0, top + 1.05), M("brass"), 18)
    cyl("brz_coals", 0.46, 0.46, 0.05, (0, 0, top + 1.0), M("ember"), 16)
    for k, (dx, dy, hh, rr) in enumerate([(0, 0, 0.75, 0.3), (0.12, -0.05, 0.5, 0.18), (-0.14, 0.05, 0.45, 0.16)]):
        cyl(f"flame_{k}", rr, 0.0, hh, (dx, dy, top + 1.05 + hh / 2), M("glow_svarog"), 10)
    return join_all("brazier")


def furnace():
    """Горнило (Сварог, II): кирпичный купол-улей с огненным устьем, труба, наковальня и молот."""
    top = plate(2, "svarog")
    cyl("frn_base", 0.62, 0.62, 0.22, (0, 0.08, top + 0.11), M("stone_warm"), 20)
    sphere("frn_dome", 0.6, (0, 0.08, top + 0.22), M("stone_warm"), 20, 12, (1.0, 1.0, 1.35))
    cyl("frn_chimney", 0.17, 0.15, 0.7, (0, 0.08, top + 1.1), M("stone_warm"), 12)
    cyl("frn_chimney_top", 0.2, 0.2, 0.1, (0, 0.08, top + 1.45), M("stone_b"), 12)
    box("frn_mouth", (0.32, 0.1, 0.36), (0.12, -0.5, top + 0.45), M("ember"), 0.03)
    cyl("anvil_foot", 0.12, 0.16, 0.25, (-0.5, -0.45, top + 0.12), M("iron"), 8)
    box("anvil", (0.4, 0.16, 0.12), (-0.5, -0.45, top + 0.3), M("iron"), 0.02)
    cyl("hammer", 0.025, 0.025, 0.6, (0.62, -0.3, top + 0.45), M("oak"), 6, (0, math.radians(-20), 0))
    box("hammer_head", (0.18, 0.1, 0.1), (0.72, -0.3, top + 0.73), M("iron"), 0.01)
    return join_all("furnace")


def cinder():
    """Огненный венец (Сварог, III): кирпичная башенка, венец бронзовых шипов, пламя в центре."""
    top = plate(3, "svarog")
    cyl("cnd_tower", 0.48, 0.42, 1.15, (0, 0, top + 0.575), M("stone_warm"), 20)
    cyl("cnd_band", 0.46, 0.46, 0.1, (0, 0, top + 1.1), M("brass"), 20)
    for k in range(7):
        a = 2 * math.pi * k / 7
        cyl(f"spike_{k}", 0.07, 0.0, 0.6, (0.4 * math.cos(a), 0.4 * math.sin(a), top + 1.45), M("brass"), 6)
        sphere(f"lamp_{k}", 0.05, (0.47 * math.cos(a), 0.47 * math.sin(a), top + 0.7), M("ember"), 6, 4)
    for k, (hh, rr) in enumerate([(1.0, 0.3), (0.6, 0.2)]):
        cyl(f"cflame_{k}", rr, 0.0, hh, (0.05 * k, 0, top + 1.15 + hh / 2), M("glow_svarog"), 10)
    return join_all("cinder")


for _id, _fn in (("spark", spark), ("storm", storm), ("brazier", brazier), ("furnace", furnace), ("cinder", cinder)):
    MODELS[_id] = dict(build=_fn, kind="towers", concept=f"buildings/{_id}_16.png", view=BUILD_VIEW)
