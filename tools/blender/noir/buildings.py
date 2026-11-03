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
    cyl("stump_foot", 0.58, 0.4, 0.3, (0, 0, top + 0.15), M("oak_warm"), 12)
    cyl("stump", 0.4, 0.36, 1.0, (0, 0, top + 0.3 + 0.5), M("oak_warm"), 12)
    for k in range(5):  # корни
        a = 2 * math.pi * k / 5 + 0.3
        tube(f"root_{k}", [(0.3 * math.cos(a), 0.3 * math.sin(a), top + 0.35),
                           (0.55 * math.cos(a), 0.55 * math.sin(a), top + 0.03)], 0.08, M("oak_warm"), 6, 0.5)
    cyl("stump_cap", 0.5, 0.46, 0.18, (0, 0, top + 1.39), M("oak_warm"), 14)
    cyl("rod", 0.035, 0.035, 0.85, (0, 0, top + 1.85), M("silver"), 8)
    for k in range(6):
        cyl(f"coil_{k}", 0.08, 0.08, 0.035, (0, 0, top + 1.55 + k * 0.07), M("silver"), 10)
    sphere("rod_tip", 0.05, (0, 0, top + 2.28), M("silver"), 8, 6)
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
    for k, (dx, dy, hh, rr) in enumerate([(0, 0, 1.0, 0.36), (0.16, -0.05, 0.65, 0.22), (-0.18, 0.05, 0.6, 0.2)]):
        cyl(f"flame_{k}", rr, 0.0, hh, (dx, dy, top + 1.05 + hh / 2), M("glow_svarog"), 10)
    return join_all("brazier")


def furnace():
    """Горнило (Сварог, II): кирпичный купол-улей с огненным устьем, труба, наковальня и молот."""
    top = plate(2, "svarog")
    cyl("frn_base", 0.52, 0.52, 0.22, (0, 0.08, top + 0.11), M("stone_warm"), 20)
    sphere("frn_dome", 0.5, (0, 0.08, top + 0.22), M("stone_warm"), 20, 12, (1.0, 1.0, 1.45))
    cyl("frn_chimney", 0.17, 0.15, 0.7, (0, 0.08, top + 1.1), M("stone_warm"), 12)
    cyl("frn_chimney_top", 0.2, 0.2, 0.1, (0, 0.08, top + 1.45), M("stone_b"), 12)
    box("frn_mouth", (0.3, 0.1, 0.34), (0.1, -0.4, top + 0.45), M("ember"), 0.03)
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
        cyl(f"spike_{k}", 0.08, 0.0, 0.75, (0.4 * math.cos(a), 0.4 * math.sin(a), top + 1.5), M("brass"), 6)
        sphere(f"lamp_{k}", 0.05, (0.47 * math.cos(a), 0.47 * math.sin(a), top + 0.7), M("ember"), 6, 4)
    for k, (hh, rr) in enumerate([(1.3, 0.34), (0.8, 0.24)]):
        cyl(f"cflame_{k}", rr, 0.0, hh, (0.05 * k, 0, top + 1.15 + hh / 2), M("glow_svarog"), 10)
    return join_all("cinder")


for _id, _fn in (("spark", spark), ("storm", storm), ("brazier", brazier), ("furnace", furnace), ("cinder", cinder)):
    MODELS[_id] = dict(build=_fn, kind="towers", concept=f"buildings/{_id}_16.png", view=BUILD_VIEW)


def glow_ring(name, r, z, school, width=0.03):
    pts = [(r * math.cos(2 * math.pi * k / 32), r * math.sin(2 * math.pi * k / 32), z) for k in range(33)]
    tube(name, pts, width, M(f"glow_{school}"), 5)


def wind():
    """Ветродуй (Стрибог, I): берёзовый шест, ветряк из четырёх холщовых лопастей."""
    top = plate(1, "stribog", sign=False)
    glow_ring("w_ring", 0.42, top + 0.01, "stribog")
    glow_ring("w_ring2", 0.26, top + 0.01, "stribog", 0.02)
    cyl("w_pole", 0.08, 0.07, 1.95, (0, 0, top + 0.975), M("birch"), 10)
    cyl("w_hub", 0.08, 0.08, 0.14, (0, -0.1, top + 1.8), M("oak"), 10, (math.pi / 2, 0, 0))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        b = box(f"w_blade_{k}", (0.24, 0.025, 1.0), (0.52 * math.sin(a), -0.16, top + 1.8 + 0.52 * math.cos(a)),
                M("cloth_white"), 0.01)
        b.rotation_euler = (0, a, 0)
    return join_all("wind")


