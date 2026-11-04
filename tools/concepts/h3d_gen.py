"""Форма модели по концепту нейросетью Hunyuan3D-2 (узлы ComfyUI-Hunyuan3DWrapper в локальном ComfyUI :8188).

Запуск: python3 -I tools/concepts/h3d_gen.py <группа> <id> [<id>...] [--seed N] [--octree 384] [--faces 80000]
Концепт new_concept/<группа>/<id>_16.png → объект без фона на белом квадрате (как учили Hunyuan) →
сетка без текстуры source_art/noir_h3d/raw/<id>.glb (+ <id>_in.png — что ушло в сеть).
Покраска — в Blender проекцией концепта (tools/blender/noir/h3d.py): текстурной части Hunyuan на Linux
нужен собранный CUDA-растеризатор, а nvcc нет.
"""
import json
import shutil
import sys
import time
import urllib.request
import uuid
from pathlib import Path

import numpy as np
from PIL import Image

URL = "http://127.0.0.1:8188"
ROOT = Path(__file__).resolve().parents[2]
COMFY = Path.home() / "ComfyUI"
OUT = ROOT / "source_art" / "noir_h3d" / "raw"


def concept_mask(px: np.ndarray, thr: float = 0.012) -> np.ndarray:
    """Как project.concept_mask: фон — связная от краёв область плавного градиента."""
    small = px[::2, ::2]
    g = np.zeros(small.shape[:2], dtype=np.float32)
    g[:, 1:] = np.maximum(g[:, 1:], np.abs(small[:, 1:] - small[:, :-1]).max(axis=2))
    g[1:, :] = np.maximum(g[1:, :], np.abs(small[1:] - small[:-1]).max(axis=2))
    smooth = g < thr
    bg = np.zeros_like(smooth)
    bg[0, :] = bg[-1, :] = bg[:, 0] = bg[:, -1] = True
    bg &= smooth
    while True:
        grown = bg.copy()
        grown[1:] |= bg[:-1]
        grown[:-1] |= bg[1:]
        grown[:, 1:] |= bg[:, :-1]
        grown[:, :-1] |= bg[:, 1:]
        grown &= smooth
        if (grown == bg).all():
            break
        bg = grown
    # замкнутые «окна» фона (между копьём и телом и т. п.): плавные места цвета фона своей строки
    edge = np.concatenate([small[:, :6], small[:, -6:]], axis=1).mean(axis=1, keepdims=True)
    close = np.abs(small - edge).max(axis=2) < 0.035
    cand = smooth & close & ~bg
    seen = np.zeros_like(cand)
    for y0, x0 in zip(*np.nonzero(cand)):
        if seen[y0, x0]:
            continue
        comp, stack = [], [(y0, x0)]
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < cand.shape[0] and 0 <= nx < cand.shape[1] and cand[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(comp) >= 150:  # мелкие тёмные пятна рисунка — не фон
            ys, xs = zip(*comp)
            bg[list(ys), list(xs)] = True
    obj = ~bg

    def shift_all(m, op):
        r = m.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            r = op(r, np.roll(np.roll(m, dy, axis=0), dx, axis=1))
        return r

    for _ in range(3):
        obj = shift_all(obj, np.logical_and)
    for _ in range(3):
        obj = shift_all(obj, np.logical_or)
    # дыры внутри силуэта (тёмные места рисунка) — тоже объект: заливаем всё, что не достижимо от краёв
    big = np.repeat(np.repeat(obj, 2, axis=0), 2, axis=1)
    return big[: px.shape[0], : px.shape[1]]


# только самая крупная часть силуэта (летающие огоньки вокруг духа сеть превращает в бесформенные куски)
MAIN_ONLY = {"spirit"}
# светлый полупрозрачный объект на белом теряет края — серый фон
BG_BY_ID = {"spirit": (70, 78, 84)}


def largest_part(mask: np.ndarray) -> np.ndarray:
    small = mask[::2, ::2]
    label = np.zeros(small.shape, dtype=np.int32)
    best, best_n, cur = 0, 0, 0
    for y0, x0 in zip(*np.nonzero(small)):
        if label[y0, x0]:
            continue
        cur += 1
        stack, n = [(y0, x0)], 0
        label[y0, x0] = cur
        while stack:
            y, x = stack.pop()
            n += 1
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < small.shape[0] and 0 <= nx < small.shape[1] and small[ny, nx] and not label[ny, nx]:
                    label[ny, nx] = cur
                    stack.append((ny, nx))
        if n > best_n:
            best, best_n = cur, n
    keep = np.repeat(np.repeat(label == best, 2, axis=0), 2, axis=1)[: mask.shape[0], : mask.shape[1]]
    return mask & keep


# концепты не из пачки 16 (автор выбрал другой вариант)
SOURCES = {"terem": "buildings/terem_5.png"}


def source(group: str, mid: str) -> Path:
    if mid in SOURCES:
        return ROOT / "new_concept" / SOURCES[mid]
    return ROOT / "new_concept" / group / f"{mid}_16.png"


def prepare(group: str, mid: str, size: int = 518, border: float = 0.12) -> Path:
    src = source(group, mid)
    img = Image.open(src).convert("RGB")
    px = np.asarray(img, dtype=np.float32) / 255.0
    mask = concept_mask(px)
    if mid in MAIN_ONLY:
        mask = largest_part(mask)
    rows = np.nonzero(mask.sum(axis=1) > 3)[0]
    cols = np.nonzero(mask.sum(axis=0) > 3)[0]
    y0, y1, x0, x1 = rows.min(), rows.max() + 1, cols.min(), cols.max() + 1
    alpha = Image.fromarray((mask * 255).astype(np.uint8)).crop((x0, y0, x1, y1))
    crop = img.crop((x0, y0, x1, y1))
    # мягкий край маски, чтобы не тащить в сеть ореол фона
    side = max(x1 - x0, y1 - y0)
    full = int(side / (1 - 2 * border))
    canvas = Image.new("RGB", (full, full), BG_BY_ID.get(mid, (255, 255, 255)))
    ox, oy = (full - (x1 - x0)) // 2, (full - (y1 - y0)) // 2
    canvas.paste(crop, (ox, oy), alpha)
    canvas = canvas.resize((size, size), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{mid}_in.png"
    canvas.save(out)
    return out


def post(path: str, data: dict) -> dict:
    req = urllib.request.Request(URL + path, json.dumps(data).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))


def upload(path: Path) -> str:
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{path.name}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + path.read_bytes() + (
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{boundary}--\r\n").encode()
    req = urllib.request.Request(URL + "/upload/image", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    return json.load(urllib.request.urlopen(req))["name"]


def workflow(image: str, mid: str, seed: int, octree: int, faces: int, steps: int, guidance: float) -> dict:
    return {
        "1": {"class_type": "Hy3DModelLoader", "inputs": {"model": "hunyuan3d-dit-v2-0-fp16.safetensors",
                                                           "attention_mode": "sdpa", "cublas_ops": False}},
        "2": {"class_type": "LoadImage", "inputs": {"image": image}},
        "3": {"class_type": "Hy3DGenerateMesh", "inputs": {"pipeline": ["1", 0], "image": ["2", 0],
              "guidance_scale": guidance, "steps": steps, "seed": seed, "force_offload": True}},
        "4": {"class_type": "Hy3DVAEDecode", "inputs": {"vae": ["1", 1], "latents": ["3", 0], "box_v": 1.01,
              "octree_resolution": octree, "num_chunks": 32000, "mc_level": 0.0, "mc_algo": "mc",
              "enable_flash_vdm": True, "force_offload": True}},
        "5": {"class_type": "Hy3DPostprocessMesh", "inputs": {"trimesh": ["4", 0], "remove_floaters": True,
              "remove_degenerate_faces": True, "reduce_faces": True, "max_facenum": faces, "smooth_normals": False}},
        "6": {"class_type": "Hy3DExportMesh", "inputs": {"trimesh": ["5", 0], "filename_prefix": f"noir_h3d/{mid}",
              "file_format": "glb", "save_file": True}},
    }


def run(group: str, mid: str, seed: int, octree: int, faces: int, steps: int, guidance: float) -> Path:
    inp = prepare(group, mid)
    name = upload(inp)
    t0 = time.time()
    pid = post("/prompt", {"prompt": workflow(name, mid, seed, octree, faces, steps, guidance)})["prompt_id"]
    while True:
        time.sleep(2)
        hist = json.load(urllib.request.urlopen(f"{URL}/history/{pid}"))
        if pid in hist:
            break
    entry = hist[pid]
    status = entry.get("status", {})
    if status.get("status_str") != "success":
        msgs = [m for m in status.get("messages", []) if m[0] == "execution_error"]
        err = msgs[0][1].get("exception_message", "")[:200] if msgs else str(status)[:200]
        print(f"[h3d] {mid}: ошибка {err}", flush=True)
        return None
    files = sorted((COMFY / "output" / "noir_h3d").glob(f"{mid}_*.glb"), key=lambda p: p.stat().st_mtime)
    out = OUT / f"{mid}.glb"
    shutil.copy(files[-1], out)
    print(flush=True)
    print(f"[h3d] {mid}: {out.relative_to(ROOT)} {out.stat().st_size // 1024} КБ за {time.time() - t0:.0f} с")
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
    octree = int(opt("--octree", "384"))
    faces = int(opt("--faces", "80000"))
    steps = int(opt("--steps", "50"))
    guidance = float(opt("--guidance", "5.5"))
    only_prep = "--prep" in args
    args = [a for a in args if a != "--prep"]
    group, ids = args[0], args[1:]
    for mid in ids:
        if only_prep:
            print(prepare(group, mid))
        else:
            if run(group, mid, seed, octree, faces, steps, guidance) is None and len(ids) == 1:
                raise SystemExit(1)


if __name__ == "__main__":
    main()
