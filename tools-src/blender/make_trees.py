"""Builds our own clean, solid low-poly trees, bushes and a stump (no see-through leaves, so
they are cheap on phones). Each is exported to game/assets/nature/<name>.glb.
Materials: "Trunk" and "Canopy" / "Needles"; the game swaps the leaf ones for a wind shader.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_trees.py
"""
import math
import os
import random
import sys
import bpy
import bmesh
from mathutils import Vector as V, noise

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "nature")

COLORS = {
    "Trunk": (0.43, 0.31, 0.22),
    "Canopy": (0.40, 0.58, 0.30),
    "Needles": (0.24, 0.42, 0.28),
    "Blossom": (0.96, 0.74, 0.80),
    "Fruit": (0.82, 0.18, 0.14),
    "Stump": (0.62, 0.48, 0.33),
}


def shade(bm, faces, tint):
    """Per-clump colour variation, stored as vertex colour (the game multiplies it in)."""
    layer = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
    col = (rk.srgb_to_linear(tint[0]), rk.srgb_to_linear(tint[1]), rk.srgb_to_linear(tint[2]), 1.0)
    for f in faces:
        for loop in f.loops:
            loop[layer] = col


def clump_tint(rnd):
    """Slightly lighter, darker or warmer clumps."""
    k = rnd.uniform(0.84, 1.12)
    warm = rnd.uniform(-0.04, 0.08)
    return (min(1.0, k + warm), min(1.0, k), min(1.0, k - warm * 0.5))


