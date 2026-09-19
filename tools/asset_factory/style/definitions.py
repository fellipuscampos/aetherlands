"""
StyleDefinition hierarchy: the shared "visual language" every generated
asset must obey. This is the only place topology budgets, primitive
resolutions and body proportions should be tuned — generators read these
numbers instead of hard-coding their own.

Hierarchy:
    FantasyStyle        - global low-poly rules (poly budgets, primitive
                           resolution, shading, material defaults)
    HumanoidStyle        - adds bipedal proportion ranges shared by every
                           two-armed/two-legged race
    HumanStyle           - human-specific proportion tuning
    (OrcStyle/ElfStyle/... subclass HumanoidStyle the same way in the future)
"""

from dataclasses import dataclass, field
from typing import Dict


@dataclass
class FantasyStyle:
    """Global rules every generated asset (any species/class) must follow."""

    name: str = "fantasy_base"

    # --- primitive resolution: keep these LOW. A stylized cylinder does not
    # need 32 sides, a stylized sphere does not need high subdivision. ---
    cylinder_segments: int = 8
    sphere_segments: int = 10     # longitude subdivisions of low-poly UV sphere
    sphere_rings: int = 5         # latitude subdivisions of low-poly UV sphere
    hex_segments: int = 6         # shields/plates that read as "hexagonal" -- stays a hexagon on purpose

    # --- topology hygiene switches: OFF by default, on this project ---
    use_bevel: bool = False
    bevel_width: float = 0.0
    bevel_segments: int = 0
    use_subdivision: bool = False
    shade_smooth: bool = False    # flat shading everywhere -> strong silhouette

    # --- explicit polygon budget per component (triangles, approximate).
    # V2 values: "low-poly, not low-detail" -- lofted multi-ring meshes cost
    # more than V1's single primitives, on purpose. ---
    poly_budget: Dict[str, int] = field(default_factory=lambda: {
        "head": 220,      # skull loft + ears + hair + eyes/brows/nose
        "torso": 360,     # pelvis + spine + chest lofts
        "pelvis": 60,
        "arm": 220,       # per arm (shoulder+upper+lower+hand)
        "leg": 260,       # per leg (thigh+calf+boot)
        "armor": 320,
        "helmet": 180,
        "weapon": 140,
        "shield": 90,
        "accessory": 40,
    })

    # --- material defaults (PBR-ish, but flat/stylized) ---
    saturation: float = 0.72
    roughness_cloth: float = 0.85
    roughness_leather: float = 0.75
    roughness_metal: float = 0.35
    roughness_skin: float = 0.6
    roughness_wood: float = 0.8
    metallic_metal: float = 0.75
    metallic_default: float = 0.0

    def total_poly_budget(self) -> int:
        return sum(self.poly_budget.values())


