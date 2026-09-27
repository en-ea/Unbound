"""Authors our own gathering animations on the Quaternius UAL skeleton, so they play on every
character built on it: Chop (a one-handed diagonal axe swing), Mine (an overhead pick strike)
and Gather (crouch, reach down, pick). Poses are set by aiming bones in armature space, so we
don't depend on each bone's local axes. The character faces -Y (Blender), Z is up.

Exported to game/assets/characters/gather_anims.glb (armature + animations only).

Run: tools/blender/blender.exe --background --python tools-src/blender/make_anims.py
"""
import math
import os
import sys
import bpy
from mathutils import Matrix, Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "game", "assets", "quaternius_characters", "UAL1_Standard.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "gather_anims.glb")

arm = rk.load_rig(RIG)
bpy.context.scene.render.fps = 30
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="POSE")
pbs = arm.pose.bones
for pb in pbs:
    pb.rotation_mode = "QUATERNION"


def update():
    bpy.context.view_layer.update()


def reset():
    for pb in pbs:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    update()


def aim(name, direction):
    """Rotate a bone (minimally) so it points along `direction` in armature space."""
    pb = pbs[name]
    cur = pb.matrix.copy()
    y = cur.to_3x3().col[1].normalized()
    q = y.rotation_difference(V(direction).normalized())
    m = (q.to_matrix() @ cur.to_3x3()).to_4x4()
    m.translation = cur.translation
    pb.matrix = m
    update()


def turn(name, axis, degrees):
    """Rotate a bone (and everything below it) about an armature-space axis."""
    pb = pbs[name]
    cur = pb.matrix.copy()
    m = (Matrix.Rotation(math.radians(degrees), 3, axis) @ cur.to_3x3()).to_4x4()
    m.translation = cur.translation
    pb.matrix = m
    update()


def lower_hips(amount):
    pb = pbs["pelvis"]
    m = pb.matrix.copy()
    m.translation.z -= amount
    pb.matrix = m
    update()


def arm_pose(side, upper, fore):
    aim(f"upperarm_{side}", upper)
    aim(f"lowerarm_{side}", fore)
    aim(f"hand_{side}", fore)


def relaxed_left():
    arm_pose("l", (0.25, -0.05, -1), (0.2, -0.45, -1))


def stance():
    """Feet a little apart, knees soft."""
    for s, side in ((1, "l"), (-1, "r")):
        aim(f"thigh_{side}", (s * 0.12, -0.12, -1))
        aim(f"calf_{side}", (0, 0.1, -1))


def pose(spine_twist=0.0, lean=0.0, right=None, left=None, crouch=0.0):
    reset()
    if crouch:
        lower_hips(crouch)
        for s, side in ((1, "l"), (-1, "r")):
            aim(f"thigh_{side}", (s * 0.25, -0.9, -0.55))
            aim(f"calf_{side}", (0, 0.45, -1))
            aim(f"foot_{side}", (0, -1, -0.2))
    else:
        stance()
    if lean:
        turn("spine_01", (1, 0, 0), -lean * 0.4)
        turn("spine_02", (1, 0, 0), -lean * 0.6)
    if spine_twist:
        turn("spine_02", (0, 0, 1), spine_twist * 0.5)
        turn("spine_03", (0, 0, 1), spine_twist * 0.5)
    arm_pose("r", *right)
    if left:
        arm_pose("l", *left)
    else:
        relaxed_left()


def key(frame):
    for pb in pbs:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


READY_R = ((-0.3, -0.35, -1), (-0.1, -1, -0.5))


def make(name, keys):
    if arm.animation_data:
        arm.animation_data.action = None      # start a fresh action; earlier ones live in NLA tracks
    for frame, kwargs in keys:
        pose(**kwargs)
        key(frame)
    action = arm.animation_data.action
    action.name = name
    action.use_fake_user = True
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(keys[0][0]), action)
    arm.animation_data.action = None
    return name


tracks = []
# Chop: wind up over the right shoulder, swing down across the body, recover. Hit at frame 13.
tracks.append(make("Chop", [
    (0, dict(right=READY_R)),
    (8, dict(spine_twist=-35, right=((-0.55, 0.35, 0.75), (-0.05, 0.55, 0.85)))),
    (13, dict(spine_twist=20, lean=15, right=((-0.1, -1, -0.15), (0.15, -0.8, -0.6)))),
    (17, dict(spine_twist=28, lean=12, right=((0.05, -0.75, -0.65), (0.25, -0.35, -0.9)))),
    (28, dict(right=READY_R)),
]))
# Mine: both arms up overhead, strike straight down in front. Hit at frame 13.
tracks.append(make("Mine", [
    (0, dict(right=READY_R, left=((0.2, -0.4, -1), (-0.1, -1, -0.4)))),
    (8, dict(lean=-8, right=((-0.25, 0.25, 1), (0.05, 0.6, 0.8)), left=((0.25, 0.25, 1), (-0.05, 0.6, 0.8)))),
    (13, dict(lean=25, right=((-0.12, -0.9, -0.4), (0.0, -0.55, -0.85)), left=((0.12, -0.9, -0.4), (0.0, -0.55, -0.85)))),
    (17, dict(lean=22, right=((-0.12, -0.8, -0.6), (0.0, -0.4, -0.95)), left=((0.12, -0.8, -0.6), (0.0, -0.4, -0.95)))),
    (28, dict(right=READY_R, left=((0.2, -0.4, -1), (-0.1, -1, -0.4)))),
]))
# Gather: crouch, reach to the ground, pick, stand. Pick at frame 10.
tracks.append(make("Gather", [
    (0, dict(right=READY_R)),
    (7, dict(crouch=0.35, lean=30, right=((-0.15, -0.6, -0.8), (-0.05, -0.5, -0.9)))),
    (10, dict(crouch=0.4, lean=35, right=((-0.1, -0.55, -0.85), (0.0, -0.3, -1)))),
    (14, dict(crouch=0.3, lean=20, right=((-0.25, -0.5, -0.7), (-0.1, 0.3, 1)))),
    (22, dict(right=READY_R)),
]))

bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True)
print("ANIMS written", tracks, OUT)
