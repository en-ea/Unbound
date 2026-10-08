"""Sunreach, the second land: a sun-baked coast of golden sand, banded sandstone, palms and turquoise sea,
and its harbour town Saffra (whitewashed and ochre adobe, domes, parapets, striped cloth awnings,
wooden beams poking out of the walls, arched doors, lanterns). Also the ship and the sea serpent.

Faceted flat-shaded low poly like make_trees.py / make_buildings.py: colours are stored per face in the
UVs (lowpoly.Builder), materials are plain white "Build" plus "Glow" for things that shine (lanterns,
the lighthouse fire, the serpent's spots and eyes). In Godot give every surface foliage_solid.gdshader
with albedo white (village.gd does exactly this) and glow > 0 on the "Glow" surfaces.

Axes (Blender -> Godot): Blender +Z up = Godot +Y; Blender -Y = Godot +Z. Houses face -Y here (+Z in
Godot, like the village houses); the ship's bow, the pier and the serpent's head point +Y here (-Z in Godot).

Nature: palm_a, palm_b, palm_small, cactus_a, cactus_b, desert_shrub, dune_grass, rock_sand_a/b/c,
        mesa_big, sand_arch, sea_rock, islet
Town:   house_dome, house_tower, house_wide, market_stall, well, lantern_post, palm_planter, pier, lighthouse
Sea:    ship (objects Hull, Sail, Wheel), serpent_head, serpent_segment, serpent_tail
Exported to game/assets/sunreach/.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_sunreach.py [-- name ...]
"""
import math
import os
import random
import sys
import bpy
import bmesh
from mathutils import Euler, Matrix, Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump, blade  # noqa: E402
from make_buildings import cube_at, soft, outline_prism, arch_outline  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "sunreach")
rnd = random.Random(21)

# --- palette -----------------------------------------------------------------------
SAND = [(0.95, 0.83, 0.58), (0.92, 0.79, 0.54), (0.97, 0.86, 0.63)]
WET_SAND = (0.8, 0.67, 0.47)
STRATA = [(0.93, 0.72, 0.48), (0.85, 0.55, 0.34), (0.96, 0.8, 0.57), (0.78, 0.42, 0.27), (0.9, 0.65, 0.41), (0.72, 0.37, 0.24)]
PALM_BARK = [(0.64, 0.48, 0.32), (0.55, 0.41, 0.28)]
FROND = [(0.42, 0.66, 0.26), (0.5, 0.72, 0.3), (0.34, 0.56, 0.24), (0.58, 0.74, 0.32)]
CACTUS = [(0.42, 0.62, 0.34), (0.34, 0.52, 0.3)]
SAGE = [(0.62, 0.66, 0.42), (0.7, 0.7, 0.45), (0.55, 0.6, 0.38)]
TWIG = (0.5, 0.38, 0.27)

WHITE = (0.98, 0.95, 0.89)
OCHRE = (0.93, 0.73, 0.47)
OCHRE_D = (0.85, 0.6, 0.37)
CLAY = (0.88, 0.58, 0.39)
TERRA = (0.8, 0.37, 0.23)
TEAL = (0.15, 0.58, 0.6)
TEAL_L = (0.3, 0.72, 0.7)
SAFFRON = (0.98, 0.71, 0.2)
CREAM = (0.98, 0.93, 0.8)
WOOD = (0.58, 0.39, 0.24)
WOOD_D = (0.38, 0.25, 0.16)
DARK = (0.2, 0.15, 0.15)
BRASS = (0.85, 0.62, 0.3)
IRON = (0.22, 0.2, 0.2)
GLOW = (1.0, 0.76, 0.4)
STONE = [(0.86, 0.76, 0.6), (0.8, 0.7, 0.54), (0.9, 0.81, 0.64)]
PLANK = [(0.68, 0.51, 0.34), (0.61, 0.45, 0.3), (0.74, 0.57, 0.38), (0.57, 0.42, 0.28)]

SER_TOP = (0.16, 0.2, 0.44)
SER_SIDE = (0.13, 0.44, 0.52)
SER_BELLY = (0.84, 0.86, 0.76)
SER_FIN = (0.25, 0.62, 0.7)
SER_SPOT = (0.45, 1.0, 0.95)


# --- small helpers --------------------------------------------------------------------
def jit(c, k=0.04, r=rnd):
    m = 1.0 + r.uniform(-k, k)
    return tuple(min(1.0, x * m) for x in c)


def shade(c, k):
    return tuple(min(1.0, x * k) for x in c)


def paint(b, faces, color, var=0.03, mat="Build"):
    for f in faces:
        b.paint([f], mat, jit(color, var))


def paint_by(b, faces, fn, mat="Build"):
    """Paints each face with fn(face) (its normal is up to date)."""
    for f in faces:
        f.normal_update()
        b.paint([f], mat, fn(f))


def box(b, center, size, color, var=0.03, rot=None, mat="Build"):
    paint(b, b.new_faces(cube_at(b, center, size, rot)), color, var, mat)


def beam(b, p0, p1, w, color, seg=4, mat="Build"):
    d = (p1 - p0).normalized()
    ref = V((0, 0, 1)) if abs(d.z) < 0.9 else V((1, 0, 0))
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [p0, p1], [(w, w)] * 2, ref=ref, seg=seg)), color, 0.03, mat)


def tube(b, pts, radii, color, seg=8, ref=V((1, 0, 0)), caps=True, var=0.03, mat="Build"):
    rr = [(r, r) if isinstance(r, (int, float)) else r for r in radii]
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, rr, ref=ref, seg=seg, caps=caps))
    if color is not None:
        paint(b, faces, color, var, mat)
    return faces


def turned(b, angle, fn, pivot=V((0, 0, 0))):
    """Runs fn (which builds and paints) and turns what it made about Z through `pivot`."""
    before = set(b.bm.verts)
    fn()
    m = Matrix.Rotation(angle, 3, "Z")
    for v in b.bm.verts:
        if v not in before:
            v.co = pivot + m @ (v.co - pivot)


def loft(bm, rings, cap0=True, cap1=True, tip=None):
    """Joins rings of points (same count, closed loops) with quads; optional end caps or a tip point."""
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for i in range(len(vs) - 1):
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((vs[i][k], vs[i][k2], vs[i + 1][k2], vs[i + 1][k]))
    if cap0:
        bm.faces.new(list(reversed(vs[0])))
    if tip is not None:
        t = bm.verts.new(tip)
        for k in range(n):
            bm.faces.new((vs[-1][k], vs[-1][(k + 1) % n], t))
    elif cap1:
        bm.faces.new(vs[-1])


def fin(b, base, tips, side, colors, mat="Build"):
    """A thin fin or frill between a base line and a (jagged) outer line, thickness 2 x |side|."""
    faces = []
    n = len(base)
    for i in range(n - 1):
        def make(i=i):
            bm = b.bm
            a0, a1 = bm.verts.new(base[i] + side), bm.verts.new(base[i + 1] + side)
            b0, b1 = bm.verts.new(base[i] - side), bm.verts.new(base[i + 1] - side)
            t0a, t1a = bm.verts.new(tips[i] + side * 0.3), bm.verts.new(tips[i + 1] + side * 0.3)
            t0b, t1b = bm.verts.new(tips[i] - side * 0.3), bm.verts.new(tips[i + 1] - side * 0.3)
            bm.faces.new((a0, a1, t1a, t0a))
            bm.faces.new((b0, t0b, t1b, b1))
            bm.faces.new((t0a, t1a, t1b, t0b))
            bm.faces.new((a0, t0a, t0b, b0))
            bm.faces.new((a1, b1, t1b, t1a))
        f = b.new_faces(make)
        paint(b, f, colors[i % len(colors)], 0.03, mat)
        faces += f
    return faces


def band_color(z, h=1.15, z0=0.0, palette=STRATA, k=0.04):
    return jit(palette[int(math.floor((z - z0) / h)) % len(palette)], k)


def prism_yz(b, outline, x0, x1, color, var=0.03):
    """A profile [(y, z)] extruded along X from x0 to x1."""
    def make():
        bm = b.bm
        a = [bm.verts.new(V((x0, y, z))) for y, z in outline]
        c = [bm.verts.new(V((x1, y, z))) for y, z in outline]
        bm.faces.new(a)
        bm.faces.new(list(reversed(c)))
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            bm.faces.new((a[i], a[j], c[j], c[i]))
    paint(b, b.new_faces(make), color, var)


# --- nature ---------------------------------------------------------------------------
def frond(b, top, ang, length, lift, color, r):
    """A long arching palm leaf, folded in a shallow V, with a feathered (wide/narrow) edge."""
    h = V((math.cos(ang), math.sin(ang), 0))
    left = V((0, 0, 1)).cross(h).normalized()
    N = 5
    rows = []
    for i in range(N):
        t = i / N
        spine = top + h * (length * t) + V((0, 0, length * (lift * t - (0.62 + lift) * t * t)))
        w = length * 0.2 * math.sin(math.pi * min(0.12 + t * 1.05, 1.0)) * (1.0 if i % 2 else 0.72)
        rows.append((spine, spine + left * w - V((0, 0, w * 0.35)), spine - left * w - V((0, 0, w * 0.35)), spine - V((0, 0, 0.05))))
    tip = top + h * length + V((0, 0, length * (lift - 0.62 - lift)))

    def make():
        bm = b.bm
        vs = [[bm.verts.new(p) for p in row] for row in rows]
        t = bm.verts.new(tip)
        for i in range(N - 1):
            S, L, R, B = vs[i]
            S2, L2, R2, B2 = vs[i + 1]
            bm.faces.new((S, L, L2, S2))
            bm.faces.new((S, S2, R2, R))
            bm.faces.new((B, B2, L2, L))
            bm.faces.new((B, R, R2, B2))
        S, L, R, B = vs[-1]
        for f in ((S, L, t), (S, t, R), (B, t, L), (B, R, t)):
            bm.faces.new(f)
        S, L, R, B = vs[0]
        bm.faces.new((S, R, B, L))
    faces = b.new_faces(make)
    for f in faces:
        f.normal_update()
        b.paint([f], "Build", jit(color if f.normal.z > -0.2 else shade(color, 0.72), 0.05, r))


