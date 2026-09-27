"""Builds the main character style ("hero") on the Quaternius UAL skeleton: a big head with a
simple happy face, a chunky tunic, big gloves and boots, plus optional parts the game switches
on and off (hair styles, beard, hood, shoulder pads, scarf, cape).

Mesh names tell the game what each part is:
  H_base_*          always shown
  H_ears            hidden under the hood
  H_<slot>_<choice> shown when that choice is picked (e.g. H_hair_long, H_back_cape)
Material names are colour slots the game recolours: Skin, Hair, Main, Second, Accent, Leather.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_hero.py
"""
import math
import os
import sys
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "hero.glb")

COLORS = {  # defaults (sRGB); the game overrides most of these
    "Skin": (0.93, 0.72, 0.56), "Hair": (0.24, 0.15, 0.10), "Face": (0.13, 0.09, 0.08),
    "Blush": (0.95, 0.58, 0.52), "Main": (0.30, 0.38, 0.52), "Second": (0.80, 0.72, 0.56),
    "Accent": (0.62, 0.22, 0.18), "Leather": (0.40, 0.26, 0.16), "Metal": (0.78, 0.74, 0.62),
}

HC = V((0.0, -0.015, 1.75))     # head centre
HR = V((0.175, 0.165, 0.185))   # head radii (big, for the stylised look)
BACK = V((0, 1, 0))             # the character faces -Y
FRONT = V((0, -1, 0))


def on_head(x, z, out=0.002):
    """Point on the front of the head surface at (x, z), pushed out along the normal."""
    dx, dz = (x - HC.x) / HR.x, (z - HC.z) / HR.z
    y = HC.y - HR.y * math.sqrt(max(0.0, 1 - dx * dx - dz * dz))
    n = V(((x - HC.x) / HR.x ** 2, (y - HC.y) / HR.y ** 2, (z - HC.z) / HR.z ** 2)).normalized()
    return V((x, y, z)) + n * out, n


def decal_ellipse(bm, cx, cz, rx, rz, seg=12, out=0.002):
    c = bm.verts.new(on_head(cx, cz, out)[0])
    ring = [bm.verts.new(on_head(cx + rx * math.cos(k * math.tau / seg), cz + rz * math.sin(k * math.tau / seg), out)[0])
            for k in range(seg)]
    for k in range(seg):
        bm.faces.new((c, ring[k], ring[(k + 1) % seg]))


def decal_strip(bm, pts, width, out=0.003):
    left, right = [], []
    for i, (x, z) in enumerate(pts):
        p, n = on_head(x, z, out)
        x0, z0 = pts[max(i - 1, 0)]
        x1, z1 = pts[min(i + 1, len(pts) - 1)]
        t = (on_head(x1, z1, out)[0] - on_head(x0, z0, out)[0]).normalized()
        side = n.cross(t).normalized() * width * 0.5
        left.append(bm.verts.new(p + side))
        right.append(bm.verts.new(p - side))
    for i in range(len(pts) - 1):
        bm.faces.new((left[i], left[i + 1], right[i + 1], right[i]))


def hair_cap(bm):
    rk.blob(bm, V((0, 0.0, 1.765)), (0.19, 0.182, 0.19), 24, 16,
            keep=lambda p: p.z > 1.80 or (p.y > -0.02 and p.z > 1.64))
    # Chunky fringe tufts over the forehead.
    for x in (-0.12, -0.06, 0.0, 0.06, 0.12):
        base, _ = on_head(x, 1.845, 0.012)
        tip, _ = on_head(x * 1.08 + 0.012, 1.78, 0.012)
        rk.tube(bm, [base, (base + tip) / 2, tip], [(0.038, 0.022), (0.028, 0.017), (0.004, 0.004)], ref=V((1, 0, 0)), seg=8)


def hair_long(bm):
    hair_cap(bm)
    rk.tube(bm, [V((0, 0.10, 1.76)), V((0, 0.15, 1.62)), V((0, 0.14, 1.47))],
            [(0.17, 0.08), (0.16, 0.06), (0.12, 0.035)], ref=V((1, 0, 0)), seg=12)


def hair_bun(bm):
    hair_cap(bm)
    rk.blob(bm, V((0, 0.15, 1.88)), (0.07, 0.065, 0.065), 12, 8)


def beard(bm):
    rk.blob(bm, V((0, -0.1, 1.64)), (0.155, 0.1, 0.125), 18, 12,
            keep=lambda p: p.z < 1.71 and p.y < -0.07)
    pts = [on_head(x, 1.694 - 0.02 * (abs(x) / 0.07) ** 2, 0.012)[0] for x in (-0.075, -0.035, 0.0, 0.035, 0.075)]
    rk.tube(bm, pts, [(0.012, 0.012), (0.018, 0.018), (0.02, 0.02), (0.018, 0.018), (0.012, 0.012)], ref=V((0, 0, 1)), seg=8)


