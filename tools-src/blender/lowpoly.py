"""Shared helpers for our faceted low-poly static models (trees, rocks, items, creatures).

Colours are stored per face in the UVs (UV = red, green; UV2.x = blue, linear), because Godot
garbled Blender vertex colours on import. The game's solid shader reads them back.
"""
import math
import os
import random
import bpy
import bmesh
from mathutils import Vector as V

import rigkit as rk

class Builder:
    """Collects faces per material with a vertex colour each."""

    def __init__(self, mats):
        self.bm = bmesh.new()
        self.mats = mats
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.uv2 = self.bm.loops.layers.uv.new("UV2")

    def paint(self, faces, mat, color=(1, 1, 1)):
        idx = self.mats.index(mat)
        r, g, b = (rk.srgb_to_linear(c) for c in color)
        for f in faces:
            f.material_index = idx
            for loop in f.loops:
                loop[self.uv].uv = (r, 1.0 - g)      # the glTF exporter flips V
                loop[self.uv2].uv = (b, 1.0)

    def new_faces(self, fn):
        before = set(self.bm.faces)
        fn()
        return [f for f in self.bm.faces if f not in before]


def clump(b, center, radius, subdiv, rnd, color, mat="Canopy", squash=0.85):
    """A faceted leafy clump: a jittered icosphere, a little flatter underneath."""
    def make():
        geom = bmesh.ops.create_icosphere(b.bm, subdivisions=subdiv, radius=1.0)
        for v in geom["verts"]:
            d = v.co.normalized()
            p = d * radius * rnd.uniform(0.9, 1.08)
            if p.z < 0:
                p.z *= squash
            v.co = center + p
    b.paint(b.new_faces(make), mat, color)


def limb(b, pts, r0, r1, seg=5):
    """An angular trunk or branch through the given points, tapering from r0 to r1."""
    n = len(pts)
    radii = [(r0 + (r1 - r0) * i / (n - 1),) * 2 for i in range(n)]
    b.paint(b.new_faces(lambda: rk.tube(b.bm, pts, radii, seg=seg)), "Trunk")


def zigzag(start, direction, length, steps, rnd, wobble=0.25):
    pts = [start]
    d = direction.normalized()
    for i in range(steps):
        side = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.2))) * wobble
        pts.append(pts[-1] + (d + side).normalized() * (length / steps))
    return pts


def blade(bm, base, tip, width):
    """A thin three-sided grass blade (looks right from every side)."""
    d = (tip - base).normalized()
    a = d.cross(V((0, 0, 1))).normalized() if abs(d.z) < 0.99 else V((1, 0, 0))
    bcross = d.cross(a).normalized()
    ring = [bm.verts.new(base + a * width), bm.verts.new(base - a * width * 0.5 + bcross * width * 0.8),
            bm.verts.new(base - a * width * 0.5 - bcross * width * 0.8)]
    t = bm.verts.new(tip)
    for k in range(3):
        bm.faces.new((ring[k], ring[(k + 1) % 3], t))
    bm.faces.new((ring[2], ring[1], ring[0]))     # closed, so its faces point outwards


def export(name, b, out_dir):
    bm = b.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in b.mats:
        mesh.materials.append(rk.MATERIALS[m])
    for p in mesh.polygons:
        p.use_smooth = False      # faceted low-poly everywhere
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB",
                              use_selection=True, export_vertex_color="NONE")
    print("TREE", name, "tris", sum(len(p.vertices) - 2 for p in mesh.polygons))
    bpy.data.objects.remove(obj, do_unlink=True)


