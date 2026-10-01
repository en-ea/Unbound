"""Builds the Moss-Cap Seeker, a small shy forest spirit (the owner's reference sheet, middle figure): a tall
pointed leaf hood whose tip droops forward, the face lost in shadow with two glowing blue-white eyes, the
body a cone of layered pointed leaves, thin dark legs. No arms show (they stay under the leaves). On the
UAL rig like the golem, so every UAL animation works; the game shrinks them to child height (Npcs "seeker").

Run: tools/blender/blender.exe --background --python tools-src/blender/make_seeker.py
"""
import math
import os
import random
import sys
import bpy  # noqa: F401
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "seeker.glb")

COLORS = {
    "Hood": (0.25, 0.45, 0.27), "Leaf": (0.21, 0.4, 0.22), "LeafDark": (0.13, 0.28, 0.15), "LeafLight": (0.31, 0.51, 0.31),
    "Shadow": (0.05, 0.05, 0.06), "Legs": (0.2, 0.14, 0.13), "Glow": (0.55, 0.85, 1.0),
}
SHADE = 0.1


def leaf(bm, a, top_z, r_top, length, width, flare, bulge=0.035, twist=0.0):
    """One pointed leaf hanging from a ring round the body: `a` is the angle round the body (degrees,
    0 = front (-Y), 90 = the left (+X)); it hangs from radius r_top at top_z, `length` down and `flare`
    outwards. A closed, slightly puffed diamond (a raised midrib in front) so it shows from any side."""
    ang = math.radians(a)
    out = V((math.sin(ang), -math.cos(ang), 0))
    side = V((math.cos(ang), math.sin(ang), 0))
    top = out * r_top + V((0, 0, top_z))
    tip = out * (r_top + flare) + V((0, 0, top_z - length)) + side * twist
    mid = top.lerp(tip, 0.42)
    vs = [bm.verts.new(p) for p in (top, mid + side * width * 0.5, tip, mid - side * width * 0.5,
                                   top.lerp(tip, 0.45) + out * bulge, top.lerp(tip, 0.45) - out * 0.012)]
    t, l, p, r, f, b = vs
    for q in ((t, r, f), (r, p, f), (p, l, f), (l, t, f), (t, l, b), (l, p, b), (p, r, b), (r, t, b)):
        bm.faces.new(q)


def body_weights(p):
    """The leaf cone: follows the chest at the top, the hips lower down, a little of the thighs at the hem."""
    if p.z > 1.15:
        return rk.weights_by_distance(["spine_02", "spine_03", "neck_01"])(p)
    leg = max(0.0, min(0.45, (0.95 - p.z) * 0.9))
    left = max(0.0, min(1.0, 0.5 + p.x / 0.3))
    return {"pelvis": 1.0 - leg, "thigh_l": leg * left, "thigh_r": leg * (1.0 - left)}


