"""Render textured animation PNGs in the connected Blender, without changing delivery lighting."""
import bpy
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['goblin_animation']; scene=st['scene']; rig=st['rig']; camera=scene.camera
folder=Path(st['source'])/'animation_frames'; folder.mkdir(exist_ok=True)
saved=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,camera.matrix_world.copy(),camera.data.ortho_scale)
scene.render.engine='BLENDER_WORKBENCH'; scene.render.resolution_x=640; scene.render.resolution_y=640
sh=scene.display.shading; sh.light='STUDIO'; sh.color_type='TEXTURE'; sh.show_shadows=True; sh.show_cavity=True
sh.cavity_type='BOTH'; sh.curvature_ridge_factor=.7; sh.curvature_valley_factor=.7
sh.background_type='WORLD'; scene.world.color=(.12,.14,.16)
floor=bpy.data.objects[st['name']+'_StudioGround']; floor.hide_render=True
for track in rig.animation_data.nla_tracks: track.mute=True
manifest={}
try:
    # Fixed camera across clips makes motion amplitude and contact easier to compare.
    camera.location=globals().get('CAMERA_POSITION',(-3.5,-5.6,2.45)); target=Vector((0,-.075,.64))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=1.72
    for name in globals().get('CLIPS',list(st['clips'])):
        data=st['clips'][name]; rig.animation_data.action=data['action']
        dest=folder/name; dest.mkdir(exist_ok=True)
        frames=globals().get('SAMPLE_FRAMES')
        if frames is None: frames=range(1,data['end']+(0 if data['loop'] else 1))
        paths=[]
        for frame in frames:
            scene.frame_set(frame); scene.render.filepath=str(dest/f'{frame:04d}.png')
            bpy.ops.render.render(write_still=True); paths.append(scene.render.filepath)
        manifest[name]={'frames':len(paths),'directory':str(dest),'fps':24,'loop':data['loop']}
finally:
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks: track.mute=False
    scene.frame_set(1); floor.hide_render=False
    scene.render.engine,scene.render.resolution_x,scene.render.resolution_y=saved[:3]
    camera.matrix_world=saved[3]; camera.data.ortho_scale=saved[4]
result={'animation_sequences':manifest}
