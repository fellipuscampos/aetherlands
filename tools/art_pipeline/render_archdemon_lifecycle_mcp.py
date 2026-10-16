"""Render both particle-free lifecycle clips in the connected Blender."""
import bpy
from pathlib import Path
from mathutils import Vector

st = bpy.app.driver_namespace['archdemon_lifecycle']
scene, rig = st['scene'], st['rig']
bpy.context.window.scene = scene
rendered = {}
for name, data in st['clips'].items():
    if name not in st.get('render_clips', st['clips']):
        continue
    if name == 'Death' and 'ground_death' in st:
        scene.camera.data.ortho_scale = 7.
        scene.camera.location = (3, -11, 7)
        aim = Vector((0, .1, .8))
    else:
        scene.camera.data.ortho_scale = 4.95
        scene.camera.location = (3, -11, 4.3)
        aim = Vector((0, 0, 1.65))
    scene.camera.rotation_euler = (aim-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
    frames = Path(st['out'])/'frames'/name
    frames.mkdir(parents=True, exist_ok=True)
    rig.animation_data.action = data['action']
    scene.frame_start = 1
    scene.frame_end = data['end_frame']
    scene.render.filepath = str(frames)+'/'
    bpy.ops.render.render(animation=True)
    rendered[name] = len(list(frames.glob('*.png')))
rig.animation_data.action = st['clips']['Death']['action']
scene.frame_start = 1
scene.frame_end = st['clips']['Death']['end_frame']
scene.frame_set(1)
scene['preview_clip'] = 'Death'
scene.timeline_markers.clear()
for label, frame in [('PECAS SE SOLTAM', 6), ('QUEDA E IMPACTOS', 25), ('REPOUSO NO CHAO', 73), ('DESAPARECE', 97), ('FIM', 113)]:
    scene.timeline_markers.new(label, frame=frame)
result = rendered
