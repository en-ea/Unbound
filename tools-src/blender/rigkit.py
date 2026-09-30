"""Shared helpers for building skinned characters on the Quaternius UAL skeleton in Blender.
Mesh object names must not match bone names (the glTF exporter would rename the bone).
"""
import math
import random
import bpy
import bmesh
from mathutils import Euler, Vector

BONES = {}       # bone name -> (head, tail) in world space
MATERIALS = {}   # material name -> bpy material


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def load_rig(path):
    """Imports the UAL rig, drops its meshes and animations, returns the armature."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    if arm.animation_data:
        arm.animation_data_clear()
    BONES.clear()
    BONES.update({b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones})
    return arm


def make_materials(colors, roughness=0.85):
    for name, (r, g, b) in colors.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1)
        bsdf.inputs["Roughness"].default_value = roughness
        MATERIALS[name] = mat


# --- shapes ------------------------------------------------------------------------

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
        rings.append([bm.verts.new(c + a * rx * math.cos(k * math.tau / seg) + b * ry * math.sin(k * math.tau / seg))
                      for k in range(seg)])
    last = n if closed else n - 1
    for i in range(last):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for k in range(seg):
            bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k]))
    if caps and not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])


def blob(bm, center, size, segments=16, rings=10, keep=None):
    """A UV sphere scaled to `size`; `keep(p)` can cut parts away (hair, hoods)."""
    geom = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    verts = geom["verts"]
    for v in verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + center
    if keep:
        bmesh.ops.delete(bm, geom=[v for v in verts if not keep(v.co)], context="VERTS")


def boulder(bm, c, size, seed, rot=(0, 0, 0), round=0.35, chips=3, jitter=0.04, top=1.0, n=44):
    """A chipped, bevelled stone: points spread over a rounded box (`round` 0 = box, 1 = ball), a few
    corners sliced off flat (`chips`), wrapped in a convex hull, so the faces come in uneven sizes like
    cut rock. Sized `size` (full width, depth, height), turned by `rot` degrees; `top` < 1 narrows the top."""
    rnd = random.Random(seed * 7919 + 13)
    golden = math.pi * (3.0 - math.sqrt(5.0))
    pts = []
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = golden * i + rnd.uniform(-0.3, 0.3)
        d = Vector((r * math.cos(a), r * math.sin(a), z))
        cube = d / max(abs(d.x), abs(d.y), abs(d.z))
        pts.append(cube.lerp(d, round) * (1.0 + rnd.uniform(-jitter, jitter * 0.4)))
    for _ in range(chips):                       # slice a corner or an edge off flat
        nrm = Vector((rnd.choice((-1, 1)), rnd.choice((-1, 1)), rnd.choice((-1, 1))))
        if rnd.random() < 0.4:
            nrm[rnd.randrange(3)] = 0.0
        nrm = (nrm + Vector(tuple(rnd.uniform(-0.4, 0.4) for _ in range(3)))).normalized()
        h = max(p.dot(nrm) for p in pts) * rnd.uniform(0.8, 0.9)
        pts = [p - nrm * (p.dot(nrm) - h) if p.dot(nrm) > h else p for p in pts]
    turn = Euler([math.radians(a) for a in rot]).to_matrix()
    verts = []
    for p in pts:
        k = 1.0 + (top - 1.0) * max(p.z, 0.0)
        verts.append(bm.verts.new(c + turn @ Vector((p.x * size[0] * 0.5 * k, p.y * size[1] * 0.5 * k, p.z * size[2] * 0.5))))
    res = bmesh.ops.convex_hull(bm, input=verts, use_existing_faces=False)
    loose = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace) and g.is_valid]
    edges = list({e for f in faces for e in f.edges})
    fverts = list({v for f in faces for v in f.verts})
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4.0), verts=fverts, edges=edges)


def ring_path(center, rx, ry, count=14):
    return [center + Vector((rx * math.cos(k * math.tau / count), ry * math.sin(k * math.tau / count), 0))
            for k in range(count)]


# --- skin weights -------------------------------------------------------------------

def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def weights_by_distance(bones, power=4.0, top=3):
    def fn(p):
        w = {name: 1.0 / max(seg_dist(p, *BONES[name]), 0.01) ** power for name in bones}
        best = sorted(w.items(), key=lambda kv: -kv[1])[:top]
        s = sum(v for _, v in best)
        return {k: v / s for k, v in best}
    return fn


def fixed(bone):
    return lambda p: {bone: 1.0}


# --- objects ----------------------------------------------------------------------------

def build_part(arm, name, material, weight_fn, builder, smooth=True, recalc=True, outward=None, shade_var=0.0, seed=0):
    """Builds one skinned mesh object. `outward` orients open surfaces (decals) instead of recalc.
    Each face gets a grey shade factor in its UVs (1 +- shade_var) that the game multiplies with
    the part's colour, for a hand-painted faceted look."""
    import random
    bm = bmesh.new()
    builder(bm)
    rnd = random.Random(sum(ord(c) * (i + 1) for i, c in enumerate(name)) + seed)   # stable per part
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    for f in bm.faces:
        k = 1.0 + rnd.uniform(-shade_var, shade_var * 0.5)
        for loop in f.loops:
            loop[uv].uv = (k, 1.0 - k)
            loop[uv2].uv = (k, 1.0)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if outward is not None:           # a direction, or a function of the face centre giving one
        for f in bm.faces:
            f.normal_update()
            d = outward(f.calc_center_median()) if callable(outward) else outward
            if f.normal.dot(d) < 0:
                f.normal_flip()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.materials.append(MATERIALS[material])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    groups = {}
    for v in mesh.vertices:
        for bone, w in weight_fn(v.co).items():
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")
    obj.parent = arm
    obj.modifiers.new("Armature", "ARMATURE").object = arm
    return obj


