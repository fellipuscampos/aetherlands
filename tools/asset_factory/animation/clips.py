"""
Four FK animation clips: Idle, Walk, Attack, Death. Each becomes its own
Blender Action (name preserved through export -> one named glTF animation
per action), keyframed on pose-bone rotation_euler/location only -- no
IK, no shape keys, nothing that wouldn't survive a glTF round-trip into
Godot's AnimationPlayer.

Poses are intentionally a bit exaggerated/readable (per the brief: this
is a top-down game, animation must communicate at a glance).
"""

import math

import bpy

FPS = 30


def _rad(d):
    return math.radians(d)


def _new_action(armature_obj, name):
    if armature_obj.animation_data is None:
        armature_obj.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    armature_obj.animation_data.action = action
    return action


def _key_rot(armature_obj, bone, frame, x=0.0, y=0.0, z=0.0):
    pb = armature_obj.pose.bones[bone]
    pb.rotation_euler = (_rad(x), _rad(y), _rad(z))
    pb.keyframe_insert(data_path="rotation_euler", frame=frame)


def _key_loc(armature_obj, bone, frame, loc):
    pb = armature_obj.pose.bones[bone]
    pb.location = loc
    pb.keyframe_insert(data_path="location", frame=frame)


def _reset_pose(armature_obj):
    for pb in armature_obj.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)


def _set_interpolation(action, mode="LINEAR"):
    for fcurve in action.fcurves:
        for kp in fcurve.keyframe_points:
            kp.interpolation = mode



# A held staff planted on the ground for support (Colonizador) shouldn't
# swing with the idle breathing sway or the walk's counter-swing -- a
# real person leaning on a walking stick keeps that arm still, the stick
# would lift off the ground every stride otherwise. Same fixed forward-
# and-bent pose reused by both build_idle/build_walk below, applied AFTER
# (so it overrides) the normal per-side sway/swing keyframe on that one
# arm -- see arm_x sign note in build_attack: POSITIVE UpperArm.R
# x-rotation swings a hand-held prop's GRIP end forward, which is what a
# planted staff needs (the grip, not the far tip, out in front).
#
# Kept deliberately SMALL: equipment_blocky.build_staff_parts sizes the
# staff so its tip touches the ground directly under the hand's REST
# position (arm hanging straight down, no rotation at all) -- a big lean
# angle here would swing that same hand up and away from its rest spot
# along the shoulder's rotation arc, lifting the tip off the ground. A
# small angle reads as "hand resting forward on the staff" while the
# hand stays close enough to its rest height/position for the tip to
# still read as planted.
_STAFF_LEAN_UPPER_X = 14.0
_STAFF_LEAN_LOWER_X = 8.0


def _apply_staff_lean(armature_obj, frame, hold_tag):
    if not hold_tag:
        return
    z = -3.0 if hold_tag == "R" else 3.0
    _key_rot(armature_obj, f"UpperArm.{hold_tag}", frame, x=_STAFF_LEAN_UPPER_X, z=z)
    _key_rot(armature_obj, f"LowerArm.{hold_tag}", frame, x=_STAFF_LEAN_LOWER_X)


def build_idle(armature_obj, staff_side=0):
    _reset_pose(armature_obj)
    action = _new_action(armature_obj, "Idle")
    length = int(2.2 * FPS)
    hold_tag = "R" if staff_side > 0 else ("L" if staff_side < 0 else None)

    def pose(frame, breathe):
        _key_rot(armature_obj, "Chest", frame, x=-2.0 * breathe)
        _key_rot(armature_obj, "Spine", frame, x=-1.0 * breathe)
        _key_rot(armature_obj, "Head", frame, x=0.6 * breathe)
        _key_rot(armature_obj, "UpperArm.L", frame, x=2.0 * breathe, z=3.0)
        _key_rot(armature_obj, "UpperArm.R", frame, x=2.0 * breathe, z=-3.0)
        _key_loc(armature_obj, "Root", frame, (0, 0, 0.004 * breathe))
        _apply_staff_lean(armature_obj, frame, hold_tag)

    pose(1, 0.0)
    pose(length * 0.5, 1.0)
    pose(length, 0.0)

    action.frame_range = (1, length)
    _set_interpolation(action, "BEZIER")
    return action


def build_walk(armature_obj, staff_side=0):
    _reset_pose(armature_obj)
    action = _new_action(armature_obj, "Walk")
    length = int(0.9 * FPS)
    half = length / 2.0
    hold_tag = "R" if staff_side > 0 else ("L" if staff_side < 0 else None)

    def pose(frame, swing, bob):
        # opposite arm/leg swing, classic readable walk
        _key_rot(armature_obj, "UpperLeg.L", frame, x=swing)
        _key_rot(armature_obj, "UpperLeg.R", frame, x=-swing)
        _key_rot(armature_obj, "LowerLeg.L", frame, x=max(0.0, -swing) * 0.9)
        _key_rot(armature_obj, "LowerLeg.R", frame, x=max(0.0, swing) * 0.9)
        _key_rot(armature_obj, "UpperArm.L", frame, x=-swing * 0.8, z=3.0)
        _key_rot(armature_obj, "UpperArm.R", frame, x=swing * 0.8, z=-3.0)
        _key_rot(armature_obj, "Chest", frame, y=swing * 0.12)
        _key_rot(armature_obj, "Pelvis", frame, y=swing * 0.08)
        _key_loc(armature_obj, "Root", frame, (0, 0, abs(bob) * 0.03))
        _apply_staff_lean(armature_obj, frame, hold_tag)

    pose(1, 0.0, 0.0)
    pose(1 + half * 0.5, 22.0, 1.0)
    pose(1 + half, 0.0, 0.0)
    pose(1 + half * 1.5, -22.0, 1.0)
    pose(1 + length, 0.0, 0.0)

    action.frame_range = (1, 1 + length)
    _set_interpolation(action, "LINEAR")
    return action


