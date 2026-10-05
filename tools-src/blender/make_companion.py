"""Builds Cinder, the Pyromancer's companion (world/companion.gd): a little fire spirit that floats at your
shoulder. A round charcoal body with glowing ember cracks and a warm belly, two big bright eyes, stubby
arms, a crown of flames and a flame tail. Separate parts with their pivots (Body, Eyes, Flame, Tail,
Arm_L, Arm_R) so the game animates it (bob, blink, flicker, wave). Faces -Y in Blender (+Z in Godot).
Exported to game/assets/creatures/cinder.glb.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_companion.py
"""
import math
import os
import random
import sys
import bpy
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "creatures", "cinder.glb")
rnd = random.Random(9)
COAL = [(0.2, 0.14, 0.14), (0.16, 0.11, 0.11), (0.24, 0.16, 0.15)]
EMBER = [(1.0, 0.45, 0.12), (1.0, 0.58, 0.18), (0.95, 0.32, 0.08)]
FLAME = [(1.0, 0.42, 0.08), (1.0, 0.62, 0.15), (1.0, 0.82, 0.35)]
BODY_C = V((0, 0, 0.0))
EYES_C = V((0, -0.17, 0.05))
CROWN = V((0, 0.02, 0.18))
TAIL = V((0, 0.17, -0.06))
ARMS = {"L": V((0.2, -0.02, -0.04)), "R": V((-0.2, -0.02, -0.04))}


def body():
    b = Builder(["Coal", "Glow"])
    faces = b.new_faces(lambda: rk.blob(b.bm, V((0, 0, 0)), (0.2, 0.19, 0.21), 10, 7))
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.y < -0.55 and c.z < -0.02:                      # the warm belly
            b.paint([f], "Glow", EMBER[1])
        elif rnd.random() < 0.16:                                    # ember cracks
            b.paint([f], "Glow", rnd.choice(EMBER))
        else:
            b.paint([f], "Coal", rnd.choice(COAL))
    for s in (1, -1):                                               # little coal cheeks
        b.paint(b.new_faces(lambda s=s: rk.blob(b.bm, V((s * 0.12, -0.15, -0.02)), (0.035, 0.02, 0.025), 6, 4)), "Glow", (1.0, 0.5, 0.3))
    return b


def eyes():
    b = Builder(["Coal", "Glow"])
    for s in (1, -1):
        c = EYES_C + V((s * 0.075, 0, 0))
        b.paint(b.new_faces(lambda c=c: rk.blob(b.bm, c, (0.045, 0.03, 0.06), 8, 6)), "Glow", (1.0, 0.97, 0.82))
        b.paint(b.new_faces(lambda c=c: rk.blob(b.bm, c + V((0, -0.022, -0.008)), (0.022, 0.012, 0.032), 6, 4)), "Coal", (0.08, 0.05, 0.05))
    return b


def flame_spike(b, base, tip, w, colors):
    faces = b.new_faces(lambda: rk.tube(b.bm, [base, (base + tip) / 2 + V((0, 0, 0.01)), tip], [(w, w * 0.8), (w * 0.7, w * 0.6), (0.004, 0.004)], seg=5))
    for f in faces:
        f.normal_update()
        t = (f.calc_center_median().z - base.z) / max(tip.z - base.z, 0.01)
        b.paint([f], "Glow", colors[min(2, int(t * 3))])


def flame():
    b = Builder(["Coal", "Glow"])
    for x, y, h, w in ((0, 0, 0.26, 0.07), (0.07, 0.03, 0.18, 0.05), (-0.07, 0.03, 0.2, 0.05), (0.03, 0.07, 0.14, 0.04), (-0.04, -0.04, 0.15, 0.045)):
        base = CROWN + V((x, y, 0))
        tip = base + V((x * 0.6, y * 0.5 + 0.04, h))
        flame_spike(b, base, tip, w, FLAME)
    return b


def tail():
    b = Builder(["Coal", "Glow"])
    pts = [TAIL, TAIL + V((0, 0.1, 0.0)), TAIL + V((0, 0.2, 0.06)), TAIL + V((0, 0.27, 0.14))]
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, [(0.06, 0.05), (0.05, 0.04), (0.03, 0.025), (0.004, 0.004)], seg=5))
    for f in faces:
        t = (f.calc_center_median().y - TAIL.y) / 0.27
        b.paint([f], "Glow", FLAME[min(2, int(t * 3))])
    return b


def arm(at):
    b = Builder(["Coal", "Glow"])
    s = 1 if at.x > 0 else -1
    faces = b.new_faces(lambda: rk.tube(b.bm, [at, at + V((s * 0.06, -0.02, -0.03)), at + V((s * 0.09, -0.03, -0.07))], [(0.035, 0.035), (0.03, 0.03), (0.026, 0.026)], seg=5))
    b.paint(faces, "Coal", COAL[0])
    b.paint(b.new_faces(lambda: rk.blob(b.bm, at + V((s * 0.1, -0.035, -0.09)), (0.03, 0.03, 0.03), 6, 4)), "Glow", EMBER[0])
    return b


def to_object(name, b, pivot):
    for v in b.bm.verts:
        v.co -= pivot
    bmesh.ops.remove_doubles(b.bm, verts=b.bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces)
    mesh = bpy.data.meshes.new(name)
    b.bm.to_mesh(mesh)
    b.bm.free()
    for m in b.mats:
        mesh.materials.append(rk.MATERIALS[m])
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    obj.location = pivot
    bpy.context.collection.objects.link(obj)
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Coal": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.85)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
objs = [to_object("Body", body(), BODY_C), to_object("Eyes", eyes(), EYES_C), to_object("Flame", flame(), CROWN),
        to_object("Tail", tail(), TAIL)]
for k, at in ARMS.items():
    objs.append(to_object("Arm_" + k, arm(at), at))
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print("CINDER tris", rk.tri_count(objs), [o.name for o in objs])
