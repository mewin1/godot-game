"""Forest boundary and valley backdrop for the standalone mountain arena (Blender)."""
import math
import random

import bpy


def ease_clamped(value):
    value = min(1.0, max(0.0, value))
    return value * value * (3.0 - 2.0 * value)


def valley_height(x, y):
    # One continuous surface extends under the cliff foot and beneath every tree.
    floor = -7.1 + 0.43 * math.sin(x * 0.31 + y * 0.19) + 0.38 * math.cos(y * 0.36)
    bank_length = ease_clamped((y + 7.0) / 5.0) * ease_clamped((37.0 - y) / 6.0)
    for middle, rise, width in [(-3.9, 8.0, 4.3), (27.8, 13.7, 4.9)]:
        distance = (x - middle - 0.30 * math.sin(y * 0.43)) / width
        floor += bank_length * rise * math.exp(-distance ** 4)
    # Distant rocky spurs give the forest a skyline above the valley.
    for ridge_x, ridge_y, rise, width, depth in [
        (-17.0, 21.0, 4.8, 8.0, 16.0),
        (-9.0, 45.0, 10.0, 17.0, 7.3),
        (19.0, 53.0, 12.0, 21.0, 9.0),
        (44.0, 33.0, 9.0, 8.0, 17.0),
    ]:
        distance = ((x - ridge_x) / width) ** 2 + ((y - ridge_y) / depth) ** 2
        floor += rise * math.exp(-distance)
    return floor


def tree_base_z(x, y):
    # Plant on the actual terrain triangle, including on the steep banks.
    left = -53 + 2 * math.floor((x + 53) / 2)
    front = -45 + 2 * math.floor((y + 45) / 2)
    u = (x - left) / 2
    v = (y - front) / 2
    low = valley_height(left, front)
    high = valley_height(left + 2, front + 2)
    if u > v:
        return low * (1 - u) + valley_height(left + 2, front) * (u - v) + high * v
    return low * (1 - v) + valley_height(left, front + 2) * (v - u) + high * u


def build_valley(api):
    peat = api.material('Valley_Blue_Peat', (0.065, 0.125, 0.165))
    terrain = api.Batch('Forest_Valley', [peat], api.forest)
    # The camera sees past the arena in every direction. Avoid exposed plane edges.
    xs = range(-53, 79, 2)
    ys = range(-45, 85, 2)
    verts = [(x, y, valley_height(x, y)) for y in ys for x in xs]
    faces = []
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            index = j * len(xs) + i
            back = index + len(xs)
            faces.extend([(index, index + 1, back + 1), (index, back + 1, back)])
    terrain.add(verts, faces, 0)
    obj = terrain.finish()
    for face in obj.data.polygons:
        face.use_smooth = True


def plume(batch, origin, angle, length, width, drop, index):
    """Faceted, ridged evergreen spray with a turned-up point and serrated edges."""
    x, y, z = origin
    ca = math.cos(angle)
    sa = math.sin(angle)
    verts = []
    for reach, spread, fall, spine in [
        (0.0, 0.05, 0.0, 0.22),
        (0.28, 0.95, 0.16, 0.9),
        (0.56, 0.72, 0.60, 0.65),
        (0.74, 0.89, 0.83, 0.38),
        (1.0, 0.025, 0.91, 0.05),
    ]:
        cx = x + length * reach * ca
        cy = y + length * reach * sa
        cz = z - drop * fall
        for lateral, lift in [(1.0, -0.16), (0.0, spine), (-1.0, -0.13), (0.0, -0.3)]:
            offset = width * spread * lateral
            verts.append((cx - sa * offset, cy + ca * offset, cz + width * lift))
    faces = []
    for ring in range(4):
        for side in range(4):
            nxt = (side + 1) % 4
            faces.append((4 * ring + side, 4 * ring + nxt, 4 * (ring + 1) + nxt,
                          4 * (ring + 1) + side))
    faces.append((16, 17, 18, 19))
    batch.add(verts, faces, index)


def shared_mesh(batch):
    template = batch.finish()
    mesh = template.data
    bpy.data.objects.remove(template, do_unlink=True)
    return mesh


