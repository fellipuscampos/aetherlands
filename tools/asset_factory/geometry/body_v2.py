"""
V2 body generators: "few polygons, many intentional forms". Every part
that reads as anatomy (torso, head, limbs) is built as a small stack of
deliberately-shaped cross-sections (see geometry/meshops.build_loft)
instead of a single primitive. Simple accessories (eyes, nose, ears,
hair clumps, thumb nub) still use plain primitives where that's honestly
the simplest correct shape -- the brief asks for intentional geometry,
not geometry for its own sake.

Every loft segment is capped at BOTH ends (cap_bottom=True, cap_top=True)
even where it touches a neighboring segment: neighboring segments are
bound to different bones and rotate independently in FK animation (an
elbow bends, a spine twists), so each segment must be watertight on its
own or a hollow gap would show mid-animation. The small seam this leaves
at rest is a deliberate, expected trait of a rigid-segment low-poly rig.
"""

import math

from geometry import meshops as mops
from geometry import primitives as prim
from rig import bones as B


def _tag(s):
    return "L" if s < 0 else "R"


_lerp = mops.lerp
_lerp3 = mops.lerp3
_ring_level = mops.ring_level


# --------------------------------------------------------------------------
# Torso: pelvis / spine (waist) / chest, each its own rigid-bound loft.
# --------------------------------------------------------------------------

def torso_width_chain(m, style):
    """Explicit, guaranteed-monotonic silhouette widths.

    Critical constraint this must satisfy and the previous two passes
    didn't: the pelvis MUST reach out far enough to contain where the legs
    actually attach (hip_x + a chunk of the thigh's own radius), and the
    chest/shoulder line MUST reach out close to where the arms actually
    attach (shoulder_x). Both earlier passes computed the pelvis/chest
    widths as an isolated ratio of hip_x alone, with no reference to the
    limb attachment points or their radius -- so the torso silhouette
    ended up NARROWER than the limbs bolted onto it, and the arms/legs
    read as floating outside the body instead of growing out of it
    ("pernas pra fora do corpo e os braços flutuando ao lado dele").
    Anchoring directly to hip_x/shoulder_x + limb radius is what actually
    fixes that, independent of any other proportion tuning."""
    depth_ratio = m.torso_depth / m.torso_width
    pelvis_depth_ratio = m.pelvis_depth / m.pelvis_width

    hip_w = m.hip_x
    shoulder_w = m.shoulder_x
    leg_r = m.upper_leg_radius
    pelvis_bottom_rx = hip_w + leg_r * 0.62
    pelvis_mid_rx = hip_w + leg_r * 0.85     # widest -- comfortably contains the thigh's own bulge
    pelvis_top_rx = hip_w + leg_r * 0.70      # hip/waist boundary anchor
    spine_waist_rx = pelvis_top_rx * style.waist_pinch
    chest_target_rx = shoulder_w * 0.90       # shoulder line: reaches out to overlap the arm's attach point
    spine_top_rx = spine_waist_rx + (chest_target_rx - spine_waist_rx) * 0.45
    chest_lower_rx = spine_waist_rx + (chest_target_rx - spine_waist_rx) * 0.75
    chest_upper_rx = chest_target_rx           # widest point: chest/shoulder line

    return {
        "pelvis_bottom": (pelvis_bottom_rx, pelvis_bottom_rx * pelvis_depth_ratio),
        "pelvis_mid": (pelvis_mid_rx, pelvis_mid_rx * pelvis_depth_ratio),
        "pelvis_top": (pelvis_top_rx, pelvis_top_rx * pelvis_depth_ratio),
        "spine_waist": (spine_waist_rx, spine_waist_rx * depth_ratio),
        "spine_top": (spine_top_rx, spine_top_rx * depth_ratio),
        "chest_lower": (chest_lower_rx, chest_lower_rx * depth_ratio),
        "chest_upper": (chest_upper_rx, chest_upper_rx * depth_ratio),
    }


