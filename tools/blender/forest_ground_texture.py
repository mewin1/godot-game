"""High-resolution ground texture for the forest arena (numpy, runs inside Blender).

The terrain mesh is a 0.2 m heightfield; vertex colours on it are far too coarse for
gravel or a crisp road edge. This paints a top-down albedo image (~100 px per metre)
from the same road line and terrain classes. Colours are authored in linear space and
written as sRGB. Ambient occlusion stays in the mesh vertex colours (multiplied in).
"""
import numpy as np

KIND_VALLEY, KIND_ROAD, KIND_TOP, KIND_SPUR = 0, 1, 2, 3


def hash01(ix, iy, seed):
    h = (ix.astype(np.int64) * 73856093) ^ (iy.astype(np.int64) * 19349663) ^ (seed * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65536.0


def value_noise(x, y, scale, seed):
    xs, ys = x / scale, y / scale
    ix, iy = np.floor(xs), np.floor(ys)
    fx, fy = xs - ix, ys - iy
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    ix, iy = ix.astype(np.int64), iy.astype(np.int64)
    a = hash01(ix, iy, seed)
    b = hash01(ix + 1, iy, seed)
    c = hash01(ix, iy + 1, seed)
    d = hash01(ix + 1, iy + 1, seed)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy


def fbm(x, y, scale, seed, octaves=4):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * value_noise(x, y, scale / (2 ** o), seed + 17 * o)
        norm += amp
        amp *= .5
    return total / norm


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def lerp(c0, c1, t):
    """Blend two colours (3-tuples or (...,3) arrays) by weight array t."""
    c0 = np.asarray(c0, dtype=np.float32)
    c1 = np.asarray(c1, dtype=np.float32)
    return c0 + (c1 - c0) * t[..., None]


def cells(x, y, size, seed, density, rmin, rmax):
    """Scattered round stones: mask (soft edge), dome shading and a per-stone random."""
    xs, ys = x / size, y / size
    ix, iy = np.floor(xs).astype(np.int64), np.floor(ys).astype(np.int64)
    fx, fy = xs - ix, ys - iy
    cx = .25 + .5 * hash01(ix, iy, seed)
    cy = .25 + .5 * hash01(ix, iy, seed + 1)
    r = rmin + (rmax - rmin) * hash01(ix, iy, seed + 2)
    pick = hash01(ix, iy, seed + 3)
    d = np.hypot((fx - cx) * (1 + .3 * (pick - .5)), fy - cy)
    mask = smooth(r, r - .07, d) * (hash01(ix, iy, seed + 4) < density)
    dome = np.clip(1 - d / np.maximum(r, 1e-3), 0, 1)
    return mask, dome, pick


def road_distance(x, y):
    """Distance to the road centre line (same pieces as build_forest_arena_v2)."""
    def vseg(sx, y0, y1):
        dy = np.maximum(np.maximum(y0 - y, 0), y - y1)
        return np.hypot(x - sx, dy)

    def half_arc(cx, cy, r, upper):
        inside = (y >= cy) if upper else (y <= cy)
        on_arc = np.abs(np.hypot(x - cx, y - cy) - r)
        ends = np.minimum(np.hypot(x - (cx - r), y - cy), np.hypot(x - (cx + r), y - cy))
        return np.where(inside, on_arc, ends)

    return np.minimum.reduce([vseg(3, -14, 16), half_arc(6, 16, 3, True), vseg(9, 4, 16),
                              half_arc(12, 4, 3, False), vseg(15, 4, 22.6)])


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= .0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - .055)