def palm(b, base, height, lean, bend, fronds, seed, scale=1.0, nuts=3):
    r = random.Random(seed)
    d = V((math.cos(lean), math.sin(lean), 0))
    nseg = 8
    pts = [base + d * bend * (i / nseg) ** 2 + V((0, 0, height * i / nseg)) for i in range(nseg + 1)]
    pts[0] = pts[0] - V((0, 0, 0.25))
    for i in range(nseg):                       # stacked rings, each wider at its top: the scaly palm trunk
        p0, p1 = pts[i], pts[i + 1]
        r0 = (0.3 - 0.14 * i / nseg) * scale
        tube(b, [p0 - (p1 - p0) * 0.08, p1], [r0 * 0.8, r0 * 1.06], PALM_BARK[i % 2], seg=6, caps=i == 0)
    top = pts[-1]
    clump(b, top + V((0, 0, 0.05)), 0.32 * scale, 1, r, (0.5, 0.44, 0.26), "Build", 0.8)
    for k in range(nuts):
        a = k * math.tau / max(nuts, 1) + r.uniform(-0.3, 0.3)
        clump(b, top + V((math.cos(a) * 0.26 * scale, math.sin(a) * 0.26 * scale, -0.22 * scale)), 0.15 * scale, 1, r, (0.42, 0.3, 0.18), "Build", 1.0)
    for k in range(fronds):
        a = k * math.tau / fronds + r.uniform(-0.25, 0.25)
        up = k % 3 == 0
        frond(b, top + V((0, 0, 0.12 * scale)), a, (2.7 if not up else 2.2) * scale * r.uniform(0.9, 1.1),
              0.75 if up else r.uniform(0.25, 0.45), FROND[k % len(FROND)], r)


def nature_palm(seed, height, bend, fronds, scale=1.0, nuts=3):
    b = Builder(["Build"])
    palm(b, V((0, 0, 0)), height, random.Random(seed).uniform(0, math.tau), bend, fronds, seed, scale, nuts)
    return b


def ribbed(b, pts, radii, ribs=6):
    """A ribbed cactus column through pts with a rounded top, striped light/dark along the ribs."""
    seg = ribs * 2
    rings = []
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = V((1, 0, 0)) if abs(t.x) < 0.9 else V((0, 1, 0))
        a = (ref - t * ref.dot(t)).normalized()
        bb = t.cross(a)
        rings.append([c + (a * math.cos(k * math.tau / seg) + bb * math.sin(k * math.tau / seg)) * radii[i] * (1.0 if k % 2 == 0 else 0.8)
                      for k in range(seg)])
    t = (pts[-1] - pts[-2]).normalized()
    top = [pts[-1] + t * radii[-1] * 0.45 + (p - pts[-1]) * 0.6 for p in rings[-1]]
    faces = b.new_faces(lambda: loft(b.bm, rings + [top], tip=pts[-1] + t * radii[-1] * 0.75))
    n = len(faces)
    for i, f in enumerate(faces):
        k = i % seg
        b.paint([f], "Build", jit(CACTUS[k % 2], 0.04))


def cactus(seed, height, arms):
    r = random.Random(seed)
    b = Builder(["Build"])
    rad = 0.32 if height > 3 else 0.26
    pts = [V((0, 0, -0.15)), V((0, 0, height * 0.3)), V((0.03, 0, height * 0.6)), V((0.0, 0.03, height * 0.85)), V((0, 0, height - rad * 0.8))]
    ribbed(b, pts, [rad * 1.05, rad, rad, rad * 0.97, rad * 0.9])
    for k, (h, a, up) in enumerate(arms):
        d = V((math.cos(a), math.sin(a), 0))
        z = height * h
        ar = rad * 0.7
        apts = [d * 0.1 + V((0, 0, z)), d * (rad + 0.35) + V((0, 0, z + 0.05)), d * (rad + 0.55) + V((0, 0, z + 0.35)),
                d * (rad + 0.6) + V((0, 0, z + up * 0.6)), d * (rad + 0.6) + V((0, 0, z + up))]
        ribbed(b, apts, [ar, ar, ar, ar * 0.95, ar * 0.9])
    return b


def cactus_a():
    return cactus(5, 3.5, [(0.42, 0.3, 1.3), (0.55, math.pi + 0.2, 0.9)])


def cactus_b():
    b = cactus(9, 2.3, [(0.45, 1.9, 0.8)])
    r = random.Random(3)
    for k in range(3):
        a = k * math.tau / 3
        clump(b, V((math.cos(a) * 0.14, math.sin(a) * 0.14, 2.3 - 0.26 * 0.8 + 0.2)), 0.08, 1, r, (0.98, 0.5, 0.62), "Build", 0.7)
    clump(b, V((0, 0, 2.3 - 0.2 + 0.25)), 0.06, 1, r, (0.99, 0.86, 0.35), "Build", 0.7)
    return b


def desert_shrub():
    r = random.Random(14)
    b = Builder(["Build"])
    for k in range(5):
        a = k * math.tau / 5 + r.uniform(-0.3, 0.3)
        tip = V((math.cos(a) * 0.75, math.sin(a) * 0.75, r.uniform(0.6, 0.85)))
        tube(b, [V((0, 0, -0.05)), tip * 0.5, tip], [0.05, 0.035, 0.02], TWIG, seg=3)
    for k in range(5):
        a = k * math.tau / 5 + r.uniform(-0.4, 0.4)
        c = V((math.cos(a) * 0.42, math.sin(a) * 0.42, 0.42 + r.uniform(0, 0.15)))
        clump(b, c, r.uniform(0.3, 0.42), 1, r, SAGE[k % 3], "Build", 0.6)
    clump(b, V((0, 0, 0.55)), 0.4, 1, r, SAGE[1], "Build", 0.6)
    return b


def dune_grass():
    r = random.Random(31)
    b = Builder(["Build"])
    for i in range(14):
        ang = r.uniform(0, math.tau)
        base = V((math.cos(ang) * r.uniform(0, 0.15), math.sin(ang) * r.uniform(0, 0.15), -0.03))
        lean = V((math.cos(ang), math.sin(ang), 0)) * r.uniform(0.15, 0.45)
        tip = base + lean + V((0, 0, r.uniform(0.5, 0.9)))
        faces = b.new_faces(lambda base=base, tip=tip: blade(b.bm, base, tip, 0.04))
        b.paint(faces, "Build")
        b.gradient(faces, (0.55, 0.56, 0.3), (0.93, 0.84, 0.52) if i % 3 else (0.78, 0.8, 0.45))
    return b


def sand_rock(seed, size, widths, colors):
    """Layered sandstone: stacked chipped slabs, each its own band of ochre or rust."""
    r = random.Random(seed)
    b = Builder(["Build"])
    z = -0.15 * size
    for i, w in enumerate(widths):
        h = size * r.uniform(0.24, 0.32)
        c = V((r.uniform(-0.06, 0.06) * size, r.uniform(-0.06, 0.06) * size, z + h / 2))
        sz = (size * w * r.uniform(0.95, 1.08), size * w * r.uniform(0.7, 0.85), h * 1.06)
        faces = b.new_faces(lambda c=c, sz=sz, i=i: rk.boulder(b.bm, c, sz, seed * 10 + i, rot=(0, 0, r.uniform(0, 360)), round=0.3, chips=2, n=28, top=0.9))
        col = colors[i % len(colors)]
        paint_by(b, faces, lambda f, col=col: jit(col if f.normal.z < 0.7 else shade(col, 1.07), 0.04, r))
        z += h * 0.9
    return b


def rock_sand_a():
    return sand_rock(1, 1.5, [1.0, 0.8], [STRATA[0], STRATA[3]])


def rock_sand_b():
    return sand_rock(2, 2.5, [1.0, 0.85, 0.62], [STRATA[1], STRATA[2], STRATA[5]])


def rock_sand_c():
    return sand_rock(3, 4.0, [1.0, 0.72, 0.6, 0.86], [STRATA[4], STRATA[3], STRATA[0], STRATA[5]])     # a hoodoo with an overhanging cap


def mesa_big():
    """A flat-topped banded mesa (~14 m wide, 10 m tall) on a sandy talus skirt."""
    r = random.Random(77)
    b = Builder(["Build"])
    n = 16
    base_r = [r.uniform(0.9, 1.08) for _ in range(n)]

    def outline(scale, z, wob):
        return [V((math.cos(k * math.tau / n) * 7.0 * scale * base_r[k] * r.uniform(1 - wob, 1 + wob),
                   math.sin(k * math.tau / n) * 5.0 * scale * base_r[k] * r.uniform(1 - wob, 1 + wob), z)) for k in range(n)]
    # Talus: a sandy skirt sloping up to the foot of the cliffs.
    faces = b.new_faces(lambda: loft(b.bm, [outline(1.22, -0.4, 0.03), outline(1.08, 1.2, 0.04), outline(0.9, 2.4, 0.03)], cap1=False))
    paint_by(b, faces, lambda f: jit(SAND[1] if f.calc_center_median().z < 1.0 else STRATA[0], 0.05, r))
    bands = [(2.2, 3.8, 0.88, 0.86, STRATA[1]), (3.8, 5.0, 0.86, 0.88, STRATA[2]), (5.0, 6.4, 0.83, 0.82, STRATA[3]),
             (6.4, 7.9, 0.84, 0.84, STRATA[0]), (7.9, 9.0, 0.82, 0.81, STRATA[5]), (9.0, 10.0, 0.85, 0.85, STRATA[4])]
    for z0, z1, s0, s1, col in bands:
        faces = b.new_faces(lambda z0=z0, z1=z1, s0=s0, s1=s1: loft(b.bm, [outline(s0, z0, 0.035), outline(s1, z1, 0.035)]))
        paint_by(b, faces, lambda f, col=col: jit(col if abs(f.normal.z) < 0.7 else shade(col, 1.08), 0.05, r))
    # Fallen blocks round the foot.
    for k, (a, s) in enumerate([(0.6, 1.8), (2.5, 1.3), (4.2, 2.2), (5.4, 1.1)]):
        c = V((math.cos(a) * 8.6, math.sin(a) * 6.3, s * 0.3))
        faces = b.new_faces(lambda c=c, s=s, k=k: rk.boulder(b.bm, c, (s, s * 0.8, s * 0.7), 70 + k, rot=(0, 0, a * 50), round=0.3, chips=2, n=24))
        paint(b, faces, STRATA[k % len(STRATA)], 0.05)
    return b


