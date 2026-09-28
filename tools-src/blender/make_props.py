"""Builds small faceted props: a treasure chest (base, and a lid built around its hinge so the game
can swing it open), a ruined arch (round drums, glowing rune, ivy), a rabbit, and the village workbench. Exported to game/assets/props/.
Front faces -Y in Blender (+Z in Godot).

Run: tools/blender/blender.exe --background --python tools-src/blender/make_props.py
"""
import math
import os
import random
import sys
import bpy
import bmesh
from mathutils import Euler, Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump, export  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "props")
rnd = random.Random(21)

WOOD = [(0.62, 0.4, 0.24), (0.56, 0.36, 0.21), (0.68, 0.45, 0.27)]
IRON = (0.3, 0.3, 0.34)
GOLD = (0.98, 0.78, 0.32)
STONE = [(0.7, 0.68, 0.62), (0.62, 0.61, 0.57), (0.76, 0.73, 0.66), (0.58, 0.57, 0.54)]
MOSS = [(0.42, 0.58, 0.3), (0.36, 0.52, 0.26), (0.48, 0.62, 0.32)]
FUR = [(0.72, 0.6, 0.46), (0.66, 0.54, 0.41), (0.76, 0.64, 0.5)]


def paint(b, faces, color, var=0.04, mat="Prop"):
    for f in faces:
        k = 1.0 + rnd.uniform(-var, var)
        b.paint([f], mat, tuple(min(1.0, c * k) for c in color))


def box(b, center, size, color, var=0.04, tilt=None, mat="Prop"):
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            p = V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if tilt:
                p.rotate(tilt)
            v.co = p + center
    paint(b, b.new_faces(make), color, var, mat)


def chest_base():
    b = Builder(["Prop", "Glow"])
    W, D, H = 0.9, 0.6, 0.42
    for i in range(4):                                   # planks
        box(b, V((0, 0, 0.05 + H * (i + 0.5) / 4)), (W, D, H / 4 - 0.012), rnd.choice(WOOD))
    for x in (-W / 2 + 0.08, W / 2 - 0.08):              # iron bands and corner caps
        box(b, V((x, 0, H / 2 + 0.05)), (0.07, D + 0.03, H + 0.03), IRON, 0.0)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            box(b, V((x, y, 0.06)), (0.09, 0.09, 0.12), IRON, 0.0)
    box(b, V((0, -D / 2 - 0.02, H - 0.02)), (0.16, 0.05, 0.2), GOLD, 0.0, mat="Glow")    # lock plate
    box(b, V((0, -D / 2 - 0.05, H - 0.06)), (0.05, 0.03, 0.07), (0.25, 0.2, 0.1), 0.0)
    return b


def chest_lid():
    """Built around the hinge (back top edge of the base) at the origin."""
    b = Builder(["Prop", "Glow"])
    W, D = 0.9, 0.6
    faces = b.new_faces(lambda: rk.tube(b.bm, [V((-W / 2 - 0.01, -D / 2, 0)), V((W / 2 + 0.01, -D / 2, 0))], [(0.2, D / 2 + 0.01)] * 2, ref=V((0, 0, 1)), seg=8))
    for f in faces:
        for v in f.verts:
            if v.co.z < 0.0:
                v.co.z = 0.0            # half a barrel: a rounded lid
    paint(b, faces, WOOD[2])
    for x in (-W / 2 + 0.08, W / 2 - 0.08):
        faces = b.new_faces(lambda x=x: rk.tube(b.bm, [V((x - 0.035, -D / 2, 0)), V((x + 0.035, -D / 2, 0))], [(0.215, D / 2 + 0.025)] * 2, ref=V((0, 0, 1)), seg=8))
        for f in faces:
            for v in f.verts:
                if v.co.z < 0.0:
                    v.co.z = 0.0
        paint(b, faces, IRON, 0.0)
    box(b, V((0, -D - 0.02, 0.02)), (0.12, 0.05, 0.1), GOLD, 0.0, mat="Glow")
    return b


