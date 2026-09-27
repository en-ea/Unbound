"""Builds the main character style ("hero") on the Quaternius UAL skeleton: a large head with a
clean simple face, a tunic, gloves and boots in crisp faceted low-poly, plus optional parts the
game switches on and off (faces, cheeks, hair styles, beard, hood, shoulder pads, scarf, cape).

Mesh names tell the game what each part is:
  H_base_*                  always shown
  H_ears                    hidden under the hood
  H_<slot>_<choice>[_extra] shown when that choice is picked (e.g. H_hair_long, H_face_calm_brows)
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
    "Skin": (0.93, 0.72, 0.56), "Hair": (0.24, 0.15, 0.10), "Face": (0.12, 0.09, 0.08),
    "Shine": (1.0, 1.0, 1.0), "Blush": (0.93, 0.6, 0.54), "Main": (0.30, 0.38, 0.52),
    "Second": (0.80, 0.72, 0.56), "Accent": (0.62, 0.22, 0.18), "Leather": (0.40, 0.26, 0.16),
    "Metal": (0.78, 0.74, 0.62),
}

HC = V((0.0, -0.015, 1.735))    # head centre
HR = V((0.158, 0.15, 0.172))    # head radii (large for the stylised read, but not chibi)
JAW = 0.2                       # how much the lower face narrows towards the chin
FRONT = V((0, -1, 0))           # the character faces -Y
Z = HC.z


def head_radius_x(z):
    t = max(0.0, (HC.z - z) / HR.z)
    return HR.x * (1.0 - JAW * t * t)


def on_head(x, z, out=0.002):
    """Point on the front of the head surface at (x, z), pushed out along the normal."""
    rx = head_radius_x(z)
    dx, dz = x / rx, (z - HC.z) / HR.z
    y = HC.y - HR.y * math.sqrt(max(0.0, 1 - dx * dx - dz * dz))
    n = V((x / rx ** 2, (y - HC.y) / HR.y ** 2, (z - HC.z) / HR.z ** 2)).normalized()
    return V((x, y, z)) + n * out, n


def head(bm):
    rk.blob(bm, HC, HR, 24, 16)
    for v in bm.verts:
        v.co.x *= head_radius_x(v.co.z) / HR.x


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


def arc(cx, cz, half_w, rise, n=6):
    """Points along a gentle arc (rise > 0 bows upwards)."""
    return [(cx + t * half_w, cz + rise * (1 - t * t)) for t in [(-1 + 2 * i / (n - 1)) for i in range(n)]]


EYE_X, EYE_Z = 0.058, Z + 0.0
BROW_Z = Z + 0.048
MOUTH_Z = Z - 0.072

# Each face: eyes + mouth (dark), brows (hair colour), optional shine (white).
FACES = {
    "calm": {
        "eyes": lambda bm: [decal_ellipse(bm, s * EYE_X, EYE_Z, 0.015, 0.023) for s in (1, -1)],
        "mouth": lambda bm: decal_strip(bm, arc(0, MOUTH_Z, 0.022, -0.004), 0.008),
        "brows": lambda bm: [decal_strip(bm, arc(s * 0.06, BROW_Z, 0.028, 0.006), 0.011) for s in (1, -1)],
    },
    "happy": {
        "eyes": lambda bm: [decal_strip(bm, arc(s * EYE_X, EYE_Z - 0.006, 0.024, 0.012), 0.011) for s in (1, -1)],
        "mouth": lambda bm: decal_strip(bm, arc(0, MOUTH_Z + 0.004, 0.03, -0.012), 0.009),
        "brows": lambda bm: [decal_strip(bm, arc(s * 0.06, BROW_Z + 0.008, 0.028, 0.008), 0.011) for s in (1, -1)],
    },
    "bright": {
        "eyes": lambda bm: [decal_ellipse(bm, s * EYE_X, EYE_Z, 0.02, 0.029) for s in (1, -1)]
                           + [decal_ellipse(bm, 0, MOUTH_Z, 0.016, 0.011)],
        "shine": lambda bm: [decal_ellipse(bm, s * EYE_X + 0.006, EYE_Z + 0.01, 0.006, 0.007, 8, 0.004) for s in (1, -1)],
        "brows": lambda bm: [decal_strip(bm, arc(s * 0.06, BROW_Z + 0.012, 0.028, 0.01), 0.011) for s in (1, -1)],
    },
    "stern": {
        "eyes": lambda bm: [decal_ellipse(bm, s * EYE_X, EYE_Z - 0.002, 0.02, 0.01) for s in (1, -1)]
                           + [decal_strip(bm, arc(0, MOUTH_Z, 0.022, 0.0), 0.008)],
        "brows": lambda bm: [decal_strip(bm, [(s * 0.032, BROW_Z - 0.01), (s * 0.058, BROW_Z - 0.002), (s * 0.088, BROW_Z + 0.006)], 0.013)
                             for s in (1, -1)],
    },
}


def hair_cap(bm):
    rk.blob(bm, V((0, 0.0, Z + 0.015)), (HR.x + 0.016, HR.y + 0.018, HR.z + 0.006), 20, 12,
            keep=lambda p: p.z > Z + 0.05 or (p.y > -0.02 and p.z > Z - 0.11))
    for x in (-0.11, -0.055, 0.0, 0.055, 0.11):
        base, _ = on_head(x, Z + 0.1, 0.012)
        tip, _ = on_head(x * 1.08 + 0.012, Z + 0.035, 0.012)
        rk.tube(bm, [base, (base + tip) / 2, tip], [(0.036, 0.02), (0.026, 0.016), (0.004, 0.004)], ref=V((1, 0, 0)), seg=6)


def hair_long(bm):
    hair_cap(bm)
    rk.tube(bm, [V((0, 0.09, Z + 0.01)), V((0, 0.14, Z - 0.12)), V((0, 0.13, Z - 0.27))],
            [(0.155, 0.075), (0.145, 0.055), (0.11, 0.032)], ref=V((1, 0, 0)), seg=10)


def hair_bun(bm):
    hair_cap(bm)
    rk.blob(bm, V((0, 0.14, Z + 0.13)), (0.064, 0.06, 0.06), 10, 6)


def beard(bm):
    rk.blob(bm, V((0, -0.09, Z - 0.1)), (0.14, 0.095, 0.115), 16, 10,
            keep=lambda p: p.z < Z - 0.045 and p.y < -0.065)
    pts = [on_head(x, Z - 0.052 - 0.018 * (abs(x) / 0.065) ** 2, 0.012)[0] for x in (-0.068, -0.032, 0.0, 0.032, 0.068)]
    rk.tube(bm, pts, [(0.011, 0.011), (0.016, 0.016), (0.018, 0.018), (0.016, 0.016), (0.011, 0.011)], ref=V((0, 0, 1)), seg=6)


def hood(bm):
    def keep(p):
        face_hole = p.y < HC.y - 0.06 and Z - 0.16 < p.z < Z + 0.095 and abs(p.x) < 0.13
        return not face_hole and p.z > Z - 0.18
    rk.blob(bm, V((0, 0.005, Z + 0.015)), (HR.x + 0.035, HR.y + 0.035, HR.z + 0.03), 20, 12, keep=keep)
    rk.tube(bm, [V((0, 0.155, Z + 0.09)), V((0, 0.23, Z - 0.04)), V((0, 0.25, Z - 0.16))],
            [(0.09, 0.06), (0.05, 0.032), (0.012, 0.012)], ref=V((1, 0, 0)), seg=8)


def hood_mantle(bm):
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.52)), 0.19, 0.16, 12), [(0.055, 0.042)] * 12, ref=V((0, 0, 1)), seg=6, closed=True)


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
    flat = {"smooth": False}      # crisp low-poly facets for clothes and gear

    def part(name, mat, weights, builder, **kw):
        parts.append(rk.build_part(arm, name, mat, weights, builder, **kw))

    headw = rk.fixed("Head")
    decal = {"smooth": False, "recalc": False, "outward": FRONT}
    # --- always-on body ------------------------------------------------------------------
    part("H_base_head", "Skin", headw, head)
    part("H_base_nose", "Skin", headw, lambda bm: rk.blob(bm, on_head(0, Z - 0.03, 0.004)[0], (0.02, 0.022, 0.026), 8, 6))
    part("H_ears", "Skin", headw, lambda bm: [rk.blob(bm, V((s * (HR.x - 0.004), 0.0, Z - 0.012)), (0.026, 0.036, 0.046), 8, 6) for s in (1, -1)])
    part("H_base_neck", "Skin", rk.weights_by_distance(["spine_03", "neck_01", "Head"]),
         lambda bm: rk.tube(bm, [V((0, 0.005, 1.45)), V((0, 0.0, 1.62))], [(0.052, 0.052)] * 2, seg=8))
    torso = [V((0, 0.02, z)) for z in (0.55, 0.75, 0.95, 1.1, 1.28, 1.42, 1.5, 1.56)]
    torso_r = [(0.26, 0.21), (0.235, 0.185), (0.205, 0.155), (0.185, 0.14), (0.205, 0.15), (0.215, 0.145), (0.145, 0.11), (0.078, 0.068)]
    part("H_base_tunic", "Main", torso_weights, lambda bm: rk.tube(bm, torso, torso_r, seg=10), **flat)
    part("H_base_trim", "Second", torso_weights,
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.02, 0.575)), 0.258, 0.208, 10), [(0.028, 0.02)] * 10, ref=V((0, 0, 1)), seg=4, closed=True), **flat)
    part("H_base_collar", "Second", rk.weights_by_distance(["spine_03", "neck_01"]),
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.015, 1.5)), 0.145, 0.115, 10), [(0.032, 0.028)] * 10, ref=V((0, 0, 1)), seg=4, closed=True), **flat)
    part("H_base_belt", "Leather", rk.weights_by_distance(["pelvis", "spine_01"]),
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.02, 1.0)), 0.192, 0.148, 10), [(0.03, 0.02)] * 10, ref=V((0, 0, 1)), seg=4, closed=True), **flat)
    part("H_base_buckle", "Metal", rk.fixed("pelvis"), lambda bm: rk.blob(bm, V((0, -0.135, 1.0)), (0.04, 0.015, 0.034), 6, 4), **flat)
    for s, side in ((1, "l"), (-1, "r")):
        arm_bones = [f"clavicle_{side}", f"upperarm_{side}", f"lowerarm_{side}", f"hand_{side}"]
        pts = [V((s * x, 0.066, 1.441)) for x in (0.15, 0.3, 0.466, 0.6, 0.7)]
        part(f"H_base_sleeve_{side}", "Main", rk.weights_by_distance(arm_bones, top=2),
             lambda bm, pts=pts: rk.tube(bm, pts, [(0.082, 0.082), (0.072, 0.072), (0.063, 0.063), (0.06, 0.06), (0.058, 0.058)], ref=V((0, 0, 1)), seg=8), **flat)
        cuff = [V((s * x, 0.066, 1.441)) for x in (0.67, 0.735)]
        part(f"H_base_cuff_{side}", "Second", rk.weights_by_distance([f"lowerarm_{side}", f"hand_{side}"], top=2),
             lambda bm, pts=cuff: rk.tube(bm, pts, [(0.07, 0.07)] * 2, ref=V((0, 0, 1)), seg=8), **flat)
        part(f"H_base_glove_{side}", "Leather", rk.fixed(f"hand_{side}"),
             lambda bm, s=s: rk.blob(bm, V((s * 0.795, 0.066, 1.438)), (0.074, 0.05, 0.06), 8, 6), **flat)
        x = s * 0.089
        part(f"H_base_leg_{side}", "Second", rk.weights_by_distance(["pelvis", f"thigh_{side}", f"calf_{side}"], top=2),
             lambda bm, x=x: rk.tube(bm, [V((x, 0.0, 0.95)), V((x, 0.0, 0.55)), V((x, 0.02, 0.3))], [(0.095, 0.095), (0.08, 0.08), (0.066, 0.066)], seg=8), **flat)
        boot = [V((x, 0.03, 0.36)), V((x, 0.03, 0.14)), V((x, -0.02, 0.06)), V((x, -0.14, 0.05)), V((x, -0.215, 0.045))]
        part(f"H_base_boot_{side}", "Leather", rk.weights_by_distance([f"calf_{side}", f"foot_{side}", f"ball_{side}"], top=2),
             lambda bm, pts=boot: rk.tube(bm, pts, [(0.078, 0.078), (0.08, 0.084), (0.082, 0.086), (0.072, 0.056), (0.06, 0.044)], ref=V((1, 0, 0)), seg=8), **flat)

    # --- faces ------------------------------------------------------------------------------
    for name, f in FACES.items():
        if "eyes" in f:
            part(f"H_face_{name}", "Face", headw, lambda bm, f=f: (f["eyes"](bm), f.get("mouth", lambda b: None)(bm)), **decal)
        part(f"H_face_{name}_brows", "Hair", headw, f["brows"], **decal)
        if "shine" in f:
            part(f"H_face_{name}_shine", "Shine", headw, f["shine"], **decal)
    part("H_cheeks_blush", "Blush", headw, lambda bm: [decal_ellipse(bm, s * 0.092, Z - 0.035, 0.024, 0.013) for s in (1, -1)], **decal)

    # --- optional parts ----------------------------------------------------------------------
    part("H_hair_short", "Hair", headw, hair_cap, **flat)
    part("H_hair_long", "Hair", rk.weights_by_distance(["Head", "neck_01", "spine_03"], top=2), hair_long, **flat)
    part("H_hair_bun", "Hair", headw, hair_bun, **flat)
    part("H_beard_beard", "Hair", headw, beard, **flat)
    part("H_head_hood", "Accent", headw, hood, **flat)
    part("H_head_hood_mantle", "Accent", rk.weights_by_distance(["spine_03", "neck_01", "clavicle_l", "clavicle_r"]), hood_mantle, **flat)
    for s, side in ((1, "l"), (-1, "r")):
        part(f"H_shoulders_pads_{side}", "Leather", rk.weights_by_distance([f"clavicle_{side}", f"upperarm_{side}"], top=2),
             lambda bm, s=s: rk.blob(bm, V((s * 0.2, 0.05, 1.47)), (0.11, 0.1, 0.07), 10, 8, keep=lambda p: p.z > 1.43), **flat)
    part("H_back_scarf", "Accent", rk.weights_by_distance(["spine_03", "neck_01"]),
         lambda bm: (rk.tube(bm, rk.ring_path(V((0, 0.01, 1.525)), 0.128, 0.118, 12), [(0.05, 0.038)] * 12, ref=V((0, 0, 1)), seg=6, closed=True),
                     rk.tube(bm, [V((0.04, 0.115, 1.52)), V((0.06, 0.175, 1.38)), V((0.07, 0.195, 1.22)), V((0.08, 0.205, 1.08))],
                             [(0.066, 0.018), (0.062, 0.016), (0.057, 0.015), (0.052, 0.014)], ref=V((1, 0, 0)), seg=6)), **flat)
    part("H_back_cape", "Accent", rk.weights_by_distance(["spine_03", "spine_02", "spine_01", "pelvis"], top=2),
         lambda bm: rk.tube(bm, [V((0, 0.13, 1.5)), V((0, 0.19, 1.15)), V((0, 0.24, 0.72))], [(0.2, 0.025), (0.25, 0.025), (0.29, 0.03)], ref=V((1, 0, 0)), seg=10), **flat)
    return parts


def group_of(o):
    if o.name.startswith("H_base_"):
        return "H_base_" + o.data.materials[0].name   # one mesh per colour
    if o.name.startswith("H_shoulders_pads"):
        return "H_shoulders_pads"
    if o.name.startswith("H_head_hood"):
        return "H_head_hood"
    return None


arm = rk.load_rig(RIG)
rk.make_materials(COLORS)
parts = rk.join_groups(build(arm), group_of)
print("HERO parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("HERO written", OUT)
