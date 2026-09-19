"""Canonical bone name list, shared by mesh generators (vertex group names
must match exactly) and the skeleton builder. One place to extend this for
future non-human bipeds."""

ROOT = "Root"
PELVIS = "Pelvis"
SPINE = "Spine"
CHEST = "Chest"
NECK = "Neck"
HEAD = "Head"


def side(base: str, s: int) -> str:
    return f"{base}.{'L' if s < 0 else 'R'}"


UPPER_ARM = "UpperArm"
LOWER_ARM = "LowerArm"
HAND = "Hand"
UPPER_LEG = "UpperLeg"
LOWER_LEG = "LowerLeg"
FOOT = "Foot"

HUMANOID_BONES = [
    ROOT, PELVIS, SPINE, CHEST, NECK, HEAD,
    side(UPPER_ARM, -1), side(UPPER_ARM, 1),
    side(LOWER_ARM, -1), side(LOWER_ARM, 1),
    side(HAND, -1), side(HAND, 1),
    side(UPPER_LEG, -1), side(UPPER_LEG, 1),
    side(LOWER_LEG, -1), side(LOWER_LEG, 1),
    side(FOOT, -1), side(FOOT, 1),
]

PARENT_OF = {
    PELVIS: ROOT,
    SPINE: PELVIS,
    CHEST: SPINE,
    NECK: CHEST,
    HEAD: NECK,
    side(UPPER_ARM, -1): CHEST, side(UPPER_ARM, 1): CHEST,
    side(LOWER_ARM, -1): side(UPPER_ARM, -1), side(LOWER_ARM, 1): side(UPPER_ARM, 1),
    side(HAND, -1): side(LOWER_ARM, -1), side(HAND, 1): side(LOWER_ARM, 1),
    side(UPPER_LEG, -1): PELVIS, side(UPPER_LEG, 1): PELVIS,
    side(LOWER_LEG, -1): side(UPPER_LEG, -1), side(LOWER_LEG, 1): side(UPPER_LEG, 1),
    side(FOOT, -1): side(LOWER_LEG, -1), side(FOOT, 1): side(LOWER_LEG, 1),
}