def build_torso_parts(m, style, mat_lib):
    sides = style.torso_sides
    parts = []
    w = torso_width_chain(m, style)

    pelvis_bottom = _ring_level((0, 0, m.z_hip), *w["pelvis_bottom"], sides)
    pelvis_mid = _ring_level((0, 0, _lerp(m.z_hip, m.z_pelvis_top, 0.55)), *w["pelvis_mid"], sides)
    pelvis_top = _ring_level((0, 0, m.z_pelvis_top), *w["pelvis_top"], sides)
    pelvis_obj = mops.build_loft("Pelvis", [pelvis_bottom, pelvis_mid, pelvis_top],
                                  cap_bottom=True, cap_top=True)
    prim.assign_material(pelvis_obj, mat_lib.get("cloth", faction=True))
    parts.append((pelvis_obj, B.PELVIS))

    waist_z = _lerp(m.z_pelvis_top, m.z_spine_top, 0.55)
    spine_bottom = _ring_level((0, 0, m.z_pelvis_top), *w["pelvis_top"], sides)
    spine_waist = _ring_level((0, 0, waist_z), *w["spine_waist"], sides)
    spine_top = _ring_level((0, 0, m.z_spine_top), *w["spine_top"], sides)
    spine_obj = mops.build_loft("Spine", [spine_bottom, spine_waist, spine_top],
                                 cap_bottom=True, cap_top=True)
    prim.assign_material(spine_obj, mat_lib.get("cloth", faction=True))
    parts.append((spine_obj, B.SPINE))

    neck_radius = m.head_width * 0.28
    chest_lower_ry_boost = w["chest_lower"][1] * (style.chest_projection - 1.0)
    chest_upper_ry_boost = w["chest_upper"][1] * (style.chest_projection - 1.0)
    # The shoulder line (z_chest_top, where the arms attach) must stay the
    # WIDEST point of the loft -- the actual narrowing into the neck is the
    # separate, much shorter Neck cone above it. The first version tapered
    # the whole chest down to neck-width by z_chest_top, collapsing the
    # torso to a point right where the arms and head attach: a funnel/
    # martini-glass silhouette rather than a ribcage with a distinct neck.
    chest_bottom = _ring_level((0, 0, m.z_spine_top), *w["spine_top"], sides)
    chest_mid = _ring_level(
        (0, m.torso_depth * 0.04, _lerp(m.z_spine_top, m.z_chest_top, 0.45)),
        w["chest_lower"][0], w["chest_lower"][1] + chest_lower_ry_boost, sides,
    )
    chest_top = _ring_level(
        (0, m.torso_depth * 0.06, m.z_chest_top),
        w["chest_upper"][0], w["chest_upper"][1] + chest_upper_ry_boost, sides,
    )
    chest_obj = mops.build_loft("Chest", [chest_bottom, chest_mid, chest_top],
                                 cap_bottom=True, cap_top=True)
    prim.assign_material(chest_obj, mat_lib.get("cloth", faction=True))
    parts.append((chest_obj, B.CHEST))

    neck = prim.cone("Neck", neck_radius, neck_radius * 0.92, m.z_neck_top - m.z_chest_top,
                      style.cylinder_segments, (0, 0, m.z_chest_top))
    prim.assign_material(neck, mat_lib.get("skin"))
    parts.append((neck, B.NECK))

    return parts


# --------------------------------------------------------------------------
# Head: skull loft + ears + hair + minimal facial detail.
# --------------------------------------------------------------------------

def _closest_index(sides, target_deg, phase_deg=90.0):
    """Index of the ring vertex whose angle is nearest target_deg (0=+X
    right, 90=+Y front, 180=-X left, matching ellipse_points' convention).
    Works for any `sides`, unlike a fixed sides//4 offset."""
    best_i, best_diff = 0, 1e9
    for i in range(sides):
        angle = (phase_deg + 360.0 * i / sides) % 360.0
        diff = min(abs(angle - target_deg), 360.0 - abs(angle - target_deg))
        if diff < best_diff:
            best_diff, best_i = diff, i
    return best_i


