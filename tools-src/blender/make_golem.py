"""Builds Brakk, the golem blacksmith, on the Quaternius UAL skeleton (same rig as make_hero.py, so every UAL
animation works). From the owner's reference picture: a hulking V-shaped body of chipped warm-grey
boulders (rk.boulder: bevelled, unevenly cut), a small head pushed forward between big shoulder rocks
(heavy brow, glowing eyes, square jaw), a glowing lava crack and a rune on the chest, blocky abs, huge
forearms with glowing runes and hex bolts, big domed shoulder plates with bolts and a horn on the right
(hammer side), a leather belt with a rune buckle, a tattered leather apron, stumpy legs in stone boots.
Colours are sampled from the picture; soft shadows (cool in the creases) and the warm light from the
lava crack are baked into the model (rk.bake_shading). Every rock is fixed to one bone, so nothing
stretches when he moves. The game scales him up (Npcs "brakk": about 1.6x). Sonnet's first version is
kept as make_golem_v1.py / golem_v1.glb.

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

# Sampled from docs/Builds/characters/golem-smith-brakk-original.png: a warm, slightly mauve grey,
# dark red-brown leather, orange glow. The shadows (cool and dark there) come from bake_shading.
COLORS = {
    "Stone": (0.57, 0.52, 0.47), "StoneDark": (0.44, 0.4, 0.37), "StoneLight": (0.66, 0.61, 0.55),
    "Apron": (0.44, 0.21, 0.14), "Leather": (0.32, 0.15, 0.1), "Glow": (1.0, 0.5, 0.13),
}
SHADE = 0.08


def rock(bm, c, size, seed, rot=(0, 0, 0), squareness=0.75, jitter=0.05, top=1.0):
    """A plain chiselled block (used for the thin glowing strokes): a cube cut once along each edge and
    pulled a little towards a ball, each corner nudged, scaled to `size`, turned by `rot` degrees."""
    rnd = random.Random(seed)
    first = len(bm.verts)                       # new verts are added at the end
    g = bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=list({e for v in g["verts"] for e in v.link_edges}), cuts=1, use_grid_fill=True)
    turn = Euler([math.radians(a) for a in rot]).to_matrix()
    bm.verts.ensure_lookup_table()
    for v in bm.verts[first:]:
        p = v.co.copy()
        p = p.lerp(p.normalized() * 1.2, 1.0 - squareness) * (1.0 + rnd.uniform(-jitter, jitter))
        k = 1.0 + (top - 1.0) * max(p.z, 0.0)
        v.co = c + turn @ V((p.x * size[0] * 0.5 * k, p.y * size[1] * 0.5 * k, p.z * size[2] * 0.5))


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


B = rk.boulder


def build(arm):
    parts = []
    flat = {"smooth": False, "shade_var": SHADE}

    def part(name, mat, bone_or_weights, builder):
        w = rk.fixed(bone_or_weights) if isinstance(bone_or_weights, str) else bone_or_weights
        parts.append(rk.build_part(arm, name, mat, w, builder, **flat))

    # --- torso: a broad upper chest and back, two big pec slabs, blocky abs and obliques ------------
    part("G_chest", "Stone", "spine_03", lambda bm: (
        B(bm, V((0, 0.05, 1.43)), (0.84, 0.5, 0.42), 1, top=0.9),
        B(bm, V((0, 0.17, 1.54)), (0.7, 0.34, 0.3), 2, round=0.45)))
    part("G_pecs", "StoneLight", "spine_03", lambda bm: [
        B(bm, V((s * 0.175, -0.17, 1.45)), (0.36, 0.2, 0.3), 3 + (s > 0), rot=(-6, s * 8, s * 4), round=0.25, chips=4)
        for s in (1, -1)])
    part("G_traps", "Stone", "spine_03", lambda bm: [
        B(bm, V((s * 0.2, 0.08, 1.6)), (0.25, 0.3, 0.17), 8 + (s > 0), rot=(0, s * 14, 0), round=0.45) for s in (1, -1)])
    part("G_belly", "Stone", "spine_02", lambda bm: [
        B(bm, V((0, 0.02, 1.19)), (0.56, 0.42, 0.32), 5, round=0.4)] + [
        B(bm, V((s * 0.26, -0.06, 1.2)), (0.15, 0.3, 0.27), 56 + (s > 0), rot=(0, 0, s * 12), round=0.35) for s in (1, -1)])
    part("G_abs", "StoneLight", "spine_02", lambda bm: [
        B(bm, V((s * 0.095, -0.19, z)), (0.18, 0.11, 0.115), 60 + i, round=0.3, chips=2, n=30)
        for i, (s, z) in enumerate(((1, 1.27), (-1, 1.27), (1, 1.15), (-1, 1.15)))])
    part("G_hips", "StoneDark", "pelvis", lambda bm: B(bm, V((0, 0.02, 0.97)), (0.52, 0.38, 0.22), 7))
    part("G_bolts_chest", "StoneDark", "spine_03", lambda bm: hex_bolt(bm, V((-0.22, -0.268, 1.5)), 0.045, (0, -1, 0.1)))
    part("G_crack", "Glow", "spine_03", lambda bm: (                   # the lava crack on the lower chest
        rock(bm, V((0.0, -0.262, 1.36)), (0.07, 0.03, 0.06), 0, squareness=0.7, jitter=0.1),
        glow_bar(bm, V((0.0, -0.26, 1.52)), V((0.03, -0.265, 1.43)), 0.035),
        glow_bar(bm, V((0.03, -0.265, 1.43)), V((0.0, -0.265, 1.36)), 0.045),
        glow_bar(bm, V((0.0, -0.265, 1.36)), V((-0.08, -0.255, 1.3)), 0.035),
        glow_bar(bm, V((0.0, -0.265, 1.36)), V((0.07, -0.26, 1.31)), 0.03),
        glow_bar(bm, V((0.0, -0.26, 1.36)), V((-0.1, -0.25, 1.39)), 0.025)))
    part("G_rune_chest", "Glow", "spine_03", lambda bm: strokes(bm, V((0.2, -0.275, 1.46)), 0.12, RUNE_S))

    # --- head: small, square and pushed forward, a heavy brow over glowing eyes, a jutting jaw -------
    part("G_head", "Stone", "Head", lambda bm: B(bm, V((0, -0.13, 1.69)), (0.27, 0.27, 0.28), 10, top=0.9, round=0.2))
    part("G_brow", "StoneDark", "Head", lambda bm: B(bm, V((0, -0.258, 1.757)), (0.33, 0.085, 0.075), 11, round=0.2, n=30))
    part("G_jaw", "StoneLight", "Head", lambda bm: B(bm, V((0, -0.222, 1.622)), (0.25, 0.15, 0.12), 12, top=1.1, round=0.25, n=30))
    part("G_nose", "StoneLight", "Head", lambda bm: B(bm, V((0, -0.285, 1.695)), (0.065, 0.065, 0.095), 13, round=0.2, chips=1, n=24))
    part("G_eyes", "Glow", "Head", lambda bm: [
        rock(bm, V((s * 0.068, -0.276, 1.713)), (0.08, 0.024, 0.034), 0, squareness=1.0, jitter=0.0) for s in (1, -1)])

    # --- arms: a round deltoid, bicep, huge forearms with runes and bolts, heavy fists ---------------
    for s, side in ((1, "l"), (-1, "r")):
        part(f"G_upperarm_{side}", "StoneLight", f"upperarm_{side}", lambda bm, s=s: (
            B(bm, V((s * 0.32, 0.04, 1.46)), (0.4, 0.42, 0.4), 20 + s, round=0.55),))
        part(f"G_bicep_{side}", "Stone", f"upperarm_{side}", lambda bm, s=s: (
            B(bm, V((s * 0.42, -0.01, 1.43)), (0.24, 0.3, 0.3), 22 + s, round=0.4),))
        part(f"G_forearm_{side}", "Stone", f"lowerarm_{side}", lambda bm, s=s: (
            B(bm, V((s * 0.62, 0.05, 1.43)), (0.3, 0.46, 0.46), 25 + s, round=0.3, chips=4),))
        part(f"G_elbow_{side}", "StoneDark", f"lowerarm_{side}", lambda bm, s=s: (
            B(bm, V((s * 0.495, 0.07, 1.43)), (0.16, 0.32, 0.32), 24 + s, round=0.4, n=30),
            hex_bolt(bm, V((s * 0.5, -0.09, 1.47)), 0.032, (0, -1, 0.25))))
        part(f"G_band_{side}", "StoneDark", f"lowerarm_{side}", lambda bm, s=s: (
            B(bm, V((s * 0.765, 0.05, 1.43)), (0.08, 0.5, 0.5), 26 + s, round=0.3, chips=1, n=36),))
        part(f"G_rune_{side}", "Glow", f"lowerarm_{side}", lambda bm, s=s: strokes(bm, V((s * 0.625, -0.183, 1.43)), 0.13, RUNE_R))
        part(f"G_fist_{side}", "StoneLight", f"hand_{side}", lambda bm, s=s: (
            B(bm, V((s * 0.875, 0.04, 1.43)), (0.24, 0.32, 0.3), 28 + s, round=0.3),
            B(bm, V((s * 0.99, 0.03, 1.415)), (0.1, 0.3, 0.24), 30 + s, round=0.35, n=30)))
        # Legs: stumpy stone pillars, a knee cap, stone boots with a cuff and a toe cap.
        x = s * 0.13
        part(f"G_thigh_{side}", "Stone", f"thigh_{side}", lambda bm, x=x, s=s: B(bm, V((x, 0.0, 0.74)), (0.33, 0.35, 0.42), 32 + s, round=0.4))
        part(f"G_knee_{side}", "StoneLight", f"calf_{side}", lambda bm, x=x, s=s: B(bm, V((x, -0.15, 0.54)), (0.22, 0.12, 0.17), 34 + s, round=0.3, n=30))
        part(f"G_calf_{side}", "StoneDark", f"calf_{side}", lambda bm, x=x, s=s: (
            B(bm, V((x, 0.02, 0.38)), (0.28, 0.28, 0.3), 36 + s, top=1.1, round=0.4),
            B(bm, V((x, 0.0, 0.22)), (0.38, 0.4, 0.09), 50 + s, round=0.25, chips=2, n=36)))
        part(f"G_foot_{side}", "Stone", f"foot_{side}", lambda bm, x=x, s=s: B(bm, V((x, -0.06, 0.1)), (0.36, 0.48, 0.2), 38 + s, top=0.85, round=0.3))
        part(f"G_toe_{side}", "StoneLight", f"foot_{side}", lambda bm, x=x, s=s: B(bm, V((x, -0.27, 0.075)), (0.3, 0.14, 0.14), 52 + s, round=0.3, n=30))

    # --- shoulders: big domed plates with a flared rim and hex bolts; a horn on the right -------------
    for s, side in ((1, "l"), (-1, "r")):
        part(f"G_pauldron_{side}", "StoneDark", f"clavicle_{side}", lambda bm, s=s: (
            B(bm, V((s * 0.38, 0.04, 1.66)), (0.56, 0.56, 0.26), 40 + s, rot=(0, -s * 18, 0), round=0.55, chips=2, n=56),
            B(bm, V((s * 0.54, 0.04, 1.5)), (0.34, 0.5, 0.16), 43 + s, rot=(0, -s * 40, 0), round=0.4)))
        part(f"G_bolts_{side}", "StoneLight", f"clavicle_{side}", lambda bm, s=s: (
            hex_bolt(bm, V((s * 0.42, -0.21, 1.66)), 0.05, (s * 0.25, -1, 0.35)),
            hex_bolt(bm, V((s * 0.6, -0.19, 1.49)), 0.035, (s * 0.5, -1, 0.1))))
    part("G_horn", "StoneLight", "clavicle_r", lambda bm: rk.tube(
        bm, [V((-0.38, 0.06, 1.74)), V((-0.47, 0.05, 1.9)), V((-0.58, 0.04, 2.01))], [(0.11, 0.11), (0.065, 0.065), (0.008, 0.008)], seg=6))

    # --- belt, rune buckle, tattered leather apron ------------------------------------------------
    part("G_belt", "Leather", "pelvis", lambda bm: rk.tube(
        bm, rk.ring_path(V((0, 0.02, 1.03)), 0.3, 0.235, 12), [(0.075, 0.035)] * 12, ref=V((0, 0, 1)), seg=4, closed=True))
    part("G_buckle", "StoneLight", "pelvis", lambda bm: B(bm, V((0, -0.25, 1.03)), (0.18, 0.06, 0.16), 45, round=0.2, chips=1, n=30))
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
rk.bake_shading(parts)
print("GOLEM parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("GOLEM written", OUT)
