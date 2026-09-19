"""
CharacterBuilder V3: continuous, multi-bone-blended body (geometry/body_v3.py)
+ the same rigid equipment as V2 (geometry/equipment_v2.py -- armor plates,
helmet, shield, sword, tabard, sleeves are genuinely separate rigid objects
on a real body too, so V2's approach there was already correct and is
reused unchanged). V1 and V2 stay independently runnable.

A part tuple is (object, bone_name_or_None): None means the object already
carries its own (possibly multi-bone, blended) vertex groups from
meshops.build_loft and must NOT be overwritten by the single-bone rigid
assignment used for the reused V2 equipment parts.
"""

import bpy

from character.params import compute_measurements, apply_seed_variation
from geometry import body_v3
from geometry import equipment_v2 as gear
from geometry import primitives as prim
from style.palette import MaterialLibrary


def build_character_v3(name: str, style, preset: dict, seed: int):
    civilization = preset.get("palette", {}).get("civilization", "human_default")
    mat_lib = MaterialLibrary(civilization)

    measurements = compute_measurements(style)
    apply_seed_variation(measurements, seed)

    all_parts = []
    all_parts += body_v3.build_torso_parts(measurements, style, mat_lib)
    all_parts += body_v3.build_head_parts(measurements, style, mat_lib)
    all_parts += body_v3.build_arm_parts(measurements, style, mat_lib)
    all_parts += body_v3.build_leg_parts(measurements, style, mat_lib)
    all_parts += gear.build_sleeve_parts(measurements, style, mat_lib)
    all_parts += gear.build_armor_parts(measurements, style, mat_lib)
    all_parts += gear.build_tabard_parts(measurements, style, mat_lib)

    equipment_cfg = preset.get("equipment", {})
    if equipment_cfg.get("helmet", True):
        all_parts += gear.build_helmet_parts(measurements, style, mat_lib)
    if equipment_cfg.get("shield"):
        all_parts += gear.build_shield_parts(measurements, style, mat_lib)
    if equipment_cfg.get("weapon") == "sword":
        all_parts += gear.build_sword_parts(measurements, style, mat_lib)

    for obj, bone_name in all_parts:
        if bone_name is not None:
            prim.assign_vertex_group(obj, bone_name)

    objs = [o for o, _ in all_parts]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = name
    merged.data.name = name

    tri_count = sum(max(0, len(poly.vertices) - 2) for poly in merged.data.polygons)
    stats = {
        "vertices": len(merged.data.vertices),
        "faces": len(merged.data.polygons),
        "triangles_estimate": tri_count,
        "materials": len(merged.data.materials),
    }

    return merged, measurements, mat_lib, stats
