"""Builds the second character style, "Carved", on the Quaternius UAL skeleton: a chunky, charming
figure that looks whittled from wood and painted, matching the world's faceted trees and rocks.
A big rounded-box head with crisp facets, painted-on faces (little raised shapes), hair as a few
bold diamond-cut chunks, thick limbs, mitten hands and big boots. Flat shading everywhere.

It follows hero.glb's naming, so the game dresses and colours it with the same look data:
  H_base_*                  always shown (one mesh per colour)
  H_ears / H_ears_<kind>    ears
  H_<slot>_<choice>[_extra] shown when that choice is picked
  H_hair_<style>_hat        the style cut short under a hat
Material names are the same colour slots (Skin, Hair, Main, Second, Cloth, Accent, Leather, Eyes,
Marks, Metal...). Choices this style doesn't model fall back in the game (CharacterLook.CARVED_FALLBACK).

Run: tools/blender/blender.exe --background --python tools-src/blender/make_carved.py
"""
import math
import os
import random
import sys
import bpy  # noqa: F401
import bmesh
from mathutils import Vector as V
from mathutils.bvhtree import BVHTree

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "carved.glb")

COLORS = {  # defaults (sRGB); the game overrides the slot colours
    "Skin": (0.93, 0.72, 0.56), "Hair": (0.24, 0.15, 0.10), "Face": (0.12, 0.07, 0.07), "Eyes": (0.1, 0.07, 0.07),
    "Shine": (1.0, 1.0, 1.0), "Blush": (0.95, 0.56, 0.5), "Main": (0.42, 0.48, 0.32),
    "Second": (0.3, 0.29, 0.3), "Cloth": (0.85, 0.8, 0.68), "Accent": (0.72, 0.25, 0.2),
    "Leather": (0.5, 0.33, 0.2), "Metal": (0.72, 0.7, 0.66), "Marks": (0.36, 0.22, 0.16),
    "Gold": (0.95, 0.74, 0.3), "Leaf": (0.36, 0.58, 0.28), "Petal": (0.97, 0.78, 0.84), "Bloom": (0.98, 0.9, 0.5),
    "Straw": (0.9, 0.77, 0.46), "Fur": (0.55, 0.44, 0.33), "Feather": (0.95, 0.94, 0.9), "Potion": (0.35, 0.82, 0.72),
    "Potion2": (0.9, 0.36, 0.42), "Wood": (0.55, 0.38, 0.24), "Antler": (0.86, 0.79, 0.66), "Teeth": (0.97, 0.95, 0.9),
}

FRONT = V((0, -1, 0))            # the character faces -Y
HC = V((0.0, -0.02, 1.775))      # head centre: a big head, for charm
HR = V((0.2, 0.185, 0.19))       # head half-sizes
JAW = 0.3                        # the lower head narrows this much towards the chin
ROUND = 0.62                     # 0 = a box, 1 = a ball
EYE_X, EYE_Z = 0.074, HC.z - 0.012
BROW_Z = EYE_Z + 0.058
MOUTH_Z = HC.z - 0.098
SHADE = 0.09                     # per-face shade variation: the hand-carved look
ARM_Y, ARM_Z = 0.066, 1.441


# --- the rounded-box head and shells around it ---------------------------------------------------

def head_dir(yaw, pitch):
    y, p = math.radians(yaw), math.radians(pitch)
    return V((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))


def rb(d, half, rnd=ROUND, jaw=JAW):
    """A point on a rounded box (half-sizes `half`) in direction d, narrowing towards the chin."""
    m = max(abs(d.x), abs(d.y), abs(d.z))
    q = (d / m).lerp(d, rnd)
    k = 1.0 - jaw * d.z * d.z if d.z < 0 else 1.0
    return V((q.x * half.x * k, q.y * half.y * k, q.z * half.z))


def rounded(bm, center, half, seg=10, rings=8, keep=None, rnd=ROUND, jaw=JAW, spin=0.5):
    """A faceted rounded box made of `seg` sides and `rings` bands (a face, not an edge, looks
    forward). keep(yaw, pitch) can cut parts away (hair caps, hoods, helmets)."""
    grid = []
    for i in range(1, rings):
        pitch = -90 + 180 * i / rings
        row = []
        for k in range(seg):
            yaw = 360 * (k + spin) / seg - 180
            row.append((yaw, pitch, bm.verts.new(center + rb(head_dir(yaw, pitch), half, rnd, jaw))))
        grid.append(row)
    bot = (0, -90, bm.verts.new(center + rb(V((0, 0, -1)), half, rnd, jaw)))
    top = (0, 90, bm.verts.new(center + rb(V((0, 0, 1)), half, rnd, jaw)))
    ok = (lambda e: keep is None or keep(e[0], e[1]))
    for i in range(len(grid) - 1):
        for k in range(seg):
            q = [grid[i][k], grid[i][(k + 1) % seg], grid[i + 1][(k + 1) % seg], grid[i + 1][k]]
            if all(ok(e) for e in q):
                bm.faces.new([e[2] for e in q])
    for k in range(seg):
        a, b = grid[0][k], grid[0][(k + 1) % seg]
        if ok(a) and ok(b) and ok(bot):
            bm.faces.new((bot[2], b[2], a[2]))
        a, b = grid[-1][k], grid[-1][(k + 1) % seg]
        if ok(a) and ok(b) and ok(top):
            bm.faces.new((a[2], b[2], top[2]))
    mine = [e[2] for row in grid for e in row] + [bot[2], top[2]]
    bmesh.ops.delete(bm, geom=[v for v in mine if not v.link_faces], context="VERTS")
    return [v for v in mine if v.is_valid]


def on_head(yaw, pitch, lift=0.0, half=HR):
    """Point on the head surface in a direction, pushed out by `lift`; and the outward direction."""
    p = HC + rb(head_dir(yaw, pitch), half)
    n = (p - HC).normalized()
    return p + n * lift, n


def head(bm):
    rounded(bm, HC, HR, seg=10, rings=8)


_bm = bmesh.new()
head(_bm)
HEAD_BVH = BVHTree.FromBMesh(_bm)


def face_pt(x, z):
    """The front of the head at (x, z): the surface point and its facet's normal."""
    hit, n, _, _ = HEAD_BVH.ray_cast(V((x, HC.y - 1.0, z)), V((0, 1, 0)))
    return hit, n


def decal(bm, pts, out=0.004, depth=0.007):
    """A little raised painted shape on the face: the 2D outline `pts` [(x, z)] pressed onto the head."""
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    _, nc = face_pt(cx, cz)
    front, back = [], []
    for x, z in pts:
        p, _ = face_pt(x, z)
        front.append(bm.verts.new(p + nc * (out + depth)))
        back.append(bm.verts.new(p + nc * (out - 0.008)))
    n = len(pts)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))


def oval(cx, cz, rx, rz, n=8, a0=0.0):
    return [(cx + rx * math.cos(a0 + k * math.tau / n), cz + rz * math.sin(a0 + k * math.tau / n)) for k in range(n)]


def band(cx, cz, r, a0, a1, thick, n=6, squash=1.0):
    """An arc-shaped band (smiles, happy eyes), angles in degrees."""
    outer, inner = [], []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        outer.append((cx + (r + thick / 2) * math.cos(a), cz + (r + thick / 2) * math.sin(a) * squash))
        inner.append((cx + (r - thick / 2) * math.cos(a), cz + (r - thick / 2) * math.sin(a) * squash))
    return outer + list(reversed(inner))


def bar(a, b, w):
    """A straight bar from a to b, `w` wide."""
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    ln = math.hypot(dx, dz)
    nx, nz = -dz / ln * w / 2, dx / ln * w / 2
    return [(ax + nx, az + nz), (bx + nx, bz + nz), (bx - nx, bz - nz), (ax - nx, az - nz)]


def strip(bm, pts, w, out=0.003, depth=0.004):
    for i in range(len(pts) - 1):
        decal(bm, bar(pts[i], pts[i + 1], w), out, depth)


def chunk(bm, base, tip, out, w, d, bend=0.02, mid_w=0.85):
    """A bold diamond-cut chunk (hair locks, fur, leaves): wide at the root, pointed at the tip."""
    axis = (tip - base).normalized()
    side = out.cross(axis).normalized()
    mid = base.lerp(tip, 0.5) + out * bend
    rk.tube(bm, [base, mid, tip], [(w, d), (w * mid_w, d * 0.9), (0.006, 0.004)], ref=side, seg=4)


def box(bm, center, half, rnd=0.35, seg=8, rings=4, spin=0.5, turn=None):
    """A small chamfered box (pouches, buckles, packs)."""
    for v in rounded(bm, V((0, 0, 0)), half, seg=seg, rings=rings, rnd=rnd, jaw=0.0, spin=spin):
        v.co = (turn @ v.co if turn else v.co) + center