def hood(bm):
    def keep(p):
        face_hole = p.y < -0.08 and 1.585 < p.z < 1.845 and abs(p.x) < 0.145
        return not face_hole and p.z > 1.56
    rk.blob(bm, V((0, 0.005, 1.765)), (0.21, 0.2, 0.215), 24, 16, keep=keep)
    rk.tube(bm, [V((0, 0.17, 1.84)), V((0, 0.25, 1.7)), V((0, 0.27, 1.58))], [(0.1, 0.07), (0.055, 0.035), (0.012, 0.012)], ref=V((1, 0, 0)), seg=10)


def hood_mantle(bm):
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.52)), 0.2, 0.17), [(0.06, 0.045)] * 14, ref=V((0, 0, 1)), seg=8, closed=True)


def skirt_weights(p):
    side = "thigh_l" if p.x > 0 else "thigh_r"
    leg = max(0.0, min(0.35, (0.95 - p.z) * 1.1))
    upper = rk.weights_by_distance(["pelvis", "spine_01", "spine_02", "spine_03"])(p)
    out = {k: v * (1 - leg) for k, v in upper.items()}
    out[side] = out.get(side, 0) + leg
    return out


def torso_weights(p):
    if p.z < 0.97:
        return skirt_weights(p)
    return rk.weights_by_distance(["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"])(p)


