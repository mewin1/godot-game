"""Построить модель(и), отрендерить сравнение с концептом и экспортировать GLB.

blender -b --factory-startup -P tools/blender/noir/run.py -- <id> [<id> ...] [--no-export]
"""
import importlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import kit  # noqa: E402
import paint  # noqa: E402
import bpy  # noqa: E402
import project  # noqa: E402

MODULES = ["buildings", "idols", "units"]


def registry() -> dict:
    reg = {}
    for name in MODULES:
        try:
            mod = importlib.import_module(name)
        except ModuleNotFoundError:
            continue
        reg.update(mod.MODELS)
    return reg


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    no_export = "--no-export" in argv
    ids = [a for a in argv if not a.startswith("--")]
    reg = registry()
    for model_id in ids:
        spec = reg[model_id]
        kit.reset()
        ob = spec["build"]()
        print(f"[noir] {model_id}: {kit.tri_count(ob)} треугольников, габарит {tuple(round(v, 2) for v in ob.dimensions)}")
        if not spec.get("flat"):
            size = spec.get("tex", 2048)
            for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
                keep = None if spec["kind"] == "plates" else kit.ROOT / "source_art" / "noir" / spec["kind"] / f"{o.name}_paint.png"
                paint.bake(o, size, keep)
        if spec.get("no_render"):
            kit.export(ob, spec["kind"], spec.get("file", model_id))
            continue
        kit.setup_render(**spec.get("view", {}))
        if spec.get("project", True) and not spec.get("flat"):
            concept = kit.ROOT / "new_concept" / spec["concept"]
            bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y = project.W, project.H
            cmask = project.concept_mask(concept)
            tmp = kit.ROOT / "new_concept" / "compare" / "renders" / f"{model_id}__mask.png"
            mmask = project.fit_camera(cmask, tmp)
            iou = project.silhouette_report(cmask, mmask, kit.ROOT / "new_concept" / "compare" / "renders" /
                                            f"{model_id}_sil.png")
            print(f"[noir] {model_id}: силуэт IoU {iou:.3f}")
            tmp.unlink(missing_ok=True)
            if not spec.get("silhouette_only"):
                meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
                project.project_bake(meshes, concept, cmask, spec.get("mirror_back", False), spec.get("tex", 2048))
        render_path = kit.ROOT / "new_concept" / "compare" / "renders" / f"{model_id}.png"
        kit.render(render_path)
        # сравнение собирает системный python (в Blender нет PIL): compare.py читает эту пометку
        render_path.with_suffix(".txt").write_text(spec["concept"])
        if not no_export and not spec.get("no_export"):
            print("[noir] ->", kit.export(ob, spec["kind"], spec.get("file", model_id)))
            plate_ob = bpy.data.objects.get(f"{ob.name}_plate")
            if plate_ob is not None and spec["kind"] == "towers":
                print("[noir] ->", kit.export(plate_ob, spec["kind"], f"{spec.get('file', model_id)}_plate"))


main()