def gale():
    """Свистящий столб (Стрибог, II): высокий берёзовый шест с костяными свистульками и лентами."""
    top = plate(2, "stribog", sign=False)
    glow_ring("g_ring", 0.45, top + 0.01, "stribog")
    glow_ring("g_ring2", 0.28, top + 0.01, "stribog", 0.02)
    cyl("g_pole", 0.08, 0.06, 2.95, (0, 0, top + 1.475), M("birch"), 10)
    for k in range(5):
        z = top + 1.0 + k * 0.42
        box(f"g_whistle_{k}", (0.32, 0.04, 0.04), (0, 0, z), M("cloth_white"), 0.01, (0, 0, k * 0.9))
        a = k * 1.3
        tube(f"g_ribbon_{k}", [(0, 0, z), (0.25 * math.cos(a), 0.25 * math.sin(a), z + 0.05),
                               (0.5 * math.cos(a + 0.4), 0.5 * math.sin(a + 0.4), z - 0.05)], 0.025,
             M("glow_stribog") if k % 2 else M("cloth_white"), 4)
    return join_all("gale")


def vortex():
    """Ветряной круг (Стрибог, III): вихрь-воронка над светящимся кругом, перья по краю."""
    top = plate(3, "stribog", sign=False)
    glow_ring("v_ring", 0.6, top + 0.01, "stribog")
    glow_ring("v_ring2", 0.35, top + 0.01, "stribog", 0.02)
    kit_loft = __import__("kit").loft
    kit_loft("v_funnel", [(top + 0.05, 0.1, 0.1), (top + 0.6, 0.2, 0.2), (top + 1.2, 0.38, 0.38),
                          (top + 2.1, 0.72, 0.72), (top + 2.35, 0.85, 0.85)], M("glow_stribog"), 24,
             cap_top=False, cap_bottom=False)
    for k in range(6):
        a = 2 * math.pi * k / 6
        box(f"v_feather_{k}", (0.06, 0.02, 0.3), (0.88 * math.cos(a), 0.88 * math.sin(a), top + 2.35),
            M("cloth_white"), 0.01, (0.4, 0, a))
    return join_all("vortex")


def dew():
    """Росник (Вода, I): мокрый камень на корягах, стеклянная кувшинка с росой."""
    top = plate(1, "water", sign=False)
    glow_ring("d_ring", 0.48, top + 0.01, "water")
    cyl("d_stone", 0.36, 0.3, 1.2, (0, 0, top + 0.6), M("stone_wet"), 12, bev=0.03)
    cyl("d_stone_top", 0.42, 0.42, 0.14, (0, 0, top + 1.25), M("stone_wet"), 12, bev=0.03)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        tube(f"d_root_{k}", [(0.28 * math.cos(a), 0.28 * math.sin(a), top + 1.1),
                             (0.42 * math.cos(a), 0.42 * math.sin(a), top + 0.5),
                             (0.5 * math.cos(a), 0.5 * math.sin(a), top + 0.02)], 0.07, M("oak_warm"), 6, 0.6)
    for k in range(8):
        a = 2 * math.pi * k / 8
        cyl(f"d_petal_{k}", 0.08, 0.0, 0.3, (0.14 * math.cos(a), 0.14 * math.sin(a), top + 1.45), M("glow_water"),
            6, (math.cos(a) * 0.7, math.sin(a) * -0.7, 0))
    return join_all("dew")


def water():
    """Водяной желоб (Вода, II): деревянный жёлоб на козлах, железная рыбья голова льёт воду в лужу."""
    top = plate(2, "water", sign=False)
    glow_ring("wt_ring", 0.42, top + 0.01, "water")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"wt_leg_{sx}_{sy}", (0.08, 0.08, 1.0), (sx * 0.42, sy * 0.15, top + 0.5), M("oak_warm"), 0.01,
                (sy * 0.15, 0, 0))
    box("wt_trough", (1.05, 0.34, 0.24), (0, 0, top + 1.0), M("oak_warm"), 0.02)
    box("wt_water", (0.95, 0.26, 0.02), (0, 0, top + 1.1), M("glow_water"))
    cyl("wt_pipe", 0.11, 0.11, 0.5, (0.45, 0.0, top + 1.35), M("iron"), 10, (0, math.pi / 2, 0))
    cyl("wt_head", 0.16, 0.13, 0.3, (0.75, 0.0, top + 1.35), M("iron"), 10, (0, math.pi / 2, 0))
    box("wt_stream", (0.06, 0.12, 0.5), (-0.56, 0, top + 0.75), M("glow_water"))
    return join_all("water")