def sand_arch():
    """A natural sandstone arch ~14 m wide, ~10 m tall, with strata running through legs and span."""
    r = random.Random(5)
    b = Builder(["Build"])
    for side in (-1, 1):
        z = -0.4
        for i, (w, h) in enumerate([(3.6, 2.4), (3.0, 2.2), (2.7, 2.3)]):
            c = V((side * (5.4 + r.uniform(-0.2, 0.2) - i * 0.1), r.uniform(-0.2, 0.2), z + h / 2))
            faces = b.new_faces(lambda c=c, w=w, h=h, i=i: rk.boulder(b.bm, c, (w, w * 0.85, h * 1.05), 40 + i + side * 7, rot=(0, 0, r.uniform(0, 360)), round=0.3, chips=2, n=26))
            paint_by(b, faces, lambda f: band_color(f.calc_center_median().z))
            z += h * 0.95
    pts, radii = [], []
    for i in range(9):
        t = i / 8
        pts.append(V((-5.3 + 10.6 * t, 0.0, 6.3 + 3.0 * math.sin(math.pi * t))))
        th = 1.0 + 0.45 * abs(t - 0.5) * 2 + r.uniform(-0.08, 0.08)
        radii.append((1.5 + r.uniform(-0.15, 0.15), th))
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=V((0, 1, 0)), seg=6))
    paint_by(b, faces, lambda f: band_color(f.calc_center_median().z) if f.normal.z < 0.6 else jit(STRATA[2], 0.05, r))
    for k, x in enumerate((-2.0, 1.4)):         # a couple of crumbling chunks on top of the span
        c = V((x, r.uniform(-0.3, 0.3), 9.3 - abs(x) * 0.25))
        faces = b.new_faces(lambda c=c, k=k: rk.boulder(b.bm, c, (1.6, 1.3, 0.9), 60 + k, rot=(0, 0, 30 * k), round=0.3, chips=2, n=20))
        paint(b, faces, STRATA[4 - k], 0.05)
    return b


def sea_rock():
    """A jagged rock sticking out of the sea: weedy dark at the waterline, rust above, bird-white top."""
    r = random.Random(8)
    b = Builder(["Build"])
    for k, (c, s, top) in enumerate([(V((0, 0, 1.8)), (3.0, 2.6, 7.6), 0.35), (V((1.5, 0.6, 0.7)), (2.2, 2.0, 4.4), 0.45),
                                     (V((-1.3, -0.5, 0.0)), (2.0, 1.8, 2.8), 0.6)]):
        faces = b.new_faces(lambda c=c, s=s, top=top, k=k: rk.boulder(b.bm, c, s, 90 + k, rot=(r.uniform(-8, 8), r.uniform(-8, 8), r.uniform(0, 360)), round=0.25, chips=3, n=30, top=top))

        def col(f):
            p = f.calc_center_median()
            if p.z < 0.45:
                return jit((0.3, 0.34, 0.27) if p.z < 0 else (0.38, 0.36, 0.27), 0.06, r)
            if f.normal.z > 0.55 and p.z > 3.0:
                return jit((0.93, 0.91, 0.85), 0.03, r)
            return shade(band_color(p.z, 1.4, 0.4), 0.82)
        paint_by(b, faces, col)
    return b


def islet():
    """A small sand islet ~16 m wide, the sand top ~1 m above the waterline, with three palms."""
    r = random.Random(12)
    b = Builder(["Build"])
    n = 16
    wob = [r.uniform(0.88, 1.1) for _ in range(n)]

    def ring(rad, z):
        return [V((math.cos(k * math.tau / n) * rad * wob[k] * (1.0 if z < 0.95 else 0.9), math.sin(k * math.tau / n) * rad * 0.82 * wob[k], z)) for k in range(n)]
    faces = b.new_faces(lambda: loft(b.bm, [ring(9.0, -1.8), ring(8.1, -0.25), ring(7.3, 0.3), ring(5.6, 0.82), ring(2.6, 1.02)], tip=V((0.3, 0, 1.05))))

    def col(f):
        z = f.calc_center_median().z
        if z < -0.05:
            return jit((0.72, 0.68, 0.52), 0.04, r)
        if z < 0.4:
            return jit(WET_SAND, 0.04, r)
        return jit(SAND[r.randrange(3)], 0.03, r)
    paint_by(b, faces, col)
    palm(b, V((-1.5, 0.8, 0.95)), 5.6, 2.6, 1.6, 8, 61)
    palm(b, V((1.2, 1.4, 0.95)), 4.6, 0.6, 1.2, 7, 62)
    palm(b, V((0.3, -1.6, 0.95)), 3.4, -1.3, 0.9, 7, 63, 0.8, 2)
    for k, (x, y) in enumerate([(3.6, -1.2), (-3.8, -1.6), (2.4, 3.0)]):
        for i in range(5):
            a = r.uniform(0, math.tau)
            base = V((x + math.cos(a) * 0.15, y + math.sin(a) * 0.15, 0.85))
            tip = base + V((math.cos(a) * 0.3, math.sin(a) * 0.3, r.uniform(0.5, 0.75)))
            faces = b.new_faces(lambda base=base, tip=tip: blade(b.bm, base, tip, 0.04))
            b.paint(faces, "Build")
            b.gradient(faces, (0.55, 0.56, 0.3), (0.9, 0.82, 0.5))
    for k, c in enumerate([V((5.6, 1.6, 0.35)), V((-5.2, 2.2, 0.3))]):
        faces = b.new_faces(lambda c=c, k=k: rk.boulder(b.bm, c, (1.4, 1.1, 0.9), 30 + k, rot=(0, 0, 40 * k), round=0.3, chips=2, n=22))
        paint(b, faces, STRATA[k * 3], 0.05)
    return b


# --- Saffra town pieces ----------------------------------------------------------------
def adobe(b, center, size, color, taper=0.04, var=0.02):
    """A box whose walls lean in a little towards the top, like thick mud-brick walls."""
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            k = 1.0 - (taper if v.co.z > 0 else 0.0)
            v.co = V((v.co.x * size[0] * k, v.co.y * size[1] * k, v.co.z * size[2])) + center
    paint(b, b.new_faces(make), color, var)


def parapet(b, x0, x1, y0, y1, z, h, t, color, corners=True, corner_color=None):
    """A low wall round a flat roof, with chunky rounded corner posts."""
    box(b, V(((x0 + x1) / 2, y0 + t / 2, z + h / 2)), (x1 - x0, t, h), color)
    box(b, V(((x0 + x1) / 2, y1 - t / 2, z + h / 2)), (x1 - x0, t, h), color)
    box(b, V((x0 + t / 2, (y0 + y1) / 2, z + h / 2)), (t, y1 - y0 - 2 * t, h), color)
    box(b, V((x1 - t / 2, (y0 + y1) / 2, z + h / 2)), (t, y1 - y0 - 2 * t, h), color)
    if corners:
        for x in (x0 + 0.18, x1 - 0.18):
            for y in (y0 + 0.18, y1 - 0.18):
                soft(b, cube_at(b, V((x, y, z + h * 0.75)), (0.44, 0.44, h * 1.5 + 0.1)), corner_color or color, 0.1, 1)


def vigas(b, x0, x1, y, z, count, out=-1):
    """Round roof beams poking out of a wall at y (out = -1: towards -Y)."""
    for i in range(count):
        x = x0 + (x1 - x0) * i / max(count - 1, 1)
        tube(b, [V((x, y - out * 0.1, z)), V((x, y + out * 0.42, z))], [0.08, 0.08], WOOD_D if i % 2 else WOOD, seg=5)


def vigas_x(b, y0, y1, x, z, count, out=1):
    for i in range(count):
        y = y0 + (y1 - y0) * i / max(count - 1, 1)
        tube(b, [V((x - out * 0.1, y, z)), V((x + out * 0.42, y, z))], [0.08, 0.08], WOOD_D if i % 2 else WOOD, seg=5, ref=V((0, 0, 1)))


def arch_door(b, x, yf, z0, w, h, frame, door, steps=5):
    """An arched door on a wall facing -Y at y = yf: a coloured surround and a door panel set in it."""
    b.paint(b.new_faces(outline_prism(b, arch_outline(x, z0, w + 0.4, h + 0.2, steps), yf - 0.07, yf + 0.05)), "Build", frame)
    b.paint(b.new_faces(outline_prism(b, arch_outline(x, z0, w, h, steps), yf - 0.1, yf - 0.03)), "Build", door)
    box(b, V((x, yf - 0.12, z0 + h * 0.48)), (0.03, 0.04, h * 0.85), shade(door, 0.75), 0.0)     # the split between two leaves
    box(b, V((x, yf - 0.35, z0 - 0.05)), (w + 0.6, 0.5, 0.2), STONE[0])


def arch_window(b, x, yf, z0, w, h, frame=TEAL, inner=DARK, sill=True):
    b.paint(b.new_faces(outline_prism(b, arch_outline(x, z0, w + 0.24, h + 0.12, 4), yf - 0.05, yf + 0.04)), "Build", frame)
    b.paint(b.new_faces(outline_prism(b, arch_outline(x, z0, w, h, 4), yf - 0.07, yf - 0.02)), "Build", inner)
    if sill:
        box(b, V((x, yf - 0.1, z0 - 0.06)), (w + 0.4, 0.22, 0.1), WHITE)


def awning(b, x, yf, z, w, depth, drop, colors, stripes=6):
    """A sloping striped cloth awning on a wall facing -Y, with a scalloped valance and two struts."""
    for i in range(stripes):
        xa = x - w / 2 + w * i / stripes
        xb = xa + w / stripes
        quad = [V((xa, yf - 0.05, z)), V((xb, yf - 0.05, z)), V((xb, yf - depth, z - drop)), V((xa, yf - depth, z - drop))]
        col = colors[i % len(colors)]

        def make(quad=quad):
            bm = b.bm
            top = [bm.verts.new(p) for p in quad]
            bot = [bm.verts.new(p - V((0, 0, 0.05))) for p in quad]
            bm.faces.new(top)
            bm.faces.new(list(reversed(bot)))
            for k in range(4):
                j = (k + 1) % 4
                bm.faces.new((top[j], top[k], bot[k], bot[j]))
        paint(b, b.new_faces(make), col, 0.02)
        # valance tongue under each stripe
        c = V(((xa + xb) / 2, yf - depth - 0.01, z - drop - 0.13))
        paint(b, b.new_faces(lambda c=c, xa=xa, xb=xb: outline_prism(b, [(xa, c.z + 0.12), (xb, c.z + 0.12), ((xa + xb) / 2, c.z - 0.14)], c.y - 0.02, c.y + 0.02)()), col, 0.02)
    for s in (-1, 1):
        beam(b, V((x + s * (w / 2 - 0.05), yf - depth + 0.05, z - drop - 0.05)), V((x + s * (w / 2 - 0.05), yf, z - drop - 0.7)), 0.035, WOOD_D)


def dome(b, center, r, h, color, seg=12, finial=True):
    pts, radii = [], []
    for k in range(5):
        a = k / 5 * math.pi / 2 * 0.98
        pts.append(center + V((0, 0, h * math.sin(a))))
        radii.append((r * math.cos(a),) * 2)
    tube(b, pts, radii, color, seg=seg, var=0.02)
    if finial:
        tube(b, [center + V((0, 0, h * 0.95)), center + V((0, 0, h + 0.35))], [0.06, 0.04], BRASS, seg=5)
        clump(b, center + V((0, 0, h + 0.45)), 0.11, 1, rnd, BRASS, "Build", 1.0)


