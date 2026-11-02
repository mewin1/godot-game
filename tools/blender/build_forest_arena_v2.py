"""Forest arena v2: solid basalt plateau with a carved, climbing road (run inside Blender).

Board 9x10 cells, 2 m per cell. Cell (gx, gy) centre: x = 1 + 2*gx, y = 19 - 2*gy.
Every non-path cell is a flat terrace for a tower, including the outer columns 0 and 8.
The road rises evenly from the entrance (front left) to the idol (back right).
Blender (X, Y, Z) becomes Godot (X, Z, -Y) on glTF export.
"""
import importlib
import math
import random
import re
import sys
from pathlib import Path
from types import SimpleNamespace

import bpy
from mathutils import Vector, kdtree

ROOT = Path('/home/d0nco/godot_game')
sys.path.insert(0, str(ROOT / 'tools/blender'))
import forest_dressing  # noqa: E402  (tree meshes shared with v1 work)
importlib.reload(forest_dressing)

SCENE_NAME = 'Zastava_Forest_Arena'
CELL = 2.0
ROAD_RISE = 6.0          # metres climbed between entering and leaving the board
LIFT = 0.4               # terraces sit this much above the mountain slope surface
MIN_WALL = 0.35          # a terrace is never within this height of a neighbouring road
TERRACE_STEP = 0.25
CLIFF_DROP = 4.2         # the arena is a shelf this high above the surrounding slope
FOOT = (-0.9, 18.9, -0.9, 21.3)   # plateau outline: x min/max, y min/max
IDOL_PAD = (13.0, 17.0, 20.0, 23.9)
rng = random.Random(51123)

# ---------------------------------------------------------------- scene, materials
old = bpy.data.scenes.get(SCENE_NAME)
if old and 'road_rise_m' in old:
    # Re-run of this script: drop the previous v2 build, keep the v1 scene intact.
    if len(bpy.data.scenes) > 1:
        bpy.context.window.scene = next(s for s in bpy.data.scenes if s != old)
    for coll in list(old.collection.children):
        for obj in list(coll.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(coll)
    bpy.data.scenes.remove(old)
    bpy.data.orphans_purge(do_recursive=True)
elif old:
    old.name = SCENE_NAME + '_v1'
scene = bpy.data.scenes.new(SCENE_NAME)
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'


def collection(name):
    result = bpy.data.collections.new(name)
    scene.collection.children.link(result)
    return result


terrain_c = collection('01_Terrain')
road_c = collection('02_Road')
cliffs_c = collection('03_Cliffs')
forest_c = collection('04_Forest')
props_c = collection('05_Lanterns_and_Idol')
stage_c = collection('06_Presentation')


def material(name, color, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.88
    if emission:
        shader.inputs['Emission Color'].default_value = (*color, 1)
        shader.inputs['Emission Strength'].default_value = emission
    return mat


def vertex_color_material(name, layer):
    mat = material(name, (1, 1, 1))
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    paint = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    paint.layer_name = layer
    mat.node_tree.links.new(paint.outputs['Color'], shader.inputs['Base Color'])
    return mat


COLOR_LAYER = 'Arena_Paint'
terrain_mat = vertex_color_material('V2_Terrain_Paint', COLOR_LAYER)
stone = [material('V2_Basalt_%02d' % i, c) for i, c in enumerate([
    (.15, .19, .25), (.19, .23, .29), (.23, .27, .32), (.26, .30, .34), (.17, .21, .27)])]
moss = [material('V2_Moss_%02d' % i, c) for i, c in enumerate([
    (.19, .25, .14), (.23, .29, .17), (.27, .32, .19), (.21, .27, .17)])]
valley_mat = material('V2_Valley_Peat', (.06, .115, .15))
wood = material('V2_Old_oak', (.17, .10, .055))
bark = material('V2_Birch_bark', (.61, .64, .56))
iron = material('V2_Forged_iron', (.095, .105, .105))
flame = material('V2_Amber_glass', (1, .33, .045), 5)
carving = material('V2_Idol_carvings', (.45, .32, .14))
needles = [material('V2_Fir_%02d' % i, c) for i, c in enumerate([
    (.025, .105, .13), (.035, .145, .16), (.055, .19, .19), (.07, .22, .21)])]
gold_leaves = [material('V2_Birch_leaf_%02d' % i, c) for i, c in enumerate([
    (.47, .38, .11), (.61, .47, .15), (.70, .55, .19)])]


class Batch:
    def __init__(self, name, materials, coll):
        self.name, self.materials, self.coll = name, materials, coll
        self.vertices, self.faces, self.indices = [], [], []

    def add(self, vertices, faces, index=0):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(offset + i for i in f) for f in faces)
        if isinstance(index, (list, tuple)):
            self.indices.extend(index)
        else:
            self.indices.extend([index] * len(faces))

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        for mat in self.materials:
            mesh.materials.append(mat)
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        self.coll.objects.link(obj)
        for poly, index in zip(mesh.polygons, self.indices):
            poly.material_index = index
        return obj


def column(batch, x, y, z, rx, ry, h, index=0, top=None, sides=6, tilt=(0.0, 0.0)):
    """Faceted basalt prism; `top` is the material index of the cap."""
    phase = rng.uniform(0, math.tau)
    radii = [rng.uniform(.86, 1.12) for _ in range(sides)]
    vertices = []
    for level, scale in [(0, .9), (.12, 1.0), (.88, .95), (1, .78)]:
        for i in range(sides):
            angle = phase + i * math.tau / sides
            vertices.append((x + math.cos(angle) * rx * radii[i] * scale + level * tilt[0],
                             y + math.sin(angle) * ry * radii[i] * scale + level * tilt[1],
                             z + h * level + (rng.uniform(-.05, .05) if level == 1 else 0)))
    faces = [tuple(reversed(range(sides)))]
    for ring in range(3):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((ring * sides + i, ring * sides + j, (ring + 1) * sides + j,
                          (ring + 1) * sides + i))
    faces.append(tuple(range(3 * sides, 4 * sides)))
    indices = [index] * (len(faces) - 1) + [index if top is None else top]
    batch.add(vertices, faces, indices)


def box(batch, center, size, index=0):
    x, y, z = center
    a, b, c = [v / 2 for v in size]
    batch.add([(x + dx * a, y + dy * b, z + dz * c) for dx, dy, dz in
               [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]],
              [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)],
              index)


