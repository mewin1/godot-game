"""Continuous basalt shelves for the forest battlefield (Blender metres)."""

import math
import random


# The two inner shelves end one row early at their respective hairpin bends.
# First and last build centres in each direction protect the usable surface.
SHELVES = (
    ('West', -2.00, 1.43, -1.48, 28.50, 3.0, (0, 0, 0, 27)),
    ('Heather', 4.52, 10.48, -1.48, 25.49, 5.3, (6, 9, 0, 24)),
    ('Juniper', 13.52, 19.48, 1.51, 28.50, 8.5, (15, 18, 3, 27)),
    ('East', 22.55, 26.10, -1.48, 28.50, 10.0, (24, 24, 0, 27)),
)
COLOR_LAYER = 'Lichen_and_slate'
PAD_HALF_WIDTH = 1.20


def mix(left, right, amount):
    amount = max(0.0, min(1.0, amount))
    return tuple(a + (b - a) * amount for a, b in zip(left, right))


def turf_color(x, y, edge_distance):
    # Coherent patches across the flat planting surface. Colour is stored in
    # the mesh so the same detail survives glTF and Godot Compatibility.
    pasture = (.182, .226, .108)
    pale_lichen = (.280, .300, .171)
    shale = (.225, .258, .240)
    hummocks = (.45 * math.sin(1.32 * x + .62 * y)
                + .31 * math.sin(.86 * x - 1.04 * y + .8 * math.cos(y * .36))
                + .24 * math.cos(x * 2.64 + y * 1.51))
    mottled = mix(pasture, pale_lichen, .45 + .56 * hummocks)
    veins = abs(math.sin(.63 * x + 1.10 * y + 1.24 * math.sin(y * .61)))
    return mix(mottled, shale, (.57 - edge_distance * .56) * veins)