def lantern(b, at, hang=0.0):
    """A pierced brass lantern: pointed cap, glowing body, a little finial underneath."""
    if hang > 0:
        beam(b, at + V((0, 0, hang + 0.35)), at + V((0, 0, 0.3)), 0.012, IRON)
    tube(b, [at + V((0, 0, 0.17)), at + V((0, 0, 0.37))], [0.15, 0.02], BRASS, seg=6)
    faces = b.new_faces(lambda: rk.tube(b.bm, [at + V((0, 0, -0.18)), at, at + V((0, 0, 0.18))], [(0.08, 0.08), (0.13, 0.13), (0.1, 0.1)], seg=6))
    paint(b, faces, GLOW, 0.0, "Glow")
    tube(b, [at + V((0, 0, -0.17)), at + V((0, 0, -0.3))], [0.08, 0.01], BRASS, seg=6)


def wall_lantern(b, at):
    """A lantern hanging from a bracket on a wall facing -Y (at = the lantern centre)."""
    beam(b, at + V((0, 0.42, 0.62)), at + V((0, 0, 0.62)), 0.03, IRON)
    beam(b, at + V((0, 0.42, 0.3)), at + V((0, 0.1, 0.6)), 0.02, IRON)
    lantern(b, at, 0.08)


def pot(b, at, h, color, plant=None):
    tube(b, [at, at + V((0, 0, h * 0.5)), at + V((0, 0, h * 0.9)), at + V((0, 0, h))], [h * 0.25, h * 0.38, h * 0.22, h * 0.26], color, seg=8)
    if plant:
        clump(b, at + V((0, 0, h + 0.12)), h * 0.42, 1, rnd, plant, "Build", 0.7)


def house_dome():
    """A whitewashed cube house (6 x 6 m) with a teal dome, parapet, beam ends, an arched teal door
    under a saffron awning, arched windows, a lantern and pots."""
    b = Builder(["Build", "Glow"])
    W = D = 5.6
    H = 3.6
    box(b, V((0, 0, 0.05)), (W + 0.4, D + 0.4, 0.3), OCHRE_D)
    adobe(b, V((0, 0, H / 2)), (W, D, H), WHITE)
    adobe(b, V((0, 0, 0.5)), (W + 0.08, D + 0.08, 0.9), OCHRE, 0.0)          # ochre skirt round the foot
    adobe(b, V((0, 0, H - 0.06)), (W - 0.12, D - 0.12, 0.14), TERRA, 0.0)    # a terracotta band under the parapet
    parapet(b, -W / 2 + 0.1, W / 2 - 0.1, -D / 2 + 0.1, D / 2 - 0.1, H, 0.42, 0.24, WHITE)
    box(b, V((0, 0, H + 0.02)), (W - 0.6, D - 0.6, 0.06), (0.9, 0.82, 0.68), 0.0)      # the roof floor
    c = V((-0.6, 0.6, H))
    tube(b, [c, c + V((0, 0, 0.65))], [1.95, 1.95], WHITE, seg=8, ref=V((math.cos(0.39), math.sin(0.39), 0)))
    tube(b, [c + V((0, 0, 0.65)), c + V((0, 0, 0.8))], [2.08, 2.08], TERRA, seg=8, ref=V((math.cos(0.39), math.sin(0.39), 0)))
    dome(b, c + V((0, 0, 0.8)), 1.9, 1.85, TEAL)
    vigas(b, -2.3, 2.3, -D / 2, H - 0.5, 6)
    vigas_x(b, -2.3, 2.3, W / 2, H - 0.5, 6)
    vigas_x(b, -2.3, 2.3, -W / 2, H - 0.5, 6, -1)
    arch_door(b, 0.8, -D / 2, 0.15, 1.2, 2.3, CLAY, TEAL)
    awning(b, 0.8, -D / 2, 3.05, 2.1, 1.15, 0.45, [SAFFRON, CREAM])
    arch_window(b, -1.5, -D / 2, 1.3, 0.7, 1.05)
    for ang in (math.pi / 2, -math.pi / 2, math.pi):
        turned(b, ang, lambda: arch_window(b, 0.6, -D / 2 + 0.04, 1.4, 0.7, 1.0))
    wall_lantern(b, V((-0.35, -D / 2 - 0.42, 2.25)))
    pot(b, V((2.15, -D / 2 - 0.45, 0.18)), 0.75, TERRA, FROND[1])
    pot(b, V((-2.3, -D / 2 - 0.4, 0.18)), 0.55, CLAY, FROND[2])
    pot(b, V((W / 2 + 0.4, -1.8, 0.18)), 0.9, OCHRE_D)
    return b


def house_tower():
    """Two storeys: an ochre ground floor with a roof terrace in front, the upper storey behind it under
    a parapet with corner horns and a teal rooftop canopy; an outside stair, striped awning, beam ends."""
    b = Builder(["Build", "Glow"])
    W, D = 4.8, 4.8
    H1, H2 = 3.4, 6.6
    box(b, V((0, 0, 0.05)), (W + 0.4, D + 0.4, 0.3), OCHRE_D)
    adobe(b, V((0, 0, H1 / 2)), (W, D, H1), OCHRE, 0.03)
    adobe(b, V((0, 0.8, (H1 + H2) / 2)), (W - 0.2, 3.2, H2 - H1), OCHRE, 0.04)
    adobe(b, V((0, 0, H1 - 0.06)), (W - 0.1, D - 0.1, 0.14), WHITE, 0.0)
    adobe(b, V((0, 0.8, H2 - 0.1)), (W - 0.3, 3.1, 0.14), TERRA, 0.0)
    # Terrace parapet (front half of the ground floor's roof), and the upper parapet with horns.
    t = 0.24
    box(b, V((0, -D / 2 + t / 2, H1 + 0.25)), (W, t, 0.5), WHITE)
    box(b, V((-W / 2 + t / 2, -1.6, H1 + 0.25)), (t, 1.6, 0.5), WHITE)
    box(b, V((W / 2 - t / 2, -1.25, H1 + 0.25)), (t, 0.9, 0.5), WHITE)      # leaves a gap for the stair
    parapet(b, -W / 2 + 0.15, W / 2 - 0.15, -0.75, 2.35, H2, 0.5, t, WHITE, corners=False)
    for x in (-W / 2 + 0.25, W / 2 - 0.25):
        for y in (-0.65, 2.25):
            tube(b, [V((x, y, H2)), V((x, y, H2 + 1.05))], [0.24, 0.05], WHITE, seg=4, ref=V((1, 1, 0)))
    for i in range(5):                      # little pointed merlons along the front parapet
        x = -1.5 + i * 0.75
        tube(b, [V((x, -0.72, H2 + 0.5)), V((x, -0.72, H2 + 0.85))], [0.13, 0.02], WHITE, seg=4, ref=V((1, 1, 0)))
    # Teal cloth canopy on four poles on the top roof.
    for x in (-1.5, 1.5):
        for y in (0.0, 1.8):
            beam(b, V((x, y, H2)), V((x, y, H2 + 1.9)), 0.04, WOOD_D)
    for i in range(4):
        xa = -1.65 + i * 0.825
        col = TEAL if i % 2 == 0 else TEAL_L
        box(b, V((xa + 0.41, 0.9, H2 + 1.95 + (0.0 if i in (0, 3) else -0.08))), (0.84, 2.3, 0.06), col, 0.02)
    # Outside stair up the right side, from the back corner to the terrace.
    steps = 10
    prof = [(2.3, 0.0)]
    for i in range(steps):
        y = 2.3 - (i + 1) * 0.36
        prof += [(y + 0.36, (i + 1) * H1 / steps), (y, (i + 1) * H1 / steps)]
    prof += [(prof[-1][0], 0.0)]
    prof = [prof[0]] + prof[1:]
    prism_yz(b, list(reversed(prof)), W / 2 - 0.02, W / 2 + 0.85, WHITE)
    box(b, V((W / 2 + 0.85 / 2, -1.25 + 0.02, H1 + 0.05)), (0.87, 0.6, 0.1), WHITE)
    # Doors, windows, awning, beam ends, lantern.
    arch_door(b, -0.6, -D / 2, 0.15, 1.15, 2.25, WHITE, WOOD)
    arch_door(b, 0.2, -0.8, H1, 1.0, 2.0, WHITE, TEAL)
    awning(b, 0.2, -0.8, H1 + 2.55, 1.8, 0.95, 0.35, [TERRA, CREAM], 6)
    arch_window(b, 1.4, -D / 2, 1.2, 0.6, 1.0)
    arch_window(b, -1.4, -0.8, H1 + 0.8, 0.55, 0.9)
    turned(b, math.pi / 2, lambda: arch_window(b, -0.4, -D / 2 + 0.04, 1.3, 0.6, 1.0))
    turned(b, -math.pi / 2, lambda: arch_window(b, 0.4, -D / 2 + 0.04, 1.3, 0.6, 1.0))
    turned(b, -math.pi / 2, lambda: arch_window(b, -0.8, -W / 2 + 0.14, H1 + 1.0, 0.55, 0.9), V((0, 0, 0)))
    turned(b, math.pi, lambda: arch_window(b, 0.0, -2.35, H1 + 1.0, 0.55, 0.9))
    vigas(b, -2.0, 2.0, -D / 2, H1 - 0.45, 5)
    vigas(b, -1.9, 1.9, -0.8, H2 - 0.45, 5)
    wall_lantern(b, V((-1.6, -D / 2 - 0.42, 2.2)))
    pot(b, V((-1.6, -1.3, H1)), 0.6, TERRA, FROND[0])
    pot(b, V((1.9, -D / 2 - 0.4, 0.18)), 0.8, CLAY)
    return b


def spandrel(x0, x1, zs, zt, steps=6):
    """The wall above an arch between two pillars: outline [(x, z)] with the round opening cut out."""
    r = (x1 - x0) / 2
    xm = (x0 + x1) / 2
    pts = [(x1, zt), (x0, zt), (x0, zs)]
    for k in range(1, steps):
        a = math.pi - k / steps * math.pi
        pts.append((xm + r * math.cos(a), zs + r * math.sin(a)))
    pts.append((x1, zs))
    return pts


