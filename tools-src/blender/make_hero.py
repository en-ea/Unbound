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
import bpy  # noqa: F401  (first, so bmesh is available when run as the bpy module)
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "hero.glb")

COLORS = {  # defaults (sRGB); the game overrides the slot colours
    "Skin": (0.93, 0.72, 0.56), "Hair": (0.24, 0.15, 0.10), "Face": (0.1, 0.07, 0.07), "Eyes": (0.1, 0.07, 0.07),
    "Shine": (1.0, 1.0, 1.0), "Blush": (0.93, 0.6, 0.54), "Main": (0.42, 0.48, 0.32),
    "Second": (0.3, 0.29, 0.3), "Cloth": (0.85, 0.8, 0.68), "Accent": (0.72, 0.25, 0.2),
    "Leather": (0.5, 0.33, 0.2), "Metal": (0.72, 0.7, 0.66), "Marks": (0.36, 0.22, 0.16),
    # Fixed colours (not recoloured by the game):
    "Gold": (0.95, 0.74, 0.3), "Leaf": (0.36, 0.58, 0.28), "Petal": (0.97, 0.78, 0.84), "Bloom": (0.98, 0.9, 0.5),
    "Straw": (0.9, 0.77, 0.46), "Fur": (0.5, 0.4, 0.3), "Feather": (0.95, 0.94, 0.9), "Potion": (0.35, 0.82, 0.72),
    "Potion2": (0.9, 0.36, 0.42), "Wood": (0.55, 0.38, 0.24),
    "Tobacco": (0.74, 0.52, 0.29), "Tobacco2": (0.6, 0.4, 0.22),
    "MaskWhite": (0.95, 0.93, 0.89), "MaskRed": (0.82, 0.1, 0.12), "Oni": (0.6, 0.07, 0.08), "OniDark": (0.3, 0.03, 0.05),
    "Ivory": (0.93, 0.88, 0.76), "Void": (0.06, 0.06, 0.08), "MaskGlow": (0.45, 0.95, 1.0), "Steel": (0.62, 0.64, 0.68),
    "Raven": (0.13, 0.13, 0.17), "RavenSheen": (0.24, 0.26, 0.36), "LensGlow": (1.0, 0.7, 0.28), "SunGlow": (1.0, 0.86, 0.5), "SunGold": (0.98, 0.7, 0.24),
    "Antler": (0.86, 0.79, 0.66),
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


NOSES = {
    "straight": lambda bm: rk.tube(bm, [on_head(0, Z - 0.012, -0.005)[0], on_head(0, Z - 0.038, 0.022)[0]],
                                   [(0.018, 0.012), (0.014, 0.01)], ref=V((1, 0, 0)), seg=4),
    "button": lambda bm: rk.blob(bm, on_head(0, Z - 0.034, 0.012)[0], (0.017, 0.014, 0.014), 6, 4),
    "long": lambda bm: rk.tube(bm, [on_head(0, Z - 0.005, -0.005)[0], on_head(0, Z - 0.03, 0.02)[0], on_head(0, Z - 0.05, 0.034)[0]],
                               [(0.016, 0.012), (0.015, 0.011), (0.006, 0.006)], ref=V((1, 0, 0)), seg=4),
    "broad": lambda bm: rk.tube(bm, [on_head(0, Z - 0.014, -0.005)[0], on_head(0, Z - 0.04, 0.024)[0]],
                                [(0.024, 0.014), (0.026, 0.013)], ref=V((1, 0, 0)), seg=5),
}


def elf_ears(bm, length, back, out):
    """Pointed ears: a leaf shape from the side of the head, sweeping out, up and back to a tip,
    far enough out to show past the hair."""
    for s in (1, -1):
        base = V((s * (HR.x - 0.004), 0.004, Z - 0.02))
        mid = base + V((s * out * 0.55, back * 0.4, length * 0.4))
        tip = base + V((s * out, back, length))
        rk.tube(bm, [base, mid, tip], [(0.012, 0.03), (0.011, 0.024), (0.003, 0.004)], ref=V((1, 0, 0)), seg=4)


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
    # A crest of separate spikes from the brow over to the back, each leaning back a little.
    for i in range(9):
        t = i / 8
        yaw = 0 if t < 0.5 else 180
        pitch = 30 + t * 120 if t < 0.5 else 150 - (t - 0.5) * 2 * 120
        pitch = min(pitch, 88)
        base, n = around(yaw, pitch, -0.004)
        out = (n + V((0, 0.45, 0.35))).normalized()
        lock(bm, base, base + out * (0.07 + 0.03 * math.sin(math.pi * t)), V((1, 0, 0)), 0.03, 0.045, 0.004)


def hair_swept(bm):
    cap(bm, Z + 0.075, Z - 0.005, Z - 0.085)
    for i, x in enumerate((-0.09, -0.05, -0.01, 0.03)):   # a big fringe swept across to one side
        base, n = on_head(x, Z + 0.125, 0.014)
        tip, _ = on_head(min(0.13, x + 0.1), Z + 0.03 - i * 0.008, 0.028)
        lock(bm, base, tip, n, 0.075, 0.04)
    side_locks(bm, -20)
    back_locks(bm, -38)


def hair_curly(bm):
    """A mop of round curls all over the head."""
    cap(bm, Z + 0.06, Z - 0.02, Z - 0.1)
    for yaw in range(0, 360, 30):
        for pitch in (5, 30, 55):
            if pitch < 20 and (yaw < 50 or yaw > 310):
                continue                                 # keep the face clear
            c, n = around(yaw + (15 if pitch == 30 else 0), pitch, 0.03)
            rk.blob(bm, c, (0.04, 0.04, 0.036), 6, 4)
    c, _ = around(0, 80, 0.035)
    rk.blob(bm, c, (0.05, 0.05, 0.04), 6, 4)
    for x in (-0.06, 0.0, 0.06):                         # curls over the brow
        c, _ = on_head(x, Z + 0.1, 0.03)
        rk.blob(bm, c, (0.035, 0.03, 0.03), 6, 4)


def hair_topknot(bm):
    """Swept back tight, tied in a knot on the crown with a short tail."""
    cap(bm, Z + 0.085, Z - 0.01, Z - 0.08, lift=0.012)
    k = V((0, 0.03, Z + 0.175))
    rk.tube(bm, [k + V((0, 0, -0.03)), k + V((0, 0, 0.01))], [(0.03, 0.03)] * 2, seg=6)
    rk.blob(bm, k + V((0, 0, 0.04)), (0.05, 0.05, 0.045), 7, 5)
    rk.tube(bm, [k + V((0, 0.03, 0.06)), k + V((0, 0.09, 0.03)), k + V((0, 0.12, -0.05))], [(0.035, 0.03), (0.03, 0.025), (0.004, 0.004)], ref=V((1, 0, 0)), seg=5)
    side_locks(bm, -5, 0.035)


def hair_pigtails(bm):
    """A fringe and two bunches tied low at either side."""
    cap(bm, Z + 0.07, Z - 0.01, Z - 0.08)
    fringe(bm, (-0.075, -0.025, 0.025, 0.075), Z + 0.1, Z + 0.045, width=0.05)
    for s in (1, -1):
        root = V((s * 0.125, 0.06, Z - 0.02))
        rk.blob(bm, root, (0.03, 0.03, 0.03), 6, 4)
        rk.tube(bm, [root + V((s * 0.01, 0.01, -0.01)), root + V((s * 0.06, 0.03, -0.12)), root + V((s * 0.05, 0.03, -0.26))],
                [(0.05, 0.045), (0.055, 0.05), (0.006, 0.006)], ref=V((1, 0, 0)), seg=6)


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


def sideburns(bm, low=-35, width=0.03):
    """Strips of beard from the hairline by the ears down to the jaw, so a beard joins the hair."""
    for s in (1, -1):
        top, n = around(s * 84, 22, 0.012)
        mid, _ = around(s * 80, -5, 0.014)
        bottom, _ = around(s * 70, low, 0.016)
        rk.tube(bm, [top, mid, bottom], [(width, 0.012), (width * 1.1, 0.013), (width * 1.2, 0.014)], ref=V((0, 0, 1)), seg=4)


def mustache(bm, droop=0.03, width=0.06):
    for s in (1, -1):
        base, n = on_head(s * 0.008, Z - 0.046, 0.012)
        tip, _ = on_head(s * width, Z - 0.046 - droop, 0.014)
        lock(bm, base, tip, n, 0.022, 0.014, 0.004)


def beard_short(bm):
    jaw_shell(bm, Z - 0.18)
    sideburns(bm, -38, 0.026)
    mustache(bm, 0.02, 0.05)


def beard_full(bm):
    jaw_shell(bm, Z - 0.185, 0.016)
    sideburns(bm, -40, 0.034)
    for x in (-0.05, 0.0, 0.05):                  # locks rooted in the beard, hanging down from the chin
        base, n = on_head(x, Z - 0.12, 0.008)
        lock(bm, base, base + V((x * 0.25, -0.02, -0.12)), n, 0.05, 0.03, 0.006)
    mustache(bm, 0.035, 0.068)


def beard_goatee(bm):
    base, n = on_head(0, Z - 0.1, 0.018)
    lock(bm, base, base + V((0, -0.025, -0.1)), n, 0.04, 0.024)
    mustache(bm, 0.02, 0.045)


def beard_mustache(bm):
    mustache(bm, 0.035, 0.07)


def beard_stubble(bm):
    jaw_shell(bm, Z - 0.165, 0.004)          # a close shadow of beard hugging the jaw, up to the ears


def beard_chinstrap(bm):
    rk.blob(bm, HC + V((0, -0.004, 0)), (HR.x + 0.012, HR.y + 0.012, HR.z + 0.006), 14, 12,
            keep=lambda p: Z - 0.175 < p.z < Z - 0.1 and p.y < HC.y + 0.02)
    for v in bm.verts:
        v.co.x *= head_radius_x(v.co.z) / HR.x
    sideburns(bm, -35, 0.024)


def beard_braided(bm):
    beard_full(bm)
    chin, n = on_head(0, Z - 0.15, 0.012)
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


def wayfarer_hat(bm):
    """A wanderer's hat: a wide brim that droops at front and back, and a tall crooked crown whose
    point bends back over the head."""
    n = 16
    inner, outer, inner_b, outer_b = [], [], [], []
    for k in range(n):
        a = k * math.tau / n
        c, sn = math.cos(a), math.sin(a)
        droop = 0.05 * abs(sn)                       # front and back (along Y) dip down
        inner.append(bm.verts.new(V((c * 0.16, sn * 0.155, Z + 0.105))))
        outer.append(bm.verts.new(V((c * 0.36, sn * 0.34, Z + 0.075 - droop))))
    for v in inner:
        inner_b.append(bm.verts.new(v.co - V((0, 0, 0.018))))
    for v in outer:
        outer_b.append(bm.verts.new(v.co - V((0, 0, 0.016))))
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((inner[k], outer[k], outer[k2], inner[k2]))
        bm.faces.new((inner_b[k2], outer_b[k2], outer_b[k], inner_b[k]))
        bm.faces.new((outer[k], outer_b[k], outer_b[k2], outer[k2]))
    rk.tube(bm, [V((0, 0.0, Z + 0.1)), V((0, 0.01, Z + 0.22)), V((0, 0.035, Z + 0.34)), V((0, 0.09, Z + 0.43)),
                 V((0, 0.17, Z + 0.47)), V((0, 0.24, Z + 0.45))],
            [(0.165, 0.16), (0.13, 0.13), (0.09, 0.09), (0.055, 0.055), (0.028, 0.028), (0.004, 0.004)], seg=10)


def wayfarer_band(bm):
    rk.tube(bm, [V((0, 0.0, Z + 0.11)), V((0, 0.0, Z + 0.155))], [(0.168, 0.163), (0.158, 0.155)], seg=10, caps=False)


def wayfarer_buckle(bm):
    p = V((0.06, -0.155, Z + 0.132))
    rk.tube(bm, [p, p + V((0, -0.018, 0))], [(0.03, 0.026)] * 2, ref=V((1, 0, 0)), seg=4)


def antlers(bm):
    """A pair of branching antlers rising from the temples, each with three tines."""
    for s in (1, -1):
        base, n = around(s * 68, 42, 0.0)
        beam_pts = [base, base + V((s * 0.05, 0.02, 0.09)), base + V((s * 0.11, 0.05, 0.18)), base + V((s * 0.15, 0.1, 0.28)),
                    base + V((s * 0.16, 0.16, 0.36))]
        rk.tube(bm, beam_pts, [(0.024, 0.024), (0.02, 0.02), (0.016, 0.016), (0.011, 0.011), (0.003, 0.003)], seg=6)
        for k, (d, ln) in enumerate(((V((s * 0.02, -0.06, 0.08)), 1.0), (V((s * 0.05, -0.04, 0.09)), 0.9), (V((s * 0.06, 0.0, 0.08)), 0.7))):
            root = beam_pts[k + 1]
            rk.tube(bm, [root, root + d * ln * 0.6, root + d * ln], [(0.012 - k * 0.002, 0.012 - k * 0.002), (0.008, 0.008), (0.002, 0.002)], seg=5)


def antler_band(bm):
    rk.tube(bm, [V((0, 0.0, Z + 0.05)), V((0, 0.0, Z + 0.08))], [(HR.x + 0.02, HR.y + 0.022)] * 2, seg=12, caps=False)


def antler_leaves(bm):
    for s in (1, -1):
        for k, (yaw, pitch) in enumerate(((60, 30), (75, 24), (50, 22))):
            c, n = around(s * yaw, pitch, 0.03)
            rk.blob(bm, c, (0.03, 0.02, 0.018), 5, 3)


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


def robe(bm):
    """A long robe to mid-calf, closed at the front, flaring a little at the hem."""
    rings = [(0.3, 0.27, 0.23), (0.55, 0.245, 0.2), (0.78, 0.225, 0.18), (0.9, 0.2, 0.158)] + SHIRT[:-1]
    pts, radii = shell(rings, 0.022)
    rk.tube(bm, pts, radii, seg=12, caps=False)
    delete_faces(bm, lambda c: c.y < -0.05 and c.z > 1.36 and abs(c.x) < 0.06)     # a small V at the neck


def robe_trim(bm):
    """A band down the front and round the hem, and a collar."""
    rk.tube(bm, [V((0, -0.2, 0.34)), V((0, -0.2, 0.62)), V((0, -0.19, 0.9)), V((0, -0.18, 1.1)), V((0, -0.175, 1.3))],
            [(0.05, 0.012)] * 5, ref=V((1, 0, 0)), seg=4)
    rk.tube(bm, [V((0, 0.018, 0.3)), V((0, 0.018, 0.36))], [(0.3, 0.26), (0.294, 0.253)], seg=12, caps=False)
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.5)), 0.14, 0.12, 10), [(0.035, 0.025)] * 10, ref=V((0, 0, 1)), seg=4, closed=True)


