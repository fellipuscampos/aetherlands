"""
Blocky equipment: same Minecraft/Hytale box language as body_blocky.py.
Positions here are derived from the SAME local arm/leg/torso placement
formulas as body_blocky.py (not from Measurements.shoulder_pos/wrist_pos
directly) -- those functions encode the old organic-style arm position,
which body_blocky.py no longer uses, so equipment anchored to them would
float away from where the arm/hand actually is now.

Chainmail, leather, wood, and cloth all use TILED textures (see
style/textures.py) instead of a flat color: "faça o couro parecer
couro" -- flat color was the actual complaint there. Plate metal (armor,
blades) went back to a flat color on request -- the brushed-metal
texture read poorly ("ficou uma bosta") at this low-poly scale.
"""

from geometry import body_blocky as body
from geometry import primitives as prim
from rig import bones as B
from style import textures


def _tag(s):
    return "L" if s < 0 else "R"


def _hand_point(m, s):
    """(x, y, z) at the middle of the hand, matching body_blocky's actual
    arm placement -- the anchor every hand-held item should attach to.
    Uses body_blocky's own arm_dims()/arm_x() so this can never drift out
    of sync with the mesh again (it already had, twice)."""
    _, _, hand_size, hand_len, _ = body.arm_dims(m)
    x = body.arm_x(m, s)
    wrist_z = m.wrist_pos(s)[2]
    return (x, 0.0, wrist_z - hand_len / 2.0)


def build_belt_parts(m, style, mat_lib):
    """Leather belt + buckle at the waist -- factored out of
    build_armor_parts so a character with NO armor (a civilian) can still
    wear one. Everybody wears a belt; not everybody wears a cuirass. A
    plain robe with no waist definition at all read as loungewear, not
    period clothing ("parecendo um cara de moletom" -- user)."""
    parts = []
    metal = mat_lib.get_metal()
    leather = mat_lib.get_leather_textured()
    hw, hd = body.torso_dims(m)

    belt_h = (m.z_pelvis_top - m.z_hip) * 0.34
    belt = prim.box("Belt", (hw * 2.05, hd * 2.15, belt_h),
                     (0, 0, m.z_pelvis_top - belt_h * 0.5))
    prim.apply_tiled_material(belt, leather, tile_size=0.045)
    parts.append((belt, B.PELVIS))

    buckle = prim.box("BeltBuckle", (hw * 0.32, hd * 0.30, belt_h * 1.15),
                       (0, hd * 1.05, m.z_pelvis_top - belt_h * 0.5))
    prim.assign_material(buckle, metal)
    parts.append((buckle, B.PELVIS))

    return parts


def build_sash_parts(m, style, mat_lib, material="cloth", side=1):
    """A diagonal strap from one shoulder down across the torso to the
    OPPOSITE hip (a baldric/sash) -- every other equipment piece here is
    an axis-aligned box, which can't produce a tilted band; uses
    primitives.strap instead, built for exactly this ("uma faixa do
    ombro a cintura", user). Tagged to the Chest bone (a static torso
    anchor), not an arm bone -- it lies across the fixed torso, it
    shouldn't swing with the arm.

    `side=1` starts at the RIGHT shoulder and crosses to the LEFT hip;
    `-1` mirrors it."""
    parts = []
    if material == "leather":
        mat = mat_lib.get_leather_textured()
    else:
        mat = mat_lib.get_cloth_textured(faction=False)

    shoulder = m.shoulder_pos(side)
    hip_x = body.leg_x(m, -side)
    torso_hw, torso_hd = body.torso_dims(m)

    # Nudged out to the front surface (torso_hd) plus a hair more, so the
    # strap sits visibly ON TOP of the chest/belly instead of embedded
    # inside it.
    front_y = torso_hd * 1.02
    p1 = (shoulder[0], front_y, m.z_chest_top)
    p2 = (hip_x, front_y, m.z_pelvis_top)

    width = torso_hw * 0.22
    depth = torso_hd * 0.12
    sash = prim.strap("Sash", p1, p2, width, depth)
    prim.apply_tiled_material(sash, mat, tile_size=0.04)
    parts.append((sash, B.CHEST))

    return parts


