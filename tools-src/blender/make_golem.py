"""Builds Brakk, the golem blacksmith, on the Quaternius UAL skeleton (same rig as make_hero.py), from
the owner's reference picture: a hulking body of faceted rock, glowing rune bracers and a glowing chest
crack, a big horned pauldron on one shoulder and layered iron plates on the other, a leather apron, a
small rocky head with glowing eyes and a beard-block chin. The game scales him up (about 1.5x).
Materials are fixed colours; "Glow" shines (the game's solid shader).

Run: ~/blender-venv/bin/python tools-src/blender/make_golem.py
"""
import math
import os
import random
import sys
import bpy  # noqa: F401
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "golem.glb")

COLORS = {
    "Stone": (0.5, 0.47, 0.45), "StoneDark": (0.32, 0.3, 0.33), "StoneWarm": (0.57, 0.5, 0.46),
    "Iron": (0.3, 0.33, 0.45), "Leather": (0.74, 0.4, 0.17), "Glow": (1.0, 0.46, 0.1),
}
SHADE = 0.11


def slab(bm, center, size, rot=(0, 0, 0), bottom=1.0, top=1.0, seed=0, bevel=0.02, wobble=0.04):
    """A chunky angular block of stone: a cube scaled to `size`, its top and bottom faces scaled by `top` /
    `bottom` (a wedge or trapezoid), turned by `rot` degrees, corners nudged a little, edges chamfered."""
    from mathutils import Euler
    rnd = random.Random(seed + int(center.x * 100) * 7 + int(center.z * 100) * 13)
    g = bmesh.ops.create_cube(bm, size=1.0)
    turn = Euler([math.radians(a) for a in rot]).to_matrix()
    for v in g["verts"]:
        k = top if v.co.z > 0 else bottom
        p = V((v.co.x * size[0] * k, v.co.y * size[1] * k, v.co.z * size[2]))
        p += V((rnd.uniform(-wobble, wobble) * size[0], rnd.uniform(-wobble, wobble) * size[1], rnd.uniform(-wobble, wobble) * size[2]))
        v.co = turn @ p + center
    edges = list({e for v in g["verts"] for e in v.link_edges})
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES")


def spike(bm, base, tip, radius):
    rk.tube(bm, [base, (base + tip) / 2, tip], [(radius, radius), (radius * 0.6, radius * 0.6), (0.006, 0.006)], seg=4)


def skirt_weights(p, top=0.99):
    side = "thigh_l" if p.x > 0 else "thigh_r"
    leg = max(0.0, min(0.75, (top - p.z) * 2.2))
    upper = rk.weights_by_distance(["pelvis", "spine_01"])(p)
    out = {k: v * (1 - leg) for k, v in upper.items()}
    out[side] = out.get(side, 0) + leg
    return out


def torso_weights(p):
    if p.z < 0.99:
        return skirt_weights(p)
    return rk.weights_by_distance(["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"])(p)


