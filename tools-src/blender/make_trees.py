"""Builds our faceted low-poly trees, pines, bushes, a dead tree and a stump (solid, no
see-through leaves, so cheap on phones). Style: flat-shaded clumps in several distinct greens,
angular twisting trunks with branches reaching out to the clumps, drooping layered pines.
Each is exported to game/assets/nature/<name>.glb.

Leaf colours are stored in the texture coordinates (UV = red, green; UV2.x = blue, linear), so
every clump can have its own shade. (Vertex colours came through Godot's import garbled.) The
game's foliage shader reads them and adds a small per-tree tint and a wind sway.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_trees.py
"""
import math
import os
import random
import sys
import bpy
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "nature")

COLORS = {
    "Trunk": (0.46, 0.31, 0.21),
    "Canopy": (1.0, 1.0, 1.0),
    "Needles": (1.0, 1.0, 1.0),
    "Blossom": (1.0, 1.0, 1.0),
    "Fruit": (0.82, 0.18, 0.14),
    "Flower": (0.92, 0.42, 0.55),
    "Stump": (0.66, 0.52, 0.36),
}
GREENS = [(0.47, 0.64, 0.28), (0.36, 0.55, 0.27), (0.60, 0.72, 0.31), (0.72, 0.79, 0.36), (0.30, 0.47, 0.26)]
PINE_GREENS = [(0.28, 0.50, 0.33), (0.34, 0.58, 0.36), (0.24, 0.43, 0.30)]
PINKS = [(0.97, 0.76, 0.82), (0.93, 0.62, 0.72), (0.99, 0.88, 0.90)]


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


def broad_tree(seed, kind="oak", leaf="Canopy", palette=GREENS, fruit=False):
    rnd = random.Random(seed)
    mats = ["Trunk", leaf] + (["Fruit"] if fruit else [])
    b = Builder(mats)
    shades = rnd.sample(palette, 3)
    if kind == "small":
        height, branches, clump_r = rnd.uniform(1.8, 2.3), rnd.randint(2, 3), (0.45, 0.7)
    elif kind == "round":
        height, branches, clump_r = rnd.uniform(2.0, 2.5), rnd.randint(4, 5), (0.8, 1.15)
    elif kind == "tall":
        height, branches, clump_r = rnd.uniform(2.6, 3.0), 2, (0.6, 0.85)
    else:
        height, branches, clump_r = rnd.uniform(2.0, 2.6), rnd.randint(3, 4), (0.9, 1.35)
    trunk = zigzag(V((0, 0, -0.1)), V((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 1)), height, 4, rnd, 0.3)
    limb(b, trunk, 0.26, 0.14, seg=6)
    top = trunk[-1]
    ends = []
    for k in range(branches):
        ang = k * math.tau / branches + rnd.uniform(-0.4, 0.4)
        out = 0.55 if kind == "tall" else rnd.uniform(0.9, 1.3)
        d = V((math.cos(ang) * out, math.sin(ang) * out, rnd.uniform(0.5, 1.0)))
        start = trunk[rnd.randint(2, 3)] if kind != "small" else trunk[rnd.randint(1, 3)]
        pts = zigzag(start, d, rnd.uniform(1.1, 1.6) * (0.8 if kind == "small" else 1.0), 2, rnd, 0.2)
        limb(b, pts, 0.1, 0.05, seg=4)
        ends.append(pts[-1])
    # Clumps at the branch tips, a crown on top, and extra clumps filling the gaps.
    spots = [(e + V((0, 0, 0.3)), rnd.uniform(*clump_r)) for e in ends]
    spots.append((top + V((0, 0, clump_r[1] * 0.9)), clump_r[1] * 1.15))
    if kind == "round":
        for k in range(6):
            ang = rnd.uniform(0, math.tau)
            spots.append((top + V((math.cos(ang) * 1.3, math.sin(ang) * 1.3, rnd.uniform(0.2, 1.4))), rnd.uniform(0.7, 1.0)))
    if kind == "tall":
        for k in range(3):
            spots.append((top + V((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 1.2 + k * 0.9)), 0.85 - k * 0.15))
    for i, (c, r) in enumerate(spots):
        clump(b, c, r, 1 if r > 0.95 or kind == "oak" else 2, rnd, shades[i % len(shades)], leaf)
    if fruit:
        for k in range(10):
            c, r = rnd.choice(spots)
            d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.8, 0.3))).normalized()
            clump(b, c + d * r * 0.95, 0.12, 1, rnd, (1, 1, 1), "Fruit", 1.0)
    return b


