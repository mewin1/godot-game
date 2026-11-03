"""Люди-юниты и герои: общий скелет (A-поза), жёсткие веса — каждая деталь принадлежит одной кости.

Рост юнита-человека HUMAN_H = 1,7 м; одежда и силуэт задаются частями поверх общего тела.
"""
import math

import bpy
from mathutils import Vector

import kit
from kit import M, box, cyl, sphere, tube, prism, join_all

ARM_ANGLE = math.radians(40)  # A-поза: руки на 40° от вертикали


def _vg(ob, bone):
    vg = ob.vertex_groups.new(name=bone)
    vg.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
    return ob


def P(ob, bone):
    """Привязать деталь к кости."""
    return _vg(ob, bone)


def skeleton(s: float = 1.0) -> dict:
    """Точки суставов общего скелета (для роста 1,7 м; s — масштаб)."""
    j = {
        "hips": Vector((0, 0, 0.9)), "spine": Vector((0, 0, 1.08)), "chest": Vector((0, 0, 1.24)),
        "neck": Vector((0, 0, 1.42)), "head": Vector((0, 0, 1.5)), "head_end": Vector((0, 0, 1.72)),
    }
    for side, sx in (("L", 1), ("R", -1)):
        sh = Vector((sx * 0.2, 0, 1.38))
        d = Vector((sx * math.sin(ARM_ANGLE), 0, -math.cos(ARM_ANGLE)))
        j[f"shoulder.{side}"] = Vector((sx * 0.05, 0, 1.38))
        j[f"upper_arm.{side}"] = sh
        j[f"forearm.{side}"] = sh + d * 0.29
        j[f"hand.{side}"] = sh + d * 0.55
        j[f"hand_end.{side}"] = sh + d * 0.66
        j[f"thigh.{side}"] = Vector((sx * 0.1, 0, 0.88))
        j[f"shin.{side}"] = Vector((sx * 0.1, 0, 0.48))
        j[f"foot.{side}"] = Vector((sx * 0.1, 0, 0.09))
        j[f"toe.{side}"] = Vector((sx * 0.1, -0.16, 0.03))
    return {k: v * s for k, v in j.items()}


BONES = [  # имя, начало, конец, родитель
    ("hips", "hips", "spine", None), ("spine", "spine", "chest", "hips"), ("chest", "chest", "neck", "spine"),
    ("neck", "neck", "head", "chest"), ("head", "head", "head_end", "neck"),
]
for _s in ("L", "R"):
    BONES += [
        (f"shoulder.{_s}", f"shoulder.{_s}", f"upper_arm.{_s}", "chest"),
        (f"upper_arm.{_s}", f"upper_arm.{_s}", f"forearm.{_s}", f"shoulder.{_s}"),
        (f"forearm.{_s}", f"forearm.{_s}", f"hand.{_s}", f"upper_arm.{_s}"),
        (f"hand.{_s}", f"hand.{_s}", f"hand_end.{_s}", f"forearm.{_s}"),
        (f"thigh.{_s}", f"thigh.{_s}", f"shin.{_s}", "hips"),
        (f"shin.{_s}", f"shin.{_s}", f"foot.{_s}", f"thigh.{_s}"),
        (f"foot.{_s}", f"foot.{_s}", f"toe.{_s}", f"shin.{_s}"),
    ]


def rig(mesh_ob, s: float = 1.0, name: str = "rig"):
    j = skeleton(s)
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for bone, a, b, parent in BONES:
        e = arm_data.edit_bones.new(bone)
        e.head, e.tail = j[a], j[b]
        if parent:
            e.parent = eb[parent]
            e.use_connect = False
        eb[bone] = e
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh_ob.parent = arm
    mod = mesh_ob.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    return arm


