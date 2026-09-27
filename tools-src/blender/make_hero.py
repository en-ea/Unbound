"""Builds the main character style ("hero") on the Quaternius UAL skeleton, in the faceted
low-poly style of the owner's references (Fighter / Explorer / Merchant / Fisherman): chunky
layered clothes with volume, baggy trousers tucked into big boots, bracers, belts and pouches,
thick faceted hair, simple faces, hats, backpacks and big scarves.

Mesh names tell the game what each part is:
  H_base_*                  always shown
  H_ears                    hidden under the hood
  H_<slot>_<choice>[_extra] shown when that choice is picked (e.g. H_top_coat, H_eyes_calm_shine)
  ..._top                   hair parts hidden under any headwear
Material names are colour slots the game recolours (Skin, Hair, Main, Second, Cloth, Accent,
Leather); Face / Shine / Blush / Metal keep their colour. Each face also carries a small shade
variation in its UVs (rigkit.build_part) for a hand-painted faceted look.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_hero.py
"""
import math
import os
import sys
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "hero.glb")

COLORS = {  # defaults (sRGB); the game overrides the slot colours
    "Skin": (0.93, 0.72, 0.56), "Hair": (0.24, 0.15, 0.10), "Face": (0.1, 0.07, 0.07),
    "Shine": (1.0, 1.0, 1.0), "Blush": (0.93, 0.6, 0.54), "Main": (0.42, 0.48, 0.32),
    "Second": (0.3, 0.29, 0.3), "Cloth": (0.85, 0.8, 0.68), "Accent": (0.72, 0.25, 0.2),
    "Leather": (0.5, 0.33, 0.2), "Metal": (0.72, 0.7, 0.66), "Marks": (0.36, 0.22, 0.16),
}

HC = V((0.0, -0.01, 1.72))      # head centre
HR = V((0.145, 0.14, 0.158))    # head radii
JAW = 0.28                      # how much the lower face narrows towards the chin
FRONT = V((0, -1, 0))           # the character faces -Y
Z = HC.z
DECAL = 0.011                   # decals float this far off the faceted head
SHADE = 0.07                    # per-face shade variation on clothes


# --- head surface helpers ---------------------------------------------------------------

def head_radius_x(z):
    t = max(0.0, (HC.z - z) / HR.z)
    return HR.x * (1.0 - JAW * t * t)


def on_head(x, z, out=DECAL):
    """Point on the front of the head surface at (x, z), pushed out along the normal."""
    rx = head_radius_x(z)
    dx, dz = x / rx, (z - HC.z) / HR.z
    y = HC.y - HR.y * math.sqrt(max(0.0, 1 - dx * dx - dz * dz))
    n = V((x / rx ** 2, (y - HC.y) / HR.y ** 2, (z - HC.z) / HR.z ** 2)).normalized()
    return V((x, y, z)) + n * out, n