def rain():
    """Дождевой круг (Вода, III): круглая беседка под тёмной тучей, дождь в круглую чашу."""
    top = plate(3, "water", sign=False)
    glow_ring("r_ring", 0.6, top + 0.01, "water")
    cyl("r_basin", 0.5, 0.52, 0.18, (0, 0, top + 0.09), M("stone_wet"), 20)
    cyl("r_pool", 0.44, 0.44, 0.02, (0, 0, top + 0.18), M("glow_water"), 20)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        cyl(f"r_post_{k}", 0.04, 0.04, 1.2, (0.42 * math.cos(a), 0.42 * math.sin(a), top + 0.78), M("oak"), 8)
    cyl("r_ring_top", 0.5, 0.5, 0.08, (0, 0, top + 1.38), M("brass"), 20)
    cyl("r_roof", 0.52, 0.12, 0.3, (0, 0, top + 1.55), M("oak"), 16)
    for k, (dx, dy, dz, rr) in enumerate([(0, 0, 1.95, 0.32), (0.25, 0.05, 1.88, 0.24), (-0.25, -0.05, 1.9, 0.25),
                                          (0.05, 0.2, 2.05, 0.22)]):
        sphere(f"r_cloud_{k}", rr, (dx, dy, top + dz), M("cloud"), 12, 8)
    cyl("r_rainfall", 0.3, 0.3, 1.1, (0, 0, top + 0.75), M("glow_water"), 12, cap=False)
    return join_all("rain")


def rime():
    """Иней (Лёд, I): придорожная божница под снегом, сосульки, светящаяся ниша."""
    top = plate(1, "ice")
    box("rm_post", (0.5, 0.5, 1.45), (0, 0, top + 0.725), M("birch"), 0.02)
    box("rm_niche", (0.3, 0.04, 0.4), (0, -0.26, top + 1.1), M("glow_ice"))
    gable_wall("rm_gw", 0.62, 0.3, 0.62, (0, 0, top + 1.45), M("birch"))
    gable("rm_roof", 0.7, 0.34, 0.76, (0, 0, top + 1.45), M("snow"), math.pi / 2, 0.08, 0.08)
    for k in range(5):
        cyl(f"rm_icicle_{k}", 0.025, 0.0, 0.16, (-0.24 + k * 0.12, -0.36, top + 1.37), M("glow_ice"), 5,
            (math.pi, 0, 0))
    return join_all("rime")


def glacier():
    """Ледник (Лёд, II): глыба льда с белёной деревянной дверной рамой, кристаллы сверху."""
    top = plate(2, "ice")
    box("gl_block", (0.72, 0.6, 1.7), (0, 0.05, top + 0.85), M("snow"), 0.06)
    box("gl_frame", (0.5, 0.06, 1.2), (0, -0.27, top + 0.62), M("birch"), 0.02)
    box("gl_door", (0.36, 0.04, 1.05), (0, -0.29, top + 0.55), M("oak"), 0.01)
    for k, (dx, dy, hh) in enumerate([(0, 0.05, 0.5), (-0.18, 0.1, 0.35), (0.2, 0.0, 0.4)]):
        cyl(f"gl_crystal_{k}", 0.12, 0.0, hh, (dx, dy, top + 1.7 + hh / 2), M("glow_ice"), 6)
    return join_all("glacier")


def ice_lance():
    """Ледяное копьё (Лёд, III): высокий белый столп-баллиста с ледяным наконечником."""
    top = plate(3, "ice")
    box("il_base", (0.7, 0.7, 0.4), (0, 0, top + 0.2), M("birch"), 0.03)
    for sx in (-1, 1):
        box(f"il_strut_{sx}", (0.1, 0.1, 0.9), (sx * 0.3, 0, top + 0.75), M("birch"), 0.01, (0, sx * 0.25, 0))
    box("il_pillar", (0.3, 0.3, 2.1), (0, 0, top + 1.45), M("snow"), 0.02)
    box("il_band", (0.36, 0.36, 0.08), (0, 0, top + 2.3), M("gold"), 0.01)
    cyl("il_tip", 0.16, 0.0, 0.7, (0, 0, top + 2.85), M("glow_ice"), 4)
    return join_all("ice_lance")