def soft(b, make, color, offset=0.05, segs=1, mat="Prop"):
    """Builds a shape with `make`, rounds its edges with a small bevel, paints it one colour."""
    def run():
        before = set(b.bm.edges)
        make()
        edges = [e for e in b.bm.edges if e not in before]
        bmesh.ops.bevel(b.bm, geom=edges, offset=offset, segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
    b.paint(b.new_faces(run), mat, color)


def cube(b, center, size, rot=None):
    def make():
        geom = bmesh.ops.create_cube(b.bm, size=1.0)
        for v in geom["verts"]:
            p = V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if rot:
                p.rotate(rot)
            v.co = p + center
    return make


def drum(b, bottom, top, r, color, seg=8):
    """A round column drum between two points."""
    soft(b, lambda: rk.tube(b.bm, [bottom, top], [(r, r)] * 2, ref=V((1, 0, 0)) if abs((top - bottom).normalized().z) > 0.9 else V((0, 0, 1)), seg=seg), color, 0.03)


RUIN_STONE = (0.76, 0.74, 0.7)
RUIN_DARK = (0.64, 0.63, 0.61)
RUNE = (0.5, 0.96, 0.9)
IVY = [(0.4, 0.62, 0.3), (0.46, 0.68, 0.33)]


def ruin():
    """A broken arch on a stepped platform: round column drums (one pillar whole, one snapped),
    half a lintel with a glowing rune keystone, hanging ivy, fallen drums and moss."""
    b = Builder(["Prop", "Glow"])
    soft(b, cube(b, V((0, 0, 0.05)), (4.6, 3.0, 0.3)), RUIN_DARK, 0.06)
    for i, (x, w, tilt) in enumerate(((-1.35, 1.4, 0.0), (0.12, 1.4, 0.04), (1.45, 1.1, -0.06))):   # cracked top step
        soft(b, cube(b, V((x, 0.1, 0.28)), (w - 0.06, 2.2, 0.18), Euler((tilt, 0, 0))), RUIN_STONE, 0.05)
    for x, drums in ((-1.35, 6), (1.35, 2)):
        soft(b, cube(b, V((x, 0.1, 0.5)), (0.9, 0.9, 0.3)), RUIN_DARK, 0.05)
        for i in range(drums):
            z0 = 0.65 + i * 0.55
            snapped = x > 0 and i == drums - 1            # the broken pillar's top drum sits askew
            top = V((x + 0.08, 0.14, z0 + 0.45)) if snapped else V((x, 0.1, z0 + 0.52))
            drum(b, V((x, 0.1, z0)), top, 0.34 - (i % 2) * 0.02, RUIN_STONE)
    cap = 0.65 + 6 * 0.55
    soft(b, cube(b, V((-1.35, 0.1, cap + 0.12)), (0.95, 0.95, 0.26)), RUIN_DARK, 0.05)
    soft(b, cube(b, V((-0.55, 0.1, cap + 0.5)), (2.3, 0.8, 0.5)), RUIN_STONE, 0.06)                 # half a lintel
    soft(b, cube(b, V((0.52, 0.1, cap + 0.44)), (0.5, 0.82, 0.62), Euler((0, 0.2, 0))), RUIN_DARK, 0.05)   # keystone, jutting
    # The rune on the keystone: a glowing ring with a diamond inside.
    ring = lambda: rk.tube(b.bm, [V((0.55, -0.32, cap + 0.44)), V((0.55, -0.36, cap + 0.44))], [(0.17, 0.17)] * 2, ref=V((1, 0, 0)), seg=10)
    b.paint(b.new_faces(ring), "Glow", RUNE)
    diamond = lambda: rk.tube(b.bm, [V((0.55, -0.34, cap + 0.3)), V((0.55, -0.34, cap + 0.44)), V((0.55, -0.34, cap + 0.58))],
                               [(0.01, 0.01), (0.07, 0.03), (0.01, 0.01)], ref=V((1, 0, 0)), seg=4)
    b.paint(b.new_faces(diamond), "Glow", (0.85, 1.0, 0.98))
    for x, length in ((-1.1, 1.6), (-0.6, 1.1), (-0.15, 1.9), (0.3, 0.8)):   # ivy hanging off the lintel
        p0 = V((x, -0.32, cap + 0.3))
        p1 = p0 + V((0.05, -0.04, -length))
        paint(b, b.new_faces(lambda p0=p0, p1=p1: rk.tube(b.bm, [p0, p1], [(0.02, 0.02)] * 2, seg=4)), IVY[0], 0.0)
        for k in range(int(length / 0.25)):
            clump(b, p0.lerp(p1, (k + 0.5) / (length / 0.25)) + V((rnd.uniform(-0.05, 0.05), -0.03, 0)), 0.07, 1, rnd, rnd.choice(IVY), "Prop", 0.6)
    for p, r in ((V((-0.9, 0.1, cap + 0.8)), 0.3), (V((-1.4, 0.1, cap + 0.3)), 0.24), (V((1.4, 0.1, 1.72)), 0.28), (V((-1.7, -0.5, 0.45)), 0.22)):
        clump(b, p, r, 1, rnd, rnd.choice(IVY), "Prop", 0.5)
    drum(b, V((1.6, -1.6, 0.3)), V((2.2, -1.9, 0.33)), 0.32, RUIN_STONE)       # fallen drums
    drum(b, V((0.4, -1.9, 0.28)), V((0.95, -2.3, 0.3)), 0.3, RUIN_STONE)
    soft(b, cube(b, V((2.3, 0.4, 0.3)), (0.9, 0.6, 0.45), Euler((0.2, -0.3, 0.6))), RUIN_DARK, 0.05)
    for x in (-2.0, -1.4, 1.9):                                  # grass tufts at the base
        clump(b, V((x, -1.4, 0.12)), 0.18, 1, rnd, rnd.choice(IVY), "Prop", 0.6)
    return b


STRAW = [(0.9, 0.74, 0.4), (0.86, 0.69, 0.36)]
WB_WOOD = (0.6, 0.41, 0.26)
WB_DARK = (0.42, 0.28, 0.19)
IRON_D = (0.34, 0.35, 0.38)


def workbench():
    """The village workbench: a sturdy bench with a vise, hammer and saw, an anvil on a stump,
    all under a round straw canopy on four posts (the round house's look). Faces -Y."""
    b = Builder(["Prop", "Glow"])
    for x in (-1.25, 1.25):                          # posts at the back, so the camera sees the bench
        for y in (0.4, 2.0):
            soft(b, cube(b, V((x, y, 1.4)), (0.18, 0.18, 2.8)), WB_DARK, 0.04)
            soft(b, cube(b, V((x, y, 0.08)), (0.34, 0.34, 0.16)), RUIN_DARK, 0.04)
    # Round straw canopy in two tiers with a little finial.
    c = V((0, 1.2, 0))
    for r0, z0, r1, z1 in ((1.95, 2.7, 1.1, 3.35), (1.25, 3.2, 0.1, 4.0)):
        faces = b.new_faces(lambda r0=r0, z0=z0, r1=r1, z1=z1: rk.tube(b.bm, [c + V((0, 0, z0)), c + V((0, 0, z0 + 0.16)), c + V((0, 0, z1))],
                                                                       [(r0, r0), (r0 * 0.96, r0 * 0.96), (r1, r1)], seg=14))
        for f in faces:
            b.paint([f], "Prop", rnd.choice(STRAW))
    soft(b, lambda: rk.tube(b.bm, [c + V((0, 0, 3.95)), c + V((0, 0, 4.35))], [(0.04, 0.04)] * 2, seg=5), WB_DARK, 0.01)
    clump(b, c + V((0, 0, 4.4)), 0.08, 1, rnd, (0.95, 0.78, 0.4), "Prop", 1.0)
    # The bench: thick top, legs, a shelf with logs, a vise, a hammer and a saw.
    soft(b, cube(b, V((0, 0.3, 0.92)), (2.0, 0.85, 0.14)), WB_WOOD, 0.04)
    for x in (-0.85, 0.85):
        for y in (0.0, 0.6):
            soft(b, cube(b, V((x, y, 0.45)), (0.12, 0.12, 0.9)), WB_DARK, 0.02)
    soft(b, cube(b, V((0, 0.3, 0.3)), (1.8, 0.7, 0.08)), WB_WOOD, 0.02)
    for i in range(3):
        soft(b, lambda i=i: rk.tube(b.bm, [V((-0.7, 0.1 + i * 0.22, 0.44)), V((0.2, 0.1 + i * 0.22, 0.44))], [(0.09, 0.09)] * 2, ref=V((0, 0, 1)), seg=6), (0.7, 0.5, 0.32), 0.02)
    soft(b, cube(b, V((0.85, 0.0, 1.08)), (0.22, 0.26, 0.2)), IRON_D, 0.02)                       # vise
    soft(b, cube(b, V((0.85, -0.18, 1.08)), (0.05, 0.3, 0.05)), IRON_D, 0.01)
    soft(b, cube(b, V((-0.3, 0.2, 1.02)), (0.5, 0.06, 0.05), Euler((0, 0, 0.3))), WB_DARK, 0.01)   # hammer
    soft(b, cube(b, V((-0.08, 0.27, 1.05)), (0.12, 0.1, 0.1), Euler((0, 0, 0.3))), IRON_D, 0.02)
    soft(b, cube(b, V((0.3, 0.45, 1.0)), (0.6, 0.04, 0.02)), (0.85, 0.87, 0.9), 0.005)             # saw blade on the bench
    # Anvil on a stump, beside the bench.
    soft(b, lambda: rk.tube(b.bm, [V((-1.7, -0.3, 0.0)), V((-1.7, -0.3, 0.55))], [(0.3, 0.3), (0.28, 0.28)], seg=8), WB_WOOD, 0.03)
    soft(b, cube(b, V((-1.7, -0.3, 0.68)), (0.24, 0.5, 0.22)), IRON_D, 0.03)
    soft(b, cube(b, V((-1.7, -0.3, 0.84)), (0.34, 0.7, 0.12)), IRON_D, 0.03)
    # A lantern hanging from the canopy, glowing warm.
    soft(b, lambda: rk.tube(b.bm, [V((1.1, -0.3, 2.78)), V((1.1, -0.3, 2.3))], [(0.012, 0.012)] * 2, seg=4), IRON_D, 0.002)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((1.1, -0.3, 2.18)), (0.11, 0.11, 0.15), 6, 4)), "Glow", (1.0, 0.76, 0.4))
    return b


