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
valley_mat = material('V2_Valley_Peat', (.06, .115, .15))
wood = material('V2_Old_oak', (.17, .10, .055))
bark = material('V2_Birch_bark', (.61, .64, .56))
iron = material('V2_Forged_iron', (.095, .105, .105))
flame = material('V2_Amber_glass', (1, .33, .045), 5)
carving = material('V2_Idol_carvings', (.45, .32, .14))
needles = [material('V2_Fir_%02d' % i, c) for i, c in enumerate([
    (.022, .075, .08), (.03, .10, .10), (.045, .13, .12), (.06, .16, .14)])]
gold_leaves = [material('V2_Birch_leaf_%02d' % i, c) for i, c in enumerate([
    (.50, .30, .05), (.64, .41, .07), (.76, .52, .11)])]


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


class PaintBatch(Batch):
    """One vertex-coloured material: the paint survives glTF and Godot (unlike Blender nodes)."""

    def __init__(self, name, coll):
        super().__init__(name, [terrain_mat], coll)
        self.colors = []
        self.shade = lambda v: (.5, .5, .5)

    def add(self, vertices, faces, index=0, colors=None):
        super().add(vertices, faces, 0)
        self.colors.extend(colors if colors is not None else [self.shade(v) for v in vertices])

    def finish(self):
        obj = super().finish()
        attr = obj.data.color_attributes.new(name=COLOR_LAYER, type='BYTE_COLOR', domain='POINT')
        flat = []
        for c in self.colors:
            flat.extend((c[0], c[1], c[2], 1.0))
        attr.data.foreach_set('color', flat)
        return obj


def hash01(i, j, salt=0):
    """Stable pseudo-random value in [0, 1) for integer grid coordinates."""
    v = (i * 73856093) ^ (j * 19349663) ^ (salt * 83492791)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) & 0xFFFF) / 65536.0


SLATE = [(.14, .17, .22), (.18, .21, .27), (.23, .26, .31), (.27, .30, .33), (.22, .21, .21)]
MOSS = [(.15, .23, .07), (.21, .29, .10), (.27, .32, .12)]


def rock_chunk(batch, x, y, z, rx, ry, h, ground=None, tilt=(0.0, 0.0), sides=None,
               moss=.8, tint=None):
    """Chunky basalt block: chamfered top, mossy cap, darker toward the ground (fake AO)."""
    sides = sides or rng.choice((5, 6, 6, 7))
    ground = z if ground is None else ground
    phase = rng.uniform(0, math.tau)
    radii = [rng.uniform(.82, 1.14) for _ in range(sides)]
    base = tint or rng.choice(SLATE)
    base = mix(base, (.30, .32, .34), rng.uniform(-.1, .25))
    moss_col = rng.choice(MOSS)
    cap_drop = rng.uniform(.02, .09) * min(1.0, h)
    vertices, colors = [], []
    for level, scale in [(0, 1.0), (.82, .97), (1, .74)]:
        for i in range(sides):
            angle = phase + i * math.tau / sides
            vz = z + h * level - (cap_drop * (1 if i % 2 else -.4) if level == 1 else 0)
            if level == .82:
                vz -= rng.uniform(0, .06)
            vertices.append((x + math.cos(angle) * rx * radii[i] * scale + level * tilt[0],
                             y + math.sin(angle) * ry * radii[i] * scale + level * tilt[1], vz))
            occlusion = .5 + .5 * smoothstep(ground - .1, ground + .9, vz)
            strata = .92 + .1 * math.sin(vz * 4.7 + x * .9)
            c = tuple(v * occlusion * strata for v in base)
            if level == 1:
                c = mix(c, moss_col, moss * rng.uniform(.6, 1.0))
            elif level == .82 and rng.random() < moss * .45:
                c = mix(c, moss_col, rng.uniform(.25, .55))
            colors.append(c)
    faces = []                               # no bottom face: it always sits in the ground
    for ring in range(2):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((ring * sides + i, ring * sides + j, (ring + 1) * sides + j,
                          (ring + 1) * sides + i))
    faces.append(tuple(range(2 * sides, 3 * sides)))
    batch.add(vertices, faces, colors=colors)