def around(yaw, pitch, lift=0.0):
    """Point on the head in a direction (yaw 0 = front, 90 = character's left; pitch up)."""
    y, p = math.radians(yaw), math.radians(pitch)
    d = V((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    pt = HC + V((d.x * HR.x, d.y * HR.y, d.z * HR.z))
    n = V(((pt.x - HC.x) / HR.x ** 2, (pt.y - HC.y) / HR.y ** 2, (pt.z - HC.z) / HR.z ** 2)).normalized()
    return pt + n * lift, n


def head(bm):
    rk.blob(bm, HC, HR, 12, 8)
    for v in bm.verts:
        v.co.x *= head_radius_x(v.co.z) / HR.x


def decal_ellipse(bm, cx, cz, rx, rz, seg=10, out=DECAL):
    c = bm.verts.new(on_head(cx, cz, out)[0])
    ring = [bm.verts.new(on_head(cx + rx * math.cos(k * math.tau / seg), cz + rz * math.sin(k * math.tau / seg), out)[0])
            for k in range(seg)]
    for k in range(seg):
        bm.faces.new((c, ring[k], ring[(k + 1) % seg]))


def decal_strip(bm, pts, width, out=DECAL + 0.001):
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


def arc(cx, cz, half_w, rise, n=5):
    return [(cx + t * half_w, cz + rise * (1 - t * t)) for t in [(-1 + 2 * i / (n - 1)) for i in range(n)]]


def lock(bm, base, tip, normal, width, depth, bend=0.01):
    """A chunky faceted lock of hair: wide at the root, pointed at the tip."""
    d = tip - base
    side = d.cross(normal).normalized()
    mid = base + d * 0.5 + normal * bend
    rk.tube(bm, [base, mid, tip], [(width, depth), (width * 0.72, depth * 0.8), (0.004, 0.004)], ref=side, seg=4)


# --- faces ---------------------------------------------------------------------------------

EYE_X, EYE_Z = 0.05, Z + 0.004
BROW_Z = Z + 0.047
MOUTH_Z = Z - 0.07

# Eyes, brows and mouths are separate slots, so faces mix and match.
EYES = {
    "calm": lambda bm: [decal_ellipse(bm, s * EYE_X, EYE_Z, 0.013, 0.021) for s in (1, -1)],
    "happy": lambda bm: [decal_strip(bm, arc(s * EYE_X, EYE_Z - 0.006, 0.022, 0.011), 0.011) for s in (1, -1)],
    "bright": lambda bm: [decal_ellipse(bm, s * EYE_X, EYE_Z, 0.017, 0.026) for s in (1, -1)],
    "narrow": lambda bm: [decal_ellipse(bm, s * EYE_X, EYE_Z - 0.002, 0.016, 0.01) for s in (1, -1)],
    "sleepy": lambda bm: [(decal_ellipse(bm, s * EYE_X, EYE_Z - 0.005, 0.014, 0.011),
                           decal_strip(bm, arc(s * EYE_X, EYE_Z + 0.004, 0.02, 0.004), 0.007)) for s in (1, -1)],
    "fierce": lambda bm: [decal_strip(bm, [(s * 0.033, EYE_Z - 0.006), (s * 0.05, EYE_Z), (s * 0.068, EYE_Z + 0.008)], 0.018) for s in (1, -1)],
}
SHINE = {   # the little white glint, for the eyes that have one
    "calm": lambda bm: [decal_ellipse(bm, s * EYE_X + 0.004, EYE_Z + 0.009, 0.004, 0.005, 6, DECAL + 0.002) for s in (1, -1)],
    "bright": lambda bm: [decal_ellipse(bm, s * EYE_X + 0.005, EYE_Z + 0.01, 0.005, 0.006, 6, DECAL + 0.002) for s in (1, -1)],
    "fierce": lambda bm: [decal_ellipse(bm, s * 0.053, EYE_Z + 0.003, 0.004, 0.004, 6, DECAL + 0.002) for s in (1, -1)],
}
BROWS = {
    "soft": lambda bm: [decal_strip(bm, [(s * 0.028, BROW_Z - 0.002), (s * 0.05, BROW_Z + 0.004), (s * 0.075, BROW_Z)], 0.016) for s in (1, -1)],
    "arched": lambda bm: [decal_strip(bm, arc(s * 0.052, BROW_Z + 0.006, 0.024, 0.007), 0.015) for s in (1, -1)],
    "raised": lambda bm: [decal_strip(bm, arc(s * 0.052, BROW_Z + 0.012, 0.024, 0.009), 0.015) for s in (1, -1)],
    "stern": lambda bm: [decal_strip(bm, [(s * 0.026, BROW_Z - 0.012), (s * 0.052, BROW_Z - 0.003), (s * 0.08, BROW_Z + 0.006)], 0.018) for s in (1, -1)],
    "thick": lambda bm: [decal_strip(bm, [(s * 0.026, BROW_Z - 0.004), (s * 0.05, BROW_Z + 0.002), (s * 0.078, BROW_Z - 0.002)], 0.026) for s in (1, -1)],
}
MOUTHS = {
    "smile": lambda bm: decal_strip(bm, arc(0, MOUTH_Z, 0.02, -0.003), 0.008),
    "grin": lambda bm: decal_strip(bm, arc(0, MOUTH_Z + 0.004, 0.026, -0.011), 0.009),
    "open": lambda bm: decal_ellipse(bm, 0, MOUTH_Z, 0.014, 0.01),
    "flat": lambda bm: decal_strip(bm, arc(0, MOUTH_Z, 0.02, 0.0), 0.008),
    "smirk": lambda bm: decal_strip(bm, [(-0.018, MOUTH_Z + 0.001), (0.0, MOUTH_Z - 0.002), (0.022, MOUTH_Z + 0.007)], 0.008),
}


# --- hair ------------------------------------------------------------------------------------

def cap(bm, front, side, back, lift=0.022):
    def keep(p):
        t = abs(math.atan2(p.x, -(p.y - HC.y))) / math.pi       # 0 front .. 1 back
        line = front + (side - front) * min(t * 2, 1) if t < 0.5 else side + (back - side) * (t - 0.5) * 2
        return p.z > line
    rk.blob(bm, V((0, 0.004, Z + 0.012)), (HR.x + lift, HR.y + lift + 0.004, HR.z + lift * 0.6), 12, 8, keep=keep)


def fringe(bm, xs, top, bottom, sweep=0.0, width=0.05):
    for x in xs:
        base, n = on_head(x, top + 0.02, 0.012)       # rooted inside the cap
        tip, _ = on_head(max(-0.13, min(0.13, x + sweep)), bottom, 0.024)
        lock(bm, base, tip, n, width * 1.3, 0.036)


def side_locks(bm, low, width=0.05):
    for s in (1, -1):
        base, n = around(s * 82, 30, 0.01)
        tip, _ = around(s * 88, low, 0.026)
        lock(bm, base, tip, n, width * 1.3, 0.036)


def back_locks(bm, low, count=4, width=0.06):
    for i in range(count):
        yaw = 180 - 55 + 110 * i / (count - 1)
        base, n = around(yaw, 20, 0.01)
        tip, _ = around(yaw, low, 0.028)
        lock(bm, base, tip, n, width * 1.3, 0.038)


def hair_short(bm):
    cap(bm, Z + 0.07, Z - 0.005, Z - 0.085)
    fringe(bm, (-0.08, -0.025, 0.03, 0.085), Z + 0.105, Z + 0.045, sweep=0.015)
    side_locks(bm, -15)
    back_locks(bm, -35)


def hair_messy_base(bm):
    cap(bm, Z + 0.07, Z - 0.01, Z - 0.09)
    fringe(bm, (-0.085, -0.03, 0.025, 0.08), Z + 0.1, Z + 0.035, sweep=-0.02, width=0.055)
    side_locks(bm, -25)
    back_locks(bm, -40, 5)


def hair_messy_top(bm):
    # Big spiky locks sticking up and out (hidden under hats).
    for yaw, pitch in ((0, 62), (50, 55), (-50, 55), (110, 45), (-110, 45), (180, 50), (150, 35), (-150, 35)):
        base, n = around(yaw, pitch - 12, 0.0)
        out = (n + V((0, 0, 0.6))).normalized()
        lock(bm, base, base + out * 0.12, n.cross(V((0, 0, 1))).normalized().cross(out) if abs(n.z) < 0.99 else V((1, 0, 0)), 0.05, 0.035)


def hair_long(bm):
    cap(bm, Z + 0.07, Z - 0.02, Z - 0.1)
    fringe(bm, (-0.07, -0.015, 0.04), Z + 0.105, Z + 0.045, sweep=0.02)
    for s in (1, -1):
        base, n = around(s * 72, 18, 0.016)
        lock(bm, base, base + V((s * 0.02, 0.015, -0.3)), n, 0.06, 0.03)
    rk.tube(bm, [V((0, 0.085, Z + 0.03)), V((0, 0.135, Z - 0.13)), V((0, 0.12, Z - 0.3))],
            [(0.15, 0.07), (0.14, 0.055), (0.1, 0.03)], ref=V((1, 0, 0)), seg=5)


def hair_ponytail(bm):
    cap(bm, Z + 0.075, Z - 0.005, Z - 0.07)
    fringe(bm, (-0.075, -0.02, 0.04), Z + 0.1, Z + 0.05, sweep=-0.02, width=0.045)
    base = V((0, HC.y + HR.y + 0.012, Z + 0.06))
    rk.tube(bm, [base, base + V((0, 0.03, -0.005))], [(0.035, 0.035)] * 2, ref=V((1, 0, 0)), seg=5)
    rk.tube(bm, [base + V((0, 0.03, 0)), base + V((0, 0.08, -0.1)), base + V((0, 0.07, -0.3))],
            [(0.055, 0.045), (0.05, 0.04), (0.006, 0.006)], ref=V((1, 0, 0)), seg=5)


def hair_bun(bm):
    cap(bm, Z + 0.08, Z - 0.005, Z - 0.07)
    rk.blob(bm, V((0, 0.11, Z + 0.14)), (0.065, 0.06, 0.06), 6, 4)


def hair_braid(bm):
    cap(bm, Z + 0.07, Z - 0.01, Z - 0.08)
    fringe(bm, (-0.07, -0.02, 0.035, 0.08), Z + 0.1, Z + 0.045, sweep=0.012)
    side_locks(bm, -10, 0.045)
    base = V((0, HC.y + HR.y + 0.01, Z - 0.02))
    for i in range(7):                              # a plait of beads down the back
        c = base + V(((0.012 if i % 2 else -0.012), 0.03 + i * 0.006, -0.02 - i * 0.055))
        rk.blob(bm, c, (0.042 - i * 0.003, 0.034, 0.036), 6, 4)
    rk.blob(bm, base + V((0, 0.07, -0.43)), (0.022, 0.02, 0.03), 5, 3)


def hair_mohawk(bm):
    cap(bm, Z + 0.02, Z - 0.03, Z - 0.1, lift=0.006)    # close-cropped sides
    for yaw, pitch, ln in ((0, 38, 0.1), (0, 58, 0.13), (0, 76, 0.15), (180, 80, 0.15), (180, 60, 0.14), (180, 40, 0.12), (180, 20, 0.1)):
        base, n = around(yaw, pitch, 0.0)
        out = (n + V((0, 0.35 if yaw else -0.1, 0.5))).normalized()
        lock(bm, base, base + out * ln, V((1, 0, 0)), 0.04, 0.05)


def hair_swept(bm):
    cap(bm, Z + 0.075, Z - 0.005, Z - 0.085)
    for i, x in enumerate((-0.09, -0.05, -0.01, 0.03)):   # a big fringe swept across to one side
        base, n = on_head(x, Z + 0.125, 0.014)
        tip, _ = on_head(min(0.13, x + 0.1), Z + 0.03 - i * 0.008, 0.028)
        lock(bm, base, tip, n, 0.075, 0.04)
    side_locks(bm, -20)
    back_locks(bm, -38)


def hair_weights(p):
    if p.z > Z - 0.1:
        return {"Head": 1.0}
    return rk.weights_by_distance(["Head", "neck_01", "spine_03"], top=2)(p)


# --- beards ------------------------------------------------------------------------------------

def jaw_shell(bm, low, lift=0.014):
    rk.blob(bm, HC + V((0, -0.004, 0)), (HR.x + lift, HR.y + lift, HR.z + lift * 0.5), 12, 10,
            keep=lambda p: low < p.z < Z - 0.03 and p.y < HC.y - 0.015)
    for v in bm.verts:
        v.co.x *= head_radius_x(v.co.z) / HR.x


def mustache(bm, droop=0.03, width=0.06):
    for s in (1, -1):
        base, n = on_head(s * 0.008, Z - 0.046, 0.018)
        tip, _ = on_head(s * width, Z - 0.046 - droop, 0.02)
        lock(bm, base, tip, n, 0.022, 0.014, 0.004)


def beard_short(bm):
    jaw_shell(bm, Z - 0.18)
    mustache(bm, 0.02, 0.05)


def beard_full(bm):
    jaw_shell(bm, Z - 0.18, 0.02)
    for x in (-0.055, 0.0, 0.055):
        base, n = on_head(x, Z - 0.13, 0.03)
        lock(bm, base, base + V((x * 0.3, -0.03, -0.13)), n, 0.05, 0.03)
    mustache(bm, 0.035, 0.068)


def beard_goatee(bm):
    base, n = on_head(0, Z - 0.1, 0.018)
    lock(bm, base, base + V((0, -0.025, -0.1)), n, 0.04, 0.024)
    mustache(bm, 0.02, 0.045)


def beard_mustache(bm):
    mustache(bm, 0.035, 0.07)


def beard_stubble(bm):
    jaw_shell(bm, Z - 0.165, 0.004)          # a close shadow of beard hugging the jaw


def beard_chinstrap(bm):
    rk.blob(bm, HC + V((0, -0.004, 0)), (HR.x + 0.012, HR.y + 0.012, HR.z + 0.006), 14, 12,
            keep=lambda p: Z - 0.175 < p.z < Z - 0.1 and p.y < HC.y + 0.02)
    for v in bm.verts:
        v.co.x *= head_radius_x(v.co.z) / HR.x


def beard_braided(bm):
    beard_full(bm)
    chin, n = on_head(0, Z - 0.15, 0.03)
    for i in range(5):                        # a braid hanging off the chin
        rk.blob(bm, chin + V((0, -0.035 + i * 0.004, -0.09 - i * 0.042)), (0.03 - i * 0.003, 0.024, 0.03), 6, 4)


# --- body and clothes ------------------------------------------------------------------------

def delete_faces(bm, test):
    """Removes faces whose centre passes `test` (used to open a jacket front or a V-neck)."""
    dead = [f for f in bm.faces if test(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=dead, context="FACES")


def skirt_weights(p, top=0.99):
    # Cloth below the belt follows the nearer leg strongly, so legs don't poke through.
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


# The torso, as rings: (height, x radius, y radius). Garments are shells a bit larger.
SHIRT = [(0.94, 0.18, 0.14), (1.1, 0.172, 0.132), (1.28, 0.195, 0.145), (1.42, 0.205, 0.14), (1.5, 0.14, 0.108), (1.56, 0.075, 0.066)]


def shell(zs_radii, grow, seg=8):
    pts = [V((0, 0.018, z)) for z, rx, ry in zs_radii]
    radii = [(rx + grow, ry + grow) for z, rx, ry in zs_radii]
    return pts, radii


def shirt(bm):
    pts, radii = shell(SHIRT, 0.0)
    rk.tube(bm, pts, radii, seg=8)


def tunic(bm):
    rings = [(0.78, 0.225, 0.18), (0.9, 0.2, 0.158)] + SHIRT[:-1]
    pts, radii = shell(rings, 0.016)
    rk.tube(bm, pts, radii, seg=8, caps=False)
    delete_faces(bm, lambda c: c.y < -0.05 and c.z > 1.33 and abs(c.x) < 0.07)     # V-neck


def jacket(bm):
    rings = [(0.9, 0.205, 0.16)] + SHIRT[:-1]
    pts, radii = shell(rings, 0.024)
    rk.tube(bm, pts, radii, seg=10, caps=False)
    delete_faces(bm, lambda c: c.y < -0.05 and abs(c.x) < 0.045 and c.z < 1.46)    # open front
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.52)), 0.15, 0.125, 10), [(0.04, 0.03)] * 10, ref=V((0, 0, 1)), seg=4, closed=True)