def robe_cuffs(bm, s):
    """Wide bell sleeves over the forearm."""
    rk.tube(bm, [V((s * 0.44, 0.066, 1.441)), V((s * 0.56, 0.066, 1.441)), V((s * 0.62, 0.066, 1.44))],
            [(0.085, 0.085), (0.11, 0.11), (0.125, 0.125)], ref=V((0, 0, 1)), seg=8, caps=False)


def rope_belt(bm):
    rk.tube(bm, rk.ring_path(V((0, 0.018, 1.0)), 0.225, 0.183, 12), [(0.022, 0.022)] * 12, ref=V((0, 0, 1)), seg=5, closed=True)
    knot = V((0.09, -0.19, 0.99))
    rk.blob(bm, knot, (0.03, 0.022, 0.028), 6, 4)
    for dx in (-0.015, 0.02):
        rk.tube(bm, [knot, knot + V((dx, -0.02, -0.12)), knot + V((dx * 1.5, -0.02, -0.26))], [(0.014, 0.014)] * 3, seg=4)
        rk.blob(bm, knot + V((dx * 1.5, -0.02, -0.28)), (0.02, 0.02, 0.03), 5, 3)


def armor(bm):
    """A breastplate over the chest and back, with a raised ridge down the front."""
    rings = [(1.02, 0.225, 0.18), (1.14, 0.215, 0.172), (1.28, 0.235, 0.182), (1.42, 0.23, 0.17), (1.5, 0.16, 0.13)]
    pts = [V((0, 0.018, z)) for z, rx, ry in rings]
    rk.tube(bm, pts, [(rx, ry) for z, rx, ry in rings], seg=10, caps=False)
    delete_faces(bm, lambda c: abs(c.x) > 0.19 and c.z > 1.36)          # arm holes
    rk.tube(bm, [V((0, -0.17, 1.05)), V((0, -0.19, 1.28)), V((0, -0.175, 1.44))], [(0.018, 0.012)] * 3, ref=V((1, 0, 0)), seg=4)