def build_armor_parts(m, style, mat_lib):
    parts = []
    metal = mat_lib.get_metal()  # solid plate armor -- the brushed-metal texture read poorly at this scale
    chest_hw, chest_hd = body.chest_dims(m)

    # Covers ONLY the Chest bone's own region -- if it reached down over
    # the narrower belly/waist block too (its first version did, using
    # the same wide chest_hw the whole way down), the wide metal shell
    # would hide the waist taper underneath and the torso reads as one
    # uniform barrel again regardless of how narrow the body itself is.
    cuirass = prim.box(
        "Cuirass", (chest_hw * 2.20, chest_hd * 2.25, (m.z_chest_top - m.z_spine_top) * 1.18),
        (0, 0, (m.z_spine_top + m.z_chest_top) / 2.0),
    )
    prim.assign_material(cuirass, metal)
    parts.append((cuirass, B.CHEST))

    bicep_hw, _, _, _, _ = body.arm_dims(m)
    for s in (-1, 1):
        shoulder_x = body.arm_x(m, s)
        shoulder_z = m.shoulder_pos(s)[2]
        pad_size = bicep_hw * 2 * 1.35
        pad = prim.box(
            f"Pauldron.{_tag(s)}", (pad_size, pad_size, pad_size * 0.7),
            (shoulder_x, 0, shoulder_z + m.len_upper_arm * 0.08),
        )
        prim.assign_material(pad, metal)
        parts.append((pad, B.side(B.UPPER_ARM, s)))

    return parts


def build_skirt_parts(m, style, mat_lib, faction=True, material="cloth"):
    """A long tunic/dress hem hanging from the belt down over the thighs
    (reference: he's wearing a robe/dress, not a hip-length tunic) -- 4
    sloped cloth panels (front/back/left/right), each one continuously
    flaring from narrow at the waist to wide at the hem via
    prim.sloped_wall, not a solid box or a stack of two differently-sized
    boxes.

    Two earlier versions of this got the flare wrong for THIS game's
    steep top-down camera specifically: a single solid box reads as a
    ring/collar around the waist because its big flat TOP face is what
    the camera mostly sees from above ("parece um anel", user); breaking
    that into 4 thin vertical panels didn't fix it either, because the
    flare was still built as two stacked tiers (a narrow box on top of a
    wider one) -- the WIDER tier's flat top is exactly as visible from
    above as a solid box's, panels or not. A continuous slope has no flat
    step anywhere in between: the outward-facing surface is one slanted
    plane, so there's nothing flat pointing up at the camera except the
    hem's own thin cap edge.

    Rigid on the Pelvis bone: it hangs around the legs rather than
    deforming with them, the standard simplification for a skirt on a
    rigid low-poly rig.

    `faction=False` gives plain undyed cloth instead of the civilization
    color -- a civilian in team-colored cloth from head to toe with
    nothing else breaking it up just reads as a solid-color blob (a
    hoodie), not period clothing. Soldiers keep the team-colored version
    (default).

    `material="leather"` swaps the whole hem to leather instead of cloth
    -- a hide loincloth/apron (goblin/orc reference) rather than a woven
    tunic; ignores `faction` (leather has no team-color variant)."""
    parts = []
    cloth = mat_lib.get_leather_textured() if material == "leather" else mat_lib.get_cloth_textured(faction=faction)
    hw, hd = body.torso_dims(m)

    top_z = m.z_hip + (m.z_pelvis_top - m.z_hip) * 0.15
    knee_z = m.knee_pos(1)[2]
    bottom_z = m.z_hip - (m.z_hip - knee_z) * 0.55

    waist_hw, waist_hd = hw * 1.05, hd * 1.10
    hem_hw, hem_hd = hw * 1.38, hd * 1.43
    panel_t_waist = min(waist_hw, waist_hd) * 0.30
    panel_t_hem = min(hem_hw, hem_hd) * 0.30
    # Full width/depth, not shy of it: at 0.80 the front/back panel and
    # the side panel both stopped short of each corner, so NEITHER
    # covered it -- 4 visible open gaps ("foda que nao ta unido", user).
    # >=1.0 makes them overlap at each corner instead of leaving a gap.
    span_frac = 1.04

    def wall(name, bottom_xy, bottom_size, top_xy, top_size):
        obj = prim.sloped_wall(name, bottom_xy, bottom_size, top_xy, top_size, bottom_z, top_z)
        prim.apply_tiled_material(obj, cloth, tile_size=0.05)
        parts.append((obj, B.PELVIS))

    wall("SkirtFront",
         (0, hem_hd), (hem_hw * 2 * span_frac, panel_t_hem),
         (0, waist_hd), (waist_hw * 2 * span_frac, panel_t_waist))
    wall("SkirtBack",
         (0, -hem_hd), (hem_hw * 2 * span_frac, panel_t_hem),
         (0, -waist_hd), (waist_hw * 2 * span_frac, panel_t_waist))
    for s in (-1, 1):
        wall(f"SkirtSide.{_tag(s)}",
             (s * hem_hw, 0), (panel_t_hem, hem_hd * 2 * span_frac),
             (s * waist_hw, 0), (panel_t_waist, waist_hd * 2 * span_frac))

    return parts