def coat(bm):
    rings = [(0.5, 0.25, 0.2), (0.7, 0.235, 0.185), (0.9, 0.21, 0.163)] + SHIRT[:-1]
    pts, radii = shell(rings, 0.028)
    rk.tube(bm, pts, radii, seg=10, caps=False)
    delete_faces(bm, lambda c: c.y < -0.05 and abs(c.x) < 0.05 and c.z < 1.3)      # open front
    rk.tube(bm, rk.ring_path(V((0, 0.025, 1.5)), 0.16, 0.13, 10), [(0.055, 0.04)] * 10, ref=V((0, 0, 1)), seg=4, closed=True)


def vest(bm):
    rings = [(0.96, 0.19, 0.15)] + SHIRT[1:-1]
    pts, radii = shell(rings, 0.045)
    rk.tube(bm, pts, radii, seg=8, caps=False)
    delete_faces(bm, lambda c: c.y < -0.05 and abs(c.x) < 0.06)                   # open front
    delete_faces(bm, lambda c: abs(c.x) > 0.17 and c.z > 1.3)                       # arm holes


def strap(bm):
    for y_sign in (-1, 1):
        pts = [V((0.16, y_sign * 0.15, 1.46)), V((0.05, y_sign * 0.185, 1.3)), V((-0.08, y_sign * 0.18, 1.12)), V((-0.18, y_sign * 0.15, 1.0))]
        rk.tube(bm, pts, [(0.03, 0.01)] * 4, ref=V((1, 0, 1)), seg=4)
    rk.blob(bm, V((-0.22, -0.02, 0.9)), (0.06, 0.09, 0.08), 6, 4)       # satchel on the hip


