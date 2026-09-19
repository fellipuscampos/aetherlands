"""
V2 equipment: armor plates that follow the torso's own loft profile
(scaled outward) instead of one oversized box, an open-face helmet built
from a partial arc dome, a shield with a raised boss, and a sword with a
diamond-section blade. Still rigid single-bone binding throughout -- the
brief is explicit that equipment shouldn't push the skeleton's
complexity up just to look better.
"""

from geometry import body_v2
from geometry import meshops as mops
from geometry import primitives as prim
from rig import bones as B

_lerp = mops.lerp
_lerp3 = mops.lerp3
_ring_level = mops.ring_level


def build_armor_parts(m, style, mat_lib):
    """Armor rings reuse the body's own torso_width_chain (scaled slightly
    outward) so the plates genuinely follow the torso silhouette computed
    in body_v2.py instead of recomputing their own (and risking drifting
    out of sync with a body-proportion tweak)."""
    sides = style.torso_sides
    metal = mat_lib.get_metal()
    parts = []
    w = body_v2.torso_width_chain(m, style)
    armor_scale = 1.10

    belly_bottom = _ring_level((0, 0, m.z_pelvis_top), w["pelvis_top"][0] * armor_scale,
                                w["pelvis_top"][1] * armor_scale, sides)
    waist_z = _lerp(m.z_pelvis_top, m.z_spine_top, 0.55)
    belly_waist = _ring_level((0, 0, waist_z), w["spine_waist"][0] * armor_scale,
                               w["spine_waist"][1] * armor_scale, sides)
    belly_top = _ring_level((0, 0, m.z_spine_top), w["spine_top"][0] * armor_scale,
                             w["spine_top"][1] * armor_scale, sides)
    belly_plate = mops.build_loft("BellyPlate", [belly_bottom, belly_waist, belly_top],
                                   cap_bottom=True, cap_top=True)
    prim.assign_material(belly_plate, mat_lib.get("leather"))
    parts.append((belly_plate, B.SPINE))

    # Same fix as the body's Chest loft: stay WIDE up to the collarbone
    # line instead of tapering to a point there -- the plate should stop
    # a little short of the neck (cloth collar peeks out above it), not
    # funnel down to meet it.
    chest_armor_scale = 1.14
    chest_bottom = _ring_level((0, 0, m.z_spine_top), w["spine_top"][0] * armor_scale,
                                w["spine_top"][1] * armor_scale, sides)
    chest_mid = _ring_level(
        (0, m.torso_depth * 0.05, _lerp(m.z_spine_top, m.z_chest_top, 0.40)),
        w["chest_lower"][0] * chest_armor_scale, w["chest_lower"][1] * style.chest_projection * chest_armor_scale, sides,
    )
    chest_top = _ring_level(
        (0, m.torso_depth * 0.08, _lerp(m.z_spine_top, m.z_chest_top, 0.88)),
        w["chest_upper"][0] * chest_armor_scale, w["chest_upper"][1] * style.chest_projection * chest_armor_scale, sides,
    )
    chest_plate = mops.build_loft("ChestPlate", [chest_bottom, chest_mid, chest_top],
                                   cap_bottom=True, cap_top=True)
    prim.assign_material(chest_plate, metal)
    parts.append((chest_plate, B.CHEST))

    belt = prim.box(
        "Belt", (m.pelvis_width * 1.10, m.pelvis_depth * 1.12, (m.z_pelvis_top - m.z_hip) * 0.26),
        (0, 0, m.z_pelvis_top - (m.z_pelvis_top - m.z_hip) * 0.16),
    )
    prim.assign_material(belt, mat_lib.get("leather"))
    parts.append((belt, B.PELVIS))

    buckle = prim.box(
        "BeltBuckle", (m.pelvis_width * 0.22, m.pelvis_depth * 0.20, (m.z_pelvis_top - m.z_hip) * 0.30),
        (0, m.pelvis_depth * 0.58, m.z_pelvis_top - (m.z_pelvis_top - m.z_hip) * 0.16),
    )
    prim.assign_material(buckle, metal)
    parts.append((buckle, B.PELVIS))

    for s in (-1, 1):
        tag = "L" if s < 0 else "R"
        elbow = m.elbow_pos(s)
        wrist = m.wrist_pos(s)
        cuff_pos = _lerp3(elbow, wrist, 0.30)
        vambrace = prim.cone(
            f"Vambrace.{tag}", m.lower_arm_radius * 1.28, m.lower_arm_radius * 1.15,
            m.len_lower_arm * 0.24, 6, (cuff_pos[0], cuff_pos[1], cuff_pos[2] - m.len_lower_arm * 0.04),
        )
        prim.assign_material(vambrace, metal)
        parts.append((vambrace, B.side(B.LOWER_ARM, s)))

        knee = m.knee_pos(s)
        kneepad = prim.hex_prism(
            f"Kneepad.{tag}", m.upper_leg_radius * 0.85, m.upper_leg_radius * 0.45,
            (knee[0], knee[1] + m.upper_leg_radius * 0.85, knee[2] + m.upper_leg_radius * 0.1),
            segments=6,
        )
        prim.assign_material(kneepad, metal)
        parts.append((kneepad, B.side(B.UPPER_LEG, s)))

    for s in (-1, 1):
        tag = "L" if s < 0 else "R"
        shoulder = m.shoulder_pos(s)
        rim = _ring_level((shoulder[0], shoulder[1], shoulder[2] + m.len_upper_arm * 0.04),
                           m.upper_arm_radius * 1.55, m.upper_arm_radius * 1.55, 6)
        mid = _ring_level((shoulder[0], shoulder[1], shoulder[2] + m.len_upper_arm * 0.12),
                           m.upper_arm_radius * 1.30, m.upper_arm_radius * 1.30, 6)
        cap = _ring_level((shoulder[0], shoulder[1], shoulder[2] + m.len_upper_arm * 0.17),
                           m.upper_arm_radius * 0.70, m.upper_arm_radius * 0.70, 6)
        pauldron = mops.build_loft(f"Pauldron.{tag}", [rim, mid, cap], cap_bottom=True, cap_top=True)
        prim.assign_material(pauldron, metal)
        parts.append((pauldron, B.side(B.UPPER_ARM, s)))

    return parts


