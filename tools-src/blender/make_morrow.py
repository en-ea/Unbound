"""Builds Morrow, the tall wanderer (the owner's reference: a gaunt figure in a long dusty coat with a high
standing collar and split tails down to the ground, a pale mask-like face with small glowing eyes, holding
a staff topped with a bird skull; the staff is an item, `skull_staff` in make_items.py). On the UAL rig like
the golem, so every UAL animation works. The game makes him tall and thin (Npcs "morrow" scale).

Run: ~/blender-venv/bin/python tools-src/blender/make_morrow.py
"""
import math
import os
import sys
import bpy  # noqa: F401
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "morrow.glb")

COLORS = {
    "Pale": (0.84, 0.78, 0.68), "Coat": (0.52, 0.42, 0.35), "CoatDark": (0.38, 0.3, 0.26), "Lining": (0.3, 0.22, 0.22),
    "Dark": (0.13, 0.11, 0.11), "Sash": (0.44, 0.33, 0.27), "Glow": (1.0, 0.9, 0.62),
}
SHADE = 0.09
FRONT = V((0, -1, 0))


def ring(c, rx, ry, a0, a1, n):
    """Points round an ellipse from angle a0 to a1 (degrees; 0 = front (-Y), 90 = his left (+X))."""
    out = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        out.append(c + V((math.sin(a) * rx, -math.cos(a) * ry, 0)))
    return out


def shell(bm, rows, thick):
    """A thin slab through rows of points (each row a list, all the same length, top to bottom), pushed
    outwards (away from the body's middle line) by `thick`."""
    inner = [[bm.verts.new(p) for p in row] for row in rows]
    outer = []
    for row in rows:
        o = []
        for p in row:
            d = V((p.x, p.y - 0.02, 0))
            d = d.normalized() if d.length > 1e-4 else V((0, -1, 0))
            o.append(bm.verts.new(p + d * thick))
        outer.append(o)
    for i in range(len(rows) - 1):
        for j in range(len(rows[0]) - 1):
            bm.faces.new((outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j]))
            bm.faces.new((inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1], inner[i][j]))
    for i in range(len(rows) - 1):
        for j in (0, len(rows[0]) - 1):
            bm.faces.new((inner[i][j], inner[i + 1][j], outer[i + 1][j], outer[i][j]))
    for i in (0, len(rows) - 1):
        for j in range(len(rows[0]) - 1):
            bm.faces.new((inner[i][j], outer[i][j], outer[i][j + 1], inner[i][j + 1]))


def coat_weights(p):
    """The long coat: stiff at the waist, following the thighs more further down."""
    if p.z > 1.0:
        return rk.weights_by_distance(["pelvis", "spine_01", "spine_02", "spine_03"])(p)
    leg = max(0.0, min(0.75, (1.0 - p.z) * 1.0))
    left = max(0.0, min(1.0, 0.5 + p.x / 0.16))
    return {"pelvis": 1.0 - leg, "thigh_l": leg * left, "thigh_r": leg * (1.0 - left)}


