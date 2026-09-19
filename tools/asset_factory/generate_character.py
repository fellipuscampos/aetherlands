"""
Entry point. Run with Blender in background mode, e.g. from the repo
root:

    blender --background --factory-startup --python tools/asset_factory/generate_character.py -- \
        --preset tools/asset_factory/presets/human_guard.json --seed 42

DATA (presets/*.json) is deliberately kept separate from this ENGINE
script -- change a character's proportions/equipment by editing/adding a
preset, not by touching this file. Only add code here for genuinely new
capabilities (a new equipment type, a new species style, ...).
"""

import argparse
import copy
import json
import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from style.definitions import HumanStyle  # noqa: E402
from character.builder import build_character  # noqa: E402
from character.builder_v2 import build_character_v2  # noqa: E402
from character.builder_v3 import build_character_v3  # noqa: E402
from character.builder_blocky import build_character_blocky  # noqa: E402
from rig.skeleton import build_skeleton  # noqa: E402
from rig.skinning import bind_to_armature  # noqa: E402
from animation.clips import build_all_clips  # noqa: E402
from export.exporter import export_glb  # noqa: E402
from preview.render import render_previews  # noqa: E402


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    p = argparse.ArgumentParser()
    p.add_argument("--preset", required=True)
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--out", default=None)
    p.add_argument("--no-preview", action="store_true")
    return p.parse_args(argv)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block_collection in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions,
                              bpy.data.materials, bpy.data.cameras, bpy.data.lights,
                              bpy.data.worlds):
        for block in list(block_collection):
            if block.users == 0:
                block_collection.remove(block)


def build_style(preset: dict) -> HumanStyle:
    style = HumanStyle()
    for key, value in preset.get("body", {}).items():
        if hasattr(style, key):
            setattr(style, key, value)
        else:
            print(f"[generate_character] WARNING: unknown style field '{key}' in preset, ignored")
    return style


def main():
    args = parse_args()

    with open(args.preset, "r", encoding="utf-8") as f:
        preset = json.load(f)

    seed = args.seed if args.seed is not None else preset.get("seed", 0)
    out_dir = args.out or preset.get("output", {}).get("directory", "assets/generated/output")
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    name = preset.get("output", {}).get("name", "character")

    clear_scene()
    bpy.context.scene.render.fps = 30

    style = build_style(preset)

    engine = preset.get("engine", "v1")
    builder_fn = {
        "v1": build_character, "v2": build_character_v2, "v3": build_character_v3,
        "blocky": build_character_blocky,
    }[engine]
    mesh_obj, measurements, mat_lib, stats = builder_fn(name, style, preset, seed)
    armature_obj = build_skeleton(measurements, name=f"{name}_armature")
    bind_to_armature(mesh_obj, armature_obj)
    # A "staff" weapon (see equipment_blocky.build_staff_parts, held in
    # the right hand -- side 1) is a support tool, not a weapon swung in
    # combat -- Idle/Walk plant that arm in a fixed forward lean instead
    # of letting it swing (see animation/clips._apply_staff_lean).
    weapon = preset.get("equipment", {}).get("weapon")
    staff_side = 1 if weapon == "staff" else 0
    clips = build_all_clips(armature_obj, staff_side=staff_side)

    glb_path = os.path.join(out_dir, f"{name}.glb")
    export_glb(glb_path)

    preview_paths = {}
    if not args.no_preview:
        preview_paths = render_previews(mesh_obj, out_dir, basename=f"preview_{name}",
                                         reference_height=style.height)

    report = {
        "preset": args.preset,
        "engine": engine,
        "seed": seed,
        "style": style.name,
        "output_glb": glb_path,
        "file_size_bytes": os.path.getsize(glb_path) if os.path.exists(glb_path) else None,
        "mesh_stats": stats,
        "material_count": len(mesh_obj.data.materials),
        "bone_count": len(armature_obj.data.bones),
        "bone_names": [b.name for b in armature_obj.data.bones],
        "animations": [c.name for c in clips],
        "previews": preview_paths,
        "height_target": style.height,
    }
    report_path = os.path.join(out_dir, f"{name}_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print("=== GENERATION REPORT ===")
    print(json.dumps(report, indent=2))
    print(f"Report written to {report_path}")


if __name__ == "__main__":
    main()