def limb(name, a, b, r1, r2, material, bone, verts=10):
    """Цилиндр между двумя точками."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = cyl(name, r1, r2, d.length, (a + b) / 2, material, verts)
    ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return P(ob, bone)


def body(j, skin, legs, boots, arms_mat, hands=None, torso=None, s=1.0):
    """Базовое тело (без головы): ноги, таз, торс, руки."""
    hands = hands or skin
    torso = torso or arms_mat
    for side, sx in (("L", 1), ("R", -1)):
        limb(f"thigh_{side}", j[f"thigh.{side}"], j[f"shin.{side}"], 0.085 * s, 0.068 * s, legs, f"thigh.{side}")
        limb(f"shin_{side}", j[f"shin.{side}"], j[f"foot.{side}"] + Vector((0, 0, 0.02)), 0.068 * s, 0.058 * s,
             boots, f"shin.{side}")
        P(box(f"foot_{side}", (0.11 * s, 0.25 * s, 0.09 * s), j[f"foot.{side}"] + Vector((0, -0.05 * s, -0.04 * s)),
              boots, 0.03), f"foot.{side}")
        limb(f"uarm_{side}", j[f"upper_arm.{side}"], j[f"forearm.{side}"], 0.058 * s, 0.05 * s, arms_mat,
             f"upper_arm.{side}")
        limb(f"farm_{side}", j[f"forearm.{side}"], j[f"hand.{side}"], 0.05 * s, 0.042 * s, arms_mat, f"forearm.{side}")
        hc = j[f"hand.{side}"].lerp(j[f"hand_end.{side}"], 0.5)
        P(sphere(f"hand_{side}", 0.048 * s, hc, hands, 8, 6, (0.8, 1.0, 1.25)), f"hand.{side}")
        P(sphere(f"shoulder_{side}", 0.07 * s, j[f"upper_arm.{side}"], arms_mat, 8, 6), f"shoulder.{side}")
    P(cyl("pelvis", 0.15 * s, 0.155 * s, 0.16 * s, j["hips"] + Vector((0, 0, -0.02 * s)), legs, 12), "hips")
    tz = j["spine"]
    P(sphere("belly", 0.165 * s, tz, torso, 12, 8, (1.0, 0.72, 1.1)), "spine")
    P(sphere("chest", 0.19 * s, j["chest"] + Vector((0, 0, 0.04 * s)), torso, 12, 8, (1.08, 0.72, 1.0)), "chest")
    limb("neck", j["neck"] + Vector((0, 0, -0.04 * s)), j["head"] + Vector((0, 0, 0.03 * s)), 0.05 * s, 0.048 * s, skin,
         "neck")


def head(j, skin, hair=None, beard=None, s=1.0):
    c = j["head"] + Vector((0, 0, 0.1 * s))
    P(sphere("head", 0.105 * s, c, skin, 14, 10, (0.88, 0.95, 1.12)), "head")
    P(box("nose", (0.03 * s, 0.05 * s, 0.05 * s), c + Vector((0, -0.1 * s, -0.01 * s)), skin, 0.01), "head")
    for sx in (-1, 1):
        P(sphere(f"eye_{sx}", 0.013 * s, c + Vector((sx * 0.037 * s, -0.088 * s, 0.018 * s)), M("cloth_dark"), 6, 4),
          "head")
        P(box(f"brow_{sx}", (0.045 * s, 0.015 * s, 0.012 * s), c + Vector((sx * 0.037 * s, -0.093 * s, 0.04 * s)),
              hair or M("hair_brown")), "head")
    if beard is not None:
        P(sphere("beard", 0.08 * s, c + Vector((0, -0.055 * s, -0.08 * s)), beard, 10, 6, (1.0, 0.7, 1.1)), "head")
    return c


def torso_bone(z: float) -> str:
    return "chest" if z > 1.2 else ("spine" if z > 1.0 else "hips")


def coat(name, rings, material, **kw):
    return kit.loft(name, rings, material, 20, weight=torso_bone, cap_bottom=False, **kw)


def arms(j, sleeve, cuff, hand, r=(0.062, 0.052, 0.045)):
    for side in ("L", "R"):
        sh, el, wr = j[f"upper_arm.{side}"], j[f"forearm.{side}"], j[f"hand.{side}"]
        P(kit.limb_tube(f"sleeve_u_{side}", [sh, sh.lerp(el, 0.5), el], [r[0], r[0] * 0.95, r[1]], sleeve), f"upper_arm.{side}")
        P(kit.limb_tube(f"sleeve_f_{side}", [el, el.lerp(wr, 0.5), wr], [r[1], r[1] * 0.95, r[2]], sleeve), f"forearm.{side}")
        if cuff is not None:
            c0 = el.lerp(wr, 0.82)
            P(kit.limb_tube(f"cuff_{side}", [c0, wr], [r[2] * 1.18, r[2] * 1.18], cuff), f"forearm.{side}")
        hc = j[f"hand.{side}"].lerp(j[f"hand_end.{side}"], 0.45)
        P(sphere(f"hand_{side}", 0.046, hc, hand, 8, 6, (0.75, 1.0, 1.3)), f"hand.{side}")


def legs(j, trousers, boots, boot_top: float = 0.34, r=(0.08, 0.062, 0.055)):
    for side in ("L", "R"):
        hip, knee, ank = j[f"thigh.{side}"], j[f"shin.{side}"], j[f"foot.{side}"]
        P(kit.limb_tube(f"thigh_{side}", [hip, hip.lerp(knee, 0.5), knee], [r[0], r[0] * 0.95, r[1]], trousers), f"thigh.{side}")
        bt = Vector((ank.x, ank.y, boot_top))
        P(kit.limb_tube(f"shin_{side}", [knee, bt + Vector((0, 0, 0.04))], [r[1] * 1.05, r[2] * 1.15], trousers), f"shin.{side}")
        P(kit.limb_tube(f"boot_{side}", [bt + Vector((0, 0, 0.02)), ank.lerp(bt, 0.4), ank],
                        [r[2] * 1.18, r[2] * 1.05, r[2]], boots), f"shin.{side}")
        P(box(f"foot_{side}", (0.1, 0.24, 0.085), ank + Vector((0, -0.055, -0.045)), boots, 0.035), f"foot.{side}")


def face(c, skin, hair, s=1.0):
    P(sphere("head", 0.1 * s, c, skin, 16, 12, (0.86, 0.96, 1.2)), "head")
    P(box("nose", (0.026, 0.045, 0.055), c + Vector((0, -0.098, -0.005)), skin, 0.012), "head")
    for sx in (-1, 1):
        P(sphere(f"eye_{sx}", 0.012, c + Vector((sx * 0.035, -0.083, 0.012)), M("cloth_dark"), 6, 4), "head")
        P(box(f"brow_{sx}", (0.045, 0.02, 0.014), c + Vector((sx * 0.036, -0.09, 0.036)), hair, 0.004,
              (0, sx * math.radians(-10), 0)), "head")
        P(sphere(f"ear_{sx}", 0.022, c + Vector((sx * 0.088, 0.0, -0.005)), skin, 6, 4, (0.5, 1, 1.2)), "head")
    P(box("mouth", (0.04, 0.01, 0.008), c + Vector((0, -0.092, -0.048)), M("cloth_red_dark")), "head")


def spearman():
    """Копейщик: красный кафтан до колен поверх кольчуги, конический шлем с бармицей, щит с чёрным солнцем."""
    j = skeleton()
    red, red_d, white = M("cloth_red"), M("cloth_red_dark"), M("cloth_white")
    legs(j, M("cloth_dark"), M("leather"))
    coat("caftan", [(0.44, 0.27, 0.2, 0, 0.01), (0.56, 0.245, 0.185), (0.7, 0.21, 0.16), (0.85, 0.175, 0.13),
                    (0.95, 0.165, 0.12), (1.08, 0.172, 0.122), (1.22, 0.19, 0.125), (1.33, 0.2, 0.12),
                    (1.4, 0.15, 0.095), (1.44, 0.065, 0.06)], red)
    coat("hem", [(0.43, 0.275, 0.205, 0, 0.01), (0.5, 0.262, 0.197, 0, 0.01)], white, cap_top=False)
    for k in range(12):  # узор каймы
        a = 2 * math.pi * k / 12
        P(box(f"hem_dot_{k}", (0.03, 0.01, 0.03), (0.272 * math.cos(a), 0.01 + 0.205 * math.sin(a), 0.465), red_d, 0,
              (0, math.pi / 4, a + math.pi / 2)), "hips")
    coat("belt", [(0.92, 0.172, 0.127), (0.98, 0.172, 0.127)], M("leather"))
    P(box("buckle", (0.06, 0.02, 0.05), (0, -0.13, 0.95), M("brass"), 0.005), "hips")
    P(box("pouch", (0.07, 0.05, 0.09), (-0.15, -0.07, 0.88), M("leather_dark"), 0.015), "hips")
    P(box("knife", (0.03, 0.03, 0.2), (0.16, -0.06, 0.84), M("leather_dark"), 0.008), "hips")
    P(box("placket", (0.045, 0.012, 0.36), (0, -0.124, 1.2), white, 0.004), "chest")
    for k in range(4):
        P(box(f"embroid_{k}", (0.026, 0.01, 0.026), (0, -0.131, 1.08 + k * 0.08), red_d, 0, (0, math.pi / 4, 0)),
          torso_bone(1.08 + k * 0.08))
    arms(j, red, white, M("skin"))
    for side, sx in (("L", 1), ("R", -1)):  # кольчужные оплечья
        P(sphere(f"mail_sh_{side}", 0.072, j[f"upper_arm.{side}"] + Vector((sx * 0.0, 0, 0.0)), M("chainmail"), 12, 8,
                 (1.05, 1.0, 0.85)), f"shoulder.{side}")
    c = j["head"] + Vector((0, 0, 0.1))
    face(c, M("skin"), M("hair_brown"))
    P(kit.loft("helm", [(c.z + 0.045, 0.106, 0.112), (c.z + 0.1, 0.104, 0.11), (c.z + 0.17, 0.068, 0.072),
                        (c.z + 0.24, 0.02, 0.02), (c.z + 0.27, 0.004, 0.004)], M("steel"), 16), "head")
    P(kit.loft("helm_rim", [(c.z + 0.035, 0.11, 0.116), (c.z + 0.07, 0.11, 0.116)], M("iron"), 16), "head")
    P(box("nasal", (0.014, 0.014, 0.05), c + Vector((0, -0.118, 0.03)), M("iron")), "head")
    P(kit.loft("aventail", [(c.z - 0.22, 0.2, 0.15, 0, 0.0), (c.z - 0.12, 0.14, 0.13, 0, 0.01),
                            (c.z + 0.045, 0.108, 0.114, 0, 0.005)], M("chainmail"), 14, arc=(-25, 205)), "neck")
    P(kit.loft("collar", [(1.38, 0.09, 0.08), (1.43, 0.075, 0.07)], white, 14, cap_top=False, cap_bottom=False), "chest")
    # копьё в правой руке (вертикально), щит на левом предплечье
    hr = j["hand.R"].lerp(j["hand_end.R"], 0.45)
    P(cyl("spear", 0.016, 0.016, 2.2, (hr.x, hr.y - 0.005, 1.08), M("oak_warm"), 8), "hand.R")
    P(cyl("spear_band", 0.021, 0.021, 0.06, (hr.x, hr.y - 0.005, 2.16), M("brass"), 8), "hand.R")
    P(prism("spear_tip", [(0, 0), (0.042, 0.1), (0, 0.3), (-0.042, 0.1)], 0.012, (hr.x, hr.y + 0.001, 2.18),
            M("steel"), (math.pi / 2, 0, 0)), "hand.R")
    yaw = math.radians(22)
    sc = j["forearm.L"].lerp(j["hand.L"], 0.45) + Vector((0.06, -0.08, 0.0))
    nrm = Vector((math.sin(yaw), -math.cos(yaw), 0))
    rot = (math.radians(90), 0, yaw)
    P(cyl("shield", 0.28, 0.28, 0.035, sc, M("oak_warm"), 24, rot), "forearm.L")
    P(cyl("shield_rim", 0.29, 0.29, 0.028, sc, M("iron"), 24, rot), "forearm.L")
    front = sc + nrm * 0.021
    P(cyl("shield_sun", 0.11, 0.11, 0.01, front, M("cloth_dark"), 16, rot), "forearm.L")
    side = Vector((math.cos(yaw), math.sin(yaw), 0))
    for k in range(8):  # изогнутые лучи чёрного солнца
        a = 2 * math.pi * k / 8
        pts = []
        for t in range(4):
            rr = 0.1 + 0.05 * t
            aa = a + 0.18 * t
            pts.append(front + side * (rr * math.cos(aa)) + Vector((0, 0, rr * math.sin(aa))))
        P(tube(f"sun_ray_{k}", pts, 0.02, M("cloth_dark"), 5, 0.3), "forearm.L")
    P(sphere("shield_boss", 0.055, front + nrm * 0.01, M("steel"), 12, 6, (1, 1, 1)), "forearm.L")
    ob = join_all("send_unit")
    rig(ob)
    return ob


UNIT_VIEW = dict(res=(600, 800), elevation=6.0, azimuth=-22.0, ortho=2.5, look_z=1.12)

MODELS = {
    "send_unit": dict(build=spearman, kind="units", concept="units/send_unit_16.png", view=UNIT_VIEW),
}
