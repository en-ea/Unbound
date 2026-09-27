"""Builds our own stylised character ("the wanderer") on the Quaternius UAL skeleton,
so every UAL animation works on it. Flat colours per material, so the game can recolour
parts (skin, hair, tunic, scarf...) to make characters unique.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_wanderer.py
Writes game/assets/characters/wanderer.glb
"""
import math
import os
import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "wanderer.glb")

# Part colours (sRGB). Material names are what the game uses to recolour.
COLORS = {
    "Skin": (0.87, 0.67, 0.52),
    "Hair": (0.24, 0.15, 0.10),
    "Eyes": (0.07, 0.07, 0.09),
    "Tunic": (0.30, 0.38, 0.48),
    "Scarf": (0.76, 0.33, 0.20),
    "Pants": (0.31, 0.27, 0.23),
    "Boots": (0.22, 0.15, 0.10),
    "Belt": (0.42, 0.28, 0.16),
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def make_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    r, g, b = COLORS[name]
    bsdf.inputs["Base Color"].default_value = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1)
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


# --- geometry helpers ----------------------------------------------------------

def tube(bm, points, radii, ref=Vector((1, 0, 0)), seg=12, closed=False, caps=True):
    """Lofts rings along a polyline. radii: (rx, ry) per point, rx along `ref`."""
    rings = []
    n = len(points)
    for i, c in enumerate(points):
        if closed:
            t = (points[(i + 1) % n] - points[i - 1]).normalized()
        else:
            t = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        a = (ref - t * ref.dot(t)).normalized()
        b = t.cross(a)
        rx, ry = radii[i]
        ring = [bm.verts.new(c + a * rx * math.cos(k * math.tau / seg) + b * ry * math.sin(k * math.tau / seg)) for k in range(seg)]
        rings.append(ring)
    last = n if closed else n - 1
    for i in range(last):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for k in range(seg):
            bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k]))
    if caps and not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])


def blob(bm, center, size, segments=16, rings=10, keep=None):
    """A UV sphere scaled to `size`; `keep(v)` can cut parts away (for hair)."""
    geom = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    verts = geom["verts"]
    for v in verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + center
    if keep:
        bmesh.ops.delete(bm, geom=[v for v in verts if not keep(v.co)], context="VERTS")


def ring_path(center, rx, ry, count=14):
    return [center + Vector((rx * math.cos(k * math.tau / count), ry * math.sin(k * math.tau / count), 0)) for k in range(count)]


# --- skin weights -------------------------------------------------------------

def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def weights_by_distance(bones, power=4.0, top=3):
    def fn(p):
        w = {}
        for name in bones:
            head, tail = BONES[name]
            w[name] = 1.0 / max(seg_dist(p, head, tail), 0.01) ** power
        best = sorted(w.items(), key=lambda kv: -kv[1])[:top]
        s = sum(v for _, v in best)
        return {k: v / s for k, v in best}
    return fn


def fixed(bone):
    return lambda p: {bone: 1.0}


def skirt_weights(p):
    # The tunic's lower hem follows the hips, with a little pull from the nearer leg.
    side = "thigh_l" if p.x > 0 else "thigh_r"
    leg = max(0.0, min(0.35, (0.95 - p.z) * 1.6))
    upper = weights_by_distance(["pelvis", "spine_01", "spine_02", "spine_03"])(p)
    out = {k: v * (1 - leg) for k, v in upper.items()}
    out[side] = out.get(side, 0) + leg
    return out


def build_part(arm, name, material, weight_fn, builder, smooth=True):
    bm = bmesh.new()
    builder(bm)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.materials.append(MATERIALS[material])
    obj = bpy.data.objects.new("W_" + name, mesh)   # prefix: must not clash with bone names
    bpy.context.collection.objects.link(obj)
    groups = {}
    for v in mesh.vertices:
        for bone, w in weight_fn(v.co).items():
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


# --- the character ----------------------------------------------------------------