def rabbit():
    """A sitting rabbit, about 30 cm tall, facing -Y."""
    b = Builder(["Prop"])
    body = b.new_faces(lambda: rk.blob(b.bm, V((0, 0.02, 0.12)), (0.09, 0.13, 0.1), 7, 5))
    paint(b, body, rnd.choice(FUR), 0.06)
    head = b.new_faces(lambda: rk.blob(b.bm, V((0, -0.11, 0.2)), (0.065, 0.07, 0.065), 7, 5))
    paint(b, head, FUR[0], 0.05)
    for s in (1, -1):
        ear = b.new_faces(lambda s=s: rk.tube(b.bm, [V((s * 0.03, -0.09, 0.25)), V((s * 0.05, -0.06, 0.35)), V((s * 0.055, -0.04, 0.41))],
                                              [(0.022, 0.012), (0.026, 0.012), (0.004, 0.004)], seg=4))
        paint(b, ear, FUR[1], 0.03)
        clump(b, V((s * 0.045, -0.15, 0.225)), 0.012, 1, rnd, (0.08, 0.07, 0.07), "Prop", 1.0)     # eyes
        paint(b, b.new_faces(lambda s=s: rk.blob(b.bm, V((s * 0.05, -0.06, 0.03)), (0.03, 0.06, 0.025), 5, 3)), FUR[2])  # hind feet
    clump(b, V((0, -0.175, 0.19)), 0.012, 1, rnd, (0.85, 0.5, 0.5), "Prop", 1.0)                  # nose
    clump(b, V((0, 0.15, 0.14)), 0.04, 1, rnd, (0.95, 0.93, 0.9), "Prop", 0.9)                   # tail
    return b


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Prop": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
os.makedirs(OUT, exist_ok=True)
def campfire():
    """A ring of stones round crossed logs with glowing embers, and a pot hanging from a tripod."""
    b = Builder(["Prop", "Glow"])
    for k in range(9):
        a = k * math.tau / 9
        clump(b, V((math.cos(a) * 0.62, math.sin(a) * 0.62, 0.08)), 0.16, 1, rnd, rnd.choice(STONE), "Prop", 0.7)
    for a in (0.3, 1.35, 2.4):
        d = V((math.cos(a), math.sin(a), 0)) * 0.45
        soft(b, lambda d=d: rk.tube(b.bm, [-d + V((0, 0, 0.08)), d + V((0, 0, 0.2))], [(0.07, 0.07)] * 2, ref=V((0, 0, 1)), seg=6), rnd.choice(WOOD), 0.02)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, 0, 0.1)), (0.3, 0.3, 0.1), 8, 3)), "Glow", (1.0, 0.45, 0.12))
    for a in (0.5, 2.6, 4.7):                        # tripod
        foot = V((math.cos(a) * 0.9, math.sin(a) * 0.9, 0))
        soft(b, lambda foot=foot: rk.tube(b.bm, [foot, V((0, 0, 1.5))], [(0.035, 0.035)] * 2, seg=5), WB_DARK, 0.01)
    soft(b, lambda: rk.tube(b.bm, [V((0, 0, 1.5)), V((0, 0, 0.95))], [(0.01, 0.01)] * 2, seg=4), IRON_D, 0.003)
    soft(b, lambda: rk.tube(b.bm, [V((0, 0, 0.62)), V((0, 0, 0.7)), V((0, 0, 0.9)), V((0, 0, 0.96))],
                            [(0.12, 0.12), (0.22, 0.22), (0.22, 0.22), (0.2, 0.2)], seg=10), IRON_D, 0.02)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0, 0, 0.94)), (0.18, 0.18, 0.02), 8, 2)), "Prop", (0.72, 0.5, 0.26))
    # A log to sit on.
    soft(b, lambda: rk.tube(b.bm, [V((-0.7, -1.3, 0.18)), V((0.7, -1.3, 0.18))], [(0.18, 0.18)] * 2, ref=V((0, 0, 1)), seg=7), WOOD[1], 0.03)
    return b


