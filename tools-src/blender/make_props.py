"""Builds small faceted props: a treasure chest (base, and a lid built around its hinge so the game
can swing it open), a mossy ruined arch, and a rabbit. Exported to game/assets/props/.
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


def ruin():
    """A broken stone arch: one tall pillar, one snapped one, part of the lintel, fallen blocks, moss."""
    b = Builder(["Prop"])
    def pillar(x, blocks, lean=0.0):
        for i in range(blocks):
            s = 0.62 - (i % 2) * 0.04
            box(b, V((x + lean * i, rnd.uniform(-0.03, 0.03), 0.3 + i * 0.58)), (s, s, 0.56), rnd.choice(STONE), 0.06,
                tilt=None if i < blocks - 1 else Euler((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.1, 0.1), rnd.uniform(0, 0.4))))
        box(b, V((x, 0, 0.08)), (0.9, 0.9, 0.18), STONE[3], 0.04)
    pillar(-1.3, 6)
    pillar(1.3, 3, 0.02)
    for i in range(3):                                    # what's left of the lintel
        box(b, V((-1.3 + i * 0.66, 0, 3.72 + (0.05 if i == 1 else 0))), (0.66, 0.68, 0.42), rnd.choice(STONE), 0.05,
            tilt=Euler((0, 0.06 * i, 0)))
    for p, s in ((V((1.9, -0.8, 0.22)), 0.46), (V((0.6, -1.1, 0.2)), 0.42), (V((2.4, 0.5, 0.2)), 0.4), (V((-2.2, -0.6, 0.15)), 0.3)):
        box(b, p, (s * 1.2, s, s), rnd.choice(STONE), 0.06, tilt=Euler((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, 1.5))))
    for i in range(7):                                    # a low broken wall behind
        h = 0.35 + (0.3 if i in (1, 2, 4) else 0.0)
        box(b, V((-2.0 + i * 0.62, 1.1, h / 2)), (0.6, 0.45, h), rnd.choice(STONE), 0.06)
    for p, r in ((V((-1.3, 0.1, 3.5)), 0.28), (V((-0.6, 0.0, 3.95)), 0.24), (V((1.3, 0.1, 1.85)), 0.3), (V((-1.55, 0.2, 0.3)), 0.3),
                 (V((1.0, 1.1, 0.7)), 0.25), (V((-0.4, 1.2, 0.45)), 0.22), (V((1.9, -0.8, 0.45)), 0.2)):
        clump(b, p, r, 1, rnd, rnd.choice(MOSS), "Prop", 0.55)
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
export("chest_base", chest_base(), OUT)
export("chest_lid", chest_lid(), OUT)
export("ruin_arch", ruin(), OUT)
export("rabbit", rabbit(), OUT)