def house_wide():
    """A long flat-roofed house (11 m) with a three-bay arcade in front, a shop front under a striped
    teal awning, roof parapet with water jars, beam ends and hanging lanterns in the arcade."""
    b = Builder(["Build", "Glow"])
    X0, X1 = -5.5, 5.5
    Y0, Y1 = -1.0, 4.0
    H = 4.0
    box(b, V((0, 1.0, 0.05)), (11.4, 9.4, 0.3), OCHRE_D)
    adobe(b, V((0, (Y0 + Y1) / 2, H / 2)), (X1 - X0, Y1 - Y0, H), WHITE, 0.025)
    adobe(b, V((0, (Y0 + Y1) / 2, 0.45)), (X1 - X0 + 0.08, Y1 - Y0 + 0.08, 0.8), CLAY, 0.0)
    parapet(b, X0 + 0.1, X1 - 0.1, Y0 + 0.1, Y1 - 0.1, H, 0.45, 0.24, WHITE)
    box(b, V((0, (Y0 + Y1) / 2, H + 0.02)), (10.5, 4.4, 0.06), (0.9, 0.82, 0.68), 0.0)
    # Arcade: four ochre pillars, arched spandrels, a flat roof on top with a low wall.
    A0, A1 = -5.5, 1.6
    AY = -3.0
    bays = 3
    pw = 0.5
    zs, zt = 2.1, 3.3
    for i in range(bays + 1):
        x = A0 + pw / 2 + (A1 - A0 - pw) * i / bays
        adobe(b, V((x, AY + 0.25, zt / 2)), (pw, pw, zt), OCHRE, 0.0)
        box(b, V((x, AY + 0.25, 0.15)), (pw + 0.16, pw + 0.16, 0.3), OCHRE_D)
    for i in range(bays):
        xa = A0 + pw + (A1 - A0 - pw) * i / bays
        xb = A0 + (A1 - A0 - pw) * (i + 1) / bays
        paint(b, b.new_faces(outline_prism(b, spandrel(xa, xb, zs, zt + 0.02), AY, AY + 0.5)), OCHRE, 0.02)
        lantern(b, V(((xa + xb) / 2, AY + 1.2, 2.55)), 0.35)
    box(b, V(((A0 + A1) / 2, (AY + Y0) / 2, zt + 0.15)), (A1 - A0, Y0 - AY + 0.1, 0.3), OCHRE)
    box(b, V(((A0 + A1) / 2, AY + 0.1, zt + 0.48)), (A1 - A0, 0.2, 0.4), WHITE)
    box(b, V((A0 + 0.1, (AY + Y0) / 2, zt + 0.48)), (0.2, Y0 - AY, 0.4), WHITE)
    box(b, V((A1 - 0.1, (AY + Y0) / 2, zt + 0.48)), (0.2, Y0 - AY, 0.4), WHITE)
    box(b, V(((A0 + A1) / 2, (AY + Y0) / 2, 0.04)), (A1 - A0, Y0 - AY, 0.08), STONE[1], 0.0)
    # Doors and windows under the arcade, the shop front on the right.
    arch_door(b, -3.5, Y0, 0.15, 1.1, 2.2, TERRA, WOOD)
    arch_window(b, -1.2, Y0, 1.0, 0.8, 1.0, TERRA)
    arch_window(b, 0.5, Y0, 1.0, 0.8, 1.0, TERRA)
    b.paint(b.new_faces(outline_prism(b, arch_outline(3.6, 0.15, 2.6, 2.4, 6), Y0 - 0.07, Y0 + 0.05)), "Build", TEAL)
    b.paint(b.new_faces(outline_prism(b, arch_outline(3.6, 0.15, 2.2, 2.2, 6), Y0 - 0.1, Y0 - 0.03)), "Build", DARK)
    box(b, V((3.6, Y0 - 0.45, 0.55)), (2.4, 0.7, 0.8), WOOD)                   # shop counter
    for k in range(4):
        clump(b, V((2.8 + k * 0.5, Y0 - 0.45, 1.05)), 0.2, 1, rnd, [SAFFRON, TERRA, (0.62, 0.6, 0.25), (0.6, 0.35, 0.2)][k], "Build", 0.6)
    awning(b, 3.6, Y0, 3.1, 3.4, 1.6, 0.6, [TEAL, CREAM], 8)
    vigas(b, 1.9, 5.2, Y0, H - 0.45, 5)
    vigas_x(b, -0.6, 3.6, X1, H - 0.45, 5)
    vigas_x(b, -0.6, 3.6, X0, H - 0.45, 5, -1)
    for ang, x in ((math.pi / 2, -1.0), (-math.pi / 2, 1.0)):
        turned(b, ang, lambda x=x: arch_window(b, x, -5.46, 1.4, 0.7, 1.0), V((0, 1.5, 0)))
    for k, x in enumerate((-4.2, -3.3, 4.6)):
        pot(b, V((x, 2.9, H)), 0.7 if k != 1 else 0.55, [TERRA, CLAY, OCHRE_D][k])
    pot(b, V((A0 + 0.6, AY + 0.9, 0.08)), 0.8, TERRA, FROND[3])
    return b


