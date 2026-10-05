"""Final studio views and one attack pose, rendered in the live Blender scene."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['troll_refinement']; scene=st['scene']; rig=st['rig']; camera=scene.camera
bpy.context.window.scene=scene
folder=Path(st['out'])/'previews'; folder.mkdir(exist_ok=True)
views={'three_quarter':((4,-8,3.8),None,1,3.48),
       'front':((0,-8,2.4),None,1,3.48),'side':((8,0,2.8),None,1,3.48),
       'back':((3,8,3.6),None,1,3.48),
       'pose_test':((4,-8,4.8),'Troll_Attack',13,4.35)}
scene.render.engine='CYCLES'; scene.render.resolution_x=1000; scene.render.resolution_y=1000
for name in globals().get('VIEWS',list(views)):
    pos,clip,frame,scale=views[name]
    for track in rig.animation_data.nla_tracks: track.mute=clip is not None
    rig.animation_data.action=st['clips'][clip]['action'] if clip else None
    scene.frame_set(frame); camera.location=pos
    target=Vector((-.17,-.10,1.24 if clip is None else 1.85))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=scale
    scene.render.filepath=str(folder/(name+'.png')); bpy.ops.render.render(write_still=True)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1); camera.location=views['three_quarter'][0]; camera.data.ortho_scale=3.48
camera.rotation_euler=(Vector((-.17,-.10,1.24))-camera.location).to_track_quat('-Z','Y').to_euler()
result={'rendered':globals().get('VIEWS',list(views)),'restored_to_neutral':True}
