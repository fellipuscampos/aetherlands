"""
CharacterBuilder V2: same contract as character/builder.py (V1) --
(StyleDefinition, preset dict, seed) in, one joined rigid-vertex-grouped
mesh object out -- but sourcing geometry from the V2 loft-based
generators (geometry/body_v2.py, geometry/equipment_v2.py) instead of
V1's single-primitive parts. V1 stays untouched and independently
runnable; this is a parallel path, not a replacement.
"""

import bpy

from character.params import compute_measurements, apply_seed_variation
from geometry import body_v2
from geometry import equipment_v2 as gear_v2
from geometry import primitives as prim
from style.palette import MaterialLibrary


def build_character_v2(name: str, style, preset: dict, seed: int):
    civilization = preset.get("palette", {}).get("civilization", "human_default")
    mat_lib = MaterialLibrary(civilization)

    measurements = compute_measurements(style)
    apply_seed_variation(measurements, seed)

    all_parts = []
    all_parts += body_v2.build_torso_parts(measurements, style, mat_lib)
    all_parts += body_v2.build_head_parts(measurements, style, mat_lib)
    all_parts += body_v2.build_arm_parts(measurements, style, mat_lib)
    all_parts += body_v2.build_leg_parts(measurements, style, mat_lib)
    all_parts += gear_v2.build_sleeve_parts(measurements, style, mat_lib)
    all_parts += gear_v2.build_armor_parts(measurements, style, mat_lib)
    all_parts += gear_v2.build_tabard_parts(measurements, style, mat_lib)

    equipment_cfg = preset.get("equipment", {})
    if equipment_cfg.get("helmet", True):
        all_parts += gear_v2.build_helmet_parts(measurements, style, mat_lib)
    if equipment_cfg.get("shield"):
        all_parts += gear_v2.build_shield_parts(measurements, style, mat_lib)
    if equipment_cfg.get("weapon") == "sword":
        all_parts += gear_v2.build_sword_parts(measurements, style, mat_lib)

    for obj, bone_name in all_parts:
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