def delete_faces(bm, test):
    dead = [f for f in bm.faces if test(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=dead, context="FACES")


# --- skin weights ----------------------------------------------------------------------------------

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


def hair_weights(p):
    if p.z > HC.z - 0.13:
        return {"Head": 1.0}
    return rk.weights_by_distance(["Head", "neck_01", "spine_03"], top=2)(p)


def sided(names):
    """Weights to one side's bones (`names` with {s} for l / r), picked by the point's side."""
    fl = rk.weights_by_distance([n.format(s="l") for n in names], top=2)
    fr = rk.weights_by_distance([n.format(s="r") for n in names], top=2)
    return lambda p: fl(p) if p.x > 0 else fr(p)


ARM_W = sided(["clavicle_{s}", "upperarm_{s}", "lowerarm_{s}", "hand_{s}"])
FOREARM_W = sided(["lowerarm_{s}"])
HAND_W = lambda p: {"hand_l" if p.x > 0 else "hand_r": 1.0}
LEG_W = sided(["thigh_{s}", "calf_{s}"])
CALF_W = sided(["calf_{s}"])
FOOT_W = sided(["calf_{s}", "foot_{s}", "ball_{s}"])
SHOULDER_W = sided(["clavicle_{s}", "upperarm_{s}"])
HEAD_W = rk.fixed("Head")


# --- body --------------------------------------------------------------------------------------

# The torso as rings (height, x radius, y radius): a chunky barrel. Clothes are shells a bit larger.
TORSO = [(0.9, 0.215, 0.168), (1.02, 0.208, 0.162), (1.18, 0.226, 0.17), (1.34, 0.248, 0.176), (1.45, 0.24, 0.165),
         (1.52, 0.165, 0.125), (1.56, 0.085, 0.075)]


def lathe(bm, rings, grow=0.0, seg=8, caps=False, cy=0.02):
    rk.tube(bm, [V((0, cy, z)) for z, _, _ in rings], [(rx + grow, ry + grow) for _, rx, ry in rings], seg=seg, caps=caps)


def arm_tube(bm, xs, radii, seg=6, y=ARM_Y, z=ARM_Z):
    for s in (1, -1):
        rk.tube(bm, [V((s * x, y, z)) for x in xs], [(r, r) for r in radii], ref=V((0, 0, 1)), seg=seg)


def hands(bm):
    for s in (1, -1):
        box(bm, V((s * 0.815, 0.07, 1.432)), V((0.075, 0.056, 0.042)), rnd=0.45, seg=8, rings=4)   # a mitten
        rk.tube(bm, [V((s * 0.775, 0.035, 1.42)), V((s * 0.81, -0.01, 1.395)), V((s * 0.84, -0.03, 1.39))],
                [(0.025, 0.022), (0.022, 0.02), (0.012, 0.012)], ref=V((0, 0, 1)), seg=5)             # the thumb


def legs(bm):
    for s in (1, -1):
        x = s * 0.1
        rk.tube(bm, [V((x, 0.0, 1.0)), V((x * 1.04, 0.0, 0.74)), V((x, 0.012, 0.5)), V((x, 0.025, 0.36))],
                [(0.125, 0.125), (0.116, 0.116), (0.1, 0.1), (0.094, 0.094)], seg=6)


def boot(bm, top=0.44, cuff=True, toe=1.0):
    for s in (1, -1):
        x = s * 0.1
        pts = [V((x, 0.03, top)), V((x, 0.03, 0.16)), V((x, 0.0, 0.075)), V((x, -0.13 * toe, 0.06)), V((x, -0.235 * toe, 0.055))]
        rk.tube(bm, pts, [(0.108, 0.108), (0.104, 0.11), (0.106, 0.112), (0.1, 0.072), (0.084, 0.056)], ref=V((1, 0, 0)), seg=6)
        if cuff:
            rk.tube(bm, [V((x, 0.03, top - 0.05)), V((x, 0.03, top + 0.03))], [(0.128, 0.128), (0.134, 0.134)], seg=6)


def soles(bm):
    for s in (1, -1):
        box(bm, V((s * 0.1, -0.08, 0.022)), V((0.1, 0.2, 0.024)), rnd=0.3, seg=8, rings=4)


# --- face -------------------------------------------------------------------------------------------

def fierce_eye(s):
    """An eye with its top cut at a slant, lower towards the nose."""
    pts = []
    for x, z in oval(0, 0, 0.027, 0.03, 8, math.pi / 8):
        out = x                                   # away from the nose
        pts.append((s * (EYE_X + x), EYE_Z + min(z, 0.004 + 0.45 * out)))
    return pts if s > 0 else list(reversed(pts))


def pair(fn):
    return lambda bm: [fn(bm, s) for s in (1, -1)]


EYES = {
    "calm": pair(lambda bm, s: decal(bm, oval(s * EYE_X, EYE_Z, 0.024, 0.032, 8, math.pi / 8))),
    "bright": pair(lambda bm, s: decal(bm, oval(s * EYE_X, EYE_Z, 0.031, 0.039, 10))),
    "happy": pair(lambda bm, s: decal(bm, band(s * EYE_X, EYE_Z - 0.012, 0.024, 15, 165, 0.012, 6))),
    "narrow": pair(lambda bm, s: decal(bm, oval(s * EYE_X, EYE_Z, 0.03, 0.013, 8))),
    "sleepy": pair(lambda bm, s: decal(bm, [(s * EYE_X + 0.028 * math.cos(a), EYE_Z - 0.004 + 0.02 * math.sin(a))
                                            for a in (math.radians(d) for d in (0, -40, -90, -140, 180))])),
    "fierce": pair(lambda bm, s: decal(bm, fierce_eye(s))),
}
SHINE = {
    "calm": lambda bm: [decal(bm, oval(s * EYE_X + 0.009, EYE_Z + 0.012, 0.008, 0.009, 5), 0.011, 0.003) for s in (1, -1)],
    "bright": lambda bm: [(decal(bm, oval(s * EYE_X + 0.011, EYE_Z + 0.014, 0.011, 0.012, 6), 0.011, 0.003),
                           decal(bm, oval(s * EYE_X - 0.012, EYE_Z - 0.016, 0.005, 0.005, 5), 0.011, 0.003)) for s in (1, -1)],
    "fierce": lambda bm: [decal(bm, oval(s * EYE_X + 0.008, EYE_Z - 0.004, 0.007, 0.007, 5), 0.011, 0.003) for s in (1, -1)],
}
BROWS = {
    "soft": pair(lambda bm, s: decal(bm, band(s * EYE_X, BROW_Z - 0.03, 0.032, 55, 125, 0.012, 4))),
    "arched": pair(lambda bm, s: decal(bm, band(s * EYE_X, BROW_Z - 0.035, 0.035, 40, 140, 0.011, 5))),
    "raised": pair(lambda bm, s: decal(bm, band(s * EYE_X, BROW_Z - 0.015, 0.03, 50, 130, 0.011, 4))),
    "stern": pair(lambda bm, s: decal(bm, bar((s * (EYE_X - 0.034), BROW_Z - 0.012), (s * (EYE_X + 0.03), BROW_Z + 0.008), 0.015))),
    "thick": pair(lambda bm, s: decal(bm, bar((s * (EYE_X - 0.032), BROW_Z - 0.002), (s * (EYE_X + 0.032), BROW_Z + 0.002), 0.022))),
}
MOUTHS = {
    "smile": lambda bm: decal(bm, band(0, MOUTH_Z + 0.022, 0.032, 215, 325, 0.01, 6)),
    "grin": lambda bm: decal(bm, [(0.036, MOUTH_Z + 0.008)] + [(0.036 * math.cos(a), MOUTH_Z + 0.008 + 0.03 * math.sin(a))
                                                              for a in (math.radians(d) for d in (-30, -60, -90, -120, -150))] + [(-0.036, MOUTH_Z + 0.008)]),
    "open": lambda bm: decal(bm, oval(0, MOUTH_Z, 0.017, 0.021, 8)),
    "flat": lambda bm: decal(bm, bar((-0.026, MOUTH_Z), (0.026, MOUTH_Z), 0.01)),
    "smirk": lambda bm: decal(bm, band(0.012, MOUTH_Z + 0.02, 0.03, 230, 335, 0.01, 5)),
}
TEETH = {"grin": lambda bm: decal(bm, [(0.03, MOUTH_Z + 0.004), (-0.03, MOUTH_Z + 0.004), (-0.026, MOUTH_Z - 0.006), (0.026, MOUTH_Z - 0.006)], 0.011, 0.002)}


def nose(w, h, length, up=0.0):
    def build_it(bm):
        p, n = face_pt(0, HC.z - 0.045 + up)
        rk.tube(bm, [p - n * 0.01, p + n * length * 0.6 + V((0, 0, -h * 0.2)), p + n * length + V((0, 0, -h * 0.35))],
                [(w, h), (w * 0.9, h * 0.8), (w * 0.55, h * 0.45)], ref=V((1, 0, 0)), seg=5)
    return build_it


NOSES = {"straight": nose(0.02, 0.03, 0.03), "button": nose(0.022, 0.022, 0.022, -0.006),
         "long": nose(0.018, 0.034, 0.05), "broad": nose(0.032, 0.026, 0.028)}


def ears(length, back, tip_up):
    def build_it(bm):
        for s in (1, -1):
            base = V((s * (HR.x - 0.01), HC.y + 0.01, HC.z - 0.02))
            tip = base + V((s * length, back, tip_up))
            rk.tube(bm, [base, base.lerp(tip, 0.45) + V((s * 0.006, 0, 0)), tip],
                    [(0.026, 0.04), (0.022, 0.036), (0.005, 0.005)], ref=V((0, 0, 1)), seg=4)
    return build_it


def round_ears(bm):
    for s in (1, -1):
        box(bm, V((s * (HR.x + 0.008), HC.y + 0.01, HC.z - 0.02)), V((0.022, 0.032, 0.044)), rnd=0.5, seg=6, rings=4)


# --- hair --------------------------------------------------------------------------------------

def hairline(front, side, back):
    """keep(yaw, pitch) for a hair cap: above `front` pitch at the forehead, `side` by the ears, `back` at the nape."""
    def keep(yaw, pitch):
        t = abs(yaw) / 180.0
        line = front + (side - front) * min(t * 2, 1) if t < 0.5 else side + (back - side) * (t - 0.5) * 2
        return pitch >= line - 0.01
    return keep


def cap(bm, front=30, side=-10, back=-45, grow=0.026, top=0.0):
    half = HR + V((grow, grow, grow * 0.8 + top))
    rounded(bm, HC + V((0, 0.006, top * 0.5)), half, seg=10, rings=10, keep=hairline(front, side, back))


def fringe(bm, yaws, top=40, low=14, sweep=0.0, w=0.05, lift=0.03):
    for yaw in yaws:
        base, n = on_head(yaw, top, lift)
        tip, _ = on_head(yaw + sweep, low, lift + 0.008)
        chunk(bm, base, tip, n, w, 0.03, bend=0.02)


def sides(bm, low=-30, w=0.05, lift=0.028):
    for s in (1, -1):
        base, n = on_head(s * 80, 20, lift)
        tip, _ = on_head(s * 86, low, lift + 0.01)
        chunk(bm, base, tip, n, w, 0.03)


def backs(bm, low=-50, count=5, w=0.065, spread=130, lift=0.028, down=0.0):
    for i in range(count):
        yaw = 180 - spread / 2 + spread * i / max(count - 1, 1)
        base, n = on_head(yaw, 20, lift)
        tip, _ = on_head(yaw, low, lift + 0.012)
        chunk(bm, base, tip + V((0, 0, -down)), n, w, 0.032)


def hair_short(bm):
    cap(bm)
    fringe(bm, (-34, -12, 10, 32), sweep=8)
    sides(bm, -22)
    backs(bm, -40, 5)


def hair_messy(bm):
    cap(bm)
    rnd = random.Random(4)
    for yaw, pitch in ((0, 75), (40, 60), (-40, 62), (90, 45), (-90, 48), (140, 50), (-140, 52), (180, 40), (20, 35), (-25, 38)):
        base, n = on_head(yaw, pitch, 0.02)
        tip = base + (n + V((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 0.4))).normalized() * rnd.uniform(0.08, 0.12)
        chunk(bm, base, tip, (tip - base).cross(V((1, 0, 0))).normalized() if abs(n.x) < 0.9 else V((0, 0, 1)), 0.045, 0.034, bend=0.0)
    fringe(bm, (-30, -5, 22), top=36, low=12, sweep=-10)
    sides(bm, -25)


def hair_swept(bm):
    cap(bm, front=34)
    for i, yaw in enumerate((-40, -18, 4)):            # one big swoop across the brow
        base, n = on_head(yaw, 60 - i * 4, 0.03)
        tip, _ = on_head(yaw + 48, 22 - i * 3, 0.04)
        chunk(bm, base, tip, n, 0.065, 0.035, bend=0.04)
    sides(bm, -20)
    backs(bm, -35, 5)


def hair_curly(bm):
    cap(bm, front=32, side=-15, back=-45)
    for yaw in range(-180, 180, 36):
        for pitch, lift in ((10, 0.03), (40, 0.035), (68, 0.03)):
            if pitch < 20 and abs(yaw) < 60:
                continue
            p, n = on_head(yaw + (18 if pitch == 40 else 0), pitch, lift)
            box(bm, p, V((0.045, 0.045, 0.042)), rnd=0.7, seg=6, rings=4)
    for yaw in (-40, -14, 14, 40):
        p, n = on_head(yaw, 34, 0.03)
        box(bm, p, V((0.036, 0.034, 0.034)), rnd=0.7, seg=6, rings=4)


def hair_long(bm):
    cap(bm, front=30, side=-10, back=-40)
    fringe(bm, (-30, 30), top=46, low=12, sweep=0, w=0.06)
    fringe(bm, (-8, 8), top=48, low=26, sweep=0, w=0.05)
    for s in (1, -1):                                   # long side locks to the shoulders
        for yaw, w in ((70, 0.06), (100, 0.065)):
            base, n = on_head(s * yaw, 10, 0.03)
            tip = V((s * (HR.x + 0.04), HC.y + 0.03 + (yaw - 70) * 0.002, 1.42))
            chunk(bm, base, tip, V((s, 0, 0)), w, 0.035, bend=0.02, mid_w=1.0)
    for i in range(5):                                   # a sheet down the back
        x = -0.15 + 0.075 * i
        base, n = on_head(180 + x * 280, 15, 0.03)
        tip = V((x * 1.15, HC.y + HR.y + 0.03, 1.36))
        chunk(bm, base, tip, V((0, 1, 0)), 0.065, 0.035, bend=0.03, mid_w=1.0)


def tail(bm, start, pts, r, n=4):
    """A tied tail: a band and then a tapering faceted rope."""
    rk.tube(bm, [start] + pts, [(r, r)] + [(r * (1.1 - 0.75 * (i + 1) / len(pts)),) * 2 for i in range(len(pts))], seg=6)


def hair_ponytail(bm):
    cap(bm, front=32, side=-10, back=-40)
    fringe(bm, (-28, -6, 16), sweep=10)
    sides(bm, -15, w=0.04)
    start = HC + V((0, HR.y + 0.03, 0.06))
    rk.blob(bm, start, (0.05, 0.045, 0.05), 6, 4)
    tail(bm, start, [start + V((0, 0.08, -0.08)), start + V((0, 0.1, -0.22)), start + V((0, 0.08, -0.36))], 0.055)


def hair_pigtails(bm):
    cap(bm, front=32, side=-12, back=-40)
    fringe(bm, (-30, -8, 14, 34), sweep=0, low=18)
    for s in (1, -1):
        start = HC + V((s * (HR.x + 0.02), 0.03, 0.02))
        rk.blob(bm, start, (0.04, 0.045, 0.045), 6, 4)
        tail(bm, start, [start + V((s * 0.07, 0.02, -0.06)), start + V((s * 0.09, 0.03, -0.17)), start + V((s * 0.08, 0.03, -0.28))], 0.05)


def hair_braid(bm):
    cap(bm, front=32, side=-10, back=-40)
    fringe(bm, (-30, -8, 14, 34), sweep=6, low=20)
    sides(bm, -20, w=0.045)
    p = HC + V((0, HR.y + 0.02, -0.08))
    for i in range(6):                                  # stacked chunks down the back
        q = p + V((0.012 * (1 if i % 2 else -1), 0.035 + i * 0.006, -0.065 * i))
        box(bm, q, V((0.05 - i * 0.004, 0.04, 0.042)), rnd=0.55, seg=6, rings=4)
    rk.tube(bm, [p + V((0, 0.06, -0.4)), p + V((0, 0.06, -0.48))], [(0.022, 0.022), (0.03, 0.03)], seg=5)


def hair_bun(bm):
    cap(bm, front=30, side=-10, back=-40)
    fringe(bm, (-26, 26), top=44, low=20, w=0.05)
    sides(bm, -10, w=0.04)
    c = HC + V((0, 0.07, HR.z + 0.04))
    box(bm, c, V((0.085, 0.08, 0.075)), rnd=0.7, seg=8, rings=6)


def hair_topknot(bm):
    cap(bm, front=36, side=0, back=-35, grow=0.018)
    c = HC + V((0, 0.02, HR.z + 0.02))
    rk.tube(bm, [c, c + V((0, 0, 0.05))], [(0.04, 0.04), (0.035, 0.035)], seg=6)
    box(bm, c + V((0, 0, 0.1)), V((0.06, 0.06, 0.055)), rnd=0.7, seg=7, rings=5)


def hair_mohawk(bm):
    for i in range(6):                                  # a crest of fins from brow to nape
        pitch = 62 - i * 28
        base, n = on_head(180 if pitch < 0 or i >= 3 else 0, abs(pitch) if i < 3 else 90 - (i - 2) * 30, 0.0)
        tip = base + n * (0.11 - abs(i - 2) * 0.012) + V((0, 0.04, 0))
        rk.tube(bm, [base - n * 0.02, tip], [(0.03, 0.07), (0.01, 0.012)], ref=V((1, 0, 0)), seg=4)


HAIR = {"short": hair_short, "messy": hair_messy, "swept": hair_swept, "curly": hair_curly, "long": hair_long,
        "ponytail": hair_ponytail, "pigtails": hair_pigtails, "braid": hair_braid, "bun": hair_bun,
        "topknot": hair_topknot, "mohawk": hair_mohawk}


def under_hat(fn):
    def build_it(bm):
        fn(bm)
        delete_faces(bm, lambda c: c.z > HC.z + 0.075)
    return build_it


# --- beards ------------------------------------------------------------------------------------

def jaw_chunk(bm, low, lift=0.02, top=-20, spread=75):
    keep = lambda yaw, pitch: abs(yaw) <= spread and pitch <= top
    rounded(bm, HC + V((0, -0.004, 0)), HR + V((lift, lift, lift)), seg=10, rings=8, keep=keep)
    for v in bm.verts:
        if v.co.z < HC.z - 0.1:
            v.co.z -= low


def beard_short(bm):
    jaw_chunk(bm, 0.02)
    mustache(bm)


def beard_full(bm):
    jaw_chunk(bm, 0.07, lift=0.026, top=0, spread=95)
    mustache(bm)


def beard_stubble(bm):
    jaw_chunk(bm, 0.0, lift=0.006, spread=80)


def mustache(bm, droop=0.0, w=0.034):
    for s in (1, -1):
        base, n = face_pt(s * 0.01, MOUTH_Z + 0.03)
        tip, _ = face_pt(s * 0.058, MOUTH_Z + 0.012 - droop)
        chunk(bm, base + n * 0.012, tip + n * 0.008, n, w * 0.6, 0.016, bend=0.01)


def beard_goatee(bm):
    mustache(bm, droop=0.03)
    base, n = face_pt(0, MOUTH_Z - 0.03)
    chunk(bm, base, base + V((0, -0.035, -0.09)), FRONT, 0.035, 0.02, bend=0.01)


def beard_mustache(bm):
    mustache(bm, droop=0.025, w=0.04)


def beard_braided(bm):
    beard_full(bm)
    p = HC + V((0, -HR.y - 0.03, -HR.z - 0.1))
    for i in range(3):
        box(bm, p + V((0, -0.005 * i, -0.06 * i)), V((0.038 - i * 0.006, 0.03, 0.035)), rnd=0.55, seg=6, rings=4)


BEARDS = {"short": beard_short, "full": beard_full, "stubble": beard_stubble, "goatee": beard_goatee,
          "mustache": beard_mustache, "braided": beard_braided}


# --- clothes -------------------------------------------------------------------------------------

def shirt(bm):
    lathe(bm, TORSO, seg=8, caps=True)


def neck(bm):
    rk.tube(bm, [V((0, 0.005, 1.47)), V((0, -0.005, 1.63))], [(0.068, 0.064)] * 2, seg=6)


def tunic(bm):
    lathe(bm, [(0.74, 0.272, 0.218), (0.86, 0.245, 0.195), (0.96, 0.226, 0.176)] + TORSO[1:-1], grow=0.016, seg=8)
    delete_faces(bm, lambda c: c.y < -0.08 and c.z > 1.36 and abs(c.x) < 0.08)


def tunic_hem(bm):
    lathe(bm, [(0.725, 0.292, 0.236), (0.79, 0.275, 0.222)], seg=8)


def jacket(bm):
    lathe(bm, [(0.88, 0.235, 0.186), (0.96, 0.226, 0.176)] + TORSO[1:-1], grow=0.022, seg=8)
    delete_faces(bm, lambda c: c.y < -0.1 and abs(c.x) < 0.06 and c.z < 1.47)
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.51)), 0.17, 0.14, 8), [(0.045, 0.032)] * 8, ref=V((0, 0, 1)), seg=4, closed=True)


