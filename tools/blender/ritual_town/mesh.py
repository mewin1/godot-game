"""Small faceted joinery, turned work and curved roof surfaces for the town GLBs."""
import math

import bpy
from mathutils import Vector

FINISHES = ("oak carving heartwood plaster stone brick lime plinth svarog ice water stribog war perun "
            "curse linen iron copper brass verdigris pottery slate glass soot ember frost pool charge "
            "rune rope bone steel").split()


class Meshwork:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.uvs = []

    def face(self, points, finish, uvs=None):
        points = [Vector(p) for p in points]
        start = len(self.verts)
        self.verts.extend(points)
        self.faces.append(tuple(range(start, start + len(points))))
        if uvs is None:
            # Plane projection follows the longest local direction on beams and pipes.
            u = (points[1] - points[0]).normalized()
            v = u.cross(points[-1] - points[0]).normalized().cross(u)
            coords = [((p-points[0]).dot(u), (p-points[0]).dot(v)) for p in points]
            w = max(x for x, y in coords) - min(x for x, y in coords)
            h = max(y for x, y in coords) - min(y for x, y in coords)
            uvs = [((x - min(a for a,b in coords)) / max(.65, w),
                    (y - min(b for a,b in coords)) / max(.65, h)) for x,y in coords]
        index = FINISHES.index(finish)
        for u, v in uvs:
            self.uvs.append(((index % 8 + .024 + .952*u) / 8,
                             1 - (index // 8 + .976 - .952*v) / 4))

    def sides(self, lower, upper, finish, cap=True):
        n = len(lower)
        for i in range(n):
            j = (i+1) % n
            self.face([lower[i], lower[j], upper[j], upper[i]], finish)
        if cap:
            self.face(lower[::-1], finish)
            self.face(upper, finish)

    def box(self, center, size, finish, bevel=.008):
        x,y,z = center
        w,d,h = [v/2 for v in size]
        b = min(w*.3, d*.3, h*.35, bevel)
        points = [(-w+b,-d), (w-b,-d), (w,-d+b), (w,d-b), (w-b,d), (-w+b,d), (-w,d-b),(-w,-d+b)]
        def ring(height, inset):
            return [(x+px*(1-inset/w), y+py*(1-inset/d), z+height) for px,py in points]
        bottom, shoulder, top = ring(-h,0), ring(h-b,0), ring(h,b)
        self.sides(bottom, shoulder, finish, False)
        self.sides(shoulder, top, finish, False)
        self.face(top, finish)
        self.face(bottom[::-1], finish)

    def span(self, a, b, r1, r2, finish, sides=8, angle=0.0, oval=1.0):
        a,b = Vector(a),Vector(b)
        axis = (b-a).normalized()
        ref = Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))
        x = ref.cross(axis).normalized()
        y = axis.cross(x)
        def ring(end, r):
            return [end + x*(math.cos(angle+i*math.tau/sides)*r) +
                    y*(math.sin(angle+i*math.tau/sides)*r*oval) for i in range(sides)]
        self.sides(ring(a,r1),ring(b,r2),finish)

    def beam(self, a, b, width, finish="oak"):
        self.span(a,b,width*.707,width*.707,finish,4,math.pi/4)

    def turned(self, center, profile, finish, n=12):
        x,y,z = center
        rings = [[(x+r*math.cos(i*math.tau/n), y+r*math.sin(i*math.tau/n), z+h)
                  for i in range(n)] for h,r in profile]
        for lo,hi in zip(rings,rings[1:]):
            self.sides(lo,hi,finish,False)
        self.face(rings[0][::-1],finish)
        self.face(rings[-1],finish)

    def hoop(self, center, radius, width, finish, n=16):
        x,y,z=center
        for i in range(n):
            a,b = i*math.tau/n,(i+1)*math.tau/n
            p = (x+radius*math.cos(a),y+radius*math.sin(a),z)
            q = (x+radius*math.cos(b),y+radius*math.sin(b),z)
            self.span(p,q,width,width,finish,5)

    def object(self, name, pivot=(0,0,0)):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([v-Vector(pivot) for v in self.verts], [], self.faces)
        mesh.update()
        uv = mesh.uv_layers.new(name="Finishes")
        uv.data.foreach_set("uv", [s for pair in self.uvs for s in pair])
        ob = bpy.data.objects.new(name,mesh)
        bpy.context.collection.objects.link(ob)
        ob.location = pivot
        return ob
