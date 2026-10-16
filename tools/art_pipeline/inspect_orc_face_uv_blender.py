"""Read the editable orc face UV layers without changing source assets."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rows = []
for stem in ("orc_squire_v1", "orc_warrior_v1", "orc_builder_v1", "orc_arcanist_v1",
             "orc_armored_cavalier_v1", "orc_griffon_rider_v1", "orc_guardian_champion_v1", "orc_sentinel_v1"):
    path = ROOT / "assets/generated/orcs" / stem / (stem + ".blend")
    with bpy.data.libraries.load(str(path), link=False) as (source, loaded):
        loaded.scenes = source.scenes
    scene = loaded.scenes[0]
    for obj in scene.objects:
        part = obj.get("part", obj.name)
        if obj.type != "MESH" or not part.startswith(("ElfEar", "Brow", "Head")):
            continue
        row = {"stem": stem, "part": part, "layers": [], "material": []}
        for layer in obj.data.uv_layers:
            coords = [tuple(loop.uv) for loop in layer.data]
            row["layers"].append({"name": layer.name, "active_render": layer.active_render,
                "unique": len(set(coords)), "first": coords[:2]})
        for material in obj.data.materials:
            if material and material.use_nodes:
                row["material"].append({"name": material.name, "uv_nodes":
                    [(node.type, getattr(node, "uv_map", "")) for node in material.node_tree.nodes
                     if node.type in ("UVMAP", "TEX_COORD")]})
        rows.append(row)
    print("ORC_FACE_SOURCE", stem, json.dumps([row for row in rows if row["stem"] == stem]), flush=True)
(ROOT / "art_source/orc_face_uv_source_audit.json").write_text(json.dumps(rows, indent=2))
