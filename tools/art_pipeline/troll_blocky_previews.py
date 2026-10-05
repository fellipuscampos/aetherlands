"""Render chosen views of the final blocky asset through Blender MCP."""
import bpy
from pathlib import Path
from mathutils import Vector
scene=bpy.data.scenes['Troll_Blocky_V3']; bpy.context.window.scene=scene
folder=Path(r'C:\Users\felipe campos\Documents\jogo\assets\generated\trolls\troll_blocky_v3\previews')
folder.mkdir(exist_ok=True)
views={'three_quarter':((4,-8,3.8),1,3.48),'front':((0,-8,2.4),1,3.48),
       'side':((8,0,2.8),1,3.48),'back':((3,8,3.6),1,3.48),
       'pose_test':((4,-8,3.8),60,3.8),'elbows_test':((4,-8,3.8),24,3.48),
       'knees_test':((4,-8,3.8),36,3.48)}
files=[]
for name in globals().get('VIEWS',['three_quarter','front','side','back','pose_test']):
    pos,frame,scale=views[name]; scene.frame_set(frame)
    scene.camera.location=pos
    scene.camera.rotation_euler=(Vector((-.23,-.08,1.24))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera.data.ortho_scale=scale
    scene.render.filepath=str(folder/(name+'.png'))
    bpy.ops.render.render(write_still=True); files.append(scene.render.filepath)
scene.frame_set(1); scene.camera.location=views['three_quarter'][0]; scene.camera.data.ortho_scale=3.48
scene.camera.rotation_euler=(Vector((-.23,-.08,1.24))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
result={'previews':files,'restored_frame':1}
