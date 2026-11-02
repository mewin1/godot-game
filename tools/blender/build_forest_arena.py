"""Run inside Blender through MCP. Builds the standalone Zastava arena asset."""
import bpy
import math
import random
from mathutils import Vector
from pathlib import Path

ROOT = Path('/home/d0nco/godot_game')
rng = random.Random(42117)
scene = bpy.data.scenes.new('Zastava_Forest_Arena')
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

def collection(name):
    result = bpy.data.collections.new(name)
    scene.collection.children.link(result)
    return result

terrain = collection('01_Terrain')
road = collection('02_Road')
cliffs = collection('03_Cliffs')
forest = collection('04_Forest')
props = collection('05_Lanterns_and_Idol')
stage = collection('06_Presentation')

def material(name, color, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.87
    if emission:
        shader.inputs['Emission Color'].default_value = (*color, 1)
        shader.inputs['Emission Strength'].default_value = emission
    return mat

stone = [material('Basalt_%02d' % i, c) for i,c in enumerate([
    (.16,.21,.28),(.20,.26,.33),(.24,.29,.35),(.27,.32,.37),(.18,.24,.30)])]
moss = [material('Moss_%02d' % i,c) for i,c in enumerate([
    (.19,.25,.16),(.24,.30,.19),(.28,.33,.21),(.22,.28,.19)])]
soil = [material('Path_%02d' % i,c) for i,c in enumerate([
    (.35,.275,.195),(.354,.279,.199),(.358,.283,.203),(.362,.287,.207)])]
needles = [material('Fir_%02d' % i,c) for i,c in enumerate([
    (.025,.105,.13),(.035,.145,.16),(.055,.19,.19),(.07,.22,.21)])]
gold_leaves = [material('Birch_leaf_%02d' % i,c) for i,c in enumerate([
    (.47,.38,.11),(.61,.47,.15),(.70,.55,.19)])]
wood = material('Old_oak',(.17,.10,.055))
bark = material('Birch_bark',(.61,.64,.56))
iron = material('Forged_iron',(.095,.105,.105))
flame = material('Amber_glass',(1,.33,.045),5)
carving = material('Idol_carvings',(.45,.32,.14))

class Batch:
    def __init__(self, name, materials, coll):
        self.name, self.materials, self.coll = name, materials, coll
        self.vertices, self.faces, self.indices = [], [], []
    def add(self, vertices, faces, index=0):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(offset+i for i in f) for f in faces)
        self.indices.extend([index]*len(faces))
    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.materials.clear()
        for mat in self.materials: mesh.materials.append(mat)
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        self.coll.objects.link(obj)
        for poly,index in zip(mesh.polygons,self.indices): poly.material_index = index
        return obj

def column(batch, x,y,z, rx,ry,h, sides=6, index=0, tilt=0):
    phase = rng.uniform(0,math.tau)
    radii = [rng.uniform(.84,1.13) for _ in range(sides)]
    vertices=[]
    for level, scale in [(0,.86),(.16,1.0),(.84,.94),(1,.73)]:
        for i in range(sides):
            angle=phase+i*math.tau/sides
            vertices.append((x+math.cos(angle)*rx*radii[i]*scale+level*tilt,
                             y+math.sin(angle)*ry*radii[i]*scale,
                             z+h*level+(rng.uniform(-.06,.06) if level else 0)))
    faces=[tuple(reversed(range(sides)))]
    for ring in range(3):
        for i in range(sides):
            j=(i+1)%sides
            faces.append((ring*sides+i,ring*sides+j,(ring+1)*sides+j,(ring+1)*sides+i))
    faces.append(tuple(range(3*sides,4*sides)))
    batch.add(vertices,faces,index)