def build_headband_parts(m, style, mat_lib):
    """A leather band wrapped around the head, sitting just ABOVE the eye
    texture (painted at roughly 47-69% of head height, see
    style/textures.build_head_face_image) and below the hair -- unlike
    build_helmet_parts, this is a thin band, not a shell over the whole
    head, so no need to avoid covering the face: it's positioned in the
    gap between eyebrows and hairline on purpose. A full solid ring here
    is fine (no top-down "flat shelf" concern like the skirt had) since
    the band barely projects past the head's own width."""
    parts = []
    leather = mat_lib.get_leather_textured()
    hw, hd, hh = m.head_width, m.head_depth, m.head_height
    band_h = hh * 0.14
    band_z = m.z_neck_top + hh * 0.74

    band = prim.box("Headband", (hw * 1.05, hd * 1.05, band_h), (0, 0, band_z))
    prim.apply_tiled_material(band, leather, tile_size=0.03)
    parts.append((band, B.HEAD))

    return parts


def build_debris_parts(m, style, mat_lib, torn_cloth=False, leaves=False, textured=True):
    """Real 3D debris clinging to the body -- an actual torn-cloth
    remnant and/or leaf clusters, built as GEOMETRY, not faked as a
    tiled texture pattern (see body_blocky.build_hide_image's own
    docstring for why a repeating image is the wrong tool for a one-off
    shape like a single torn hem or a leaf: it would either repeat
    every few centimeters, which reads as a fabric print, or (if the
    tile is scaled up to avoid that) stretch and blur)."""
    parts = []
    chest_hw, chest_hd = body.chest_dims(m)
    hw, hd = body.torso_dims(m)

    if torn_cloth:
        # A muted, worn gray -- NOT the leaf green or the leather brown
        # already on the body, on purpose: an earlier version used the
        # regular team-cloth material, close enough to the skin tone at
        # a glance that it barely read as a separate object.
        if textured:
            cloth_image = textures.build_leather_image("tex_torn_cloth", (0.42, 0.40, 0.36))
            cloth_mat = textures.build_tiled_material("torn_cloth_tiled", cloth_image, roughness=0.8)
        else:
            cloth_mat = mat_lib.get_torn_cloth_flat()
        # A ragged strip draped over the front of the chest -- prim.
        # wedge()'s own taper (full width at the top, narrowing to a
        # near-point lower down) reads as a frayed, torn hem instead of
        # a clean rectangle of fabric.
        #
        # Y is the load-bearing number here: an earlier version centered
        # this INSIDE the chest box's own depth (its Y ran up to 0.079,
        # short of the chest surface at chest_hd=0.098) -- entirely
        # hidden behind/inside the solid chest, invisible from every
        # angle. Center it a half-thickness PAST the chest's own front
        # surface instead so it visibly protrudes.
        strip_w = chest_hw * 0.85
        strip_d = chest_hd * 0.6
        strip_h = (m.z_chest_top - m.z_spine_top) * 1.5
        strip_y = chest_hd + strip_d * 0.5
        strip = prim.wedge(
            "TornCloth", (strip_w, strip_d, strip_h),
            (-chest_hw * 0.1, strip_y, m.z_chest_top - strip_h * 0.35), taper=0.15,
        )
        if textured:
            prim.apply_tiled_material(strip, cloth_mat, tile_size=0.05)
        else:
            prim.assign_material(strip, cloth_mat)
        parts.append((strip, B.CHEST))

    if leaves:
        leaf_mat = mat_lib.get_leaf()
        # On TOP of the head (Head bone), not the shoulder -- an earlier
        # version put them at the chest/shoulder line, which is exactly
        # where the Neck and Head sit: verified with a direct world-
        # space bounding-box dump (not by eyeballing a render) that the
        # leaves were mostly EMBEDDED in the chest box or occluded by
        # the much-wider head sitting right above them. The top of the
        # head has nothing else there (hair is off for this species,
        # see `hair` equipment flag) -- unoccluded from every angle, and
        # matches the reference image's own most distinctive feature
        # (leaf/spike tufts on top of the head).
        hw_head, hd_head, hh_head = m.head_width, m.head_depth, m.head_height
        head_top_z = m.z_neck_top + hh_head
        leaf_w, leaf_d, leaf_h = hw_head * 0.16, hd_head * 0.30, hw_head * 0.9
        for i, (lx, ly, scale) in enumerate((
            (-hw_head * 0.28, 0.0, 1.0),
            (0.0, hd_head * 0.05, 0.8),
            (hw_head * 0.28, -hd_head * 0.05, 0.65),
        )):
            leaf = prim.wedge(
                f"LeafHead{i}", (leaf_w * scale, leaf_d * scale, leaf_h * scale),
                (lx, ly, head_top_z + leaf_h * scale * 0.5), taper=0.03,
            )
            prim.assign_material(leaf, leaf_mat)
            parts.append((leaf, B.HEAD))

        # Hip leaf: pushed OUT past the torso's own half-width (not a
        # fraction of it) so it clears the leg/torso silhouette from the
        # side instead of embedding into the pelvis block.
        hip_leaf_w, hip_leaf_d, hip_leaf_h = hw * 0.28, hd * 0.5, hw * 0.7
        hip_x = hw + hip_leaf_w * 0.5
        hip_leaf = prim.wedge(
            "LeafHip", (hip_leaf_w, hip_leaf_d, hip_leaf_h),
            (hip_x, 0.0, m.z_pelvis_top - hip_leaf_h * 0.2), taper=0.04,
        )
        prim.assign_material(hip_leaf, leaf_mat)
        parts.append((hip_leaf, B.PELVIS))

    return parts


