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


def antler_beam(b, base, s, scale, color=(0.93, 0.86, 0.72)):
    """One pale antler: a curving beam with three tines (the stag's, from make_stag.py, in small)."""
    pts = [base + V((s * x, 0, z)) * scale for x, z in [(0, 0), (0.08, 0.1), (0.2, 0.24), (0.28, 0.4), (0.24, 0.55), (0.14, 0.62)]]
    tube_faces(b, pts, [(0.03 * scale, 0.03 * scale), (0.026 * scale, 0.026 * scale), (0.022 * scale, 0.022 * scale),
                        (0.018 * scale, 0.018 * scale), (0.012 * scale, 0.012 * scale), (0.003, 0.003)], color, seg=5, ref=V((0, 1, 0)))
    for i, (dx, dz, ln) in {1: (0.02, 0.14, 0.12), 2: (-0.04, 0.16, 0.14), 3: (0.07, 0.15, 0.13)}.items():
        p = pts[i]
        d = V((s * dx, -0.04, dz)).normalized() * ln * scale
        tube_faces(b, [p, p + d], [(0.014 * scale, 0.014 * scale), (0.002, 0.002)], color, seg=4, ref=V((0, 1, 0)))


def antler():
    b = Builder(["Item"])
    antler_beam(b, V((-0.08, 0, -0.12)), 1, 0.55)
    return b


def crown_antlers():
    """The whole crown on a dark wooden plaque: a trophy."""
    b = Builder(["Item"])
    b.paint(b.new_faces(lambda: rk.tube(b.bm, [V((0, 0.02, -0.14)), V((0, 0.02, -0.02))], [(0.1, 0.03), (0.1, 0.03)], ref=V((1, 0, 0)), seg=6)),
            "Item", (0.36, 0.22, 0.14))
    for s in (1, -1):
        antler_beam(b, V((s * 0.03, 0, -0.06)), s, 0.42)
    return b


def duskmaw_fang():
    b = Builder(["Item", "Glow"])
    pts = [V((0.0, 0, -0.1)), V((0.03, 0, 0.0)), V((0.02, 0, 0.09)), V((-0.03, 0, 0.15))]
    tube_faces(b, pts, [(0.04, 0.03), (0.032, 0.024), (0.018, 0.014), (0.002, 0.002)], (0.16, 0.13, 0.2), seg=5, ref=V((0, 1, 0)))
    tube_faces(b, [V((0.0, 0, -0.1)), V((0.0, 0, -0.13))], [(0.03, 0.03), (0.02, 0.02)], (0.9, 0.2, 0.25), seg=5, mat="Glow", ref=V((0, 1, 0)))
    return b


def _flat(b, pts, color, mat="Item", t=0.004):
    """A thin flat fin through `pts` (in the XZ plane), with a face on each side."""
    bm = b.bm
    front = [bm.verts.new(V((p[0], t, p[1]))) for p in pts]
    back = [bm.verts.new(V((p[0], -t, p[1]))) for p in pts]
    faces = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        faces.append(bm.faces.new((front[j], front[i], back[i], back[j])))
    b.paint(faces, mat, color)


def fish(body, belly, fin, length=1.0, height=1.0, eel=False, glow=None, eyes=True):
    """A faceted fish along +X (nose at +X): a flattened body, darker back and pale belly, tail and fins.
    `glow`: a colour for glowing spots along its side (and glowing fins)."""
    b = Builder(["Item", "Glow"])
    L = 0.3 * length
    if eel:
        xs = [-0.5, -0.3, 0.0, 0.3, 0.45, 0.5]
        hs = [0.02, 0.03, 0.035, 0.035, 0.028, 0.012]
    else:
        xs = [-0.5, -0.38, -0.1, 0.18, 0.38, 0.5]
        hs = [0.02, 0.05, 0.1, 0.1, 0.065, 0.015]
    pts = [V((x * L, 0, 0)) for x in xs]
    radii = [(h * height, h * (0.5 if not eel else 0.8)) for h in hs]
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=V((0, 0, 1)), seg=6))
    for f in faces:
        z = f.calc_center_median().z
        b.paint([f], "Item", belly if z < -0.008 else body)
    fm = "Glow" if glow else "Item"
    t0 = -0.5 * L
    tail = 0.13 * height if not eel else 0.05
    _flat(b, [(t0 + 0.01, 0), (t0 - 0.22 * L, tail), (t0 - 0.14 * L, 0), (t0 - 0.22 * L, -tail)], fin, fm)
    top = 0.1 * height if not eel else 0.035
    if eel:
        _flat(b, [(-0.45 * L, 0.03), (0.3 * L, 0.03), (0.2 * L, 0.06), (-0.4 * L, 0.055)], fin, fm)
    else:
        _flat(b, [(-0.18 * L, top - 0.01), (0.12 * L, top - 0.01), (-0.12 * L, top + 0.07 * height)], fin, fm)
        _flat(b, [(-0.05 * L, -top + 0.015), (0.1 * L, -top + 0.02), (-0.02 * L, -top - 0.04 * height)], fin, fm)
    if eyes:
        for side in (-1, 1):
            b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.36 * L, side * 0.02 * (1 if not eel else 1.3), 0.02 * height)),
                                                     (0.012, 0.012, 0.012), 6, 4)), "Item", (0.06, 0.06, 0.08))
    if glow:
        for k in range(5 if eel else 3):
            x = (-0.35 + k * (0.75 / (5 if eel else 3))) * L
            for side in (-1, 1):
                b.paint(b.new_faces(lambda: rk.blob(b.bm, V((x, side * (0.022 if eel else 0.03), 0.004)), (0.01, 0.01, 0.01), 6, 4)),
                        "Glow", glow)
    return b


