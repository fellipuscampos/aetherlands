"""
Equipment generators: armor, helmet, belt, shield, sword. Every piece is
treated as RIGID (single bone, 100% weight) per the brief -- low-poly
armor does not need organic deformation. Shield/sword geometry stays a
literal hexagon / simple prism-and-wedge, never over-segmented.
"""

from geometry import primitives as prim
from rig import bones as B


def build_armor(measurements, style, mat_lib):
    """Cuirass + pauldrons + belt. Returns (object, bone_name) tuples."""
    m = measurements
    parts = []

    cuirass = prim.box(
        "Cuirass",
        (m.torso_width * 1.10, m.torso_depth * 1.12, (m.z_chest_top - m.z_spine_top) * 1.02),
        (0, 0, (m.z_spine_top + m.z_chest_top) / 2.0),
    )
    prim.assign_material(cuirass, mat_lib.get_metal())
    parts.append((cuirass, B.CHEST))

    belt = prim.box(
        "Belt",
        (m.pelvis_width * 1.08, m.pelvis_depth * 1.1, (m.z_pelvis_top - m.z_hip) * 0.28),
        (0, 0, m.z_pelvis_top - (m.z_pelvis_top - m.z_hip) * 0.2),
    )
    prim.assign_material(belt, mat_lib.get("leather"))
    parts.append((belt, B.PELVIS))

    buckle = prim.box(
        "BeltBuckle",
        (m.pelvis_width * 0.22, m.pelvis_depth * 0.18, (m.z_pelvis_top - m.z_hip) * 0.3),
        (0, m.pelvis_depth * 0.55, m.z_pelvis_top - (m.z_pelvis_top - m.z_hip) * 0.2),
    )
    prim.assign_material(buckle, mat_lib.get_metal())
    parts.append((buckle, B.PELVIS))

    for s in (-1, 1):
        shoulder = m.shoulder_pos(s)
        pad = prim.cone(
            f"Pauldron.{'L' if s < 0 else 'R'}",
            m.upper_arm_radius * 1.55, m.upper_arm_radius * 1.15,
            m.len_upper_arm * 0.32, style.cylinder_segments,
            (shoulder[0], shoulder[1], shoulder[2] + m.len_upper_arm * 0.05),
            direction=-1,
        )
        prim.assign_material(pad, mat_lib.get_metal())
        parts.append((pad, B.side(B.UPPER_ARM, s)))

    return parts


def build_helmet(measurements, style, mat_lib):
    m = measurements
    parts = []

    dome = prim.uv_sphere(
        "HelmetDome",
        (m.head_width * 0.58, m.head_depth * 0.58, m.head_height * 0.56),
        style.sphere_segments, style.sphere_rings,
        (0, 0, m.z_head_center + m.head_height * 0.06),
    )
    prim.assign_material(dome, mat_lib.get_metal())
    parts.append((dome, B.HEAD))

    rim = prim.cone(
        "HelmetRim", m.head_width * 0.60, m.head_width * 0.62, m.head_height * 0.10,
        style.cylinder_segments, (0, 0, m.z_head_center - m.head_height * 0.06),
    )
    prim.assign_material(rim, mat_lib.get_metal(dark=True))
    parts.append((rim, B.HEAD))

    nose_guard = prim.box(
        "NoseGuard",
        (m.head_width * 0.10, m.head_depth * 0.22, m.head_height * 0.5),
        (0, m.head_depth * 0.42, m.z_head_center - m.head_height * 0.1),
    )
    prim.assign_material(nose_guard, mat_lib.get_metal(dark=True))
    parts.append((nose_guard, B.HEAD))

    return parts


def build_shield(measurements, style, mat_lib):
    """A literal hexagon: two stacked hex prisms (metal rim + faction field),
    6-segment prism = exactly a hexagon, no extra segments."""
    m = measurements
    parts = []
    wrist = m.wrist_pos(-1)
    radius = m.head_width * 1.35
    center = (wrist[0] - m.hand_width * 0.7, wrist[1], wrist[2] - m.len_hand * 0.3)

    rim = prim.hex_prism("ShieldRim", radius, m.hand_depth * 0.9, center, segments=style.hex_segments)
    prim.assign_material(rim, mat_lib.get_metal())
    parts.append((rim, B.side(B.HAND, -1)))

    field = prim.hex_prism(
        "ShieldField", radius * 0.8, m.hand_depth * 0.95,
        (center[0] - m.hand_depth * 0.05, center[1], center[2]),
        segments=style.hex_segments,
    )
    prim.assign_material(field, mat_lib.get("shield_field", faction=True))
    parts.append((field, B.side(B.HAND, -1)))

    return parts


def build_sword(measurements, style, mat_lib):
    """Simple straight short sword, held blade-up at rest."""
    m = measurements
    parts = []
    wrist = m.wrist_pos(1)
    grip_len = m.len_hand * 1.1
    guard_z = wrist[2] + grip_len

    handle = prim.cone(
        "SwordHandle", m.hand_width * 0.16, m.hand_width * 0.16, grip_len,
        style.cylinder_segments, wrist,
    )
    prim.assign_material(handle, mat_lib.get("leather"))
    parts.append((handle, B.side(B.HAND, 1)))

    guard = prim.box(
        "SwordGuard", (m.hand_width * 0.9, m.hand_depth * 0.5, m.hand_depth * 0.22),
        (wrist[0], wrist[1], guard_z),
    )
    prim.assign_material(guard, mat_lib.get_metal())
    parts.append((guard, B.side(B.HAND, 1)))

    blade_len = m.len_upper_arm * 1.15
    blade = prim.wedge(
        "SwordBlade", (m.hand_width * 0.32, m.hand_depth * 0.14, blade_len),
        (wrist[0], wrist[1], guard_z + blade_len / 2.0), taper=0.12,
    )
    prim.assign_material(blade, mat_lib.get_metal())
    parts.append((blade, B.side(B.HAND, 1)))

    pommel = prim.uv_sphere(
        "SwordPommel", m.hand_width * 0.16, 6, 4, (wrist[0], wrist[1], wrist[2] - m.hand_width * 0.1),
    )
    prim.assign_material(pommel, mat_lib.get_metal(dark=True))
    parts.append((pommel, B.side(B.HAND, 1)))

    return parts