def scarf(bm):
    rk.tube(bm, rk.ring_path(V((0, 0.012, 1.53)), 0.13, 0.12, 10), [(0.062, 0.05)] * 10, ref=V((0, 0, 1)), seg=5, closed=True)
    rk.tube(bm, [V((0.05, -0.1, 1.5)), V((0.08, -0.16, 1.4)), V((0.1, -0.17, 1.28))],
            [(0.06, 0.02), (0.055, 0.018), (0.05, 0.016)], ref=V((1, 0, 0)), seg=4)          # tail at the front


def cape(bm):
    rk.tube(bm, [V((0, 0.14, 1.5)), V((0, 0.2, 1.15)), V((0, 0.25, 0.72))], [(0.21, 0.025), (0.26, 0.025), (0.3, 0.03)], ref=V((1, 0, 0)), seg=8)


def backpack(bm):
    rk.tube(bm, [V((0, 0.18, 0.98)), V((0, 0.22, 1.2)), V((0, 0.2, 1.4))], [(0.17, 0.08), (0.18, 0.09), (0.16, 0.08)], ref=V((1, 0, 0)), seg=6)
    for s in (1, -1):
        rk.tube(bm, [V((s * 0.1, 0.14, 1.42)), V((s * 0.11, -0.05, 1.48)), V((s * 0.12, -0.16, 1.3)), V((s * 0.12, -0.14, 1.05))],
                [(0.024, 0.008)] * 4, ref=V((1, 0, 0)), seg=4)                   # shoulder straps


