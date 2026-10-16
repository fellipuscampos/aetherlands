"""Paint/render/export Orc Siege Arsenal through live Blender MCP, asset only."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER = 'Orc_Siege_Arsenal_Hex_V1','orc_siege_arsenal_hex_v1'
scene = bpy.data.scenes[ASSET_NAME]
parts = [o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio']
if not parts[0].data.materials:
    exec((PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8'))
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
bpy.context.window.scene = st['scene']
camera,target = st['camera'],st['target']
views = {'three_quarter':((2.6,-4,3.3),2.75),'game_top':((1.8,-2.9,4.9),2.60),
         'top':((0,0,6),2.25),'back':((-2.6,4,3.4),2.75)}
out = Path(st['out'])/'previews'
out.mkdir(parents=True,exist_ok=True)
for name in globals().get('VIEWS',['three_quarter','game_top','top','back']):
    camera.location,camera.data.ortho_scale = views[name]
    aim = Vector((0,0,0)) if name=='top' else target
    camera.rotation_euler = (aim-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location,camera.data.ortho_scale = views['three_quarter']
camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for o in st['parts'] for v in o.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum
source = (PIPELINE.parent.parent/'scripts/data/BuildingDatabase.gd').read_text(encoding='utf-8')
assert ASSET_FOLDER not in source, 'This asset must remain unintegrated.'
st['report'].update({
    'civilization':'orc','unit_class':'siege','asset_only':True,'integrated_in_game':False,
    'hex_tile':{'tile_circumradius':1.0,'foundation_circumradius':.92,
                'orientation':'pointy-top','placement_scale':'tile_radius',
                'max_half_plane_blender':maximum,'tile_apothem':math.sqrt(3)/2},
    'siege_props':{'catapult_count':1,'catapult_static':True,'crane':True,
                    'loaded_spoon':True,'suspended_spare_axle':True,
                    'unit_models_defined':False},
    'faction_tint':'Cog backing cloth and miniature catapult nose plate isolated in Faction mesh for future owner tint. No runtime integration.'})
(Path(st['out'])/(ASSET_FOLDER+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
exec((PIPELINE/'guardian_hall_export.py').read_text(encoding='utf-8'))