def coat(bm):
    lathe(bm, [(0.5, 0.29, 0.24), (0.7, 0.265, 0.215), (0.9, 0.232, 0.182)] + TORSO[1:-1], grow=0.026, seg=10)
    delete_faces(bm, lambda c: c.y < -0.12 and abs(c.x) < 0.06 and c.z < 1.32)
    rk.tube(bm, rk.ring_path(V((0, 0.025, 1.5)), 0.18, 0.15, 10), [(0.065, 0.045)] * 10, ref=V((0, 0, 1)), seg=4, closed=True)


def coat_buttons(bm):
    for z in (1.08, 1.18, 1.28):
        for s in (1, -1):
            box(bm, V((s * 0.085, -0.205 + (z - 1.08) * 0.04, z)), V((0.016, 0.012, 0.016)), rnd=0.6, seg=6, rings=4)


ROBE = [(0.14, 0.34, 0.29), (0.4, 0.3, 0.25), (0.7, 0.262, 0.212), (0.9, 0.232, 0.182)] + TORSO[1:-1]


def robe(bm):
    lathe(bm, ROBE, grow=0.022, seg=10)
    delete_faces(bm, lambda c: c.y < -0.1 and c.z > 1.38 and abs(c.x) < 0.07)


def robe_trim(bm):
    rk.tube(bm, [V((0, -0.31, 0.16)), V((0, -0.27, 0.45)), V((0, -0.235, 0.75)), V((0, -0.2, 0.94)), V((0, -0.21, 1.12)), V((0, -0.22, 1.32))],
            [(0.05, 0.014)] * 6, ref=V((1, 0, 0)), seg=4)
    lathe(bm, [(0.13, 0.372, 0.322), (0.2, 0.36, 0.31)], seg=10)
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.5)), 0.16, 0.135, 10), [(0.04, 0.03)] * 10, ref=V((0, 0, 1)), seg=4, closed=True)