def site_board():
    """A notice board on two posts with a pinned plan (the village project board)."""
    b = Builder(["Prop", "Glow"])
    for x in (-0.55, 0.55):
        soft(b, cube(b, V((x, 0, 0.8)), (0.12, 0.12, 1.6)), WB_DARK, 0.02)
    soft(b, cube(b, V((0, 0, 1.15)), (1.3, 0.08, 0.8)), WOOD[0], 0.03)
    soft(b, cube(b, V((0, 0.05, 1.5)), (1.5, 0.3, 0.08)), WB_DARK, 0.02)
    soft(b, cube(b, V((-0.2, -0.06, 1.15)), (0.55, 0.02, 0.5)), (0.95, 0.9, 0.78), 0.005)
    soft(b, cube(b, V((0.35, -0.06, 1.05)), (0.3, 0.02, 0.35)), (0.92, 0.84, 0.66), 0.005)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((-0.2, -0.08, 1.35)), (0.03, 0.02, 0.03), 5, 3)), "Glow", (1.0, 0.4, 0.3))
    return b


def scaffold():
    """Posts, planks and a stack of timber: a building on its way."""
    b = Builder(["Prop"])
    for x in (-2.0, 2.0):
        for y in (-1.6, 1.6):
            soft(b, cube(b, V((x, y, 1.3)), (0.14, 0.14, 2.6)), WB_DARK, 0.02)
    for z in (1.0, 2.2):
        for y in (-1.6, 1.6):
            soft(b, cube(b, V((0, y, z)), (4.2, 0.1, 0.16)), WOOD[0], 0.02)
        for x in (-2.0, 2.0):
            soft(b, cube(b, V((x, 0, z)), (0.1, 3.4, 0.16)), WOOD[2], 0.02)
    soft(b, cube(b, V((0, -1.75, 1.05)), (3.8, 0.5, 0.06)), WOOD[1], 0.02)
    for i in range(4):
        soft(b, cube(b, V((1.2, 2.4, 0.1 + i * 0.16)), (1.8, 0.5, 0.14), Euler((0, 0, 0.05 * i))), WOOD[i % 3], 0.02)
    for k in range(5):
        clump(b, V((-1.4 + k * 0.3, 2.3, 0.12)), 0.16, 1, rnd, rnd.choice(STONE), "Prop", 0.7)
    return b


