"""
Measurements: the single source of truth for every joint position and
part dimension. Both the mesh generators (geometry/parts.py,
geometry/equipment.py) and the skeleton builder (rig/skeleton.py) derive
their numbers from this same object, so mesh and bones always line up
exactly -- no manual re-alignment step.

Built from a HumanStyle plus a seed: the seed nudges a few proportions
within small, style-bounded ranges (see `apply_seed_variation`) so
"human_guard seed 1/2/3" differ slightly without ever breaking the shared
visual language.
"""

import random
from dataclasses import dataclass, field
from typing import Tuple

Vec3 = Tuple[float, float, float]


@dataclass
class Measurements:
    style: object

    # joint heights (world Z, ground = 0)
    z_ground: float = 0.0
    z_ankle: float = 0.0
    z_knee: float = 0.0
    z_hip: float = 0.0
    z_pelvis_top: float = 0.0
    z_spine_top: float = 0.0
    z_chest_top: float = 0.0
    z_shoulder: float = 0.0
    z_neck_top: float = 0.0
    z_head_top: float = 0.0
    z_head_center: float = 0.0

    # segment lengths
    len_upper_leg: float = 0.0
    len_lower_leg: float = 0.0
    len_upper_arm: float = 0.0
    len_lower_arm: float = 0.0
    len_hand: float = 0.0
    len_foot: float = 0.0

    # widths / radii
    shoulder_x: float = 0.0     # half-width, shoulder joint offset from spine
    hip_x: float = 0.0          # half-width, hip joint offset from spine
    torso_width: float = 0.0
    torso_depth: float = 0.0
    pelvis_width: float = 0.0
    pelvis_depth: float = 0.0
    head_width: float = 0.0
    head_depth: float = 0.0
    head_height: float = 0.0
    upper_arm_radius: float = 0.0
    lower_arm_radius: float = 0.0
    hand_width: float = 0.0
    hand_depth: float = 0.0
    upper_leg_radius: float = 0.0
    lower_leg_radius: float = 0.0
    foot_width: float = 0.0
    foot_height: float = 0.0

    # arm/leg outward lean at rest pose (small, keeps limbs off torso without T-pose)
    arm_out_x: float = 0.0
    leg_out_x: float = 0.0

    def shoulder_pos(self, side: int) -> Vec3:
        return (side * self.shoulder_x, 0.0, self.z_shoulder)

    def elbow_pos(self, side: int) -> Vec3:
        sx, sy, sz = self.shoulder_pos(side)
        return (sx + side * self.arm_out_x, sy, sz - self.len_upper_arm)

    def wrist_pos(self, side: int) -> Vec3:
        ex, ey, ez = self.elbow_pos(side)
        return (ex + side * self.arm_out_x * 0.3, ey, ez - self.len_lower_arm)

    def hand_tip_pos(self, side: int) -> Vec3:
        wx, wy, wz = self.wrist_pos(side)
        return (wx, wy, wz - self.len_hand)

    def hip_pos(self, side: int) -> Vec3:
        return (side * self.hip_x, 0.0, self.z_hip)

    def knee_pos(self, side: int) -> Vec3:
        hx, hy, hz = self.hip_pos(side)
        return (hx + side * self.leg_out_x, hy, hz - self.len_upper_leg)

    def ankle_pos(self, side: int) -> Vec3:
        kx, ky, kz = self.knee_pos(side)
        return (kx, ky, kz - self.len_lower_leg)


def compute_measurements(style) -> Measurements:
    h = style.height
    m = Measurements(style=style)

    m.foot_height = h * style.foot_height_ratio
    m.len_lower_leg = h * style.lower_leg_ratio
    m.len_upper_leg = h * style.upper_leg_ratio
    pelvis_h = h * style.pelvis_height_ratio
    torso_h = h * style.torso_height_ratio
    neck_h = h * style.neck_height_ratio
    m.head_height = h * style.head_height_ratio

    m.z_ground = 0.0
    m.z_ankle = m.foot_height
    m.z_knee = m.z_ankle + m.len_lower_leg
    m.z_hip = m.z_knee + m.len_upper_leg
    m.z_pelvis_top = m.z_hip + pelvis_h
    m.z_spine_top = m.z_pelvis_top + torso_h * style.belly_fraction
    m.z_chest_top = m.z_pelvis_top + torso_h
    m.z_shoulder = m.z_pelvis_top + torso_h * 0.86
    m.z_neck_top = m.z_chest_top + neck_h
    m.z_head_top = m.z_neck_top + m.head_height
    m.z_head_center = m.z_neck_top + m.head_height * 0.5

    m.len_upper_arm = h * style.upper_arm_ratio
    m.len_lower_arm = h * style.lower_arm_ratio
    m.len_hand = h * style.hand_ratio

    m.shoulder_x = h * style.shoulder_width_ratio
    m.hip_x = h * style.hip_width_ratio
    m.torso_width = m.shoulder_x * 1.55
    m.torso_depth = h * style.torso_depth_ratio
    m.pelvis_width = m.torso_width * style.torso_taper
    m.pelvis_depth = m.torso_depth * 0.92
    m.head_width = h * style.head_width_ratio
    m.head_depth = h * style.head_depth_ratio

    m.upper_arm_radius = h * style.upper_arm_radius_ratio * style.limb_thickness
    m.lower_arm_radius = h * style.lower_arm_radius_ratio * style.limb_thickness
    m.hand_width = h * style.hand_width_ratio
    m.hand_depth = h * style.hand_depth_ratio
    m.upper_leg_radius = h * style.upper_leg_radius_ratio * style.limb_thickness
    m.lower_leg_radius = h * style.lower_leg_radius_ratio * style.limb_thickness
    m.foot_width = h * style.foot_width_ratio
    len_foot = h * style.foot_length_ratio
    m.len_foot = len_foot

    m.arm_out_x = h * 0.018
    m.leg_out_x = h * 0.006

    return m


def apply_seed_variation(measurements: Measurements, seed: int) -> Measurements:
    """Small, style-bounded per-seed variation (+/-4% on a few knobs) so
    different seeds of the same preset look like siblings, not clones."""
    rng = random.Random(seed)
    jitter = lambda v, spread=0.04: v * (1.0 + rng.uniform(-spread, spread))

    for attr in (
        "head_width", "head_depth", "head_height",
        "torso_width", "torso_depth",
        "upper_arm_radius", "lower_arm_radius",
        "upper_leg_radius", "lower_leg_radius",
    ):
        setattr(measurements, attr, jitter(getattr(measurements, attr)))
    return measurements