def armor_gorget(bm):
    rk.tube(bm, [V((0, 0.02, 1.48)), V((0, 0.02, 1.56))], [(0.155, 0.135), (0.11, 0.1)], seg=10)


def armor_skirt(bm):
    """A quilted skirt below the breastplate."""
    rings = [(0.66, 0.245, 0.2), (0.8, 0.232, 0.188), (0.96, 0.214, 0.172), (1.04, 0.212, 0.17)]
    pts, radii = shell(rings, 0.004)
    rk.tube(bm, pts, radii, seg=12, caps=False)
    for z in (0.74, 0.86):                              # quilting lines
        rk.tube(bm, [V((0, 0.018, z)), V((0, 0.018, z + 0.014))], [(0.244 - (z - 0.66) * 0.1, 0.2 - (z - 0.66) * 0.09)] * 2, seg=12, caps=False)


def armor_rivets(bm):
    for z in (1.08, 1.22, 1.36):
        for s in (1, -1):
            rk.blob(bm, V((s * 0.1, -0.2 + (z - 1.08) * 0.02, z)), (0.012, 0.01, 0.012), 4, 3)


def tassets(bm):
    """Leather strips hanging from the belt over the skirt."""
    for a in (-0.9, -0.3, 0.3, 0.9, 2.5, 3.1, 3.7):
        c, sn = math.sin(a), -math.cos(a)
        top = V((c * 0.235, 0.018 + sn * 0.19, 0.96))
        bot = V((c * 0.26, 0.018 + sn * 0.215, 0.74))
        out = V((c, sn, 0))
        rk.tube(bm, [top, bot], [(0.055, 0.012), (0.06, 0.012)], ref=out.cross(V((0, 0, 1))).normalized(), seg=4)


def jerkin(bm):
    """A sleeveless jerkin (bare arms), laced at the front, with a fur trim at the shoulders."""
    rings = [(0.82, 0.22, 0.175), (0.92, 0.205, 0.162)] + SHIRT[1:-1]
    pts, radii = shell(rings, 0.02)
    rk.tube(bm, pts, radii, seg=10, caps=False)
    delete_faces(bm, lambda c: abs(c.x) > 0.17 and c.z > 1.33)            # arm holes
    delete_faces(bm, lambda c: c.y < -0.05 and c.z > 1.32 and abs(c.x) < 0.06)


def jerkin_laces(bm):
    for z in (1.12, 1.2, 1.28):
        rk.tube(bm, [V((-0.04, -0.2, z)), V((0.04, -0.2, z + 0.04))], [(0.006, 0.006)] * 2, seg=4)
        rk.tube(bm, [V((0.04, -0.2, z)), V((-0.04, -0.2, z + 0.04))], [(0.006, 0.006)] * 2, seg=4)


def bare_arm(bm, s):
    rk.tube(bm, [V((s * x, 0.066, 1.441)) for x in (0.15, 0.3, 0.46, 0.6)], [(0.07, 0.07), (0.062, 0.062), (0.056, 0.056), (0.054, 0.054)],
            ref=V((0, 0, 1)), seg=6)


def fur_trim(bm):
    """A shaggy fur collar round the jerkin's neck and shoulders."""
    import random
    r = random.Random(7)
    for k in range(16):
        a = (k + r.uniform(-0.3, 0.3)) / 16 * math.tau
        out = V((math.sin(a), -math.cos(a), 0))
        base = V((math.sin(a) * 0.19, 0.02 - math.cos(a) * 0.155, 1.48 + r.uniform(-0.01, 0.01)))
        lock(bm, base, base + out * r.uniform(0.03, 0.05) + V((0, 0, -r.uniform(0.05, 0.08))), out, r.uniform(0.04, 0.05), 0.025, 0.008)


