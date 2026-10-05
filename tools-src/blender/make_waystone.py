"""Builds the waystone (fast travel, world/waystone.gd): a tall faceted standing stone with a glowing rune
on its front, on a round plinth of flagstones, with a ring of small stones. The rune and the grooves are
"Glow" (lit when the stone is woken). Faces -Y in Blender (+Z in Godot). Exported to
game/assets/props/waystone.glb.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_waystone.py
"""
import math
import os
import random
import sys
import bpy
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, export  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "props")
rnd = random.Random(31)
STONE = [(0.56, 0.58, 0.63), (0.5, 0.52, 0.58), (0.62, 0.63, 0.67), (0.47, 0.49, 0.55)]
FLAG = [(0.62, 0.6, 0.56), (0.56, 0.55, 0.52), (0.68, 0.66, 0.6)]
MOSS = [(0.38, 0.52, 0.3), (0.32, 0.46, 0.27)]
RUNE = (0.45, 0.95, 1.0)


def paint_each(b, faces, palette, mat="Stone"):
    for f in faces:
        b.paint([f], mat, rnd.choice(palette))


def waystone():
    b = Builder(["Stone", "Glow"])
    # The plinth: a low octagon of flagstones, a step round it.
    paint_each(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, -0.1)), V((0, 0, 0.12))], [(1.75, 1.75)] * 2, seg=8)), FLAG)
    paint_each(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, 0.12)), V((0, 0, 0.26))], [(1.25, 1.25)] * 2, seg=8)), FLAG)
    # The standing stone: four-sided, tapering, leaning a touch back, the top cut at a slant.
    pts = [V((0, 0, 0.2)), V((0, 0.02, 1.2)), V((0, 0.05, 2.3)), V((0, 0.07, 2.85))]
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, [(0.42, 0.3), (0.38, 0.28), (0.32, 0.24), (0.2, 0.16)], seg=4, ref=V((1, 0, 0))))
    paint_each(b, faces, STONE)
    for f in faces:                                   # moss on the lower back
        f.normal_update()
        c = f.calc_center_median()
        if c.z < 1.0 and f.normal.y > 0.3:
            b.paint([f], "Stone", rnd.choice(MOSS))
    # The rune on the front (-Y face): a ring, a staff through it, two arrow strokes.
    front = -0.33
    def bar(p0, p1, w=0.045):
        b.paint(b.new_faces(lambda: rk.tube(b.bm, [p0, p1], [(w, 0.02)] * 2, seg=4, ref=V((0, 1, 0)))), "Glow", RUNE)
    for k in range(10):                               # the ring
        a0, a1 = k * math.tau / 10, (k + 1) * math.tau / 10
        bar(V((math.cos(a0) * 0.2, front, 1.55 + math.sin(a0) * 0.2)), V((math.cos(a1) * 0.2, front, 1.55 + math.sin(a1) * 0.2)), 0.035)
    bar(V((0, front - 0.005, 0.95)), V((0, front - 0.005, 2.15)))
    bar(V((-0.16, front - 0.005, 2.0)), V((0, front - 0.005, 2.18)))
    bar(V((0.16, front - 0.005, 2.0)), V((0, front - 0.005, 2.18)))
    bar(V((-0.14, front - 0.005, 1.08)), V((0.14, front - 0.005, 1.08)), 0.035)
    # A ring of small stones round the plinth, and a glowing groove in the step.
    for k in range(7):
        a = k * math.tau / 7 + 0.3
        c = V((math.cos(a) * 2.05, math.sin(a) * 2.05, 0.15))
        paint_each(b, b.new_faces(lambda c=c, k=k: rk.boulder(b.bm, c, (0.42, 0.36, 0.5 + (k % 3) * 0.12), k + 5)), STONE)
    for k in range(8):
        a0, a1 = k * math.tau / 8 + math.pi / 8, (k + 1) * math.tau / 8 + math.pi / 8
        r = 1.27
        bar(V((math.cos(a0) * r, math.sin(a0) * r, 0.27)), V((math.cos(a1) * r, math.sin(a1) * r, 0.27)), 0.025)
    return b


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Stone": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)
os.makedirs(OUT, exist_ok=True)
export("waystone", waystone(), OUT)