def box(batch, center, size, index=0):
    x,y,z=center; a,b,c=[v/2 for v in size]
    batch.add([(x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in
        [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],
        [(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],index)

def beam(batch, start, end, radius, index=0, sides=7):
    start,end=Vector(start),Vector(end)
    direction=(end-start).normalized()
    u=direction.cross(Vector((0,0,1)))
    if u.length < .01: u=direction.cross(Vector((0,1,0)))
    u.normalize(); v=direction.cross(u)
    vertices=[tuple(p+radius*(math.cos(i*math.tau/sides)*u+math.sin(i*math.tau/sides)*v))
              for p in [start,end] for i in range(sides)]
    faces=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
    faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    batch.add(vertices,faces,index)

# Broad uneven island with a flat walkable top; the side wall descends into the valley.
ground=Batch('Arena_Ground',moss+stone,terrain)
nx,ny=24,28
verts=[]
for j in range(ny+1):
    for i in range(nx+1):
        x=-3+i; y=-4+j
        verts.append((x,y,-.08+rng.uniform(-.025,.025)))
for j in range(ny):
    for i in range(nx):
        a=j*(nx+1)+i
        ground.add([verts[a],verts[a+1],verts[a+nx+2],verts[a+nx+1]],[(0,1,2),(0,2,3)],rng.randrange(4))
ground_object=ground.finish()
rocks=Batch('Basalt_Cliffs',stone,cliffs)
caps=Batch('Moss_Caps',moss,cliffs)
pebbles=Batch('Scree_and_Road_Edges',stone+moss,cliffs)
for x in [i*.62-3 for i in range(40)]:
    for y in [-3.5,23.5]:
        h=rng.uniform(2.7,3.8)
        column(rocks,x,y,-h,.55,.65,h, index=rng.randrange(5),tilt=rng.uniform(-.2,.2))
for y in [i*.64-3.5 for i in range(43)]:
    for x in [-3,21]:
        h=rng.uniform(2.8,4.1)
        column(rocks,x,y,-h,.65,.58,h,index=rng.randrange(5))

def ridge(xmin,xmax,ymin,ymax,height):
    for x in [xmin+i*.65 for i in range(int((xmax-xmin)/.65)+1)]:
        for y in [ymin+i*.70 for i in range(int((ymax-ymin)/.70)+1)]:
            h=height+rng.uniform(-.23,.22)
            column(rocks,x,y,-.13,.52,.55,h,index=rng.randrange(5),tilt=rng.uniform(-.1,.1))
            column(caps,x,y,h-.20,.46,.49,.14,index=rng.randrange(4))
    for _ in range(int((xmax-xmin+ymax-ymin)*9)):
        if rng.random()<.5:
            x=rng.choice([xmin-.5,xmax+.5])+rng.uniform(-.25,.25); y=rng.uniform(ymin-.5,ymax+.5)
        else:
            x=rng.uniform(xmin-.5,xmax+.5); y=rng.choice([ymin-.45,ymax+.45])+rng.uniform(-.2,.2)
        column(pebbles,x,y,0,rng.uniform(.08,.26),rng.uniform(.08,.26),rng.uniform(.12,.38),index=rng.randrange(9))

ridge(4.7,7.25,3.1,16.8,1.9)
ridge(10.7,13.25,3.1,16.8,2.25)
ridge(-2.7,.9,4.2,17.8,1.25)
ridge(17.3,20.5,3,17.7,1.5)
ridge(-2.5,19.9,21.4,23.2,.65)

# Rounded road follows the centre line of BoardLayout (two metres per cell).
points=[(3,-4),(3,16.8)]
for i in range(1,17):
    t=math.pi-i*math.pi/16
    points.append((6+3*math.cos(t),16.8+3*math.sin(t)))
points.append((9,3.1))
for i in range(1,17):
    t=math.pi+i*math.pi/16
    points.append((12+3*math.cos(t),3.1+3*math.sin(t)))
points.extend([(15,19),(15,24)])
samples=[]
for a,b in zip(points,points[1:]):
    count=max(1,math.ceil(math.dist(a,b)/.45))
    samples += [(a[0]+(b[0]-a[0])*i/count,a[1]+(b[1]-a[1])*i/count) for i in range(count)]
samples.append(points[-1])
path=Batch('Walkable_Road',soil,road)
for i,(x,y) in enumerate(samples):
    prev=Vector(samples[max(0,i-1)]); nxt=Vector(samples[min(len(samples)-1,i+1)])
    tangent=(nxt-prev).normalized(); side=Vector((-tangent.y,tangent.x))
    width=1.14+rng.uniform(-.045,.045)
    for t in [-1,0,1]: path.vertices.append((x+side.x*width*t,y+side.y*width*t,.015+(0 if t else .018)))
    if i:
        for k in range(2):
            a=(i-1)*3+k
            path.faces.extend([(a,a+3,a+4),(a,a+4,a+1)])
            path.indices.extend([rng.randrange(4)]*2)
    if i%2==0:
        for sign in [-1,1]:
            px=x+side.x*(width+.13)*sign; py=y+side.y*(width+.13)*sign
            column(pebbles,px,py,.02,.11,.09,rng.uniform(.06,.15),index=rng.randrange(5))
path_object=path.finish()
for poly in path_object.data.polygons: poly.use_smooth=True
for poly in ground_object.data.polygons: poly.use_smooth=True

# Shared mesh variants: layered, jagged fir boughs rather than plain stacked cones.
def fir_mesh(variant):
    batch=Batch('Fir_Variant_%d'%variant,[wood]+needles,forest)
    beam(batch,(0,0,0),(0,0,4.9),.10)
    for level in range(7):
        z=.65+level*.57; radius=1.18*(1-level/8.0)
        n=12; vertices=[]
        phase=level*.37+variant*.2
        for ring,rad,height in [(0,radius*.85,z),(1,radius,z+.20),(2,radius*.43,z+.59)]:
            for j in range(n):
                angle=j*math.tau/n+phase
                r=rad*(1.13 if j%2==0 else .67)*rng.uniform(.9,1.08)
                vertices.append((math.cos(angle)*r,math.sin(angle)*r,height+rng.uniform(-.065,.065)))
        vertices.append((0,0,z+1.0))
        for j in range(n):
            k=(j+1)%n
            batch.add([vertices[j],vertices[k],vertices[n+k],vertices[n+j]],[(0,1,2,3)],1+(level+j)%4)
            batch.add([vertices[n+j],vertices[n+k],vertices[2*n+k],vertices[2*n+j]],[(0,1,2,3)],1+(level+j+1)%4)
            batch.add([vertices[2*n+j],vertices[2*n+k],vertices[-1]],[(0,1,2)],1+(level+j+2)%4)
    obj=batch.finish(); mesh=obj.data; bpy.data.objects.remove(obj,do_unlink=True)
    return mesh

fir_variants=[fir_mesh(i) for i in range(4)]
def tree(x,y,z=0,scale=1):
    obj=bpy.data.objects.new('Fir',rng.choice(fir_variants)); forest.objects.link(obj)
    obj.location=(x,y,z); obj.rotation_euler.z=rng.uniform(0,math.tau)
    obj.scale=(scale,scale,scale*rng.uniform(.9,1.14))

# Keep both high inner ridges clear for later tower placement.
for _ in range(185):
    x=rng.uniform(-7,25); y=rng.uniform(-8,28)
    if -1<x<18 and -3<y<21: continue
    if x>15 and 16<y<24: continue
    z=-2.0 if x < -3.4 or x>21.5 or y < -4.1 or y>24 else .2
    tree(x,y,z,rng.uniform(.55,1.15))
for _ in range(46):
    x=rng.choice([rng.uniform(-2.5,.6),rng.uniform(17.7,20.5)])
    y=rng.uniform(4,18)
    if not (x>15 and y>16):
        tree(x,y,1.2 if x<2 else 1.5,rng.uniform(.48,.82))
for x,y,z in [(4.9,5,1.9),(7,14,1.9),(10.7,13,2.25),(13,5,2.25)]:
    tree(x,y,z,.42)

birches=Batch('Birch_Trunks',[bark,wood],forest)
leaves=Batch('Golden_Birch_Crowns',gold_leaves,forest)
for x,y,z in [(-.3,6,1.3),(-1,13,1.3),(18,6,1.5),(19,15,1.5),(-1,20,.1),(17,21,.7),(22,2,-2),(-5,10,-2)]:
    beam(birches,(x,y,z),(x+.16,y,z+3.8),.065)
    for i in range(8):
        angle=i*2.4; h=1.3+i*.28
        end=(x+math.cos(angle)*.7,y+math.sin(angle)*.7,z+h+.6)
        beam(birches,(x+.1,y,z+h),end,.022)
        for j in range(3):
            column(leaves,end[0]+rng.uniform(-.3,.3),end[1]+rng.uniform(-.3,.3),end[2]-.2,.36,.28,.48,index=rng.randrange(3))
birches.finish(); leaves.finish()

timber=Batch('Lantern_Timber',[wood],props)
metal=Batch('Lantern_Iron',[iron],props)
glow=Batch('Lantern_Amber_Glass',[flame],props)
lantern_positions=[(1.65,-.8),(1.55,9),(3.1,20.6),(10.35,10),(13.7,-.35),(16.45,12.5)]
def point_light(name,position,color,power,radius):
    data=bpy.data.lights.new(name,'POINT'); data.energy=480; data.color=color; data.shadow_soft_size=radius
    data.use_shadow=False
    obj=bpy.data.objects.new(name,data); stage.objects.link(obj); obj.location=position
    return obj
for x,y in lantern_positions:
    box(timber,(x,y,.13),(.45,.42,.26))
    box(timber,(x,y,1.5),(.16,.16,2.8))
    box(timber,(x+.38,y,2.85),(1.03,.16,.16))
    beam(timber,(x,y,2.28),(x+.46,y,2.78),.045)
    beam(metal,(x+.72,y,2.8),(x+.72,y,2.39),.025)
    column(glow,x+.72,y,1.98,.115,.115,.38,index=0)
    for z in [1.96,2.37]: box(metal,(x+.72,y,z),(.31,.27,.07))
    for dx,dy in [(-.12,-.1),(-.12,.1),(.12,-.1),(.12,.1)]:
        beam(metal,(x+.72+dx,y+dy,1.99),(x+.72+dx,y+dy,2.38),.015)
    point_light('Lantern_Warm',(x+.72,y,2.2),(1,.41,.10),180,.65)
timber.finish(); metal.finish(); glow.finish()

idol=Batch('Guardian_Idol',stone+[carving],props)
ix,iy=16.6,21.0
box(idol,(ix,iy,.12),(1.55,1.35,.24),2)
box(idol,(ix,iy,.38),(1.2,1.0,.28),3)
box(idol,(ix,iy,1.5),(.75,.7,2.05),2)
box(idol,(ix,iy,2.57),(.91,.8,.25),3)
# Raised geometric face and folk lozenge motifs on the camera-facing side.
for xx in [-.19,.19]:
    box(idol,(ix+xx,iy-.365,2.13),(.22,.055,.065),5)
box(idol,(ix,iy-.40,1.94),(.10,.13,.27),5)
box(idol,(ix,iy-.37,1.73),(.29,.05,.06),5)
for z in [.8,1.18,1.48]:
    for a,b in [((-.21,0),(0,.16)),((0,.16),(.21,0)),((.21,0),(0,-.16)),((0,-.16),(-.21,0))]:
        beam(idol,(ix+a[0],iy-.37,z+a[1]),(ix+b[0],iy-.37,z+b[1]),.025,5)
idol.finish()
brazier=Batch('Offering_Brazier',[stone[2],iron,flame],props)
column(brazier,15.6,20.9,.02,.42,.42,.24,index=0)
column(brazier,15.6,20.9,.25,.3,.3,.20,index=1)
column(brazier,15.6,20.9,.45,.18,.17,.5,index=2)
brazier.finish()
point_light('Idol_Fire',(15.6,20.9,.9),(1,.35,.06),220,.55)
rocks.finish(); caps.finish(); pebbles.finish()

world=bpy.data.worlds.new('Blue_Hour'); scene.world=world; world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
background.inputs['Color'].default_value=(.055,.095,.19,1)
background.inputs['Strength'].default_value=.45
sun_data=bpy.data.lights.new('Moon','SUN'); sun_data.energy=.95; sun_data.color=(.48,.65,1)
sun_data.angle=.15
sun=bpy.data.objects.new('Moon',sun_data); stage.objects.link(sun)
sun.rotation_euler=(math.radians(24),math.radians(-25),math.radians(-35))
area_data=bpy.data.lights.new('Soft_Sky','AREA'); area_data.energy=1100; area_data.shape='DISK'; area_data.size=30
area_data.color=(.36,.54,1)
area=bpy.data.objects.new('Soft_Sky',area_data); stage.objects.link(area); area.location=(8,7,19)
camera_data=bpy.data.cameras.new('Arena_Camera'); camera=bpy.data.objects.new('Arena_Camera',camera_data)
stage.objects.link(camera); camera.location=(20,-35,34)
target=Vector((8.5,10,0)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'; camera_data.ortho_scale=39; camera_data.lens=45; camera_data.clip_end=250
scene.camera=camera
scene.render.resolution_x=1600; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ROOT/'output/forest_arena/blender_preview.png')
scene.view_settings.view_transform='AgX'
scene['reference']='User image #3, 2026-11-02. Standalone art scene, not yet connected to MatchSim.'
scene['grid_mapping']='Godot (x,z) = Blender (x,-y). Cell=2m; centres x=3/9/15, y=19-2*grid_y. Rounded turns are visual only.'
scene['seed']=42117
for area_ui in bpy.context.screen.areas:
    if area_ui.type=='VIEW_3D':
        area_ui.spaces.active.region_3d.view_perspective='CAMERA'
print('BUILT',len(scene.objects),'objects;',sum(len(o.data.polygons) for o in scene.objects if o.type=='MESH'),'instance faces')
