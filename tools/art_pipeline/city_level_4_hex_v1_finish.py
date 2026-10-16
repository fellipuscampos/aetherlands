"""Paint/render/export City IV through live Blender MCP. Optional VIEWS list."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER = 'City_Level_4_Hex_V1','city_level_4_hex_v1'
scene = bpy.data.scenes[ASSET_NAME]
parts = [o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio']
if not parts[0].data.materials:
    exec((PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8'))
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
bpy.context.window.scene = st['scene']
camera,target = st['camera'],st['target']
views = {'three_quarter':((2.6,-4,3.6),3.25),'game_top':((1.8,-2.9,5.2),2.95),
         'top':((0,0,6),2.05),'back':((-2.6,4,3.7),3.25)}
out = Path(st['out'])/'previews'
out.mkdir(parents=True,exist_ok=True)
for name in globals().get('VIEWS',['three_quarter','game_top','top','back']):
    camera.location,camera.data.ortho_scale = views[name]
    aim = Vector((0,0,0)) if name=='top' else target
    camera.rotation_euler = (aim-camera.location).to_track_quat('-Z','Y').to_euler()
    st['scene'].render.filepath = str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location,camera.data.ortho_scale = views['three_quarter']
camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for o in st['parts'] for v in o.data.vertices for i in range(6))
st['report']['hex_tile'] = {'tile_circumradius':1.0,'foundation_circumradius':.84,
    'orientation':'pointy-top','placement_scale':'tile_radius','max_half_plane_blender':maximum,
    'reserved_border_for_fortification':True}
st['report']['city_level'] = 4
st['report']['remaining_levels'] = []
st['report']['includes_perimeter_walls'] = False
st['report']['evolved_from'] = 'city_level_3_hex_v1'
st['report']['faction_tint'] = 'Neutral cloth and entrance carpet in Faction mesh, tinted per owner in City.gd.'
(Path(st['out'])/(ASSET_FOLDER+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
exec((PIPELINE/'guardian_hall_export.py').read_text(encoding='utf-8'))
