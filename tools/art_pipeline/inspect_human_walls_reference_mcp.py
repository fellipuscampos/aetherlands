"""Inspect the existing human city without replacing the current Blender scene."""
import bpy, json
from pathlib import Path

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
scene = bpy.data.scenes.get('City_Level_4_Hex_V1')
if scene is None:
    with bpy.data.libraries.load(str(ROOT/'assets/generated/humans/buildings/city_level_4_hex_v1/city_level_4_hex_v1.blend'), link=False) as (source, loaded):
        loaded.scenes = ['City_Level_4_Hex_V1']
    scene = loaded.scenes[0]
bpy.app.driver_namespace['human_wall_reference'] = scene
regions = {}
for obj in scene.objects:
    if obj.type == 'MESH' and obj.get('region') and obj.get('region') != 'studio':
        regions.setdefault(obj['region'], []).append(dict(name=obj.name, part=obj.get('part'), polygons=len(obj.data.polygons), materials=[mat.name for mat in obj.data.materials if mat]))
print(json.dumps({region: parts[:3] for region, parts in regions.items()}))