def old_boot():
    """A soggy old boot, fished out of the pond."""
    b = Builder(["Item"])
    box(b, V((0, 0, 0.06)), (0.08, 0.09, 0.14), (0.36, 0.27, 0.2), top=0.9)
    box(b, V((0.06, 0, -0.03)), (0.17, 0.09, 0.06), (0.33, 0.25, 0.19))
    box(b, V((0.04, 0, -0.065)), (0.2, 0.1, 0.015), (0.2, 0.17, 0.14))
    tube_faces(b, [V((0.0, 0, 0.13)), V((0.0, 0, 0.15))], [(0.045, 0.05)] * 2, (0.28, 0.21, 0.16), seg=6, ref=V((1, 0, 0)))
    return b


def rod():
    """A fishing rod along +Z, the grip at the origin: a cork handle, a little reel, a long thin rod (tip at 1.3 m)."""
    b = Builder(["Item"])
    tube_faces(b, [V((0, 0, -0.12)), V((0, 0, 0.16))], [(0.03, 0.03), (0.026, 0.026)], (0.78, 0.6, 0.4), seg=6, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, 0, 0.16)), V((0, 0, 0.7)), V((0, 0, 1.3))], [(0.022, 0.022), (0.016, 0.016), (0.008, 0.008)],
               (0.36, 0.24, 0.16), seg=5, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, 0, 1.26)), V((0, 0, 1.3))], [(0.012, 0.012)] * 2, (0.9, 0.2, 0.15), seg=5, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, 0.035, 0.05)), V((0, 0.06, 0.05))], [(0.03, 0.03)] * 2, (0.55, 0.57, 0.6), seg=8, ref=V((0, 0, 1)))
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


def shears():
    """Wren's hedge shears: two long wooden handles spreading from the pivot (at the origin) towards
    -Z, where the hands grip them, and two long steel blades along +Z, slightly crossed."""
    b = Builder(["Item"])
    steel, edge, wood, dark = (0.78, 0.8, 0.84), (0.92, 0.94, 0.96), (0.58, 0.38, 0.22), (0.3, 0.3, 0.33)
    for s in (1, -1):
        # blade: broad at the pivot, tapering to a point, crossing the middle line
        tube_faces(b, [V((s * 0.006, 0, 0.0)), V((-s * 0.012, 0, 0.22)), V((-s * 0.02, 0, 0.44))],
                   [(0.01, 0.042), (0.007, 0.032), (0.003, 0.004)], steel, seg=4, ref=V((1, 0, 0)))
        tube_faces(b, [V((-s * 0.004, 0.02, 0.03)), V((-s * 0.018, 0.02, 0.42))], [(0.004, 0.006), (0.002, 0.002)], edge, seg=4)
        # neck and ferrule, then the long handle
        tube_faces(b, [V((s * 0.004, 0, 0.0)), V((s * 0.03, 0, -0.08))], [(0.013, 0.013), (0.015, 0.015)], dark, seg=5)
        tube_faces(b, [V((s * 0.03, 0, -0.08)), V((s * 0.075, 0, -0.24)), V((s * 0.12, 0, -0.4))],
                   [(0.021, 0.021), (0.02, 0.02), (0.022, 0.022)], wood, seg=6)
        tube_faces(b, [V((s * 0.12, 0, -0.4)), V((s * 0.126, 0, -0.43))], [(0.024, 0.024), (0.018, 0.018)], dark, seg=6)
    tube_faces(b, [V((0, -0.025, 0.0)), V((0, 0.025, 0.0))], [(0.02, 0.02)] * 2, dark, seg=6)      # the pivot bolt
    return b


