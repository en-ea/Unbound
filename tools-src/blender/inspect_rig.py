import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[-1])
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
print("ARM", arm.name, tuple(round(v,3) for v in arm.matrix_world.to_euler()), tuple(round(v,3) for v in arm.scale))
for b in arm.data.bones:
    h = arm.matrix_world @ b.head_local; t = arm.matrix_world @ b.tail_local
    print("BONE", b.name, b.parent.name if b.parent else "-", tuple(round(v,3) for v in h), tuple(round(v,3) for v in t))
for o in bpy.data.objects: print("OBJ", o.name, o.type, o.parent.name if o.parent else "-")