def rock_stack(batch, x, y, z0, z1, r, ground=None, out=(0.0, 0.0), moss=.8):
    """A cliff pillar of 1-4 stacked blocks with small ledges, like broken basalt."""
    z = z0
    tint = rng.choice(SLATE)
    while z1 - z > .15:
        h = min(z1 - z, rng.uniform(1.0, 2.2) if z1 - z > 2.6 else rng.uniform(.6, 1.4))
        if z1 - z - h < .35:
            h = z1 - z
        rr = r * rng.uniform(.86, 1.06)
        sx, sy = rng.uniform(-.06, .06), rng.uniform(-.06, .06)
        top = z + h if z + h < z1 - .01 else z1 + rng.uniform(-.12, .08)
        rock_chunk(batch, x + sx + out[0] * rng.uniform(-.08, .05), y + sy + out[1] * rng.uniform(-.08, .05),
                   z, rr, rr * rng.uniform(.85, 1.1), top - z, ground=ground,
                   tilt=(out[0] * .05, out[1] * .05), moss=moss if top >= z1 - .2 else .35,
                   tint=mix(tint, rng.choice(SLATE), .3))
        z = top - .04


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


# Cavity: how far the surrounding ground rises above a vertex (0.6 m around).
# Darkening wall feet and hairpin insides gives depth without baked lighting.
cavity = []
R_CAV = 3
for j in range(ny + 1):
    row = []
    for i in range(nx + 1):
        z = zs[j][i]
        best = 0.0
        for dj in range(-R_CAV, R_CAV + 1, 1):
            jj = min(ny, max(0, j + dj))
            for di in range(-R_CAV, R_CAV + 1, 1):
                ii = min(nx, max(0, i + di))
                rise = (zs[jj][ii] - z) / (1 + .6 * math.hypot(di, dj) * STEP)
                if rise > best:
                    best = rise
        row.append(best)
    cavity.append(row)


def noise2(x, y):
    return (.45 * math.sin(1.32 * x + .62 * y) + .31 * math.sin(.86 * x - 1.04 * y)
            + .24 * math.cos(x * 2.64 + y * 1.51))


def turf(x, y, i=0, j=0):
    pasture, lichen, dry = (.15, .235, .07), (.27, .34, .12), (.40, .37, .15)
    hum = noise2(x, y)
    base = mix(pasture, lichen, .45 + .5 * hum)
    # Sparse sun-dried patches and dark clover, broken up per vertex.
    base = mix(base, dry, .45 * smoothstep(.55, .95, noise2(x * .7 + 13, y * .7 - 5)))
    base = mix(base, (.09, .16, .06), .35 * smoothstep(.5, .9, noise2(y * 1.3 - 2, x * 1.1 + 7)))
    jitter = .9 + .2 * hash01(i, j, 3)
    return tuple(c * jitter for c in base)


def paint(i, j):
    x, y = X0 + i * STEP, Y0 + j * STEP
    z = zs[j][i]
    gx = (zs[j][min(nx, i + 1)] - zs[j][max(0, i - 1)]) / (2 * STEP)
    gy = (zs[min(ny, j + 1)][i] - zs[max(0, j - 1)][i]) / (2 * STEP)
    slope = math.hypot(gx, gy)
    kind = kinds[j][i]
    rock = mix(SLATE[0], SLATE[3], .5 + .3 * math.sin(z * 3.1 + x * .4) + .15 * math.sin(y * 1.9))
    if kind == 'valley':
        color = mix((.045, .09, .11), (.07, .12, .12), .5 + .5 * math.sin(x * .7 + y * .5))
        color = mix(color, (.10, .14, .07), .4 * smoothstep(.3, .9, noise2(x * .4, y * .4)))
    elif kind == 'road' or kind == 'spur':
        _, d, _ = nearest(x, y)
        if kind == 'spur' and d > half_width(0) + .1:
            # Ramp banks: dark moss and peat, not bare rock.
            return mix((.13, .17, .08), (.06, .10, .12), smoothstep(1.4, 3.4, d))
        dirt = mix((.37, .275, .17), (.45, .34, .21), .5 + .5 * math.sin(x * 3.1 + y * 2.3))
        # Two trodden ruts, compacted crown, and loose gravel speckles.
        ruts = math.exp(-((abs(d) - .62) / .16) ** 2)
        dirt = mix(dirt, (.25, .19, .13), .42 * ruts)
        dirt = mix(dirt, (.45, .38, .27), .25 * math.exp(-(d / .25) ** 2))
        speck = hash01(i, j, 1)
        if speck > .86:
            dirt = mix(dirt, (.48, .45, .40), .55)
        elif speck < .1:
            dirt = mix(dirt, (.20, .15, .10), .5)
        verge = smoothstep(1.05, 1.42, d)
        color = mix(dirt, turf(x, y, i, j), verge)
        # A ragged strip of grass creeps onto the road edge.
        if .9 < d < 1.3 and hash01(i, j, 2) > .55:
            color = mix(color, turf(x, y, i, j), .7)
    else:
        color = turf(x, y, i, j)
    color = mix(color, rock, smoothstep(.9, 2.2, slope))
    occlusion = 1 - .5 * smoothstep(.05, 1.1, cavity[j][i])
    return tuple(c * occlusion for c in color)


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

