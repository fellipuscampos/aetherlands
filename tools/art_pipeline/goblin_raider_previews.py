"""Render review views of the static Goblin in Blender MCP."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['goblin_raider']; scene=st['scene']; camera=scene.camera
bpy.context.window.scene=scene
out=Path(st['out'])/'previews'; out.mkdir(exist_ok=True)
views={'three_quarter':(3,-6,2.8),'front':(0,-6,1.5),'side':(6,0,1.8),'back':(3,6,2.5)}
rendered=[]
for name in globals().get('VIEWS',list(views)):
    camera.location=views[name]
    camera.rotation_euler=(Vector((0,-.03,.65))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True); rendered.append(scene.render.filepath)
camera.location=views['three_quarter']
camera.rotation_euler=(Vector((0,-.03,.65))-camera.location).to_track_quat('-Z','Y').to_euler()
result={'renders':rendered}