def robe_cuffs(bm):
    for s in (1, -1):
        rk.tube(bm, [V((s * x, ARM_Y, ARM_Z)) for x in (0.46, 0.6, 0.68)], [(0.1, 0.1), (0.13, 0.13), (0.145, 0.145)], ref=V((0, 0, 1)), seg=8, caps=False)


def rope_belt(bm):
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.0)), 0.262, 0.212, 10), [(0.024, 0.024)] * 10, ref=V((0, 0, 1)), seg=5, closed=True)
    knot = V((0.1, -0.21, 0.99))
    box(bm, knot, V((0.032, 0.024, 0.03)), rnd=0.6, seg=6, rings=4)
    for dx in (-0.015, 0.02):
        rk.tube(bm, [knot, knot + V((dx, -0.02, -0.14)), knot + V((dx * 1.5, -0.02, -0.28))], [(0.016, 0.016)] * 3, seg=4)


def armor(bm):
    rings = [(1.0, 0.245, 0.198), (1.14, 0.238, 0.19), (1.3, 0.268, 0.2), (1.43, 0.262, 0.19), (1.51, 0.19, 0.15)]
    lathe(bm, rings, seg=8)
    delete_faces(bm, lambda c: abs(c.x) > 0.21 and c.z > 1.38)
    rk.tube(bm, [V((0, -0.2, 1.02)), V((0, -0.225, 1.28)), V((0, -0.205, 1.45))], [(0.022, 0.016)] * 3, ref=V((1, 0, 0)), seg=4)


def armor_gorget(bm):
    rk.tube(bm, [V((0, 0.02, 1.49)), V((0, 0.02, 1.58))], [(0.17, 0.15), (0.12, 0.11)], seg=8)


def armor_skirt(bm):
    lathe(bm, [(0.66, 0.27, 0.222), (0.82, 0.25, 0.202), (1.0, 0.236, 0.188), (1.05, 0.232, 0.184)], seg=10)


def armor_rivets(bm):
    for z in (1.08, 1.22, 1.36):
        for s in (1, -1):
            box(bm, V((s * 0.11, -0.218 + (z - 1.08) * 0.02, z)), V((0.014, 0.012, 0.014)), rnd=0.6, seg=6, rings=4)


def tassets(bm):
    for a in (-0.9, -0.3, 0.3, 0.9, 2.5, 3.1, 3.7):
        c, sn = math.sin(a), -math.cos(a)
        top = V((c * 0.255, 0.02 + sn * 0.205, 0.98))
        bot = V((c * 0.285, 0.02 + sn * 0.235, 0.72))
        rk.tube(bm, [top, bot], [(0.06, 0.014), (0.065, 0.014)], ref=V((c, sn, 0)).cross(V((0, 0, 1))).normalized(), seg=4)