# ---------------------------------------------------------------- basalt walls and cliffs
rocks = PaintBatch('Basalt_Cliffs', cliffs_c)
scree = PaintBatch('Scree_and_Boulders', cliffs_c)


def top_at(x, y):
    return height(x, y)[0]


def pebble(x, y, z, size, moss=.2):
    rock_chunk(scree, x, y, z - size * .25, size, size * rng.uniform(.7, 1.0),
               size * rng.uniform(.5, 1.0), ground=z, moss=moss, sides=rng.choice((5, 6)))


# Road walls: stacked blocks along both edges. Uphill: cut face; downhill: retaining wall.
for side in (-1, 1):
    travelled, prev = 0.0, None
    for i, (cx, cy) in enumerate(line):
        l = lengths[i]
        if l < L_ENTRY - .9 or l > lengths[-1] - .2:
            continue
        t = tangents[i]
        n = Vector((-t.y, t.x)) * side
        hw = half_width(l)
        p = Vector((cx, cy)) + n * (hw + .22)
        if prev is not None:
            travelled += (p - prev).length
        prev = p
        if travelled < rng.uniform(.36, .48):
            continue
        travelled = 0.0
        rz = road_z(l)
        beyond = Vector((cx, cy)) + n * (hw + .75)
        zt = top_at(beyond.x, beyond.y)
        if inside_distance(beyond.x, beyond.y) <= 0:
            continue
        if abs(zt - rz) >= .2:
            r = rng.uniform(.27, .36)
            if zt > rz:
                rock_stack(rocks, p.x, p.y, rz - .3, zt, r, ground=rz, out=(-n.x, -n.y))
            else:
                rock_stack(rocks, p.x, p.y, zt - .3, rz + rng.uniform(.0, .1), r, ground=zt,
                           out=(n.x, n.y), moss=.5)
        # Kerb stones and pebbles along the road edge.
        if rng.random() < .7:
            q = Vector((cx, cy)) + n * (hw - .14 + rng.uniform(-.06, .08))
            pebble(q.x, q.y, rz, rng.uniform(.07, .17), moss=.3)


# Outer cliff: stacked pillars all around the plateau, down into the valley.
def outline_points():
    x0, x1, y0, y1 = FOOT
    px0, px1, py0, py1 = IDOL_PAD
    edges = []
    for x in [x0 + k * .45 for k in range(int((x1 - x0) / .45) + 1)]:
        if not 1.4 < x < 4.6:                       # entry ramp gap
            edges.append((x, y0 + foot_noise(x, 3), (0, -1)))
        if not px0 + .2 < x < px1 - .2:
            edges.append((x, y1 + foot_noise(x, 4), (0, 1)))
    for y in [y0 + k * .45 for k in range(int((y1 - y0) / .45) + 1)]:
        edges.append((x0 + foot_noise(y, 1), y, (-1, 0)))
        edges.append((x1 + foot_noise(y, 2), y, (1, 0)))
    for x in [px0 + .3 + k * .45 for k in range(int((px1 - px0 - .3) / .45))]:
        edges.append((x, py1, (0, 1)))
    for y in [py0 + 1.3 + k * .45 for k in range(int((py1 - py0 - 1.3) / .45) + 1)]:
        edges.append((px0, y, (-1, 0)))
        edges.append((px1, y, (1, 0)))
    return edges


