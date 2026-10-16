"""Render refreshed stills or animation frames in the open Blender review."""
import bpy,json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/settlers_review'
assets=bpy.app.driver_namespace['settlers_v1_assets']; review=bpy.app.driver_namespace['settlers_v1_review']; scene=review['scene']; camera=scene.camera
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
prefs=bpy.context.preferences.addons['cycles'].preferences; old_compute=prefs.compute_device_type
try:
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    if any(d.type=='OPTIX' and d.use for d in prefs.devices): scene.cycles.device='GPU'
except (TypeError,RuntimeError): pass
old_samples=scene.cycles.samples; old_resolution=(scene.render.resolution_x,scene.render.resolution_y)
old_persistent=scene.render.use_persistent_data
old_pos=camera.location.copy(); old_rot=camera.rotation_euler.copy(); old_scale=camera.data.ortho_scale
fonts={o:o.hide_render for o in scene.objects if o.type=='FONT'}
def stage(value,frame=None): (WORK/'current_stage.json').write_text(json.dumps(dict(stage=value,frame=frame)),encoding='utf-8')
try:
    if SETTLER_PREVIEW=='stills':
        scene.cycles.samples=16; scene.frame_set(1); scene.render.resolution_x=scene.render.resolution_y=700
        for index,asset in enumerate(assets):
            if asset['report']['race'] not in globals().get('SETTLER_PREVIEW_RACES',('human','elf','dwarf','orc')): continue
            for i,col in enumerate(review['collections']): col.hide_render=i!=index
            for font in fonts: font.hide_render=True
            target=review['roots'][index].location+Vector((0,.05,asset['report']['geometry']['dimensions'][2]/2))
            camera.data.ortho_scale=asset['report']['geometry']['dimensions'][2]*1.40
            for view,offset in [('front',(0,-5,1.45)),('three_quarter',(2.6,-5,2.2)),('back',(-2.6,5,2.2))]:
                stage(asset['report']['race']+'_still_'+view)
                camera.location=target+Vector(offset); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
                scene.render.filepath=str(asset['folder']/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
        for col in review['collections']: col.hide_render=False
        for font,hidden in fonts.items(): font.hide_render=hidden
        scene.render.resolution_x,scene.render.resolution_y=1800,900; camera.data.ortho_scale=8.7
        for view,position in [('front',(0,-14,4.9)),('three_quarter',(4.3,-15,6.2)),('back',(-4.3,15,6.2))]:
            stage('overview_'+view); camera.location=position; camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(WORK/('settlers_'+view+'.png')); bpy.ops.render.render(write_still=True)
        scene.frame_set(179); camera.location=(4.3,-15,6.2); camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(WORK/'settlers_walk_pose.png'); stage('walk_pose'); bpy.ops.render.render(write_still=True)
    else:
        assert SETTLER_PREVIEW in ('idle','walk')
        scene.render.use_persistent_data=True
        scene.cycles.samples=6; scene.render.resolution_x,scene.render.resolution_y=900,450
        camera.location=(4.3,-15,6.2); camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=8.7
        folder=WORK/'animation_frames'/SETTLER_PREVIEW; folder.mkdir(parents=True,exist_ok=True)
        frames=range(1,145,4) if SETTLER_PREVIEW=='idle' else range(161,233,2)
        for index,frame in enumerate(frames):
            stage('render_'+SETTLER_PREVIEW,frame); scene.frame_set(frame)
            scene.render.filepath=str(folder/(str(index).zfill(3)+'.png')); bpy.ops.render.render(write_still=True)
finally:
    for col in review['collections']: col.hide_render=False
    for font,hidden in fonts.items(): font.hide_render=hidden
    prefs.compute_device_type=old_compute; scene.cycles.samples=old_samples
    scene.render.use_persistent_data=old_persistent
    scene.render.resolution_x,scene.render.resolution_y=old_resolution
    camera.location=old_pos; camera.rotation_euler=old_rot; camera.data.ortho_scale=old_scale
    scene.frame_set(161); scene.use_preview_range=True; scene.frame_preview_start=161; scene.frame_preview_end=233
result={'status':'PASS','preview':SETTLER_PREVIEW}