def build_tabard_parts(m, style, mat_lib):
    """A cloth tabard/surcoat hanging from the belt over the tops of the
    thighs, with a jagged handkerchief hem -- this single shape does more
    to sell "a clothed person" than any amount of armor-plate detail,
    since it's the first thing that reads as fabric rather than metal."""
    sides = style.torso_sides
    w = body_v2.torso_width_chain(m, style)
    cloth = mat_lib.get("cloth", faction=True)

    top_z = m.z_pelvis_top - (m.z_pelvis_top - m.z_hip) * 0.05
    top = _ring_level((0, 0, top_z), w["pelvis_top"][0] * 1.02, w["pelvis_top"][1] * 1.02, sides)

    hem_z = m.z_hip - (m.z_hip - m.z_knee) * 0.24
    hem_rx = w["pelvis_top"][0] * 1.30
    hem_ry = w["pelvis_top"][1] * 1.30
    hem_pts = mops.ellipse_points(sides, hem_rx, hem_ry)
    hem_pts = mops.jagged_hem(hem_pts, drop=(m.z_hip - m.z_knee) * 0.10)
    hem = {"z": hem_z, "cx": 0, "cy": 0, "points": hem_pts}

    tabard = mops.build_loft("Tabard", [top, hem], cap_bottom=True, cap_top=False)
    prim.assign_material(tabard, cloth)
    return [(tabard, B.PELVIS)]


def build_sleeve_parts(m, style, mat_lib):
    """Fabric sleeves over the upper arms -- without them the arm reads as
    bare skin with an armor ring floating on it, not a dressed shoulder."""
    sides = style.limb_sides
    cloth = mat_lib.get("cloth", faction=True)
    parts = []
    for s in (-1, 1):
        tag = "L" if s < 0 else "R"
        shoulder = m.shoulder_pos(s)
        elbow = m.elbow_pos(s)
        r = m.upper_arm_radius
        levels = []
        for t, rad in ((0.02, r * 1.30), (0.5, r * 1.18), (0.92, r * 1.00)):
            pos = _lerp3(shoulder, elbow, t)
            levels.append(_ring_level(pos, rad, rad, sides))
        sleeve = mops.build_loft(f"Sleeve.{tag}", levels, cap_bottom=True, cap_top=True)
        prim.assign_material(sleeve, cloth)
        parts.append((sleeve, B.side(B.UPPER_ARM, s)))
    return parts


