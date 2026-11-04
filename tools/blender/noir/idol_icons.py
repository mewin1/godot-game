"""Значки идолов для интерфейса из моделей Hunyuan3D: assets/noir_h3d/icons/idol_<бог>.png (256², прозрачный фон).

blender -b --factory-startup -P tools/blender/noir/idol_icons.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402

import kit  # noqa: E402

GODS = {"idol_empty": "", "idol_perun": "perun", "idol_svarog": "svarog", "idol_stribog": "stribog",
        "idol_curse": "curse", "idol_ice": "ice", "idol_war": "war", "idol_water": "water"}
OUT = kit.ROOT / "assets" / "noir_h3d" / "icons"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for mid, god in GODS.items():
        src = kit.ROOT / "assets" / "noir_h3d" / "idols" / f"{mid}.glb"
        if not src.exists():
            continue
        kit.reset()
        bpy.ops.import_scene.gltf(filepath=str(src))
        kit.setup_render(res=(256, 256), elevation=10.0, azimuth=-40.0, ortho=2.1, look_z=2.35)
        sc = bpy.context.scene
        sc.render.film_transparent = True
        name = f"idol_{god or 'empty'}.png"
        kit.render(OUT / name)
        print("[icon]", name)


main()