def box(b, c, size, color, mat="Item", top=1.0):
    """A rough block; `top` narrows its top face (a tapered block)."""
    def make():
        g = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in g["verts"]:
            k = top if v.co.z > 0 else 1.0
            v.co = V((v.co.x * size[0] * k, v.co.y * size[1] * k, v.co.z * size[2])) + c
    b.paint(b.new_faces(make), mat, color)


def golem_hammer():
    """Brakk's big sledge: a wooden haft from the grip (origin) along +Z with a leather wrap and an iron pommel,
    and a big block head across the far end (striking faces left and right) with capped ends and a hex bolt."""
    b = Builder(["Item", "Glow"])
    steel, dark, wood = (0.62, 0.62, 0.66), (0.4, 0.4, 0.44), (0.46, 0.3, 0.18)
    tube_faces(b, [V((0, 0, -0.2)), V((0, 0, 0.74))], [(0.036, 0.036)] * 2, wood, seg=6, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, 0, -0.14)), V((0, 0, 0.1))], [(0.042, 0.042)] * 2, (0.3, 0.17, 0.1), seg=6, ref=V((1, 0, 0)))
    box(b, V((0, 0, -0.23)), (0.09, 0.09, 0.07), dark, top=0.8)                   # pommel
    box(b, V((0, 0, 0.88)), (0.44, 0.3, 0.34), steel)                            # the head, long across the haft
    for s in (1, -1):
        box(b, V((s * 0.25, 0, 0.88)), (0.07, 0.34, 0.38), dark)                   # capped striking faces
        tube_faces(b, [V((0, s * 0.15, 0.88)), V((0, s * 0.185, 0.88))], [(0.055, 0.055)] * 2, dark, seg=6, ref=V((1, 0, 0)))
    box(b, V((0, 0, 0.7)), (0.12, 0.12, 0.05), dark)                             # collar where the haft enters
    return b


def skull_staff():
    """Morrow's staff: a long, slightly crooked branch with a bird skull on top. The grip is at the origin;
    the skull end is towards -Z (a held prop hangs +Z down along the hand, so the skull ends up on top)."""
    b = Builder(["Item", "Glow"])
    wood, bone, dark = (0.42, 0.3, 0.22), (0.9, 0.85, 0.74), (0.14, 0.11, 0.1)
    tube_faces(b, [V((0, 0, 0.85)), V((0.02, 0, 0.3)), V((-0.015, 0.01, -0.3)), V((0.01, 0, -0.8)), V((0, 0, -1.06))],
               [(0.022, 0.022), (0.026, 0.026), (0.024, 0.024), (0.028, 0.028), (0.04, 0.04)], wood, seg=6, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, 0, -0.78)), V((0, 0, -0.86))], [(0.034, 0.034)] * 2, (0.3, 0.2, 0.14), seg=6, ref=V((1, 0, 0)))  # a wrap
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, 0.02, -1.16)), (0.075, 0.09, 0.08), 7, 5)), "Item", bone)       # the cranium
    tube_faces(b, [V((0, -0.05, -1.15)), V((0, -0.16, -1.12)), V((0, -0.3, -1.06))], [(0.045, 0.03), (0.028, 0.02), (0.004, 0.004)],
               bone, seg=5, ref=V((1, 0, 0)))                                                                     # the long beak
    for s in (1, -1):
        b.paint(b.new_faces(lambda s=s: rk.blob(b.bm, V((s * 0.05, -0.04, -1.18)), (0.02, 0.025, 0.022), 6, 4)), "Item", dark)
        b.paint(b.new_faces(lambda s=s: rk.blob(b.bm, V((s * 0.058, -0.045, -1.18)), (0.006, 0.006, 0.006), 4, 3)), "Glow", (1.0, 0.9, 0.62))
    return b


