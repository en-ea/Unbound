"""Styled swords from the owner's sword pictures (4 Oct). Same frame as the plain sword in make_tools.py:
the grip at the origin, the blade up +Z (about 0.78 long). Own materials (not "Metal", so the tier tint
leaves them alone); "Rune" and "Crystal" parts glow in the game.
  sword_runeblade: a black blade with a gold crossguard curling up at the tips, a gold gem, a gold
                   pommel and glowing amber runes down the middle (Epic swords).
  sword_frost:     a pale glowing crystal blade, a guard of frost spikes fanning out, a teal wrapped grip
                   and a crystal pommel (Legendary swords).
Exported to game/assets/items/.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_swords.py
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
COLORS = {"Dark": (0.07, 0.07, 0.09), "Gold": (0.92, 0.68, 0.24), "Rune": (1.0, 0.72, 0.28), "Wrap": (0.1, 0.09, 0.11),
          "Crystal": (0.62, 0.95, 1.0), "Frost": (0.28, 0.52, 0.56), "FrostWrap": (0.16, 0.3, 0.33)}


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
        for p in mesh.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(name + "_" + mat, mesh)
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
    obj = rk.join(objs, name)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True)
    print("SWORD", name, rk.tri_count([obj]))
    bpy.data.objects.remove(obj, do_unlink=True)


def gem(bm, at, r, h):
    """A faceted gem: two four-sided cones back to back."""
    rk.tube(bm, [at - V((0, 0, h)), at, at + V((0, 0, h))], [(0.002, 0.002), (r, r), (0.002, 0.002)], seg=4)


# --- the runeblade --------------------------------------------------------------------------------

def rune_blade(bm):
    rk.tube(bm, [V((0, 0, 0.13)), V((0, 0, 0.62)), V((0, 0, 0.78))], [(0.052, 0.011), (0.046, 0.01), (0.002, 0.002)], seg=4)


def rune_wrap(bm):
    rk.tube(bm, [V((0, 0, -0.1)), V((0, 0, 0.1))], [(0.021, 0.021)] * 2, seg=6)


def rune_gold(bm):
    # the guard: a bar that curls up at both tips, a gem holder in the middle
    for s in (1, -1):
        rk.tube(bm, [V((0, 0, 0.12)), V((s * 0.08, 0, 0.125)), V((s * 0.12, 0, 0.16)), V((s * 0.13, 0, 0.2))],
                [(0.024, 0.026), (0.02, 0.022), (0.016, 0.018), (0.006, 0.006)], ref=V((0, 0, 1)), seg=4)
        rk.tube(bm, [V((s * 0.02, 0, 0.14)), V((s * 0.05, 0, 0.21))], [(0.012, 0.014), (0.004, 0.004)], ref=V((0, 0, 1)), seg=4)
    gem(bm, V((0, 0, -0.13)), 0.034, 0.04)                                  # the pommel
    rk.tube(bm, [V((0, 0, -0.105)), V((0, 0, -0.09))], [(0.028, 0.028)] * 2, seg=6)
    rk.tube(bm, [V((0, 0, 0.085)), V((0, 0, 0.105))], [(0.027, 0.027)] * 2, seg=6)


def rune_gem(bm):
    gem(bm, V((0, 0, 0.135)), 0.03, 0.035)


def runes(bm):
    """Little glowing marks down the middle of both faces of the blade."""
    for k in range(5):
        z = 0.24 + k * 0.075
        for y in (0.012, -0.012):
            w, h = (0.012, 0.03) if k % 2 == 0 else (0.022, 0.018)
            g = bmesh.ops.create_cube(bm, size=1.0)
            for v in g["verts"]:
                v.co = V((v.co.x * w, v.co.y * 0.004 + y, v.co.z * h + z))


# --- the frost blade ------------------------------------------------------------------------------

def frost_blade(bm):
    rk.tube(bm, [V((0, 0, 0.13)), V((0, 0, 0.45)), V((0, 0, 0.66)), V((0, 0, 0.8))],
            [(0.05, 0.016), (0.058, 0.018), (0.042, 0.014), (0.002, 0.002)], seg=4)
    gem(bm, V((0, 0, -0.14)), 0.03, 0.05)                                  # the crystal pommel


def frost_guard(bm):
    rk.tube(bm, [V((0, 0, 0.1)), V((0, 0, 0.14))], [(0.04, 0.03)] * 2, seg=6)
    for s in (1, -1):
        for tip, r in ((V((s * 0.14, 0, 0.19)), 0.016), (V((s * 0.1, 0, 0.25)), 0.013), (V((s * 0.16, 0, 0.12)), 0.012),
                       (V((s * 0.07, 0, 0.06)), 0.01)):
            rk.tube(bm, [V((s * 0.02, 0, 0.12)), tip], [(r, r * 0.8), (0.002, 0.002)], ref=V((0, 0, 1)), seg=4)


def frost_grip(bm):
    rk.tube(bm, [V((0, 0, -0.1)), V((0, 0, 0.1))], [(0.02, 0.02)] * 2, seg=6)
    for k in range(4):                                                     # a twisting wrap
        z = -0.08 + k * 0.05
        rk.tube(bm, [V((0, 0, z)), V((0, 0, z + 0.015))], [(0.024, 0.024)] * 2, seg=6)


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials(COLORS, roughness=0.5)
os.makedirs(OUT, exist_ok=True)
build("sword_runeblade", [("Wrap", rune_wrap), ("Dark", rune_blade), ("Gold", rune_gold), ("Rune", rune_gem), ("Rune", runes)])
build("sword_frost", [("FrostWrap", frost_grip), ("Frost", frost_guard), ("Crystal", frost_blade)])
