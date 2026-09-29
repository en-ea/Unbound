"""Builds the gathering tools (axe, pickaxe), the sword, and simple armour pieces (helm, chestplate,
boots: drop and icon placeholders until the owner's designs) as faceted low-poly models.
The handle runs along +Z from the grip (origin) so the game can put it straight in the hand.
Exported to game/assets/items/<name>.glb.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_tools.py
"""
import os
import sys
import bpy
import bmesh
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "items")
COLORS = {"Handle": (0.55, 0.38, 0.22), "Metal": (0.72, 0.74, 0.78), "Wrap": (0.32, 0.2, 0.13)}


def handle(bm):
    rk.tube(bm, [V((0, 0, -0.12)), V((0, 0, 0.3)), V((0, 0, 0.62))], [(0.022, 0.022), (0.02, 0.02), (0.019, 0.019)], seg=6)


def wrap(bm):
    rk.tube(bm, [V((0, 0, -0.1)), V((0, 0, 0.08))], [(0.026, 0.026)] * 2, seg=6)


def axe_head(bm):
    # A wedge: thick at the handle, wide thin edge out along +X.
    verts = [V((-0.04, -0.03, 0.5)), V((-0.04, 0.03, 0.5)), V((-0.04, 0.03, 0.62)), V((-0.04, -0.03, 0.62)),
             V((0.2, -0.005, 0.44)), V((0.2, 0.005, 0.44)), V((0.2, 0.005, 0.7)), V((0.2, -0.005, 0.7))]
    bv = [bm.verts.new(v) for v in verts]
    for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2)):
        bm.faces.new([bv[i] for i in f])


def pick_head(bm):
    rk.tube(bm, [V((-0.24, 0, 0.5)), V((-0.1, 0, 0.6)), V((0, 0, 0.62)), V((0.1, 0, 0.6)), V((0.24, 0, 0.5))],
            [(0.004, 0.004), (0.022, 0.018), (0.032, 0.026), (0.022, 0.018), (0.004, 0.004)], ref=V((0, 1, 0)), seg=4)


def sword_grip(bm):
    rk.tube(bm, [V((0, 0, -0.1)), V((0, 0, 0.1))], [(0.02, 0.02)] * 2, seg=6)


def sword_guard(bm):
    rk.tube(bm, [V((-0.1, 0, 0.12)), V((0.1, 0, 0.12))], [(0.022, 0.03)] * 2, ref=V((0, 0, 1)), seg=4)
    rk.blob(bm, V((0, 0, -0.12)), (0.03, 0.03, 0.03), 6, 4)


def sword_blade(bm):
    rk.tube(bm, [V((0, 0, 0.13)), V((0, 0, 0.6)), V((0, 0, 0.72))], [(0.045, 0.01), (0.04, 0.009), (0.002, 0.002)],
            ref=V((1, 0, 0)), seg=4)


def helm_shell(bm):
    rk.blob(bm, V((0, 0, 0.12)), (0.15, 0.16, 0.15), 10, 7, keep=lambda p: p.z > 0.1)
    rk.tube(bm, [V((0, 0, 0.1)), V((0, 0, 0.13))], [(0.165, 0.175)] * 2, seg=10)
    rk.tube(bm, [V((0, -0.17, 0.2)), V((0, -0.18, 0.06))], [(0.018, 0.012), (0.014, 0.01)], ref=V((1, 0, 0)), seg=4)


def helm_crest(bm):
    rk.tube(bm, [V((0, -0.08, 0.28)), V((0, 0.02, 0.31)), V((0, 0.13, 0.26))], [(0.018, 0.03)] * 3, ref=V((1, 0, 0)), seg=4)


def chest_plate(bm):
    rk.tube(bm, [V((0, 0, 0.0)), V((0, 0, 0.14)), V((0, 0, 0.28)), V((0, 0, 0.34))], [(0.15, 0.1), (0.16, 0.105), (0.17, 0.1), (0.1, 0.07)], seg=10)
    rk.tube(bm, [V((0, -0.1, 0.03)), V((0, -0.112, 0.2)), V((0, -0.1, 0.32))], [(0.012, 0.008)] * 3, ref=V((1, 0, 0)), seg=4)


def chest_straps(bm):
    for s in (1, -1):
        rk.blob(bm, V((s * 0.17, 0, 0.3)), (0.07, 0.08, 0.05), 6, 4)
    rk.tube(bm, [V((0, 0, -0.01)), V((0, 0, 0.03))], [(0.155, 0.105)] * 2, seg=10)


def boot_pair(bm):
    for s in (1, -1):
        x = s * 0.08
        rk.tube(bm, [V((x, 0.03, 0.26)), V((x, 0.03, 0.08)), V((x, 0.0, 0.03)), V((x, -0.1, 0.02)), V((x, -0.15, 0.02))],
                [(0.055, 0.055), (0.055, 0.058), (0.055, 0.06), (0.05, 0.035), (0.04, 0.028)], ref=V((1, 0, 0)), seg=6)


def boot_cuffs(bm):
    for s in (1, -1):
        rk.tube(bm, [V((s * 0.08, 0.03, 0.2)), V((s * 0.08, 0.03, 0.28))], [(0.065, 0.065)] * 2, seg=6)


def build(name, parts):
    objs = []
    for mat, fn in parts:
        bm = bmesh.new()
        fn(bm)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(name + mat)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(rk.MATERIALS[mat])
        obj = bpy.data.objects.new(name + "_" + mat, mesh)
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
    obj = rk.join(objs, name)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True)
    print("TOOL", name, rk.tri_count([obj]))
    bpy.data.objects.remove(obj, do_unlink=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials(COLORS, roughness=0.7)
os.makedirs(OUT, exist_ok=True)
build("axe", [("Handle", handle), ("Wrap", wrap), ("Metal", axe_head)])
build("pickaxe", [("Handle", handle), ("Wrap", wrap), ("Metal", pick_head)])
build("sword", [("Wrap", sword_grip), ("Handle", sword_guard), ("Metal", sword_blade)])
build("armor_helm", [("Metal", helm_shell), ("Wrap", helm_crest)])
build("armor_chest", [("Metal", chest_plate), ("Wrap", chest_straps)])
build("armor_boots", [("Wrap", boot_pair), ("Metal", boot_cuffs)])