def fir_mesh(api, rng, index):
    batch = api.Batch('Spruce_Boughs_%d' % index, [api.wood, *api.needles], api.forest)
    api.beam(batch, (0, 0, -0.12), (0, 0, 4.65), 0.075, sides=6)
    for tier in range(8):
        tier_z = 0.94 + tier * 0.52
        radius = (1.0 - tier / 8.8) ** 0.8 * 1.23
        count = max(4, 7 - tier // 3)
        turn = 2.39 * tier + rng.uniform(-0.27, 0.27)
        for arm in range(count):
            angle = turn + arm * math.tau / count + rng.uniform(-0.11, 0.11)
            length = radius * rng.uniform(0.88, 1.18)
            height = tier_z + rng.uniform(-0.10, 0.10)
            fall = 0.54 * length
            shade = 1 + min(len(api.needles) - 1, (tier + index) // 3)
            plume(batch, (0, 0, height), angle, length, length * 0.28, fall, shade)
            for side in [-1, 1]:
                fork = length * (0.36 if side == 1 else 0.47)
                root = (fork * math.cos(angle), fork * math.sin(angle), height - 0.10)
                plume(batch, root, angle + 0.55 * side, length * 0.58, length * 0.17,
                      fall * 0.93, shade)
    # Slender central leader rises above the eight broad branch whorls.
    for tip in range(4):
        plume(batch, (0, 0, 4.61), tip * math.pi / 2, 0.23, 0.13, -0.39,
              len(api.needles))
    return shared_mesh(batch)


def leaf_cluster(batch, rng, center, radius, index):
    """Irregular almond-shaped cluster with sloping facets and compact highlights."""
    x, y, z = center
    sides = 7
    turn = rng.random() * math.tau
    verts = [(x, y, z - radius * 0.63)]
    for height, spread in [(-0.13, 0.96), (0.38, 0.79)]:
        for side in range(sides):
            angle = turn + (side + height * 0.5) * math.tau / sides
            r = radius * spread * rng.uniform(0.85, 1.14)
            verts.append((x + r * math.cos(angle), y + r * math.sin(angle) * 0.73,
                          z + radius * height))
    verts.append((x + radius * 0.16, y, z + radius * 0.69))
    faces = []
    for side in range(sides):
        nxt = (side + 1) % sides
        faces.extend([(0, 1 + nxt, 1 + side), (1 + side, 1 + nxt, 8 + nxt, 8 + side),
                      (8 + side, 8 + nxt, 15)])
    batch.add(verts, faces, index)


def birch_mesh(api, rng, variant):
    batch = api.Batch('Silver_Birch_%d' % variant, [api.bark, api.wood, *api.gold_leaves],
                      api.forest)
    for stem, (ox, oy, height) in enumerate([(-0.09, 0.04, 4.4), (0.19, -0.04, 3.55)]):
        base = (ox, oy, -0.14)
        fork = (ox + 0.14 * stem, oy + 0.11, height * 0.47)
        tip = (fork[0] + 0.18 * (-1 if stem == 0 else 1), fork[1] - 0.09, height)
        api.beam(batch, base, fork, 0.061, sides=6)
        api.beam(batch, fork, tip, 0.037, sides=6)
        for mark in range(5):
            t = rng.uniform(0.2, 0.9)
            start = tuple(a + t * (b - a) for a, b in zip(base, fork))
            api.beam(batch, start, (start[0], start[1], start[2] + 0.034), 0.062, 1, 6)
        for arm in range(10):
            angle = arm * 2.399 + stem + variant
            u = (arm + 0.6) / 10
            start = (fork[0], fork[1], height * (0.29 + 0.61 * u))
            length = (0.91 - 0.57 * u) * rng.uniform(0.82, 1.22)
            end = (start[0] + length * math.cos(angle), start[1] + length * math.sin(angle),
                   start[2] + 0.53)
            api.beam(batch, start, end, 0.024, 0, 5)
            for leaf in range(4):
                center = (end[0] + rng.uniform(-0.25, 0.25), end[1] + rng.uniform(-0.2, 0.2),
                          end[2] + leaf * 0.10)
                leaf_cluster(batch, rng, center, rng.uniform(0.20, 0.33),
                             2 + rng.randrange(len(api.gold_leaves)))
    return shared_mesh(batch)


def instance(api, rng, mesh, name, x, y, scale):
    obj = bpy.data.objects.new(name, mesh)
    api.forest.objects.link(obj)
    obj.location = (x, y, tree_base_z(x, y) - 0.12)
    obj.scale = (scale, scale, scale * rng.uniform(0.95, 1.11))
    obj.rotation_euler.z = rng.uniform(0.0, math.tau)


def distant_fir(batch, rng, x, y, z, height):
    # Distant silhouettes merge in the blue air. The outline still has separate limbs.
    width = height * rng.uniform(0.18, 0.25)
    phase = rng.uniform(0, math.tau)
    for tier in range(4):
        crown_z = z + height * (0.22 + 0.17 * tier)
        radius = width * (1 - tier * 0.22)
        sides = 10
        verts = []
        for j in range(sides):
            angle = phase + 0.31 * tier + j * math.tau / sides
            radial = radius * (1 if j % 2 == 0 else 0.58)
            verts.append((x + radial * math.cos(angle), y + radial * math.sin(angle),
                          crown_z - (0.10 if j % 2 == 0 else 0.03) * height))
        verts.append((x, y, crown_z + height * 0.26))
        faces = [(j, (j + 1) % sides, sides) for j in range(sides)]
        batch.add(verts, faces, tier // 2)


def build_forest(api):
    rng = random.Random(30823)
    build_valley(api)
    spruce = [fir_mesh(api, rng, variant) for variant in range(3)]
    birch = [birch_mesh(api, rng, variant) for variant in range(2)]
    for side in [-1, 1]:
        edge = -2 if side < 0 else 26
        for row, step in [(0, 1.38), (1, 1.97)]:
            y = -3.4 + rng.random() * 1.1
            while y < 32:
                # The root and full crown stay outside the two outer building columns.
                x = edge + side * (2.23 + 1.56 * row + rng.uniform(0.0, 0.56))
                scale = rng.uniform(0.53, 0.82) + row * 0.16
                if y < 2.4:
                    scale *= 0.66
                if rng.random() < (0.15 if row == 0 else 0.10):
                    instance(api, rng, rng.choice(birch), 'Golden_Birch', x, y, scale)
                else:
                    instance(api, rng, rng.choice(spruce), 'Forest_Spruce', x, y, scale)
                y += step * rng.uniform(0.83, 1.45)

    # A broken treeline behind the island; the pass to the right stays in open view.
    for x in [-1.5, 0.4, 1.5, 3.0, 5.2, 6.4, 8.3, 10.0, 11.2, 13.4, 14.8, 16.5]:
        y = rng.uniform(33.8, 36.0)
        instance(api, rng, rng.choice(spruce), 'Ravine_Spruce', x, y, rng.uniform(0.6, 0.9))

    distance_shades = [
        api.material('Forest_Distant_Deep', (0.035, 0.105, 0.16), 0.12),
        api.material('Forest_Distant_Blue', (0.069, 0.151, 0.223), 0.12),
    ]
    far = api.Batch('Distant_Forest_Silhouettes', distance_shades, api.forest)
    for row in range(30):
        for column in range(40):
            x = -25 + column * 2.1 + rng.uniform(-0.7, 0.7)
            y = -16 + row * 2.1 + rng.uniform(-0.7, 0.7)
            if -7.8 < x < 32 and -7.0 < y < 35:
                continue
            if 0 < x < 21 and y < 0:
                continue
            # Small glades keep the hills legible through the surrounding treeline.
            density = 0.46 + 0.24 * math.sin(x * 0.31 + math.cos(y * 0.35))
            if rng.random() < density:
                distant_fir(far, rng, x, y, tree_base_z(x, y) - 0.1, rng.uniform(2.7, 5.3))
    far.finish()
