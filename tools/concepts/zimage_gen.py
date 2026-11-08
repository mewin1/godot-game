"""Концепты через Z-Image Turbo в локальном ComfyUI (должен быть запущен на :8188).

Запуск: python3 -I tools/concepts/zimage_gen.py output/concepts <имя> <W> <H> <сид>... < prompt.txt
"""
import json
import sys
import time
import urllib.request
from pathlib import Path

URL = "http://127.0.0.1:8188"


def post(path: str, data: dict) -> dict:
    request = urllib.request.Request(URL + path, json.dumps(data).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(request))


def workflow(prompt: str, width: int, height: int, seed: int, prefix: str) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b_fp8_mixed.safetensors", "type": "lumina2"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "4": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3.0}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "6": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["5", 0]}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0],
              "latent_image": ["7", 0], "seed": seed, "steps": 8, "cfg": 1.0,
              "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
    }


def main() -> None:
    out_dir, name, width, height = Path(sys.argv[1]), sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    seeds = [int(s) for s in sys.argv[5:]]
    prompt = sys.stdin.read().strip()
    out_dir.mkdir(parents=True, exist_ok=True)
    for seed in seeds:
        started = time.time()
        prompt_id = post("/prompt", {"prompt": workflow(prompt, width, height, seed, f"concepts/{name}")})["prompt_id"]
        while True:
            history = json.load(urllib.request.urlopen(f"{URL}/history/{prompt_id}"))
            if prompt_id in history:
                break
            time.sleep(1)
        entry = history[prompt_id]
        if entry["status"].get("status_str") != "success":
            print(f"seed {seed}: ОШИБКА", json.dumps(entry["status"])[:600])
            continue
        image = entry["outputs"]["10"]["images"][0]
        query = f"filename={image['filename']}&subfolder={image['subfolder']}&type=output"
        target = out_dir / f"{name}_{seed}.png"
        target.write_bytes(urllib.request.urlopen(f"{URL}/view?{query}").read())
        print(f"seed {seed}: {target} ({time.time() - started:.0f} с)")


if __name__ == "__main__":
    main()