def pine_tree(seed):
    rnd = random.Random(seed)
    b = Builder(["Trunk", "Needles"])
    limb(b, [V((0, 0, -0.1)), V((0, 0, 0.9))], 0.2, 0.16, seg=6)
    tiers = rnd.randint(4, 5)
    z, radius, height = 0.55, rnd.uniform(1.5, 1.75), 1.25
    for t in range(tiers):
        seg = 8

        def make(z=z, radius=radius, height=height, t=t):
            bm = b.bm
            outer, inner = [], []
            for k in range(seg * 2):
                a = k * math.pi / seg + t * 0.4
                r = radius * (1.0 if k % 2 == 0 else 0.8)            # jagged drooping edge
                dz = -0.12 if k % 2 == 0 else 0.05
                outer.append(bm.verts.new(V((math.cos(a) * r, math.sin(a) * r, z + dz))))
                inner.append(bm.verts.new(V((math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, z + height * 0.45))))
            tip = bm.verts.new(V((0, 0, z + height)))
            for k in range(seg * 2):
                k2 = (k + 1) % (seg * 2)
                bm.faces.new((outer[k], outer[k2], inner[k2], inner[k]))
                bm.faces.new((inner[k], inner[k2], tip))
            bm.faces.new(list(reversed(outer)))
        b.paint(b.new_faces(make), "Needles", rnd.choice(PINE_GREENS))
        z += height * 0.62
        radius *= 0.76
        height *= 0.9
    return b


def dead_tree(seed):
    rnd = random.Random(seed)
    b = Builder(["Trunk"])
    trunk = zigzag(V((0, 0, -0.1)), V((0.1, 0, 1)), 2.6, 4, rnd, 0.35)
    limb(b, trunk, 0.24, 0.1, seg=5)

    def grow(start, d, length, r, depth):
        pts = zigzag(start, d, length, 2, rnd, 0.25)
        limb(b, pts, r, r * 0.55, seg=4)
        if depth > 0:
            for k in range(2):
                nd = (d + V((rnd.uniform(-0.9, 0.9), rnd.uniform(-0.9, 0.9), rnd.uniform(0.1, 0.6)))).normalized()
                grow(pts[-1], nd, length * 0.65, r * 0.55, depth - 1)
    for k in range(3):
        ang = k * math.tau / 3 + rnd.uniform(-0.3, 0.3)
        grow(trunk[rnd.randint(2, 4)], V((math.cos(ang), math.sin(ang), 1.2)), 1.2, 0.09, 2)
    return b


def bush(seed, flowers=False):
    rnd = random.Random(seed)
    b = Builder(["Canopy"] + (["Flower"] if flowers else []))
    shades = rnd.sample(GREENS, 2)
    spots = []
    for i in range(rnd.randint(4, 6)):
        ang = rnd.uniform(0, math.tau)
        c = V((math.cos(ang) * 0.45, math.sin(ang) * 0.45, 0.35 + rnd.uniform(0, 0.25)))
        r = rnd.uniform(0.38, 0.55)
        spots.append((c, r))
        clump(b, c, r, 1, rnd, shades[i % 2], squash=0.6)
    if flowers:
        for k in range(6):
            c, r = rnd.choice(spots)
            d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0.2, 1))).normalized()
            clump(b, c + d * r, 0.07, 1, rnd, (1, 1, 1), "Flower", 1.0)
    return b


def stump(seed):
    b = Builder(["Trunk", "Stump"])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, -0.1)), V((0, 0, 0.25)), V((0, 0, 0.42))],
                                        [(0.34, 0.34), (0.26, 0.26), (0.24, 0.24)], seg=7)), "Trunk")
    for f in b.bm.faces:
        f.normal_update()
        if f.normal.z > 0.9:
            f.material_index = 1
    return b


def export(name, b):
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
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              use_selection=True, export_vertex_color="NONE")
    print("TREE", name, "tris", sum(len(p.vertices) - 2 for p in mesh.polygons))
    bpy.data.objects.remove(obj, do_unlink=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials(COLORS, roughness=0.95)
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".glb") or f.endswith(".glb.import"):
        os.remove(os.path.join(OUT, f))
export("tree_oak_1", broad_tree(11))
export("tree_oak_2", broad_tree(23))
export("tree_round_1", broad_tree(31, "round"))
export("tree_round_2", broad_tree(37, "round"))
export("tree_small_1", broad_tree(43, "small"))
export("tree_small_2", broad_tree(47, "small"))
export("tree_tall_1", broad_tree(67, "tall"))
export("tree_apple_1", broad_tree(53, "round", fruit=True))
export("tree_blossom_1", broad_tree(41, "oak", "Blossom", PINKS))
export("tree_pine_1", pine_tree(5))
export("tree_pine_2", pine_tree(18))
export("tree_dead_1", dead_tree(7))
export("bush_1", bush(3))
export("bush_2", bush(8))
export("bush_flower_1", bush(13, flowers=True))
export("tree_stump", stump(1))
