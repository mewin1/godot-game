"""Writes assets/arenas/forest/arena_layout.json: heights the match view needs (pure Python).

Godot reads it to put towers on terraces and mobs on the climbing road. Coordinates are
Blender metres (x, y); Godot uses (x, -y). Called by build_forest_arena_v2.py after heights.
"""
import json
import math
from pathlib import Path

ROAD_STEP = 0.25   # metres between exported road points


def write(out_path, line, lengths, road_z, heights, l_entry, l_exit, cell=2.0):
    road = []
    last = -1.0
    for (x, y), length in zip(line, lengths):
        if length < l_entry - 1.0 or length > l_exit + 1.0:
            continue
        if last >= 0.0 and length - last < ROAD_STEP:
            continue
        last = length
        road.append([round(x, 3), round(y, 3), round(road_z(length), 3), round(length - l_entry, 3)])
    data = {
        'cell_m': cell,
        'note': 'Blender metres. Cell (gx,gy) centre x=1+2gx, y=19-2gy; Godot (x, height, -y).',
        'terraces': {'%d,%d' % k: round(v, 3) for k, v in sorted(heights.items())},
        'road': road,
        'road_length': round(l_exit - l_entry, 3),
    }
    Path(out_path).write_text(json.dumps(data, separators=(',', ':')) + '\n')
    return len(road)


def road_height_at(road, x, y):
    best = min(road, key=lambda p: (p[0] - x) ** 2 + (p[1] - y) ** 2)
    return best[2], math.dist(best[:2], (x, y))
