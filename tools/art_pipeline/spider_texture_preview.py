"""One review render of the live edited Spider; restore camera and render settings."""
import bpy
from pathlib import Path
from mathutils import Vector

scene=bpy.context.scene; assert scene.name=='Giant_Spider_V1'
camera=scene.camera
old=(camera.matrix_world.copy(),scene.render.filepath,scene.render.resolution_x,scene.render.resolution_y,scene.cycles.samples)
out=Path(r'C:\Users\felipe campos\Documents\jogo\assets\generated\spiders\giant_spider_v1\previews\no_green.png')
try:
    target=Vector((0,.15,.50)); camera.location=target+Vector((5,-7,8))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=800; scene.render.resolution_y=800; scene.cycles.samples=24
    scene.render.filepath=str(out); bpy.ops.render.render(write_still=True)
finally:
    camera.matrix_world=old[0]; scene.render.filepath=old[1]
    scene.render.resolution_x=old[2]; scene.render.resolution_y=old[3]; scene.cycles.samples=old[4]
result={'preview':str(out)}
