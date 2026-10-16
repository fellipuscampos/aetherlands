"""Paint/export/render the Ranger Camp in the live Blender MCP; optional VIEWS list."""
import bpy
from pathlib import Path
from mathutils import Vector

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER = 'Ranger_Camp_Hex_V1','ranger_camp_hex_v1'
scene = bpy.data.scenes[ASSET_NAME]
parts = [o for o in scene.objects if o.type == 'MESH' and o.get('part') and o.get('region') != 'studio']
if not parts[0].data.materials:
    exec((PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8'))
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
bpy.context.window.scene = st['scene']
camera,target = st['camera'],st['target']
views = {'three_quarter':((2.6,-4,3.3),2.70), 'game_top':((1.8,-2.9,4.9),2.55),
         'top':((0,0,6),2.20), 'back':((-2.6,4,3.4),2.70)}
out = Path(st['out'])/'previews'
out.mkdir(parents=True,exist_ok=True)
for name in globals().get('VIEWS',['three_quarter','game_top','top','back']):
    camera.location,camera.data.ortho_scale = views[name]
    aim = Vector((0,0,0)) if name == 'top' else target
    camera.rotation_euler = (aim-camera.location).to_track_quat('-Z','Y').to_euler()
    st['scene'].render.filepath = str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location,camera.data.ortho_scale = views['three_quarter']
camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
exec((PIPELINE/'guardian_hall_export.py').read_text(encoding='utf-8'))