def jerkin(bm):
    lathe(bm, [(0.82, 0.25, 0.2), (0.94, 0.232, 0.182)] + TORSO[1:-1], grow=0.02, seg=8)
    delete_faces(bm, lambda c: abs(c.x) > 0.2 and c.z > 1.36)
    delete_faces(bm, lambda c: c.y < -0.08 and c.z > 1.34 and abs(c.x) < 0.07)


def jerkin_laces(bm):
    for z in (1.12, 1.21, 1.3):
        for s in (1, -1):
            rk.tube(bm, [V((-s * 0.045, -0.215, z)), V((s * 0.045, -0.215, z + 0.045))], [(0.008, 0.008)] * 2, seg=4)


def fur_ring(bm, z=1.5, rx=0.22, ry=0.18, count=12, seed=7, size=1.0):
    r = random.Random(seed)
    for k in range(count):
        a = (k + r.uniform(-0.2, 0.2)) / count * math.tau
        out = V((math.sin(a), -math.cos(a), 0))
        base = V((math.sin(a) * rx, 0.02 - math.cos(a) * ry, z + r.uniform(-0.01, 0.01)))
        chunk(bm, base, base + out * 0.05 * size + V((0, 0, -0.1 * size * r.uniform(0.8, 1.1))), out, 0.06 * size, 0.035 * size, bend=0.02)


def bare_arms(bm):
    arm_tube(bm, (0.15, 0.3, 0.46, 0.62, 0.75), (0.082, 0.078, 0.07, 0.064, 0.06))