def build_helmet_parts(m, style, mat_lib, material="metal"):
    """A real kettle-helmet silhouette (dome + wide brim), not a box
    bigger than the head in every direction -- that first version's
    "shell" was sized hh*1.10 tall centered low enough to cover the WHOLE
    head including the face, so the painted eyes/nose/mouth were sitting
    right behind a wider, closer, opaque box and never had a chance to
    show. The dome now starts at brow height (well above where the eye
    texture is painted) and only covers up from there; a wide brim marks
    that boundary, like the reference's rounded war-hat. The mail coif
    hangs below and around the BACK and sides, in the same chainmail
    texture as the arms/legs, rising all the way up to meet the dome's
    own bottom edge (brow_z) -- they sit at the temple (hw*0.52 out from
    center), well outside the front-face eye texture (~hw*0.19 out), so
    there's no risk of covering the eyes by going that high. Stopping
    short used to leave a bare patch of skin on the side of the head
    between the coif and the dome.

    `material="leather"` -- a snug leather skullcap instead: NO brim at
    all (a brim is what makes this read as a war-HAT, not a helmet --
    "capacete nao chapeu", user) and leather instead of chainmail for the
    back/cheek wrap. Every other proportion (brow_z, dome size, coif
    coverage) stays identical, just without the brim and in a different
    material."""
    parts = []
    metal = mat_lib.get_metal()  # solid plate armor
    chainmail = mat_lib.get_chainmail()
    leather = mat_lib.get_leather_textured()
    is_leather = material == "leather"
    dome_mat = leather if is_leather else metal
    wrap_mat = leather if is_leather else chainmail
    hw, hd, hh = m.head_width, m.head_depth, m.head_height

    # The face texture's eyes sit at ~47%-69% of head height (see
    # style/textures.py) -- the helmet must start ABOVE that.
    brow_z = m.z_neck_top + hh * 0.74
    dome_top_z = m.z_neck_top + hh * 1.08
    dome_h = dome_top_z - brow_z
    dome = prim.box("HelmetDome", (hw * 1.04, hd * 1.04, dome_h),
                     (0, 0, (dome_top_z + brow_z) / 2.0))
    if is_leather:
        prim.apply_tiled_material(dome, dome_mat, tile_size=0.04)
    else:
        prim.assign_material(dome, dome_mat)
    parts.append((dome, B.HEAD))

    if not is_leather:
        brim = prim.box("HelmetBrim", (hw * 1.42, hd * 1.42, hh * 0.07),
                         (0, 0, brow_z))
        prim.assign_material(brim, metal)
        parts.append((brim, B.HEAD))

    # Coif back can rise all the way to the brim (it's behind the head,
    # never occludes the face); cheek panels stop at jaw height so they
    # frame the face instead of covering the eyes.
    back_h = brow_z - m.z_chest_top
    coif_back = prim.box("CoifBack", (hw * 1.10, hd * 0.32, back_h),
                          (0, -hd * 0.46, (brow_z + m.z_chest_top) / 2.0))
    prim.apply_tiled_material(coif_back, wrap_mat, tile_size=0.04 if is_leather else 0.03)
    parts.append((coif_back, B.HEAD))

    cheek_top = brow_z  # meets the dome's bottom edge exactly -- no gap of exposed skin on the side
    cheek_h = cheek_top - m.z_chest_top
    for s in (-1, 1):
        # Full head depth (hd*1.0, not the old hd*0.62) -- anything less
        # left a sliver of bare skin between the panel and the front edge
        # of the head, at the temple/sideburn.
        cheek = prim.box(f"Coif.{_tag(s)}", (hw * 0.20, hd * 1.02, cheek_h),
                          (s * hw * 0.52, 0, (cheek_top + m.z_chest_top) / 2.0))
        prim.apply_tiled_material(cheek, wrap_mat, tile_size=0.04 if is_leather else 0.03)
        parts.append((cheek, B.HEAD))

    return parts


