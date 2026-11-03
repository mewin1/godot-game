"""Построить модель(и), отрендерить сравнение с концептом и экспортировать GLB.

blender -b --factory-startup -P tools/blender/noir/run.py -- <id> [<id> ...] [--no-export]
"""
import importlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import kit  # noqa: E402

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
        if spec.get("no_render"):
            kit.export(ob, spec["kind"], spec.get("file", model_id))
            continue
        kit.setup_render(**spec.get("view", {}))
        render_path = kit.ROOT / "new_concept" / "compare" / "renders" / f"{model_id}.png"
        kit.render(render_path)
        # сравнение собирает системный python (в Blender нет PIL): compare.py читает эту пометку
        render_path.with_suffix(".txt").write_text(spec["concept"])
        if not no_export and not spec.get("no_export"):
            print("[noir] ->", kit.export(ob, spec["kind"], spec.get("file", model_id)))


main()