def lumpy_ball(bm, center, radius, subdiv, seed, squash=0.85, lump=0.12):
    """An icosphere with soft lumps, flattened a little underneath."""
    geom = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = V((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in geom["verts"]:
        d = v.co.normalized()
        r = radius * (1.0 + lump * noise.noise(d * 1.6 + off))
        p = d * r
        if p.z < 0:
            p.z *= squash
        v.co = center + p
    return list({f for v in geom["verts"] for f in v.link_faces})


def assign(bm, faces, index):
    for f in faces:
        f.material_index = index


def trunk(bm, height, base_r, top_r, bend, seed, seg=8):
    rnd = random.Random(seed)
    pts, radii = [], []
    for i in range(5):
        t = i / 4
        pts.append(V((bend[0] * t * t, bend[1] * t * t, height * t)))
        r = base_r + (top_r - base_r) * t
        radii.append((r, r))
    radii[0] = (base_r * 1.35, base_r * 1.35)   # flared roots
    start = len(bm.faces)
    rk.tube(bm, pts, radii, seg=seg)
    bm.faces.ensure_lookup_table()
    return list(bm.faces[start:]), pts[-1]


def branch(bm, start, direction, length, r, seg=6):
    first = len(bm.faces)
    end = start + direction.normalized() * length
    rk.tube(bm, [start, (start + end) / 2, end], [(r, r), (r * 0.8, r * 0.8), (r * 0.5, r * 0.5)], seg=seg)
    bm.faces.ensure_lookup_table()
    return list(bm.faces[first:]), end


def round_tree(seed, leaf="Canopy", fruit=False, tall=False):
    rnd = random.Random(seed)
    bm = bmesh.new()
    h = rnd.uniform(2.6, 3.4) * (1.25 if tall else 1.0)
    faces, top = trunk(bm, h, 0.24, 0.15, (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3)), seed)
    assign(bm, faces, 0)
    shade(bm, faces, (1, 1, 1))
    crown = [(top + V((0, 0, 1.2)), 1.6, 3)]
    if tall:
        crown = [(top + V((0, 0, 0.6)), 1.25, 3), (top + V((0, 0, 1.9)), 1.05, 2), (top + V((0, 0, 2.9)), 0.7, 2)]
    for k in range(rnd.randint(2, 3)):
        ang = rnd.uniform(0, math.tau)
        d = V((math.cos(ang), math.sin(ang), rnd.uniform(0.15, 0.5)))
        f, end = branch(bm, top - V((0, 0, rnd.uniform(0.3, 0.9))), d, rnd.uniform(0.7, 1.1) * (0.6 if tall else 1.0), 0.08)
        assign(bm, f, 0)
        shade(bm, f, (1, 1, 1))
        crown.append((end + V((0, 0, 0.35)), rnd.uniform(0.9, 1.2) * (0.8 if tall else 1.0), 2))
    # Small clumps around the crown so it reads as many leafy bunches, not one ball.
    main_c, main_r, _ = crown[0]
    for k in range(rnd.randint(4, 6)):
        ang = rnd.uniform(0, math.tau)
        c = main_c + V((math.cos(ang) * main_r * 0.8, math.sin(ang) * main_r * 0.8, rnd.uniform(-0.4, 0.7)))
        crown.append((c, rnd.uniform(0.5, 0.8), 1 if k % 2 else 2))
    for i, (c, r, sub) in enumerate(crown):
        f = lumpy_ball(bm, c, r, sub, seed * 10 + i)
        assign(bm, f, 1)
        shade(bm, f, clump_tint(rnd))
    mats = ["Trunk", leaf]
    if fruit:
        for k in range(rnd.randint(7, 10)):
            ang = rnd.uniform(0, math.tau)
            c = main_c + V((math.cos(ang) * main_r * 0.95, math.sin(ang) * main_r * 0.95, rnd.uniform(-0.7, 0.3)))
            f = lumpy_ball(bm, c, 0.13, 1, seed + k, squash=1.0, lump=0.0)
            assign(bm, f, 2)
            shade(bm, f, (1, 1, 1))
        mats.append("Fruit")
    return bm, mats


def pine_tree(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    h = rnd.uniform(1.4, 1.9)
    faces, top = trunk(bm, h, 0.2, 0.13, (0, 0), seed)
    assign(bm, faces, 0)
    shade(bm, faces, (1, 1, 1))
    tiers = rnd.randint(3, 4)
    z = h * 0.55
    radius = rnd.uniform(1.6, 1.9)
    for t in range(tiers):
        tier_h = 2.0 - t * 0.25
        first = len(bm.faces)
        seg = 9
        base = [bm.verts.new(V((radius * math.cos(k * math.tau / seg + t), radius * math.sin(k * math.tau / seg + t), z)))
                for k in range(seg)]
        tip = bm.verts.new(V((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), z + tier_h)))
        for k in range(seg):
            bm.faces.new((base[k], base[(k + 1) % seg], tip))
        bm.faces.new(list(reversed(base)))
        bm.faces.ensure_lookup_table()
        assign(bm, bm.faces[first:], 1)
        shade(bm, bm.faces[first:], clump_tint(rnd))
        z += tier_h * 0.55
        radius *= 0.72
    return bm, ["Trunk", "Needles"]


def bush(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    for i in range(rnd.randint(3, 4)):
        ang = rnd.uniform(0, math.tau)
        c = V((math.cos(ang) * 0.45, math.sin(ang) * 0.45, 0.45 + rnd.uniform(0, 0.2)))
        f = lumpy_ball(bm, c, rnd.uniform(0.5, 0.7), 2, seed * 7 + i, squash=0.6)
        assign(bm, f, 0)
        shade(bm, f, clump_tint(rnd))
    return bm, ["Canopy"]


def stump(seed):
    bm = bmesh.new()
    rk.tube(bm, [V((0, 0, -0.1)), V((0, 0, 0.25)), V((0, 0, 0.45))], [(0.34, 0.34), (0.25, 0.25), (0.23, 0.23)], seg=8)
    for f in bm.faces:
        # The flat top shows the light cut wood; the sides stay bark.
        f.material_index = 1 if f.normal.z > 0.9 or (f.calc_center_median().z > 0.44) else 0
    return bm, ["Trunk", "Stump"]


def export(name, bm, mats, smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(rk.MATERIALS[m])
    # Trunks look better faceted; leaves soft.
    for p in mesh.polygons:
        p.use_smooth = mats[p.material_index] in ("Canopy", "Blossom", "Fruit")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True,
                              export_vertex_color="ACTIVE")
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    print("TREE", name, "tris", tris)
    bpy.data.objects.remove(obj, do_unlink=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials(COLORS, roughness=0.95)
os.makedirs(OUT, exist_ok=True)
for i in range(3):
    export(f"tree_round_{i + 1}", *round_tree(11 + i * 7))
export("tree_blossom_1", *round_tree(41, leaf="Blossom"))
export("tree_apple_1", *round_tree(53, fruit=True))
export("tree_tall_1", *round_tree(67, tall=True))
for i in range(2):
    export(f"tree_pine_{i + 1}", *pine_tree(5 + i * 13))
for i in range(2):
    export(f"bush_{i + 1}", *bush(3 + i * 5))
export("tree_stump", *stump(1))