def paint_rows(x, y, kind, slope):
    """Albedo (linear RGB) for world coordinates x, y; kind/slope sampled from the mesh grid."""
    big = fbm(x, y, 2.2, 11)
    mid = fbm(x, y, .45, 23)
    fine = value_noise(x, y, .05, 31)
    finer = value_noise(x, y, .018, 37)

    # Grass: meadow patches, dry sun-bleached spots, clover, blade speckle and flowers.
    grass = lerp((.12, .20, .055), (.25, .32, .10), smooth(.25, .75, big))
    grass = lerp(grass, (.38, .35, .14), .65 * smooth(.6, .78, fbm(x + 40, y - 9, 1.6, 41)))
    grass = lerp(grass, (.07, .14, .045), .5 * smooth(.55, .75, fbm(x - 7, y + 3, .5, 43)))
    grass = grass * (.72 + .5 * finer[..., None]) * (.88 + .24 * fine[..., None])
    blade, _, _ = cells(x, y, .035, 47, .45, .18, .32)
    grass = lerp(grass, grass * 1.35 + np.float32(.02), .6 * blade)
    for seed, petal, density in [(53, (.85, .80, .60), .05), (59, (.55, .62, .95), .03),
                                 (61, (.95, .70, .30), .03)]:
        cluster = smooth(.62, .7, fbm(x, y, .9, seed))
        dots, _, _ = cells(x, y, .09, seed, density, .16, .28)
        grass = lerp(grass, petal, dots * cluster)

    # Dirt road: sandy base, two trodden ruts, packed crown, gravel and a ragged edge.
    d = road_distance(x, y)
    dirt = lerp((.33, .245, .15), (.46, .35, .21), smooth(.2, .8, mid))
    dirt = dirt * (.86 + .28 * fine[..., None])
    rut_edge = np.abs(d - .62 + .06 * (mid - .5))
    dirt = lerp(dirt, (.21, .15, .095), .55 * smooth(.17, .06, rut_edge))
    dirt = lerp(dirt, (.50, .42, .29), .3 * smooth(.35, 0, d))
    for size, seed, density, rmin, rmax, tone in [(.055, 67, .5, .2, .42, (.50, .47, .41)),
                                                  (.055, 71, .3, .15, .35, (.27, .22, .17)),
                                                  (.22, 73, .12, .18, .38, (.42, .41, .39))]:
        stone, dome, pick = cells(x, y, size, seed, density, rmin, rmax)
        shade = (.55 + .6 * dome) * (.85 + .3 * pick)
        dirt = lerp(dirt, np.asarray(tone, np.float32) * shade[..., None], stone * .95)
    edge = 1.12 + .22 * (mid - .5) + .06 * (fine - .5)
    road_w = smooth(edge + .035, edge - .035, d)
    # Grass tufts creep over the outer part of the road.
    tuft, _, _ = cells(x, y, .13, 79, .55, .25, .45)
    road_w = road_w * (1 - tuft * smooth(.8, 1.08, d))

    # Forest floor in the valley, rock where the mesh is steep.
    floor = lerp((.035, .065, .06), (.075, .10, .06), smooth(.3, .7, mid))
    floor = lerp(floor, (.10, .16, .06), .45 * smooth(.55, .75, big))
    floor = floor * (.8 + .4 * finer[..., None])
    rock = lerp((.13, .16, .21), (.26, .29, .32), smooth(.2, .8, mid)) * (.8 + .4 * fine[..., None])
    rock = lerp(rock, (.17, .25, .09), .35 * smooth(.6, .8, big))
    banks = lerp((.11, .16, .06), (.05, .09, .09), smooth(1.5, 3.4, d))

    color = grass.copy()
    on_road = (kind == KIND_ROAD) | (kind == KIND_SPUR)
    color = np.where(on_road[..., None], lerp(grass, dirt, road_w), color)
    spur_bank = (kind == KIND_SPUR) & (d > 1.45)
    color = np.where(spur_bank[..., None], banks, color)
    color = np.where((kind == KIND_VALLEY)[..., None], floor, color)
    color = lerp(color, rock, smooth(.9, 2.2, slope))
    return color


def build_image(width, height, bounds, kind_grid, slope_grid, step, rows_per_chunk=512):
    """Return an (height, width, 4) float32 sRGB array; row 0 is the image bottom (Blender)."""
    x0, x1, y0, y1 = bounds
    kind_grid = np.asarray(kind_grid, dtype=np.int8)
    slope_grid = np.asarray(slope_grid, dtype=np.float32)
    gy_max, gx_max = kind_grid.shape[0] - 1, kind_grid.shape[1] - 1
    out = np.empty((height, width, 4), dtype=np.float32)
    xs = x0 + (np.arange(width, dtype=np.float32) + .5) / width * (x1 - x0)
    for r0 in range(0, height, rows_per_chunk):
        r1 = min(height, r0 + rows_per_chunk)
        ys = y0 + (np.arange(r0, r1, dtype=np.float32) + .5) / height * (y1 - y0)
        x, y = np.meshgrid(xs, ys)
        gx, gy = (x - x0) / step, (y - y0) / step
        ki = np.clip(np.rint(gx), 0, gx_max).astype(np.int64)
        kj = np.clip(np.rint(gy), 0, gy_max).astype(np.int64)
        kind = kind_grid[kj, ki]
        i0 = np.clip(np.floor(gx), 0, gx_max - 1).astype(np.int64)
        j0 = np.clip(np.floor(gy), 0, gy_max - 1).astype(np.int64)
        tx, ty = np.clip(gx - i0, 0, 1), np.clip(gy - j0, 0, 1)
        s = (slope_grid[j0, i0] * (1 - tx) * (1 - ty) + slope_grid[j0, i0 + 1] * tx * (1 - ty)
             + slope_grid[j0 + 1, i0] * (1 - tx) * ty + slope_grid[j0 + 1, i0 + 1] * tx * ty)
        rgb = to_srgb(paint_rows(x, y, kind, s))
        out[r0:r1, :, :3] = rgb
        out[r0:r1, :, 3] = 1.0
    return out
