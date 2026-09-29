"""Builds Brakk, the golem blacksmith, on the Quaternius UAL skeleton (same rig as make_hero.py, so every UAL
animation works). From the owner's reference picture, kept simple: a hulking V-shaped body of chiselled
warm-grey boulders, a small head sunk low between big shoulder rocks (heavy brow, glowing eyes, square
jaw), a glowing lava crack down the chest, huge forearms with glowing rune bands, a horned boulder on his
left shoulder and stacked plates on his right, a leather belt with a rune buckle, a leather apron, stumpy
rock legs. Every rock is fixed to one bone, so nothing stretches when he moves. The game scales him up
(Npcs "brakk": about 1.6x). Sonnet's first version is kept as make_golem_v1.py / golem_v1.glb.

Run: ~/blender-venv/bin/python tools-src/blender/make_golem.py
"""
import math
import os
import random
import sys
import bpy  # noqa: F401
import bmesh
from mathutils import Euler, Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "golem.glb")

COLORS = {
    "Stone": (0.55, 0.49, 0.43), "StoneDark": (0.41, 0.37, 0.35), "StoneLight": (0.64, 0.57, 0.5),
    "Apron": (0.5, 0.27, 0.15), "Glow": (1.0, 0.52, 0.14),
}
SHADE = 0.1


def rock(bm, c, size, seed, rot=(0, 0, 0), squareness=0.75, jitter=0.05, top=1.0):
    """A chiselled block of stone: a cube cut once along each edge and pulled a little towards a ball
    (flat faces with cut-off corners), each corner nudged, scaled to `size` (full width, depth, height),
    turned by `rot` degrees. `top` < 1 narrows the top (a wedge). `squareness` 1 = a plain box."""
    rnd = random.Random(seed)
    first = len(bm.verts)                       # new verts are added at the end
    g = bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=list({e for v in g["verts"] for e in v.link_edges}), cuts=1, use_grid_fill=True)
    turn = turn_of(rot)
    bm.verts.ensure_lookup_table()
    for v in bm.verts[first:]:
        p = v.co.copy()
        p = p.lerp(p.normalized() * 1.2, 1.0 - squareness) * (1.0 + rnd.uniform(-jitter, jitter))
        k = 1.0 + (top - 1.0) * max(p.z, 0.0)
        v.co = c + turn @ V((p.x * size[0] * 0.5 * k, p.y * size[1] * 0.5 * k, p.z * size[2] * 0.5))


def turn_of(rot):
    return Euler([math.radians(a) for a in rot]).to_matrix()


def glow_bar(bm, a, b, width, depth=0.03):
    """A thin glowing stroke from a to b (runes and cracks), facing -Y."""
    d = b - a
    c = (a + b) / 2
    ang = math.degrees(math.atan2(d.x, d.z))
    rock(bm, c, (width, depth, d.length + width * 0.5), 0, rot=(0, ang, 0), squareness=1.0, jitter=0.0)


def rune(bm, c, s):
    """A simple carved rune (a staff with a hook and a kick), glowing, on a face that looks -Y."""
    glow_bar(bm, c + V((-0.25, 0, -0.45)) * s, c + V((-0.25, 0, 0.45)) * s, 0.12 * s)
    glow_bar(bm, c + V((-0.25, 0, 0.45)) * s, c + V((0.25, 0, 0.2)) * s, 0.12 * s)
    glow_bar(bm, c + V((0.25, 0, 0.2)) * s, c + V((-0.2, 0, 0.0)) * s, 0.12 * s)
    glow_bar(bm, c + V((-0.1, 0, 0.0)) * s, c + V((0.3, 0, -0.45)) * s, 0.12 * s)


def skirt_weights(p, top=0.99):
    side = "thigh_l" if p.x > 0 else "thigh_r"
    leg = max(0.0, min(0.7, (top - p.z) * 2.0))
    out = {"pelvis": 1.0 - leg}
    out[side] = leg
    return out