for x, y, (ox, oy) in outline_points():
    zt = top_at(x - ox * .45, y - oy * .45)
    zb = valley(x, y) - .7
    if zt - zb < 1:
        continue
    r = rng.uniform(.4, .58)
    px, py = x + ox * .18 + rng.uniform(-.06, .06), y + oy * .18 + rng.uniform(-.06, .06)
    rock_stack(rocks, px, py, zb, zt, r, ground=zb + .7, out=(ox, oy))
    # Talus: a lower ring of tumbled blocks, then loose boulders on the slope below.
    if rng.random() < .65:
        r2 = rng.uniform(.4, .75)
        rock_stack(rocks, px + ox * .6, py + oy * .6, zb, zb + .7 + rng.uniform(.6, 2.2), r2,
                   ground=zb + .7, out=(ox, oy), moss=.6)
    if rng.random() < .3:
        bx, by = px + ox * rng.uniform(1.2, 2.2), py + oy * rng.uniform(1.2, 2.2)
        pebble(bx + rng.uniform(-.3, .3), by + rng.uniform(-.3, .3), valley(bx, by),
               rng.uniform(.25, .55), moss=.6)

# Steps between terraces of different heights: a continuous low wall of blocks.
for x0, y0, x1, y1, h, s, gx, gy in cells:
    for dgx, dgy in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
        other = heights.get((gx + dgx, gy + dgy))
        if other is None or other >= h - .05:
            continue                       # only the higher cell builds the wall
        t = rng.uniform(.05, .25)
        while t < .98:
            if dgx:
                x, y = (x1 if dgx > 0 else x0), y0 + 2 * t
            else:
                x, y = x0 + 2 * t, (y0 if dgy > 0 else y1)
            # Skip the stretch that the road channel already cut away.
            if nearest(x, y)[1] > half_width(0) + .25:
                r = rng.uniform(.27, .35)
                rock_stack(rocks, x + rng.uniform(-.06, .06), y + rng.uniform(-.06, .06),
                           other - .2, h + rng.uniform(-.06, .05), r, ground=other)
            t += rng.uniform(.24, .32)

# A few boulders on terrace rims (never in the cell centres where towers stand).
for (gx, gy), h in heights.items():
    cx, cy = cell_centre(gx, gy)
    for _ in range(rng.randint(0, 2)):
        angle = rng.uniform(0, math.tau)
        rad = rng.uniform(.72, .9)
        bx, by = cx + math.cos(angle) * rad, cy + math.sin(angle) * rad
        if height(bx, by)[1] == 'top':
            pebble(bx, by, top_at(bx, by), rng.uniform(.1, .22), moss=.7)

rocks.finish()
scree.finish()

# ---------------------------------------------------------------- vegetation on the terraces
greens = PaintBatch('Shrubs_Grass_Flowers', cliffs_c)


def bush(x, y, z, radius):
    dark, light = rng.choice([((.04, .10, .04), (.13, .24, .07)), ((.05, .11, .05), (.20, .27, .08)),
                              ((.07, .10, .04), (.30, .28, .09))])
    greens.shade = lambda v: mix(dark, light, smoothstep(z - .05, z + radius * 1.6, v[2]))
    forest_dressing.leaf_cluster(greens, rng, (x, y, z + radius * .55), radius, 0)


def tuft(x, y, z, dry=False):
    tip = (.42, .40, .17) if dry else rng.choice([(.27, .37, .11), (.33, .40, .14)])
    for _blade in range(rng.randint(4, 7)):
        bx, by = x + rng.uniform(-.1, .1), y + rng.uniform(-.1, .1)
        lean = (rng.uniform(-.1, .1), rng.uniform(-.1, .1))
        a = rng.uniform(0, math.pi)
        w = .025
        greens.add([(bx - math.cos(a) * w, by - math.sin(a) * w, z - .02),
                    (bx + math.cos(a) * w, by + math.sin(a) * w, z - .02),
                    (bx + lean[0], by + lean[1], z + rng.uniform(.13, .3))],
                   [(0, 1, 2)], colors=[(.05, .09, .03), (.05, .09, .03), tip])


def flower_patch(x, y, z):
    petal = rng.choice([(.85, .80, .55), (.60, .66, .90), (.90, .62, .45)])
    for _ in range(rng.randint(3, 6)):
        fx, fy = x + rng.uniform(-.2, .2), y + rng.uniform(-.2, .2)
        fz = z + rng.uniform(.06, .14)
        s = .035
        greens.add([(fx - s, fy, fz), (fx + s * .5, fy - s, fz), (fx + s * .5, fy + s, fz),
                    (fx, fy, fz - .1)], [(0, 1, 2), (0, 3, 1), (1, 3, 2), (2, 3, 0)],
                   colors=[petal, petal, petal, (.08, .14, .05)])