def anvil():
    """A big anvil for Brakk (about 0.9 m long), with a glowing blade on top: a stone base, iron top and a horn."""
    b = Builder(["Item", "Glow"])
    box(b, V((0, 0, 0.13)), (0.5, 0.3, 0.26), (0.43, 0.39, 0.4), top=0.9)
    box(b, V((0, 0, 0.36)), (0.3, 0.2, 0.2), (0.5, 0.5, 0.54), top=0.7)
    box(b, V((0, 0, 0.5)), (0.72, 0.3, 0.1), (0.58, 0.6, 0.66))
    tube_faces(b, [V((0.34, 0, 0.5)), V((0.5, 0, 0.5)), V((0.62, 0, 0.5))], [(0.12, 0.05), (0.08, 0.035), (0.01, 0.01)], (0.58, 0.6, 0.66), seg=4, ref=V((0, 1, 0)))
    tube_faces(b, [V((-0.28, 0, 0.58)), V((0.1, 0, 0.58)), V((0.34, 0, 0.58))], [(0.03, 0.035), (0.045, 0.03), (0.005, 0.01)], (1.0, 0.6, 0.2), seg=4, ref=V((0, 1, 0)), mat="Glow")
    tube_faces(b, [V((-0.4, 0, 0.58)), V((-0.28, 0, 0.58))], [(0.03, 0.03)] * 2, (0.5, 0.34, 0.2), seg=5)
    return b


def bandit_shield():
    """A bandit's round shield: dark planks with a red-painted half, an iron rim and a domed boss. Faces -Y
    (the front), about 0.62 m across, the grip at the origin (behind the boss)."""
    b = Builder(["Item", "Glow"])
    wood, red, iron, dark = (0.54, 0.4, 0.28), (0.72, 0.18, 0.14), (0.62, 0.62, 0.66), (0.34, 0.32, 0.32)
    seg = 12
    def disc(z, r, color, depth):
        tube_faces(b, [V((0, z, 0)), V((0, z - depth, 0))], [(r, r)] * 2, color, seg=seg, ref=V((1, 0, 0)))
    disc(0.0, 0.31, iron, 0.03)                                                  # rim
    disc(-0.005, 0.29, wood, 0.035)                                              # planks
    for f in b.bm.faces:                                                         # paint the left half red
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.y < -0.9 and c.x < -0.02 and c.z > -0.25:
            b.paint([f], "Item", red)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, -0.05, 0)), (0.08, 0.05, 0.08), 7, 4)), "Item", iron)   # boss
    for k in range(6):                                                          # rivets round the rim
        a = k * math.tau / 6
        box(b, V((math.cos(a) * 0.26, -0.045, math.sin(a) * 0.26)), (0.03, 0.02, 0.03), dark)
    box(b, V((0, 0.03, 0)), (0.04, 0.04, 0.2), (0.3, 0.18, 0.1))                 # the grip bar behind
    return b


def bandit_bow():
    """A plain recurve bow: a dark wooden limb curving back at the tips, a leather grip, a taut string. The
    grip is at the origin, the bow stands along Z, the string on the -Y side."""
    b = Builder(["Item", "Glow"])
    wood, grip, string = (0.5, 0.35, 0.24), (0.62, 0.38, 0.22), (0.9, 0.86, 0.76)
    for s in (1, -1):
        tube_faces(b, [V((0, 0, 0)), V((0, 0.05, s * 0.22)), V((0, 0.07, s * 0.44)), V((0, 0.03, s * 0.58)), V((0, -0.02, s * 0.63))],
                   [(0.022, 0.018), (0.02, 0.016), (0.016, 0.013), (0.012, 0.01), (0.008, 0.008)], wood, seg=5, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, 0, -0.07)), V((0, 0, 0.07))], [(0.028, 0.024)] * 2, grip, seg=6, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, -0.02, -0.62)), V((0, -0.02, 0.62))], [(0.004, 0.004)] * 2, string, seg=3, ref=V((1, 0, 0)))
    return b


def arrow():
    """An arrow along +Z (tip at +Z): a shaft, an iron head, red fletching."""
    b = Builder(["Item", "Glow"])
    tube_faces(b, [V((0, 0, -0.38)), V((0, 0, 0.32))], [(0.008, 0.008)] * 2, (0.55, 0.42, 0.28), seg=4, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, 0, 0.3)), V((0, 0, 0.42))], [(0.022, 0.012), (0.002, 0.002)], (0.4, 0.4, 0.44), seg=4, ref=V((1, 0, 0)))
    for k in range(3):
        a = k * math.tau / 3
        d = V((math.cos(a), math.sin(a), 0))
        b.paint(b.new_faces(lambda d=d: [b.bm.faces.new([b.bm.verts.new(V((0, 0, -0.36))), b.bm.verts.new(d * 0.035 + V((0, 0, -0.33))),
                                                     b.bm.verts.new(d * 0.03 + V((0, 0, -0.22))), b.bm.verts.new(V((0, 0, -0.2)))])]), "Item", (0.62, 0.12, 0.1))
    return b


