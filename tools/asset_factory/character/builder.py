"""
CharacterBuilder: turns (StyleDefinition, preset dict, seed) into a single
joined, rigid-vertex-grouped mesh object ready for rig/skinning.py.
"""

import bpy

from character.params import compute_measurements, apply_seed_variation
from geometry import parts as body_parts
from geometry import equipment as gear
from geometry import primitives as prim
from style.palette import MaterialLibrary


def build_character(name: str, style, preset: dict, seed: int):
    civilization = preset.get("palette", {}).get("civilization", "human_default")
    mat_lib = MaterialLibrary(civilization)

    measurements = compute_measurements(style)
    apply_seed_variation(measurements, seed)

    all_parts = []
    all_parts += body_parts.build_body_parts(measurements, style, mat_lib)
    all_parts += gear.build_armor(measurements, style, mat_lib)

    equipment_cfg = preset.get("equipment", {})
    if equipment_cfg.get("helmet", True):
        all_parts += gear.build_helmet(measurements, style, mat_lib)
    if equipment_cfg.get("shield"):
        all_parts += gear.build_shield(measurements, style, mat_lib)
    if equipment_cfg.get("weapon") == "sword":
        all_parts += gear.build_sword(measurements, style, mat_lib)

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