def build(arm):
    parts = []
    flat = {"smooth": False, "shade_var": SHADE}

    def part(name, mat, bone_or_weights, builder):
        w = rk.fixed(bone_or_weights) if isinstance(bone_or_weights, str) else bone_or_weights
        parts.append(rk.build_part(arm, name, mat, w, builder, **flat))

    # --- torso: a broad upper chest and back, two big pecs, a narrower belly -------------------------
    part("G_chest", "Stone", "spine_03", lambda bm: (
        rock(bm, V((0, 0.03, 1.42)), (0.78, 0.5, 0.42), 1, top=0.9),
        rock(bm, V((0, 0.14, 1.56)), (0.62, 0.36, 0.26), 2)))
    part("G_pecs", "StoneLight", "spine_03", lambda bm: [
        rock(bm, V((s * 0.16, -0.17, 1.4)), (0.32, 0.18, 0.3), 3 + (s > 0), rot=(0, s * 6, 0)) for s in (1, -1)])
    part("G_belly", "Stone", "spine_02", lambda bm: (
        rock(bm, V((0, 0.0, 1.2)), (0.54, 0.4, 0.3), 5),
        rock(bm, V((0, -0.15, 1.2)), (0.3, 0.14, 0.24), 6)))
    part("G_hips", "StoneDark", "pelvis", lambda bm: rock(bm, V((0, 0.02, 0.98)), (0.5, 0.36, 0.2), 7))
    part("G_crack", "Glow", "spine_03", lambda bm: (                   # the lava crack between the pecs
        glow_bar(bm, V((0.0, -0.245, 1.52)), V((0.03, -0.245, 1.44)), 0.035),
        glow_bar(bm, V((0.03, -0.245, 1.44)), V((-0.02, -0.25, 1.36)), 0.045),
        glow_bar(bm, V((-0.02, -0.25, 1.36)), V((0.01, -0.245, 1.28)), 0.035),
        glow_bar(bm, V((-0.02, -0.25, 1.36)), V((-0.09, -0.24, 1.33)), 0.025)))
    # Big trapezius rocks rise either side of the neck, so the head sits low between them.
    part("G_traps", "Stone", "spine_03", lambda bm: [
        rock(bm, V((s * 0.19, 0.05, 1.63)), (0.24, 0.3, 0.2), 8 + (s > 0), rot=(0, s * 14, 0)) for s in (1, -1)])

    # --- head: small and square, heavy brow, glowing eyes, a jutting jaw ----------------------------
    part("G_head", "Stone", "Head", lambda bm: rock(bm, V((0, -0.06, 1.68)), (0.24, 0.24, 0.26), 10, top=0.9))
    part("G_brow", "StoneDark", "Head", lambda bm: rock(bm, V((0, -0.17, 1.735)), (0.27, 0.08, 0.07), 11, squareness=0.8))
    part("G_jaw", "StoneLight", "Head", lambda bm: rock(bm, V((0, -0.14, 1.6)), (0.22, 0.14, 0.11), 12, top=1.1))
    part("G_nose", "StoneLight", "Head", lambda bm: rock(bm, V((0, -0.19, 1.67)), (0.05, 0.05, 0.08), 13))
    part("G_eyes", "Glow", "Head", lambda bm: [
        rock(bm, V((s * 0.06, -0.185, 1.7)), (0.055, 0.02, 0.028), 0, squareness=1.0, jitter=0.0) for s in (1, -1)])

    # --- arms: big upper arms, huge forearms with rune bands, heavy fists ---------------------------
    for s, side in ((1, "l"), (-1, "r")):
        part(f"G_upperarm_{side}", "Stone", f"upperarm_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.31, 0.07, 1.44)), (0.3, 0.3, 0.3), 20 + s),
            rock(bm, V((s * 0.33, 0.0, 1.47)), (0.2, 0.18, 0.2), 22 + s)))
        part(f"G_forearm_{side}", "Stone", f"lowerarm_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.6, 0.07, 1.44)), (0.34, 0.36, 0.36), 24 + s),))
        part(f"G_band_{side}", "StoneDark", f"lowerarm_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.62, 0.07, 1.44)), (0.16, 0.41, 0.41), 26 + s, squareness=0.85, jitter=0.02),))
        part(f"G_rune_{side}", "Glow", f"lowerarm_{side}", lambda bm, s=s: rune(bm, V((s * 0.62, -0.143, 1.44)), 0.1))
        part(f"G_fist_{side}", "StoneLight", f"hand_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.85, 0.06, 1.43)), (0.24, 0.27, 0.27), 28 + s),
            rock(bm, V((s * 0.95, 0.04, 1.43)), (0.1, 0.24, 0.22), 30 + s)))
        # Legs: stumpy stone pillars, a knee cap, big flat feet.
        x = s * 0.12
        part(f"G_thigh_{side}", "Stone", f"thigh_{side}", lambda bm, x=x, s=s: rock(bm, V((x, 0.0, 0.72)), (0.3, 0.32, 0.46), 32 + s))
        part(f"G_knee_{side}", "StoneLight", f"calf_{side}", lambda bm, x=x, s=s: rock(bm, V((x, -0.13, 0.52)), (0.2, 0.12, 0.16), 34 + s))
        part(f"G_calf_{side}", "StoneDark", f"calf_{side}", lambda bm, x=x, s=s: rock(bm, V((x, 0.02, 0.32)), (0.3, 0.3, 0.42), 36 + s, top=1.1))
        part(f"G_foot_{side}", "Stone", f"foot_{side}", lambda bm, x=x, s=s: rock(bm, V((x, -0.07, 0.09)), (0.32, 0.44, 0.2), 38 + s, top=0.85))

    # --- shoulders: a horned boulder on the left, stacked stone plates on the right ------------------
    part("G_pauldron_l", "StoneDark", "clavicle_l", lambda bm: (
        rock(bm, V((0.34, 0.05, 1.62)), (0.44, 0.44, 0.24), 40, rot=(0, -12, 0)),
        rock(bm, V((0.46, 0.05, 1.5)), (0.3, 0.4, 0.16), 41, rot=(0, -30, 0))))
    part("G_horn_l", "StoneLight", "clavicle_l", lambda bm: rk.tube(
        bm, [V((0.4, 0.05, 1.7)), V((0.5, 0.03, 1.84)), V((0.62, 0.0, 1.93))], [(0.08, 0.08), (0.05, 0.05), (0.008, 0.008)], seg=5))
    part("G_pauldron_r", "StoneDark", "clavicle_r", lambda bm: [
        rock(bm, V((-0.33 - i * 0.07, 0.05, 1.64 - i * 0.07)), (0.38 - i * 0.04, 0.42, 0.12), 42 + i, rot=(0, 10 + i * 12, 0), squareness=0.8)
        for i in range(3)])

    # --- belt, rune buckle, apron ----------------------------------------------------------------
    part("G_belt", "Apron", "pelvis", lambda bm: rk.tube(
        bm, rk.ring_path(V((0, 0.02, 1.02)), 0.29, 0.22, 12), [(0.05, 0.03)] * 12, ref=V((0, 0, 1)), seg=4, closed=True))
    part("G_buckle", "StoneLight", "pelvis", lambda bm: rock(bm, V((0, -0.235, 1.02)), (0.15, 0.06, 0.14), 45, squareness=0.85, jitter=0.02))
    part("G_buckle_rune", "Glow", "pelvis", lambda bm: rune(bm, V((0, -0.268, 1.02)), 0.08))
    apron = lambda p: skirt_weights(p)
    part("G_apron", "Apron", apron, lambda bm: (
        rock(bm, V((0, -0.23, 0.79)), (0.4, 0.04, 0.44), 46, squareness=1.0, jitter=0.02, top=0.8),
        rock(bm, V((0, 0.24, 0.8)), (0.44, 0.04, 0.4), 47, squareness=1.0, jitter=0.02, top=0.8)))
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