def smithy():
    """An open-fronted smithy: a stone forge with glowing coals and a tall chimney, a slate roof on
    timber posts, an anvil on a stump, a quench barrel and tools on the wall. Faces -Y."""
    b = Builder(["Prop", "Glow"])
    soft(b, cube(b, V((0, 0.2, 0.1)), (4.6, 3.6, 0.2)), RUIN_DARK, 0.05)
    # Forge at the back left: stone block, coals, chimney.
    soft(b, cube(b, V((-1.2, 1.2, 0.6)), (1.6, 1.1, 1.0)), STONE[1], 0.06)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((-1.2, 1.05, 1.12)), (0.55, 0.35, 0.08), 8, 3)), "Glow", (1.0, 0.42, 0.1))
    soft(b, cube(b, V((-1.2, 1.45, 2.2)), (1.0, 0.6, 2.2)), STONE[3], 0.05)
    soft(b, cube(b, V((-1.2, 1.45, 4.1)), (0.7, 0.45, 1.6)), STONE[0], 0.05)
    soft(b, cube(b, V((-1.2, 1.45, 4.95)), (0.85, 0.6, 0.12)), RUIN_DARK, 0.02)
    # Posts and a sloped slate roof.
    for x in (-2.1, 2.1):
        for y in (-1.4, 1.7):
            soft(b, cube(b, V((x, y, 1.5)), (0.2, 0.2, 2.8 + (0.4 if y > 0 else 0))), WB_DARK, 0.03)
    for k in range(5):
        y = -1.8 + k * 0.8
        z = 2.95 + k * 0.18
        soft(b, cube(b, V((0, y, z)), (5.0, 0.95, 0.12), Euler((-0.22, 0, 0))), (0.36, 0.4, 0.5) if k % 2 else (0.42, 0.46, 0.56), 0.02)
    # Anvil on a stump, quench barrel, hanging tools.
    soft(b, lambda: rk.tube(b.bm, [V((0.6, -0.4, 0.2)), V((0.6, -0.4, 0.75))], [(0.32, 0.32), (0.3, 0.3)], seg=8), WB_WOOD, 0.03)
    soft(b, cube(b, V((0.6, -0.4, 0.88)), (0.26, 0.55, 0.24)), IRON_D, 0.03)
    soft(b, cube(b, V((0.6, -0.4, 1.05)), (0.38, 0.8, 0.14)), IRON_D, 0.03)
    soft(b, lambda: rk.tube(b.bm, [V((1.6, 0.9, 0.2)), V((1.6, 0.9, 1.0))], [(0.35, 0.35), (0.38, 0.38)], seg=10), WB_WOOD, 0.03)
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((1.6, 0.9, 0.98)), (0.32, 0.32, 0.02), 8, 2)), "Prop", (0.3, 0.45, 0.55))
    soft(b, cube(b, V((0.8, 1.72, 1.9)), (1.6, 0.08, 1.0)), WOOD[1], 0.02)
    for x in (0.3, 0.8, 1.3):
        soft(b, cube(b, V((x, 1.64, 1.9)), (0.06, 0.04, 0.6)), IRON_D, 0.01)
    # A warm lantern at the front post.
    b.paint(b.new_faces(lambda: rk.blob(b.bm, V((2.1, -1.55, 2.3)), (0.12, 0.12, 0.16), 6, 4)), "Glow", (1.0, 0.76, 0.4))
    return b


export("chest_base", chest_base(), OUT)
export("chest_lid", chest_lid(), OUT)
export("ruin_arch", ruin(), OUT)
export("rabbit", rabbit(), OUT)
export("workbench", workbench(), OUT)
export("campfire", campfire(), OUT)
export("site_board", site_board(), OUT)
export("scaffold", scaffold(), OUT)
export("smithy", smithy(), OUT)
