"""Render review views of the static ShockCavalier in Blender MCP.
Optional globals: VIEWS (list of names), PREVIEW_DIR (override output folder).
"""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['shock_cavalier']; scene=st['scene']; camera=scene.camera; target=st['target']
bpy.context.window.scene=scene
out=Path(globals().get('PREVIEW_DIR',str(Path(st['out'])/'previews'))); out.mkdir(parents=True,exist_ok=True)
# Offsets from the target; 'game_top' approximates the steep top-down 3/4 gameplay camera.
views={'three_quarter':(6,-12,5.6),'front':(0,-12,1.2),'side':(12,0,2.0),'back':(-6,12,5.0),'game_top':(5,-7,11)}
rendered=[]
for name in globals().get('VIEWS',list(views)):
    camera.location=target+Vector(views[name])
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True); rendered.append(scene.render.filepath)
camera.location=target+Vector(views['three_quarter'])
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
result={'renders':rendered}
