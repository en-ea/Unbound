"""Builds the wolf enemy: a lean faceted grey wolf with a dark saddle, pale chest and muzzle,
tall ears, a bushy tail and amber eyes. Separate parts (Body, Head with a child Jaw, Tail,
Leg_FL/FR/BL/BR) whose origins are their pivots, animated in code (wolf_visual.gd).
Faces -Y in Blender (+Z in Godot). Exported to game/assets/creatures/wolf.glb.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_wolf.py
"""
import os
import random
import sys
import bmesh
import bpy
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "creatures", "wolf.glb")
rnd = random.Random(9)

FUR = [(0.68, 0.7, 0.75), (0.62, 0.64, 0.7), (0.73, 0.75, 0.8)]
DARK = [(0.42, 0.43, 0.5), (0.47, 0.48, 0.55), (0.38, 0.39, 0.46)]
PALE = [(0.88, 0.87, 0.84), (0.82, 0.81, 0.78), (0.92, 0.91, 0.88)]
NOSE = (0.12, 0.11, 0.13)
AMBER = (1.0, 0.68, 0.18)
NECK = V((0, -0.52, 0.8))
JAW = NECK + V((0, -0.14, -0.04))
TAIL = V((0, 0.52, 0.68))
HIPS = {"FL": V((0.12, -0.38, 0.56)), "FR": V((-0.12, -0.38, 0.56)), "BL": V((0.12, 0.36, 0.58)), "BR": V((-0.12, 0.36, 0.58))}


def faceted(b, pts, radii, palette, seg=6, ref=V((1, 0, 0)), mat="Wolf"):
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=ref, seg=seg))
    for f in faces:
        b.paint([f], mat, rnd.choice(palette))
    return faces


def tuft(b, base, tip, width, palette):
    faceted(b, [base, tip], [(width, width * 0.7), (0.004, 0.004)], palette, seg=4)


def body():
    b = Builder(["Wolf", "Eye"])
    # Deep chest, tucked waist, lean hips (the back is +Y).
    pts = [V((0, -0.52, 0.7)), V((0, -0.34, 0.66)), V((0, -0.08, 0.64)), V((0, 0.18, 0.64)), V((0, 0.4, 0.66)), V((0, 0.54, 0.68))]
    faceted(b, pts, [(0.14, 0.17), (0.2, 0.25), (0.18, 0.2), (0.14, 0.14), (0.16, 0.17), (0.1, 0.11)], FUR, seg=8)
    # Dark saddle along the back, pale chest ruff below the neck.
    faceted(b, [V((0, -0.4, 0.86)), V((0, -0.1, 0.8)), V((0, 0.25, 0.76)), V((0, 0.5, 0.78))],
            [(0.12, 0.06), (0.13, 0.06), (0.11, 0.05), (0.07, 0.03)], DARK, seg=6)
    clump(b, V((0, -0.5, 0.56)), 0.15, 1, rnd, PALE[0], "Wolf", 0.8)
    clump(b, V((0, -0.3, 0.46)), 0.12, 1, rnd, PALE[1], "Wolf", 0.7)
    # Shaggy scruff over the shoulders, leaning back.
    for i, y in enumerate([-0.5, -0.4, -0.3, -0.2]):
        tuft(b, V((0, y, 0.9 - i * 0.02)), V((0, y + 0.16, 1.0 - i * 0.03)), 0.07 - i * 0.008, DARK)
    for s in (1, -1):
        tuft(b, V((s * 0.17, -0.42, 0.78)), V((s * 0.26, -0.28, 0.84)), 0.06, FUR)
        tuft(b, V((s * 0.15, -0.5, 0.6)), V((s * 0.22, -0.42, 0.5)), 0.05, PALE)
    return b