def bedroll(bm):
    rk.tube(bm, [V((-0.22, 0.2, 1.46)), V((0.22, 0.2, 1.46))], [(0.07, 0.07)] * 2, ref=V((0, 0, 1)), seg=6)


def hat(bm):
    # A wide brim with a slight droop, a tapered crown.
    brim = rk.ring_path(V((0, 0.0, Z + 0.1)), 0.29, 0.28, 12)
    ring_in = [bm.verts.new(V((p.x * 0.52, p.y * 0.52 - 0.004, p.z + 0.012))) for p in brim]
    ring_out = [bm.verts.new(V((p.x, p.y, p.z - 0.03))) for p in brim]
    ring_in_b = [bm.verts.new(V((v.co.x, v.co.y, v.co.z - 0.018))) for v in ring_in]
    ring_out_b = [bm.verts.new(V((v.co.x, v.co.y, v.co.z - 0.016))) for v in ring_out]
    n = len(brim)
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((ring_in[k], ring_out[k], ring_out[k2], ring_in[k2]))
        bm.faces.new((ring_in_b[k2], ring_out_b[k2], ring_out_b[k], ring_in_b[k]))
        bm.faces.new((ring_out[k], ring_out_b[k], ring_out_b[k2], ring_out[k2]))
    rk.tube(bm, [V((0, 0.0, Z + 0.1)), V((0, 0.0, Z + 0.2)), V((0, 0.005, Z + 0.25))], [(0.16, 0.155), (0.145, 0.14), (0.11, 0.105)], seg=8)


def hat_band(bm):
    rk.tube(bm, [V((0, 0.0, Z + 0.11)), V((0, 0.0, Z + 0.15))], [(0.162, 0.157), (0.155, 0.15)], seg=8, caps=False)


def headband(bm):
    rk.tube(bm, [V((0, 0.0, Z + 0.045)), V((0, 0.0, Z + 0.085))], [(HR.x + 0.02, HR.y + 0.022)] * 2, seg=10, caps=False)
    for s in (1, -1):
        rk.tube(bm, [V((s * 0.02, HR.y + 0.01, Z + 0.06)), V((s * 0.07, HR.y + 0.05, Z - 0.02)), V((s * 0.09, HR.y + 0.06, Z - 0.1))],
                [(0.025, 0.006)] * 3, ref=V((1, 0, 0)), seg=4)


def bandana(bm):
    """A cloth wrapped over the top of the head, knotted at the back with two tails."""
    rk.blob(bm, HC + V((0, 0.004, 0.004)), (HR.x + 0.03, HR.y + 0.03, HR.z + 0.028), 12, 9, keep=lambda p: p.z > Z + 0.035)
    rk.tube(bm, [V((0, 0.0, Z + 0.03)), V((0, 0.0, Z + 0.07))], [(HR.x + 0.032, HR.y + 0.032)] * 2, seg=10, caps=False)
    knot = V((0, HR.y + 0.035, Z + 0.05))
    rk.blob(bm, knot, (0.03, 0.025, 0.028), 6, 4)
    for s in (1, -1):
        rk.tube(bm, [knot, knot + V((s * 0.04, 0.03, -0.07)), knot + V((s * 0.05, 0.04, -0.13))], [(0.028, 0.006)] * 3, ref=V((1, 0, 0)), seg=4)


