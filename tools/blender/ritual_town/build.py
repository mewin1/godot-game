"""blender -b --factory-startup -P tools/blender/ritual_town/build.py [-- svarog ...]"""
import sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from houses import body, roof
from devices import FAMILIES, device

ROOT=HERE.parents[2]
OUT=ROOT/"assets/ritual/town"
SRC=ROOT/"source_art/ritual_town"
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
atlas=bpy.data.materials.new("Town finishes")
atlas.use_nodes=True
tex=atlas.node_tree.nodes.new("ShaderNodeTexImage")
tex.image=bpy.data.images.load(str(OUT/"finishes.jpg"))
atlas.node_tree.links.new(tex.outputs["Color"],atlas.node_tree.nodes["Principled BSDF"].inputs["Base Color"])


def write(name, objects, position):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        if ob.type=="MESH":
            # Use more of the 2 m plot without exceeding the common curb.
            for vert in ob.data.vertices:
                vert.co.x *= 1.075
                vert.co.y *= 1.075
            ob.data.materials.append(atlas)
        ob.location.x *= 1.075
        ob.location.y *= 1.075
        ob.select_set(True)
    # Only geometry goes into the shipped GLBs. Godot binds the shared atlas once.
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")), use_selection=True,
                              export_materials="NONE",export_normals=True,export_texcoords=True,
                              export_animations=False,export_cameras=False,export_lights=False,
                              export_yup=True,export_extras=False)
    group=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(group)
    for ob in objects:
        for coll in list(ob.users_collection):
            coll.objects.unlink(ob)
        group.objects.link(ob)
        ob.location+=Vector(position)
        ob.name=name+"_"+ob.name


def marker(name,point):
    ob=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(ob)
    ob.location=point
    return ob


schools = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(FAMILIES)
for tier in range(1,4):
    parts=[body(tier,l).object("Level%d"%l) for l in range(1,5)]
    parts.append(roof(tier,"svarog").object("Roof"))
    write("house_%d"%tier,parts,(-3,tier*3,0))
    for index,ob in enumerate(parts[:4]):
        ob.hide_set(index!=1)
        ob.hide_render=index!=1

for school in schools:
    for tier,name in enumerate(FAMILIES[school],1):
        working,moving,outlet,pivot=device(school,tier)
        parts=[working.object("Works"),marker("Outlet",outlet)]
        if moving:
            parts.append(moving.object("Moving",pivot))
        write(name,parts,(list(FAMILIES).index(school)*3,tier*3,0))
if len(schools)==len(FAMILIES):
    tex.image.filepath="//../../assets/ritual/town/finishes.jpg"
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/"joinery.blend"),compress=True,relative_remap=False)
