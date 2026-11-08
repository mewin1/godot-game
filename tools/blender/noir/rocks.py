"""Камни опушки: покрашенные сетки Hunyuan3D → облегчённые GLB для MultiMesh в Godot.

Запуск: blender -b --factory-startup -P tools/blender/noir/rocks.py -- <id> [<id> ...]
Вход: source_art/noir_h3d/raw/<id>_paint.glb (tools/concepts/rock_gen.py → h3d_gen.py → h3d_paint.py).
Выход: assets/noir/rocks/<id>.glb — основание на z = 0 (чуть утоплено), размер в метрах по SIZES.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "source_art" / "noir_h3d" / "raw"
OUT = ROOT / "assets" / "noir" / "rocks"
# наибольший размер (м): по горизонтали, у менгира — высота
SIZES = {"rock_boulder": 1.7, "rock_slab": 2.3, "rock_menhir": 2.6, "rock_cluster": 2.1, "rock_split": 1.9,
         "rock_flat": 1.1}
FACES = 3500
SINK = 0.06  # доля высоты под землёй — камень не «стоит на цыпочках»
# Hunyuan лепит тень с концепта плоским диском у основания — срезаем всё ниже этой высоты (м)
CUT = 0.07


def noir_stone(img: bpy.types.Image) -> None:
    """Под «нуар» двора: концепт светлый и сочный (дневной ассет) — темнее, мох глуше, холоднее."""
    import numpy as np

    px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    rgb = px[:, :3]
    luma = (rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32))[:, None]
    green = np.clip((rgb[:, 1:2] - np.maximum(rgb[:, 0:1], rgb[:, 2:3])) * 4.0, 0.0, 1.0)  # мох
    sat = 0.8 - 0.22 * green
    rgb = luma + (rgb - luma) * sat
    rgb *= (0.7 - 0.06 * green) * np.array([0.94, 1.0, 1.06], dtype=np.float32)
    px[:, :3] = np.clip(rgb, 0.0, 1.0)
    img.pixels.foreach_set(px.ravel())
    img.update()


def build(rid: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(RAW / f"{rid}_paint.glb"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    size = (hi - lo)
    span = size.z if rid == "rock_menhir" else max(size.x, size.y)
    s = SIZES[rid] / span
    obj.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2,
                                                                         -lo.z - SINK * size.z))))
    obj.data.update()
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < CUT], context="VERTS")
    for v in bm.verts:
        v.co.z -= CUT + 0.02
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.ratio = min(1.0, FACES / max(1, len(obj.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    obj.name = obj.data.name = rid
    for mat in obj.data.materials:
        mat.name = f"{rid}_stone"
        mat.blend_method = "OPAQUE"
        mat.use_backface_culling = False
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None:
                node.image.name = f"{rid}_stone"
                if node.image.size[0] > 1024:
                    node.image.scale(1024, 1024)
                noir_stone(node.image)
            if node.type == "BSDF_PRINCIPLED":
                for link in list(node.inputs["Alpha"].links):
                    mat.node_tree.links.remove(link)
                node.inputs["Alpha"].default_value = 1.0
                node.inputs["Roughness"].default_value = 0.9
                node.inputs["Metallic"].default_value = 0.0
                node.inputs["Specular IOR Level"].default_value = 0.2
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    out = OUT / f"{rid}.glb"
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", use_selection=True,
                              export_image_format="JPEG", export_jpeg_quality=88)
    print(f"[rock] {rid}: {out.relative_to(ROOT)} {out.stat().st_size // 1024} КБ, "
          f"{len(obj.data.polygons)} гр., {tuple(round(v * s, 2) for v in size)} м")


if __name__ == "__main__":
    for rid in sys.argv[sys.argv.index("--") + 1:]:
        build(rid)
