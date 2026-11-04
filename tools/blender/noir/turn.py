"""Облёт готовой модели: 4 ракурса (спереди-слева, справа, сзади, слева) в одну полосу — видно бока и спину.

blender -b --factory-startup -P tools/blender/noir/turn.py -- <out.png> <a.glb> [<b.glb> ...] [--cpu]
Несколько GLB — по строке на каждый (сравнение «было | стало»). Свет — как в kit.setup_render (нуар).
"""
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy  # noqa: E402
import numpy as np  # noqa: E402

import kit  # noqa: E402

AZ = (-40.0, 50.0, 140.0, 230.0)
CPU = "--cpu" in sys.argv
W, H = 420, 520


def frame(glb: Path, az: float, out: Path) -> None:
    kit.reset()
    bpy.ops.import_scene.gltf(filepath=str(glb))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = np.array([1e9] * 3)
    hi = -lo
    bpy.context.view_layer.update()
    for o in meshes:
        for c in o.bound_box:
            p = np.array(o.matrix_world @ __import__("mathutils").Vector(c))
            lo, hi = np.minimum(lo, p), np.maximum(hi, p)
    size = float(max(hi - lo))
    kit.setup_render(res=(W, H), elevation=28.0, azimuth=az, ortho=size * 1.25, look_z=float(lo[2] + hi[2]) / 2)
    if CPU:  # EEVEE иногда падает в драйвере на текстурированных моделях — запасной рендер процессором
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = 24
        sc.cycles.use_denoising = True
    kit.render(out)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:]
    out, glbs = Path(argv[0]), [Path(a) for a in argv[1:] if a != "--cpu"]
    tmp = out.parent / "_turn"
    tmp.mkdir(parents=True, exist_ok=True)
    rows = []
    for gi, glb in enumerate(glbs):
        row = []
        for ai, az in enumerate(AZ):
            f = tmp / f"{gi}_{ai}.png"
            frame(glb, az, f)
            img = bpy.data.images.load(str(f), check_existing=False)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
            row.append(px)
            bpy.data.images.remove(img)
        rows.append(np.concatenate(row, axis=1))
    sheet = np.concatenate(rows[::-1], axis=0)  # пиксели Blender снизу вверх: первая модель — верхняя строка
    im = bpy.data.images.new("turn", sheet.shape[1], sheet.shape[0])
    im.pixels[:] = sheet.ravel()
    im.filepath_raw = str(out)
    im.file_format = "PNG"
    im.save()
    print("[turn] ->", out)


main()
