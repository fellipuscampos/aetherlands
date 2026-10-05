"""Render textured animation PNG sequences in the connected Blender (EEVEE),
restoring the delivery lighting/camera afterwards.
Globals: FRAMES_DIR (required), CLIPS, SAMPLE_FRAMES, CAMERA_OFFSET.
"""
import bpy
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['skeleton_animation']; scene=st['scene']; rig=st['rig']; camera=scene.camera
folder=Path(FRAMES_DIR); folder.mkdir(parents=True,exist_ok=True)
saved=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,camera.matrix_world.copy(),camera.data.ortho_scale)
# EEVEE with the delivery studio lights keeps the same colours as the Cycles stills.
scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=640; scene.render.resolution_y=640
for track in rig.animation_data.nla_tracks: track.mute=True
manifest={}
try:
    # Fixed camera across clips: front-right three-quarter, wide enough for the raised sword.
    target=Vector((0,-.20,1.20)); camera.location=target+Vector(globals().get('CAMERA_OFFSET',(5.5,-9.5,3.6)))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=3.4
    for name in globals().get('CLIPS',list(st['clips'])):
        data=st['clips'][name]; rig.animation_data.action=data['action']
        dest=folder/name; dest.mkdir(exist_ok=True)
        frames=globals().get('SAMPLE_FRAMES',{}).get(name)
        if frames is None: frames=range(1,data['end']+(0 if data['loop'] else 1))
        paths=[]
        for frame in frames:
            scene.frame_set(frame); scene.render.filepath=str(dest/f'{frame:04d}.png')
            bpy.ops.render.render(write_still=True); paths.append(scene.render.filepath)
        manifest[name]={'frames':len(paths),'directory':str(dest),'fps':24,'loop':data['loop']}
finally:
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks: track.mute=False
    scene.frame_set(1)
    scene.render.engine,scene.render.resolution_x,scene.render.resolution_y=saved[:3]
    camera.matrix_world=saved[3]; camera.data.ortho_scale=saved[4]
result={'animation_sequences':manifest}