def _face_ring(pos, w, d, sides, flatten=True, flatten_scale=0.93):
    """An ellipse ring, optionally flattened at the front 3 vertices into a
    small planar facet -- a real flat spot for eyes/nose/mouth to sit
    flush on, instead of bulging off a continuously convex curve (which
    reads as blisters glued to a ball, not a face)."""
    pts = mops.ellipse_points(sides, w / 2.0, d / 2.0)
    if flatten:
        target_y = (d / 2.0) * flatten_scale
        pts = mops.flatten_indices(pts, [-1, 0, 1], target_y)
    return {"z": pos[2], "cx": pos[0], "cy": pos[1], "points": pts}


def build_head_parts(m, style, mat_lib):
    sides = style.head_sides
    hh = m.head_height
    hw = m.head_width
    hd = m.head_depth
    base_z = m.z_neck_top
    skin = mat_lib.get("skin")
    hair = mat_lib.get("hair")
    eyes_mat = mat_lib.get("eyes")

    jaw_base = _face_ring((0, 0, base_z + 0.06 * hh), hw * 0.58, hd * 0.56, sides, flatten=False)
    jaw = _face_ring((0, 0, base_z + 0.20 * hh), hw * 0.86, hd * 0.76, sides, flatten=False)
    mouth_ring = _face_ring((0, 0, base_z + 0.34 * hh), hw * 1.02, hd * 0.92, sides)
    cheek = _face_ring((0, 0, base_z + 0.50 * hh), hw * 1.08, hd * 0.98, sides)
    brow = _face_ring((0, 0, base_z + 0.66 * hh), hw * 1.00, hd * 0.94, sides)
    forehead = _face_ring((0, 0, base_z + 0.82 * hh), hw * 0.84, hd * 0.78, sides, flatten=False)
    crown = _face_ring((0, -hd * 0.02, base_z + 0.97 * hh), hw * 0.36, hd * 0.34, sides, flatten=False)

    skull = mops.build_loft(
        "Skull", [jaw_base, jaw, mouth_ring, cheek, brow, forehead, crown],
        cap_bottom=True, cap_top=True,
    )
    prim.assign_material(skull, skin)
    parts = [(skull, B.HEAD)]

    face_plane_y = cheek["points"][0][1]  # the flattened facet's depth -- features sit flush on this
    face_z = cheek["z"]

    ear_size = hw * style.ear_size_ratio
    left_idx = _closest_index(sides, 180.0)
    right_idx = _closest_index(sides, 0.0)
    for s, idx in ((-1, left_idx), (1, right_idx)):
        px, py = brow["points"][idx]
        anchor = (brow["cx"] + px, brow["cy"] + py, brow["z"])
        ear = _build_ear(f"Ear.{_tag(s)}", s, anchor, ear_size)
        prim.assign_material(ear, skin)
        parts.append((ear, B.HEAD))

    eye_z = _lerp(cheek["z"], brow["z"], 0.55)
    for s in (-1, 1):
        eye = prim.box(f"Eye.{_tag(s)}", (hw * 0.13, hd * 0.05, hh * 0.065),
                        (s * hw * 0.19, face_plane_y + hd * 0.01, eye_z))
        prim.assign_material(eye, eyes_mat)
        parts.append((eye, B.HEAD))

        brow_ridge = prim.box(f"Brow.{_tag(s)}", (hw * 0.16, hd * 0.05, hh * 0.03),
                               (s * hw * 0.19, face_plane_y, eye_z + hh * 0.055))
        prim.assign_material(brow_ridge, hair)
        parts.append((brow_ridge, B.HEAD))

    nose = prim.wedge("Nose", (hw * 0.09, hd * 0.14, hh * 0.10),
                       (0, face_plane_y + hd * 0.06, eye_z - hh * 0.04), taper=0.25)
    prim.assign_material(nose, skin)
    parts.append((nose, B.HEAD))

    mouth = prim.box("Mouth", (hw * 0.16, hd * 0.035, hh * 0.02),
                      (0, face_plane_y + hd * 0.01, _lerp(jaw["z"], mouth_ring["z"], 0.7)))
    prim.assign_material(mouth, mat_lib.get_metal(dark=True))
    parts.append((mouth, B.HEAD))

    hair_top = prim.uv_sphere("HairTop", (hw * 0.56, hd * 0.52, hh * 0.30), 8, 3,
                               (0, -hd * 0.06, base_z + 0.86 * hh))
    prim.assign_material(hair_top, hair)
    parts.append((hair_top, B.HEAD))

    hair_back = prim.wedge("HairBack", (hw * 0.74, hd * 0.42, hh * 0.46),
                            (0, -hd * 0.22, base_z + 0.66 * hh), taper=0.55)
    prim.assign_material(hair_back, hair)
    parts.append((hair_back, B.HEAD))

    for s in (-1, 1):
        sideburn = prim.box(f"Sideburn.{_tag(s)}", (hw * 0.09, hd * 0.20, hh * 0.22),
                             (s * hw * 0.40, -hd * 0.02, base_z + 0.34 * hh))
        prim.assign_material(sideburn, hair)
        parts.append((sideburn, B.HEAD))

    return parts


