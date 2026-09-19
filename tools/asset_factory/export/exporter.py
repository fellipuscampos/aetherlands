"""
GLB export. Filters the kwargs we ask for against the operator's actual
RNA properties before calling it, since exact glTF-exporter option names
have shifted across Blender versions -- this keeps the script working
across Blender point releases without hand-tracking every rename.
"""

import bpy


def export_glb(filepath: str):
    op = bpy.ops.export_scene.gltf
    valid_props = set(op.get_rna_type().properties.keys())

    desired = {
        "filepath": filepath,
        "export_format": "GLB",
        "use_selection": False,
        "export_animations": True,
        "export_animation_mode": "ACTIONS",
        "export_bake_animation": False,
        "export_force_sampling": False,
        "export_frame_range": False,
        "export_skins": True,
        "export_rest_position_armature": True,
        "export_apply": False,
        "export_yup": True,
        "export_materials": "EXPORT",
        "export_cameras": False,
        "export_lights": False,
        "export_optimize_animation_size": False,
    }
    kwargs = {k: v for k, v in desired.items() if k in valid_props}
    result = op(**kwargs)
    if result != {"FINISHED"}:
        raise RuntimeError(f"glTF export did not finish cleanly: {result}")