for _id, _fn in (("wind", wind), ("gale", gale), ("vortex", vortex), ("dew", dew), ("water", water), ("rain", rain),
                 ("rime", rime), ("glacier", glacier), ("ice_lance", ice_lance)):
    MODELS[_id] = dict(build=_fn, kind="towers", concept=f"buildings/{_id}_16.png", view=BUILD_VIEW)


def bolt():
    """Самострел (Война, I): арбалет на поворотной колоде, багровые флажки."""
    top = plate(1, "war")
    cyl("b_log", 0.13, 0.15, 1.0, (0, 0, top + 0.5), M("oak"), 10)
    box("b_stock", (0.18, 1.0, 0.12), (0, 0, top + 1.07), M("oak_warm"), 0.02, (0, 0, math.radians(-35)))
    box("b_bow", (1.1, 0.08, 0.08), (0.17, -0.25, top + 1.11), M("iron"), 0.01, (0, 0, math.radians(-35)))
    for sx in (-1, 1):
        box(f"b_flag_{sx}", (0.04, 0.2, 0.3), (0.17 + sx * 0.45 * 0.82, -0.25 + sx * 0.45 * -0.57, top + 1.01),
            M("cloth_red"), 0.005, (0, 0, math.radians(-35)))
    return join_all("bolt")


