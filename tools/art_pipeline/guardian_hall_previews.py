"""Review renders from the live Blender MCP scene. Optional VIEWS list."""
import bpy
from pathlib import Path
from mathutils import Vector

exec(Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\guardian_hall_state.py').read_text(encoding='utf-8'))
st = bpy.app.driver_namespace['guardian_hall']
scene, camera, target = st['scene'], st['camera'], st['target']
bpy.context.window.scene = scene
out = Path(st['out']) / 'previews'
out.mkdir(parents=True, exist_ok=True)
views = {'three_quarter': ((12, -17, 13), 15.6),
         'front': ((0, -20, 8.2), 13.4),
         'side': ((20, -3, 10), 13.8),
         'back': ((-12, 17, 12), 15.0),
         'game_top': ((10, -14, 22), 15.6),
         'courtyard_detail': ((5.2, -10.8, 11.8), 9.2)}
rendered = []
for name in globals().get('VIEWS', list(views)):
    position, scale = views[name]
    camera.location = position
    aim = Vector((0, -1.10, 1.9)) if name == 'courtyard_detail' else target
    camera.rotation_euler = (aim - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = scale
    scene.render.filepath = str(out / (name + '.png'))
    bpy.ops.render.render(write_still=True)
    rendered.append(scene.render.filepath)
camera.location = views['three_quarter'][0]
camera.data.ortho_scale = views['three_quarter'][1]
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
result = {'renders': rendered}