def beam(batch, start, end, radius, index=0, sides=7):
    start, end = Vector(start), Vector(end)
    direction = (end - start).normalized()
    u = direction.cross(Vector((0, 0, 1)))
    if u.length < .01:
        u = direction.cross(Vector((0, 1, 0)))
    u.normalize()
    v = direction.cross(u)
    vertices = [tuple(p + radius * (math.cos(i * math.tau / sides) * u
                                    + math.sin(i * math.tau / sides) * v))
                for p in [start, end] for i in range(sides)]
    faces = [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    faces += [(i, (i + 1) % sides, (i + 1) % sides + sides, i + sides) for i in range(sides)]
    batch.add(vertices, faces, index)


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(p + (q - p) * t for p, q in zip(a, b))


# ---------------------------------------------------------------- board and road line
board_text = (ROOT / 'data/board/board_default.tres').read_text()
path_line = next(line for line in board_text.splitlines() if line.startswith('path_cells'))
PATH = [(int(a), int(b)) for a, b in re.findall(r'Vector2i\((\d+), (\d+)\)', path_line)]
PATH_SET = set(PATH)
BOARD_W, BOARD_H = 9, 10


def cell_centre(gx, gy):
    return 1 + CELL * gx, 19 - CELL * gy


line = []


def seg(a, b):
    count = max(1, math.ceil(math.dist(a, b) / .08))
    line.extend((a[0] + (b[0] - a[0]) * i / count, a[1] + (b[1] - a[1]) * i / count)
                for i in range(count))


def arc(c, r, a0, a1):
    count = max(4, math.ceil(abs(a1 - a0) * r / .08))
    line.extend((c[0] + r * math.cos(a0 + (a1 - a0) * i / count),
                 c[1] + r * math.sin(a0 + (a1 - a0) * i / count)) for i in range(count))


# Straight runs follow the cell centres; the two hairpins are semicircles (radius 1.5 cells).
seg((3, -14), (3, 16))
arc((6, 16), 3, math.pi, 0)
seg((9, 16), (9, 4))
arc((12, 4), 3, math.pi, 2 * math.pi)
seg((15, 4), (15, 22.6))
line.append((15, 22.6))
lengths = [0.0]
for a, b in zip(line, line[1:]):
    lengths.append(lengths[-1] + math.dist(a, b))
L_ENTRY = 14.0                                 # length where the road enters the board (y = 0)
L_EXIT = next(l for (x, y), l in zip(line, lengths) if x == 15 and y >= 20 and l > 40)
BOARD_LEN = L_EXIT - L_ENTRY
tangents = []
for i in range(len(line)):
    a = Vector(line[max(0, i - 1)])
    b = Vector(line[min(len(line) - 1, i + 1)])
    tangents.append((b - a).normalized())
tree = kdtree.KDTree(len(line))
for i, (x, y) in enumerate(line):
    tree.insert((x, y, 0), i)
tree.balance()


def road_z(l):
    u = l - L_ENTRY
    if u < 0:
        return 0.3 * u                      # ramp down to the valley outside the board
    if u <= BOARD_LEN:
        return ROAD_RISE * u / BOARD_LEN
    return ROAD_RISE + 0.05 * (u - BOARD_LEN)


def half_width(l):
    return 1.45 + .06 * math.sin(l * 1.3) + .04 * math.sin(l * 3.1 + 1)


def nearest(x, y):
    _, i, d = tree.find((x, y, 0))
    t = tangents[i]
    cx, cy = line[i]
    side = 1 if t.x * (y - cy) - t.y * (x - cx) > 0 else -1
    return i, d, side


# ---------------------------------------------------------------- mountain slope and terraces
# The whole arena is one hillside: a plane fitted to the climbing road, plus the local
# deviation of the nearby road (inverse-distance weighted), like a serpentine mountain pass.
board_samples = [(line[i][0], line[i][1], road_z(lengths[i])) for i in range(0, len(line), 4)
                 if L_ENTRY <= lengths[i] <= L_EXIT]


def fit_plane(points):
    n = len(points)
    sx = sum(p[0] for p in points)
    sy = sum(p[1] for p in points)
    sz = sum(p[2] for p in points)
    sxx = sum(p[0] ** 2 for p in points)
    syy = sum(p[1] ** 2 for p in points)
    sxy = sum(p[0] * p[1] for p in points)
    sxz = sum(p[0] * p[2] for p in points)
    syz = sum(p[1] * p[2] for p in points)
    m = [[n, sx, sy, sz], [sx, sxx, sxy, sxz], [sy, sxy, syy, syz]]
    for c in range(3):                      # Gauss-Jordan on the 3x3 normal equations
        pivot = m[c][c]
        m[c] = [v / pivot for v in m[c]]
        for r in range(3):
            if r != c:
                f = m[r][c]
                m[r] = [a - f * b for a, b in zip(m[r], m[c])]
    return m[0][3], m[1][3], m[2][3]


PA, PB, PC = fit_plane(board_samples)


def slope_plane(x, y):
    return PA + PB * x + PC * y


def slope_surface(x, y):
    total, weight = 0.0, 0.0
    for sx, sy, sz in board_samples:
        d2 = (sx - x) ** 2 + (sy - y) ** 2 + .5
        if d2 < 64:
            w = 1 / d2          # summed along a road line this falls off as 1/distance
            total += w * (sz - slope_plane(sx, sy))
            weight += w
    return slope_plane(x, y) + (total / weight if weight else 0.0)


def raw_cell_height(gx, gy):
    cx, cy = cell_centre(gx, gy)
    near = [road_z(lengths[i]) for _, i, _ in tree.find_range((cx, cy, 0), 2.6)
            if L_ENTRY <= lengths[i] <= L_EXIT]
    h = slope_surface(cx, cy) + LIFT
    # Downhill terraces may sit below the road (a retaining wall holds the road up),
    # but a terrace level with the road would blur the tower spot into the path.
    for z in sorted(near):
        if abs(h - z) < MIN_WALL:
            h = z + MIN_WALL
    return h


heights = {}
for gy in range(BOARD_H):
    for gx in range(BOARD_W):
        if (gx, gy) not in PATH_SET:
            heights[(gx, gy)] = math.ceil(raw_cell_height(gx, gy) / TERRACE_STEP) * TERRACE_STEP

cells = []
for (gx, gy), h in heights.items():
    cx, cy = cell_centre(gx, gy)
    cells.append((cx - 1, cy - 1, cx + 1, cy + 1, h, nearest(cx, cy)[2], gx, gy))


def block_height(x, y, side, rz):
    best, best_d = None, 99.0
    for x0, y0, x1, y1, h, s, _, _ in cells:
        if s != side:
            continue
        dx = max(x0 - x, 0, x - x1)
        dy = max(y0 - y, 0, y - y1)
        dd = dx * dx + dy * dy
        if dd < best_d:
            best_d, best = dd, h
    if best_d > 1.0:
        # Narrow rocky lip outside the board (behind the top hairpin, before the bottom one).
        return rz + .3 + .06 * math.sin(x * 2.3 + y * 1.7)
    return best


def valley(x, y):
    # The surrounding mountainside continues the same slope below the arena shelf.
    z = slope_plane(x, y) - CLIFF_DROP + .45 * math.sin(x * .31 + y * .19) + .35 * math.cos(y * .36 + x * .07)
    far = math.hypot((x - 9) / 26, (y - 10) / 24)
    return z + 7.5 * smoothstep(1.0, 2.0, far)


def foot_noise(t, seed):
    return .14 * math.sin(t * 1.7 + seed) + .07 * math.sin(t * 4.3 + 2 * seed)


def inside_distance(x, y):
    """Positive inside the plateau outline (metres to its edge)."""
    x0, x1, y0, y1 = FOOT
    d = min(x - (x0 + foot_noise(y, 1)), (x1 + foot_noise(y, 2)) - x,
            y - (y0 + foot_noise(x, 3)), (y1 + foot_noise(x, 4)) - y)
    px0, px1, py0, py1 = IDOL_PAD
    pad = min(x - px0, px1 - x, y - py0, py1 - y)
    return max(d, pad)


def height(x, y):
    i, d, side = nearest(x, y)
    l = lengths[i]
    rz = road_z(l)
    v = valley(x, y)
    inside = inside_distance(x, y)
    if inside <= 0:
        if l < L_ENTRY + .5:          # embankment of the entry ramp
            return max(v, rz - 2.2 * max(0.0, d - half_width(l))), 'spur'
        return v, 'valley'
    hw = half_width(l)
    block = block_height(x, y, side, rz)
    w = smoothstep(hw - .05, hw + .10, d)
    crown = .035 * (1 - min(1.0, d / hw) ** 2)
    z = rz + crown + (block - rz) * w
    edge = smoothstep(0, .14, inside)
    kind = 'road' if w < .5 else 'top'
    return v + (z - v) * edge, kind


# ---------------------------------------------------------------- terrain heightfield
STEP = .2
X0, X1, Y0, Y1 = -4.0, 22.0, -15.0, 25.0
nx = int(round((X1 - X0) / STEP))
ny = int(round((Y1 - Y0) / STEP))
zs, kinds = [], []
for j in range(ny + 1):
    row_z, row_k = [], []
    for i in range(nx + 1):
        z, k = height(X0 + i * STEP, Y0 + j * STEP)
        row_z.append(z)
        row_k.append(k)
    zs.append(row_z)
    kinds.append(row_k)


def turf(x, y):
    pasture, lichen, shale = (.16, .24, .075), (.29, .34, .13), (.22, .26, .20)
    hum = (.45 * math.sin(1.32 * x + .62 * y) + .31 * math.sin(.86 * x - 1.04 * y)
           + .24 * math.cos(x * 2.64 + y * 1.51))
    base = mix(pasture, lichen, .45 + .5 * hum)
    return mix(base, shale, .25 * abs(math.sin(.63 * x + 1.1 * y)))


def paint(i, j):
    x, y = X0 + i * STEP, Y0 + j * STEP
    z = zs[j][i]
    gx = (zs[j][min(nx, i + 1)] - zs[j][max(0, i - 1)]) / (2 * STEP)
    gy = (zs[min(ny, j + 1)][i] - zs[max(0, j - 1)][i]) / (2 * STEP)
    slope = math.hypot(gx, gy)
    kind = kinds[j][i]
    rock = mix((.11, .135, .18), (.25, .275, .30), .5 + .3 * math.sin(z * 3.1 + x * .4)
               + .15 * math.sin(y * 1.9))
    if kind == 'valley':
        color = mix((.05, .10, .13), (.07, .13, .15), .5 + .5 * math.sin(x * .7 + y * .5))
    elif kind == 'road' or kind == 'spur':
        _, d, _ = nearest(x, y)
        if kind == 'spur' and d > 1.0:
            # Ramp banks: dark moss and peat, not bare rock.
            return mix((.13, .17, .08), (.06, .10, .12), smoothstep(1.0, 3.0, d))
        dirt = mix((.33, .26, .18), (.38, .30, .21), .5 + .5 * math.sin(x * 3.1 + y * 2.3))
        dirt = mix(dirt, (.29, .225, .16), .35 * math.exp(-((abs(d) - .55) / .14) ** 2))
        color = mix(dirt, turf(x, y), smoothstep(.95, 1.32, d))
    else:
        color = turf(x, y)
    return mix(color, rock, smoothstep(.9, 2.2, slope))


tf = Batch('Arena_Terrain', [terrain_mat], terrain_c)
tf.vertices = [(X0 + i * STEP, Y0 + j * STEP, zs[j][i]) for j in range(ny + 1) for i in range(nx + 1)]
stride = nx + 1
for j in range(ny):
    for i in range(nx):
        a = j * stride + i
        b, c, d = a + 1, a + stride + 1, a + stride
        # Split along the shorter height jump to keep cliff edges crisp.
        if abs(zs[j][i] - zs[j + 1][i + 1]) <= abs(zs[j][i + 1] - zs[j + 1][i]):
            tf.faces += [(a, b, c), (a, c, d)]
        else:
            tf.faces += [(a, b, d), (b, c, d)]
tf.indices = [0] * len(tf.faces)
terrain_obj = tf.finish()
attr = terrain_obj.data.color_attributes.new(name=COLOR_LAYER, type='BYTE_COLOR', domain='POINT')
colors = []
for j in range(ny + 1):
    for i in range(nx + 1):
        colors.extend((*paint(i, j), 1.0))
attr.data.foreach_set('color', colors)
for poly in terrain_obj.data.polygons:
    poly.use_smooth = poly.normal.z > .75

# Wide valley floor under and around the plateau (coarse; the camera sees far).
vb = Batch('Forest_Valley', [valley_mat], forest_c)
xs, ys = list(range(-50, 72, 3)), list(range(-46, 80, 3))
vb.vertices = [(x, y, valley(x, y) - .06) for y in ys for x in xs]
for j in range(len(ys) - 1):
    for i in range(len(xs) - 1):
        a = j * len(xs) + i
        vb.faces += [(a, a + 1, a + len(xs) + 1), (a, a + len(xs) + 1, a + len(xs))]
vb.indices = [0] * len(vb.faces)
valley_obj = vb.finish()
for poly in valley_obj.data.polygons:
    poly.use_smooth = True

# ---------------------------------------------------------------- basalt columns
rocks = Batch('Basalt_Columns', stone + moss, cliffs_c)
scree = Batch('Scree_and_Road_Edges', stone + moss, cliffs_c)


def top_at(x, y):
    return height(x, y)[0]


# Road walls: a dense row of columns along both edges wherever the terrace stands above.
for side in (-1, 1):
    travelled, prev = 0.0, None
    for i, (cx, cy) in enumerate(line):
        l = lengths[i]
        if l < L_ENTRY - .9 or l > lengths[-1] - .2:
            continue
        t = tangents[i]
        n = Vector((-t.y, t.x)) * side
        hw = half_width(l)
        p = Vector((cx, cy)) + n * (hw + .2)
        if prev is not None:
            travelled += (p - prev).length
        prev = p
        if travelled < rng.uniform(.42, .55):
            continue
        travelled = 0.0
        rz = road_z(l)
        beyond = Vector((cx, cy)) + n * (hw + .75)
        zt = top_at(beyond.x, beyond.y)
        if inside_distance(beyond.x, beyond.y) <= 0 or abs(zt - rz) < .22:
            continue
        r = rng.uniform(.28, .36)
        if zt > rz:      # cut wall on the uphill side
            column(rocks, p.x, p.y, rz - .3, r, r * rng.uniform(.85, 1.1),
                   zt - rz + .3 + rng.uniform(-.2, .12), index=rng.randrange(5),
                   top=5 + rng.randrange(4), tilt=(n.x * -.06, n.y * -.06))
        else:            # retaining wall under the road on the downhill side
            column(rocks, p.x, p.y, zt - .3, r, r * rng.uniform(.85, 1.1),
                   rz - zt + .3 + rng.uniform(-.06, .04), index=rng.randrange(5),
                   top=5 + rng.randrange(4))
        if rng.random() < .55:
            q = Vector((cx, cy)) + n * (hw - .12 + rng.uniform(-.05, .08))
            column(scree, q.x, q.y, rz - .02, rng.uniform(.08, .2), rng.uniform(.08, .18),
                   rng.uniform(.07, .2), index=rng.randrange(9))


# Outer cliff: tall columns all around the plateau, down into the valley.
def outline_points():
    x0, x1, y0, y1 = FOOT
    px0, px1, py0, py1 = IDOL_PAD
    edges = []
    for x in [x0 + k * .5 for k in range(int((x1 - x0) / .5) + 1)]:
        if not 1.6 < x < 4.4:                       # entry ramp gap
            edges.append((x, y0 + foot_noise(x, 3), (0, -1)))
        if not px0 + .2 < x < px1 - .2:
            edges.append((x, y1 + foot_noise(x, 4), (0, 1)))
    for y in [y0 + k * .5 for k in range(int((y1 - y0) / .5) + 1)]:
        edges.append((x0 + foot_noise(y, 1), y, (-1, 0)))
        edges.append((x1 + foot_noise(y, 2), y, (1, 0)))
    for x in [px0 + .3 + k * .5 for k in range(int((px1 - px0 - .3) / .5))]:
        edges.append((x, py1, (0, 1)))
    for y in [py0 + 1.3 + k * .5 for k in range(int((py1 - py0 - 1.3) / .5) + 1)]:
        edges.append((px0, y, (-1, 0)))
        edges.append((px1, y, (1, 0)))
    return edges


for x, y, (ox, oy) in outline_points():
    zt = top_at(x - ox * .45, y - oy * .45)
    zb = valley(x, y) - .7
    if zt - zb < 1:
        continue
    r = rng.uniform(.42, .58)
    px, py = x + ox * .18 + rng.uniform(-.06, .06), y + oy * .18 + rng.uniform(-.06, .06)
    column(rocks, px, py, zb, r, r * rng.uniform(.85, 1.1),
           zt - zb + rng.uniform(-.28, .06), index=rng.randrange(5),
           top=5 + rng.randrange(4), tilt=(ox * .12, oy * .12))
    # A second, shorter ring gives the foot of the cliff its broken talus.
    if rng.random() < .6:
        r2 = rng.uniform(.4, .7)
        column(rocks, px + ox * .55, py + oy * .55, zb, r2, r2,
               rng.uniform(1.2, 3.2), index=rng.randrange(5), top=5 + rng.randrange(4))

# Low steps between terraces of different heights get a few loose blocks.
for x0, y0, x1, y1, h, s, gx, gy in cells:
    for dgx, dgy in [(1, 0), (0, 1)]:
        other = heights.get((gx + dgx, gy + dgy))
        if other is None or abs(other - h) < .05:
            continue
        for k in range(2):
            if rng.random() < .55:
                continue
            t = rng.uniform(.15, .85)
            if dgx:
                x, y = x1, y0 + 2 * t
            else:
                x, y = x0 + 2 * t, y0
            low = min(h, other)
            column(rocks, x + rng.uniform(-.1, .1), y + rng.uniform(-.1, .1), low - .2,
                   .3, .28, abs(other - h) + .15, index=rng.randrange(5),
                   top=5 + rng.randrange(4))

rocks.finish()
scree.finish()

# Low shrubs along terrace rims and grass tufts on the tops (towers stand in cell centres).
shrub_mats = [material('V2_Shrub_%02d' % i, c) for i, c in enumerate([
    (.07, .16, .07), (.11, .21, .08), (.20, .25, .07)])]
greens = Batch('Rim_Shrubs_and_Grass', shrub_mats, cliffs_c)
for _ in range(1400):
    x, y = rng.uniform(FOOT[0], FOOT[1]), rng.uniform(FOOT[2], FOOT[3])
    z, kind = height(x, y)
    if kind != 'top' or inside_distance(x, y) < .35:
        continue
    _, d, _ = nearest(x, y)
    fx, fy = (x - 1) / 2 % 1, (19 - y) / 2 % 1 if y < 20 else .0
    rim = min(fx, 1 - fx, fy, 1 - fy) if y < 20 else 0
    near_wall = d - half_width(lengths[nearest(x, y)[0]]) < .9
    if near_wall and rng.random() < .55:
        forest_dressing.leaf_cluster(greens, rng, (x, y, z + .12), rng.uniform(.18, .3),
                                     rng.randrange(3))
    elif rim < .3 or rng.random() < .25:
        for _blade in range(rng.randint(3, 6)):
            bx, by = x + rng.uniform(-.12, .12), y + rng.uniform(-.12, .12)
            lean = (rng.uniform(-.08, .08), rng.uniform(-.08, .08))
            greens.add([(bx - .03, by, z - .02), (bx + .03, by, z - .02),
                        (bx + lean[0], by + lean[1], z + rng.uniform(.14, .28))],
                       [(0, 1, 2)], rng.randrange(3))
greens_obj = greens.finish()

# ---------------------------------------------------------------- lanterns, idol, lights


def point_light(name, position, color, energy, radius):
    data = bpy.data.lights.new(name, 'POINT')
    data.energy = energy
    data.color = color
    data.shadow_soft_size = radius
    data.use_shadow = False
    obj = bpy.data.objects.new(name, data)
    stage_c.objects.link(obj)
    obj.location = position
    return obj


timber = Batch('Lantern_Timber', [wood], props_c)
metal = Batch('Lantern_Iron', [iron], props_c)
glow = Batch('Lantern_Amber_Glass', [flame], props_c)
lantern_lights = []


def lantern(u, side):
    """Post on the road verge at board length u; the arm reaches over the road."""
    l = L_ENTRY + u
    i = min(range(len(lengths)), key=lambda k: abs(lengths[k] - l))
    t = tangents[i]
    n = Vector((-t.y, t.x)) * side
    base = Vector(line[i]) + n * (half_width(l) - .2)
    z = road_z(l)
    arm = -n
    x, y = base
    tip = (x + arm.x * .72, y + arm.y * .72)
    box(timber, (x, y, z + .13), (.42, .42, .26))
    box(timber, (x, y, z + 1.5), (.16, .16, 2.8))
    beam(timber, (x, y, z + 2.85), (x + arm.x * .9, y + arm.y * .9, z + 2.85), .08, sides=4)
    beam(timber, (x, y, z + 2.28), (x + arm.x * .46, y + arm.y * .46, z + 2.78), .045)
    beam(metal, (tip[0], tip[1], z + 2.8), (tip[0], tip[1], z + 2.39), .025)
    column(glow, tip[0], tip[1], z + 1.98, .115, .115, .38)
    for zz in [1.96, 2.37]:
        box(metal, (tip[0], tip[1], z + zz), (.3, .3, .07))
    lantern_lights.append(point_light('Lantern_Warm', (tip[0], tip[1], z + 2.2),
                                      (1, .41, .10), 230, .6))


for u, side in [(2.5, 1), (11.5, -1), (16 + 3 * math.pi / 2, 1), (31.4, 1),
                (16 + 3 * math.pi + 12 + 3 * math.pi / 2, -1), (54.0, 1)]:
    lantern(u, side)
timber.finish()
metal.finish()
glow.finish()

idol = Batch('Guardian_Idol', stone + [carving], props_c)
ix, iy = 15.0, 23.0
iz = road_z(lengths[-1]) + .45
box(idol, (ix, iy, iz + .12), (1.55, 1.35, .24), 2)
box(idol, (ix, iy, iz + .38), (1.2, 1.0, .28), 3)
box(idol, (ix, iy, iz + 1.5), (.75, .7, 2.05), 2)
box(idol, (ix, iy, iz + 2.57), (.91, .8, .25), 3)
for xx in [-.19, .19]:
    box(idol, (ix + xx, iy - .365, iz + 2.13), (.22, .055, .065), 5)
box(idol, (ix, iy - .40, iz + 1.94), (.10, .13, .27), 5)
box(idol, (ix, iy - .37, iz + 1.73), (.29, .05, .06), 5)
for zz in [.8, 1.18, 1.48]:
    for a, b in [((-.21, 0), (0, .16)), ((0, .16), (.21, 0)), ((.21, 0), (0, -.16)),
                 ((0, -.16), (-.21, 0))]:
        beam(idol, (ix + a[0], iy - .37, iz + zz + a[1]), (ix + b[0], iy - .37, iz + zz + b[1]),
             .025, 5)
idol.finish()
brazier = Batch('Offering_Brazier', [stone[2], iron, flame], props_c)
bx, by = 13.9, 22.6
column(brazier, bx, by, iz + .02, .42, .42, .24, index=0)
column(brazier, bx, by, iz + .25, .3, .3, .20, index=1)
column(brazier, bx, by, iz + .45, .18, .17, .5, index=2)
brazier.finish()
idol_light = point_light('Idol_Fire', (bx, by, iz + .9), (1, .35, .06), 380, .5)

# ---------------------------------------------------------------- forest (outside the plateau only)
api = SimpleNamespace(Batch=Batch, beam=beam, material=material, wood=wood, bark=bark,
                      needles=needles, gold_leaves=gold_leaves, forest=forest_c)
spruce = [forest_dressing.fir_mesh(api, rng, k) for k in range(3)]
birch = [forest_dressing.birch_mesh(api, rng, k) for k in range(2)]


def plant(x, y, scale, birch_chance=.14, z=None):
    mesh = rng.choice(birch) if rng.random() < birch_chance else rng.choice(spruce)
    obj = bpy.data.objects.new('Birch' if mesh in birch else 'Spruce', mesh)
    forest_c.objects.link(obj)
    obj.location = (x, y, (valley(x, y) if z is None else z) - .12)
    obj.scale = (scale, scale, scale * rng.uniform(.95, 1.12))
    obj.rotation_euler.z = rng.uniform(0, math.tau)


# Side belts hug the cliffs: two staggered rows each side, nothing on the plateau.
for side_x, direction in [(FOOT[0] - 1.9, -1), (FOOT[1] + 1.9, 1)]:
    for row, step in [(0, 1.45), (1, 1.9)]:
        y = -12 + rng.random()
        while y < 28:
            x = side_x + direction * (row * 1.7 + rng.uniform(0, .5))
            plant(x, y, rng.uniform(.95, 1.2) + row * .15)
            y += step * rng.uniform(.8, 1.3)
# Front belt below the cliffs; the entry ramp keeps a clear corridor.
x = -2.5
while x < 21.5:
    for row in range(2):
        y = FOOT[2] - 2.2 - row * 1.8 + rng.uniform(-.3, .3)
        xx = x + row * .7
        if abs(xx - 3) > 2.6:
            plant(xx, y, rng.uniform(1.05, 1.35))
    x += rng.uniform(1.3, 1.8)
# Along the ramp, below its banks.
for y in [-3.5, -5.5, -7.5, -9.5, -11.5]:
    for s in (-1, 1):
        plant(3 + s * rng.uniform(2.6, 3.4), y + rng.uniform(-.4, .4), rng.uniform(.85, 1.15))
# Behind the plateau and on its back lip (behind the road, never in front of it).
x = -2.5
while x < 21.5:
    if not 12.6 < x < 17.4:
        plant(x, FOOT[3] + 2.0 + rng.uniform(0, 1.2), rng.uniform(.8, 1.1))
    x += rng.uniform(1.4, 2.0)
for x in [3.6, 5.4, 7.6, 9.2]:
    y = 20.85 + rng.uniform(-.1, .15)
    plant(x, y, rng.uniform(.38, .5), birch_chance=.35, z=top_at(x, y))

far = Batch('Distant_Forest_Silhouettes', [
    material('V2_Forest_Distant_Deep', (.035, .105, .16), .12),
    material('V2_Forest_Distant_Blue', (.069, .151, .223), .12)], forest_c)
for row in range(34):
    for col in range(44):
        x = -30 + col * 2.1 + rng.uniform(-.7, .7)
        y = -24 + row * 2.1 + rng.uniform(-.7, .7)
        if -7.5 < x < 26.5 and -15 < y < 29:
            continue
        if rng.random() < .5 + .22 * math.sin(x * .31 + math.cos(y * .35)):
            forest_dressing.distant_fir(far, rng, x, y, valley(x, y) - .1, rng.uniform(2.8, 5.4))
far.finish()

# ---------------------------------------------------------------- light, camera
world = bpy.data.worlds.new('V2_Blue_Hour')
scene.world = world
world.use_nodes = True
background = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
background.inputs['Color'].default_value = (.055, .095, .19, 1)
background.inputs['Strength'].default_value = .45
sun_data = bpy.data.lights.new('Moon', 'SUN')
sun_data.energy = 1.0
sun_data.color = (.48, .65, 1)
sun_data.angle = .15
sun = bpy.data.objects.new('Moon', sun_data)
stage_c.objects.link(sun)
sun.rotation_euler = (math.radians(35), math.radians(-20), math.radians(-30))
area_data = bpy.data.lights.new('Soft_Sky', 'AREA')
area_data.energy = 1400
area_data.shape = 'DISK'
area_data.size = 34
area_data.color = (.36, .54, 1)
area = bpy.data.objects.new('Soft_Sky', area_data)
stage_c.objects.link(area)
area.location = (9, 8, 22)

CAM_PITCH, CAM_YAW, CAM_DIST = math.radians(54), math.radians(10), 60
target = Vector((9.0, 10.8, 3.0))
offset = Vector((math.sin(CAM_YAW) * math.cos(CAM_PITCH), -math.cos(CAM_YAW) * math.cos(CAM_PITCH),
                 math.sin(CAM_PITCH))) * CAM_DIST
camera_data = bpy.data.cameras.new('Arena_Camera')
camera = bpy.data.objects.new('Arena_Camera', camera_data)
stage_c.objects.link(camera)
camera.location = target + offset
camera.rotation_euler = (-offset).to_track_quat('-Z', 'Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 41
camera_data.clip_end = 250
scene.camera = camera
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(ROOT / 'output/forest_arena/blender_preview.png')
scene.view_settings.view_transform = 'AgX'
scene['reference'] = 'User image #3 + author markup, 2026-11-02. v2: solid plateau, climbing road.'
scene['grid_mapping'] = 'Godot (x,z) = Blender (x,-y). Cell=2m; centre x=1+2*gx, y=19-2*gy.'
scene['terrace_heights'] = {'%d,%d' % k: round(v, 2) for k, v in heights.items()}
scene['road_rise_m'] = ROAD_RISE
for area_ui in bpy.context.screen.areas:
    if area_ui.type == 'VIEW_3D':
        area_ui.spaces.active.region_3d.view_perspective = 'CAMERA'

ARENA_INFO = {
    'lights': [(o.name, tuple(round(c, 2) for c in o.location)) for o in lantern_lights + [idol_light]],
    'camera': (tuple(round(c, 2) for c in camera.location), CAM_PITCH, CAM_YAW, camera_data.ortho_scale),
}
print('PLANE', round(PA,2), round(PB,3), round(PC,3))
print('BUILT v2:', len(scene.objects), 'objects;',
      sum(len(o.data.polygons) for o in scene.objects if o.type == 'MESH'), 'instance faces')
for gy in range(BOARD_H):
    print(' '.join('  ~~ ' if (gx, gy) in PATH_SET else '%5.1f' % heights[(gx, gy)]
                   for gx in range(BOARD_W)))
print(ARENA_INFO)
