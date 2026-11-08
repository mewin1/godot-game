"""Примеры дневного света для «Обряда»: наш кадр игры → Z-Image Turbo (картинка → картинка) с разными
описаниями света и палитры. Композиция остаётся нашей, меняются свет и цвет — автор выбирает образец.

python3 -I tools/concepts/day_look_gen.py <кадр.png> <папка> [--denoise 0.6] [--seed 7] [--mix]
ComfyUI должен быть запущен на :8188 (см. zimage_gen.py).
"""
import json
import sys
import time
import urllib.request
import uuid
from pathlib import Path

URL = "http://127.0.0.1:8188"
SCENE = ("top-down three-quarter view of a fortified courtyard with a wooden palisade, stone paving and "
         "small wooden towers, a dark wooden terem house in the corner, surrounded by a dense slavic spruce "
         "and birch forest with a meadow clearing, stylized 3D game render, detailed, ")
LOOKS = {
    "1_overcast_emerald": "overcast daytime, soft cool diffuse sky light, deep saturated emerald green spruce "
                          "forest, blue-teal shadows under the trees, light mist between trunks, moody dark "
                          "fairy tale, clearly daytime",
    "2_sunny_green": "bright sunny day, warm sunlight, rich saturated green grass and fir trees, clear air, "
                     "soft shadows, vivid but natural colors",
    "3_misty_morning": "misty morning daylight, pale blue-grey fog, cold blue-green spruce forest, muted "
                       "palette but clearly day, soft light from the sky",
    "4_teal_cinematic": "cloudy cinematic daylight, teal and dark green palette, saturated greens, slightly "
                        "gloomy, dark blue tinted shadows in the forest, bright readable clearing in the center",
    "5_afternoon_sun": "late afternoon sunlight with long soft shadows, golden highlights on the trees, deep "
                       "green forest with blue shade, calm atmosphere",
    "6_cold_noir_day": "cold noir fairy tale daylight, pale blue sky light, deep dark green conifers with a "
                       "bluish tint, slightly desaturated, cold atmosphere, bright readable courtyard",
}
## Смеси по выбору автора (2 + 6): солнце и сочная зелень + холодный синеватый «нуар».
MIX_LOOKS = {
    "7_sunny_noir": "sunny day with a cold noir fairy tale atmosphere, bright sunlight patches on the clearing, "
                    "rich saturated green grass and deep green spruces, deep blue-teal shadows, cool bluish sky "
                    "light, high contrast between sunlit green and blue shade",
    "8_noir_green": "cold noir daylight with lush saturated greens, deep emerald conifers with a bluish tint, "
                    "soft sun from the side, blue shadows, slightly gloomy but clearly a bright day",
    "9_sun_blue_air": "clear bright day, saturated green meadow and forest, cool blue atmospheric haze in the "
                      "distance, dark blue shadows under the trees, crisp but soft light, slavic dark fairy tale",
}


def post(path: str, data: dict) -> dict:
    request = urllib.request.Request(URL + path, json.dumps(data).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(request))


def upload(image: Path) -> str:
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{image.name}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + image.read_bytes() + (
            f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n"
            f"--{boundary}--\r\n").encode()
    request = urllib.request.Request(URL + "/upload/image", body,
                                     {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    return json.load(urllib.request.urlopen(request))["name"]


def workflow(image_name: str, prompt: str, seed: int, denoise: float, prefix: str) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b_fp8_mixed.safetensors", "type": "lumina2"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "4": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3.0}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "6": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["5", 0]}},
        "7": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "8": {"class_type": "VAEEncode", "inputs": {"pixels": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0],
              "latent_image": ["8", 0], "seed": seed, "steps": 8, "cfg": 1.0,
              "sampler_name": "res_multistep", "scheduler": "simple", "denoise": denoise}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["9", 0], "vae": ["3", 0]}},
        "11": {"class_type": "SaveImage", "inputs": {"images": ["10", 0], "filename_prefix": prefix}},
    }


def main() -> None:
    args = sys.argv[1:]
    denoise, seed = 0.6, 7
    if "--denoise" in args:
        denoise = float(args[args.index("--denoise") + 1])
        del args[args.index("--denoise"):args.index("--denoise") + 2]
    if "--seed" in args:
        seed = int(args[args.index("--seed") + 1])
        del args[args.index("--seed"):args.index("--seed") + 2]
    looks = LOOKS
    if "--mix" in args:
        looks = MIX_LOOKS
        args.remove("--mix")
    frame, out_dir = Path(args[0]), Path(args[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    name = upload(frame)
    for look, words in looks.items():
        started = time.time()
        prompt_id = post("/prompt", {"prompt": workflow(name, SCENE + words, seed, denoise, f"day_look/{look}")})["prompt_id"]
        while True:
            history = json.load(urllib.request.urlopen(f"{URL}/history/{prompt_id}"))
            if prompt_id in history:
                break
            time.sleep(1)
        entry = history[prompt_id]
        if entry["status"].get("status_str") != "success":
            print(f"{look}: ОШИБКА", json.dumps(entry["status"])[:600])
            continue
        image = entry["outputs"]["11"]["images"][0]
        query = f"filename={image['filename']}&subfolder={image['subfolder']}&type=output"
        target = out_dir / f"{look}.png"
        target.write_bytes(urllib.request.urlopen(f"{URL}/view?{query}").read())
        print(f"{look}: {target} ({time.time() - started:.0f} с)")


if __name__ == "__main__":
    main()
