"""Покраска сетки Hunyuan3D её же текстурной нейросетью (Hunyuan3D-2 paint) — со всех сторон, без растяжек.

Запуск: python3 -I tools/concepts/h3d_paint.py <группа> <id> [<id>...] [--seed N] [--steps 30] [--delight]
        [--view 512] [--tex 2048] [--turbo]
Вход: сетка source_art/noir_h3d/raw/<id>.glb (tools/concepts/h3d_gen.py) и концепт new_concept/<группа>/<id>_16.png.
Выход: source_art/noir_h3d/raw/<id>_paint.glb (сетка с UV и текстурой) и <id>_paint_ref.png (что ушло в сеть).
Нужен собранный custom_rasterizer в venv ComfyUI (nvcc из pip; сборка — output/h3d_paint_build.sh)
и перезапущенный ComfyUI. Дальше модель ставится в Blender: tools/blender/noir/h3d.sh <id> --paint.
"""
import json
import shutil
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import h3d_gen  # noqa: E402

OUT = h3d_gen.OUT
COMFY = h3d_gen.COMFY
# серый фон: с белым нейросеть снятия света пересвечивает, с чёрным — краснит (совет автора узлов)
REF_BG = (204, 204, 204)


def workflow(mesh: Path, image: str, mid: str, seed: int, steps: int, delight: bool, view: int, tex: int,
             turbo: bool) -> dict:
    model = "hunyuan3d-paint-v2-0-turbo" if turbo else "hunyuan3d-paint-v2-0"
    g = {
        "1": {"class_type": "Hy3DLoadMesh", "inputs": {"glb_path": str(mesh)}},
        "2": {"class_type": "LoadImage", "inputs": {"image": image}},
        "3": {"class_type": "Hy3DMeshUVWrap", "inputs": {"trimesh": ["1", 0]}},
        "4": {"class_type": "Hy3DCameraConfig", "inputs": {
            "camera_azimuths": "0, 90, 180, 270, 0, 180", "camera_elevations": "0, 0, 0, 0, 90, -90",
            "view_weights": "1, 0.1, 0.5, 0.1, 0.05, 0.05", "camera_distance": 1.45, "ortho_scale": 1.2}},
        "5": {"class_type": "Hy3DRenderMultiView", "inputs": {"trimesh": ["3", 0], "render_size": 1024,
              "texture_size": tex, "camera_config": ["4", 0], "normal_space": "world"}},
        "6": {"class_type": "DownloadAndLoadHy3DPaintModel", "inputs": {"model": model}},
        "7": {"class_type": "Hy3DDiffusersSchedulerConfig", "inputs": {"pipeline": ["6", 0],
              "scheduler": "Euler A", "sigmas": "default"}},
    }
    ref = ["2", 0]
    if delight:
        g["8"] = {"class_type": "DownloadAndLoadHy3DDelightModel", "inputs": {"model": "hunyuan3d-delight-v2-0"}}
        g["9"] = {"class_type": "Hy3DDiffusersSchedulerConfig", "inputs": {"pipeline": ["8", 0],
                  "scheduler": "Euler A", "sigmas": "default"}}
        g["10"] = {"class_type": "Hy3DDelightImage", "inputs": {"delight_pipe": ["8", 0], "image": ["2", 0],
                   "steps": 50, "width": 512, "height": 512, "cfg_image": 1.0, "seed": seed,
                   "scheduler": ["9", 0]}}
        ref = ["10", 0]
    g.update({
        "11": {"class_type": "Hy3DSampleMultiView", "inputs": {"pipeline": ["6", 0], "ref_image": ref,
               "normal_maps": ["5", 0], "position_maps": ["5", 1], "view_size": view, "steps": steps,
               "seed": seed, "camera_config": ["4", 0], "scheduler": ["7", 0], "denoise_strength": 1.0}},
        "12": {"class_type": "ImageScale", "inputs": {"image": ["11", 0], "upscale_method": "lanczos",
               "width": tex, "height": tex, "crop": "disabled"}},
        "13": {"class_type": "Hy3DBakeFromMultiview", "inputs": {"images": ["12", 0], "renderer": ["5", 2],
               "camera_config": ["4", 0]}},
        "14": {"class_type": "Hy3DMeshVerticeInpaintTexture", "inputs": {"texture": ["13", 0], "mask": ["13", 1],
               "renderer": ["13", 2]}},
        "15": {"class_type": "CV2InpaintTexture", "inputs": {"texture": ["14", 0], "mask": ["14", 1],
               "inpaint_radius": 3, "inpaint_method": "ns"}},
        "16": {"class_type": "Hy3DApplyTexture", "inputs": {"texture": ["15", 0], "renderer": ["14", 2]}},
        "17": {"class_type": "Hy3DExportMesh", "inputs": {"trimesh": ["16", 0],
               "filename_prefix": f"noir_h3d_paint/{mid}", "file_format": "glb", "save_file": True}},
        "18": {"class_type": "SaveImage", "inputs": {"images": ["11", 0], "filename_prefix": f"noir_h3d_paint/{mid}_views"}},
        "19": {"class_type": "SaveImage", "inputs": {"images": [ref[0], ref[1]],
               "filename_prefix": f"noir_h3d_paint/{mid}_ref"}},
    })
    return g


