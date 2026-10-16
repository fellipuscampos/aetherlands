"""Exercise the fixed Blender exporter against a disposable squire export."""
import bpy
import json
from pathlib import Path
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/art_pipeline"))
from build_elf_troops import reset_pose
from export_orc_clothing_glb import export
from glb_pose_math import accessor
from human_texture_glb import read_glb

stem = "orc_squire_v1"
folder = ROOT / "assets/generated/orcs" / stem
output = ROOT / "art_source/orc_face_uv_repair/export_check" / stem
output.mkdir(parents=True, exist_ok=True)
with bpy.data.libraries.load(str(folder / (stem + ".blend")), link=False) as (source, loaded):
    loaded.scenes = source.scenes
scene = loaded.scenes[0]
bpy.context.window.scene = scene
rig = next(obj for obj in scene.objects if obj.type == "ARMATURE")
root = rig.parent
reset_pose(rig, scene)
parts = [obj for obj in scene.objects if obj.type == "MESH" and obj.get("region") not in (None, "studio")]
report = json.loads((folder / (stem + "_report.json")).read_text(encoding="utf-8"))
details = report["clothing_refinement"]
export({"stem": stem}, scene, parts, rig, root, output,
       details["source_part_uv_boxes"], details["blade_rotations"])
(output / (stem + "_report.json")).write_text(json.dumps(report))
doc, binary = read_glb((output / (stem + ".glb")).read_bytes())
attributes = doc["meshes"][0]["primitives"][0]["attributes"]
primary = accessor(doc, binary, attributes["TEXCOORD_0"])
original = accessor(doc, binary, attributes["TEXCOORD_1"])
inherited = np.max(np.abs(original - [0., 1.]), axis=1) > 1e-6
assert inherited.any()
assert np.array_equal(primary[inherited], original[inherited]), "Fresh export still needs UV repair"
validation = {"status": "PASS", "stem": stem, "inherited_vertices": int(inherited.sum()),
              "correct_primary_mapping_after_fresh_export": True}
(ROOT / "docs/orc_face_uv_export_validation.json").write_text(json.dumps(validation, indent=2))
print("ORC_FACE_EXPORT_PASS", validation["inherited_vertices"], flush=True)
