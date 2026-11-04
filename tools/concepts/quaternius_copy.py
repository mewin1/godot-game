"""Камни арены из Quaternius Stylized Nature MegaKit (CC0, source_art/quaternius/nature_megakit).

python3 -I tools/concepts/quaternius_copy.py
Копирует выбранные модели как есть (glTF + общие фактуры) в assets/quaternius/nature/; NoirArena3D
приглушает их под ночь. Деревья и трава набора не подошли по стилю (слишком мультяшные) — лес теперь
рисованный: tools/concepts/billboard_gen.py.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "source_art" / "quaternius" / "nature_megakit" / "extracted" / "glTF"
OUT = ROOT / "assets" / "quaternius" / "nature"
COPY = ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    images: set[str] = set()
    for mid in COPY:
        data = json.loads((SRC / f"{mid}.gltf").read_text())
        for buf in data.get("buffers", []):
            shutil.copy(SRC / buf["uri"], OUT / buf["uri"])
        images.update(img["uri"] for img in data.get("images", []))
        shutil.copy(SRC / f"{mid}.gltf", OUT / f"{mid}.gltf")
    for uri in images:
        shutil.copy(SRC / uri, OUT / uri)
    print(f"[q] скопировано {len(COPY)} моделей, {len(images)} фактур -> {OUT}")


main()