def _build_ear(name, side, anchor, size):
    import bmesh
    bm = bmesh.new()
    ax, ay, az = anchor
    half = size * 0.5
    base = [
        bm.verts.new((ax, ay - half * 0.6, az + half * 0.9)),
        bm.verts.new((ax, ay - half * 0.6, az - half * 0.9)),
        bm.verts.new((ax, ay + half * 0.6, az - half * 0.9)),
        bm.verts.new((ax, ay + half * 0.6, az + half * 0.9)),
    ]
    tip = bm.verts.new((ax + side * size * 0.95, ay, az))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((base[i], base[j], tip))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return prim.finish_mesh(name, bm)


# --------------------------------------------------------------------------
# Arms: shoulder-bulge upper arm loft + forearm loft + paddle hand.
# --------------------------------------------------------------------------

def build_arm_parts(m, style, mat_lib):
    sides = style.limb_sides
    skin = mat_lib.get("skin")
    parts = []

    for s in (-1, 1):
        tag = _tag(s)
        shoulder = m.shoulder_pos(s)
        elbow = m.elbow_pos(s)
        wrist = m.wrist_pos(s)

        r = m.upper_arm_radius
        levels = []
        for t, rad in ((0.0, r * 1.30), (0.18, r * 1.05), (0.60, r * 0.95), (1.0, r * 0.72)):
            pos = _lerp3(shoulder, elbow, t)
            levels.append(_ring_level(pos, rad, rad, sides))
        upper_arm = mops.build_loft(f"UpperArm.{tag}", levels, cap_bottom=True, cap_top=True)
        prim.assign_material(upper_arm, skin)
        parts.append((upper_arm, B.side(B.UPPER_ARM, s)))

        rl = m.lower_arm_radius
        levels = []
        for t, rad in ((0.0, rl * 1.05), (0.45, rl * 0.95), (1.0, rl * 0.65)):
            pos = _lerp3(elbow, wrist, t)
            levels.append(_ring_level(pos, rad, rad, sides))
        lower_arm = mops.build_loft(f"LowerArm.{tag}", levels, cap_bottom=True, cap_top=True)
        prim.assign_material(lower_arm, skin)
        parts.append((lower_arm, B.side(B.LOWER_ARM, s)))

        hand = _build_hand(tag, s, m, wrist, mat_lib)
        parts += hand

    return parts