def head():
    b = Builder(["Wolf", "Eye"])
    faceted(b, [NECK + V((0, 0.14, -0.12)), NECK + V((0, 0.0, 0.0)), NECK + V((0, -0.18, 0.06))],
            [(0.13, 0.16), (0.13, 0.14), (0.13, 0.12)], FUR, seg=6)                                   # neck and skull
    faceted(b, [NECK + V((0, -0.18, 0.05)), NECK + V((0, -0.34, 0.0)), NECK + V((0, -0.46, -0.02))],
            [(0.1, 0.09), (0.065, 0.06), (0.045, 0.045)], FUR, seg=6)                                  # muzzle
    faceted(b, [NECK + V((0, -0.2, -0.01)), NECK + V((0, -0.44, -0.04))], [(0.08, 0.04), (0.045, 0.025)], PALE, seg=5)  # pale lip line
    faceted(b, [NECK + V((0, -0.06, 0.13)), NECK + V((0, -0.26, 0.07))], [(0.1, 0.035), (0.06, 0.02)], DARK, seg=4)     # brow
    clump(b, NECK + V((0, -0.475, 0.0)), 0.032, 1, rnd, NOSE, "Wolf", 1.0)
    for s in (1, -1):
        base = NECK + V((s * 0.075, -0.08, 0.13))
        faceted(b, [base, base + V((s * 0.04, 0.03, 0.12)), base + V((s * 0.05, 0.05, 0.2))],
                [(0.055, 0.03), (0.035, 0.02), (0.004, 0.004)], DARK, seg=4)                          # tall ears
        clump(b, base + V((s * 0.01, -0.012, 0.05)), 0.022, 1, rnd, PALE[1], "Wolf", 0.5)            # inner ear
        eye = NECK + V((s * 0.075, -0.22, 0.085))
        b.paint(b.new_faces(lambda eye=eye: clump(b, eye, 0.022, 1, rnd, AMBER, "Eye", 1.0)), "Eye", AMBER)
        tuft(b, NECK + V((s * 0.1, -0.1, 0.0)), NECK + V((s * 0.2, 0.02, -0.06)), 0.05, PALE)          # cheek fluff
    return b


def jaw():
    b = Builder(["Wolf", "Eye"])
    faceted(b, [JAW, JAW + V((0, -0.16, -0.03)), JAW + V((0, -0.29, -0.02))], [(0.075, 0.035), (0.05, 0.025), (0.035, 0.018)], PALE, seg=5)
    for s in (1, -1):
        faceted(b, [JAW + V((s * 0.025, -0.25, 0.0)), JAW + V((s * 0.025, -0.25, 0.05))], [(0.01, 0.01), (0.002, 0.002)], [(0.97, 0.96, 0.9)], seg=4)
    return b


def tail():
    b = Builder(["Wolf"])
    faceted(b, [TAIL, TAIL + V((0, 0.16, -0.06)), TAIL + V((0, 0.32, -0.18)), TAIL + V((0, 0.4, -0.3))],
            [(0.045, 0.045), (0.085, 0.09), (0.08, 0.08), (0.05, 0.05)], FUR, seg=6)
    faceted(b, [TAIL + V((0, 0.4, -0.3)), TAIL + V((0, 0.46, -0.4))], [(0.05, 0.05), (0.005, 0.005)], DARK, seg=6)
    return b


def leg(hip, front):
    b = Builder(["Wolf"])
    x, y = hip.x, hip.y
    if front:
        pts = [hip + V((0, 0, 0.08)), V((x, y - 0.01, 0.3)), V((x, y - 0.03, 0.06))]
        radii = [(0.075, 0.1), (0.045, 0.05), (0.035, 0.04)]
    else:   # the hind leg bends back at the hock
        pts = [hip + V((0, 0, 0.08)), V((x, y - 0.1, 0.36)), V((x, y + 0.08, 0.2)), V((x, y + 0.04, 0.06))]
        radii = [(0.09, 0.13), (0.055, 0.065), (0.035, 0.04), (0.033, 0.038)]
    faceted(b, pts, radii, FUR, seg=6)
    paw = pts[-1]
    faceted(b, [paw + V((0, 0.02, -0.02)), paw + V((0, -0.07, -0.04))], [(0.045, 0.03), (0.04, 0.025)], DARK, seg=6)
    return b


def to_object(name, b, pivot):
    mesh = bpy.data.meshes.new(name)
    for v in b.bm.verts:
        v.co -= pivot
    bmesh.ops.remove_doubles(b.bm, verts=b.bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces)
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
rk.make_materials({"Wolf": (1, 1, 1), "Eye": (1, 1, 1)}, roughness=0.85)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
head_obj = to_object("Head", head(), NECK)
jaw_obj = to_object("Jaw", jaw(), JAW)
bpy.context.view_layer.update()
jaw_obj.parent = head_obj                  # the jaw moves with the head
jaw_obj.matrix_parent_inverse = head_obj.matrix_world.inverted()
objs = [to_object("Body", body(), V((0, 0, 0.62))), head_obj, jaw_obj, to_object("Tail", tail(), TAIL)]
for key, hip in HIPS.items():
    objs.append(to_object("Leg_" + key, leg(hip, key.startswith("F")), hip))
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print("WOLF tris", rk.tri_count(objs), [o.name for o in objs])