for _ in range(2400):
    x, y = rng.uniform(FOOT[0], FOOT[1]), rng.uniform(FOOT[2], FOOT[3])
    z, kind = height(x, y)
    if kind != 'top' or inside_distance(x, y) < .4:
        continue
    i_near, d, _ = nearest(x, y)
    from_wall = d - half_width(lengths[i_near])
    fx = (x - 1) / 2 % 1 if 0 < x < 18 else 0.0
    fy = (19 - y) / 2 % 1 if 0 < y < 20 else 0.0
    rim = min(fx, 1 - fx, fy, 1 - fy)            # 0 at a cell border, .5 in the centre
    roll = rng.random()
    if from_wall < .8 and roll < .5:
        bush(x, y, z, rng.uniform(.16, .3))
    elif rim < .22 and roll < .35:
        bush(x, y, z, rng.uniform(.12, .22))
    elif roll < .75:
        tuft(x, y, z, dry=noise2(x * .7 + 13, y * .7 - 5) > .55)
    elif roll < .83:
        flower_patch(x, y, z)

# Ferns and undergrowth at the cliff foot, under the first row of trees.
for _ in range(260):
    x, y = rng.uniform(-6.5, 24.5), rng.uniform(-14, 28)
    if inside_distance(x, y) > -.6 or inside_distance(x, y) < -4.5:
        continue
    if abs(x - 3) < 2.2 and y < 0:
        continue
    z = valley(x, y)
    for frond in range(rng.randint(5, 8)):
        a = frond * math.tau / 7 + rng.uniform(-.3, .3)
        length = rng.uniform(.35, .6)
        tip = (x + math.cos(a) * length, y + math.sin(a) * length, z + .12)
        mid = (x + math.cos(a) * length * .5, y + math.sin(a) * length * .5, z + .3)
        side = (-math.sin(a) * .09, math.cos(a) * .09)
        greens.add([(x, y, z), (mid[0] + side[0], mid[1] + side[1], mid[2]), tip,
                    (mid[0] - side[0], mid[1] - side[1], mid[2])],
                   [(0, 1, 2), (0, 2, 3)],
                   colors=[(.03, .07, .04), (.09, .19, .08), (.15, .25, .09), (.09, .19, .08)])
greens_obj = greens.finish()

# ---------------------------------------------------------------- lanterns, idol, lights


def point_light(name, position, color, energy, radius):
    data = bpy.data.lights.new(name, 'POINT')
    data.energy = energy
    data.color = color
    data.shadow_soft_size = radius
    data.use_shadow = True
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


TOP_APEX = 16 + 3 * math.pi / 2
BOTTOM_APEX = 16 + 3 * math.pi + 12 + 3 * math.pi / 2
for u, side in [(-1.6, -1), (6.0, 1), (13.5, -1), (TOP_APEX, 1), (29.0, 1), (36.5, -1),
                (BOTTOM_APEX, -1), (51.5, 1), (59.0, -1)]:
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
fire_lights = []
for bx, by in [(13.75, 22.55), (16.25, 22.55)]:
    column(brazier, bx, by, iz + .02, .36, .36, .24, index=0)
    column(brazier, bx, by, iz + .25, .26, .26, .18, index=1)
    for k in range(5):                      # tongues of flame
        a = k * math.tau / 5
        column(brazier, bx + math.cos(a) * .08, by + math.sin(a) * .08, iz + .4, .07, .06,
               rng.uniform(.25, .45), index=2)
    fire_lights.append(point_light('Idol_Fire', (bx, by, iz + .9), (1, .35, .06), 300, .5))
brazier.finish()
idol_light = fire_lights[0]
# Worn flagstones in front of the idol, where the road ends.
flags = PaintBatch('Idol_Flagstones', props_c)
for fx in [-1.1, -.4, .3, 1.0]:
    for fy in [-1.3, -.6, .1]:
        x, y = ix + fx + rng.uniform(-.06, .06), iy + fy + rng.uniform(-.06, .06)
        rock_chunk(flags, x, y, iz - .12, .3, .28, .15, ground=iz - .2, moss=.25,
                   sides=rng.choice((5, 6)), tint=SLATE[3])