def build_attack(armature_obj):
    _reset_pose(armature_obj)
    action = _new_action(armature_obj, "Attack")

    f_start, f_windup, f_strike, f_follow, f_end = 1, 8, 14, 20, 26

    def pose(frame, arm_x, arm_z, chest_y, elbow_x):
        _key_rot(armature_obj, "UpperArm.R", frame, x=arm_x, z=arm_z - 3.0)
        _key_rot(armature_obj, "LowerArm.R", frame, x=elbow_x)
        _key_rot(armature_obj, "Chest", frame, y=chest_y)
        _key_rot(armature_obj, "Spine", frame, y=chest_y * 0.5)
        _key_rot(armature_obj, "UpperLeg.L", frame, x=-chest_y * 0.3)
        _key_rot(armature_obj, "UpperLeg.R", frame, x=chest_y * 0.3)

    # arm_x sign here is NOT "forward"/"back" the way it reads intuitively --
    # measured directly against the actual rig (a long held prop rigidly
    # bound to Hand.R, its tip tracked through posed vertex positions):
    # negative UpperArm.R x-rotation swings a hand-held prop's far end
    # FORWARD (in front of the body), positive swings it BEHIND. The
    # original values here had this backwards -- windup=-75/strike=+55
    # actually swung the weapon's business end (blade/axe-head, far from
    # the grip) behind the character at "windup" and, worse, pushed only
    # the near/butt end forward at "strike" while the blade stayed behind
    # him ("ataca com o cabo de baixo" bug). Flipping every arm_x sign
    # below fixes it: windup cocks the far end back, strike swings it
    # through to the front.
    pose(f_start, -10.0, 0.0, 0.0, 10.0)
    pose(f_windup, 75.0, 25.0, -18.0, 40.0)
    pose(f_strike, -55.0, -35.0, 22.0, 5.0)
    pose(f_follow, -25.0, -10.0, 8.0, 12.0)
    pose(f_end, -10.0, 0.0, 0.0, 10.0)

    action.frame_range = (f_start, f_end)
    _set_interpolation(action, "BEZIER")
    for fcurve in action.fcurves:
        for kp in fcurve.keyframe_points:
            if abs(kp.co[0] - f_strike) < 0.5:
                kp.interpolation = "LINEAR"  # snappy impact, no ease into the hit
    return action


def build_death(armature_obj):
    _reset_pose(armature_obj)
    action = _new_action(armature_obj, "Death")

    f_start, f_stagger, f_fall, f_rest = 1, 6, 20, 30

    def pose(frame, root_x, root_z, chest_x, leg_x, arm_x, arm_z):
        _key_rot(armature_obj, "Root", frame, x=root_x)
        _key_loc(armature_obj, "Root", frame, (0, 0, root_z))
        _key_rot(armature_obj, "Chest", frame, x=chest_x)
        _key_rot(armature_obj, "Spine", frame, x=chest_x * 0.6)
        _key_rot(armature_obj, "UpperLeg.L", frame, x=leg_x)
        _key_rot(armature_obj, "UpperLeg.R", frame, x=leg_x * 0.8)
        _key_rot(armature_obj, "UpperArm.L", frame, x=arm_x, z=arm_z)
        _key_rot(armature_obj, "UpperArm.R", frame, x=arm_x, z=-arm_z)
        _key_rot(armature_obj, "Head", frame, x=root_x * 0.3)

    pose(f_start, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0)
    pose(f_stagger, -12.0, 0.01, -8.0, -5.0, -15.0, 20.0)
    pose(f_fall, 92.0, -0.05, 10.0, -20.0, -35.0, 55.0)
    pose(f_rest, 92.0, -0.05, 10.0, -20.0, -35.0, 55.0)

    action.frame_range = (f_start, f_rest)
    _set_interpolation(action, "BEZIER")
    return action


def build_all_clips(armature_obj, staff_side=0):
    """`staff_side`: 1/-1 to plant Idle/Walk's held-staff arm (R/L) in a
    fixed forward lean instead of swinging it (see _apply_staff_lean) --
    0 (default) is every character built before this parameter existed."""
    clips = [
        build_idle(armature_obj, staff_side=staff_side),
        build_walk(armature_obj, staff_side=staff_side),
        build_attack(armature_obj),
        build_death(armature_obj),
    ]
    _reset_pose(armature_obj)
    armature_obj.animation_data.action = None
    return clips