def build(arm):
    parts = []

    def part(name, mat, weights, builder, **kw):
        parts.append(rk.build_part(arm, name, mat, weights, builder, **kw))

    head = rk.fixed("Head")
    # --- always-on body --------------------------------------------------------------
    part("H_base_head", "Skin", head, lambda bm: rk.blob(bm, HC, HR, 24, 16))
    part("H_base_nose", "Skin", head, lambda bm: rk.blob(bm, on_head(0, 1.708, 0.006)[0], (0.024, 0.02, 0.024), 10, 6))
    part("H_base_eyes", "Face", head, lambda bm: [decal_strip(bm, [(cx + t * 0.028, 1.738 + 0.013 * (1 - t * t)) for t in (-1, -0.6, -0.2, 0.2, 0.6, 1)], 0.012)
                                                   for cx in (-0.064, 0.064)], smooth=False, recalc=False, outward=FRONT)
    part("H_base_blush", "Blush", head, lambda bm: [decal_ellipse(bm, cx, 1.702, 0.03, 0.017) for cx in (-0.1, 0.1)],
         smooth=False, recalc=False, outward=FRONT)
    part("H_ears", "Skin", head, lambda bm: [rk.blob(bm, V((s * 0.17, 0.0, 1.735)), (0.03, 0.04, 0.05), 10, 6) for s in (1, -1)])
    part("H_base_neck", "Skin", rk.weights_by_distance(["spine_03", "neck_01", "Head"]),
         lambda bm: rk.tube(bm, [V((0, 0.005, 1.45)), V((0, 0.0, 1.62))], [(0.055, 0.055)] * 2, seg=10))
    torso = [V((0, 0.02, z)) for z in (0.55, 0.75, 0.95, 1.1, 1.28, 1.42, 1.5, 1.56)]
    torso_r = [(0.27, 0.22), (0.24, 0.19), (0.21, 0.16), (0.19, 0.145), (0.21, 0.155), (0.22, 0.15), (0.15, 0.115), (0.08, 0.07)]
    part("H_base_tunic", "Main", torso_weights, lambda bm: rk.tube(bm, torso, torso_r, seg=18))
    part("H_base_trim", "Second", torso_weights,
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.02, 0.575)), 0.268, 0.218, 18), [(0.03, 0.022)] * 18, ref=V((0, 0, 1)), seg=6, closed=True))
    part("H_base_collar", "Second", rk.weights_by_distance(["spine_03", "neck_01"]),
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.015, 1.5)), 0.15, 0.12), [(0.035, 0.03)] * 14, ref=V((0, 0, 1)), seg=6, closed=True))
    part("H_base_belt", "Leather", rk.weights_by_distance(["pelvis", "spine_01"]),
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.02, 1.0)), 0.2, 0.155, 16), [(0.032, 0.022)] * 16, ref=V((0, 0, 1)), seg=6, closed=True), smooth=False)
    part("H_base_buckle", "Metal", rk.fixed("pelvis"), lambda bm: rk.blob(bm, V((0, -0.14, 1.0)), (0.042, 0.016, 0.036), 8, 6), smooth=False)
    for s, side in ((1, "l"), (-1, "r")):
        arm_bones = [f"clavicle_{side}", f"upperarm_{side}", f"lowerarm_{side}", f"hand_{side}"]
        pts = [V((s * x, 0.066, 1.441)) for x in (0.15, 0.3, 0.466, 0.6, 0.7)]
        part(f"H_base_sleeve_{side}", "Main", rk.weights_by_distance(arm_bones, top=2),
             lambda bm, pts=pts: rk.tube(bm, pts, [(0.088, 0.088), (0.078, 0.078), (0.068, 0.068), (0.064, 0.064), (0.062, 0.062)], ref=V((0, 0, 1)), seg=10))
        cuff = [V((s * x, 0.066, 1.441)) for x in (0.67, 0.74)]
        part(f"H_base_cuff_{side}", "Second", rk.weights_by_distance([f"lowerarm_{side}", f"hand_{side}"], top=2),
             lambda bm, pts=cuff: rk.tube(bm, pts, [(0.074, 0.074)] * 2, ref=V((0, 0, 1)), seg=10))
        part(f"H_base_glove_{side}", "Leather", rk.fixed(f"hand_{side}"),
             lambda bm, s=s: rk.blob(bm, V((s * 0.805, 0.066, 1.438)), (0.088, 0.06, 0.072), 12, 8))
        x = s * 0.089
        part(f"H_base_leg_{side}", "Second", rk.weights_by_distance(["pelvis", f"thigh_{side}", f"calf_{side}"], top=2),
             lambda bm, x=x: rk.tube(bm, [V((x, 0.0, 0.95)), V((x, 0.0, 0.55)), V((x, 0.02, 0.3))], [(0.1, 0.1), (0.085, 0.085), (0.07, 0.07)], seg=10))
        boot = [V((x, 0.03, 0.37)), V((x, 0.03, 0.14)), V((x, -0.02, 0.06)), V((x, -0.14, 0.05)), V((x, -0.22, 0.045))]
        part(f"H_base_boot_{side}", "Leather", rk.weights_by_distance([f"calf_{side}", f"foot_{side}", f"ball_{side}"], top=2),
             lambda bm, pts=boot: rk.tube(bm, pts, [(0.082, 0.082), (0.084, 0.088), (0.088, 0.092), (0.078, 0.06), (0.066, 0.048)], ref=V((1, 0, 0)), seg=10), smooth=False)

    # --- optional parts ----------------------------------------------------------------
    part("H_hair_short", "Hair", head, hair_cap)
    part("H_hair_long", "Hair", rk.weights_by_distance(["Head", "neck_01", "spine_03"], top=2), hair_long)
    part("H_hair_bun", "Hair", head, hair_bun)
    part("H_beard_beard", "Hair", head, beard)
    part("H_head_hood", "Accent", head, hood)
    part("H_head_hood_mantle", "Accent", rk.weights_by_distance(["spine_03", "neck_01", "clavicle_l", "clavicle_r"]), hood_mantle)
    for s, side in ((1, "l"), (-1, "r")):
        part(f"H_shoulders_pads_{side}", "Leather", rk.weights_by_distance([f"clavicle_{side}", f"upperarm_{side}"], top=2),
             lambda bm, s=s: rk.blob(bm, V((s * 0.2, 0.05, 1.47)), (0.115, 0.105, 0.075), 14, 10, keep=lambda p: p.z > 1.43), smooth=False)
    part("H_back_scarf", "Accent", rk.weights_by_distance(["spine_03", "neck_01"]),
         lambda bm: (rk.tube(bm, rk.ring_path(V((0, 0.01, 1.53)), 0.135, 0.125), [(0.055, 0.042)] * 14, ref=V((0, 0, 1)), seg=8, closed=True),
                     rk.tube(bm, [V((0.04, 0.12, 1.52)), V((0.06, 0.18, 1.38)), V((0.07, 0.2, 1.22)), V((0.08, 0.21, 1.08))],
                             [(0.07, 0.02), (0.065, 0.018), (0.06, 0.016), (0.055, 0.015)], ref=V((1, 0, 0)), seg=8)))
    part("H_back_cape", "Accent", rk.weights_by_distance(["spine_03", "spine_02", "spine_01", "pelvis"], top=2),
         lambda bm: rk.tube(bm, [V((0, 0.13, 1.5)), V((0, 0.19, 1.15)), V((0, 0.24, 0.72))], [(0.2, 0.025), (0.25, 0.025), (0.29, 0.03)], ref=V((1, 0, 0)), seg=14))
    return parts


arm = rk.load_rig(RIG)
rk.make_materials(COLORS)
parts = build(arm)


def group_of(o):
    if o.name.startswith("H_base_"):
        return "H_base_" + o.data.materials[0].name   # one mesh per colour
    if o.name.startswith("H_shoulders_pads"):
        return "H_shoulders_pads"
    if o.name.startswith("H_head_hood"):
        return "H_head_hood"
    return None


parts = rk.join_groups(parts, group_of)
print("HERO parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("HERO written", OUT)