def build(arm):
    parts = []
    flat = {"smooth": False, "shade_var": SHADE}
    headw = rk.fixed("Head")

    def part(name, mat, weights, builder, **kw):
        parts.append(rk.build_part(arm, name, mat, weights, builder, **(flat | kw)))

    def many(bm, *calls):
        for c in calls:
            c(bm)

    # --- torso: a big wedge of stone, a raised chest plate with a glowing crack, side plates ---------
    part("G_torso", "Stone", torso_weights, lambda bm: (
        slab(bm, V((0, 0.0, 1.38)), (0.7, 0.46, 0.46), bottom=0.62, seed=1),
        slab(bm, V((0, 0.0, 1.08)), (0.46, 0.36, 0.26), bottom=0.85, seed=2),
        slab(bm, V((0, 0.0, 0.9)), (0.5, 0.34, 0.16), seed=3)))
    part("G_chest_plate", "StoneWarm", torso_weights, lambda bm: (
        slab(bm, V((0, -0.24, 1.4)), (0.36, 0.1, 0.34), bottom=0.75, seed=4),
        slab(bm, V((0.25, -0.22, 1.44)), (0.2, 0.09, 0.24), rot=(0, 0, -8), seed=5),
        slab(bm, V((-0.25, -0.22, 1.44)), (0.2, 0.09, 0.24), rot=(0, 0, 8), seed=6),
        slab(bm, V((0, -0.2, 1.1)), (0.28, 0.08, 0.2), bottom=0.8, seed=7)))
    part("G_back", "StoneDark", torso_weights, lambda bm: (
        slab(bm, V((0, 0.24, 1.42)), (0.5, 0.12, 0.34), seed=8), slab(bm, V((0, 0.2, 1.1)), (0.3, 0.1, 0.2), seed=9)))
    part("G_traps", "Stone", rk.weights_by_distance(["spine_03", "neck_01", "clavicle_l", "clavicle_r"]), lambda bm: [
        slab(bm, V((s * 0.2, 0.02, 1.62)), (0.26, 0.26, 0.14), rot=(0, 0, s * 12), seed=10) for s in (1, -1)])
    # The glowing crack: a jagged run of thin plates down the chest plate, with runes at each side.
    part("G_crack", "Glow", torso_weights, lambda bm: (
        slab(bm, V((0.02, -0.298, 1.5)), (0.04, 0.02, 0.12), rot=(0, 0, 18), bevel=0, wobble=0, seed=11),
        slab(bm, V((-0.03, -0.3, 1.4)), (0.05, 0.02, 0.12), rot=(0, 0, -22), bevel=0, wobble=0, seed=12),
        slab(bm, V((0.03, -0.302, 1.3)), (0.06, 0.02, 0.12), rot=(0, 0, 20), bevel=0, wobble=0, seed=13),
        slab(bm, V((-0.01, -0.3, 1.2)), (0.05, 0.02, 0.1), rot=(0, 0, -16), bevel=0, wobble=0, seed=14),
        slab(bm, V((0.25, -0.272, 1.46)), (0.07, 0.014, 0.1), bevel=0, wobble=0, seed=15),
        slab(bm, V((-0.25, -0.272, 1.46)), (0.07, 0.014, 0.1), bevel=0, wobble=0, seed=16)))
    part("G_neck", "StoneDark", rk.weights_by_distance(["spine_03", "neck_01", "Head"]), lambda bm: slab(bm, V((0, 0.0, 1.6)), (0.22, 0.2, 0.12), seed=17))

    # --- belt and apron ---------------------------------------------------------------------
    part("G_belt", "Leather", torso_weights, lambda bm: slab(bm, V((0, 0.01, 0.98)), (0.56, 0.4, 0.09), bevel=0.012, seed=18))
    part("G_buckle", "StoneWarm", rk.fixed("pelvis"), lambda bm: slab(bm, V((0, -0.215, 0.98)), (0.15, 0.05, 0.13), seed=19))
    part("G_buckle_rune", "Glow", rk.fixed("pelvis"), lambda bm: slab(bm, V((0, -0.245, 0.98)), (0.07, 0.014, 0.08), bevel=0, wobble=0, seed=20))
    apron = rk.weights_by_distance(["pelvis", "spine_01"])
    part("G_apron_front", "Leather", apron, lambda bm: slab(bm, V((0, -0.2, 0.78)), (0.3, 0.03, 0.34), bottom=0.8, bevel=0.01, seed=21))
    part("G_apron_back", "Leather", apron, lambda bm: slab(bm, V((0, 0.2, 0.78)), (0.3, 0.03, 0.34), bottom=0.8, bevel=0.01, seed=22))

    # --- arms and legs -----------------------------------------------------------------------
    for s, side in ((1, "l"), (-1, "r")):
        arm_bones = [f"clavicle_{side}", f"upperarm_{side}", f"lowerarm_{side}", f"hand_{side}"]
        aw = rk.weights_by_distance(arm_bones, top=2)
        pts = [V((s * x, 0.066, 1.441)) for x in (0.14, 0.3, 0.466, 0.6)]
        part(f"G_arm_{side}", "Stone", aw, lambda bm, pts=pts: rk.tube(
            bm, pts, [(0.19, 0.19), (0.18, 0.18), (0.17, 0.17), (0.16, 0.16)], ref=V((0, 0, 1)), seg=4))
        part(f"G_bicep_{side}", "StoneWarm", rk.weights_by_distance([f"upperarm_{side}", f"clavicle_{side}"], top=2), lambda bm, s=s: (
            slab(bm, V((s * 0.33, 0.04, 1.49)), (0.26, 0.26, 0.26), seed=23), slab(bm, V((s * 0.47, 0.05, 1.42)), (0.2, 0.22, 0.2), seed=24)))
        part(f"G_bracer_{side}", "Iron", rk.weights_by_distance([f"lowerarm_{side}", f"hand_{side}"], top=2), lambda bm, s=s: slab(
            bm, V((s * 0.63, 0.066, 1.441)), (0.3, 0.4, 0.38), bevel=0.03, seed=25))
        part(f"G_bracer_rune_{side}", "Glow", rk.weights_by_distance([f"lowerarm_{side}"], top=1), lambda bm, s=s: (
            slab(bm, V((s * 0.63, -0.147, 1.44)), (0.11, 0.014, 0.16), bevel=0, wobble=0, seed=26),
            slab(bm, V((s * 0.63, 0.28, 1.44)), (0.11, 0.014, 0.16), bevel=0, wobble=0, seed=27)))
        part(f"G_fist_{side}", "StoneWarm", rk.fixed(f"hand_{side}"), lambda bm, s=s: (
            slab(bm, V((s * 0.84, 0.066, 1.43)), (0.26, 0.26, 0.26), seed=28), slab(bm, V((s * 0.95, 0.05, 1.44)), (0.1, 0.22, 0.2), seed=29)))
        x = s * 0.13
        part(f"G_leg_{side}", "Stone", rk.weights_by_distance(["pelvis", f"thigh_{side}", f"calf_{side}"], top=2), lambda bm, x=x: rk.tube(
            bm, [V((x, 0.0, 0.99)), V((x * 1.1, 0.0, 0.72)), V((x, 0.01, 0.5)), V((x, 0.025, 0.36))],
            [(0.2, 0.2), (0.19, 0.19), (0.17, 0.17), (0.155, 0.155)], seg=4))
        part(f"G_knee_{side}", "StoneWarm", rk.weights_by_distance([f"thigh_{side}", f"calf_{side}"], top=2), lambda bm, x=x: slab(
            bm, V((x, -0.16, 0.56)), (0.26, 0.12, 0.2), seed=30))
        foot = rk.weights_by_distance([f"calf_{side}", f"foot_{side}", f"ball_{side}"], top=2)
        part(f"G_boot_{side}", "StoneDark", foot, lambda bm, x=x: (
            slab(bm, V((x, -0.08, 0.09)), (0.32, 0.5, 0.18), seed=31), slab(bm, V((x, 0.03, 0.3)), (0.3, 0.3, 0.26), seed=32)))
        part(f"G_boot_band_{side}", "Iron", rk.weights_by_distance([f"calf_{side}"], top=1), lambda bm, x=x: slab(
            bm, V((x, 0.03, 0.44)), (0.34, 0.34, 0.06), bevel=0.01, seed=33))

    # --- shoulders: a big horned slab on his left, layered iron plates on his right ------------
    lw = rk.weights_by_distance(["clavicle_l", "upperarm_l"], top=2)
    part("G_pauldron_l", "StoneDark", lw, lambda bm: (
        slab(bm, V((0.36, 0.03, 1.66)), (0.44, 0.4, 0.16), rot=(0, 0, -8), seed=34),
        slab(bm, V((0.4, 0.03, 1.55)), (0.46, 0.42, 0.12), rot=(0, 0, -8), seed=35)))
    part("G_pauldron_l_horn", "Stone", lw, lambda bm: (spike(bm, V((0.42, 0.0, 1.72)), V((0.56, -0.05, 2.05)), 0.09),
                                                      spike(bm, V((0.28, 0.1, 1.72)), V((0.28, 0.2, 1.98)), 0.06)))
    rw = rk.weights_by_distance(["clavicle_r", "upperarm_r"], top=2)
    part("G_pauldron_r", "Iron", rw, lambda bm: [
        slab(bm, V((-0.34 - i * 0.06, 0.03, 1.68 - i * 0.09)), (0.4 - i * 0.02, 0.36, 0.11), rot=(0, 0, 8 + i * 3), seed=36 + i) for i in range(3)])
    part("G_pauldron_r_spike", "StoneDark", rw, lambda bm: spike(bm, V((-0.3, 0.03, 1.74)), V((-0.32, 0.03, 1.98)), 0.07))

    # --- head: a small blocky head sunk between the shoulders, heavy brow, beard-block chin --------
    part("G_head", "Stone", headw, lambda bm: (
        slab(bm, V((0, -0.02, 1.75)), (0.28, 0.28, 0.24), top=0.85, seed=40),
        slab(bm, V((0, -0.155, 1.7)), (0.06, 0.05, 0.1), seed=41)))
    part("G_beard", "StoneWarm", headw, lambda bm: (
        slab(bm, V((0, -0.11, 1.63)), (0.24, 0.14, 0.14), bottom=0.7, seed=42),
        slab(bm, V((0, -0.12, 1.56)), (0.14, 0.1, 0.08), seed=43)))
    part("G_brow", "StoneDark", headw, lambda bm: (
        slab(bm, V((0, -0.14, 1.79)), (0.3, 0.07, 0.06), seed=44), slab(bm, V((0, 0.0, 1.9)), (0.12, 0.18, 0.06), seed=45)))
    part("G_eyes", "Glow", headw, lambda bm: [
        slab(bm, V((s * 0.065, -0.152, 1.74)), (0.05, 0.02, 0.028), bevel=0, wobble=0, seed=46) for s in (1, -1)])
    return parts


def group_of(o):
    return "G_" + o.data.materials[0].name


arm = rk.load_rig(RIG)
rk.make_materials(COLORS, roughness=0.9)
parts = rk.join_groups(build(arm), group_of)
print("GOLEM parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("GOLEM written", OUT)