flags.finish()

# ---------------------------------------------------------------- forest (outside the plateau only)
api = SimpleNamespace(Batch=Batch, beam=beam, material=material, wood=wood, bark=bark,
                      needles=needles, gold_leaves=gold_leaves, forest=forest_c)
spruce = [forest_dressing.fir_mesh(api, rng, k) for k in range(3)]
birch = [forest_dressing.birch_mesh(api, rng, k) for k in range(2)]


def plant(x, y, scale, birch_chance=.2, z=None):
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


# ---------------------------------------------------------------- fireflies and valley mist
firefly_mat = material('V2_Firefly', (.95, .85, .35), 9)
flies = Batch('Fireflies', [firefly_mat], props_c)
for _ in range(36):
    x, y = rng.uniform(-4, 22), rng.uniform(-6, 25)
    z = top_at(x, y) if inside_distance(x, y) > 0 else valley(x, y)
    z += rng.uniform(.5, 1.8)
    s = rng.uniform(.022, .034)
    flies.add([(x + s, y, z), (x - s, y, z), (x, y + s, z), (x, y - s, z), (x, y, z + s), (x, y, z - s)],
              [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)])
flies.finish()

mist_mat = material('V2_Valley_Mist', (.40, .50, .70), .18)
mist_shader = next(n for n in mist_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
mist_shader.inputs['Alpha'].default_value = .042
mist_mat.surface_render_method = 'BLENDED'
mist_mat.use_backface_culling = False
mist = Batch('Valley_Mist', [mist_mat], forest_c)
placed = 0
while placed < 34:
    x, y = rng.uniform(-14, 32), rng.uniform(-16, 34)
    radius = rng.uniform(3.0, 6.0)
    aspect = rng.uniform(1.3, 1.9)
    # Keep every wisp in the valley: its whole ellipse stays clear of the plateau.
    if inside_distance(x, y) > -(radius * aspect * .75 + 1.0):
        continue
    placed += 1
    turn = rng.uniform(0, math.pi)
    z = valley(x, y) + rng.uniform(.8, 1.9)
    for layer, (scale, lift) in enumerate([(1.0, 0), (.84, .18), (.68, .36), (.52, .54), (.36, .72)]):
        ring = []
        for k in range(18):
            a = k * math.tau / 18
            wob = 1 + .14 * math.sin(a * 3 + turn * 5)
            px = math.cos(a) * radius * scale * aspect * wob
            py = math.sin(a) * radius * scale * wob
            ring.append((x + px * math.cos(turn) - py * math.sin(turn),
                         y + px * math.sin(turn) + py * math.cos(turn), z + lift))
        mist.add(ring + [(x, y, z + lift)], [(k, (k + 1) % 18, 18) for k in range(18)])
mist_obj = mist.finish()
mist_obj.visible_shadow = False

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
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.eevee.use_raytracing = True
scene.eevee.taa_render_samples = 96
scene['reference'] = 'User image #3 + author markup, 2026-11-02. v2: solid plateau, climbing road.'
scene['grid_mapping'] = 'Godot (x,z) = Blender (x,-y). Cell=2m; centre x=1+2*gx, y=19-2*gy.'
scene['terrace_heights'] = {'%d,%d' % k: round(v, 2) for k, v in heights.items()}
scene['road_rise_m'] = ROAD_RISE
for area_ui in bpy.context.screen.areas:
    if area_ui.type == 'VIEW_3D':
        area_ui.spaces.active.region_3d.view_perspective = 'CAMERA'

ARENA_INFO = {
    'lights': [(o.name, tuple(round(c, 2) for c in o.location)) for o in lantern_lights + fire_lights],
    'camera': (tuple(round(c, 2) for c in camera.location), CAM_PITCH, CAM_YAW, camera_data.ortho_scale),
}
print('PLANE', round(PA,2), round(PB,3), round(PC,3))
print('BUILT v2:', len(scene.objects), 'objects;',
      sum(len(o.data.polygons) for o in scene.objects if o.type == 'MESH'), 'instance faces')
for gy in range(BOARD_H):
    print(' '.join('  ~~ ' if (gx, gy) in PATH_SET else '%5.1f' % heights[(gx, gy)]
                   for gx in range(BOARD_W)))
print(ARENA_INFO)
