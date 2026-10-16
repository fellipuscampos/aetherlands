"""Resolve live IDs again after Blender render/undo can invalidate Python handles.
Also permits exporting and previewing the saved .blend in a fresh MCP session.
"""
import bpy
import json
from pathlib import Path
from mathutils import Vector

NAME = globals().get('ASSET_NAME', 'Guardian_Hall_V1')
scene = bpy.data.scenes[NAME]
PROJECT_ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
OUT = PROJECT_ROOT / scene.get('asset_output_relative',
    'assets/generated/humans/buildings/' + globals().get('ASSET_FOLDER', 'guardian_hall_v1'))
groups = {collection.name[len(NAME) + 1:]: collection for collection in scene.collection.children
          if collection.name.startswith(NAME + '_') and not collection.name.endswith('_EXPORT_TEMP')}
parts = [obj for obj in scene.objects if obj.type == 'MESH' and
         obj.get('part') and obj.get('region') != 'studio' and not obj.get('preview_only')]
root = next(obj for obj in scene.objects if obj.name == NAME + '_ROOT')
material = parts[0].data.materials[0]
images = [node.image for node in material.node_tree.nodes if node.type == 'TEX_IMAGE']
for im in images:
    relocated = OUT / Path(im.filepath_raw).name
    if relocated.exists():
        im.filepath_raw = str(relocated)
report = json.loads((OUT / (OUT.name + '_report.json')).read_text(encoding='utf-8'))
report['scale'] = scene.get('scale_note', report.get('scale', ''))
report['design'] = scene.get('design_note', report.get('design', ''))
report['door_clearance_m'] = list(scene.get('door_clearance', report.get('door_clearance_m', [1.80, 2.40])))
st = {'name': NAME, 'out': str(OUT), 'scene': scene, 'groups': groups,
      'parts': parts, 'root': root, 'material': material, 'images': images,
      'camera': scene.camera, 'target': Vector(scene.get('preview_target', (0, -.20, 2.45))),
      'density': scene.get('density', 64), 'paint_world_scale': scene.get('paint_world_scale', 1),
      'scale_note': report['scale'], 'design_note': report['design'],
      'door_clearance': report['door_clearance_m'], 'report': report}
bpy.app.driver_namespace['guardian_hall'] = st