def shelf_geometry(bounds, seed):
    """Return a closed indexed mesh and its per-face, per-corner linear colours."""
    name, xmin, xmax, ymin, ymax, height, centres = bounds
    west, east, south, north = centres
    rng = random.Random(seed)
    nx = math.ceil((xmax - xmin) / .63)
    ny = math.ceil((ymax - ymin) / .68)
    vertices, faces, colours = [], [], []

    def face(indices, tints):
        faces.append(tuple(indices))
        colours.append(tints)

    # Sample the whole top, including the rounded corners, in a single grid.
    # Ring vertices will reuse these exact perimeter indices: no cracks.
    top_colours = []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = xmin + (xmax - xmin) * i / nx
            y = ymin + (ymax - ymin) * j / ny
            on_side = i == 0 or i == nx
            on_end = j == 0 or j == ny
            if on_side:
                sign = -1 if i == 0 else 1
                corner = max(0.0, 1.0 - min(y - ymin, ymax - y) / .65)
                x += sign * (.081 * math.sin(y * .68 + seed) + rng.uniform(-.044, .044) - .22 * corner)
                x = min(x, west - 1.24) if i == 0 else max(x, east + 1.24)
            else:
                x += rng.uniform(-.17, .17)
            if on_end:
                sign = -1 if j == 0 else 1
                corner = max(0.0, 1.0 - min(x - xmin, xmax - x) / .65)
                y += sign * (.049 * math.sin(x * 1.78) + rng.uniform(-.032, .032) - .17 * corner)
                y = min(y, south - 1.24) if j == 0 else max(y, north + 1.24)
            else:
                y += rng.uniform(-.16, .16)
            clearance = min(x - xmin, xmax - x, y - ymin, ymax - y)
            vertices.append((x, y, height))
            top_colours.append(turf_color(x, y, clearance))

    stride = nx + 1
    for j in range(ny):
        for i in range(nx):
            a = j * stride + i
            b, c, d = a + 1, a + stride + 1, a + stride
            pair = ((a, b, d), (b, c, d)) if rng.random() < .5 else ((a, b, c), (a, c, d))
            for tri in pair:
                face(tri, [top_colours[index] for index in tri])

    rim = list(range(nx))
    rim.extend(j * stride + nx for j in range(ny))
    rim.extend(ny * stride + i for i in range(nx, 0, -1))
    rim.extend(j * stride for j in range(ny, 0, -1))
    count = len(rim)
    # Adjacent strata share complete rings. Irregular joints wander slightly
    # downslope and intersect broader horizontal bedding planes.
    joints = [False] * count
    k = rng.randint(0, 3)
    while k < count:
        joints[k] = True
        k += rng.randint(2, 5)
    profiles = []
    for k, index in enumerate(rim):
        prev = vertices[rim[k - 1]]
        nxt = vertices[rim[(k + 1) % count]]
        length = math.hypot(nxt[0] - prev[0], nxt[1] - prev[1])
        normal = ((nxt[1] - prev[1]) / length, (prev[0] - nxt[0]) / length)
        profiles.append((normal, rng.uniform(.65, 1.12), rng.uniform(-.3, .3), rng.uniform(.0, .22)))

    # Depth, wall displacement and lip tint for each successive stratum.
    bottom = -5.35
    levels = ((.025, -.01), (.05, .10), (.08, .07), (.28, -.035),
              (.34, .10), (.37, -.09), (.66, .02), (.69, -.08), (.93, .09), (1.0, .04))
    previous = rim
    for row, (depth, shift) in enumerate(levels):
        ring = []
        for k, index in enumerate(rim):
            x, y, _ = vertices[index]
            normal, stretch, lean, irregular = profiles[k]
            notch = (-.31 if joints[k] else .08) * math.sin(math.pi * min(1.0, depth * 2.1))
            offset = shift * stretch + notch
            drift = lean * math.sin(.4 + depth * 2)
            distance = depth * (height - bottom)
            if row == 0:
                distance = .12 + irregular * .47
            elif row == 1:
                distance = .23 + irregular * .55
            elif row < len(levels) - 1:
                distance += .19 * math.sin(.88 * y + .64 * x + .56 * row) + irregular * .22
            ring.append(len(vertices))
            vertices.append((x + normal[0] * offset - normal[1] * drift,
                             y + normal[1] * offset + normal[0] * drift, height - distance))

        for k in range(count):
            n = (k + 1) % count
            # Upper ring is CCW. Face order gives outward wall normals.
            quad = (previous[k], ring[k], ring[n], previous[n])
            x, y, _ = vertices[rim[k]]
            stone = mix((.112, .138, .189), (.252, .279, .305),
                        .45 + .30 * math.sin(.72 * y + x * .96) + .17 * math.sin(k * 1.72))
            if row == 0:
                green = turf_color(x, y, 0)
                tint = mix(green, stone, .27)
            else:
                tint = mix(stone, (.115, .141, .173), .38 if joints[k] else .08)
                if row in (2, 4, 7):
                    tint = mix(tint, (.262, .280, .298), .27)
                if row == 1:
                    tint = mix(tint, (.194, .226, .131), .48 + .28 * math.sin(k * .56))
            face(quad, [tint] * 4)
        previous = ring

    # Keep bottom closed without an n-gon, including concave perimeter facets.
    centre = len(vertices)
    vertices.append(((xmin + xmax) / 2, (ymin + ymax) / 2, bottom))
    for k in range(count):
        face((previous[(k + 1) % count], previous[k], centre), [(.09, .112, .142)] * 3)
    return vertices, faces, colours


def build_relief(api):
    """Create one watertight, editable mesh for each terrain terrace."""
    material = api.material('Slate, moss and lichen', (1.0, 1.0, 1.0))
    shader = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    paint = material.node_tree.nodes.new('ShaderNodeVertexColor')
    paint.layer_name = COLOR_LAYER
    material.node_tree.links.new(paint.outputs['Color'], shader.inputs['Base Color'])
    objects = []
    for order, shelf in enumerate(SHELVES):
        verts, faces, colours = shelf_geometry(shelf, 82 + order * 17)
        batch = api.Batch('Mesa_' + shelf[0], [material], api.cliffs)
        batch.vertices, batch.faces, batch.indices = verts, faces, [0] * len(faces)
        obj = batch.finish()
        attr = obj.data.color_attributes.new(name=COLOR_LAYER, type='BYTE_COLOR', domain='CORNER')
        rgba = [value for row in colours for color in row for value in (*color, 1.0)]
        attr.data.foreach_set('color', rgba)
        obj['top_z_m'] = shelf[5]
        objects.append(obj)
    return objects