def war_engine():
    """Осадный станок (Война, II): катапульта на колёсах с длинным рычагом и противовесом."""
    top = plate(2, "war")
    box("we_frame", (0.9, 0.55, 0.22), (0, 0, top + 0.45), M("oak"), 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(f"we_wheel_{sx}_{sy}", 0.22, 0.22, 0.08, (sx * 0.34, sy * 0.33, top + 0.24), M("iron"), 14,
                (math.pi / 2, 0, 0))
    for sy in (-1, 1):
        box(f"we_post_{sy}", (0.1, 0.08, 0.7), (-0.05, sy * 0.2, top + 0.85), M("oak"), 0.01)
    cyl("we_drum", 0.18, 0.18, 0.45, (0.25, 0, top + 0.72), M("iron"), 14, (math.pi / 2, 0, 0))
    box("we_arm", (0.08, 0.08, 1.5), (-0.2, 0, top + 1.45), M("oak_warm"), 0.01, (0, math.radians(25), 0))
    cyl("we_cup", 0.1, 0.12, 0.12, (-0.52, 0, top + 2.12), M("iron"), 10)
    return join_all("war_engine")


def war_rocket():
    """Ракетница (Война, III): бронированная телега со стойкой огненных стрел."""
    top = plate(3, "war")
    box("wr_cart", (0.8, 0.62, 0.55), (0, 0, top + 0.55), M("iron"), 0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(f"wr_wheel_{sx}_{sy}", 0.24, 0.24, 0.09, (sx * 0.3, sy * 0.36, top + 0.25), M("oak"), 14,
                (math.pi / 2, 0, 0))
    box("wr_rack", (0.6, 0.5, 0.75), (0, 0.05, top + 1.2), M("oak"), 0.02, (math.radians(-12), 0, 0))
    box("wr_box", (0.24, 0.24, 0.85), (0.32, 0.18, top + 1.25), M("iron"), 0.02)
    for k in range(6):
        cyl(f"wr_rocket_{k}", 0.025, 0.025, 0.7, (-0.2 + (k % 3) * 0.15, -0.1 + (k // 3) * 0.2, top + 1.75), M("oak"),
            6, (math.radians(-12), 0, 0))
    for sx in (-1, 1):
        box(f"wr_flag_{sx}", (0.04, 0.22, 0.35), (sx * 0.2, -0.2, top + 1.3), M("cloth_red"), 0.005)
    return join_all("war_rocket")


def hex_post():
    """Чёрная метка (Порча, I): кривой мёртвый столб, костяная маска, вороньи перья, шипы у подножия."""
    top = plate(1, "curse")
    tube("h_post", [(0, 0, top), (0.05, 0.02, top + 0.85), (-0.03, 0.0, top + 1.7), (0.02, 0.0, top + 2.3)], 0.17,
         M("oak_dark"), 8, 0.75)
    sphere("h_skull", 0.19, (0.0, -0.16, top + 1.8), M("cloth_white"), 12, 8, (1, 0.8, 1.1))
    for k in range(6):
        a = 2 * math.pi * k / 6
        cyl(f"h_thorn_{k}", 0.05, 0.0, 0.4, (0.22 * math.cos(a), 0.22 * math.sin(a), top + 0.18), M("glow_curse"), 5,
            (math.cos(a) * 0.5, -math.sin(a) * 0.5, 0))
    return join_all("hex")


def plague():
    """Моровой колокол (Порча, II): кривая виселица из мёртвого дерева с треснутым колоколом."""
    top = plate(2, "curse")
    tube("p_post", [(0.1, 0.1, top), (0.12, 0.1, top + 1.4), (0.08, 0.1, top + 2.6)], 0.12, M("oak_dark"), 8, 0.8)
    box("p_beam", (0.7, 0.12, 0.12), (-0.15, 0.1, top + 2.55), M("oak_dark"), 0.02)
    cyl("p_bell", 0.07, 0.15, 0.22, (-0.4, 0.1, top + 2.32), M("brass"), 12)
    for k in range(7):
        a = 2 * math.pi * k / 7
        cyl(f"p_thorn_{k}", 0.05, 0.0, 0.45, (0.1 + 0.25 * math.cos(a), 0.1 + 0.25 * math.sin(a), top + 0.2),
            M("glow_curse"), 5, (math.cos(a) * 0.5, -math.sin(a) * 0.5, 0))
    return join_all("plague")


def doom():
    """Чёрный обелиск (Порча, III): высокий обсидиановый обелиск с рунами и шипами у основания."""
    top = plate(3, "curse")
    cyl("dm_obelisk", 0.3, 0.2, 2.6, (0, 0, top + 1.3), M("stone_b"), 4, (0, 0, math.pi / 4))
    cyl("dm_tip", 0.2, 0.0, 0.4, (0, 0, top + 2.8), M("stone_b"), 4, (0, 0, math.pi / 4))
    for k in range(6):
        box(f"dm_rune_{k}", (0.1, 0.02, 0.1), (0, -0.2 + k * 0.005, top + 0.6 + k * 0.35), M("glow_curse"), 0,
            (0, 0, 0))
    for k in range(8):
        a = 2 * math.pi * k / 8
        cyl(f"dm_thorn_{k}", 0.06, 0.0, 0.55, (0.32 * math.cos(a), 0.32 * math.sin(a), top + 0.22), M("oak_dark"), 5,
            (math.cos(a) * 0.6, -math.sin(a) * 0.6, 0))
    return join_all("doom")


def beacon():
    """Маяк (I): дубовая вышка на четырёх ногах с латунным прожектором."""
    top = plate(1, "neutral", sign=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube(f"bc_leg_{sx}_{sy}", [(sx * 0.45, sy * 0.45, top), (sx * 0.17, sy * 0.17, top + 2.0)], 0.05, M("oak"), 6)
    for z, r in ((0.6, 0.36), (1.25, 0.27)):
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            box(f"bc_rail_{z}_{k}", (r * 1.45, 0.04, 0.04), (r * math.cos(a) * 0.7, r * math.sin(a) * 0.7, top + z),
                M("oak"), 0, (0, 0, a + math.pi / 2))
    box("bc_deck", (0.46, 0.46, 0.08), (0, 0, top + 2.02), M("oak"), 0.01)
    cyl("bc_lamp", 0.2, 0.24, 0.65, (0.05, -0.05, top + 2.3), M("brass"), 14, (math.radians(70), 0, math.radians(-40)))
    cyl("bc_lens", 0.22, 0.22, 0.03, (0.2, -0.24, top + 2.42), M("glow_neutral"), 14, (math.radians(70), 0, math.radians(-40)))
    return join_all("beacon")


for _id, _fn in (("bolt", bolt), ("war_engine", war_engine), ("war_rocket", war_rocket), ("hex", hex_post),
                 ("plague", plague), ("doom", doom), ("beacon", beacon)):
    MODELS[_id] = dict(build=_fn, kind="towers", concept=f"buildings/{_id}_16.png", view=BUILD_VIEW)
