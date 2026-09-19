"""
Entry point pro cavalo decorativo (geometry/horse.py) que decora tiles com
o recurso "horses" (ver ResourceDatabase.gd/ResourcePropsManager.gd) --
pedido do usuario: "faça um modelo de cavalo pra usar nos tiles com o
recurso cavalo", explicitamente pela pipeline de verdade (Blender/bpy) em
vez do box cru direto em GDScript que ja existia (mantido pra outros
recursos, ver ResourcePropsManager._build_horses_mesh).

Roda com Blender em background mode, do repo root:

    blender --background --factory-startup --python tools/asset_factory/generate_horse.py

SEM --preset/rig/skinning/animacao de proposito -- e uma decoracao
ESTATICA de terreno (nunca se move/luta, Unit.gd e o UNICO consumidor de
rig+animacao deste projeto), entao esta pipeline e bem mais curta que
generate_character.py: so geometria + export + preview, sem style/
character/rig/animation nenhum.

v2 (pedido do usuario, com screenshot: "o cavalo ficou horroroso" --
2 cavalos sobrepostos, pernas finas demais, pescoco em escadinha): geometry
reescrita (ver geometry/horse.py) e reduzido de uma "manada" de 2 pra 1
cavalo so, centralizado na origem.
"""

import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from geometry.horse import build_horse_parts  # noqa: E402
from export.exporter import export_glb  # noqa: E402
from preview.render import render_previews  # noqa: E402


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block_collection in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                              bpy.data.lights, bpy.data.worlds):
        for block in list(block_collection):
            if block.users == 0:
                block_collection.remove(block)


def main():
    clear_scene()

    out_dir = os.path.abspath("assets/generated/resources/horses")
    os.makedirs(out_dir, exist_ok=True)
    name = "horses"

    # 1 cavalo so, centralizado na origem (era uma "manada" de 2
    # sobrepostos -- pedido explicito do usuario pra reduzir a 1).
    all_parts = build_horse_parts(
        coat_color=(0.45, 0.29, 0.15), mane_color=(0.16, 0.12, 0.09), hoof_color=(0.08, 0.06, 0.05),
        scale=1.0, offset=(0.0, 0.0, 0.0), yaw=0.0,
    )

    bpy.ops.object.select_all(action="DESELECT")
    for o in all_parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = all_parts[0]
    if len(all_parts) > 1:
        bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = name
    merged.data.name = name

    glb_path = os.path.join(out_dir, f"{name}.glb")
    export_glb(glb_path)
    preview_paths = render_previews(merged, out_dir, basename=f"preview_{name}", reference_height=1.6)

    report = {
        "output_glb": glb_path,
        "file_size_bytes": os.path.getsize(glb_path) if os.path.exists(glb_path) else None,
        "vertices": len(merged.data.vertices),
        "faces": len(merged.data.polygons),
        "previews": preview_paths,
    }
    report_path = os.path.join(out_dir, f"{name}_report.json")
    import json
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print("=== GENERATION REPORT ===")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