def build_gloves_parts(m, style, mat_lib):
    """Gauntlet boxes worn OVER the hand -- leather (per reference), kept
    as separate equipment (not a hand recolor) so bare-handed classes/
    races stay possible."""
    parts = []
    leather = mat_lib.get_leather_textured()
    _, _, hand_size, hand_len, hand_width_x = body.arm_dims(m)
    # Mirror the same depth/length stretch build_arm_parts applies to the
    # hand itself (see body_blocky.py), or a hand stretched via the
    # asset-factory editor would poke out of an unstretched glove.
    hand_size_scaled = hand_size * getattr(style, "hand_depth_mult", 1.0)
    hand_len_scaled = hand_len * getattr(style, "hand_length_mult", 1.0)

    for s in (-1, 1):
        hand = _hand_point(m, s)
        glove = prim.box(
            f"Glove.{_tag(s)}", (hand_width_x * 2 * 1.14, hand_size_scaled * 2 * 1.14, hand_len_scaled * 1.14),
            hand,
        )
        prim.apply_tiled_material(glove, leather, tile_size=0.03)
        parts.append((glove, B.side(B.HAND, s)))

    return parts


def build_shield_parts(m, style, mat_lib):
    parts = []
    hand = _hand_point(m, -1)
    radius = m.head_width * 0.62
    center = (hand[0] - m.hand_width * 0.7, hand[1], hand[2])
    metal = mat_lib.get_metal()

    rim = prim.hex_prism("ShieldRim", radius, m.hand_depth * 0.9, center, segments=style.hex_segments)
    prim.assign_material(rim, metal)
    parts.append((rim, B.side(B.HAND, -1)))

    field_cloth = mat_lib.get_cloth_textured(faction=True)
    field = prim.hex_prism("ShieldField", radius * 0.8, m.hand_depth * 0.95,
                            (center[0] - m.hand_depth * 0.05, center[1], center[2]),
                            segments=style.hex_segments)
    prim.apply_tiled_material(field, field_cloth, tile_size=0.05)
    parts.append((field, B.side(B.HAND, -1)))

    return parts


def build_halberd_parts(m, style, mat_lib):
    """Poleaxe: long wooden shaft gripped in one hand (rigid single-hand
    attachment, same as the sword -- true two-handed IK is out of scope
    for a rigid low-poly rig), an axe blade to one side near the top, a
    hook/beak on the other side, and a spike at the very top."""
    parts = []
    wood = mat_lib.get_wood_textured()
    metal = mat_lib.get_metal()
    # _hand_point sits exactly in the arm's own sagittal plane (y=0), which
    # put the shaft dead-center through the thigh/calf in side view -- not
    # "gripped", just clipping through the leg. Holding a real polearm
    # brings it out in front of the body; nudge forward by roughly the
    # torso's own depth so the shaft clears the leg silhouette instead of
    # slicing through it.
    hand = _hand_point(m, 1)
    _, torso_hd = body.torso_dims(m)
    hand = (hand[0], hand[1] + torso_hd * 1.15, hand[2])

    shaft_len = m.style.height * 1.55
    below = shaft_len * 0.15
    bottom_z = hand[2] - below
    top_z = bottom_z + shaft_len
    shaft_hw = m.hand_width * 0.16

    shaft = prim.box("HalberdShaft", (shaft_hw * 2, shaft_hw * 2, shaft_len),
                      (hand[0], hand[1], (bottom_z + top_z) / 2.0))
    prim.apply_tiled_material(shaft, wood, tile_size=0.04)
    parts.append((shaft, B.side(B.HAND, 1)))

    blade_w = m.head_width * 0.95
    blade_h = m.head_height * 0.55
    blade_z = top_z - blade_h * 0.7
    blade = prim.box("HalberdBlade", (blade_w, shaft_hw * 1.8, blade_h),
                      (hand[0] - blade_w * 0.34, hand[1], blade_z))
    prim.assign_material(blade, metal)
    parts.append((blade, B.side(B.HAND, 1)))

    hook = prim.wedge("HalberdHook", (m.head_width * 0.32, shaft_hw * 1.7, m.head_height * 0.24),
                       (hand[0] + m.head_width * 0.24, hand[1], blade_z + blade_h * 0.05), taper=0.25)
    prim.assign_material(hook, metal)
    parts.append((hook, B.side(B.HAND, 1)))

    spike = prim.wedge("HalberdSpike", (shaft_hw * 1.7, shaft_hw * 1.7, m.head_height * 0.42),
                        (hand[0], hand[1], top_z + m.head_height * 0.21), taper=0.08)
    prim.assign_material(spike, metal)
    parts.append((spike, B.side(B.HAND, 1)))

    return parts


