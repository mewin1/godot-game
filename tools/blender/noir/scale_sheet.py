"""Лист масштабов: готовые GLB рядом на сетке клеток 2 м + отметки роста.

blender -b --factory-startup -P tools/blender/noir/scale_sheet.py
Результат: new_concept/compare/scale_sheet.png (сжатый jpg собирает compare.py --sheet).
"""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit  # noqa: E402

ROW = [  # файл, плита (уровень, школа) или None, подпись
    ("plates/plate_1_neutral.glb", None, "плита I"),
    ("plates/plate_2_neutral.glb", None, "плита II"),
    ("plates/plate_3_neutral.glb", None, "плита III"),
    ("towers/thunder.glb", (2, "perun"), "Грозовой столб II"),
    ("idols/idol.glb", (1, "neutral"), "идол"),
    ("base/terem.glb", (1, "neutral"), "терем"),
    ("units/send_unit.glb", None, "копейщик 1,7 м"),
]


def main():
    kit.reset()
    x = 0.0
    for path, plate, _label in ROW:
        objs_before = set(bpy.context.scene.objects)
        if plate is not None:
            bpy.ops.import_scene.gltf(filepath=str(kit.ROOT / "assets/noir/plates" / f"plate_{plate[0]}_{plate[1]}.glb"))
        bpy.ops.import_scene.gltf(filepath=str(kit.ROOT / "assets/noir" / path))
        for o in set(bpy.context.scene.objects) - objs_before:
            if o.parent is None:
                o.location.x += x
        x += 2.4
    # линейки высоты: 2 / 2,8 / 3,6 м (уровни I–III) и 1,7 м (человек)
    for h, name in ((2.0, "I"), (2.8, "II"), (3.6, "III"), (1.7, "human")):
        kit.box(f"ruler_{name}", (x + 0.4, 0.01, 0.012), (x / 2 - 1.2, 1.2, h), kit.M("glow_neutral"))
    kit.setup_render(res=(1800, 700), elevation=10.0, azimuth=0.0, ortho=x * 0.95, look_z=1.8)
    bpy.context.scene.camera.location.x += x / 2 - 1.2
    kit.render(kit.ROOT / "new_concept/compare/renders/scale_sheet.png")


main()
