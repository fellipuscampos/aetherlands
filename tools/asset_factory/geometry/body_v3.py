"""
V3 body: the fix for "limbs aren't connected". V2 built each segment
(UpperArm, LowerArm, Hand, ...) as its own independently-capped object,
rigidly bound to one bone -- at rest the two caps touch, but they are
still two separate flat surfaces meeting edge-to-edge, and the instant a
joint bends in animation they visibly separate (or always read as a
slightly artificial seam even at rest).

V3 builds each ARM, each LEG, and the whole TORSO as ONE continuous
watertight loft spanning several bones, with vertex weights BLENDED
across 2-3 rings at each joint (see meshops.build_loft's `weights`
support). There is no seam because there is no second surface -- and the
joint now actually deforms smoothly when the two bones rotate apart,
instead of hinging as two rigid blocks. This is the standard way real
game characters are skinned; it costs more geometry (more rings through
each joint) and more setup per vertex, which is the "more complex
calculation" being asked for here.

The head (self-contained, single-bone, never was the problem) and all
equipment (armor plates, helmet, shield, sword -- genuinely separate
rigid objects even on a real body) are reused unchanged from V2.
"""

from geometry import body_v2
from geometry import meshops as mops
from geometry import primitives as prim
from rig import bones as B

_tag = body_v2._tag
_lerp = mops.lerp
_lerp3 = mops.lerp3


def _wring(pos, rx, ry, sides, weights, nudge=None):
    lvl = mops.ring_level(pos, rx, ry, sides, nudge=nudge)
    lvl["weights"] = weights
    return lvl


# --------------------------------------------------------------------------
# Torso: pelvis -> waist -> chest as ONE continuous loft, blended at the
# two internal bone boundaries. Neck stays a separate short cone (V2,
# unchanged) -- its diameter is small enough that the seam there is a
# minor, expected "collar line", not a limb-connection problem.
# --------------------------------------------------------------------------

def build_torso_parts(m, style, mat_lib):
    sides = style.torso_sides
    w = body_v2.torso_width_chain(m, style)
    cloth = mat_lib.get("cloth", faction=True)
    eps = (m.z_chest_top - m.z_hip) * 0.012

    waist_z = _lerp(m.z_pelvis_top, m.z_spine_top, 0.55)
    chest_lower_ry_boost = w["chest_lower"][1] * (style.chest_projection - 1.0)
    chest_upper_ry_boost = w["chest_upper"][1] * (style.chest_projection - 1.0)

    levels = [
        _wring((0, 0, m.z_hip), *w["pelvis_bottom"], sides, {B.PELVIS: 1.0}),
        _wring((0, 0, _lerp(m.z_hip, m.z_pelvis_top, 0.55)), *w["pelvis_mid"], sides, {B.PELVIS: 1.0}),
        _wring((0, 0, m.z_pelvis_top - eps), w["pelvis_top"][0] * 0.99, w["pelvis_top"][1] * 0.99, sides,
               {B.PELVIS: 0.7, B.SPINE: 0.3}),
        _wring((0, 0, m.z_pelvis_top), *w["pelvis_top"], sides, {B.PELVIS: 0.35, B.SPINE: 0.65}),
        _wring((0, 0, waist_z), *w["spine_waist"], sides, {B.SPINE: 1.0}),
        _wring((0, 0, m.z_spine_top - eps), w["spine_top"][0] * 0.99, w["spine_top"][1] * 0.99, sides,
               {B.SPINE: 0.7, B.CHEST: 0.3}),
        _wring((0, 0, m.z_spine_top), *w["spine_top"], sides, {B.SPINE: 0.35, B.CHEST: 0.65}),
        _wring((0, m.torso_depth * 0.04, _lerp(m.z_spine_top, m.z_chest_top, 0.45)),
               w["chest_lower"][0], w["chest_lower"][1] + chest_lower_ry_boost, sides, {B.CHEST: 1.0}),
        _wring((0, m.torso_depth * 0.06, m.z_chest_top),
               w["chest_upper"][0], w["chest_upper"][1] + chest_upper_ry_boost, sides, {B.CHEST: 1.0}),
    ]
    torso = mops.build_loft("Torso", levels, cap_bottom=True, cap_top=True)
    prim.assign_material(torso, cloth)
    parts = [(torso, None)]

    neck_radius = m.head_width * 0.28
    neck = prim.cone("Neck", neck_radius, neck_radius * 0.92, m.z_neck_top - m.z_chest_top,
                      style.cylinder_segments, (0, 0, m.z_chest_top))
    prim.assign_material(neck, mat_lib.get("skin"))
    parts.append((neck, B.NECK))

    return parts


# --------------------------------------------------------------------------
# Arms: shoulder -> upper arm -> [blend] -> forearm -> [blend] -> hand,
# one continuous skin-colored loft per arm.
# --------------------------------------------------------------------------

