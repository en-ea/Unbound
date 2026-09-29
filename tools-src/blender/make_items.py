"""Builds the faceted item models (used for drops in the world and rendered as Bag icons).
Each item is about 0.3 m across, centred on the origin. Exported to game/assets/items/<id>.glb.
Material "Item" everywhere (colours in UVs); "Glow" parts shine a little.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_items.py
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
from lowpoly import Builder, clump, blade, export  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "items")
COLORS = {"Item": (1, 1, 1), "Glow": (1, 1, 1)}


def tube_faces(b, pts, radii, color, seg=7, mat="Item", ref=V((0, 0, 1))):
    b.paint(b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=ref, seg=seg)), mat, color)


def log(bark=(0.58, 0.4, 0.25), cut=(0.82, 0.66, 0.44)):
    b = Builder(["Item"])
    tube_faces(b, [V((-0.17, 0, 0)), V((0.17, 0, 0))], [(0.075, 0.075)] * 2, bark)
    # Light cut ends.
    for f in b.bm.faces:
        f.normal_update()
        if abs(f.normal.x) > 0.9:
            b.paint([f], "Item", cut)
    return b


def stone():
    rnd = random.Random(2)
    b = Builder(["Item"])
    clump(b, V((0, 0, 0)), 0.12, 1, rnd, (0.62, 0.62, 0.6), "Item", 0.7)
    for f in b.bm.faces:
        b.paint([f], "Item", rnd.choice([(0.62, 0.62, 0.6), (0.55, 0.56, 0.55), (0.68, 0.67, 0.63)]))
    return b


def apple():
    rnd = random.Random(3)
    b = Builder(["Item"])
    clump(b, V((0, 0, 0)), 0.1, 2, rnd, (0.85, 0.18, 0.14), "Item", 0.9)
    tube_faces(b, [V((0, 0, 0.08)), V((0.01, 0, 0.14))], [(0.01, 0.01)] * 2, (0.35, 0.22, 0.12), seg=4)
    b.paint(b.new_faces(lambda: blade(b.bm, V((0.01, 0, 0.12)), V((0.07, 0.02, 0.15)), 0.025)), "Item", (0.4, 0.65, 0.28))
    return b


def mushroom(cap, mat="Item"):
    b = Builder(["Item", "Glow"])
    tube_faces(b, [V((0, 0, -0.1)), V((0, 0, 0.04))], [(0.035, 0.035), (0.03, 0.03)], (0.93, 0.9, 0.82), seg=6)
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 0.02)), V((0, 0, 0.07)), V((0, 0, 0.1))],
                                        [(0.11, 0.11), (0.08, 0.08), (0.01, 0.01)], seg=8)), mat, cap)
    return b


def flower():
    rnd = random.Random(5)
    b = Builder(["Item"])
    tube_faces(b, [V((0, 0, -0.12)), V((0, 0, 0.06))], [(0.012, 0.012)] * 2, (0.4, 0.62, 0.28), seg=4)
    b.paint(b.new_faces(lambda: blade(b.bm, V((0, 0, -0.04)), V((0.08, 0.02, 0.0)), 0.025)), "Item", (0.45, 0.66, 0.3))
    for k in range(5):
        a = k * math.tau / 5
        clump(b, V((math.cos(a) * 0.045, math.sin(a) * 0.045, 0.08)), 0.035, 1, rnd, (0.95, 0.55, 0.72), "Item", 0.6)
    clump(b, V((0, 0, 0.09)), 0.025, 1, rnd, (0.98, 0.85, 0.3), "Item", 1.0)
    return b


def shard(color, mat, height=0.26, width=0.06, seg=5):
    b = Builder(["Item", "Glow"])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, -height / 2)), V((0, 0, height * 0.15)), V((0, 0, height / 2))],
                                        [(width * 0.6, width * 0.6), (width, width), (0.004, 0.004)], seg=seg)), mat, color)
    return b


def ore_chunk(color, seed):
    """A grey nugget with a few crystals of ore sticking out."""
    rnd = random.Random(seed)
    b = Builder(["Item", "Glow"])
    clump(b, V((0, 0, -0.02)), 0.09, 1, rnd, (0.5, 0.49, 0.47), "Item", 0.8)
    for a in (0.3, 2.4, 4.4):
        d = V((math.cos(a) * 0.6, math.sin(a) * 0.6, 0.8)).normalized()
        b.paint(b.new_faces(lambda d=d: rk.tube(b.bm, [d * 0.03, d * 0.15], [(0.035, 0.03), (0.006, 0.006)], ref=V((0, 0, 1)), seg=5)), "Item", color)
    return b


def amber():
    rnd = random.Random(7)
    b = Builder(["Item", "Glow"])
    clump(b, V((0, 0, 0)), 0.08, 1, rnd, (1.0, 0.62, 0.15), "Glow", 1.3)
    return b


def hide(color=(0.52, 0.42, 0.44)):
    b = Builder(["Item"])
    def make():
        bm = b.bm
        ring = [bm.verts.new(V((math.cos(a) * r, math.sin(a) * r * 0.8, 0.0)))
                for a, r in [(k * math.tau / 9, 0.15 + 0.03 * math.sin(k * 2.7)) for k in range(9)]]
        c = bm.verts.new(V((0, 0, 0.02)))
        for k in range(9):
            bm.faces.new((c, ring[k], ring[(k + 1) % 9]))
            bm.faces.new((ring[(k + 1) % 9], ring[k], bm.verts.new(V((0, 0, -0.01)))))
    b.paint(b.new_faces(make), "Item", color)
    return b


def tusk():
    b = Builder(["Item"])
    pts = [V((-0.1, 0, -0.05)), V((0.0, 0, 0.0)), V((0.08, 0, 0.06)), V((0.11, 0, 0.13))]
    tube_faces(b, pts, [(0.03, 0.03), (0.025, 0.025), (0.017, 0.017), (0.003, 0.003)], (0.93, 0.88, 0.74), seg=6, ref=V((0, 1, 0)))
    return b


def fang():
    b = Builder(["Item"])
    pts = [V((0.0, 0, -0.07)), V((0.02, 0, 0.0)), V((0.01, 0, 0.06)), V((-0.02, 0, 0.1))]
    tube_faces(b, pts, [(0.028, 0.02), (0.022, 0.017), (0.012, 0.01), (0.002, 0.002)], (0.97, 0.95, 0.88), seg=5, ref=V((0, 1, 0)))
    return b


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials(COLORS, roughness=0.7)
os.makedirs(OUT, exist_ok=True)
def meat(color, bone=True):
    rnd = random.Random(8)
    b = Builder(["Item"])
    clump(b, V((0.02, 0, 0)), 0.11, 1, rnd, color, "Item", 0.6)
    if bone:
        tube_faces(b, [V((-0.2, 0, 0)), V((-0.06, 0, 0))], [(0.022, 0.022)] * 2, (0.95, 0.92, 0.84), seg=5)
        clump(b, V((-0.21, 0, 0)), 0.035, 1, rnd, (0.95, 0.92, 0.84), "Item", 0.9)
    return b


def skewer():
    rnd = random.Random(9)
    b = Builder(["Item"])
    tube_faces(b, [V((-0.2, 0, 0)), V((0.2, 0, 0))], [(0.008, 0.008)] * 2, (0.6, 0.45, 0.28), seg=4, ref=V((0, 0, 1)))
    for k, x in enumerate((-0.1, 0.0, 0.1)):
        clump(b, V((x, 0, 0.01)), 0.05, 1, rnd, (0.72, 0.42, 0.22) if k != 1 else (0.9, 0.8, 0.6), "Item", 0.8)
    return b


def bowl(soup):
    b = Builder(["Item"])
    tube_faces(b, [V((0, 0, -0.07)), V((0, 0, -0.04)), V((0, 0, 0.05))], [(0.07, 0.07), (0.12, 0.12), (0.15, 0.15)], (0.62, 0.42, 0.26), seg=10)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, 0, 0.04)), (0.13, 0.13, 0.02), 10, 2)), "Item", soup)
    return b


def tart():
    b = Builder(["Item"])
    tube_faces(b, [V((0, 0, -0.03)), V((0, 0, 0.02))], [(0.14, 0.14), (0.15, 0.15)], (0.9, 0.7, 0.42), seg=10)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, 0, 0.025)), (0.12, 0.12, 0.02), 10, 2)), "Item", (0.85, 0.25, 0.2))
    return b


def tobacco_leaf():
    rnd = random.Random(7)
    b = Builder(["Item"])
    green = [(0.42, 0.58, 0.22), (0.5, 0.66, 0.26)]
    for k, ang in enumerate((-0.35, 0.0, 0.35)):
        tip = V((math.cos(ang) * 0.2, math.sin(ang) * 0.2, 0.02 * k))
        b.paint(b.new_faces(lambda tip=tip: blade(b.bm, V((-0.12, 0, 0)), tip, 0.09)), "Item", green[k % 2])
    tube_faces(b, [V((-0.14, 0, 0)), V((0.12, 0, 0.005))], [(0.008, 0.006)] * 2, (0.72, 0.66, 0.36), seg=3)
    return b


def cigarette():
    b = Builder(["Item", "Glow"])
    tube_faces(b, [V((-0.1, 0, 0)), V((0.05, 0, 0))], [(0.014, 0.014)] * 2, (0.96, 0.94, 0.88), seg=6)
    tube_faces(b, [V((0.05, 0, 0)), V((0.1, 0, 0))], [(0.014, 0.014)] * 2, (0.9, 0.55, 0.22), seg=6)
    tube_faces(b, [V((-0.105, 0, 0)), V((-0.1, 0, 0))], [(0.015, 0.015)] * 2, (1.0, 0.5, 0.15), seg=6, mat="Glow")
    return b


export("wood", log(), OUT)
export("tobacco", tobacco_leaf(), OUT)
export("cigarette", cigarette(), OUT)
export("stone", stone(), OUT)
export("apple", apple(), OUT)
export("mushroom", mushroom((0.82, 0.3, 0.2)), OUT)
export("glowcap", mushroom((0.45, 1.0, 0.75), "Glow"), OUT)
export("flower", flower(), OUT)
export("flint", shard((0.44, 0.44, 0.5), "Item", 0.2, 0.07, 4), OUT)
export("shard", shard((0.55, 0.88, 1.0), "Glow"), OUT)
export("resin", amber(), OUT)
export("hide", hide(), OUT)
export("tusk", tusk(), OUT)
export("pelt", hide((0.6, 0.64, 0.72)), OUT)
export("copper", ore_chunk((0.93, 0.55, 0.3), 5), OUT)
export("iron", ore_chunk((0.8, 0.84, 0.92), 6), OUT)
export("fang", fang(), OUT)
export("pinewood", log((0.36, 0.24, 0.17), (0.93, 0.78, 0.5)), OUT)
export("shadow_pelt", hide((0.2, 0.19, 0.3)), OUT)
export("raw_meat", meat((0.86, 0.42, 0.42)), OUT)
export("roast_meat", meat((0.62, 0.34, 0.18)), OUT)
export("skewer", skewer(), OUT)
export("stew", bowl((0.6, 0.36, 0.2)), OUT)
export("apple_tart", tart(), OUT)
