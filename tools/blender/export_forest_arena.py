"""Run with the arena scene active in Blender; export geometry and save source."""
import bpy
from pathlib import Path

root = Path('/home/d0nco/godot_game')
scene = bpy.context.scene
if not scene.name.startswith('Zastava_Forest_Arena'):
    raise RuntimeError('Select the Zastava_Forest_Arena scene before exporting')
bpy.ops.object.select_all(action='DESELECT')
for obj in scene.objects:
    if obj.type == 'MESH':
        obj.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=str(root / 'assets/arenas/forest/forest_arena.glb'),
    use_selection=True,
    use_active_scene=True,
    export_cameras=False,
    export_lights=False,
    # The ground texture lives next to the GLB; Godot maps the material to terrain_ground.tres.
    export_image_format='NONE',
    # Only the paint layer, as COLOR_0 (with images off the exporter can't see which one).
    export_vertex_color='ACTIVE',
)
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(root / 'source_art/arenas/forest_arena.blend'))
