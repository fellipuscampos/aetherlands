"""
Body-part mesh generators. Each function builds ONE small mesh object,
tags it with a vertex group named exactly after the bone that should
drive it (rigid skin -- see rig/skinning.py), and assigns its material.
character/builder.py joins everything into a single mesh at the end.
"""

from geometry import primitives as prim
from rig import bones as B


def build_body_parts(measurements, style, mat_lib):
    """Returns a list of (object, bone_name) tuples for the bare body
    (no equipment)."""
    m = measurements
    parts = []

    # Pelvis
    pelvis = prim.box(
        "Pelvis",
        (m.pelvis_width, m.pelvis_depth, m.z_pelvis_top - m.z_hip),
        (0, 0, (m.z_hip + m.z_pelvis_top) / 2.0),
    )
    prim.assign_material(pelvis, mat_lib.get("cloth", faction=True))
    parts.append((pelvis, B.PELVIS))

    # Spine (lower torso, waist -> narrower)
    spine_w = (m.pelvis_width + m.torso_width) / 2.0 * 0.92
    spine = prim.box(
        "Spine",
        (spine_w, m.torso_depth * 0.95, m.z_spine_top - m.z_pelvis_top),
        (0, 0, (m.z_pelvis_top + m.z_spine_top) / 2.0),
    )
    prim.assign_material(spine, mat_lib.get("cloth", faction=True))
    parts.append((spine, B.SPINE))

    # Chest (upper torso, full shoulder width)
    chest = prim.box(
        "Chest",
        (m.torso_width, m.torso_depth, m.z_chest_top - m.z_spine_top),
        (0, 0, (m.z_spine_top + m.z_chest_top) / 2.0),
    )
    prim.assign_material(chest, mat_lib.get("cloth", faction=True))
    parts.append((chest, B.CHEST))

    # Neck
    neck_radius = m.head_width * 0.28
    neck = prim.cone(
        "Neck", neck_radius, neck_radius * 0.92, m.z_neck_top - m.z_chest_top,
        style.cylinder_segments, (0, 0, m.z_chest_top),
    )
    prim.assign_material(neck, mat_lib.get("skin"))
    parts.append((neck, B.NECK))

    # Head (squashed low-poly sphere -> chunky, not perfectly round)
    head = prim.uv_sphere(
        "Head",
        (m.head_width / 2.0, m.head_depth / 2.0, m.head_height / 2.0),
        style.sphere_segments, style.sphere_rings,
        (0, 0, m.z_head_center),
    )
    prim.assign_material(head, mat_lib.get("skin"))
    parts.append((head, B.HEAD))

    # Arms + hands
    for s in (-1, 1):
        shoulder = m.shoulder_pos(s)
        elbow = m.elbow_pos(s)
        wrist = m.wrist_pos(s)

        upper_arm = prim.cone(
            f"UpperArm.{'L' if s < 0 else 'R'}",
            m.upper_arm_radius, m.upper_arm_radius * 0.9, m.len_upper_arm,
            style.cylinder_segments, shoulder, cap_ends=True, direction=-1,
        )
        prim.assign_material(upper_arm, mat_lib.get("skin"))
        parts.append((upper_arm, B.side(B.UPPER_ARM, s)))

        lower_arm = prim.cone(
            f"LowerArm.{'L' if s < 0 else 'R'}",
            m.lower_arm_radius, m.lower_arm_radius * 0.85, m.len_lower_arm,
            style.cylinder_segments, elbow, cap_ends=True, direction=-1,
        )
        prim.assign_material(lower_arm, mat_lib.get("skin"))
        parts.append((lower_arm, B.side(B.LOWER_ARM, s)))

        hand = prim.box(
            f"Hand.{'L' if s < 0 else 'R'}",
            (m.hand_width, m.hand_depth, m.len_hand),
            (wrist[0], wrist[1], wrist[2] - m.len_hand / 2.0),
        )
        prim.assign_material(hand, mat_lib.get("skin"))
        parts.append((hand, B.side(B.HAND, s)))

    # Legs + feet
    for s in (-1, 1):
        hip = m.hip_pos(s)
        knee = m.knee_pos(s)
        ankle = m.ankle_pos(s)

        upper_leg = prim.cone(
            f"UpperLeg.{'L' if s < 0 else 'R'}",
            m.upper_leg_radius, m.upper_leg_radius * 0.9, m.len_upper_leg,
            style.cylinder_segments, hip, cap_ends=True, direction=-1,
        )
        prim.assign_material(upper_leg, mat_lib.get("leather"))
        parts.append((upper_leg, B.side(B.UPPER_LEG, s)))

        lower_leg = prim.cone(
            f"LowerLeg.{'L' if s < 0 else 'R'}",
            m.lower_leg_radius, m.lower_leg_radius * 0.85, m.len_lower_leg,
            style.cylinder_segments, knee, cap_ends=True, direction=-1,
        )
        prim.assign_material(lower_leg, mat_lib.get("leather"))
        parts.append((lower_leg, B.side(B.LOWER_LEG, s)))

        foot = prim.box(
            f"Foot.{'L' if s < 0 else 'R'}",
            (m.foot_width, m.len_foot, m.foot_height),
            (ankle[0], ankle[1] + m.len_foot * 0.28, m.z_ground + m.foot_height / 2.0),
        )
        prim.assign_material(foot, mat_lib.get("leather"))
        parts.append((foot, B.side(B.FOOT, s)))

    return parts