def build_staff_parts(m, style, mat_lib):
    """Plain wooden walking staff -- the Colonizador's tool, not a weapon:
    same rigid single-hand shaft as the halberd (see build_halberd_parts)
    but no blade/hook/spike, just a small knob on top so the silhouette
    doesn't read as a bare stick floating in the hand.

    Tilted, not vertical: the bottom trails BACKWARD (-Y) and down to the
    ground behind his heel, and the top reaches FORWARD (+Y) and up past
    the front of his body, crossing through the grip -- like a staff
    carried resting diagonally across the body at ease, not held bolt
    upright (user's own description, after a sketch and a follow-up
    question). Built as TWO prim.sloped_wall segments (below-the-grip and
    above-the-grip), not one continuous straight rod: the long
    below-segment (reaching the ground, `below = hand[2] - m.z_ground`)
    uses a gentler slope than the short above-segment, so reaching the
    ground doesn't ALSO sprawl the tip far sideways -- only the short
    overhang above the grip keeps the dramatic forward lean the user
    approved for the earlier, shorter version ("isso porra"). Both
    segments meet exactly at the hand's own (x,y,z), so the grip point
    itself doesn't move and the shaft still passes through the Hand
    box's own center instead of floating off to one side of it ("eu
    quero o cajado dentro da mao do boneco", user -- a real, separately-
    fixed bug from an earlier version)."""
    parts = []
    wood = mat_lib.get_wood_textured()
    hand = _hand_point(m, 1)

    # Below reaches the actual ground now ("faca tocando o chao tambem",
    # user) -- above stays a short overhang, not a tall cajado reaching
    # past the head, to keep the OVERALL piece small ("a vareta menor").
    # Two separate segments (not one straight prism through the grip)
    # with different tilt slopes: the long below segment uses a gentler
    # slope so reaching all the way to the ground doesn't also sprawl it
    # far sideways -- only the short above segment keeps the dramatic
    # forward lean the user approved ("isso porra"). They still meet
    # exactly at the hand's own (x,y,z), so the grip itself doesn't move.
    below = hand[2] - m.z_ground
    above = m.head_height * 0.30
    bottom_z = m.z_ground
    top_z = hand[2] + above
    staff_hw = m.hand_width * 0.12  # slightly thinner too -- "menor"

    below_slope = 0.35
    above_slope = 1.3
    bottom_y = hand[1] - below_slope * below
    top_y = hand[1] + above_slope * above

    lower_shaft = prim.sloped_wall(
        "StaffShaftLower",
        (hand[0], bottom_y), (staff_hw * 2, staff_hw * 2),
        (hand[0], hand[1]), (staff_hw * 2, staff_hw * 2),
        bottom_z, hand[2],
    )
    prim.apply_tiled_material(lower_shaft, wood, tile_size=0.04)
    parts.append((lower_shaft, B.side(B.HAND, 1)))

    upper_shaft = prim.sloped_wall(
        "StaffShaftUpper",
        (hand[0], hand[1]), (staff_hw * 2, staff_hw * 2),
        (hand[0], top_y), (staff_hw * 2, staff_hw * 2),
        hand[2], top_z,
    )
    prim.apply_tiled_material(upper_shaft, wood, tile_size=0.04)
    parts.append((upper_shaft, B.side(B.HAND, 1)))

    knob = prim.uv_sphere("StaffKnob", staff_hw * 2.1, 6, 4, (hand[0], top_y, top_z))
    prim.apply_tiled_material(knob, wood, tile_size=0.04)
    parts.append((knob, B.side(B.HAND, 1)))

    return parts