def circlet(bm):
    """A thin metal band around the brow."""
    rk.tube(bm, [V((0, 0.0, Z + 0.055)), V((0, 0.0, Z + 0.072))], [(HR.x + 0.016, HR.y + 0.018)] * 2, seg=12, caps=False)


def circlet_gem(bm):
    p, n = on_head(0, Z + 0.066, 0.03)
    rk.tube(bm, [p - n * 0.01, p + n * 0.012], [(0.018, 0.024), (0.008, 0.012)], ref=V((1, 0, 0)), seg=4)


def shoulder(bm, s, size):
    rk.blob(bm, V((s * 0.2, 0.05, 1.46)), size, 8, 6, keep=lambda p: p.z > 1.42)


def build(arm):
    parts = []
    flat = {"smooth": False, "shade_var": SHADE}
    headw = rk.fixed("Head")
    decal = {"smooth": False, "recalc": False, "outward": FRONT}

    def part(name, mat, weights, builder, **kw):
        parts.append(rk.build_part(arm, name, mat, weights, builder, **kw))

    # --- always-on body ------------------------------------------------------------------
    part("H_base_head", "Skin", headw, head, smooth=False, shade_var=0.03)
    part("H_base_nose", "Skin", headw, lambda bm: rk.tube(bm, [on_head(0, Z - 0.012, -0.005)[0], on_head(0, Z - 0.038, 0.022)[0]],
                                                           [(0.018, 0.012), (0.014, 0.01)], ref=V((1, 0, 0)), seg=4), smooth=False)
    part("H_ears", "Skin", headw, lambda bm: [rk.blob(bm, V((s * (HR.x - 0.002), 0.0, Z - 0.01)), (0.024, 0.032, 0.042), 6, 4) for s in (1, -1)], smooth=False)
    part("H_base_neck", "Skin", rk.weights_by_distance(["spine_03", "neck_01", "Head"]),
         lambda bm: rk.tube(bm, [V((0, 0.005, 1.45)), V((0, 0.0, 1.62))], [(0.052, 0.05)] * 2, seg=6), smooth=False)
    part("H_base_shirt", "Cloth", torso_weights, shirt, **flat)
    part("H_base_belt", "Leather", rk.weights_by_distance(["pelvis", "spine_01"]),
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.018, 0.98)), 0.215, 0.172, 10), [(0.034, 0.022)] * 10, ref=V((0, 0, 1)), seg=4, closed=True), **flat)
    part("H_base_buckle", "Metal", rk.fixed("pelvis"), lambda bm: rk.blob(bm, V((0, -0.16, 0.98)), (0.04, 0.014, 0.034), 4, 2), **flat)
    part("H_base_pouches", "Leather", rk.fixed("pelvis"),
         lambda bm: [rk.blob(bm, V((s * 0.19, -0.08, 0.93)), (0.05, 0.035, 0.055), 6, 4) for s in (1, -1)], **flat)
    for s, side in ((1, "l"), (-1, "r")):
        arm_bones = [f"clavicle_{side}", f"upperarm_{side}", f"lowerarm_{side}", f"hand_{side}"]
        pts = [V((s * x, 0.066, 1.441)) for x in (0.14, 0.3, 0.466, 0.58)]
        part(f"H_base_sleeve_{side}", "Main", rk.weights_by_distance(arm_bones, top=2),
             lambda bm, pts=pts: rk.tube(bm, pts, [(0.088, 0.088), (0.078, 0.078), (0.07, 0.07), (0.072, 0.072)], ref=V((0, 0, 1)), seg=6), **flat)
        cuff = [V((s * x, 0.066, 1.441)) for x in (0.56, 0.61)]
        part(f"H_base_cuff_{side}", "Cloth", rk.weights_by_distance([f"lowerarm_{side}"], top=1),
             lambda bm, pts=cuff: rk.tube(bm, pts, [(0.078, 0.078)] * 2, ref=V((0, 0, 1)), seg=6), **flat)
        bracer = [V((s * x, 0.066, 1.441)) for x in (0.6, 0.67, 0.735)]
        part(f"H_base_bracer_{side}", "Leather", rk.weights_by_distance([f"lowerarm_{side}", f"hand_{side}"], top=2),
             lambda bm, pts=bracer: rk.tube(bm, pts, [(0.066, 0.066), (0.07, 0.07), (0.064, 0.064)], ref=V((0, 0, 1)), seg=6), **flat)
        part(f"H_base_hand_{side}", "Skin", rk.fixed(f"hand_{side}"),
             lambda bm, s=s: rk.tube(bm, [V((s * 0.74, 0.066, 1.44)), V((s * 0.8, 0.066, 1.438)), V((s * 0.86, 0.064, 1.43))],
                                     [(0.058, 0.04), (0.062, 0.042), (0.05, 0.036)], ref=V((0, 0, 1)), seg=6), smooth=False)
        x = s * 0.092
        part(f"H_base_leg_{side}", "Second", rk.weights_by_distance(["pelvis", f"thigh_{side}", f"calf_{side}"], top=2),
             lambda bm, x=x: rk.tube(bm, [V((x, 0.0, 0.99)), V((x * 1.08, 0.0, 0.72)), V((x, 0.01, 0.5)), V((x, 0.025, 0.36))],
                                     [(0.115, 0.115), (0.108, 0.108), (0.092, 0.092), (0.082, 0.082)], seg=7), **flat)
        # Feet: tall boots, low shoes (trousers to the ankle) or cloth wraps. Each is a choice.
        calf = rk.weights_by_distance([f"calf_{side}"], top=1)
        foot = rk.weights_by_distance([f"calf_{side}", f"foot_{side}", f"ball_{side}"], top=2)
        boot = [V((x, 0.03, 0.46)), V((x, 0.03, 0.15)), V((x, -0.02, 0.07)), V((x, -0.15, 0.055)), V((x, -0.23, 0.05))]
        part(f"H_feet_boots_{side}", "Leather", foot,
             lambda bm, pts=boot: rk.tube(bm, pts, [(0.098, 0.098), (0.096, 0.1), (0.094, 0.102), (0.085, 0.066), (0.07, 0.05)], ref=V((1, 0, 0)), seg=7), **flat)
        part(f"H_feet_boots_cuff_{side}", "Leather", calf,
             lambda bm, x=x: rk.tube(bm, [V((x, 0.03, 0.42)), V((x, 0.03, 0.5))], [(0.112, 0.112), (0.116, 0.116)], seg=7), **flat)
        part(f"H_feet_shoes_trouser_{side}", "Second", calf,
             lambda bm, x=x: rk.tube(bm, [V((x, 0.025, 0.4)), V((x, 0.03, 0.14))], [(0.085, 0.085), (0.08, 0.08)], seg=7), **flat)
        shoe = [V((x, 0.03, 0.15)), V((x, -0.02, 0.07)), V((x, -0.15, 0.055)), V((x, -0.23, 0.05))]
        for style in ("shoes", "wraps"):
            part(f"H_feet_{style}_shoe_{side}", "Leather", foot,
                 lambda bm, pts=shoe: rk.tube(bm, pts, [(0.074, 0.074), (0.09, 0.098), (0.083, 0.062), (0.068, 0.048)], ref=V((1, 0, 0)), seg=7), **flat)
        part(f"H_feet_wraps_cloth_{side}", "Cloth", calf,
             lambda bm, x=x: rk.tube(bm, [V((x, 0.025, 0.42)), V((x, 0.03, 0.14))], [(0.088, 0.088), (0.078, 0.078)], seg=7), **flat)
        part(f"H_feet_wraps_bands_{side}", "Leather", calf,
             lambda bm, x=x: [rk.tube(bm, [V((x, 0.028, z)), V((x, 0.028, z + 0.025))], [(0.09 - (0.4 - z) * 0.04, 0.09 - (0.4 - z) * 0.04)] * 2, seg=7, caps=False)
                              for z in (0.36, 0.27, 0.18)], **flat)

    # --- faces ------------------------------------------------------------------------------
    for name, fn in EYES.items():
        part(f"H_eyes_{name}", "Face", headw, fn, **decal)
        if name in SHINE:
            part(f"H_eyes_{name}_shine", "Shine", headw, SHINE[name], **decal)
    for name, fn in BROWS.items():
        part(f"H_brows_{name}", "Hair", headw, fn, **decal)
    for name, fn in MOUTHS.items():
        part(f"H_mouth_{name}", "Face", headw, fn, **decal)
    marks = {
        "freckles": lambda bm: [decal_ellipse(bm, s * (0.06 + dx), Z - 0.022 + dz, 0.0045, 0.0045, 5, DECAL + 0.001)
                                for s in (1, -1) for dx, dz in ((0.0, 0.0), (0.018, 0.006), (0.034, -0.004), (0.012, -0.016), (0.028, 0.016))],
        "scar": lambda bm: decal_strip(bm, [(0.028, EYE_Z + 0.05), (0.05, EYE_Z + 0.004), (0.07, EYE_Z - 0.05)], 0.011, DECAL + 0.002),
        "warpaint": lambda bm: [decal_strip(bm, [(s * 0.03, EYE_Z - 0.03 - k * 0.022), (s * 0.085, EYE_Z - 0.045 - k * 0.022)], 0.013, DECAL + 0.002)
                                for s in (1, -1) for k in (0, 1)],
        "stripe": lambda bm: decal_strip(bm, [(-0.05, BROW_Z + 0.04), (-0.05, EYE_Z - 0.06)], 0.02, DECAL + 0.001),
    }
    for name, fn in marks.items():
        part(f"H_marks_{name}", "Marks", headw, fn, **decal)

    def glasses(bm):
        for s in (1, -1):
            c, n = on_head(s * EYE_X, EYE_Z, 0.03)
            ring = [c + V((math.cos(a) * 0.034, 0, math.sin(a) * 0.03)) for a in (k * math.tau / 12 for k in range(12))]
            rk.tube(bm, ring, [(0.006, 0.006)] * 12, ref=V((0, 1, 0)), seg=4, closed=True)
            ear, _ = around(s * 80, 5, 0.012)
            rk.tube(bm, [c + V((s * 0.034, 0, 0.005)), ear], [(0.005, 0.005)] * 2, seg=4)
        l, _ = on_head(0.016, EYE_Z + 0.006, 0.032)
        r, _ = on_head(-0.016, EYE_Z + 0.006, 0.032)
        rk.tube(bm, [l, r], [(0.005, 0.005)] * 2, seg=4)

    def eyepatch(bm):
        c, n = on_head(EYE_X, EYE_Z, 0.016)
        rk.tube(bm, [c - n * 0.004, c + n * 0.01], [(0.03, 0.028), (0.026, 0.024)], ref=V((1, 0, 0)), seg=8)
        pts = [on_head(EYE_X + 0.03, EYE_Z + 0.02, 0.014)[0]] + [around(y, 30 - y * 0.12, 0.012)[0] for y in (60, 100, 140, 180, 220, 260, 300)]
        rk.tube(bm, pts, [(0.009, 0.004)] * len(pts), ref=V((0, 0, 1)), seg=4)

    def earrings(bm):
        for s in (1, -1):
            c = V((s * (HR.x + 0.012), 0.004, Z - 0.066))
            ring = [c + V((0, math.cos(a) * 0.014, math.sin(a) * 0.014 - 0.012)) for a in (k * math.tau / 10 for k in range(10))]
            rk.tube(bm, ring, [(0.0045, 0.0045)] * 10, ref=V((1, 0, 0)), seg=4, closed=True)

    part("H_extra_glasses", "Metal", headw, glasses, **flat)
    part("H_extra_eyepatch", "Leather", headw, eyepatch, **flat)
    part("H_extra_earrings", "Metal", headw, earrings, **flat)
    part("H_cheeks_blush", "Blush", headw, lambda bm: [decal_ellipse(bm, s * 0.085, Z - 0.03, 0.022, 0.012) for s in (1, -1)], **decal)

    # --- hair and beards --------------------------------------------------------------------
    for style, fn in (("short", hair_short), ("messy", hair_messy_base), ("long", hair_long),
                      ("ponytail", hair_ponytail), ("bun", hair_bun), ("braid", hair_braid), ("mohawk", hair_mohawk),
                      ("swept", hair_swept)):
        part(f"H_hair_{style}", "Hair", hair_weights, fn, **flat)
    part("H_hair_messy_top", "Hair", headw, hair_messy_top, **flat)
    for style, fn in (("short", beard_short), ("full", beard_full), ("goatee", beard_goatee), ("mustache", beard_mustache),
                      ("stubble", beard_stubble), ("chinstrap", beard_chinstrap), ("braided", beard_braided)):
        part(f"H_beard_{style}", "Hair", headw, fn, **flat)

    # --- clothes and gear ---------------------------------------------------------------------
    part("H_top_tunic", "Main", torso_weights, tunic, **flat)
    part("H_top_jacket", "Main", torso_weights, jacket, **flat)
    part("H_top_coat", "Main", torso_weights, coat, **flat)
    part("H_chest_strap", "Leather", torso_weights, strap, **flat)
    part("H_chest_vest", "Leather", torso_weights, vest, **flat)
    for s, side in ((1, "l"), (-1, "r")):
        w = rk.weights_by_distance([f"clavicle_{side}", f"upperarm_{side}"], top=2)
        part(f"H_shoulders_pads_{side}", "Leather", w, lambda bm, s=s: shoulder(bm, s, (0.11, 0.1, 0.07)), **flat)
        part(f"H_shoulders_plates_{side}", "Metal", w, lambda bm, s=s: shoulder(bm, s, (0.13, 0.12, 0.085)), **flat)
    neck_w = rk.weights_by_distance(["spine_03", "neck_01", "spine_02"])
    part("H_back_scarf", "Accent", neck_w, scarf, **flat)
    part("H_back_cape", "Accent", rk.weights_by_distance(["spine_03", "spine_02", "spine_01", "pelvis"], top=2), cape, **flat)
    back_w = rk.weights_by_distance(["spine_02", "spine_03"], top=2)
    part("H_back_backpack", "Leather", back_w, backpack, **flat)
    part("H_back_backpack_roll", "Accent", back_w, bedroll, **flat)
    part("H_head_hat", "Accent", headw, hat, **flat)
    part("H_head_hat_band", "Leather", headw, hat_band, **flat)
    part("H_head_band", "Accent", headw, headband, **flat)
    part("H_head_bandana", "Accent", headw, bandana, **flat)
    part("H_head_circlet", "Metal", headw, circlet, **flat)
    part("H_head_circlet_gem", "Accent", headw, circlet_gem, **flat)
    return parts


def group_of(o):
    if o.name.startswith("H_base_"):
        return "H_base_" + o.data.materials[0].name   # one mesh per colour
    for prefix in ("H_shoulders_pads", "H_shoulders_plates"):
        if o.name.startswith(prefix):
            return prefix
    return None


arm = rk.load_rig(RIG)
rk.make_materials(COLORS)
parts = rk.join_groups(build(arm), group_of)
print("HERO parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("HERO written", OUT)