def build(arm):
    parts = []
    flat = {"smooth": False, "shade_var": SHADE}

    def part(name, mat, weights, builder, **kw):
        parts.append(rk.build_part(arm, name, mat, weights, builder, **(flat | kw)))

    headw = rk.fixed("Head")
    torso = rk.weights_by_distance(["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"])

    # --- head: a bald, long, pale face like a mask; high cheekbones, a narrow chin, glowing eyes ----
    def head(bm):
        rk.blob(bm, V((0, -0.01, 1.74)), (0.105, 0.115, 0.15), 8, 7)
        for v in bm.verts:
            if v.co.z < 1.72:                        # the jaw narrows to a small chin
                k = 1.0 - (1.72 - v.co.z) * 2.2
                v.co.x *= k
                v.co.y = -0.01 + (v.co.y + 0.01) * (0.8 + 0.2 * k)
            if v.co.y < -0.08:                       # a flatter, mask-like front
                v.co.y = -0.08 + (v.co.y + 0.08) * 0.45
    part("M_head", "Pale", headw, head)
    part("M_brow", "Pale", headw, lambda bm: rk.tube(bm, [V((-0.07, -0.1, 1.775)), V((0, -0.108, 1.78)), V((0.07, -0.1, 1.775))],
                                                     [(0.016, 0.012)] * 3, ref=V((0, 0, 1)), seg=4))
    part("M_cheeks", "Pale", headw, lambda bm: [rk.blob(bm, V((s * 0.055, -0.085, 1.71)), (0.03, 0.02, 0.03), 5, 3) for s in (1, -1)])
    part("M_nose", "Pale", headw, lambda bm: rk.tube(bm, [V((0, -0.1, 1.76)), V((0, -0.112, 1.715))], [(0.012, 0.012), (0.018, 0.014)], seg=4))
    part("M_sockets", "Dark", headw, lambda bm: [rk.blob(bm, V((s * 0.04, -0.093, 1.748)), (0.026, 0.012, 0.014), 6, 4) for s in (1, -1)])
    part("M_mouth", "Dark", headw, lambda bm: rk.tube(bm, [V((-0.025, -0.1, 1.668)), V((0.025, -0.1, 1.668))], [(0.003, 0.003)] * 2, seg=4))
    part("M_eyes", "Glow", headw, lambda bm: [rk.blob(bm, V((s * 0.04, -0.1, 1.749)), (0.011, 0.006, 0.006), 6, 4) for s in (1, -1)])
    part("M_neck", "Dark", rk.weights_by_distance(["spine_03", "neck_01", "Head"]),
         lambda bm: rk.tube(bm, [V((0, 0.0, 1.45)), V((0, 0.0, 1.62))], [(0.045, 0.045)] * 2, seg=6))

    # --- the coat: a fitted body, a tall collar open at the front, lapels, long split tails -------
    part("M_coat_body", "Coat", torso, lambda bm: rk.tube(
        bm, [V((0, 0.02, 0.96)), V((0, 0.02, 1.12)), V((0, 0.02, 1.3)), V((0, 0.02, 1.46)), V((0, 0.02, 1.52))],
        [(0.17, 0.13), (0.16, 0.12), (0.2, 0.14), (0.22, 0.14), (0.14, 0.1)], ref=V((1, 0, 0)), seg=8))
    collar_w = rk.weights_by_distance(["spine_03", "neck_01"])
    part("M_collar", "Coat", collar_w, lambda bm: shell(bm, [
        ring(V((0, 0.03, 1.9)), 0.27, 0.23, 58, 302, 10),
        ring(V((0, 0.02, 1.72)), 0.18, 0.15, 42, 318, 10),
        ring(V((0, 0.02, 1.5)), 0.15, 0.12, 26, 334, 10)], 0.02))
    part("M_collar_lining", "Lining", collar_w, lambda bm: shell(bm, [
        ring(V((0, 0.03, 1.88)), 0.255, 0.215, 61, 299, 10),
        ring(V((0, 0.02, 1.72)), 0.165, 0.135, 46, 314, 10),
        ring(V((0, 0.02, 1.52)), 0.135, 0.105, 30, 330, 10)], 0.006))
    part("M_lapels", "CoatDark", torso, lambda bm: [shell(bm, [
        [V((s * 0.07, -0.14, 1.52)), V((s * 0.15, -0.12, 1.5))],
        [V((s * 0.03, -0.16, 1.3)), V((s * 0.12, -0.15, 1.34))],
        [V((s * 0.02, -0.15, 1.05)), V((s * 0.05, -0.15, 1.08))]], 0.014) for s in (1, -1)])
    part("M_sash", "Sash", rk.weights_by_distance(["pelvis", "spine_01"]), lambda bm: rk.tube(
        bm, rk.ring_path(V((0, 0.02, 1.0)), 0.185, 0.145, 12), [(0.035, 0.02)] * 12, ref=V((0, 0, 1)), seg=4, closed=True))
    # Tails: the coat splits below the waist into many long strips round the sides and back, parted
    # at the front so the thin legs show. Each strip flares out as it falls, ends in a ragged point at
    # its own length (the longest trail on the ground), and alternates light and dark cloth.
    strips = [(-155, -128, 0.02), (-128, -103, 0.08), (-103, -80, 0.0), (-80, -58, 0.14), (-58, -36, 0.22),
              (36, 58, 0.18), (58, 80, 0.05), (80, 103, 0.1), (103, 128, 0.0), (128, 155, 0.06), (155, 182, 0.03), (182, 205, 0.09)]
    for i, (a0, a1, end) in enumerate(strips):
        def tail(bm, a0=a0, a1=a1, end=end, i=i):
            rows = []
            levels = [(1.02, 0.19, 0.15), (0.78, 0.235, 0.19), (0.54, 0.28, 0.23), (0.3, 0.33, 0.27), (end, 0.38, 0.31)]
            for k, (z, rx, ry) in enumerate(levels):
                narrow = 1.0 - k * 0.07                   # strips thin out and part as they fall
                mid = (a0 + a1) / 2 + (k * 2.5 if a0 > 0 else -k * 2.5)
                rows.append(ring(V((0, 0.02, z)), rx, ry, mid + (a0 - mid) * narrow, mid + (a1 - mid) * narrow, 3))
            last = rows[-1]                               # a ragged pointed hem
            for j, p in enumerate(last):
                p.z -= (0.07 if j in (1, 2) else 0.0) + (0.03 if (i + j) % 2 else 0.0)
            shell(bm, rows, 0.014)
        part(f"M_tail_{i}", "Coat" if i % 2 == 0 else "CoatDark", coat_weights, tail)
    # A dark under-robe showing in the front gap, down to the shins.
    part("M_underrobe", "Lining", coat_weights, lambda bm: shell(bm, [
        ring(V((0, 0.02, 1.0)), 0.17, 0.14, -40, 40, 4),
        ring(V((0, 0.02, 0.62)), 0.2, 0.16, -38, 38, 4),
        ring(V((0, 0.02, 0.42)), 0.22, 0.18, -36, 36, 4)], 0.01))

    # --- arms: long sleeves with wide cuffs, thin pale hands --------------------------------------
    for s, side in ((1, "l"), (-1, "r")):
        arm_bones = [f"clavicle_{side}", f"upperarm_{side}", f"lowerarm_{side}", f"hand_{side}"]
        pts = [V((s * x, 0.066, 1.441)) for x in (0.12, 0.3, 0.47, 0.64)]
        part(f"M_sleeve_{side}", "Coat", rk.weights_by_distance(arm_bones, top=2), lambda bm, pts=pts: rk.tube(
            bm, pts, [(0.075, 0.075), (0.065, 0.065), (0.058, 0.058), (0.062, 0.062)], ref=V((0, 0, 1)), seg=6))
        cuff = [V((s * x, 0.066, 1.441)) for x in (0.62, 0.72)]
        part(f"M_cuff_{side}", "CoatDark", rk.weights_by_distance([f"lowerarm_{side}"], top=1), lambda bm, pts=cuff: rk.tube(
            bm, pts, [(0.07, 0.07), (0.085, 0.085)], ref=V((0, 0, 1)), seg=6))
        part(f"M_hand_{side}", "Pale", rk.fixed(f"hand_{side}"), lambda bm, s=s: rk.tube(
            bm, [V((s * 0.73, 0.066, 1.44)), V((s * 0.8, 0.066, 1.438)), V((s * 0.88, 0.064, 1.43))],
            [(0.04, 0.026), (0.045, 0.028), (0.03, 0.02)], ref=V((0, 0, 1)), seg=6))
        # Legs: thin dark trousers, pointed dark shoes.
        x = s * 0.09
        part(f"M_leg_{side}", "Dark", rk.weights_by_distance(["pelvis", f"thigh_{side}", f"calf_{side}"], top=2), lambda bm, x=x: rk.tube(
            bm, [V((x, 0.0, 0.96)), V((x, 0.0, 0.53)), V((x, 0.02, 0.12))], [(0.07, 0.07), (0.055, 0.055), (0.045, 0.045)], seg=6))
        part(f"M_shoe_{side}", "Dark", rk.weights_by_distance([f"foot_{side}", f"ball_{side}"], top=2), lambda bm, x=x: rk.tube(
            bm, [V((x, 0.05, 0.05)), V((x, -0.08, 0.04)), V((x, -0.2, 0.02))], [(0.05, 0.045), (0.045, 0.035), (0.01, 0.01)], ref=V((0, 0, 1)), seg=6))
    return parts


def group_of(o):
    return "M_" + o.data.materials[0].name


arm = rk.load_rig(RIG)
rk.make_materials(COLORS, roughness=0.9)
parts = rk.join_groups(build(arm), group_of)
print("MORROW parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("MORROW written", OUT)