def build_arm_parts(m, style, mat_lib):
    sides = style.limb_sides
    skin = mat_lib.get("skin")
    parts = []

    for s in (-1, 1):
        tag = _tag(s)
        UA, LA, HD = B.side(B.UPPER_ARM, s), B.side(B.LOWER_ARM, s), B.side(B.HAND, s)
        shoulder, elbow, wrist = m.shoulder_pos(s), m.elbow_pos(s), m.wrist_pos(s)
        tip = m.hand_tip_pos(s)
        ru, rl = m.upper_arm_radius, m.lower_arm_radius
        rh = (m.hand_width + m.hand_depth) / 4.0

        levels = [
            _wring(shoulder, ru * 1.05, ru * 1.05, sides, {UA: 1.0}),
            _wring(_lerp3(shoulder, elbow, 0.22), ru * 1.16, ru * 1.16, sides, {UA: 1.0}),
            _wring(_lerp3(shoulder, elbow, 0.65), ru * 0.92, ru * 0.92, sides, {UA: 1.0}),
            _wring(_lerp3(shoulder, elbow, 0.90), ru * 0.80, ru * 0.80, sides, {UA: 0.65, LA: 0.35}),
            _wring(elbow, (ru * 0.76 + rl * 1.05) / 2.0, (ru * 0.76 + rl * 1.05) / 2.0, sides,
                   {UA: 0.30, LA: 0.70}),
            _wring(_lerp3(elbow, wrist, 0.25), rl * 1.05, rl * 1.05, sides, {LA: 1.0}),
            _wring(_lerp3(elbow, wrist, 0.60), rl * 0.90, rl * 0.90, sides, {LA: 1.0}),
            _wring(_lerp3(elbow, wrist, 0.88), rl * 0.76, rl * 0.76, sides, {LA: 0.65, HD: 0.35}),
            _wring(wrist, (rl * 0.70 + rh * 1.0) / 2.0, (rl * 0.70 + rh * 0.85) / 2.0, sides,
                   {LA: 0.30, HD: 0.70}),
            _wring(_lerp3(wrist, tip, 0.45), m.hand_width * 0.27, m.hand_depth * 0.30, sides, {HD: 1.0}),
            _wring(tip, m.hand_width * 0.24, m.hand_depth * 0.20, sides, {HD: 1.0}),
        ]
        arm = mops.build_loft(f"Arm.{tag}", levels, cap_bottom=True, cap_top=True)
        prim.assign_material(arm, skin)
        parts.append((arm, None))

        thumb_pos = _lerp3(wrist, tip, 0.42)
        thumb = prim.wedge(
            f"Thumb.{tag}", (m.hand_width * 0.16, m.hand_depth * 0.16, m.hand_width * 0.30),
            (thumb_pos[0] + s * m.hand_width * 0.28, thumb_pos[1] - m.hand_depth * 0.05, thumb_pos[2]),
            taper=0.35,
        )
        prim.assign_material(thumb, skin)
        parts.append((thumb, HD))

    return parts


# --------------------------------------------------------------------------
# Legs: hip -> thigh -> [blend] -> calf -> [blend] -> boot, one continuous
# leather loft per leg.
# --------------------------------------------------------------------------

def build_leg_parts(m, style, mat_lib):
    sides = style.limb_sides
    leather = mat_lib.get("leather")
    parts = []

    for s in (-1, 1):
        tag = _tag(s)
        UL, LL, FT = B.side(B.UPPER_LEG, s), B.side(B.LOWER_LEG, s), B.side(B.FOOT, s)
        hip, knee, ankle = m.hip_pos(s), m.knee_pos(s), m.ankle_pos(s)
        ru, rl = m.upper_leg_radius, m.lower_leg_radius
        z_sole = m.z_ground + m.foot_height * 0.30
        bridge_pos = (ankle[0], ankle[1] + m.len_foot * 0.16, _lerp(ankle[2], z_sole, 0.5))
        toe_pos = (ankle[0], ankle[1] + m.len_foot * 0.34, z_sole)
        foot_cuff_r = m.foot_width * 0.42

        levels = [
            _wring(hip, ru * 1.00, ru * 1.00, sides, {UL: 1.0}),
            _wring(_lerp3(hip, knee, 0.30), ru * 1.12, ru * 1.12, sides, {UL: 1.0}),
            _wring(_lerp3(hip, knee, 0.75), ru * 0.88, ru * 0.88, sides, {UL: 1.0}),
            _wring(_lerp3(hip, knee, 0.94), ru * 0.80, ru * 0.80, sides, {UL: 0.65, LL: 0.35}),
            _wring(knee, (ru * 0.76 + rl * 1.05) / 2.0, (ru * 0.76 + rl * 1.05) / 2.0, sides,
                   {UL: 0.30, LL: 0.70}),
            _wring(_lerp3(knee, ankle, 0.18), rl * 1.16, rl * 1.16, sides, {LL: 1.0}),
            _wring(_lerp3(knee, ankle, 0.50), rl * 1.08, rl * 1.08, sides, {LL: 1.0}),
            _wring(_lerp3(knee, ankle, 0.85), rl * 0.78, rl * 0.78, sides, {LL: 0.65, FT: 0.35}),
            _wring(ankle, (rl * 0.70 + foot_cuff_r) / 2.0, (rl * 0.70 + foot_cuff_r) / 2.0, sides,
                   {LL: 0.30, FT: 0.70}),
            _wring(bridge_pos, m.foot_width * 0.55, m.len_foot * 0.32, sides, {FT: 1.0},
                   nudge=[(0, 0.0, m.len_foot * 0.10)]),
            _wring(toe_pos, m.foot_width * 0.48, m.len_foot * 0.28, sides, {FT: 1.0},
                   nudge=[(0, 0.0, m.len_foot * 0.20)]),
        ]
        leg = mops.build_loft(f"Leg.{tag}", levels, cap_bottom=True, cap_top=True)
        prim.assign_material(leg, leather)
        parts.append((leg, None))

    return parts


build_head_parts = body_v2.build_head_parts