def build(arm):
    V = Vector
    parts = []
    # Head: a little bigger than real for a stylised read from the high camera.
    parts.append(build_part(arm, "Head", "Skin", fixed("Head"),
        lambda bm: blob(bm, V((0, -0.01, 1.675)), (0.118, 0.125, 0.14))))
    for x in (0.046, -0.046):
        parts.append(build_part(arm, "Eye", "Eyes", fixed("Head"),
            lambda bm, x=x: blob(bm, V((x, -0.126, 1.68)), (0.02, 0.012, 0.028), 10, 6)))
    parts.append(build_part(arm, "Hair", "Hair", fixed("Head"),
        lambda bm: blob(bm, V((0, 0.0, 1.69)), (0.128, 0.137, 0.15), 18, 12,
            keep=lambda p: p.z > 1.70 or (p.y > -0.03 and p.z > 1.58) or (p.y > -0.1 and p.z > 1.665))))
    parts.append(build_part(arm, "Neck", "Skin", weights_by_distance(["spine_03", "neck_01", "Head"]),
        lambda bm: tube(bm, [V((0, 0.005, 1.46)), V((0, 0.0, 1.6))], [(0.05, 0.05)] * 2, seg=10)))
    # Tunic: shoulders to a hem just above the knee.
    torso_pts = [V((0, 0.02, z)) for z in (0.74, 0.86, 0.97, 1.08, 1.22, 1.35, 1.45, 1.51)]
    torso_r = [(0.23, 0.19), (0.215, 0.17), (0.19, 0.145), (0.17, 0.13), (0.185, 0.14), (0.2, 0.145), (0.185, 0.13), (0.1, 0.09)]
    parts.append(build_part(arm, "Tunic", "Tunic",
        lambda p: skirt_weights(p) if p.z < 0.97 else weights_by_distance(["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"])(p),
        lambda bm: tube(bm, torso_pts, torso_r, seg=16)))
    parts.append(build_part(arm, "Belt", "Belt", weights_by_distance(["pelvis", "spine_01"]),
        lambda bm: tube(bm, ring_path(V((0, 0.02, 1.02)), 0.18, 0.14), [(0.03, 0.022)] * 14, ref=V((0, 0, 1)), seg=6, closed=True), smooth=False))
    # Scarf: a thick wrap round the neck and a tail down the back (the back is +Y).
    parts.append(build_part(arm, "Scarf", "Scarf", weights_by_distance(["spine_03", "neck_01"]),
        lambda bm: tube(bm, ring_path(V((0, 0.01, 1.52)), 0.105, 0.1), [(0.05, 0.035)] * 14, ref=V((0, 0, 1)), seg=8, closed=True)))
    tail_pts = [V((0.03, 0.1, 1.5)), V((0.05, 0.16, 1.38)), V((0.06, 0.18, 1.24)), V((0.07, 0.19, 1.1))]
    parts.append(build_part(arm, "ScarfTail", "Scarf", weights_by_distance(["spine_03", "spine_02"], top=2),
        lambda bm: tube(bm, tail_pts, [(0.065, 0.018), (0.06, 0.016), (0.055, 0.015), (0.05, 0.014)], ref=V((1, 0, 0)), seg=8)))
    for s, side in ((1, "l"), (-1, "r")):
        y = 0.066
        arm_pts = [V((s * x, y, 1.441)) for x in (0.15, 0.3, 0.466, 0.6, 0.73)]
        parts.append(build_part(arm, "Sleeve_" + side, "Tunic",
            weights_by_distance([f"clavicle_{side}", f"upperarm_{side}", f"lowerarm_{side}", f"hand_{side}"], top=2),
            lambda bm, pts=arm_pts: tube(bm, pts, [(0.07, 0.07), (0.062, 0.062), (0.055, 0.055), (0.052, 0.052), (0.048, 0.048)], ref=V((0, 0, 1)), seg=10)))
        parts.append(build_part(arm, "Hand_" + side, "Skin", fixed(f"hand_{side}"),
            lambda bm, s=s: blob(bm, V((s * 0.8, 0.066, 1.438)), (0.07, 0.045, 0.055), 10, 8)))
        x = s * 0.089
        parts.append(build_part(arm, "Leg_" + side, "Pants", weights_by_distance(["pelvis", f"thigh_{side}", f"calf_{side}"], top=2),
            lambda bm, x=x: tube(bm, [V((x, 0.0, 0.95)), V((x, 0.0, 0.53)), V((x, 0.02, 0.22))], [(0.105, 0.105), (0.08, 0.08), (0.066, 0.066)], seg=10)))
        boot_pts = [V((x, 0.03, 0.3)), V((x, 0.03, 0.13)), V((x, -0.02, 0.055)), V((x, -0.13, 0.045)), V((x, -0.21, 0.04))]
        parts.append(build_part(arm, "Boot_" + side, "Boots", weights_by_distance([f"calf_{side}", f"foot_{side}", f"ball_{side}"], top=2),
            lambda bm, pts=boot_pts: tube(bm, pts, [(0.068, 0.068), (0.07, 0.075), (0.072, 0.08), (0.066, 0.05), (0.058, 0.04)], ref=V((1, 0, 0)), seg=10), smooth=False))
    return parts


# --- main -----------------------------------------------------------------------

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=RIG)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
if arm.animation_data:
    arm.animation_data_clear()
BONES = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
MATERIALS = {name: make_material(name) for name in COLORS}
parts = build(arm)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)
print("WANDERER parts", len(parts), "tris", tris)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for o in parts:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
    export_animations=False, export_skins=True, export_apply=False)
print("WANDERER written", OUT)