def build_pack_parts(m, style, mat_lib):
    """A travel sack strapped to the back -- the Colonizador carries his
    own supplies to found a city with, unlike the soldiers who only carry
    weapons. Rigid on the Chest bone, offset behind the body (negative Y,
    the established "front" is +Y -- see render.py's front camera)."""
    parts = []
    leather = mat_lib.get_leather_textured()
    hw, hd = body.torso_dims(m)

    # Spans the Chest AND Spine bone's own height (not just Chest's, which
    # is only the top third of the torso) -- a bindle sized to just the
    # Chest region read as a barely-visible ledge on the shoulder instead
    # of an actual sack. Rigid-bound to Chest only regardless (single
    # vertex group, same simplification as every other equipment box) --
    # riding a bit loose over the Spine's own animated region is an
    # acceptable trade for actually reading as a pack.
    pack_w = hw * 1.15
    pack_h = (m.z_chest_top - m.z_pelvis_top) * 1.05
    pack_d = hd * 1.1
    center_y = -(hd + pack_d * 0.5) * 0.92
    center_z = (m.z_pelvis_top + m.z_chest_top) / 2.0

    # Leather, not the tunic's own cloth -- same color as the tunic made
    # the sack disappear into the robe's silhouette from every angle.
    sack = prim.box("PackSack", (pack_w, pack_d, pack_h), (0, center_y, center_z))
    prim.apply_tiled_material(sack, leather, tile_size=0.05)
    parts.append((sack, B.CHEST))

    roll = prim.box("PackBedroll", (pack_w * 1.08, pack_d * 0.55, pack_h * 0.22),
                     (0, center_y, center_z + pack_h * 0.5 + pack_h * 0.11))
    prim.apply_tiled_material(roll, leather, tile_size=0.04)
    parts.append((roll, B.CHEST))

    strap_w = hw * 0.16
    for s in (-1, 1):
        strap = prim.box(f"PackStrap.{_tag(s)}", (strap_w, hd * 2.1, pack_h * 0.85),
                          (s * hw * 0.55, 0, center_z + pack_h * 0.05))
        prim.apply_tiled_material(strap, leather, tile_size=0.03)
        parts.append((strap, B.CHEST))

    return parts


def build_club_parts(m, style, mat_lib):
    """Simple wooden cudgel: narrow grip inside the fist, widening into a
    chunky head that hangs DOWN from the hand -- the natural direction
    for a blunt weapon on an arm resting at the character's side (an
    earlier version grew it UPWARD from the grip instead, straight back
    along the same line as the forearm, so the whole club sat hidden
    behind/inside the much wider forearm box -- verified by dumping its
    world-space bounding box, not just re-rendering and guessing).
    prim.wedge's taper narrows going up by default, matching this
    grip-on-top/head-on-bottom shape directly (size = the wide BOTTOM/
    head, taper<1 shrinks to the grip at top) -- kept as one tapered box,
    not a rounded prim.cone, to match the all-box "blocky" language
    every other weapon here uses."""
    parts = []
    wood = mat_lib.get_wood_textured()
    hand = _hand_point(m, 1)

    grip_w = m.hand_width * 0.34
    head_w = m.hand_width * 0.90
    forearm_len = m.elbow_pos(1)[2] - m.wrist_pos(1)[2]
    club_len = forearm_len * 0.9
    # A little grip sits ABOVE the hand's own center, inside the fist
    # (same "seat part of the handle in the hand" convention as
    # SwordHandle/guard_z above); the head hangs below that.
    top_z = hand[2] + m.len_hand * 0.15
    bottom_z = top_z - club_len

    club = prim.wedge("Club", (head_w, head_w, club_len),
                       (hand[0], hand[1], (top_z + bottom_z) / 2.0), taper=grip_w / head_w)
    prim.apply_tiled_material(club, wood, tile_size=0.05)
    parts.append((club, B.side(B.HAND, 1)))

    return parts