def kilt(bm):
    """A pleated kilt from the belt to the knee."""
    n = 16
    top, bot = [], []
    for k in range(n):
        a = k * math.tau / n
        r = 1.0 + (0.08 if k % 2 else 0.0)                 # pleats
        top.append(V((math.cos(a) * 0.222, 0.018 + math.sin(a) * 0.18, 0.99)))
        bot.append(V((math.cos(a) * 0.27 * r, 0.018 + math.sin(a) * 0.225 * r, 0.6)))
    tv = [bm.verts.new(p) for p in top]
    bv = [bm.verts.new(p) for p in bot]
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((tv[k], tv[k2], bv[k2], bv[k]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)


def kilt_band(bm):
    rk.tube(bm, [V((0, 0.018, 0.64)), V((0, 0.018, 0.68))], [(0.265, 0.22), (0.258, 0.214)], seg=16, caps=False)


def apron(bm):
    """A heavy leather apron from the chest to the knee."""
    rk.tube(bm, [V((0, -0.2, 1.34)), V((0, -0.215, 1.12)), V((0, -0.235, 0.9)), V((0, -0.245, 0.66))],
            [(0.13, 0.012), (0.17, 0.012), (0.2, 0.012), (0.21, 0.012)], ref=V((1, 0, 0)), seg=4)
    for s in (1, -1):
        rk.tube(bm, [V((s * 0.12, -0.19, 1.34)), V((s * 0.09, -0.12, 1.52)), V((0, 0.08, 1.56)), V((-s * 0.02, 0.12, 1.5))], [(0.012, 0.006)] * 4, seg=4)
    rk.tube(bm, [V((0.06, -0.25, 0.92)), V((0.06, -0.26, 1.02))], [(0.06, 0.012)] * 2, ref=V((1, 0, 0)), seg=4)   # a pocket


def tabard(bm):
    """Cloth panels hanging from the belt, front and back."""
    for y, sign in ((-0.2, -1), (0.23, 1)):
        rk.tube(bm, [V((0, y, 1.0)), V((0, y + sign * 0.03, 0.82)), V((0, y + sign * 0.05, 0.58))],
                [(0.11, 0.01), (0.115, 0.01), (0.12, 0.01)], ref=V((1, 0, 0)), seg=4)


def tabard_emblem(bm):
    c = V((0, -0.238, 0.82))
    rk.tube(bm, [c + V((0, 0, -0.07)), c, c + V((0, 0, 0.07))], [(0.002, 0.01), (0.06, 0.01), (0.002, 0.01)], ref=V((1, 0, 0)), seg=4)
    rk.tube(bm, [V((0, -0.24, 0.6)), V((0, -0.245, 0.64))], [(0.12, 0.012)] * 2, ref=V((1, 0, 0)), seg=4)


def sash(bm):
    """A wide cloth sash from the left shoulder to the right hip, knotted there."""
    pts = [V((0.16, -0.1, 1.46)), V((0.06, -0.19, 1.3)), V((-0.08, -0.2, 1.12)), V((-0.2, -0.13, 0.98))]
    rk.tube(bm, pts, [(0.055, 0.012)] * 4, ref=V((1, 0, 1)), seg=4)
    back = [V((0.16, 0.16, 1.46)), V((0.05, 0.2, 1.28)), V((-0.08, 0.19, 1.1)), V((-0.2, 0.13, 0.98))]
    rk.tube(bm, back, [(0.055, 0.012)] * 4, ref=V((1, 0, 1)), seg=4)
    k = V((-0.22, -0.08, 0.96))
    rk.blob(bm, k, (0.04, 0.035, 0.04), 6, 4)
    for dx in (0.0, 0.03):
        rk.tube(bm, [k, k + V((-0.02 + dx, -0.02, -0.1)), k + V((-0.03 + dx, -0.02, -0.19))], [(0.022, 0.008), (0.02, 0.007), (0.004, 0.004)], ref=V((1, 0, 0)), seg=4)


def bandolier(bm):
    pts = [V((-0.16, -0.12, 1.46)), V((-0.05, -0.2, 1.3)), V((0.08, -0.2, 1.12)), V((0.2, -0.12, 0.98))]
    rk.tube(bm, pts, [(0.03, 0.012)] * 4, ref=V((1, 0, 1)), seg=4)
    back = [V((-0.16, 0.16, 1.46)), V((-0.05, 0.2, 1.28)), V((0.08, 0.19, 1.1)), V((0.2, 0.13, 0.98))]
    rk.tube(bm, back, [(0.03, 0.012)] * 4, ref=V((1, 0, 1)), seg=4)


VIALS = [V((-0.09, -0.215, 1.34)), V((-0.015, -0.225, 1.24)), V((0.055, -0.222, 1.15))]


def vials(bm, which):
    for i, c in enumerate(VIALS):
        if i % 2 != which:
            continue
        rk.blob(bm, c, (0.024, 0.02, 0.03), 6, 4)
        rk.tube(bm, [c + V((0, 0, 0.025)), c + V((0, 0, 0.05))], [(0.009, 0.009)] * 2, seg=5)


def vial_corks(bm):
    for c in VIALS:
        rk.tube(bm, [c + V((0, 0, 0.048)), c + V((0, 0, 0.062))], [(0.011, 0.011)] * 2, seg=5)


def fur_mantle(bm):
    """A shaggy fur mantle over the shoulders and round the neck: tufts of different sizes pointing
    down and out, in three loose rings."""
    import random
    r = random.Random(4)
    for ring, (rx, ry, z) in enumerate(((0.17, 0.15, 1.52), (0.21, 0.18, 1.47), (0.245, 0.205, 1.41))):
        n = 14 + ring * 3
        for k in range(n):
            a = (k + r.uniform(-0.3, 0.3)) / n * math.tau
            out = V((math.sin(a), -math.cos(a), 0))
            base = V((math.sin(a) * rx, 0.02 - math.cos(a) * ry, z + r.uniform(-0.015, 0.015)))
            tip = base + out * r.uniform(0.04, 0.07) + V((0, 0, -r.uniform(0.07, 0.12)))
            lock(bm, base, tip, out, r.uniform(0.045, 0.06), 0.03, 0.01)


def pauldron(bm):
    """A big layered pauldron on the left shoulder."""
    for i in range(3):
        c = V((0.2 + i * 0.03, 0.04, 1.49 - i * 0.05))
        rk.blob(bm, c, (0.14 - i * 0.02, 0.13 - i * 0.015, 0.08), 8, 6, keep=lambda p, c=c: p.z > c.z - 0.03)


def pauldron_strap(bm):
    pts = [V((0.16, -0.14, 1.44)), V((0.0, -0.2, 1.3)), V((-0.16, -0.16, 1.22)), V((-0.2, 0.0, 1.2)), V((-0.16, 0.17, 1.24)), V((0.0, 0.2, 1.3)), V((0.16, 0.16, 1.44))]
    rk.tube(bm, pts, [(0.022, 0.008)] * 7, ref=V((0, 0, 1)), seg=4)


def quiver(bm):
    a, b = V((0.14, 0.2, 0.95)), V((-0.08, 0.22, 1.45))
    rk.tube(bm, [a, (a + b) / 2, b], [(0.06, 0.06), (0.065, 0.065), (0.068, 0.068)], seg=8)
    for s in (1, -1):
        rk.tube(bm, [V((s * 0.11, 0.14, 1.42)), V((s * 0.12, -0.08, 1.45)), V((s * 0.13, -0.16, 1.26)), V((s * 0.12, -0.15, 1.05))], [(0.018, 0.008)] * 4, seg=4)


def quiver_arrows(bm):
    d = (V((-0.08, 0.22, 1.45)) - V((0.14, 0.2, 0.95))).normalized()
    for i, off in enumerate((V((0.02, 0, 0)), V((-0.02, 0.01, 0.01)), V((0.0, -0.015, 0.02)), V((0.01, 0.02, -0.01)))):
        base = V((-0.08, 0.22, 1.45)) + off
        rk.tube(bm, [base, base + d * 0.12], [(0.006, 0.006)] * 2, seg=4)


def quiver_fletch(bm):
    d = (V((-0.08, 0.22, 1.45)) - V((0.14, 0.2, 0.95))).normalized()
    for off in (V((0.02, 0, 0)), V((-0.02, 0.01, 0.01)), V((0.0, -0.015, 0.02)), V((0.01, 0.02, -0.01))):
        base = V((-0.08, 0.22, 1.45)) + off + d * 0.09
        rk.tube(bm, [base, base + d * 0.07], [(0.022, 0.004), (0.004, 0.002)], ref=V((1, 0, 0)), seg=4)


SHIELD_C = V((0, 0.25, 1.18))


def shield(bm):
    rk.tube(bm, [SHIELD_C + V((0, -0.02, 0)), SHIELD_C + V((0, 0.02, 0))], [(0.26, 0.26), (0.25, 0.25)], ref=V((1, 0, 0)), seg=14)


def shield_rim(bm):
    ring = [SHIELD_C + V((math.cos(a) * 0.262, 0.026, math.sin(a) * 0.262)) for a in (k * math.tau / 14 for k in range(14))]
    rk.tube(bm, ring, [(0.022, 0.022)] * 14, ref=V((0, 1, 0)), seg=4, closed=True)
    rk.blob(bm, SHIELD_C + V((0, 0.04, 0)), (0.07, 0.04, 0.07), 8, 5)


def shield_band(bm):
    """A painted cross band on the shield."""
    rk.tube(bm, [SHIELD_C + V((0, 0.024, -0.25)), SHIELD_C + V((0, 0.024, 0.25))], [(0.05, 0.004)] * 2, ref=V((1, 0, 0)), seg=4)
    rk.tube(bm, [SHIELD_C + V((-0.25, 0.025, 0)), SHIELD_C + V((0.25, 0.025, 0))], [(0.05, 0.004)] * 2, ref=V((0, 0, 1)), seg=4)


def hood(bm):
    """A hood up over the head (face open), with a point at the back and a cowl on the shoulders."""
    def keep(p):
        face = p.y < HC.y - 0.03 and abs(p.x) < 0.115 and Z - 0.12 < p.z < Z + 0.095
        return not face and p.z > Z - 0.14
    rk.blob(bm, HC + V((0, 0.012, 0.012)), (HR.x + 0.045, HR.y + 0.05, HR.z + 0.045), 14, 10, keep=keep)
    rk.tube(bm, [HC + V((0, HR.y + 0.03, 0.08)), HC + V((0, HR.y + 0.1, 0.02)), HC + V((0, HR.y + 0.15, -0.07))],
            [(0.07, 0.05), (0.04, 0.03), (0.005, 0.005)], ref=V((1, 0, 0)), seg=5)
    rk.tube(bm, [V((0, 0.02, 1.58)), V((0, 0.02, 1.52)), V((0, 0.02, 1.45))], [(0.14, 0.13), (0.2, 0.17), (0.23, 0.19)], seg=12, caps=False)


def helm(bm):
    """A round steel helm with a nose guard and a rim."""
    rk.blob(bm, HC + V((0, 0.005, 0.02)), (HR.x + 0.035, HR.y + 0.035, HR.z + 0.035), 12, 8, keep=lambda p: p.z > Z + 0.03)
    rk.tube(bm, [V((0, 0.005, Z + 0.025)), V((0, 0.005, Z + 0.055))], [(HR.x + 0.045, HR.y + 0.045)] * 2, seg=12, caps=False)
    top, n = on_head(0, Z + 0.05, 0.04)
    rk.tube(bm, [top, on_head(0, Z - 0.035, 0.03)[0]], [(0.016, 0.01), (0.012, 0.008)], ref=V((1, 0, 0)), seg=4)


def helm_crest(bm):
    """A plume along the top of the helm."""
    for i in range(7):
        t = i / 6
        a = math.radians(-40 + t * 170)
        base = V((0, HC.y + math.sin(a) * (HR.y + 0.03), Z + 0.02 + math.cos(a) * (HR.z + 0.04)))
        out = V((0, math.sin(a), math.cos(a)))
        lock(bm, base, base + out * 0.07 + V((0, 0.04, 0)), V((1, 0, 0)), 0.02, 0.03, 0.004)


def soft_cap(bm):
    """A soft cap worn tilted, with a feather."""
    rk.blob(bm, HC + V((0.02, 0.005, 0.1)), (HR.x + 0.045, HR.y + 0.04, 0.07), 12, 6, keep=lambda p: p.z > Z + 0.075)
    rk.tube(bm, [V((0, 0.0, Z + 0.07)), V((0, 0.0, Z + 0.1))], [(HR.x + 0.025, HR.y + 0.025)] * 2, seg=12, caps=False)


def cap_feather(bm):
    base = V((-0.13, 0.03, Z + 0.12))
    rk.tube(bm, [base, base + V((-0.05, 0.08, 0.09)), base + V((-0.04, 0.2, 0.15))], [(0.012, 0.03), (0.016, 0.04), (0.003, 0.006)], ref=V((1, 0, 0)), seg=4)


def crown_leaves(bm):
    for k in range(14):
        a = k * math.tau / 14
        c = V((math.sin(a) * (HR.x + 0.02), HC.y - math.cos(a) * (HR.y + 0.02), Z + 0.07 + 0.01 * math.sin(a * 3)))
        rk.blob(bm, c, (0.03, 0.03, 0.016), 5, 3)
    rk.tube(bm, [V((0, 0.0, Z + 0.065)), V((0, 0.0, Z + 0.075))], [(HR.x + 0.018, HR.y + 0.02)] * 2, seg=12, caps=False)


def crown_flowers(bm, which):
    for k in range(6):
        if k % 2 != which:
            continue
        a = (k - 0.5) * math.tau / 7 - 0.9
        c = V((math.sin(a) * (HR.x + 0.03), HC.y - math.cos(a) * (HR.y + 0.03), Z + 0.085))
        for j in range(5):
            b = j * math.tau / 5
            rk.blob(bm, c + V((math.cos(b) * 0.014, 0, math.sin(b) * 0.014)) + V((0, -0.008 * math.cos(a), 0)), (0.012, 0.008, 0.012), 4, 3)


def straw_hat(bm):
    """A wide conical straw hat."""
    rk.tube(bm, [V((0, 0.0, Z + 0.06)), V((0, 0.0, Z + 0.1)), V((0, 0.0, Z + 0.22)), V((0, 0.0, Z + 0.27))],
            [(0.36, 0.35), (0.3, 0.29), (0.1, 0.1), (0.01, 0.01)], seg=14)
    for r, z in ((0.33, 0.074), (0.24, 0.13), (0.16, 0.18)):                # woven rings
        rk.tube(bm, [V((0, 0.0, Z + z)), V((0, 0.0, Z + z + 0.008))], [(r + 0.006, r + 0.006)] * 2, seg=14, caps=False)


def straw_band(bm):
    rk.tube(bm, [V((0, 0.0, Z + 0.1)), V((0, 0.0, Z + 0.12))], [(0.3, 0.29), (0.28, 0.27)], seg=14, caps=False)
    for s in (1, -1):
        rk.tube(bm, [V((s * 0.12, -0.02, Z + 0.07)), V((s * 0.1, -0.06, Z - 0.1)), V((0, -0.14, Z - 0.17))], [(0.006, 0.006)] * 3, seg=4)


def sun_hat(bm):
    """A huge flat straw hat: a broad brim that droops a little at the edge and a low round crown."""
    n = 16
    z0 = Z + 0.135
    rings = [(0.05, 0.0), (0.2, 0.012), (0.4, -0.004), (0.54, -0.03), (0.64, -0.075)]   # (radius, height offset)
    # The hat sits tipped back: the front of the brim lifts (so the face shows under it), the back dips.
    verts = [[bm.verts.new(V((math.cos(k * math.tau / n) * r, math.sin(k * math.tau / n) * r * 0.97,
                              z0 + dz - 0.04 * math.sin(k * math.tau / n) * (r / 0.64)))) for k in range(n)] for r, dz in rings]
    under = [[bm.verts.new(V((v.co.x, v.co.y, v.co.z - 0.014))) for v in ring] for ring in verts]
    for i in range(len(rings) - 1):
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((verts[i][k], verts[i + 1][k], verts[i + 1][k2], verts[i][k2]))
            bm.faces.new((under[i][k2], under[i + 1][k2], under[i + 1][k], under[i][k]))
    for k in range(n):                                          # the thin rim
        k2 = (k + 1) % n
        bm.faces.new((verts[-1][k], under[-1][k], under[-1][k2], verts[-1][k2]))
    rk.tube(bm, [V((0, 0.0, z0 - 0.02)), V((0, 0.0, z0 + 0.08)), V((0, 0.0, z0 + 0.15)), V((0, 0.0, z0 + 0.19)), V((0, 0.0, z0 + 0.205))],
            [(0.165, 0.16), (0.16, 0.155), (0.148, 0.143), (0.11, 0.106), (0.03, 0.03)], seg=n // 2)   # a rounded crown


def sun_hat_band(bm):
    rk.tube(bm, [V((0, 0.0, Z + 0.15)), V((0, 0.0, Z + 0.21))], [(0.168, 0.163), (0.16, 0.155)], seg=8, caps=False)
    for s in (1, -1):                                               # chin strap
        rk.tube(bm, [V((s * 0.15, -0.01, Z + 0.14)), V((s * 0.11, -0.07, Z - 0.06)), V((0, -0.13, Z - 0.16))], [(0.006, 0.006)] * 3, seg=4)


# Five rows of big pointed leaves (height, radius x, radius y, count, length), each row overlapping the one
# below and flaring out a little more, like the owner's reference (a poncho of tobacco leaves).
LEAF_RINGS = [(1.57, 0.2, 0.17, 7, 0.3), (1.4, 0.25, 0.21, 8, 0.36), (1.25, 0.31, 0.26, 9, 0.4),
              (1.09, 0.35, 0.29, 10, 0.42), (0.93, 0.37, 0.31, 11, 0.4)]


def leaf(bm, base, tip, out, width):
    """One big pointed leaf, folded a little along its middle: narrow at the stem, widest a third of the way down."""
    d = tip - base
    side = d.cross(out).normalized()
    mid1, mid2 = base + d * 0.35 + out * 0.02, base + d * 0.7 + out * 0.03
    rk.tube(bm, [base, mid1, mid2, tip], [(width * 0.3, 0.012), (width, 0.02), (width * 0.6, 0.016), (0.004, 0.004)], ref=side, seg=4)


def leaf_spots():
    """Where every leaf goes: (row, base, tip, out, width), the same for leaves and their midribs."""
    import random
    r = random.Random(12)
    out_list = []
    for row, (z, rx, ry, n, length) in enumerate(LEAF_RINGS):
        for k in range(n):
            a = (k + 0.5 * (row % 2) + r.uniform(-0.1, 0.1)) / n * math.tau
            out = V((math.sin(a), -math.cos(a), 0)).normalized()
            base = V((math.sin(a) * rx, 0.018 - math.cos(a) * ry, z))
            tip = base + out * (0.07 + row * 0.02) + V((0, 0, -length * r.uniform(0.9, 1.1)))
            out_list.append((row, base, tip, out, 0.14 + row * 0.012))
    return out_list


def leaf_cloak(bm, dark):
    """A poncho of overlapping tobacco leaves in rows from the shoulders to the thighs. `dark` picks every other row."""
    for row, base, tip, out, width in leaf_spots():
        if (row % 2 == 1) == dark:
            leaf(bm, base, tip, out, width)


def leaf_ribs(bm):
    """A darker vein down the middle of each leaf."""
    for row, base, tip, out, width in leaf_spots():
        d = tip - base
        pts = [base + out * 0.012, base + d * 0.35 + out * 0.034, base + d * 0.7 + out * 0.04, tip + out * 0.008]
        rk.tube(bm, pts, [(0.007, 0.007), (0.006, 0.006), (0.005, 0.005), (0.002, 0.002)], seg=4)


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
    for name, fn in NOSES.items():
        part(f"H_nose_{name}", "Skin", headw, fn, smooth=False)
    part("H_ears", "Skin", headw, lambda bm: [rk.blob(bm, V((s * (HR.x - 0.002), 0.0, Z - 0.01)), (0.024, 0.032, 0.042), 6, 4) for s in (1, -1)], smooth=False)
    part("H_ears_pointed", "Skin", headw, lambda bm: elf_ears(bm, 0.06, 0.03, 0.06), smooth=False)
    part("H_ears_long", "Skin", headw, lambda bm: elf_ears(bm, 0.09, 0.06, 0.11), smooth=False)
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
        part(f"H_eyes_{name}", "Eyes", headw, fn, **decal)
        if name in SHINE:
            part(f"H_eyes_{name}_shine", "Shine", headw, SHINE[name], **decal)
    for name, fn in BROWS.items():
        part(f"H_brows_{name}", "Hair", headw, fn, **decal)
    for name, fn in MOUTHS.items():
        part(f"H_mouth_{name}", "Face", headw, fn, **decal)
    marks = {
        "freckles": lambda bm: [decal_ellipse(bm, s * (0.06 + dx), Z - 0.022 + dz, 0.0045, 0.0045, 5, DECAL + 0.001)
                                for s in (1, -1) for dx, dz in ((0.0, 0.0), (0.018, 0.006), (0.034, -0.004), (0.012, -0.016), (0.028, 0.016))],
        "scar": lambda bm: [decal_strip(bm, [(0.04, EYE_Z - 0.035), (0.066, EYE_Z - 0.06), (0.09, EYE_Z - 0.078)], 0.01, DECAL + 0.002),
                            decal_strip(bm, [(0.058, EYE_Z - 0.066), (0.076, EYE_Z - 0.05)], 0.008, DECAL + 0.003)],   # a cheek scar with a stitch
        "warpaint": lambda bm: [decal_strip(bm, [(s * 0.03, EYE_Z - 0.03 - k * 0.022), (s * 0.085, EYE_Z - 0.045 - k * 0.022)], 0.013, DECAL + 0.002)
                                for s in (1, -1) for k in (0, 1)],
        "eyestripe": lambda bm: decal_strip(bm, [(-0.05, BROW_Z + 0.04), (-0.05, EYE_Z - 0.06)], 0.02, DECAL + 0.001),
        "mask": lambda bm: decal_strip(bm, [(-0.11, EYE_Z + 0.002), (-0.075, EYE_Z + 0.012), (-0.04, EYE_Z + 0.012), (0.0, EYE_Z + 0.004),
                                            (0.04, EYE_Z + 0.012), (0.075, EYE_Z + 0.012), (0.11, EYE_Z + 0.002)], 0.052, DECAL - 0.003),
        "tears": lambda bm: [decal_strip(bm, [(s * dx, EYE_Z - 0.026), (s * (dx + 0.002), EYE_Z - 0.026 - ln)], 0.01, DECAL + 0.002)
                             for s in (1, -1) for dx, ln in ((0.043, 0.06), (0.06, 0.04))],
        "claws": lambda bm: [decal_strip(bm, [(0.032 + k * 0.02, EYE_Z - 0.012), (0.05 + k * 0.02, EYE_Z - 0.05), (0.062 + k * 0.02, EYE_Z - 0.09)], 0.009, DECAL + 0.002)
                             for k in range(3)],
        "dots": lambda bm: [decal_ellipse(bm, s * (0.045 + k * 0.021), EYE_Z - 0.04 - k * 0.006, 0.009, 0.009, 6, DECAL + 0.002)
                            for s in (1, -1) for k in range(3)],
        "chin": lambda bm: [decal_strip(bm, [(x, MOUTH_Z - 0.018), (x * 1.2, MOUTH_Z - 0.075)], 0.011, DECAL + 0.002) for x in (-0.024, 0.0, 0.024)],
        "noseband": lambda bm: decal_strip(bm, [(-0.11, EYE_Z - 0.04), (-0.055, EYE_Z - 0.03), (0.0, EYE_Z - 0.027), (0.055, EYE_Z - 0.03), (0.11, EYE_Z - 0.04)], 0.02, DECAL + 0.001),
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

    # --- masks: a plate over the face (following the head), plus each mask's own pieces ----------
    def plate(bm, lo, hi, lift=0.02, thick=0.014, yaw=80):
        """A face plate from yaw -`yaw` to `yaw` (degrees round the head) and pitch lo(yaw) to hi(yaw)."""
        cols, rows = 12, 7
        grid = []
        for i in range(cols + 1):
            yw = -yaw + 2 * yaw * i / cols
            col = []
            for j in range(rows + 1):
                pt = lo(yw) + (hi(yw) - lo(yw)) * j / rows
                a, _ = around(yw, pt, lift)
                b, _ = around(yw, pt, lift + thick)
                col.append((bm.verts.new(a), bm.verts.new(b)))
            grid.append(col)
        for i in range(cols):
            for j in range(rows):
                q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
                bm.faces.new([v[1] for v in q])
                bm.faces.new([v[0] for v in reversed(q)])
        for i in range(cols):                       # top and bottom edges
            for j in (0, rows):
                a, b = grid[i][j], grid[i + 1][j]
                bm.faces.new((a[0], b[0], b[1], a[1]))
        for i in (0, cols):                         # side edges
            for j in range(rows):
                a, b = grid[i][j], grid[i][j + 1]
                bm.faces.new((a[0], b[0], b[1], a[1]))

    def on(yaw, pitch, lift):
        return around(yaw, pitch, lift)[0]

    def line(bm, pts, r, flat_r=None):
        rk.tube(bm, pts, [(r, flat_r or r)] * len(pts), seg=4)

    # Kitsune: a white fox face with a pointed snout, tall ears, red swirls and slanted black eyes.
    kit_lo = lambda yw: -50 + abs(yw) * 0.15
    kit_hi = lambda yw: 44 - abs(yw) * 0.1
    part("H_mask_kitsune", "MaskWhite", headw, lambda bm: (
        plate(bm, kit_lo, kit_hi),
        rk.tube(bm, [on(0, -8, 0.03), V((0, HC.y - HR.y - 0.07, Z - 0.035)), V((0, HC.y - HR.y - 0.12, Z - 0.05))],
                [(0.05, 0.04), (0.03, 0.025), (0.008, 0.008)], ref=V((0, 0, 1)), seg=6),
        [rk.tube(bm, [on(s * 38, 50, 0.0), V((s * 0.12, -0.05, Z + 0.24)), V((s * 0.14, -0.04, Z + 0.33))],
                 [(0.055, 0.025), (0.035, 0.018), (0.004, 0.004)], ref=V((1, 0, 0)), seg=4) for s in (1, -1)]), **flat)
    part("H_mask_kitsune_red", "MaskRed", headw, lambda bm: [(
        line(bm, [on(s * 6, 22, 0.036), on(s * 20, 30, 0.036), on(s * 38, 25, 0.036)], 0.008),
        line(bm, [on(s * 34, -6, 0.036), on(s * 52, -12, 0.036)], 0.007),
        line(bm, [on(s * 36, -16, 0.036), on(s * 54, -22, 0.036)], 0.007),
        rk.tube(bm, [V((s * 0.105, -0.06, Z + 0.22)), V((s * 0.13, -0.052, Z + 0.3))], [(0.02, 0.008), (0.003, 0.003)], ref=V((1, 0, 0)), seg=4),
        rk.blob(bm, on(0, 34, 0.036), (0.012, 0.006, 0.016), 6, 4)) for s in (1, -1)], **flat)
    part("H_mask_kitsune_eyes", "Void", headw, lambda bm: (
        [line(bm, [on(s * 10, 4, 0.036), on(s * 20, 7, 0.037), on(s * 32, 13, 0.036)], 0.012, 0.006) for s in (1, -1)],
        rk.blob(bm, V((0, HC.y - HR.y - 0.12, Z - 0.05)), (0.016, 0.014, 0.012), 6, 4)), **flat)

    # Oni: a crimson demon face, heavy dark brows, a snarl with ivory fangs, curling horns.
    part("H_mask_oni", "Oni", headw, lambda bm: (
        plate(bm, lambda yw: -62 + abs(yw) * 0.2, lambda yw: 42 - abs(yw) * 0.1),
        rk.blob(bm, on(0, -12, 0.045), (0.034, 0.03, 0.028), 6, 4)), **flat)
    part("H_mask_oni_brow", "OniDark", headw, lambda bm: [
        rk.tube(bm, [on(s * 4, 14, 0.036), on(s * 20, 24, 0.05), on(s * 42, 20, 0.036)], [(0.02, 0.02), (0.026, 0.026), (0.01, 0.01)], seg=5)
        for s in (1, -1)], **flat)
    part("H_mask_oni_mouth", "Void", headw, lambda bm: (
        [line(bm, [on(s * 11, 6, 0.036), on(s * 28, 11, 0.036)], 0.016, 0.008) for s in (1, -1)],
        line(bm, [on(-30, -34, 0.036), on(-14, -40, 0.04), on(0, -41, 0.042), on(14, -40, 0.04), on(30, -34, 0.036)], 0.02, 0.01)), **flat)
    part("H_mask_oni_horns", "Ivory", headw, lambda bm: (
        [rk.tube(bm, [on(s * 30, 42, 0.0), V((s * 0.15, -0.05, Z + 0.18)), V((s * 0.21, -0.05, Z + 0.22)), V((s * 0.24, -0.07, Z + 0.3))],
                 [(0.04, 0.04), (0.03, 0.03), (0.016, 0.016), (0.003, 0.003)], seg=6) for s in (1, -1)],
        [rk.tube(bm, [on(s * 12, -33, 0.042), on(s * 12, -44, 0.05)], [(0.012, 0.01), (0.002, 0.002)], seg=4) for s in (1, -1)],
        [rk.tube(bm, [on(s * 24, -44, 0.042), on(s * 24, -34, 0.05)], [(0.011, 0.009), (0.002, 0.002)], seg=4) for s in (1, -1)]), **flat)

    # Hollow: a smooth black face with thin glowing slits and a steel line down the middle.
    part("H_mask_hollow", "Void", headw, lambda bm: plate(bm, lambda yw: -58 + abs(yw) * 0.18, lambda yw: 46 - abs(yw) * 0.1, yaw=84), **flat)
    part("H_mask_hollow_eyes", "MaskGlow", headw, lambda bm: [
        rk.tube(bm, [on(s * 8, 5, 0.036), on(s * 20, 5, 0.037), on(s * 34, 8, 0.036)], [(0.005, 0.008)] * 3, ref=V((0, 0, 1)), seg=4)
        for s in (1, -1)], **flat)
    part("H_mask_hollow_lines", "Steel", headw, lambda bm: (
        line(bm, [on(0, 44, 0.036), on(0, 10, 0.037), on(0, -30, 0.037), on(0, -58, 0.036)], 0.004),
        [line(bm, [on(s * 40, -10, 0.036), on(s * 26, -36, 0.036)], 0.003) for s in (1, -1)]), **flat)

    # Raven: a dark crow mask over the upper face, a long curved beak, feathered brows sweeping back,
    # round lenses glowing amber in steel rims.
    part("H_mask_raven", "Raven", headw, lambda bm: (
        plate(bm, lambda yw: -22 + abs(yw) * 0.05, lambda yw: 46 - abs(yw) * 0.1),
        rk.tube(bm, [on(0, -6, 0.03), V((0, HC.y - HR.y - 0.08, Z - 0.035)), V((0, HC.y - HR.y - 0.17, Z - 0.075)),
                     V((0, HC.y - HR.y - 0.23, Z - 0.13))],
                [(0.05, 0.045), (0.034, 0.03), (0.018, 0.016), (0.003, 0.003)], ref=V((1, 0, 0)), seg=6)), **flat)
    part("H_mask_raven_feathers", "RavenSheen", headw, lambda bm: [
        rk.tube(bm, [on(s * (8 + k * 11), 24 + k * 2, 0.032), on(s * (22 + k * 13), 38 + k * 5, 0.07 + k * 0.01)],
                [(0.018 - k * 0.002, 0.008), (0.002, 0.002)], ref=V((0, 0, 1)), seg=4)
        for s in (1, -1) for k in range(4)], **flat)
    part("H_mask_raven_rims", "Steel", headw, lambda bm: [
        rk.tube(bm, [around(s * 20, 7, 0.03)[0], around(s * 20, 7, 0.05)[0]], [(0.034, 0.034)] * 2, ref=V((0, 0, 1)), seg=10)
        for s in (1, -1)], **flat)
    part("H_mask_raven_lenses", "LensGlow", headw, lambda bm: [
        rk.tube(bm, [around(s * 20, 7, 0.048)[0], around(s * 20, 7, 0.054)[0]], [(0.025, 0.025)] * 2, ref=V((0, 0, 1)), seg=10)
        for s in (1, -1)], **flat)

    # Sun mask: a serene gold face with closed eyes and a halo of rays round the head.
    part("H_mask_aurum", "SunGold", headw, lambda bm: (
        plate(bm, lambda yw: -56 + abs(yw) * 0.18, lambda yw: 44 - abs(yw) * 0.1),
        rk.tube(bm, [V((0, HC.y + 0.035, Z + 0.02)), V((0, HC.y + 0.055, Z + 0.02))], [(0.2, 0.21)] * 2, ref=V((1, 0, 0)), seg=16),
        [rk.tube(bm, [V((math.cos(a) * 0.19, HC.y + 0.045, Z + 0.02 + math.sin(a) * 0.2)),
                      V((math.cos(a) * (0.33 if k % 2 == 0 else 0.27), HC.y + 0.045, Z + 0.02 + math.sin(a) * (0.34 if k % 2 == 0 else 0.28)))],
                 [(0.055, 0.016), (0.004, 0.004)], ref=V((0, 1, 0)), seg=4)
         for k, a in enumerate(math.radians(-15 + 210 * i / 10) for i in range(11))]), **flat)
    part("H_mask_aurum_lines", "Void", headw, lambda bm: (
        [line(bm, [on(s * 8, 8, 0.037), on(s * 19, 4, 0.038), on(s * 31, 8, 0.037)], 0.006) for s in (1, -1)],
        line(bm, [on(-10, -34, 0.037), on(0, -36, 0.038), on(10, -34, 0.037)], 0.005)), **flat)
    part("H_mask_aurum_gem", "SunGlow", headw, lambda bm: (
        rk.blob(bm, on(0, 28, 0.045), (0.022, 0.012, 0.03), 6, 4),
        [rk.blob(bm, V((math.cos(a) * 0.335, HC.y + 0.045, Z + 0.02 + math.sin(a) * 0.345)), (0.016, 0.016, 0.016), 5, 3)
         for i, a in enumerate(math.radians(-15 + 210 * i / 10) for i in range(11)) if i % 2 == 0]), **flat)

    part("H_extra_glasses", "Metal", headw, glasses, **flat)
    part("H_extra_eyepatch", "Leather", headw, eyepatch, **flat)
    part("H_extra_earrings", "Metal", headw, earrings, **flat)
    part("H_cheeks_blush", "Blush", headw, lambda bm: [decal_ellipse(bm, s * 0.085, Z - 0.03, 0.022, 0.012) for s in (1, -1)], **decal)

    # --- hair and beards --------------------------------------------------------------------
    for style, fn in (("short", hair_short), ("messy", hair_messy_base), ("long", hair_long),
                      ("ponytail", hair_ponytail), ("bun", hair_bun), ("braid", hair_braid), ("mohawk", hair_mohawk),
                      ("swept", hair_swept), ("curly", hair_curly), ("topknot", hair_topknot), ("pigtails", hair_pigtails)):
        part(f"H_hair_{style}", "Hair", hair_weights, fn, **flat)
    part("H_hair_messy_top", "Hair", headw, hair_messy_top, **flat)
    # Under a hat or bandana: the same style with everything above the brim taken away,
    # so nothing pokes through (the game swaps these in).
    def under_hat(fn):
        def build_it(bm):
            fn(bm)
            delete_faces(bm, lambda c: c.z > Z + 0.055)
        return build_it
    for style, fn in (("short", hair_short), ("messy", hair_messy_base), ("long", hair_long),
                      ("ponytail", hair_ponytail), ("bun", hair_bun), ("braid", hair_braid), ("mohawk", hair_mohawk),
                      ("swept", hair_swept), ("curly", hair_curly), ("topknot", hair_topknot), ("pigtails", hair_pigtails)):
        part(f"H_hair_{style}_hat", "Hair", hair_weights, under_hat(fn), **flat)
    for style, fn in (("short", beard_short), ("full", beard_full), ("goatee", beard_goatee), ("mustache", beard_mustache),
                      ("stubble", beard_stubble), ("chinstrap", beard_chinstrap), ("braided", beard_braided)):
        # The jaw shell is an open surface: orient every face away from the head's centre instead of
        # letting a normal recalculation flip it inside out (which hid the beard from the front).
        part(f"H_beard_{style}", "Hair", headw, fn, smooth=False, recalc=False, outward=lambda c: c - HC, shade_var=SHADE)

    # --- clothes and gear ---------------------------------------------------------------------
    part("H_top_tunic", "Main", torso_weights, tunic, **flat)
    part("H_top_jacket", "Main", torso_weights, jacket, **flat)
    part("H_top_coat", "Main", torso_weights, coat, **flat)
    part("H_top_robe", "Main", torso_weights, robe, **flat)
    part("H_top_robe_trim", "Accent", torso_weights, robe_trim, **flat)
    part("H_top_robe_belt", "Cloth", torso_weights, rope_belt, **flat)
    part("H_top_armor", "Metal", torso_weights, armor, **flat)
    part("H_top_armor_gorget", "Metal", rk.weights_by_distance(["spine_03", "neck_01"]), armor_gorget, **flat)
    part("H_top_armor_skirt", "Main", torso_weights, armor_skirt, **flat)
    part("H_top_armor_rivets", "Gold", torso_weights, armor_rivets, **flat)
    part("H_top_armor_tassets", "Leather", torso_weights, tassets, **flat)
    part("H_top_jerkin", "Main", torso_weights, jerkin, **flat)
    part("H_top_jerkin_laces", "Leather", torso_weights, jerkin_laces, **flat)
    part("H_top_jerkin_fur", "Fur", rk.weights_by_distance(["spine_03", "clavicle_l", "clavicle_r", "neck_01"]), fur_trim, **flat)
    for s, side in ((1, "l"), (-1, "r")):
        arm_w = rk.weights_by_distance([f"clavicle_{side}", f"upperarm_{side}", f"lowerarm_{side}"], top=2)
        part(f"H_top_robe_cuff_{side}", "Main", rk.weights_by_distance([f"lowerarm_{side}"], top=1), lambda bm, s=s: robe_cuffs(bm, s), **flat)
        part(f"H_top_jerkin_arm_{side}", "Skin", arm_w, lambda bm, s=s: bare_arm(bm, s), smooth=False)
    part("H_waist_kilt", "Accent", lambda p: skirt_weights(p), kilt, **flat)
    part("H_waist_kilt_band", "Second", lambda p: skirt_weights(p), kilt_band, **flat)
    part("H_waist_apron", "Leather", torso_weights, apron, **flat)
    part("H_waist_tabard", "Accent", lambda p: skirt_weights(p), tabard, **flat)
    part("H_waist_tabard_emblem", "Gold", lambda p: skirt_weights(p), tabard_emblem, **flat)
    part("H_chest_sash", "Accent", torso_weights, sash, **flat)
    part("H_chest_bandolier", "Leather", torso_weights, bandolier, **flat)
    part("H_chest_bandolier_vials", "Potion", torso_weights, lambda bm: vials(bm, 0), **flat)
    part("H_chest_bandolier_vials2", "Potion2", torso_weights, lambda bm: vials(bm, 1), **flat)
    part("H_chest_bandolier_corks", "Wood", torso_weights, vial_corks, **flat)
    part("H_chest_strap", "Leather", torso_weights, strap, **flat)
    part("H_chest_vest", "Leather", torso_weights, vest, **flat)
    for s, side in ((1, "l"), (-1, "r")):
        w = rk.weights_by_distance([f"clavicle_{side}", f"upperarm_{side}"], top=2)
        part(f"H_shoulders_pads_{side}", "Leather", w, lambda bm, s=s: shoulder(bm, s, (0.11, 0.1, 0.07)), **flat)
        part(f"H_shoulders_plates_{side}", "Metal", w, lambda bm, s=s: shoulder(bm, s, (0.13, 0.12, 0.085)), **flat)
    neck_w = rk.weights_by_distance(["spine_03", "neck_01", "spine_02"])
    part("H_back_scarf", "Accent", neck_w, scarf, **flat)
    part("H_shoulders_fur", "Fur", rk.weights_by_distance(["spine_03", "clavicle_l", "clavicle_r", "neck_01"]), fur_mantle, **flat)
    part("H_shoulders_pauldron", "Metal", rk.weights_by_distance(["clavicle_l", "upperarm_l"], top=2), pauldron, **flat)
    part("H_shoulders_pauldron_strap", "Leather", torso_weights, pauldron_strap, **flat)
    back_w2 = rk.weights_by_distance(["spine_02", "spine_03"], top=2)
    part("H_back_quiver", "Leather", back_w2, quiver, **flat)
    part("H_back_quiver_arrows", "Wood", back_w2, quiver_arrows, **flat)
    part("H_back_quiver_fletch", "Feather", back_w2, quiver_fletch, **flat)
    part("H_back_shield", "Accent", back_w2, shield, **flat)
    part("H_back_shield_rim", "Metal", back_w2, shield_rim, **flat)
    part("H_back_shield_band", "Second", back_w2, shield_band, **flat)
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
    part("H_head_hood", "Accent", rk.weights_by_distance(["Head", "neck_01", "spine_03"], top=2), hood, **flat)
    part("H_head_helm", "Metal", headw, helm, **flat)
    part("H_head_helm_crest", "Accent", headw, helm_crest, **flat)
    part("H_head_cap", "Accent", headw, soft_cap, **flat)
    part("H_head_cap_feather", "Feather", headw, cap_feather, **flat)
    part("H_head_crown", "Leaf", headw, crown_leaves, **flat)
    part("H_head_crown_petals", "Petal", headw, lambda bm: crown_flowers(bm, 0), **flat)
    part("H_head_crown_blooms", "Bloom", headw, lambda bm: crown_flowers(bm, 1), **flat)
    part("H_head_sunhat", "Straw", headw, sun_hat, **flat)
    part("H_head_sunhat_band", "Leather", headw, sun_hat_band, **flat)
    part("H_back_leafcloak", "Tobacco", torso_weights, lambda bm: leaf_cloak(bm, False), **flat)
    part("H_back_leafcloak_dark", "Tobacco2", torso_weights, lambda bm: leaf_cloak(bm, True), **flat)
    part("H_back_leafcloak_ribs", "Wood", torso_weights, leaf_ribs, **flat)
    part("H_head_wayfarer", "Accent", headw, wayfarer_hat, **flat)
    part("H_head_wayfarer_band", "Leather", headw, wayfarer_band, **flat)
    part("H_head_wayfarer_buckle", "Gold", headw, wayfarer_buckle, **flat)
    part("H_head_antlers", "Antler", headw, antlers, **flat)
    part("H_head_antlers_band", "Leather", headw, antler_band, **flat)
    part("H_head_antlers_leaves", "Leaf", headw, antler_leaves, **flat)
    part("H_head_straw", "Straw", headw, straw_hat, **flat)
    part("H_head_straw_band", "Accent", headw, straw_band, **flat)
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
