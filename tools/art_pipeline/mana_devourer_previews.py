"""Review renders of the Mana Devourer from the connected Blender."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['mana_devourer']; scene=st['scene']; camera=scene.camera
bpy.context.window.scene=scene; target=Vector((0,0,1.43)); out=Path(st['out'])/'previews'; out.mkdir(exist_ok=True)
views={'three_quarter':(4,-9,3.2),'front':(0,-10,.4),'side':(10,0,2),'back':(-4,9,3.2),'game_top':(4,-6,9)}
for name in globals().get('VIEWS',list(views)):
    camera.location=target+Vector(views[name]); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/f'{name}.png'); bpy.ops.render.render(write_still=True)
camera.location=target+Vector(views['three_quarter']); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
result={'previews':str(out)}
