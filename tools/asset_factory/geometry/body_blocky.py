"""
Blocky body: Minecraft/Hytale-language geometry instead of an attempt at
smooth human anatomy. Every part is a straight rectangular box -- no
lofted curves, no organic taper.

Proportions here are modeled directly on the reference (a classic
Minecraft-family rig), not on the "realistic" radius/ratio fields in
Measurements (those were tuned for the organic V2/V3 lofts and encode
the OPPOSITE relationships this style wants -- e.g. thigh thicker than
calf, legs spread out from a wide hip). So torso/arm/leg X-placement and
thickness are computed locally from a single `torso_hw` anchor instead
of reusing m.hip_x/m.shoulder_x/m.upper_leg_radius directly:
    - torso: one continuous rectangular cross-section, portrait-oriented
      (taller than wide), not the near-square block the first pass had.
    - legs: attach BELOW the torso (centered under each half), not out to
      its sides; calf is thicker than thigh; foot is thicker than calf.
    - arms: attach flush to the torso's outer edge; forearm and hand
      share the same (thicker) width, both noticeably chunkier than the
      upper arm.
Z heights (how far down the hip/knee/ankle joints sit) still come from
the shared Measurements stack -- only X placement and thickness are
style-local.
"""

from geometry import primitives as prim
from rig import bones as B
from style import textures
from style.palette import FIXED_COLORS


def _tag(s):
    return "L" if s < 0 else "R"


def torso_dims(m):
    """Single anchor for the whole style: a portrait-oriented rectangle
    (width noticeably less than height), matching a Minecraft-family body
    box instead of the near-square block the first pass produced."""
    hw = m.shoulder_x * 0.48
    hd = hw * 0.62
    return hw, hd


def chest_dims(m):
    """The chest block is wider than the rest of the torso (a pectoral
    bulk block, see build_torso_parts) -- arms attach to ITS width, since
    they hang from the shoulder/chest line, not the waist.

    `style.slim_build` (per-character opt-out, see definitions.py) drops
    the pectoral bulk entirely -- chest matches waist/belly width exactly,
    an ordinary build instead of a soldier's V-taper. (An earlier version
    of this kept a small 1.08x step here specifically to fake a shoulder
    line -- wrong fix for a real problem: the actual gap was
    build_arm_parts capping the sleeve well below the top of the torso.
    Fixed there instead, so chest width itself can go back to matching
    the waist exactly, as asked.)"""
    hw, hd = torso_dims(m)
    if getattr(m.style, "slim_build", False):
        return hw, hd
    return hw * 1.22, hd * 1.15