def black_seal():
    """Varek's black seal: a heavy dark-iron signet on a short chain, a red stone set in it, a faint glow."""
    b = Builder(["Item", "Glow"])
    iron, dark = (0.2, 0.19, 0.22), (0.12, 0.11, 0.13)
    tube_faces(b, [V((0, -0.03, 0)), V((0, 0.03, 0))], [(0.1, 0.1)] * 2, iron, seg=8, ref=V((1, 0, 0)))
    tube_faces(b, [V((0, -0.035, 0)), V((0, -0.028, 0))], [(0.075, 0.075)] * 2, dark, seg=8, ref=V((1, 0, 0)))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, -0.05, 0)), (0.035, 0.02, 0.035), 6, 4)), "Glow", (0.9, 0.12, 0.1))
    for k in range(4):                                                          # a few chain links
        tube_faces(b, [V((0, 0, 0.1 + k * 0.045)), V((0, 0, 0.135 + k * 0.045))], [(0.014, 0.014)] * 2, iron, seg=4, ref=V((1, 0, 0)))
    return b


def bandit_token():
    """A torn strip of red cloth with a black hand painted on it: what the Red Hand bandits wear."""
    b = Builder(["Item", "Glow"])
    box(b, V((0, 0, 0)), (0.26, 0.02, 0.12), (0.6, 0.12, 0.1))
    box(b, V((0.02, -0.012, 0)), (0.07, 0.01, 0.07), (0.1, 0.08, 0.08))
    return b


export("bandit_shield", bandit_shield(), OUT)
export("bandit_bow", bandit_bow(), OUT)
export("arrow", arrow(), OUT)
export("black_seal", black_seal(), OUT)
export("red_hand", bandit_token(), OUT)
export("wood", log(), OUT)
export("golem_hammer", golem_hammer(), OUT)
export("anvil", anvil(), OUT)
export("skull_staff", skull_staff(), OUT)
export("shears", shears(), OUT)
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
export("antler", antler(), OUT)
export("crown_antlers", crown_antlers(), OUT)
export("duskmaw_fang", duskmaw_fang(), OUT)
export("stag_hide", hide((0.86, 0.5, 0.26)), OUT)
export("pinewood", log((0.36, 0.24, 0.17), (0.93, 0.78, 0.5)), OUT)
export("shadow_pelt", hide((0.2, 0.19, 0.3)), OUT)
export("raw_meat", meat((0.86, 0.42, 0.42)), OUT)
export("roast_meat", meat((0.62, 0.34, 0.18)), OUT)
export("skewer", skewer(), OUT)
export("stew", bowl((0.6, 0.36, 0.2)), OUT)
export("apple_tart", tart(), OUT)
export("bluegill", fish((0.35, 0.5, 0.62), (0.95, 0.75, 0.35), (0.28, 0.4, 0.55), 0.8, 1.3), OUT)
export("perch", fish((0.5, 0.6, 0.28), (0.92, 0.88, 0.7), (0.9, 0.45, 0.25), 0.95, 1.0), OUT)
export("golden_carp", fish((1.0, 0.7, 0.18), (1.0, 0.9, 0.55), (0.95, 0.52, 0.15), 1.15, 1.25), OUT)
export("trout", fish((0.42, 0.52, 0.48), (0.95, 0.78, 0.76), (0.55, 0.6, 0.55), 1.1, 0.85), OUT)
export("pike", fish((0.28, 0.42, 0.24), (0.86, 0.86, 0.6), (0.52, 0.36, 0.2), 1.5, 0.8), OUT)
export("ghost_koi", fish((0.9, 0.94, 1.0), (1.0, 1.0, 1.0), (0.65, 0.82, 1.0), 1.2, 1.1, glow=(0.6, 0.85, 1.0)), OUT)
export("cavefish", fish((0.9, 0.76, 0.78), (1.0, 0.92, 0.92), (0.86, 0.7, 0.74), 0.8, 0.9, eyes=False), OUT)
export("glimmer_eel", fish((0.14, 0.18, 0.28), (0.3, 0.38, 0.48), (0.2, 0.5, 0.7), 1.7, 1.0, eel=True, glow=(0.45, 0.9, 1.0)), OUT)
export("grilled_fish", fish((0.58, 0.36, 0.18), (0.82, 0.6, 0.34), (0.42, 0.26, 0.14), 1.0, 1.0), OUT)
export("old_boot", old_boot(), OUT)
export("rod", rod(), OUT)