def build(arm):
    parts = []
    flat = {"smooth": False, "shade_var": SHADE}

    def part(name, mat, weights, builder, **kw):
        parts.append(rk.build_part(arm, name, mat, weights, builder, **(flat | kw)))

    headw = rk.weights_by_distance(["Head", "neck_01"], top=2)

    # --- the hood: big and round over the head, rising to a tall point that droops forward ----------
    part("S_hood", "Hood", headw, lambda bm: rk.tube(bm, [
        V((0, 0.03, 1.45)), V((0, 0.02, 1.62)), V((0, 0.03, 1.8)), V((0, 0.06, 1.96)), V((0, 0.06, 2.1)),
        V((0.01, 0.03, 2.2)), V((0.03, -0.05, 2.28)), V((0.06, -0.18, 2.3)), V((0.08, -0.3, 2.22)), V((0.09, -0.36, 2.11))],
        [(0.36, 0.33), (0.35, 0.32), (0.31, 0.29), (0.23, 0.22), (0.15, 0.15), (0.1, 0.1), (0.075, 0.075), (0.05, 0.05), (0.03, 0.03), (0.006, 0.006)],
        ref=V((1, 0, 0)), seg=9))
    # The face: a deep shadow under an overhanging brim, and two glowing eyes.
    part("S_face", "Shadow", rk.fixed("Head"), lambda bm: rk.blob(bm, V((0, -0.265, 1.67)), (0.15, 0.05, 0.14), 10, 6))
    def brim(bm):
        pts, radii = [], []
        for k in range(9):
            th = math.radians(-115 + 230 * k / 8)
            pts.append(V((math.sin(th) * 0.2, -0.3 - 0.035 * math.cos(th), 1.67 + math.cos(th) * 0.19)))
            w = 0.018 + 0.035 * math.cos(th * 0.8)
            radii.append((w * 1.2, w))
        rk.tube(bm, pts, radii, ref=V((0, 1, 0)), seg=5)
    part("S_brim", "Hood", rk.fixed("Head"), brim)
    part("S_eyes", "Glow", rk.fixed("Head"), lambda bm: [
        rk.blob(bm, V((s * 0.056, -0.318, 1.685)), (0.026, 0.012, 0.034), 6, 4) for s in (1, -1)])

    # --- a jagged cape of hood leaves over the shoulders, then a bell of leaves down past the knees ---
    rnd = random.Random(5)
    rows = [  # top z, radius, leaf length, width, flare, count, colour
        (1.5, 0.33, 0.3, 0.24, 0.1, 10, "Hood"),
        (1.35, 0.34, 0.34, 0.24, 0.1, 11, "LeafLight"),
        (1.19, 0.37, 0.36, 0.26, 0.11, 12, "Leaf"),
        (1.03, 0.41, 0.37, 0.28, 0.12, 12, "LeafLight"),
        (0.87, 0.46, 0.37, 0.3, 0.12, 13, "Leaf"),
        (0.72, 0.5, 0.33, 0.3, 0.1, 13, "LeafDark"),
    ]
    for i, (z, r, length, width, flare, n, col) in enumerate(rows):
        off = (i % 2) * 0.5 * 360.0 / n
        def ring(bm, z=z, r=r, length=length, width=width, flare=flare, n=n, off=off):
            for k in range(n):
                a = off + k * 360.0 / n + rnd.uniform(-5, 5)
                leaf(bm, a, z + rnd.uniform(-0.02, 0.02), r, length * rnd.uniform(0.9, 1.1), width, flare,
                     twist=rnd.uniform(-0.03, 0.03))
        part(f"S_leaves_{i}", col, body_weights, ring)
    # A dark core inside the bell, so no gaps show between the leaves.
    part("S_core", "LeafDark", body_weights, lambda bm: rk.tube(bm, [
        V((0, 0.02, 0.6)), V((0, 0.02, 0.95)), V((0, 0.02, 1.3)), V((0, 0.02, 1.52))],
        [(0.46, 0.44), (0.38, 0.36), (0.31, 0.29), (0.26, 0.25)], ref=V((1, 0, 0)), seg=9))

    # --- thin dark legs with small pointed feet ----------------------------------------------------
    for s, side in ((1, "l"), (-1, "r")):
        x = s * 0.09
        part(f"S_leg_{side}", "Legs", rk.weights_by_distance(["pelvis", f"thigh_{side}", f"calf_{side}"], top=2), lambda bm, x=x: rk.tube(
            bm, [V((x, 0.0, 0.9)), V((x, 0.0, 0.53)), V((x * 1.1, 0.02, 0.1))], [(0.05, 0.05), (0.04, 0.04), (0.03, 0.03)], seg=5))
        part(f"S_foot_{side}", "Legs", rk.weights_by_distance([f"foot_{side}", f"ball_{side}"], top=2), lambda bm, x=x: rk.tube(
            bm, [V((x * 1.1, 0.04, 0.05)), V((x * 1.1, -0.07, 0.035)), V((x * 1.1, -0.16, 0.02))],
            [(0.04, 0.04), (0.035, 0.03), (0.008, 0.008)], ref=V((0, 0, 1)), seg=5))
    return parts


def group_of(o):
    return "S_" + o.data.materials[0].name


arm = rk.load_rig(RIG)
rk.make_materials(COLORS, roughness=0.9)
parts = rk.join_groups(build(arm), group_of)
print("SEEKER parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("SEEKER written", OUT)