def build_torso_parts(m, style, mat_lib, faction=True, bare=False, pelvis_material=None, muscles=False,
                       textured=True, bone_marks=False):
    """Pelvis is its own block; the Spine bone gets a distinct "belly"/
    waist block sized to match the PELVIS exactly (not narrower) -- if the
    waist is narrower than the hips it reads as flared/wide hips
    ("bundudo"), so pelvis and belly share one width and only the chest
    is wider, giving a clean two-step taper: chest (widest) -> waist and
    hips (equal, narrower).

    `faction=False` -- see build_arm_parts' sleeve_material docstring,
    same civilian override (plain undyed cloth instead of team color).

    `bare=True` skips cloth entirely -- bare skin instead, for a species
    (goblin/orc) whose reference shows an exposed torso, not a shirt.
    Ignores `faction` (skin never carries team color). `textured=False`
    (only meaningful with `bare`) uses a FLAT skin color instead of the
    mottled hide texture (mat_lib.get_hide_textured()) -- a whole
    texturing pass the user tried and then asked reverted wholesale
    ("tire todas as texturas ai, deixe ele com texturas solidas, ficou
    horrivel"); default stays True only so nothing silently changes for
    a hypothetical future bare+textured preset that never asked for flat.

    `muscles=True` (only meaningful with `bare and textured`) overlays a
    unique pec/ab texture on the Chest box's front face (mat_lib.
    get_muscle_face("chest")) on top of the tiled hide base -- makes no
    sense without the textured hide base under it, so it's ignored when
    `textured=False` regardless of what's passed in.

    `pelvis_material="leather"` paints JUST the pelvis block leather,
    overriding `bare` for that one piece -- a loincloth painted directly
    onto the body instead of separate 3D skirt geometry ("pinte de couro
    como se fosse tecido a pelvis", user), while spine/chest stay bare.

    `bone_marks=True` (only meaningful with `bare`, independent of
    `muscles`/`textured`) overlays a ribcage texture on the Chest box's
    front face instead (mat_lib.get_bone_face("chest")) -- a Skeleton's
    bone structure, not a fleshy species' muscle definition."""
    parts = []
    hw, hd = torso_dims(m)
    # Same width as the pelvis by default -- narrower than that reads as
    # flared/wide hips ("bundudo") on a fleshy build. belly_width_mult
    # overrides that for a species where the waist should read as
    # something else entirely -- a Skeleton's spine as a thin post
    # ("estaca") connecting a boxy ribcage to the pelvis, not a matching-
    # width belly (user, after rejecting a texture-based ribcage: "so
    # mudar as coisas, tipo... a barriga uma estaca"). 1.0 default keeps
    # every existing preset's belly pixel-identical.
    belly_width_mult = getattr(m.style, "belly_width_mult", 1.0)
    belly_hw, belly_hd = hw * belly_width_mult, hd * belly_width_mult
    chest_hw, chest_hd = chest_dims(m)
    overlap = min(hw, hd) * 0.18
    muscles = muscles and textured
    if bare:
        torso_mat = mat_lib.get_hide_textured() if textured else mat_lib.get("skin")
    else:
        torso_mat = mat_lib.get_cloth_textured(faction=faction)
    if pelvis_material == "leather":
        pelvis_mat = mat_lib.get_leather_textured() if textured else mat_lib.get("leather")
    else:
        pelvis_mat = torso_mat
    tile = 0.045

    def _apply(obj, mat):
        if bare and not textured:
            prim.assign_material(obj, mat)  # flat color, no UV work needed
        else:
            prim.apply_tiled_material(obj, mat, tile_size=tile)

    pelvis = prim.box("Pelvis", (hw * 2, hd * 2, (m.z_pelvis_top - m.z_hip) + overlap),
                       (0, 0, (m.z_hip + m.z_pelvis_top) / 2.0))
    _apply(pelvis, pelvis_mat)
    parts.append((pelvis, B.PELVIS))

    belly = prim.box("Spine", (belly_hw * 2, belly_hd * 2, (m.z_spine_top - m.z_pelvis_top) + overlap * 2),
                      (0, 0, (m.z_pelvis_top + m.z_spine_top) / 2.0))
    _apply(belly, torso_mat)
    parts.append((belly, B.SPINE))

    chest = prim.box("Chest", (chest_hw * 2, chest_hd * 2, (m.z_chest_top - m.z_spine_top) + overlap),
                      (0, 0, (m.z_spine_top + m.z_chest_top) / 2.0 + overlap * 0.3))
    _apply(chest, torso_mat)
    if bare and muscles:
        chest_face = mat_lib.get_muscle_face("chest")
        prim.tag_front_face(chest, chest_face, front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
    elif bare and bone_marks:
        # Independent of `muscles`/`textured` -- a flat bone-colored box
        # alone reads as "just an albino" (user), not a skeleton; this is
        # what actually puts a ribcage on it.
        chest_face = mat_lib.get_bone_face("chest")
        prim.tag_front_face(chest, chest_face, front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
    parts.append((chest, B.CHEST))

    neck_h = m.z_neck_top - m.z_chest_top
    neck = prim.box("Neck", (hw * 0.78, hd * 0.78, neck_h + overlap),
                     (0, 0, (m.z_chest_top + m.z_neck_top) / 2.0))
    prim.assign_material(neck, mat_lib.get("skin"))
    parts.append((neck, B.NECK))

    return parts


def build_head_parts(m, style, mat_lib, wears_helmet=False, beard=True, teeth=False, hair=True,
                      textured_skin=False, eye_style="round", nose=False):
    """A big blocky head (deliberately oversized -- Minecraft/Hytale
    proportions read as a person specifically BECAUSE the head is large
    relative to the body) with a generated pixel-art face texture on the
    front face -- big cartoon eyes (and, per reference, a light stubble
    shadow) read at a glance in a way that tiny 3D eye boxes never did.

    `wears_helmet`: the loose hair cap this style normally uses would
    otherwise poke out ABOVE a low helmet dome (it did, and looked like a
    second brown "helmet" floating over the real one) -- skip it when a
    helmet is equipped; the dome and coif already read as headwear.

    `hair=False` skips the hair cap even with no helmet -- a bald/hairless
    species (goblin) rather than "not wearing a helmet right now".

    `textured_skin=True` swaps the head's (and ears') base material from
    flat skin to the same mottled hide texture as a bare-skinned
    species' torso/arms/legs (build_torso_parts' own `bare`) --
    consistent skin texture head to toe, not a flat-colored head on a
    textured body. Only the FRONT face (the face texture, unique per
    character) stays untouched by this -- tag_front_face overrides just
    that one polygon after the tiled base is applied.

    `eye_style`/`nose` -- see build_head_face_image's own eye_style
    docstring; `nose=True` adds a separate protruding nose block (a
    monster reference had one, this style's flat face texture never
    did: "inserir um bloco pra ser o nariz", user)."""
    parts = []
    skin = mat_lib.get_hide_textured() if textured_skin else mat_lib.get("skin")
    hw, hd, hh = m.head_width, m.head_depth, m.head_height

    head = prim.box("Head", (hw, hd, hh), (0, 0, m.z_neck_top + hh / 2.0))
    if textured_skin:
        prim.apply_tiled_material(head, skin, tile_size=0.03)
    else:
        prim.assign_material(head, skin)

    face_kwargs = {}
    if mat_lib.eye_color_override:
        face_kwargs["eye_color"] = mat_lib.eye_color_override
    face_image = textures.build_head_face_image(
        f"FaceTex_{mat_lib.civilization}", mat_lib.skin_color_override or FIXED_COLORS["skin"],
        beard=beard, beard_color=mat_lib.hair_color_override or FIXED_COLORS["hair"],
        teeth=teeth, eye_style=eye_style, **face_kwargs,
    )
    face_mat = textures.build_face_material(f"FaceMat_{mat_lib.civilization}", face_image)
    prim.tag_front_face(head, face_mat, front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
    parts.append((head, B.HEAD))

    if not wears_helmet and hair:
        hair_h = hh * 0.34
        hair = prim.box("HairTop", (hw * 1.08, hd * 1.08, hair_h),
                         (0, 0, m.z_neck_top + hh - hair_h * 0.28))
        prim.assign_material(hair, mat_lib.get("hair"))
        parts.append((hair, B.HEAD))

    if nose:
        # A small block protruding from the middle of the face, roughly
        # at/just below eye height (the face texture's eyes sit at
        # ~47-69% of head height, see build_head_face_image) -- this
        # style's flat-face-texture heads never had a 3D nose at all.
        nose_w, nose_d, nose_h = hw * 0.20, hd * 0.20, hh * 0.22
        nose_z = m.z_neck_top + hh * 0.46
        nose_obj = prim.box("Nose", (nose_w, nose_d, nose_h), (0, hd / 2.0 + nose_d * 0.3, nose_z))
        if textured_skin:
            prim.apply_tiled_material(nose_obj, skin, tile_size=0.03)
        else:
            prim.assign_material(nose_obj, skin)
        parts.append((nose_obj, B.HEAD))

    # Goblin/elf-style pointed ears (m.style.pointy_ears, off for every
    # human preset so far) -- prim.wedge() only tapers along its own
    # local +Z, so instead of a true sideways-pointing ear, this angles a
    # wedge UP and OUT from high on the side of the head: wide at the
    # skull, narrowing to a point up-and-outward. Close enough at this
    # low-poly scale, and no new primitive needed.
    if getattr(m.style, "pointy_ears", False):
        ear_w, ear_d, ear_h = hw * 0.22, hd * 0.34, hh * 0.5
        ear_z = m.z_neck_top + hh * 0.62
        for s in (-1, 1):
            ear = prim.wedge(f"Ear.{_tag(s)}", (ear_w, ear_d, ear_h),
                              (s * (hw / 2.0 + ear_w * 0.32), 0, ear_z), taper=0.12)
            if textured_skin:
                prim.apply_tiled_material(ear, skin, tile_size=0.03)
            else:
                prim.assign_material(ear, skin)
            parts.append((ear, B.HEAD))

    return parts


def arm_dims(m):
    """Single source of truth for arm thickness + X placement, shared by
    body_blocky.py (the mesh) and equipment_blocky.py (shield/sword/
    pauldron anchors) -- these drifted out of sync once already when
    each file computed its own copy of the same constants.

    `style.slim_build` -- see chest_dims docstring. Bicep thinner than
    forearm is itself part of the "built" read; a slim build gives both
    the same uniform thickness instead.

    `style.thin_arms` -- separate from `slim_build` (which also flattens
    chest/leg thickness): a species can have thin, uniform arms while
    keeping a stocky/muscular torso and legs (goblin reference: "goblins
    tem bracos finos" said specifically about the arms, nothing else).
    Thinner than slim_build's own uniform value -- properly skinny, not
    just "not built"."""
    chest_hw, _ = chest_dims(m)
    arm_scale = 0.88  # uniform thinning -- keeps bicep/forearm/hand proportions to each other unchanged
    if getattr(m.style, "slim_build", False):
        bicep_hw = forearm_hw = chest_hw * 0.36 * arm_scale
    elif getattr(m.style, "thin_arms", False):
        bicep_hw = forearm_hw = chest_hw * 0.30 * arm_scale
    else:
        bicep_hw = chest_hw * 0.34 * arm_scale
        forearm_hw = chest_hw * 0.42 * arm_scale
    # hand_size derives from forearm_hw BEFORE limb_slenderness below, so
    # a thinned arm doesn't also shrink the hand -- a relatively bulkier
    # hand at the end of a thin bone reads as a joint mass (a Skeleton).
    hand_size = forearm_hw * getattr(m.style, "hand_size_ratio", 1.18)  # a real cube, clearly bigger than the forearm -- distinct but not oversized
    slenderness = getattr(m.style, "limb_slenderness", 1.0)
    bicep_hw *= slenderness
    forearm_hw *= slenderness
    hand_len = hand_size           # half of a full cube's length (hand_size*2), full width -- see build_arm_parts
    hand_width_mult = getattr(m.style, "hand_width_mult", None)
    if hand_width_mult is not None:
        # Explicit continuous override (asset-factory editor) -- takes
        # priority over the older boolean below so a preset/slider can
        # dial in ANY width, not just the two fixed thin/thick presets.
        hand_width_x = hand_size * hand_width_mult
    elif getattr(m.style, "thick_hands", False):
        # Opposite of the locked human baseline below -- some species
        # (goblin) want the hand to read as visibly THICKER than the
        # forearm, not thinner. The human baseline's own 0.75 narrowing
        # already made hand_width_x smaller than forearm_hw once
        # combined with hand_size's 1.18x (0.75*1.18 = 0.885x, thinner);
        # 1.2 here instead gives 1.2*1.18 = 1.42x -- clearly chunkier.
        hand_width_x = hand_size * 1.2
    else:
        hand_width_x = hand_size * 0.75  # narrower side-to-side only ("lateralmente") -- depth (Y) stays a full cube
    return bicep_hw, forearm_hw, hand_size, hand_len, hand_width_x


def arm_x(m, s):
    chest_hw, _ = chest_dims(m)
    bicep_hw, _, _, _, _ = arm_dims(m)
    return s * (chest_hw + bicep_hw)


def leg_x(m, s):
    """Same single-source-of-truth reasoning as arm_x: the skeleton
    builder (rig/skeleton.py, shared by every engine) must place the hip/
    knee/ankle bones at THIS exact X, or the bones end up wherever
    Measurements.hip_pos() puts them (the organic style's hip_x, tuned
    for a completely different silhouette) instead of where the blocky
    leg mesh actually is -- see character/builder_blocky.py, which copies
    this value into measurements.hip_x before the skeleton is built."""
    torso_hw, _ = torso_dims(m)
    return s * (torso_hw * 0.52)


def build_arm_parts(m, style, mat_lib, sleeve_material="chainmail", muscles=False, textured=True,
                     bone_marks=False):
    """3 segments per arm: upper arm (bicep, the thinnest), forearm and
    hand sharing the SAME thickness (both chunkier than the bicep) --
    per reference. Arms hang straight down, flush against the torso's
    outer edge, not leaning away from the body.

    `sleeve_material` defaults to "chainmail" (every character built
    before this parameter existed, i.e. every soldier, wore mail sleeves
    unconditionally as part of the base body) -- a non-combat character
    (Colonizador: no armor at all, see builder_blocky.py) passes "cloth"
    instead, since bare mail with no cuirass over it reads as a costume
    mistake, not a civilian. The "cloth" branch is plain undyed cloth
    (faction=False), not team-colored -- it's only ever used for that
    same unarmored-civilian case, matching build_torso_parts/
    build_skirt_parts' own faction=False for the same character. "skin"
    is bare arms -- textured hide by default, or (`textured=False`, see
    build_torso_parts' own docstring) the SAME flat `skin` material as
    the hand below, so sleeve and hand read as one consistent color
    with no texture-vs-flat mismatch between them.

    `muscles=True` (only meaningful with sleeve_material="skin" and
    textured=True) overlays a unique bicep/forearm definition texture on
    each segment's front face (mat_lib.get_muscle_face, see
    build_torso_parts' own docstring for why this can't just be part of
    the tiled hide texture)."""
    parts = []
    skin = mat_lib.get("skin")
    muscles = muscles and textured
    if sleeve_material == "chainmail":
        sleeve_mat = mat_lib.get_chainmail()
    elif sleeve_material == "skin":
        sleeve_mat = mat_lib.get_hide_textured() if textured else skin
    else:
        sleeve_mat = mat_lib.get_cloth_textured(faction=False)
    bicep_hw, forearm_hw, hand_size, hand_len, hand_width_x = arm_dims(m)
    flat_sleeve = sleeve_material == "skin" and not textured

    def _apply(obj, mat):
        if flat_sleeve:
            prim.assign_material(obj, mat)
        else:
            prim.apply_tiled_material(obj, mat, tile_size=0.035)

    for s in (-1, 1):
        tag = _tag(s)
        shoulder_z = m.shoulder_pos(s)[2]
        elbow_z = m.elbow_pos(s)[2]
        wrist_z = m.wrist_pos(s)[2]
        x = arm_x(m, s)
        overlap = bicep_hw * 0.35

        # m.shoulder_pos is only ~86% of the way up the torso (the actual
        # shoulder JOINT), well below m.z_chest_top (the top of the torso
        # mesh, 100%) -- capping the arm box there left a gap between the
        # top of the sleeve and the top of the torso with nothing in it,
        # at exactly the X position outside the torso's own width. Always
        # invisible on an armored character (the Pauldron sits right over
        # it, see build_armor_parts) but plainly visible with no armor --
        # "os bracos comecando a partir do peito nao do ombro" (user).
        # Extending the box up to z_chest_top closes it: the arm now
        # visibly starts at the actual top corner of the torso.
        upper_top_z = max(shoulder_z + overlap, m.z_chest_top)
        upper_width_mult = getattr(m.style, "upper_arm_width_mult", 1.0)
        upper = prim.box(
            f"UpperArm.{tag}", (bicep_hw * 2 * upper_width_mult, bicep_hw * 2, upper_top_z - (elbow_z - overlap)),
            (x, 0, (upper_top_z + (elbow_z - overlap)) / 2.0),
        )
        _apply(upper, sleeve_mat)
        if sleeve_material == "skin" and muscles:
            prim.tag_front_face(upper, mat_lib.get_muscle_face("bicep"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        elif sleeve_material == "skin" and bone_marks:
            prim.tag_front_face(upper, mat_lib.get_bone_face("bicep"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        parts.append((upper, B.side(B.UPPER_ARM, s)))

        lower_width_mult = getattr(m.style, "lower_arm_width_mult", 1.0)
        lower = prim.box(
            f"LowerArm.{tag}", (forearm_hw * 2 * lower_width_mult, forearm_hw * 2, (elbow_z - wrist_z) + overlap * 2),
            (x, 0, (elbow_z + wrist_z) / 2.0),
        )
        _apply(lower, sleeve_mat)
        if sleeve_material == "skin" and muscles:
            prim.tag_front_face(lower, mat_lib.get_muscle_face("forearm"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        elif sleeve_material == "skin" and bone_marks:
            prim.tag_front_face(lower, mat_lib.get_bone_face("forearm"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        parts.append((lower, B.side(B.LOWER_ARM, s)))

        # Depth (Y) stays a full cube's worth (hand_size*2); width (X, side-
        # to-side) is narrower (hand_width_x) -- read as too thick laterally
        # at a full cube; length (Z) is half a cube (hand_len). depth_mult/
        # length_mult let the editor stretch Y/Z independently on top of
        # that baseline (default 1.0 -- every existing preset unaffected).
        hand_depth_mult = getattr(m.style, "hand_depth_mult", 1.0)
        hand_length_mult = getattr(m.style, "hand_length_mult", 1.0)
        hand_len_final = hand_len * hand_length_mult
        if getattr(m.style, "round_extremities", False):
            # A rounded knuckle-bone instead of a boxy hand -- see the
            # matching Foot branch in build_leg_parts for why (user's own
            # sketch: circles at the end of thin limb rods).
            hand_r = hand_size * 1.1
            hand = prim.uv_sphere(f"Hand.{tag}", hand_r, style.sphere_segments, style.sphere_rings,
                                   (x, 0, wrist_z - hand_r * 0.6))
        else:
            hand = prim.box(
                f"Hand.{tag}", (hand_width_x * 2, hand_size * 2 * hand_depth_mult, hand_len_final),
                (x, 0, wrist_z - hand_len_final / 2.0),
            )
        prim.assign_material(hand, skin)
        parts.append((hand, B.side(B.HAND, s)))

    return parts


def build_leg_parts(m, style, mat_lib, sleeve_material="chainmail", foot_material="leather", muscles=False,
                     textured=True, bone_marks=False):
    """Legs attach BELOW the torso, centered under each half of it (not
    spread out to its sides) -- each leg's outer edge lines up with the
    torso's own outer edge. Calf is thicker than thigh, and the foot is a
    genuinely chunky square block thicker than the calf -- all the
    opposite of the first pass, per reference.

    `sleeve_material`/`textured` -- see build_arm_parts docstring, same
    civilian/flat-vs-hide override. `muscles` -- see build_arm_parts
    docstring, same idea (thigh/calf definition instead of bicep/
    forearm), also ignored when `textured=False`.

    `foot_material="skin"` gives a bare foot (skin material, textured or
    flat per `textured` + a small toenail texture on the front/toe face
    always, see style.textures.build_foot_nail_image) instead of a
    leather boot -- a species that goes barefoot (goblin), not just
    civilian vs. soldier."""
    parts = []
    leather = mat_lib.get_leather_textured()
    muscles = muscles and textured
    if sleeve_material == "chainmail":
        sleeve_mat = mat_lib.get_chainmail()
    elif sleeve_material == "skin":
        sleeve_mat = mat_lib.get_hide_textured() if textured else mat_lib.get("skin")
    else:
        sleeve_mat = mat_lib.get_cloth_textured(faction=False)
    flat_sleeve = sleeve_material == "skin" and not textured
    torso_hw, _ = torso_dims(m)

    lower_leg_scale = 0.90  # uniform thinning -- keeps calf/foot proportion to each other unchanged
    if getattr(m.style, "slim_build", False):
        # See chest_dims/arm_dims docstrings -- calf thicker than thigh is
        # itself part of the "built" read; a slim build gives both the
        # same uniform thickness instead.
        thigh_hw = calf_hw = torso_hw * 0.50 * lower_leg_scale
    else:
        thigh_hw = torso_hw * 0.46
        calf_hw = torso_hw * 0.54 * lower_leg_scale       # thicker than the thigh
    # foot_size derives from torso_hw BEFORE limb_slenderness below (same
    # reasoning as arm_dims' hand_size) -- see HumanoidStyle.
    # limb_slenderness's own docstring.
    foot_size = torso_hw * 0.60 * lower_leg_scale     # a true cube -- equal on every side, centered under the ankle
    leg_slenderness = getattr(m.style, "limb_slenderness", 1.0)
    thigh_hw *= leg_slenderness
    calf_hw *= leg_slenderness

    for s in (-1, 1):
        tag = _tag(s)
        hip_z = m.hip_pos(s)[2]
        knee_z = m.knee_pos(s)[2]
        ankle_z = m.ankle_pos(s)[2]
        x = leg_x(m, s)
        overlap = calf_hw * 0.35

        thigh_width_mult = getattr(m.style, "upper_leg_width_mult", 1.0)
        thigh = prim.box(
            f"UpperLeg.{tag}", (thigh_hw * 2 * thigh_width_mult, thigh_hw * 2, (hip_z - knee_z) + overlap * 2),
            (x, 0, (hip_z + knee_z) / 2.0),
        )
        if flat_sleeve:
            prim.assign_material(thigh, sleeve_mat)
        else:
            prim.apply_tiled_material(thigh, sleeve_mat, tile_size=0.035)
        if sleeve_material == "skin" and muscles:
            prim.tag_front_face(thigh, mat_lib.get_muscle_face("thigh"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        elif sleeve_material == "skin" and bone_marks:
            prim.tag_front_face(thigh, mat_lib.get_bone_face("thigh"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        parts.append((thigh, B.side(B.UPPER_LEG, s)))

        calf_width_mult = getattr(m.style, "lower_leg_width_mult", 1.0)
        calf = prim.box(
            f"LowerLeg.{tag}", (calf_hw * 2 * calf_width_mult, calf_hw * 2, (knee_z - ankle_z) + overlap * 2),
            (x, 0, (knee_z + ankle_z) / 2.0),
        )
        if flat_sleeve:
            prim.assign_material(calf, sleeve_mat)
        else:
            prim.apply_tiled_material(calf, sleeve_mat, tile_size=0.035)
        if sleeve_material == "skin" and muscles:
            prim.tag_front_face(calf, mat_lib.get_muscle_face("calf"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        elif sleeve_material == "skin" and bone_marks:
            prim.tag_front_face(calf, mat_lib.get_bone_face("calf"), front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
        parts.append((calf, B.side(B.LOWER_LEG, s)))

        # Width/depth ("grossura") stay a full cube's worth (foot_size*2);
        # length ("comprimento", the vertical extent) is half that.
        # foot_width_mult stretches X independently (default 1.0, square).
        round_extremities = getattr(m.style, "round_extremities", False)
        foot_width_mult = getattr(m.style, "foot_width_mult", 1.0)
        foot_len = foot_size + overlap
        if round_extremities:
            # A rounded knuckle-bone instead of a boxy foot -- "maos/pes
            # arredondados" (user's own sketch: circles at the end of thin
            # limb rods, not boxes). No toenail texture on this shape
            # (tag_front_face would grab one tiny sliver of the sphere,
            # not a real "front face" the way it does on a box) -- a bone
            # foot has no nails anyway.
            foot_r = foot_size * 1.1
            foot = prim.uv_sphere(f"Foot.{tag}", foot_r, style.sphere_segments, style.sphere_rings,
                                   (x, 0, m.z_ground + foot_r * 0.75))
            prim.assign_material(foot, mat_lib.get("skin") if foot_material == "skin" else leather)
        else:
            foot = prim.box(
                f"Foot.{tag}", (foot_size * 2 * foot_width_mult, foot_size * 2, foot_len),
                (x, 0, m.z_ground + foot_len / 2.0),
            )
            if foot_material == "skin":
                skin_color = mat_lib.skin_color_override or FIXED_COLORS["skin"]
                if textured:
                    prim.apply_tiled_material(foot, mat_lib.get_hide_textured(), tile_size=0.035)
                else:
                    prim.assign_material(foot, mat_lib.get("skin"))
                nail_image = textures.build_foot_nail_image(f"NailTex_{mat_lib.civilization}_{tag}", skin_color)
                nail_mat = textures.build_face_material(f"NailMat_{mat_lib.civilization}_{tag}", nail_image)
                prim.tag_front_face(foot, nail_mat, front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0))
            else:
                prim.apply_tiled_material(foot, leather, tile_size=0.04)
        parts.append((foot, B.side(B.FOOT, s)))

    return parts