def market_stall():
    """A stall with a striped sloping canopy and scalloped edge, a counter with a teal cloth, crates of
    oranges and lemons, bowls heaped with spices, sacks and a hanging lantern."""
    b = Builder(["Build", "Glow"])
    W, D = 3.2, 2.2
    for x in (-W / 2, W / 2):
        beam(b, V((x, -D / 2, 0)), V((x, -D / 2, 2.35)), 0.06, WOOD_D)
        beam(b, V((x, D / 2, 0)), V((x, D / 2, 2.75)), 0.06, WOOD_D)
    stripes = 8
    for i in range(stripes):
        xa = -W / 2 - 0.2 + (W + 0.4) * i / stripes
        xb = xa + (W + 0.4) / stripes
        col = [TERRA, CREAM][i % 2]
        quad = [V((xa, D / 2 + 0.25, 2.85)), V((xb, D / 2 + 0.25, 2.85)), V((xb, -D / 2 - 0.45, 2.3)), V((xa, -D / 2 - 0.45, 2.3))]

        def make(quad=quad):
            bm = b.bm
            top = [bm.verts.new(p) for p in quad]
            bot = [bm.verts.new(p - V((0, 0, 0.05))) for p in quad]
            bm.faces.new(top)
            bm.faces.new(list(reversed(bot)))
            for k in range(4):
                j = (k + 1) % 4
                bm.faces.new((top[j], top[k], bot[k], bot[j]))
        paint(b, b.new_faces(make), col, 0.02)
        y = -D / 2 - 0.46
        paint(b, b.new_faces(outline_prism(b, [(xa, 2.27), (xb, 2.27), ((xa + xb) / 2, 2.0)], y - 0.02, y + 0.02)), col, 0.02)
    box(b, V((0, -D / 2 + 0.35, 0.45)), (W - 0.2, 0.8, 0.9), WOOD)
    box(b, V((0, -D / 2 - 0.08, 0.55)), (W - 0.1, 0.06, 0.7), TEAL, 0.02)
    for k in range(5):
        box(b, V((-1.2 + k * 0.6, -D / 2 - 0.12, 0.25)), (0.25, 0.04, 0.12), SAFFRON, 0.0)
    for k, (x, fruit) in enumerate([(-1.05, (0.98, 0.55, 0.15)), (-0.35, (0.98, 0.86, 0.25))]):
        box(b, V((x, -D / 2 + 0.35, 1.02)), (0.6, 0.5, 0.25), PLANK[k], 0.03)
        for i in range(5):
            clump(b, V((x - 0.18 + (i % 3) * 0.18, -D / 2 + 0.28 + (i // 3) * 0.16, 1.18)), 0.1, 1, rnd, fruit, "Build", 1.0)
    for k, (x, col) in enumerate([(0.3, SAFFRON), (0.75, (0.78, 0.22, 0.12)), (1.2, (0.62, 0.6, 0.26))]):
        tube(b, [V((x, -D / 2 + 0.35, 0.9)), V((x, -D / 2 + 0.35, 1.02))], [0.16, 0.2], (0.75, 0.6, 0.42), seg=8)
        tube(b, [V((x, -D / 2 + 0.35, 1.02)), V((x, -D / 2 + 0.35, 1.25))], [0.18, 0.02], col, seg=8)
    # Sacks by the counter, a crate of melons behind, a rug hanging at the back.
    for k, x in enumerate((-1.75, 1.8)):
        b.paint(b.new_faces(lambda x=x: rk.blob(b.bm, V((x, -0.7, 0.3)), (0.28, 0.25, 0.35), 7, 4)), "Build", (0.86, 0.76, 0.56))
        tube(b, [V((x, -0.7, 0.58)), V((x, -0.7, 0.7))], [0.1, 0.16], (0.8, 0.7, 0.5), seg=6)
    box(b, V((0.9, 0.5, 0.3)), (0.8, 0.6, 0.6), PLANK[2])
    for i in range(3):
        clump(b, V((0.65 + i * 0.25, 0.5, 0.72)), 0.16, 1, rnd, (0.42, 0.62, 0.28), "Build", 0.9)
    for i in range(5):
        box(b, V((-0.9 + i * 0.36, D / 2 - 0.02, 1.55)), (0.36, 0.04, 1.6), [TERRA, SAFFRON, TEAL, CREAM, TERRA][i], 0.02)
    beam(b, V((-W / 2, D / 2, 2.4)), V((W / 2, D / 2, 2.4)), 0.035, WOOD_D)
    beam(b, V((-W / 2, -D / 2, 2.2)), V((W / 2, -D / 2, 2.2)), 0.035, WOOD_D)
    lantern(b, V((0.0, -D / 2 + 0.1, 1.75)), 0.25)
    return b


def ring_wall(b, r_in, r_out, z0, z1, seg, color):
    def make():
        rings = []
        for rr, z in ((r_out, z0), (r_out, z1), (r_in, z1), (r_in, z0)):
            rings.append([V((math.cos(k * math.tau / seg) * rr, math.sin(k * math.tau / seg) * rr, z)) for k in range(seg)])
        bm = b.bm
        vs = [[bm.verts.new(p) for p in ring] for ring in rings]
        for i in range(4):
            r0, r1 = vs[i], vs[(i + 1) % 4]
            for k in range(seg):
                k2 = (k + 1) % seg
                bm.faces.new((r0[k], r0[k2], r1[k2], r1[k]))
    faces = b.new_faces(make)
    paint_by(b, faces, lambda f: jit(STONE[rnd.randrange(3)] if f.normal.z < 0.7 else shade(color, 1.05), 0.04))


def well():
    """A round sandstone well with a little terracotta roof on a pulley frame, a rope and a bucket."""
    b = Builder(["Build"])
    ring_wall(b, 0.72, 1.05, -0.1, 0.55, 10, STONE[2])
    ring_wall(b, 0.68, 1.12, 0.55, 0.75, 10, STONE[0])
    tube(b, [V((0, 0, 0.0)), V((0, 0, 0.35))], [0.75, 0.75], (0.14, 0.42, 0.46), seg=10, var=0.0)
    for x in (-0.95, 0.95):
        box(b, V((x, 0, 1.4)), (0.16, 0.16, 1.4), WOOD_D)
        box(b, V((x, 0, 0.82)), (0.26, 0.3, 0.14), WOOD)
    box(b, V((0, 0, 2.08)), (2.2, 0.14, 0.14), WOOD)
    for s in (-1, 1):
        quad = [V((-1.3, 0, 2.55)), V((1.3, 0, 2.55)), V((1.3, s * 0.95, 2.1)), V((-1.3, s * 0.95, 2.1))]
        if s > 0:
            quad = list(reversed(quad))

        def make(quad=quad):
            bm = b.bm
            top = [bm.verts.new(p) for p in quad]
            bot = [bm.verts.new(p - V((0, 0, 0.08))) for p in quad]
            bm.faces.new(top)
            bm.faces.new(list(reversed(bot)))
            for k in range(4):
                j = (k + 1) % 4
                bm.faces.new((top[j], top[k], bot[k], bot[j]))
        paint(b, b.new_faces(make), TERRA, 0.04)
    for x in (-0.95, 0.95):
        paint(b, b.new_faces(outline_prism(b, [(x - 0.06, 2.12), (x + 0.06, 2.12), (x, 2.5)], -0.05, 0.05)), WOOD_D)
    tube(b, [V((-0.12, 0, 1.85)), V((0.12, 0, 1.85))], [0.2, 0.2], WOOD, seg=8, ref=V((0, 0, 1)))
    beam(b, V((0, -0.2, 1.85)), V((0, -0.2, 1.15)), 0.015, (0.85, 0.75, 0.55))
    tube(b, [V((0, -0.2, 0.85)), V((0, -0.2, 1.12))], [0.13, 0.16], WOOD, seg=6)
    beam(b, V((-0.15, -0.2, 1.13)), V((0.15, -0.2, 1.13)), 0.012, IRON)
    return b


def lantern_post():
    """A dark iron post on a stone foot with a curled double arm and two brass lanterns."""
    b = Builder(["Build", "Glow"])
    box(b, V((0, 0, 0.12)), (0.42, 0.42, 0.34), STONE[0])
    tube(b, [V((0, 0, 0.25)), V((0, 0, 0.45))], [0.12, 0.08], IRON, seg=6)
    tube(b, [V((0, 0, 0.45)), V((0, 0, 2.85))], [0.06, 0.045], IRON, seg=6)
    clump(b, V((0, 0, 2.95)), 0.1, 1, rnd, BRASS, "Build", 1.0)
    for s in (-1, 1):
        pts = [V((0, 0, 2.55)), V((s * 0.3, 0, 2.72)), V((s * 0.55, 0, 2.68)), V((s * 0.62, 0, 2.55))]
        tube(b, pts, [0.03] * 4, IRON, seg=4, ref=V((0, 1, 0)))
        beam(b, V((s * 0.15, 0, 2.2)), V((s * 0.4, 0, 2.66)), 0.02, IRON)
        lantern(b, V((s * 0.62, 0, 2.05)), 0.12)
    return b


def palm_planter():
    """A square ochre planter with a white rim and a teal tile band, a small palm in it."""
    b = Builder(["Build"])
    adobe(b, V((0, 0, 0.35)), (1.3, 1.3, 0.7), OCHRE, 0.04)
    adobe(b, V((0, 0, 0.32)), (1.34, 1.34, 0.16), TEAL, 0.0)
    for x, y, sx, sy in ((0, -0.6, 1.4, 0.18), (0, 0.6, 1.4, 0.18), (-0.6, 0, 0.18, 1.05), (0.6, 0, 0.18, 1.05)):
        box(b, V((x, y, 0.74)), (sx, sy, 0.1), WHITE)
    box(b, V((0, 0, 0.66)), (1.06, 1.06, 0.06), (0.4, 0.3, 0.22), 0.0)
    palm(b, V((0, 0, 0.65)), 2.0, 0.8, 0.35, 7, 71, 0.6, 2)
    return b


def pier():
    """A straight 4 x 12 m wooden pier section: planks across, three stringers, eight pilings. Top at
    +1.2, origin at the shore end centre, running along +Y here (-Z in Godot)."""
    b = Builder(["Build"])
    L = 12.0
    n = 30
    for i in range(n):
        y = (i + 0.5) * L / n
        w = 4.0 + (0.12 if i % 3 == 0 else 0.0) * (1 if i % 2 else -1)
        box(b, V((rnd.uniform(-0.04, 0.04), y, 1.15)), (w, L / n - 0.045, 0.1), PLANK[rnd.randrange(4)], 0.04)
    for x in (-1.55, 0, 1.55):
        box(b, V((x, L / 2, 0.98)), (0.18, L, 0.24), WOOD_D)
    for y in (1.5, 4.5, 7.5, 10.5):
        for x in (-1.95, 1.95):
            faces = tube(b, [V((x, y, -2.5)), V((x, y, 1.55))], [0.15, 0.13], None, seg=6)
            paint_by(b, faces, lambda f: jit((0.3, 0.33, 0.25) if f.calc_center_median().z < 0.15 else (0.42, 0.3, 0.2), 0.04))
        box(b, V((0, y, 0.82)), (4.1, 0.16, 0.14), WOOD_D)
    for y in (3.0, 9.0):
        tube(b, [V((1.65, y, 1.2)), V((1.65, y, 1.5)), V((1.65, y, 1.58))], [0.12, 0.1, 0.14], IRON, seg=6)
    return b


def lighthouse():
    """A banded sandstone lighthouse (~17 m) on a stepped base, with a gallery, four pillars under a
    teal cupola and a bronze fire bowl in the middle (the separate object "Fire")."""
    b = Builder(["Build", "Glow"])
    ref = V((math.cos(math.pi / 8), math.sin(math.pi / 8), 0))          # flat faces towards -Y
    tube(b, [V((0, 0, -0.2)), V((0, 0, 0.6))], [3.5, 3.5], STONE[1], seg=8, ref=ref)
    tube(b, [V((0, 0, 0.6)), V((0, 0, 1.2))], [2.95, 2.95], STONE[0], seg=8, ref=ref)
    zs = [1.2, 3.8, 4.2, 7.1, 7.5, 10.4, 10.8, 13.0]
    radius = lambda z: 2.3 - (z - 1.2) / 11.8 * 0.65
    for i in range(len(zs) - 1):
        z0, z1 = zs[i], zs[i + 1]
        col = TERRA if i % 2 else (0.93, 0.78, 0.55)
        tube(b, [V((0, 0, z0)), V((0, 0, z1))], [radius(z0), radius(z1)], col, seg=8, ref=ref, var=0.02)
    tube(b, [V((0, 0, 13.0)), V((0, 0, 13.6))], [radius(13.0), 2.3], WHITE, seg=8, ref=ref)
    tube(b, [V((0, 0, 13.6)), V((0, 0, 13.85))], [2.4, 2.4], STONE[0], seg=8, ref=ref)
    ap = 2.25 * math.cos(math.pi / 8)
    for k in range(8):                   # gallery wall: a low wall with a gap on each face
        a = k * math.tau / 8 + math.pi / 8
        p0 = V((math.cos(a) * 2.25, math.sin(a) * 2.25, 13.85))
        p1 = V((math.cos(a + math.tau / 8) * 2.25, math.sin(a + math.tau / 8) * 2.25, 13.85))
        for t0, t1 in ((0.0, 0.32), (0.68, 1.0)):
            q0, q1 = p0.lerp(p1, t0), p0.lerp(p1, t1)
            box(b, (q0 + q1) / 2 + V((0, 0, 0.4)), ((q1 - q0).length, 0.22, 0.8), WHITE, 0.02, rot=Euler((0, 0, a + math.pi / 8 + math.pi / 2)))
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        p = V((math.cos(a) * 1.25, math.sin(a) * 1.25, 13.85))
        tube(b, [p, p + V((0, 0, 2.2))], [0.14, 0.12], WHITE, seg=6)
    tube(b, [V((0, 0, 16.05)), V((0, 0, 16.3))], [1.6, 1.6], TERRA, seg=8, ref=ref)
    dome(b, V((0, 0, 16.3)), 1.5, 1.2, TEAL, seg=8)
    tube(b, [V((0, 0, 13.85)), V((0, 0, 14.4))], [0.32, 0.22], BRASS, seg=6)
    # Door and slit windows on the front, a lantern by the door.
    yf = -2.3 * math.cos(math.pi / 8)
    arch_door(b, 0, yf + 0.02, 1.2, 1.1, 2.1, WHITE, WOOD)
    box(b, V((0, -3.2, 0.75)), (1.5, 0.7, 0.3), STONE[1])
    for z in (5.4, 8.8, 11.8):
        r = radius(z) * math.cos(math.pi / 8)
        arch_window(b, 0, -r + 0.02, z, 0.42, 0.85, WHITE, DARK, sill=False)
        turned(b, math.pi, lambda r=r, z=z: arch_window(b, 0, -r + 0.02, z - 1.4, 0.42, 0.85, WHITE, DARK, sill=False))
    wall_lantern(b, V((0.95, yf - 0.35, 2.9)))
    return b


def fire_bowl():
    """The lighthouse fire: a bronze bowl and flame tongues (glowing). Origin at the bowl's centre."""
    b = Builder(["Build", "Glow"])
    tube(b, [V((0, 0, -0.25)), V((0, 0, 0.0)), V((0, 0, 0.3))], [0.25, 0.6, 0.8], BRASS, seg=8)
    r = random.Random(4)
    for k in range(5):
        a = k * math.tau / 5
        base = V((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.2))
        tip = base + V((math.cos(a + 1.0) * 0.2, math.sin(a + 1.0) * 0.2, r.uniform(0.9, 1.3)))
        faces = b.new_faces(lambda base=base, tip=tip: rk.tube(b.bm, [base, (base + tip) / 2 + V((0, 0, -0.1)), tip], [(0.28, 0.28), (0.2, 0.2), (0.02, 0.02)], seg=4))
        paint(b, faces, (1.0, 0.62, 0.22), 0.04, "Glow")
    faces = b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 0.2)), V((0, 0, 0.8)), V((0, 0, 1.7))], [(0.35, 0.35), (0.28, 0.28), (0.02, 0.02)], seg=5))
    paint(b, faces, (1.0, 0.88, 0.5), 0.0, "Glow")
    return b