def _build_hand(tag, s, m, wrist, mat_lib):
    sides = 6
    hand_len = m.len_hand
    tip = (wrist[0], wrist[1], wrist[2] - hand_len)
    skin = mat_lib.get("skin")

    levels = []
    for t, rx_f, ry_f in ((0.0, 0.34, 0.34), (0.4, 0.50, 0.56), (1.0, 0.48, 0.40)):
        pos = _lerp3(wrist, tip, t)
        levels.append(_ring_level(pos, m.hand_width * rx_f, m.hand_depth * ry_f, sides))
    hand_obj = mops.build_loft(f"Hand.{tag}", levels, cap_bottom=True, cap_top=True)
    prim.assign_material(hand_obj, skin)

    thumb_pos = _lerp3(wrist, tip, 0.45)
    thumb = prim.wedge(
        f"Thumb.{tag}", (m.hand_width * 0.16, m.hand_depth * 0.16, m.hand_width * 0.30),
        (thumb_pos[0] + s * m.hand_width * 0.30, thumb_pos[1] - m.hand_depth * 0.05, thumb_pos[2]),
        taper=0.35,
    )
    prim.assign_material(thumb, skin)

    return [(hand_obj, B.side(B.HAND, s)), (thumb, B.side(B.HAND, s))]


# --------------------------------------------------------------------------
# Legs: hip/thigh loft + knee/calf loft + boot loft.
# --------------------------------------------------------------------------

def build_leg_parts(m, style, mat_lib):
    sides = style.limb_sides
    leather = mat_lib.get("leather")
    parts = []

    for s in (-1, 1):
        tag = _tag(s)
        hip = m.hip_pos(s)
        knee = m.knee_pos(s)
        ankle = m.ankle_pos(s)

        r = m.upper_leg_radius
        levels = []
        for t, rad in ((0.0, r * 1.00), (0.30, r * 1.12), (1.0, r * 0.76)):
            pos = _lerp3(hip, knee, t)
            levels.append(_ring_level(pos, rad, rad, sides))
        thigh = mops.build_loft(f"UpperLeg.{tag}", levels, cap_bottom=True, cap_top=True)
        prim.assign_material(thigh, leather)
        parts.append((thigh, B.side(B.UPPER_LEG, s)))

        rl = m.lower_leg_radius
        levels = []
        for t, rad in ((0.0, rl * 1.05), (0.35, rl * 1.15), (1.0, rl * 0.62)):
            pos = _lerp3(knee, ankle, t)
            levels.append(_ring_level(pos, rad, rad, sides))
        calf = mops.build_loft(f"LowerLeg.{tag}", levels, cap_bottom=True, cap_top=True)
        prim.assign_material(calf, leather)
        parts.append((calf, B.side(B.LOWER_LEG, s)))

        boot = _build_boot(tag, m, ankle, mat_lib)
        parts.append((boot, B.side(B.FOOT, s)))

    return parts


def _build_boot(tag, m, ankle, mat_lib):
    sides = 6
    leather = mat_lib.get("leather")
    z_sole = m.z_ground + m.foot_height * 0.30

    cuff = _ring_level(ankle, m.foot_width * 0.42, m.foot_width * 0.42, sides)
    bridge_pos = (ankle[0], ankle[1] + m.len_foot * 0.16, _lerp(ankle[2], z_sole, 0.5))
    bridge = _ring_level(bridge_pos, m.foot_width * 0.55, m.len_foot * 0.32, sides,
                          nudge=[(0, 0.0, m.len_foot * 0.10)])
    toe_pos = (ankle[0], ankle[1] + m.len_foot * 0.34, z_sole)
    toe = _ring_level(toe_pos, m.foot_width * 0.48, m.len_foot * 0.28, sides,
                       nudge=[(0, 0.0, m.len_foot * 0.20)])

    boot = mops.build_loft(f"Foot.{tag}", [cuff, bridge, toe], cap_bottom=True, cap_top=True)
    prim.assign_material(boot, leather)
    return boot