def build_troll_club_parts(m, style, mat_lib):
    """A big spiked log club -- same tapered-box shape and downward-
    hanging orientation as build_club_parts (see its own docstring for
    why: hangs AWAY from the forearm, not back into it), scaled up for a
    much bigger creature, with a handful of thin spikes (primitives.strap
    -- a box between two arbitrary points, so each one can radiate
    outward from the club's own surface at its own angle, unlike
    prim.wedge which only tapers straight along its own local Z) poking
    out near the wide end. Matches the reference image's spiked-log
    troll club."""
    import math

    parts = []
    wood = mat_lib.get_wood_textured()
    hand = _hand_point(m, 1)

    grip_w = m.hand_width * 0.34
    head_w = m.hand_width * 1.05
    forearm_len = m.elbow_pos(1)[2] - m.wrist_pos(1)[2]
    club_len = forearm_len * 1.35
    top_z = hand[2] + m.len_hand * 0.15
    bottom_z = top_z - club_len

    club = prim.wedge("TrollClub", (head_w, head_w, club_len),
                       (hand[0], hand[1], (top_z + bottom_z) / 2.0), taper=grip_w / head_w)
    prim.apply_tiled_material(club, wood, tile_size=0.06)
    parts.append((club, B.side(B.HAND, 1)))

    # Kept SHORT on purpose: these radiate sideways off the club, which
    # sits well away from the body's own centerline -- a long spike here
    # blows out the WHOLE character's horizontal footprint (X/Z aabb)
    # far more than its own small size suggests, making the model read
    # as "massive" even when its actual standing HEIGHT is correct (a
    # real bug found this way: model_scale_multiplier only normalizes by
    # aabb.size.Y, so the width of a wide sideways sword sticking out
    # made it LOOK gigantic despite being scaled to the right height).
    spike_len = head_w * 0.55
    spike_w = head_w * 0.14
    for i, (frac, ang) in enumerate((
        (0.10, 0.0), (0.10, math.pi), (0.28, math.pi / 2), (0.28, -math.pi / 2),
        (0.46, math.pi / 4), (0.46, math.pi + math.pi / 4),
    )):
        z = bottom_z + club_len * frac
        local_half = (head_w + (grip_w - head_w) * (frac)) / 2.0  # taper is linear bottom(head_w)->top(grip_w)
        dir_x, dir_y = math.cos(ang), math.sin(ang)
        p1 = (hand[0] + dir_x * local_half * 0.6, hand[1] + dir_y * local_half * 0.6, z)
        p2 = (hand[0] + dir_x * (local_half + spike_len), hand[1] + dir_y * (local_half + spike_len), z)
        spike = prim.strap(f"ClubSpike{i}", p1, p2, spike_w, spike_w)
        prim.assign_material(spike, wood)
        parts.append((spike, B.side(B.HAND, 1)))

    return parts


def build_sword_parts(m, style, mat_lib):
    """Blade points DOWN from the grip, away from the forearm -- an
    earlier version grew the handle/guard/blade UPWARD from the hand
    instead, straight back along the same vertical column the (unbent,
    per this rig) forearm already occupies, so the entire sword sat
    hidden behind/inside it: verified by dumping its world-space
    bounding box (SwordHandle/Guard both fell squarely inside the
    forearm's own Z range) rather than re-rendering and guessing. Same
    root cause and fix as build_club_parts' own history."""
    parts = []
    hand = _hand_point(m, 1)
    grip_len = m.len_hand * 1.1
    metal = mat_lib.get_metal()
    wood = mat_lib.get_wood_textured()

    # A little of the grip sits ABOVE the hand's own center, inside the
    # fist (same convention as build_club_parts' top_z); guard and blade
    # hang below that.
    top_z = hand[2] + m.len_hand * 0.15
    guard_z = top_z - grip_len

    handle = prim.box("SwordHandle", (m.hand_width * 0.30, m.hand_width * 0.30, grip_len),
                       (hand[0], hand[1], (top_z + guard_z) / 2.0))
    prim.apply_tiled_material(handle, wood, tile_size=0.02)
    parts.append((handle, B.side(B.HAND, 1)))

    guard = prim.box("SwordGuard", (m.hand_width * 1.0, m.hand_depth * 0.4, m.hand_depth * 0.22),
                      (hand[0], hand[1], guard_z))
    prim.assign_material(guard, metal)
    parts.append((guard, B.side(B.HAND, 1)))

    blade_len = m.len_upper_arm * 1.15
    blade = prim.box("SwordBlade", (m.hand_width * 0.34, m.hand_depth * 0.16, blade_len),
                      (hand[0], hand[1], guard_z - blade_len / 2.0))
    prim.assign_material(blade, metal)
    parts.append((blade, B.side(B.HAND, 1)))

    return parts