# --- the ship -------------------------------------------------------------------------
STATIONS = [(-5.4, 1.5, 1.95, -0.6), (-4.6, 1.8, 1.8, -0.8), (-3.0, 1.98, 1.65, -0.9), (-1.0, 2.0, 1.6, -0.95),
            (1.0, 1.95, 1.6, -0.95), (2.8, 1.7, 1.7, -0.9), (4.0, 1.3, 1.85, -0.8), (4.9, 0.8, 2.05, -0.55),
            (5.5, 0.32, 2.3, 0.0), (5.85, 0.1, 2.45, 0.6)]
DECK = 1.0


def hull_ring(y, hw, zt, kz):
    t = min(0.14, hw * 0.4)
    pts = [(-hw + t, DECK), (-hw + t, zt), (-hw, zt), (-hw * 1.04, 0.75), (-hw * 0.9, 0.0), (-hw * 0.55, kz * 0.75), (0.0, kz),
           (hw * 0.55, kz * 0.75), (hw * 0.9, 0.0), (hw * 1.04, 0.75), (hw, zt), (hw - t, zt), (hw - t, DECK)]
    inner = hw - t
    for k in range(1, 5):
        pts.append((inner - 2 * inner * k / 5, DECK))
    return [V((x, y, z)) for x, z in pts]


HULL_COLORS = {0: (0.8, 0.62, 0.42), 1: WOOD_D, 2: TEAL, 3: (0.7, 0.47, 0.28), 4: (0.52, 0.24, 0.18), 5: (0.52, 0.24, 0.18),
               6: (0.52, 0.24, 0.18), 7: (0.52, 0.24, 0.18), 8: (0.7, 0.47, 0.28), 9: TEAL, 10: WOOD_D, 11: (0.8, 0.62, 0.42)}


def ship_hull():
    b = Builder(["Build", "Glow"])
    rings = [hull_ring(*s) for s in STATIONS]
    n = len(rings[0])
    faces = b.new_faces(lambda: loft(b.bm, rings))
    for i, f in enumerate(faces):
        if i >= len(faces) - 2:
            b.paint([f], "Build", jit(WOOD, 0.03))                # transom and stem caps
            continue
        k = i % n
        st = i // n
        if k in HULL_COLORS:
            col = HULL_COLORS[k]
            if k in (3, 8) and st % 2:
                col = shade(col, 0.92)
        else:
            col = PLANK[(k + st) % 2]                             # deck planks
        b.paint([f], "Build", jit(col, 0.03))
    # A gold stern band, a stern lantern, a hatch, a mast with a crow's nest, yards, stays, a pennant.
    box(b, V((0, -5.42, 1.55)), (2.6, 0.06, 0.12), SAFFRON, 0.0)
    beam(b, V((0, -5.2, 1.9)), V((0, -5.2, 2.6)), 0.05, WOOD_D)
    beam(b, V((0, -5.2, 2.6)), V((0, -5.55, 2.6)), 0.03, IRON)
    lantern(b, V((0, -5.55, 2.25)), 0.12)
    box(b, V((0, -1.6, DECK + 0.08)), (1.3, 1.3, 0.16), WOOD_D, 0.0)
    for k in range(4):
        box(b, V((-0.45 + k * 0.3, -1.6, DECK + 0.17)), (0.16, 1.2, 0.03), PLANK[2], 0.02)
    tube(b, [V((0, 0.6, DECK - 0.1)), V((0, 0.6, 10.0))], [0.17, 0.11], WOOD, seg=6)
    tube(b, [V((0, 0.6, 9.0)), V((0, 0.6, 9.55))], [0.42, 0.48], WOOD_D, seg=8)
    for z in (8.85, 3.25):
        tube(b, [V((-2.95, 0.88, z)), V((0, 0.88, z + 0.05)), V((2.95, 0.88, z))], [0.07, 0.1, 0.07], WOOD_D, seg=5)
    tube(b, [V((0, 5.4, 2.1)), V((0, 6.8, 2.75))], [0.12, 0.06], WOOD, seg=5)
    rope = (0.32, 0.26, 0.2)
    beam(b, V((0, 0.6, 9.9)), V((0, 6.75, 2.75)), 0.02, rope)
    for s in (-1, 1):
        beam(b, V((0, 0.6, 9.9)), V((s * 1.45, -5.0, 1.85)), 0.02, rope)
        for y in (0.2, 1.1):
            beam(b, V((0, 0.6, 8.7)), V((s * 1.98, y, 1.6)), 0.02, rope)
    paint(b, b.new_faces(outline_prism(b, [(0, 10.0), (0, 10.45), (-0.0, 10.2)], -0.02, 0.02)), SAFFRON)
    flag = [V((0, 0.6, 10.45)), V((0, 0.6, 10.0)), V((0, -0.9, 10.2))]
    def make_flag():
        bm = b.bm
        a = [bm.verts.new(p + V((0.02, 0, 0))) for p in flag]
        c = [bm.verts.new(p - V((0.02, 0, 0))) for p in flag]
        bm.faces.new(a)
        bm.faces.new(list(reversed(c)))
        for k in range(3):
            j = (k + 1) % 3
            bm.faces.new((a[k], a[j], c[j], c[k]))
    paint(b, b.new_faces(make_flag), SAFFRON, 0.0)
    # Cargo: crates and barrels by the mast, a coil of rope.
    box(b, V((-1.1, 2.0, DECK + 0.35)), (0.7, 0.7, 0.7), PLANK[2], 0.03)
    box(b, V((-1.0, 2.05, DECK + 0.95)), (0.5, 0.5, 0.5), PLANK[0], 0.03, rot=Euler((0, 0, 0.4)))
    for x, y in ((1.1, 2.1), (1.15, 2.85)):
        at = V((x, y, DECK))
        tube(b, [at, at + V((0, 0, 0.4)), at + V((0, 0, 0.8))], [0.28, 0.33, 0.28], WOOD, seg=8)
        tube(b, [at + V((0, 0, 0.62)), at + V((0, 0, 0.68))], [0.32, 0.32], IRON, seg=8, var=0.0)
    tube(b, [V((-1.2, -3.0, DECK)), V((-1.2, -3.0, DECK + 0.18))], [0.35, 0.35], (0.78, 0.66, 0.46), seg=8)
    # The wheel's pedestal.
    box(b, V((0, -4.0, DECK + 0.45)), (0.25, 0.25, 0.9), WOOD_D)
    return b


def ship_wheel():
    """The steering wheel, origin at its hub, turning about Y here (Godot Z)."""
    b = Builder(["Build"])
    R = 0.55
    rim = [V((math.cos(k * math.tau / 12) * R, 0, math.sin(k * math.tau / 12) * R)) for k in range(12)]
    faces = b.new_faces(lambda: rk.tube(b.bm, rim, [(0.045, 0.045)] * 12, ref=V((0, 1, 0)), seg=4, closed=True))
    paint(b, faces, WOOD, 0.03)
    for k in range(8):
        a = k * math.tau / 8
        d = V((math.cos(a), 0, math.sin(a)))
        beam(b, d * 0.08, d * R, 0.025, WOOD_D)
        tube(b, [d * R, d * (R + 0.2)], [0.035, 0.028], WOOD, seg=4, ref=V((0, 1, 0)))
    tube(b, [V((0, -0.1, 0)), V((0, 0.12, 0))], [0.1, 0.1], BRASS, seg=6, ref=V((1, 0, 0)))
    return b


def ship_sail():
    """A square sail bellied forward (+Y here, -Z in Godot), cream with a teal stripe. Built around the
    mast at (0, 0.6, 6.0): that is the object's origin, so scaling Y billows it."""
    b = Builder(["Build"])
    cols, xs = 6, [-2.75 + 5.5 * i / 6 for i in range(7)]
    zs = [8.75, 7.4, 6.85, 6.2, 4.8, 3.35]          # the teal stripe is the band between 6.85 and 6.2
    band_cols = [CREAM, CREAM, TEAL, CREAM, CREAM]

    def p(x, z):
        u = x / 2.75
        t = (8.75 - z) / 5.4
        bulge = 0.9 * (1 - u * u * 0.85) * math.sin(math.pi * (0.15 + 0.85 * t))
        return V((x, 0.95 + bulge, z))
    for j in range(len(zs) - 1):
        for i in range(cols):
            corners = [p(xs[i], zs[j]), p(xs[i + 1], zs[j]), p(xs[i + 1], zs[j + 1]), p(xs[i], zs[j + 1])]

            def make(corners=corners):
                bm = b.bm
                a = [bm.verts.new(c + V((0, 0.025, 0))) for c in corners]
                c2 = [bm.verts.new(c - V((0, 0.025, 0))) for c in corners]
                bm.faces.new(a)
                bm.faces.new(list(reversed(c2)))
            b.paint(b.new_faces(make), "Build", jit(band_cols[j], 0.02))
    return b


# --- the sea serpent --------------------------------------------------------------------
def serpent_paint(b, faces):
    def col(f):
        nz = f.normal.z
        if nz < -0.45:
            return jit(SER_BELLY, 0.04)
        if nz > 0.4:
            return jit(SER_TOP, 0.05)
        return jit(SER_SIDE, 0.05)
    paint_by(b, faces, col)


def glow_spot(b, at, out, size=0.13):
    """A flattened glowing spot on the skin, facing `out`."""
    out = out.normalized()
    faces = b.new_faces(lambda: rk.tube(b.bm, [at - out * 0.05, at + out * 0.06], [(size, size * 0.7), (size * 0.75, size * 0.5)], ref=V((0, 1, 0)) if abs(out.y) < 0.9 else V((1, 0, 0)), seg=6))
    paint(b, faces, SER_SPOT, 0.0, "Glow")