@dataclass
class HumanoidStyle(FantasyStyle):
    """Shared bipedal proportion language for every two-legged race."""

    name: str = "humanoid_base"

    # proportions expressed as fractions of total standing height, so every
    # race can be derived by nudging a handful of numbers.
    height: float = 1.8
    head_height_ratio: float = 0.150
    neck_height_ratio: float = 0.050
    torso_height_ratio: float = 0.240
    # Fraction of torso_height_ratio's span given to the "belly" (Spine
    # bone, body_blocky.py's waist block) vs the rest going to the chest
    # (Chest bone) -- see character/params.py compute_measurements. 0.42
    # (every human preset so far) was baked in directly until a request
    # to shorten JUST the belly, not the chest, needed them decoupled:
    # torso_height_ratio alone scales both proportionally together.
    belly_fraction: float = 0.42
    # Belly/Spine block width as a fraction of the pelvis's own width
    # (which it matches exactly by default -- see body_blocky.py
    # build_torso_parts' own comment on why: narrower reads as flared
    # hips on a normal build). A species whose waist should read as
    # something else entirely (a Skeleton's spine, a thin post connecting
    # ribcage to pelvis) overrides this instead. 1.0 default keeps every
    # existing preset's belly pixel-identical.
    belly_width_mult: float = 1.0
    pelvis_height_ratio: float = 0.100
    upper_leg_ratio: float = 0.235
    lower_leg_ratio: float = 0.220
    foot_height_ratio: float = 0.055
    upper_arm_ratio: float = 0.170
    lower_arm_ratio: float = 0.155
    hand_ratio: float = 0.080

    shoulder_width_ratio: float = 0.260   # half-width from spine to shoulder
    hip_width_ratio: float = 0.150
    limb_thickness: float = 1.0           # global multiplier, "chunkiness"
    torso_depth_ratio: float = 0.150
    head_width_ratio: float = 0.140
    head_depth_ratio: float = 0.140

    upper_arm_radius_ratio: float = 0.054
    lower_arm_radius_ratio: float = 0.045
    hand_width_ratio: float = 0.058
    hand_depth_ratio: float = 0.040
    # body_blocky.py's blocky engine derives the hand cube's SIZE from the
    # forearm's own thickness (forearm_hw * hand_size_ratio) rather than
    # from hand_width_ratio/hand_depth_ratio above (those two are only
    # read by the older organic v1/v2/v3 builders) -- this was a bare
    # 1.18 literal in body_blocky.arm_dims until the asset-factory editor
    # needed an actual slider for hand size. Default keeps every existing
    # preset's hands pixel-identical.
    hand_size_ratio: float = 1.18

    # --- shape multipliers: every limb segment box above is built SQUARE
    # in cross-section (X width == Y depth, both driven by the same
    # *_radius_ratio/hand_size_ratio) -- these stretch just the X (width,
    # side-to-side) or, for the hand, also Y/Z independently, without
    # touching the shared baseline. 1.0 = square, exactly today's
    # baseline; every existing preset leaves these unset and is
    # untouched. "a mao nao e quadrada, e meio retangular, mas eu nao
    # posso deixar quadrado" (user) -- this is what makes that possible,
    # for every limb segment, not just the hand.
    upper_arm_width_mult: float = 1.0
    lower_arm_width_mult: float = 1.0
    # None (not 1.0) so arm_dims() can tell "never set" apart from
    # "explicitly set to 1.0" and fall back to the old thick_hands
    # boolean's 0.75/1.2 split for every preset that predates this field.
    hand_width_mult: float = None
    hand_depth_mult: float = 1.0
    hand_length_mult: float = 1.0

    upper_leg_radius_ratio: float = 0.088
    lower_leg_radius_ratio: float = 0.068
    upper_leg_width_mult: float = 1.0
    lower_leg_width_mult: float = 1.0
    foot_width_mult: float = 1.0
    foot_length_ratio: float = 0.145
    foot_width_ratio: float = 0.065

    torso_taper: float = 0.82  # pelvis width relative to shoulder width

    # False (default) = the locked blocky baseline's "built" V-taper: wider
    # chest than waist, bicep thinner than forearm, thigh thinner than
    # calf (see body_blocky.py chest_dims/arm_dims/build_leg_parts). A
    # non-combat character can set this true in its own preset to read as
    # an ordinary slim build instead of a soldier's physique -- chest
    # matches waist width and each limb's two segments share one uniform
    # thickness. Per-character override, NOT a change to the locked
    # baseline itself (see feedback_blocky_humanoid_baseline memory).
    slim_build: bool = False

    # Independent of `slim_build` (which also flattens chest/leg
    # thickness) -- a species can have skinny, uniform-thickness arms
    # while keeping a stocky torso/legs. See body_blocky.arm_dims.
    thin_arms: bool = False

    # Opposite of the locked human baseline (which narrows hand_width_x
    # to read as slightly THINNER than the forearm, see body_blocky.
    # arm_dims) -- some species want the hand to read as visibly
    # thicker/chunkier than the forearm instead.
    thick_hands: bool = False

    # Off by default (every human preset so far). A non-human species
    # preset (goblin, elf, ...) sets this true to get build_ear_parts'
    # pointed ears -- see body_blocky.py.
    pointy_ears: bool = False

    # Swaps the Hand/Foot boxes for rounded prim.uv_sphere "knuckle
    # bones" instead -- see body_blocky.py build_arm_parts/build_leg_
    # parts. Off by default -- every existing preset keeps boxy hands/
    # feet unless it explicitly opts in.
    round_extremities: bool = False

    # Continuous thinness multiplier on the UPPER/LOWER ARM and LEG
    # segments only (not hand/foot, which stay their own size -- a
    # relatively bulkier hand/foot at the end of a thinned bone reads as
    # a joint mass, which is the point for a Skeleton). *_radius_ratio
    # above is NOT read by body_blocky.py's arm_dims()/build_leg_parts at
    # all -- the blocky engine derives bicep/forearm/thigh/calf width
    # from chest/torso width times a FIXED coefficient selected by
    # slim_build/thin_arms (3 discrete presets, no continuous knob) --
    # tuning those ratio fields silently did nothing, a real bug found
    # while trying to make a Skeleton's limbs thinner. 1.0 default keeps
    # every existing preset's limb width pixel-identical.
    limb_slenderness: float = 1.0

    angularity: float = 1.0  # 1.0 = boxy/angular, 0.0 = rounder (future races)

    # --- V2 "faceted sculpt" knobs: cross-section resolution for lofted
    # (multi-ring) meshes. Still explicit, still low, still style-shared. ---
    torso_sides: int = 12
    limb_sides: int = 8
    head_sides: int = 12
    waist_pinch: float = 0.85     # waist width relative to hip/chest (silhouette pinch)
    chest_projection: float = 1.18  # chest depth multiplier vs waist depth (pec volume)
    jaw_width_ratio: float = 0.62   # jaw width relative to cheek/eye width
    ear_size_ratio: float = 0.16    # ear size relative to head width


@dataclass
class HumanStyle(HumanoidStyle):
    """Baseline human proportions: average build, no exaggeration."""

    name: str = "human"
    height: float = 1.8
    limb_thickness: float = 1.0
    angularity: float = 0.85


DEFAULT_HUMAN_STYLE = HumanStyle()
