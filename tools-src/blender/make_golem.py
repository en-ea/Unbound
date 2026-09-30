"""Builds Brakk, the golem blacksmith, on the Quaternius UAL skeleton (same rig as make_hero.py, so every UAL
animation works). From the owner's reference picture: a hulking V-shaped body of chiselled warm-grey
boulders, a small head pushed forward between big shoulder rocks (heavy brow, glowing eyes, square jaw),
a glowing lava crack and a rune on the chest, blocky abs, huge forearms with glowing runes and hex bolts,
big curved shoulder plates with bolts and a horn on the right (hammer side), a leather belt with a rune
buckle, a tattered leather apron, stumpy legs in stone boots. Every rock is fixed to one bone, so nothing
stretches when he moves. The game scales him up (Npcs "brakk": about 1.6x). Sonnet's first version is kept
as make_golem_v1.py / golem_v1.glb.

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
    "Stone": (0.58, 0.51, 0.46), "StoneDark": (0.43, 0.38, 0.36), "StoneLight": (0.68, 0.6, 0.53),
    "Apron": (0.55, 0.3, 0.16), "Leather": (0.34, 0.19, 0.11), "Glow": (1.0, 0.46, 0.1),
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


def hex_bolt(bm, c, r, normal, depth=0.035):
    """A six-sided bolt head sticking out of a surface along `normal`."""
    first = len(bm.verts)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=r, radius2=r * 0.82, depth=depth)
    m = V((0, 0, 1)).rotation_difference(V(normal).normalized()).to_matrix()
    bm.verts.ensure_lookup_table()
    for v in bm.verts[first:]:
        v.co = c + m @ (v.co + V((0, 0, depth * 0.5)))


def glow_bar(bm, a, b, width, depth=0.03):
    """A thin glowing stroke from a to b (runes and cracks), facing -Y."""
    d = b - a
    c = (a + b) / 2
    ang = math.degrees(math.atan2(d.x, d.z))
    rock(bm, c, (width, depth, d.length + width * 0.5), 0, rot=(0, ang, 0), squareness=1.0, jitter=0.0)


def strokes(bm, c, s, pts, width=0.12):
    """A rune drawn as strokes between points (in units of `s`, x right, z up) on a face that looks -Y."""
    for a, b in pts:
        glow_bar(bm, c + V((a[0], 0, a[1])) * s, c + V((b[0], 0, b[1])) * s, width * s)


RUNE_R = [((-0.25, -0.45), (-0.25, 0.45)), ((-0.25, 0.45), (0.25, 0.2)), ((0.25, 0.2), (-0.2, 0.0)), ((-0.1, 0.0), (0.3, -0.45))]
RUNE_S = [((-0.3, 0.45), (0.05, 0.15)), ((0.05, 0.15), (-0.2, -0.05)), ((-0.2, -0.05), (0.25, -0.45)), ((0.25, 0.45), (0.25, 0.1))]


def sheet(bm, c, w_top, w_bot, h, t, n, seed, curve=0.0, back=False):
    """A hanging leather panel with a tattered hem: n strips across, top edge at c, its sides bending
    towards the body by `curve` (towards +Y, or -Y for a back panel)."""
    rnd = random.Random(seed)
    sy = -1.0 if back else 1.0
    drops = []
    for i in range(n + 1):
        d = rnd.uniform(0.0, 0.03) if i % 2 == 0 else -0.06 - rnd.uniform(0.0, 0.03)
        drops.append(-0.02 if i in (0, n) else d)
    rows = []
    for layer in (-0.5, 0.5):
        top, bot = [], []
        for i in range(n + 1):
            u = i / n - 0.5
            bend = sy * curve * (2 * u) ** 2
            top.append(bm.verts.new(c + V((u * w_top, bend + layer * t, 0))))
            bot.append(bm.verts.new(c + V((u * w_bot, bend * 1.3 + layer * t, -h - drops[i]))))
        rows.append((top, bot))
    (ft, fb), (bt, bb) = rows
    for i in range(n):
        bm.faces.new((ft[i], ft[i + 1], fb[i + 1], fb[i]))
        bm.faces.new((bt[i + 1], bt[i], bb[i], bb[i + 1]))
        bm.faces.new((fb[i], fb[i + 1], bb[i + 1], bb[i]))
        bm.faces.new((ft[i + 1], ft[i], bt[i], bt[i + 1]))
    for i in (0, n):
        bm.faces.new((ft[i], fb[i], bb[i], bt[i]))


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

    # --- torso: a broad upper chest and back, two big pecs, a blocky belly --------------------------
    part("G_chest", "Stone", "spine_03", lambda bm: (
        rock(bm, V((0, 0.03, 1.42)), (0.86, 0.52, 0.44), 1, top=0.88),
        rock(bm, V((0, 0.16, 1.55)), (0.7, 0.36, 0.26), 2)))
    part("G_pecs", "StoneLight", "spine_03", lambda bm: [
        rock(bm, V((s * 0.18, -0.18, 1.43)), (0.36, 0.2, 0.32), 3 + (s > 0), rot=(0, s * 6, 0)) for s in (1, -1)])
    part("G_belly", "Stone", "spine_02", lambda bm: [
        rock(bm, V((0, 0.0, 1.19)), (0.58, 0.42, 0.32), 5)] + [
        rock(bm, V((s * 0.1, -0.19, z)), (0.19, 0.1, 0.11), 60 + i, jitter=0.07)
        for i, (s, z) in enumerate(((1, 1.26), (-1, 1.26), (1, 1.14), (-1, 1.14)))])
    part("G_hips", "StoneDark", "pelvis", lambda bm: rock(bm, V((0, 0.02, 0.98)), (0.54, 0.38, 0.22), 7))
    part("G_bolts_chest", "StoneDark", "spine_03", lambda bm: hex_bolt(bm, V((-0.2, -0.275, 1.47)), 0.045, (0, -1, 0.1)))
    part("G_crack", "Glow", "spine_03", lambda bm: (                   # the lava crack on the lower chest
        rock(bm, V((0.0, -0.262, 1.36)), (0.07, 0.03, 0.06), 0, squareness=0.7, jitter=0.1),
        glow_bar(bm, V((0.0, -0.26, 1.52)), V((0.03, -0.265, 1.43)), 0.035),
        glow_bar(bm, V((0.03, -0.265, 1.43)), V((0.0, -0.265, 1.36)), 0.045),
        glow_bar(bm, V((0.0, -0.265, 1.36)), V((-0.08, -0.255, 1.3)), 0.035),
        glow_bar(bm, V((0.0, -0.265, 1.36)), V((0.07, -0.26, 1.31)), 0.03),
        glow_bar(bm, V((0.0, -0.26, 1.36)), V((-0.1, -0.25, 1.39)), 0.025)))
    part("G_rune_chest", "Glow", "spine_03", lambda bm: strokes(bm, V((0.2, -0.285, 1.45)), 0.12, RUNE_S))
    # Trapezius rocks either side of the neck, low enough that the head still shows.
    part("G_traps", "Stone", "spine_03", lambda bm: [
        rock(bm, V((s * 0.2, 0.08, 1.58)), (0.22, 0.3, 0.16), 8 + (s > 0), rot=(0, s * 14, 0)) for s in (1, -1)])

    # --- head: small, square and pushed forward, a heavy brow over glowing eyes, a jutting jaw -------
    part("G_head", "Stone", "Head", lambda bm: rock(bm, V((0, -0.14, 1.7)), (0.28, 0.27, 0.28), 10, top=0.88))
    part("G_brow", "StoneDark", "Head", lambda bm: rock(bm, V((0, -0.262, 1.757)), (0.32, 0.075, 0.07), 11, squareness=0.8))
    part("G_jaw", "StoneLight", "Head", lambda bm: rock(bm, V((0, -0.23, 1.625)), (0.26, 0.15, 0.12), 12, top=1.1))
    part("G_nose", "StoneLight", "Head", lambda bm: rock(bm, V((0, -0.29, 1.695)), (0.06, 0.06, 0.09), 13))
    part("G_eyes", "Glow", "Head", lambda bm: [
        rock(bm, V((s * 0.068, -0.29, 1.717)), (0.08, 0.024, 0.036), 0, squareness=1.0, jitter=0.0) for s in (1, -1)])

    # --- arms: big upper arms, huge forearms with runes and bolts, heavy fists -----------------------
    for s, side in ((1, "l"), (-1, "r")):
        part(f"G_upperarm_{side}", "Stone", f"upperarm_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.3, 0.06, 1.43)), (0.38, 0.38, 0.38), 20 + s),))
        part(f"G_bicep_{side}", "StoneLight", f"upperarm_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.36, -0.05, 1.47)), (0.26, 0.24, 0.24), 22 + s),))
        part(f"G_forearm_{side}", "Stone", f"lowerarm_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.5, 0.06, 1.43)), (0.2, 0.32, 0.32), 24 + s),
            rock(bm, V((s * 0.63, 0.06, 1.43)), (0.3, 0.46, 0.46), 25 + s)))
        part(f"G_band_{side}", "StoneDark", f"lowerarm_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.755, 0.06, 1.43)), (0.07, 0.48, 0.48), 26 + s, squareness=0.85, jitter=0.02),
            hex_bolt(bm, V((s * 0.52, -0.105, 1.5)), 0.034, (0, -1, 0.3))))
        part(f"G_rune_{side}", "Glow", f"lowerarm_{side}", lambda bm, s=s: strokes(bm, V((s * 0.635, -0.175, 1.43)), 0.13, RUNE_R))
        part(f"G_fist_{side}", "StoneLight", f"hand_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.87, 0.06, 1.43)), (0.26, 0.3, 0.3), 28 + s),
            rock(bm, V((s * 0.98, 0.04, 1.43)), (0.1, 0.28, 0.24), 30 + s)))
        # Legs: stumpy stone pillars, a knee cap, stone boots with a cuff and a toe cap.
        x = s * 0.13
        part(f"G_thigh_{side}", "Stone", f"thigh_{side}", lambda bm, x=x, s=s: rock(bm, V((x, 0.0, 0.74)), (0.32, 0.34, 0.42), 32 + s))
        part(f"G_knee_{side}", "StoneLight", f"calf_{side}", lambda bm, x=x, s=s: rock(bm, V((x, -0.15, 0.53)), (0.2, 0.12, 0.16), 34 + s))
        part(f"G_calf_{side}", "StoneDark", f"calf_{side}", lambda bm, x=x, s=s: (
            rock(bm, V((x, 0.02, 0.37)), (0.29, 0.29, 0.32), 36 + s, top=1.1),
            rock(bm, V((x, 0.0, 0.21)), (0.36, 0.38, 0.08), 50 + s, squareness=0.9, jitter=0.02)))
        part(f"G_foot_{side}", "Stone", f"foot_{side}", lambda bm, x=x, s=s: rock(bm, V((x, -0.06, 0.09)), (0.34, 0.46, 0.2), 38 + s, top=0.85))
        part(f"G_toe_{side}", "StoneLight", f"foot_{side}", lambda bm, x=x, s=s: rock(bm, V((x, -0.26, 0.07)), (0.3, 0.13, 0.13), 52 + s))

    # --- shoulders: big curved plates with hex bolts; a horn on the right (the hammer side) ----------
    for s, side in ((1, "l"), (-1, "r")):
        part(f"G_pauldron_{side}", "StoneDark", f"clavicle_{side}", lambda bm, s=s: (
            rock(bm, V((s * 0.37, 0.04, 1.64)), (0.52, 0.52, 0.28), 40 + s, rot=(0, -s * 16, 0), squareness=0.6),
            rock(bm, V((s * 0.52, 0.04, 1.5)), (0.34, 0.48, 0.16), 43 + s, rot=(0, -s * 38, 0), squareness=0.7)))
        part(f"G_bolts_{side}", "StoneLight", f"clavicle_{side}", lambda bm, s=s: (
            hex_bolt(bm, V((s * 0.42, -0.2, 1.66)), 0.05, (s * 0.25, -1, 0.35)),
            hex_bolt(bm, V((s * 0.6, -0.18, 1.49)), 0.035, (s * 0.5, -1, 0.1))))
    part("G_horn", "StoneLight", "clavicle_r", lambda bm: rk.tube(
        bm, [V((-0.38, 0.06, 1.74)), V((-0.46, 0.05, 1.9)), V((-0.56, 0.04, 2.0))], [(0.1, 0.1), (0.06, 0.06), (0.008, 0.008)], seg=5))

    # --- belt, rune buckle, tattered leather apron ------------------------------------------------
    part("G_belt", "Leather", "pelvis", lambda bm: rk.tube(
        bm, rk.ring_path(V((0, 0.02, 1.03)), 0.3, 0.235, 12), [(0.075, 0.035)] * 12, ref=V((0, 0, 1)), seg=4, closed=True))
    part("G_buckle", "StoneLight", "pelvis", lambda bm: rock(bm, V((0, -0.25, 1.03)), (0.18, 0.06, 0.16), 45, squareness=0.85, jitter=0.02))
    part("G_buckle_rune", "Glow", "pelvis", lambda bm: strokes(bm, V((0, -0.284, 1.03)), 0.1, RUNE_R))
    apron = lambda p: skirt_weights(p)
    part("G_apron", "Apron", apron, lambda bm: (
        sheet(bm, V((0, -0.24, 0.99)), 0.46, 0.42, 0.5, 0.03, 7, 46, curve=0.07),
        sheet(bm, V((0, 0.25, 0.99)), 0.42, 0.36, 0.3, 0.03, 5, 47, curve=0.06, back=True)))
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
