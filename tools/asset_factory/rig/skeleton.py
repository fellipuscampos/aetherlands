"""
Builds the humanoid armature directly from Measurements, so every bone
head/tail matches the geometry exactly -- no manual re-alignment.
"""

import bpy
from mathutils import Vector

from rig import bones as B


def _chain(edit_bones, name, head, tail, parent_name):
    b = edit_bones.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    b.use_connect = False
    if parent_name:
        b.parent = edit_bones[parent_name]
    return b


def build_skeleton(measurements, name="Armature"):
    m = measurements
    arm_data = bpy.data.armatures.new(name)
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    _chain(eb, B.ROOT, (0, 0, 0), (0, 0, m.z_hip * 0.35), None)
    _chain(eb, B.PELVIS, (0, 0, m.z_hip), (0, 0, m.z_pelvis_top), B.ROOT)
    _chain(eb, B.SPINE, (0, 0, m.z_pelvis_top), (0, 0, m.z_spine_top), B.PELVIS)
    _chain(eb, B.CHEST, (0, 0, m.z_spine_top), (0, 0, m.z_chest_top), B.SPINE)
    _chain(eb, B.NECK, (0, 0, m.z_chest_top), (0, 0, m.z_neck_top), B.CHEST)
    _chain(eb, B.HEAD, (0, 0, m.z_neck_top), (0, 0, m.z_head_top), B.NECK)

    for s in (-1, 1):
        tag = "L" if s < 0 else "R"
        _chain(eb, f"{B.UPPER_ARM}.{tag}", m.shoulder_pos(s), m.elbow_pos(s), B.CHEST)
        _chain(eb, f"{B.LOWER_ARM}.{tag}", m.elbow_pos(s), m.wrist_pos(s), f"{B.UPPER_ARM}.{tag}")
        _chain(eb, f"{B.HAND}.{tag}", m.wrist_pos(s), m.hand_tip_pos(s), f"{B.LOWER_ARM}.{tag}")

        hip = m.hip_pos(s)
        knee = m.knee_pos(s)
        ankle = m.ankle_pos(s)
        toe = (ankle[0], ankle[1] + m.len_foot * 0.85, m.z_ground + m.foot_height * 0.5)
        _chain(eb, f"{B.UPPER_LEG}.{tag}", hip, knee, B.PELVIS)
        _chain(eb, f"{B.LOWER_LEG}.{tag}", knee, ankle, f"{B.UPPER_LEG}.{tag}")
        _chain(eb, f"{B.FOOT}.{tag}", ankle, toe, f"{B.LOWER_LEG}.{tag}")

    bpy.ops.object.mode_set(mode="OBJECT")
    # Euler XYZ is far easier to keyframe by hand than quaternions for a
    # small, fixed set of FK poses (idle/walk/attack/death).
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    return arm_obj