def join(objs, name):
    """Merges objects into one (fewer draw calls). Keeps vertex groups and materials."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def join_groups(parts, group_of):
    """Joins parts that share a group name (group_of(obj) -> name or None to keep as is)."""
    groups, out = {}, []
    for o in parts:
        g = group_of(o)
        if g is None:
            out.append(o)
        else:
            groups.setdefault(g, []).append(o)
    for g, objs in groups.items():
        out.append(join(objs, g) if len(objs) > 1 else objs[0])
        out[-1].name = g
    return out


def export(arm, parts, path):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in parts:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True, export_apply=False)


def tri_count(parts):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)


# --- baked light -------------------------------------------------------------------------

def bake_shading(parts, glow_slot="Glow", reach=0.3, rays=32, strength=0.9, shadow=(0.36, 0.38, 0.52),
                 legs=(0.15, 1.1, 0.72), glow=(1.0, 0.42, 0.1), glow_reach=0.22, glow_strength=0.7):
    """Paints soft light into the per-face colours stored in the UVs (see build_part), so the phone gets
    it for free: creases and undersides where rocks meet go dark and cool (`shadow` is the colour at
    full occlusion), the lower body a little darker (`legs` = z where it starts, z where it ends, darkest
    factor), and stone next to glowing parts picks up a warm glow. Runs on the rest pose, after joining."""
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree
    solid = [o for o in parts if o.data.materials[0].name != glow_slot]
    lit = [o for o in parts if o.data.materials[0].name == glow_slot]
    verts, polys = [], []
    for o in solid:
        base = len(verts)
        verts += [v.co.copy() for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    bvh = BVHTree.FromPolygons(verts, polys)
    glow_pts = [v.co.copy() for o in lit for v in o.data.vertices]
    kd = KDTree(max(1, len(glow_pts)))
    for i, p in enumerate(glow_pts):
        kd.insert(p, i)
    kd.balance()
    dirs = []                                    # cosine-weighted hemisphere around +Z
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(rays):
        u = (i + 0.5) / rays
        r = math.sqrt(u)
        dirs.append(Vector((r * math.cos(golden * i), r * math.sin(golden * i), math.sqrt(1.0 - u))))
    up = Vector((0, 0, 1))
    for o in solid:
        mesh = o.data
        uv = mesh.uv_layers["UVMap"].data
        uv2 = mesh.uv_layers["UV2"].data
        for poly in mesh.polygons:
            n = poly.normal
            turn = up.rotation_difference(n).to_matrix()
            ray_dirs = [turn @ d for d in dirs]
            for li in poly.loop_indices:
                p = mesh.vertices[mesh.loops[li].vertex_index].co
                origin = p.lerp(poly.center, 0.1) + n * 0.004
                occ = 0.0
                for d in ray_dirs:
                    hit, _, _, dist = bvh.ray_cast(origin, d, reach)
                    if hit is None and d.z < -0.01:          # the ground
                        t = -origin.z / d.z
                        dist = t if 0.0 < t < reach else None
                    if dist is not None:
                        occ += 1.0 - 0.5 * dist / reach
                ao = 1.0 - strength * occ / rays
                t = max(0.0, min(1.0, (p.z - legs[0]) / (legs[1] - legs[0])))
                low = legs[2] + (1.0 - legs[2]) * t * t * (3 - 2 * t)
                warm = 0.0
                if glow_pts:
                    for _, _, dist in kd.find_range(p, glow_reach):
                        warm += (1.0 - dist / glow_reach) ** 2 * 0.25
                warm = min(warm, 1.0) * glow_strength
                r, g, b = uv[li].uv.x, 1.0 - uv[li].uv.y, uv2[li].uv.x
                c = [(ch * (s + (1.0 - s) * ao) * low) + gl * warm
                     for ch, s, gl in zip((r, g, b), shadow, glow)]
                uv[li].uv = (c[0], 1.0 - c[1])
                uv2[li].uv = (c[2], 1.0)