def kilt(bm):
    n = 16
    tv, bv = [], []
    for k in range(n):
        a = k * math.tau / n
        r = 1.0 + (0.08 if k % 2 else 0.0)
        tv.append(bm.verts.new(V((math.cos(a) * 0.245, 0.02 + math.sin(a) * 0.196, 1.0))))
        bv.append(bm.verts.new(V((math.cos(a) * 0.3 * r, 0.02 + math.sin(a) * 0.245 * r, 0.6))))
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((tv[k], tv[k2], bv[k2], bv[k]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.014)


def kilt_band(bm):
    lathe(bm, [(0.95, 0.262, 0.212), (1.03, 0.258, 0.208)], seg=8)


def apron(bm):
    rk.tube(bm, [V((0, -0.2, 1.3)), V((0, -0.225, 1.0)), V((0, -0.26, 0.72)), V((0, -0.26, 0.5))],
            [(0.15, 0.012), (0.18, 0.012), (0.2, 0.014), (0.21, 0.014)], ref=V((1, 0, 0)), seg=4)
    box(bm, V((0, -0.255, 0.8)), V((0.08, 0.02, 0.05)), rnd=0.3, seg=4, rings=2)      # a big pocket


def tabard(bm):
    for y, sgn in ((-0.21, -1), (0.25, 1)):
        rk.tube(bm, [V((0, y, 1.42)), V((0, y + sgn * 0.02, 1.0)), V((0, y + sgn * 0.06, 0.6))],
                [(0.14, 0.012), (0.15, 0.012), (0.16, 0.014)], ref=V((1, 0, 0)), seg=4)


def tabard_emblem(bm):
    c = V((0, -0.24, 1.2))
    rk.tube(bm, [c + V((0, 0, -0.08)), c, c + V((0, 0, 0.08))], [(0.004, 0.01), (0.06, 0.012), (0.004, 0.01)], ref=V((1, 0, 0)), seg=4)


def diagonal(bm, w, thick, front_y=-0.2, back_y=0.22):
    for y in (front_y, back_y):
        pts = [V((0.2, y * 0.8, 1.48)), V((0.06, y, 1.32)), V((-0.1, y, 1.12)), V((-0.22, y * 0.85, 0.98))]
        rk.tube(bm, pts, [(w, thick)] * 4, ref=V((1, 0, 1)).normalized(), seg=4)


def strap(bm):
    diagonal(bm, 0.032, 0.012)
    box(bm, V((-0.25, -0.03, 0.9)), V((0.06, 0.1, 0.085)), rnd=0.4, seg=8, rings=4)


def sash(bm):
    diagonal(bm, 0.06, 0.016)
    box(bm, V((-0.2, -0.15, 0.97)), V((0.04, 0.03, 0.04)), rnd=0.6, seg=6, rings=4)


def bandolier(bm):
    diagonal(bm, 0.035, 0.012)


VIALS = [V((-0.12, -0.24, 1.18)), V((-0.03, -0.25, 1.28)), V((0.06, -0.24, 1.38))]


def vials(bm, which):
    for i, c in enumerate(VIALS):
        if i % 2 == which:
            box(bm, c, V((0.024, 0.02, 0.034)), rnd=0.7, seg=6, rings=4)


def vial_corks(bm):
    for c in VIALS:
        rk.tube(bm, [c + V((0, 0, 0.03)), c + V((0, 0, 0.055))], [(0.012, 0.012)] * 2, seg=5)


def vest(bm):
    lathe(bm, [(0.96, 0.226, 0.176)] + TORSO[2:-1], grow=0.04, seg=8)
    delete_faces(bm, lambda c: c.y < -0.1 and abs(c.x) < 0.07)
    delete_faces(bm, lambda c: abs(c.x) > 0.2 and c.z > 1.32)


def shoulder(bm, size, lift=0.0):
    for s in (1, -1):
        box(bm, V((s * 0.25, 0.04, 1.5 + lift)), size, rnd=0.45, seg=8, rings=4)


def plates(bm):
    for s in (1, -1):
        box(bm, V((s * 0.26, 0.04, 1.52)), V((0.12, 0.13, 0.07)), rnd=0.45, seg=8, rings=4)
        box(bm, V((s * 0.3, 0.04, 1.45)), V((0.1, 0.12, 0.05)), rnd=0.45, seg=8, rings=4)


def pauldron(bm):
    for k, (dx, dz, sz) in enumerate(((0.26, 1.54, 1.0), (0.31, 1.47, 0.86), (0.35, 1.4, 0.72))):
        box(bm, V((dx, 0.04, dz)), V((0.14 * sz, 0.15 * sz, 0.075 * sz)), rnd=0.5, seg=8, rings=4)


def pauldron_strap(bm):
    diagonal(bm, 0.028, 0.012)


def scarf(bm):
    rk.tube(bm, rk.ring_path(V((0, 0.012, 1.55)), 0.15, 0.13, 8), [(0.07, 0.055)] * 8, ref=V((0, 0, 1)), seg=5, closed=True)
    rk.tube(bm, [V((0.06, -0.12, 1.52)), V((0.09, -0.2, 1.4)), V((0.11, -0.21, 1.24))],
            [(0.065, 0.022), (0.06, 0.02), (0.055, 0.02)], ref=V((1, 0, 0)), seg=4)
    box(bm, V((0.11, -0.215, 1.22)), V((0.06, 0.02, 0.03)), rnd=0.3, seg=4, rings=2)


def cape(bm):
    rk.tube(bm, [V((0, 0.16, 1.5)), V((0, 0.22, 1.15)), V((0, 0.27, 0.66))], [(0.24, 0.026), (0.29, 0.028), (0.33, 0.032)], ref=V((1, 0, 0)), seg=6)


def cape_clasp(bm):
    rk.tube(bm, rk.ring_path(V((0, 0.02, 1.52)), 0.17, 0.145, 8), [(0.03, 0.022)] * 8, ref=V((0, 0, 1)), seg=4, closed=True)


def backpack(bm):
    box(bm, V((0, 0.25, 1.2)), V((0.19, 0.1, 0.2)), rnd=0.35, seg=8, rings=4)
    box(bm, V((0, 0.33, 1.12)), V((0.12, 0.04, 0.08)), rnd=0.35, seg=8, rings=4)       # front pocket
    for s in (1, -1):
        rk.tube(bm, [V((s * 0.12, 0.16, 1.42)), V((s * 0.13, -0.06, 1.5)), V((s * 0.14, -0.19, 1.32)), V((s * 0.14, -0.17, 1.06))],
                [(0.028, 0.01)] * 4, ref=V((1, 0, 0)), seg=4)


def bedroll(bm):
    rk.tube(bm, [V((-0.24, 0.24, 1.47)), V((0.24, 0.24, 1.47))], [(0.075, 0.075)] * 2, ref=V((0, 0, 1)), seg=6)


def quiver(bm):
    rk.tube(bm, [V((-0.1, 0.24, 0.95)), V((0.14, 0.24, 1.48))], [(0.07, 0.07), (0.075, 0.075)], seg=6)
    diagonal(bm, 0.028, 0.012)


def quiver_arrows(bm):
    for k in range(4):
        b = V((0.12 + (k % 2) * 0.03 - 0.03, 0.22 + (k // 2) * 0.03, 1.45))
        rk.tube(bm, [b, b + V((0.05, 0, 0.14))], [(0.007, 0.007)] * 2, seg=4)


def quiver_fletch(bm):
    for k in range(4):
        b = V((0.12 + (k % 2) * 0.03 - 0.03, 0.22 + (k // 2) * 0.03, 1.45)) + V((0.05, 0, 0.14))
        rk.tube(bm, [b - V((0.01, 0, 0.03)), b + V((0.012, 0, 0.04))], [(0.02, 0.006), (0.004, 0.004)], ref=V((0, 1, 0)), seg=4)


SHIELD_C = V((0, 0.27, 1.2))


def shield(bm):
    rk.tube(bm, [SHIELD_C, SHIELD_C + V((0, 0.03, 0))], [(0.27, 0.29), (0.26, 0.28)], ref=V((1, 0, 0)), seg=8)


def shield_rim(bm):
    rk.tube(bm, rk.ring_path(SHIELD_C + V((0, 0.015, 0)), 0.27, 0.29, 8), [(0.025, 0.025)] * 8, ref=V((0, 1, 0)), seg=4, closed=True)
    box(bm, SHIELD_C + V((0, 0.05, 0)), V((0.06, 0.03, 0.06)), rnd=0.6, seg=6, rings=4)


def ring_path_xz(c, rx, rz, n):
    return [c + V((rx * math.cos(k * math.tau / n), 0, rz * math.sin(k * math.tau / n))) for k in range(n)]


def shield_band(bm):
    rk.tube(bm, [SHIELD_C + V((-0.25, 0.034, 0)), SHIELD_C + V((0.25, 0.034, 0))], [(0.03, 0.006)] * 2, ref=V((0, 0, 1)), seg=4)


# --- headwear ------------------------------------------------------------------------------------

BRIM_Z = HC.z + 0.1


def brim(bm, c, r_out, r_in, droop=0.03, thick=0.02, n=10):
    ring_in = [bm.verts.new(c + V((math.cos(k * math.tau / n) * r_in, math.sin(k * math.tau / n) * r_in * 0.95, 0.01))) for k in range(n)]
    ring_out = [bm.verts.new(c + V((math.cos(k * math.tau / n) * r_out, math.sin(k * math.tau / n) * r_out * 0.95, -droop))) for k in range(n)]
    ib = [bm.verts.new(v.co - V((0, 0, thick))) for v in ring_in]
    ob = [bm.verts.new(v.co - V((0, 0, thick))) for v in ring_out]
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((ring_in[k], ring_out[k], ring_out[k2], ring_in[k2]))
        bm.faces.new((ib[k2], ob[k2], ob[k], ib[k]))
        bm.faces.new((ring_out[k], ob[k], ob[k2], ring_out[k2]))
        bm.faces.new((ring_in[k2], ib[k2], ib[k], ring_in[k]))


def hat(bm):
    c = V((HC.x, HC.y + 0.01, BRIM_Z))
    brim(bm, c, 0.37, 0.2)
    rk.tube(bm, [c, c + V((0, 0, 0.13)), c + V((0, 0.01, 0.2))], [(0.225, 0.21), (0.2, 0.19), (0.14, 0.13)], seg=8)


def hat_band(bm):
    c = V((HC.x, HC.y + 0.01, BRIM_Z))
    rk.tube(bm, [c + V((0, 0, 0.01)), c + V((0, 0, 0.055))], [(0.232, 0.218), (0.226, 0.213)], seg=8, caps=False)


def straw(bm):
    c = V((HC.x, HC.y + 0.01, BRIM_Z))
    brim(bm, c, 0.44, 0.2, droop=0.08, thick=0.018, n=12)
    rk.tube(bm, [c, c + V((0, 0, 0.08)), c + V((0, 0, 0.13))], [(0.225, 0.21), (0.2, 0.19), (0.08, 0.08)], seg=8)


def straw_band(bm):
    c = V((HC.x, HC.y + 0.01, BRIM_Z))
    rk.tube(bm, [c + V((0, 0, 0.01)), c + V((0, 0, 0.045))], [(0.232, 0.218), (0.226, 0.213)], seg=8, caps=False)


def hood(bm):
    keep = lambda yaw, pitch: not (abs(yaw) < 50 and pitch < 40)
    rounded(bm, HC + V((0, 0.01, 0.01)), HR + V((0.045, 0.045, 0.04)), seg=10, rings=8, keep=keep, jaw=0.15)
    rk.tube(bm, [V((0, 0.03, 1.66)), V((0, 0.03, 1.55)), V((0, 0.03, 1.47))], [(0.21, 0.19), (0.24, 0.21), (0.27, 0.22)], seg=8, caps=False)
    tip = HC + V((0, HR.y + 0.08, 0.05))
    rk.tube(bm, [HC + V((0, HR.y, 0.12)), tip, tip + V((0, 0.06, -0.08))], [(0.08, 0.06), (0.04, 0.035), (0.01, 0.01)], seg=6)


def helm(bm):
    keep = lambda yaw, pitch: pitch > 22 or (abs(yaw) > 40 and pitch > -50)
    rounded(bm, HC + V((0, 0.005, 0.0)), HR + V((0.035, 0.035, 0.03)), seg=10, rings=8, keep=keep, jaw=0.1)
    p, n = on_head(0, 22, 0.035)
    rk.tube(bm, [p, p + V((0, -0.01, -0.1))], [(0.022, 0.012), (0.016, 0.01)], ref=V((1, 0, 0)), seg=4)     # nose guard


def helm_crest(bm):
    for i in range(5):
        pitch = 50 + i * 20 if i < 3 else 90
        base, n = on_head(0 if i < 3 else 180, pitch if i < 3 else 90 - (i - 2) * 30, 0.03)
        rk.tube(bm, [base, base + n * 0.07 + V((0, 0.04, 0.02))], [(0.018, 0.05), (0.01, 0.02)], ref=V((1, 0, 0)), seg=4)


def head_ring(bm, z=HC.z + 0.09, h=0.04, grow=0.022):
    pts = [on_head(360 * k / 10 - 180 + 18, 0, 0)[0] for k in range(10)]
    ring = [V((p.x * (1 + grow / HR.x), HC.y + (p.y - HC.y) * (1 + grow / HR.y), z)) for p in pts]
    rk.tube(bm, ring, [(h, 0.015)] * 10, ref=V((0, 0, 1)), seg=4, closed=True)


def headband(bm):
    head_ring(bm)
    p = HC + V((-0.06, HR.y + 0.02, 0.09))
    for dx in (0.0, 0.05):
        chunk(bm, p, p + V((-0.03 + dx, 0.08, -0.12)), V((0, 1, 0)), 0.03, 0.01, bend=0.01)


def bandana(bm):
    keep = lambda yaw, pitch: pitch > 22 or (abs(yaw) > 110 and pitch > -10)
    rounded(bm, HC + V((0, 0.006, 0.0)), HR + V((0.03, 0.03, 0.025)), seg=10, rings=10, keep=keep)
    p = HC + V((0, HR.y + 0.035, 0.0))
    box(bm, p, V((0.04, 0.03, 0.035)), rnd=0.5, seg=6, rings=4)
    for dx in (-0.04, 0.04):
        chunk(bm, p, p + V((dx, 0.06, -0.12)), V((0, 1, 0)), 0.035, 0.012, bend=0.01)


def circlet(bm):
    pts = [on_head(360 * k / 10 - 180 + 18, 0, 0)[0] for k in range(10)]
    ring = [V((p.x * 1.09, HC.y + (p.y - HC.y) * 1.1, HC.z + 0.1 - (0.02 if abs(p.x) < 0.1 and p.y < HC.y else 0))) for p in pts]
    rk.tube(bm, ring, [(0.012, 0.012)] * 10, ref=V((0, 0, 1)), seg=4, closed=True)


def circlet_gem(bm):
    p, n = face_pt(0, HC.z + 0.075)
    rk.tube(bm, [p + n * 0.01, p + n * 0.035], [(0.02, 0.028), (0.008, 0.012)], ref=V((1, 0, 0)), seg=4)


def soft_cap(bm):
    keep = lambda yaw, pitch: pitch > 25
    rounded(bm, HC + V((0, 0.01, 0.02)), HR + V((0.035, 0.035, 0.035)), seg=10, rings=8, keep=keep)
    c = HC + V((0, -HR.y - 0.02, 0.07))
    rk.tube(bm, [c + V((-0.13, 0.04, 0)), c + V((0, -0.06, -0.01)), c + V((0.13, 0.04, 0))], [(0.02, 0.012)] * 3, ref=V((0, 0, 1)), seg=4)


def cap_feather(bm):
    base = HC + V((0.18, 0.04, 0.12))
    rk.tube(bm, [base, base + V((0.05, 0.08, 0.12)), base + V((0.04, 0.2, 0.2))], [(0.008, 0.03), (0.01, 0.04), (0.004, 0.006)], ref=V((1, 0, 0)), seg=4)


def crown_leaves(bm):
    for k in range(10):
        yaw = 360 * k / 10 - 180
        base, n = on_head(yaw, 30, 0.02)
        tip = base + n * 0.08 + V((0, 0, 0.03))
        chunk(bm, base, tip, V((0, 0, 1)), 0.04, 0.012, bend=0.01)


def crown_flowers(bm, which):
    for k in range(5):
        yaw = 360 * k / 5 - 180 + 36 + which * 30
        p, n = on_head(yaw, 36, 0.035)
        box(bm, p, V((0.03, 0.03, 0.022)) if which == 0 else V((0.015, 0.015, 0.016)), rnd=0.6, seg=6, rings=4)


def antlers(bm):
    for s in (1, -1):
        base, n = on_head(s * 55, 55, 0.0)
        a = base + V((s * 0.08, 0.0, 0.1))
        b = a + V((s * 0.06, 0.03, 0.12))
        rk.tube(bm, [base, a, b], [(0.026, 0.026), (0.02, 0.02), (0.006, 0.006)], seg=5)
        rk.tube(bm, [a, a + V((s * 0.02, -0.06, 0.08))], [(0.016, 0.016), (0.004, 0.004)], seg=4)
        rk.tube(bm, [a.lerp(b, 0.5), a.lerp(b, 0.5) + V((s * 0.08, 0.0, 0.03))], [(0.014, 0.014), (0.004, 0.004)], seg=4)


# --- build -------------------------------------------------------------------------------------------

def build(arm):
    parts = []
    flat = {"smooth": False, "shade_var": SHADE}
    deco = {"smooth": False, "shade_var": 0.0}

    def part(name, mat, weights, builder, **kw):
        kw = {**flat, **kw}
        parts.append(rk.build_part(arm, name, mat, weights, builder, **kw))

    # body
    part("H_base_head", "Skin", HEAD_W, head, shade_var=0.05)
    part("H_base_neck", "Skin", rk.weights_by_distance(["spine_03", "neck_01", "Head"]), neck, shade_var=0.04)
    part("H_base_hands", "Skin", HAND_W, hands, shade_var=0.05)
    part("H_base_shirt", "Cloth", torso_weights, shirt)
    part("H_base_sleeves", "Main", ARM_W, lambda bm: arm_tube(bm, (0.14, 0.3, 0.47, 0.64), (0.098, 0.09, 0.08, 0.078)))
    part("H_base_cuffs", "Cloth", FOREARM_W, lambda bm: arm_tube(bm, (0.62, 0.7), (0.086, 0.084)))
    part("H_base_belt", "Leather", rk.weights_by_distance(["pelvis", "spine_01"]),
         lambda bm: rk.tube(bm, rk.ring_path(V((0, 0.02, 0.98)), 0.235, 0.185, 8), [(0.038, 0.024)] * 8, ref=V((0, 0, 1)), seg=4, closed=True))
    part("H_base_buckle", "Gold", rk.fixed("pelvis"), lambda bm: box(bm, V((0, -0.205, 0.98)), V((0.04, 0.016, 0.034)), rnd=0.3, seg=4, rings=2))
    part("H_base_legs", "Second", LEG_W, legs)
    part("H_base_soles", "Second", FOOT_W, soles)
    for name, fn in NOSES.items():
        part(f"H_nose_{name}", "Skin", HEAD_W, fn, shade_var=0.04)
    part("H_ears", "Skin", HEAD_W, round_ears, shade_var=0.04)
    part("H_ears_pointed", "Skin", HEAD_W, ears(0.07, 0.04, 0.06), shade_var=0.04)
    part("H_ears_long", "Skin", HEAD_W, ears(0.12, 0.08, 0.1), shade_var=0.04)

    # feet
    part("H_feet_boots", "Leather", FOOT_W, boot)
    part("H_feet_shoes", "Leather", FOOT_W, lambda bm: boot(bm, top=0.17, cuff=False))
    part("H_feet_shoes_trouser", "Second", CALF_W, lambda bm: [rk.tube(bm, [V((s * 0.1, 0.025, 0.4)), V((s * 0.1, 0.03, 0.15))], [(0.098, 0.098), (0.09, 0.09)], seg=6) for s in (1, -1)])
    part("H_feet_wraps", "Leather", FOOT_W, lambda bm: boot(bm, top=0.16, cuff=False, toe=0.95))
    part("H_feet_wraps_cloth", "Cloth", CALF_W, lambda bm: [rk.tube(bm, [V((s * 0.1, 0.025, 0.42)), V((s * 0.1, 0.03, 0.14))], [(0.104, 0.104), (0.096, 0.096)], seg=6) for s in (1, -1)])
    part("H_feet_wraps_bands", "Leather", CALF_W, lambda bm: [rk.tube(bm, [V((s * 0.1, 0.028, z)), V((s * 0.1, 0.028, z + 0.03))], [(0.108 - (0.4 - z) * 0.03,) * 2] * 2, seg=6)
                                                               for s in (1, -1) for z in (0.36, 0.26, 0.17)])

    # face
    for name, fn in EYES.items():
        part(f"H_eyes_{name}", "Eyes", HEAD_W, fn, **deco)
        if name in SHINE:
            part(f"H_eyes_{name}_shine", "Shine", HEAD_W, SHINE[name], **deco)
    for name, fn in BROWS.items():
        part(f"H_brows_{name}", "Hair", HEAD_W, fn, **deco)
    for name, fn in MOUTHS.items():
        part(f"H_mouth_{name}", "Face", HEAD_W, fn, **deco)
    part("H_mouth_grin_teeth", "Teeth", HEAD_W, TEETH["grin"], **deco)
    part("H_cheeks_blush", "Blush", HEAD_W, lambda bm: [decal(bm, oval(s * 0.118, EYE_Z - 0.048, 0.024, 0.014, 6), 0.002, 0.003) for s in (1, -1)], **deco)
    mk = {"out": 0.002, "depth": 0.003}
    marks = {
        "freckles": lambda bm: [decal(bm, oval(s * (0.085 + dx), EYE_Z - 0.04 + dz, 0.0055, 0.0055, 4, math.pi / 4), **mk)
                                for s in (1, -1) for dx, dz in ((0.0, 0.0), (0.022, 0.008), (0.04, -0.006), (0.014, -0.022), (0.034, 0.02))],
        "scar": lambda bm: [strip(bm, [(0.05, EYE_Z - 0.04), (0.08, EYE_Z - 0.07), (0.105, EYE_Z - 0.09)], 0.011, **mk),
                            strip(bm, [(0.068, EYE_Z - 0.075), (0.09, EYE_Z - 0.056)], 0.009, out=0.003, depth=0.003)],
        "warpaint": lambda bm: [decal(bm, bar((s * 0.04, EYE_Z - 0.042 - k * 0.026), (s * 0.12, EYE_Z - 0.054 - k * 0.026), 0.014), **mk)
                                for s in (1, -1) for k in (0, 1)],
        "eyestripe": lambda bm: decal(bm, bar((-EYE_X, BROW_Z + 0.05), (-EYE_X, EYE_Z - 0.075), 0.024), out=0.001, depth=0.003),
        "mask": lambda bm: strip(bm, [(-0.17, EYE_Z + 0.004), (-0.11, EYE_Z + 0.014), (-0.04, EYE_Z + 0.012), (0.0, EYE_Z + 0.004),
                                      (0.04, EYE_Z + 0.012), (0.11, EYE_Z + 0.014), (0.17, EYE_Z + 0.004)], 0.068, out=0.0, depth=0.003),
        "tears": lambda bm: [decal(bm, bar((s * dx, EYE_Z - 0.04), (s * dx, EYE_Z - 0.04 - ln), 0.011), **mk)
                             for s in (1, -1) for dx, ln in ((0.062, 0.06), (0.084, 0.04))],
        "claws": lambda bm: [decal(bm, bar((0.04 + k * 0.024, EYE_Z + 0.03), (0.07 + k * 0.024, EYE_Z - 0.1), 0.011), **mk) for k in range(3)],
        "dots": lambda bm: [decal(bm, oval(s * (0.07 + k * 0.026), EYE_Z - 0.05 - k * 0.008, 0.009, 0.009, 6), **mk)
                            for s in (1, -1) for k in range(3)],
        "chin": lambda bm: [decal(bm, bar((x, MOUTH_Z - 0.025), (x * 1.2, MOUTH_Z - 0.075), 0.012), **mk) for x in (-0.028, 0.0, 0.028)],
        "noseband": lambda bm: strip(bm, [(-0.15, EYE_Z - 0.05), (-0.07, EYE_Z - 0.04), (0.0, EYE_Z - 0.038), (0.07, EYE_Z - 0.04), (0.15, EYE_Z - 0.05)], 0.024, **mk),
    }
    for name, fn in marks.items():
        part(f"H_marks_{name}", "Marks", HEAD_W, fn, **deco)

    def glasses(bm):
        for s in (1, -1):
            p, n = face_pt(s * EYE_X, EYE_Z)
            c = p + n * 0.03
            rk.tube(bm, ring_path_xz(c, 0.038, 0.034, 8), [(0.007, 0.007)] * 8, ref=V((0, 1, 0)), seg=4, closed=True)
            ear, _ = on_head(s * 85, -2, 0.01)
            rk.tube(bm, [c + V((s * 0.038, 0, 0.005)), ear], [(0.006, 0.006)] * 2, seg=4)
        a, n = face_pt(0.0, EYE_Z + 0.008)
        rk.tube(bm, [a + n * 0.03 + V((0.036, 0, 0)), a + n * 0.03 + V((-0.036, 0, 0))], [(0.006, 0.006)] * 2, seg=4)

    def eyepatch(bm):
        decal(bm, oval(EYE_X, EYE_Z, 0.038, 0.036, 6), 0.012, 0.008)
        pts = [face_pt(EYE_X + 0.035, EYE_Z + 0.03)[0] + V((0, -0.012, 0))] + [on_head(y, 22 - (y - 60) * 0.12, 0.01)[0] for y in (60, 100, 140, 180, 220, 260, 300)]
        rk.tube(bm, pts, [(0.01, 0.005)] * len(pts), ref=V((0, 0, 1)), seg=4)

    def earrings(bm):
        for s in (1, -1):
            c = V((s * (HR.x + 0.02), HC.y + 0.01, HC.z - 0.085))
            rk.tube(bm, [c + V((0, 0, 0.02)), c], [(0.006, 0.006)] * 2, seg=4)
            box(bm, c - V((0, 0, 0.01)), V((0.014, 0.014, 0.016)), rnd=0.6, seg=6, rings=4)

    part("H_extra_glasses", "Metal", HEAD_W, glasses)
    part("H_extra_eyepatch", "Leather", HEAD_W, eyepatch)
    part("H_extra_earrings", "Gold", HEAD_W, earrings)

    # hair and beards
    for style, fn in HAIR.items():
        part(f"H_hair_{style}", "Hair", hair_weights, fn)
        part(f"H_hair_{style}_hat", "Hair", hair_weights, under_hat(fn))
    for style, fn in BEARDS.items():
        part(f"H_beard_{style}", "Hair", HEAD_W, fn, recalc=False, outward=lambda c: c - HC)

    # clothes
    part("H_top_tunic", "Main", torso_weights, tunic)
    part("H_top_tunic_hem", "Accent", torso_weights, tunic_hem)
    part("H_top_jacket", "Main", torso_weights, jacket)
    part("H_top_coat", "Main", torso_weights, coat)
    part("H_top_coat_buttons", "Gold", torso_weights, coat_buttons)
    part("H_top_robe", "Main", torso_weights, robe)
    part("H_top_robe_trim", "Accent", torso_weights, robe_trim)
    part("H_top_robe_belt", "Cloth", torso_weights, rope_belt)
    part("H_top_robe_cuffs", "Main", FOREARM_W, robe_cuffs)
    part("H_top_armor", "Metal", torso_weights, armor)
    part("H_top_armor_gorget", "Metal", rk.weights_by_distance(["spine_03", "neck_01"]), armor_gorget)
    part("H_top_armor_skirt", "Main", torso_weights, armor_skirt)
    part("H_top_armor_rivets", "Gold", torso_weights, armor_rivets)
    part("H_top_armor_tassets", "Leather", torso_weights, tassets)
    part("H_top_jerkin", "Main", torso_weights, jerkin)
    part("H_top_jerkin_laces", "Leather", torso_weights, jerkin_laces)
    part("H_top_jerkin_fur", "Fur", rk.weights_by_distance(["spine_03", "clavicle_l", "clavicle_r", "neck_01"]), lambda bm: fur_ring(bm))
    part("H_top_jerkin_arms", "Skin", ARM_W, bare_arms, shade_var=0.05)
    part("H_waist_kilt", "Accent", skirt_weights, kilt)
    part("H_waist_kilt_band", "Second", skirt_weights, kilt_band)
    part("H_waist_apron", "Leather", torso_weights, apron)
    part("H_waist_tabard", "Accent", skirt_weights, tabard)
    part("H_waist_tabard_emblem", "Gold", skirt_weights, tabard_emblem)
    part("H_chest_strap", "Leather", torso_weights, strap)
    part("H_chest_sash", "Accent", torso_weights, sash)
    part("H_chest_bandolier", "Leather", torso_weights, bandolier)
    part("H_chest_bandolier_vials", "Potion", torso_weights, lambda bm: vials(bm, 0))
    part("H_chest_bandolier_vials2", "Potion2", torso_weights, lambda bm: vials(bm, 1))
    part("H_chest_bandolier_corks", "Wood", torso_weights, vial_corks)
    part("H_chest_vest", "Leather", torso_weights, vest)
    part("H_shoulders_pads", "Leather", SHOULDER_W, lambda bm: shoulder(bm, V((0.11, 0.12, 0.065))))
    part("H_shoulders_plates", "Metal", SHOULDER_W, plates)
    part("H_shoulders_fur", "Fur", rk.weights_by_distance(["spine_03", "clavicle_l", "clavicle_r", "neck_01"]),
         lambda bm: fur_ring(bm, 1.5, 0.25, 0.2, 14, 3, 1.25))
    part("H_shoulders_pauldron", "Metal", rk.weights_by_distance(["clavicle_l", "upperarm_l"], top=2), pauldron)
    part("H_shoulders_pauldron_strap", "Leather", torso_weights, pauldron_strap)
    neck_w = rk.weights_by_distance(["spine_03", "neck_01", "spine_02"])
    back_w = rk.weights_by_distance(["spine_02", "spine_03"], top=2)
    part("H_back_scarf", "Accent", neck_w, scarf)
    part("H_back_cape", "Accent", rk.weights_by_distance(["spine_03", "spine_02", "spine_01", "pelvis"], top=2), cape)
    part("H_back_cape_clasp", "Gold", neck_w, cape_clasp)
    part("H_back_backpack", "Leather", back_w, backpack)
    part("H_back_backpack_roll", "Accent", back_w, bedroll)
    part("H_back_quiver", "Leather", back_w, quiver)
    part("H_back_quiver_arrows", "Wood", back_w, quiver_arrows)
    part("H_back_quiver_fletch", "Feather", back_w, quiver_fletch)
    part("H_back_shield", "Accent", back_w, shield)
    part("H_back_shield_rim", "Metal", back_w, shield_rim)
    part("H_back_shield_band", "Second", back_w, shield_band)

    # headwear
    hood_w = rk.weights_by_distance(["Head", "neck_01", "spine_03"], top=2)
    part("H_head_hat", "Accent", HEAD_W, hat)
    part("H_head_hat_band", "Leather", HEAD_W, hat_band)
    part("H_head_straw", "Straw", HEAD_W, straw)
    part("H_head_straw_band", "Accent", HEAD_W, straw_band)
    part("H_head_hood", "Accent", lambda p: HEAD_W(p) if p.z > 1.62 else hood_w(p), hood)
    part("H_head_helm", "Metal", HEAD_W, helm)
    part("H_head_helm_crest", "Accent", HEAD_W, helm_crest)
    part("H_head_band", "Accent", HEAD_W, headband)
    part("H_head_bandana", "Accent", HEAD_W, bandana)
    part("H_head_circlet", "Gold", HEAD_W, circlet)
    part("H_head_circlet_gem", "Accent", HEAD_W, circlet_gem)
    part("H_head_cap", "Accent", HEAD_W, soft_cap)
    part("H_head_cap_feather", "Feather", HEAD_W, cap_feather)
    part("H_head_crown", "Leaf", HEAD_W, crown_leaves)
    part("H_head_crown_petals", "Petal", HEAD_W, lambda bm: crown_flowers(bm, 0))
    part("H_head_crown_blooms", "Bloom", HEAD_W, lambda bm: crown_flowers(bm, 1))
    part("H_head_antlers", "Antler", HEAD_W, antlers)
    part("H_head_antlers_band", "Leather", HEAD_W, lambda bm: head_ring(bm, h=0.03))
    return parts


def group_of(o):
    if o.name.startswith("H_base_"):
        return "H_base_" + o.data.materials[0].name   # one mesh per colour
    return None


arm = rk.load_rig(RIG)
rk.make_materials(COLORS)
parts = rk.join_groups(build(arm), group_of)
print("CARVED parts", len(parts), "tris", rk.tri_count(parts))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
rk.export(arm, parts, OUT)
print("CARVED written", OUT)