def build_helmet_parts(m, style, mat_lib):
    metal = mat_lib.get_metal()
    metal_dark = mat_lib.get_metal(dark=True)
    parts = []

    hw, hh, hd = m.head_width, m.head_height, m.head_depth
    brow_z = m.z_head_center - hh * 0.06
    sides = 8

    rim = _ring_level((0, 0, brow_z), hw * 0.60, hd * 0.60, sides)
    rim["points"] = mops.arc_points(sides, hw * 0.60, hd * 0.60, -130, 130)
    bulge = _ring_level((0, -hd * 0.02, brow_z + hh * 0.18), hw * 0.63, hd * 0.60, sides)
    bulge["points"] = mops.arc_points(sides, hw * 0.63, hd * 0.60, -130, 130)
    taper = _ring_level((0, -hd * 0.03, brow_z + hh * 0.36), hw * 0.42, hd * 0.40, sides)
    taper["points"] = mops.arc_points(sides, hw * 0.42, hd * 0.40, -130, 130)
    apex = {"z": brow_z + hh * 0.34, "cx": 0, "cy": -hd * 0.05, "apex": True}

    dome = mops.build_loft("HelmetDome", [rim, bulge, taper, apex], closed=False, cap_bottom=False)
    prim.assign_material(dome, metal)
    parts.append((dome, B.HEAD))

    p_left = (rim["cx"] + rim["points"][0][0], rim["cy"] + rim["points"][0][1], rim["z"])
    p_right = (rim["cx"] + rim["points"][-1][0], rim["cy"] + rim["points"][-1][1], rim["z"])
    mid_x = (p_left[0] + p_right[0]) / 2.0
    mid_y = (p_left[1] + p_right[1]) / 2.0
    browband = prim.box(
        "Browband", (abs(p_right[0] - p_left[0]) * 1.05, hd * 0.16, hh * 0.07),
        (mid_x, mid_y, rim["z"]),
    )
    prim.assign_material(browband, metal_dark)
    parts.append((browband, B.HEAD))

    nose_guard = prim.box(
        "NoseGuard", (hw * 0.09, hd * 0.22, hh * 0.5),
        (0, mid_y + hd * 0.14, rim["z"] - hh * 0.12),
    )
    prim.assign_material(nose_guard, metal_dark)
    parts.append((nose_guard, B.HEAD))

    for s, p in ((-1, p_left), (1, p_right)):
        cheek = prim.box(
            f"CheekGuard.{'L' if s < 0 else 'R'}", (hw * 0.10, hd * 0.22, hh * 0.32),
            (p[0], p[1] * 0.85, rim["z"] - hh * 0.16),
        )
        prim.assign_material(cheek, metal)
        parts.append((cheek, B.HEAD))

    return parts


def build_shield_parts(m, style, mat_lib):
    parts = []
    wrist = m.wrist_pos(-1)
    radius = m.head_width * 1.35
    center = (wrist[0] - m.hand_width * 0.7, wrist[1], wrist[2] - m.len_hand * 0.3)

    rim = prim.hex_prism("ShieldRim", radius, m.hand_depth * 0.9, center, segments=style.hex_segments)
    prim.assign_material(rim, mat_lib.get_metal())
    parts.append((rim, B.side(B.HAND, -1)))

    field_center = (center[0] - m.hand_depth * 0.05, center[1], center[2])
    field = prim.hex_prism("ShieldField", radius * 0.82, m.hand_depth * 0.95, field_center,
                            segments=style.hex_segments)
    prim.assign_material(field, mat_lib.get("shield_field", faction=True))
    parts.append((field, B.side(B.HAND, -1)))

    boss_center = (field_center[0] - m.hand_depth * 0.35, field_center[1], field_center[2])
    boss = prim.hex_prism("ShieldBoss", radius * 0.30, m.hand_depth * 0.55, boss_center,
                           segments=style.hex_segments, radius2=0.0)
    prim.assign_material(boss, mat_lib.get_metal())
    parts.append((boss, B.side(B.HAND, -1)))

    return parts


def build_sword_parts(m, style, mat_lib):
    parts = []
    wrist = m.wrist_pos(1)
    grip_len = m.len_hand * 1.1
    guard_z = wrist[2] + grip_len

    handle = prim.cone("SwordHandle", m.hand_width * 0.16, m.hand_width * 0.16, grip_len,
                        style.cylinder_segments, wrist)
    prim.assign_material(handle, mat_lib.get("leather"))
    parts.append((handle, B.side(B.HAND, 1)))

    guard = prim.box("SwordGuard", (m.hand_width * 1.05, m.hand_depth * 0.5, m.hand_depth * 0.22),
                      (wrist[0], wrist[1], guard_z))
    prim.assign_material(guard, mat_lib.get_metal())
    parts.append((guard, B.side(B.HAND, 1)))

    blade_len = m.len_upper_arm * 1.20
    metal = mat_lib.get_metal()
    b0 = _ring_level((wrist[0], wrist[1], guard_z), m.hand_width * 0.22, m.hand_depth * 0.10, 4)
    b1 = _ring_level((wrist[0], wrist[1], guard_z + blade_len * 0.6), m.hand_width * 0.17, m.hand_depth * 0.075, 4)
    tip = {"z": guard_z + blade_len, "cx": wrist[0], "cy": wrist[1], "apex": True}
    blade = mops.build_loft("SwordBlade", [b0, b1, tip], cap_bottom=True, cap_top=False)
    prim.assign_material(blade, metal)
    parts.append((blade, B.side(B.HAND, 1)))

    pommel = prim.uv_sphere("SwordPommel", m.hand_width * 0.16, 6, 3,
                             (wrist[0], wrist[1], wrist[2] - m.hand_width * 0.1))
    prim.assign_material(pommel, mat_lib.get_metal(dark=True))
    parts.append((pommel, B.side(B.HAND, 1)))

    return parts
