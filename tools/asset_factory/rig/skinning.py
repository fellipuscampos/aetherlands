"""
Binds the merged character mesh to the armature. Every part already
carries a vertex group named after its driving bone (rigid weight = 1.0,
assigned back in geometry/parts.py + equipment.py), so this step only
needs to attach the Armature modifier -- no automatic-weights solve, no
smoothing, nothing that could leak weight across unrelated parts.
"""

import bpy


def bind_to_armature(mesh_obj, armature_obj):
    mesh_obj.parent = armature_obj
    mesh_obj.matrix_parent_inverse = armature_obj.matrix_world.inverted()

    mod = mesh_obj.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = armature_obj
    mod.use_vertex_groups = True

    bone_names = {b.name for b in armature_obj.data.bones}
    group_names = {g.name for g in mesh_obj.vertex_groups}
    missing = group_names - bone_names
    if missing:
        raise RuntimeError(
            f"Vertex group(s) with no matching bone (typo in a part's bone name?): {missing}"
        )
    return mod