def serpent_head():
    """A big sea-serpent head (~3 m) with an open jaw, teeth, glowing eyes, side frills and a crest.
    Faces +Y here (-Z in Godot); origin at the neck joint."""
    b = Builder(["Build", "Glow"])
    # Upper head: neck to snout.
    prof = [(0.0, 0.1, 1.05, 1.0), (0.7, 0.28, 1.12, 0.88), (1.5, 0.34, 0.9, 0.62), (2.3, 0.26, 0.64, 0.42), (2.95, 0.12, 0.34, 0.22)]
    pts = [V((0, y, z)) for y, z, _, _ in prof]
    serpent_paint(b, b.new_faces(lambda: rk.tube(b.bm, pts, [(rx, rz) for _, _, rx, rz in prof], ref=V((1, 0, 0)), seg=8)))
    # Lower jaw, hinged near the neck and dropped open.
    hinge = V((0, 0.5, -0.35))
    d = V((0, math.cos(0.5), -math.sin(0.5)))
    jaw = [hinge + d * s for s in (0.0, 0.8, 1.6, 2.3)]
    jr = [(0.82, 0.38), (0.72, 0.3), (0.52, 0.22), (0.26, 0.13)]
    serpent_paint(b, b.new_faces(lambda: rk.tube(b.bm, jaw, jr, ref=V((1, 0, 0)), seg=8)))
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, 1.2, -0.42)), (0.55, 1.05, 0.4), 8, 5)), "Build", (0.62, 0.18, 0.24))
    # Teeth: down from the upper jaw's edge, up from the lower jaw's.
    ivory = (0.96, 0.93, 0.84)
    for y, z, rx in ((1.2, -0.12, 0.72), (1.75, -0.12, 0.66), (2.3, -0.1, 0.5), (2.75, -0.05, 0.28)):
        for s in (-1, 1):
            base = V((s * rx * 0.8, y, z))
            tube(b, [base, base + V((0, 0.03, -0.24 if y < 2.6 else -0.42))], [0.07, 0.01], ivory, seg=3)
    for s_ in (0.95, 1.5, 2.0):
        for s in (-1, 1):
            p = hinge + d * s_
            w = 0.82 - s_ * 0.24
            base = V((s * w * 0.75, p.y, p.z + 0.25))
            tube(b, [base, base + V((0, 0.05, 0.22))], [0.06, 0.01], ivory, seg=3)
    # Glowing eyes under a dark brow, nostrils, and spots along the cheeks.
    for s in (-1, 1):
        b.paint(b.new_faces(lambda s=s: rk.blob(b.bm, V((s * 0.66, 1.55, 0.58)), (0.12, 0.2, 0.13), 6, 4)), "Glow", (0.85, 1.0, 0.6))
        box(b, V((s * 0.62, 1.55, 0.74)), (0.28, 0.5, 0.1), SER_TOP, 0.02, rot=Euler((0.15, -s * 0.35, 0)))
        glow_spot(b, V((s * 0.88, 0.75, 0.05)), V((s, 0, -0.2)), 0.11)
        glow_spot(b, V((s * 0.78, 1.25, -0.05)), V((s, 0, -0.25)), 0.09)
        glow_spot(b, V((s * 0.6, 1.0, -0.5)), V((s, 0, -0.5)), 0.08)
        b.paint(b.new_faces(lambda s=s: rk.blob(b.bm, V((s * 0.13, 2.92, 0.27)), (0.05, 0.05, 0.04), 5, 3)), "Build", (0.08, 0.08, 0.14))
    # Side frills fanning back and out, a crest along the top.
    for s in (-1, 1):
        base = [V((s * 0.85, 0.55, 0.85 - k * 0.32)) for k in range(5)]
        tips = [V((s * (1.55 + (0.25 if k % 2 == 0 else 0.0)), -0.45 + (0.3 if k % 2 else 0.0) - abs(k - 2) * 0.12, 1.35 - k * 0.55)) for k in range(5)]
        fin(b, base, tips, V((0.04, 0.03, 0)), [SER_FIN, shade(SER_FIN, 0.82)])
        glow_spot(b, tips[0] + V((0, 0, 0)), V((s, -0.3, 0.4)), 0.07)
        glow_spot(b, tips[4], V((s, -0.3, -0.4)), 0.07)
    base = [V((0, 1.7 - k * 0.42, 0.75 + k * 0.1)) for k in range(5)]
    tips = [V((0, 1.5 - k * 0.42 - 0.25, 1.1 + k * 0.12 + (0.25 if k % 2 else 0.0))) for k in range(5)]
    fin(b, base, tips, V((0.05, 0, 0)), [SER_FIN, shade(SER_FIN, 0.82)])
    return b


def serpent_body(b, y0, y1, prof, spots=True):
    """Body tube along Y with (y, radius, z) points, belly plates banded."""
    pts = [V((0, y, z)) for y, _, z in prof]
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, [(r, r * 0.95) for _, r, _ in prof], ref=V((1, 0, 0)), seg=10))
    serpent_paint(b, faces)
    for i, f in enumerate(faces):
        f.normal_update()
        if f.normal.z < -0.45 and (i // 10) % 2:
            b.paint([f], "Build", jit(shade(SER_BELLY, 0.9), 0.02))


def serpent_segment():
    """A body ring (~2.2 m across, 2.4 m long) with a jagged dorsal fin and glowing side spots. Origin at
    its centre, long axis along Y here (Godot Z)."""
    b = Builder(["Build", "Glow"])
    serpent_body(b, -1.2, 1.2, [(-1.25, 1.0, 0.0), (-0.6, 1.08, 0.0), (0.0, 1.12, 0.0), (0.6, 1.08, 0.0), (1.25, 1.0, 0.0)])
    base = [V((0, 0.9 - k * 0.45, 0.98 + (0.06 if k in (1, 2, 3) else 0))) for k in range(5)]
    tips = [V((0, 0.75 - k * 0.45 - 0.35, 1.45 + (0.4 if k % 2 else 0.05) - (0.25 if k in (0, 4) else 0))) for k in range(5)]
    fin(b, base, tips, V((0.05, 0, 0)), [SER_FIN, shade(SER_FIN, 0.82)])
    for s in (-1, 1):
        for y, z in ((-0.55, -0.15), (0.45, -0.25), (0.0, 0.35)):
            out = V((s, 0, z * 0.9))
            glow_spot(b, V((s * 1.06 * math.sqrt(max(0.0, 1 - z * z * 0.8)), y, z)), out, 0.13 if z < 0 else 0.1)
    return b


def serpent_tail():
    """The tapering tail with a big forked fluke. Its front (thick, like a segment's) end is at +1.2 on
    Y (Godot -1.2 on Z); origin where a segment's centre would be, so chain it like one more segment."""
    b = Builder(["Build", "Glow"])
    prof = [(1.25, 1.0, 0.0), (0.0, 0.88, 0.05), (-1.4, 0.68, 0.12), (-2.8, 0.47, 0.2), (-4.1, 0.28, 0.3), (-5.2, 0.13, 0.38), (-5.9, 0.06, 0.4)]
    serpent_body(b, -5.9, 1.25, prof)
    base = [V((0, 0.6 - k * 0.6, 0.86 - k * 0.12)) for k in range(5)]
    tips = [V((0, 0.4 - k * 0.6 - 0.3, 1.25 - k * 0.2 + (0.25 if k % 2 else 0))) for k in range(5)]
    fin(b, base, tips, V((0.05, 0, 0)), [SER_FIN, shade(SER_FIN, 0.82)])
    base = [V((0, -4.6 - k * 0.35, 0.33 + k * 0.02)) for k in range(5)]
    tips = [V((0, -5.3, 2.0)), V((0, -6.3, 1.5)), V((0, -6.1, 0.4)), V((0, -6.5, -0.7)), V((0, -5.8, -1.3))]
    fin(b, base, tips, V((0.06, 0, 0)), [SER_FIN, shade(SER_FIN, 0.82), (0.32, 0.7, 0.76)])
    glow_spot(b, V((0.04, -6.0, 1.5)), V((1, 0, 0)), 0.1)
    glow_spot(b, V((-0.04, -6.0, 1.5)), V((-1, 0, 0)), 0.1)
    glow_spot(b, V((0.04, -6.0, -0.75)), V((1, 0, 0)), 0.1)
    glow_spot(b, V((-0.04, -6.0, -0.75)), V((-1, 0, 0)), 0.1)
    for s in (-1, 1):
        for y, r in ((0.6, 0.95), (-0.7, 0.78), (-2.0, 0.58), (-3.3, 0.38)):
            glow_spot(b, V((s * r * 0.95, y, -0.12)), V((s, 0, -0.2)), 0.12 * r)
    return b


# --- export -----------------------------------------------------------------------------
def finish(name, b, origin=V((0, 0, 0))):
    bm = b.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    for v in bm.verts:
        v.co -= origin
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in b.mats:
        mesh.materials.append(rk.MATERIALS[m])
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    obj.location = origin
    bpy.context.collection.objects.link(obj)
    return obj, len(mesh.polygons)


def export(name, parts):
    """parts: [(object name, builder, origin)]; all go into one .glb."""
    objs, tris = [], 0
    for oname, b, origin in parts:
        o, t = finish(oname, b, origin)
        objs.append(o)
        tris += t
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True, export_vertex_color="NONE")
    print("SUNREACH", name, "tris", tris, "objects", [o.name for o in objs])
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


def single(name, fn):
    return lambda: export(name, [(name, fn(), V((0, 0, 0)))])


MODELS = {
    "palm_a": single("palm_a", lambda: nature_palm(3, 7.2, 1.9, 9)),
    "palm_b": single("palm_b", lambda: nature_palm(8, 6.0, 1.1, 8)),
    "palm_small": single("palm_small", lambda: nature_palm(15, 2.6, 0.5, 7, 0.7, 2)),
    "cactus_a": single("cactus_a", cactus_a),
    "cactus_b": single("cactus_b", cactus_b),
    "desert_shrub": single("desert_shrub", desert_shrub),
    "dune_grass": single("dune_grass", dune_grass),
    "rock_sand_a": single("rock_sand_a", rock_sand_a),
    "rock_sand_b": single("rock_sand_b", rock_sand_b),
    "rock_sand_c": single("rock_sand_c", rock_sand_c),
    "mesa_big": single("mesa_big", mesa_big),
    "sand_arch": single("sand_arch", sand_arch),
    "sea_rock": single("sea_rock", sea_rock),
    "islet": single("islet", islet),
    "house_dome": single("house_dome", house_dome),
    "house_tower": single("house_tower", house_tower),
    "house_wide": single("house_wide", house_wide),
    "market_stall": single("market_stall", market_stall),
    "well": single("well", well),
    "lantern_post": single("lantern_post", lantern_post),
    "palm_planter": single("palm_planter", palm_planter),
    "pier": single("pier", pier),
    "lighthouse": lambda: export("lighthouse", [("Lighthouse", lighthouse(), V((0, 0, 0))), ("Fire", _shift(fire_bowl(), V((0, 0, 14.65))), V((0, 0, 14.65)))]),
    "ship": lambda: export("ship", [("Hull", ship_hull(), V((0, 0, 0))), ("Sail", ship_sail(), V((0, 0.6, 6.0))),
                                    ("Wheel", _shift(ship_wheel(), V((0, -4.12, 1.95))), V((0, -4.12, 1.95)))]),
    "serpent_head": single("serpent_head", serpent_head),
    "serpent_segment": single("serpent_segment", serpent_segment),
    "serpent_tail": single("serpent_tail", serpent_tail),
}


def _shift(b, off):
    for v in b.bm.verts:
        v.co += off
    return b


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, fn in MODELS.items():
        if not only or name in only:
            fn()