def run(group: str, mid: str, seed: int, steps: int, delight: bool, view: int, tex: int, turbo: bool) -> Path | None:
    mesh = OUT / f"{mid}.glb"
    if not mesh.exists():
        print(f"[paint] {mid}: нет сетки {mesh} — сначала h3d_gen.py", flush=True)
        return None
    # prepare() пишет <id>_in.png — это вход сетки (в Git), его сохраняем как был
    mesh_in = OUT / f"{mid}_in.png"
    keep = mesh_in.read_bytes() if mesh_in.exists() else None
    h3d_gen.BG_BY_ID.setdefault(mid, REF_BG)
    inp = h3d_gen.prepare(group, mid, size=512)
    ref = OUT / f"{mid}_paint_in.png"
    shutil.copy(inp, ref)
    if keep is not None:
        mesh_in.write_bytes(keep)
    name = h3d_gen.upload(ref)
    t0 = time.time()
    pid = h3d_gen.post("/prompt", {"prompt": workflow(mesh, name, mid, seed, steps, delight, view, tex, turbo)})[
        "prompt_id"]
    while True:
        time.sleep(3)
        hist = json.load(urllib.request.urlopen(f"{h3d_gen.URL}/history/{pid}"))
        if pid in hist:
            break
    status = hist[pid].get("status", {})
    if status.get("status_str") != "success":
        msgs = [m for m in status.get("messages", []) if m[0] == "execution_error"]
        err = msgs[0][1].get("exception_message", "")[:300] if msgs else str(status)[:300]
        print(f"[paint] {mid}: ошибка {err}", flush=True)
        return None
    folder = COMFY / "output" / "noir_h3d_paint"
    files = sorted(folder.glob(f"{mid}_0*.glb"), key=lambda p: p.stat().st_mtime)
    out = OUT / f"{mid}_paint.glb"
    shutil.copy(files[-1], out)
    views = sorted(folder.glob(f"{mid}_views_*.png"), key=lambda p: p.stat().st_mtime)
    if views:
        shutil.copy(views[-1], OUT / f"{mid}_paint_views.png")
    print(f"[paint] {mid}: {out.relative_to(h3d_gen.ROOT)} {out.stat().st_size // 1024} КБ за {time.time() - t0:.0f} с",
          flush=True)
    return out


def main() -> None:
    args = sys.argv[1:]

    def opt(name: str, default: str) -> str:
        if name in args:
            i = args.index(name)
            value = args[i + 1]
            del args[i : i + 2]
            return value
        return default

    seed = int(opt("--seed", "16"))
    steps = int(opt("--steps", "30"))
    view = int(opt("--view", "512"))
    tex = int(opt("--tex", "2048"))
    # снятие света по умолчанию выключено: на тёмных концептах «нуара» оно выдумывает цвета (жёлтые рукава, белые пятна)
    delight = "--delight" in args
    turbo = "--turbo" in args
    args = [a for a in args if a not in ("--delight", "--turbo")]
    group, ids = args[0], args[1:]
    failed = [mid for mid in ids if run(group, mid, seed, steps, delight, view, tex, turbo) is None]
    if failed:
        raise SystemExit(f"не вышло: {' '.join(failed)}")


if __name__ == "__main__":
    main()
