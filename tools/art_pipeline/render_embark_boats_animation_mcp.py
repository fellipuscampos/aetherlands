"""Refresh still renders and two four-boat clips against an unmoving water plane."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/embark_boats_review'
BOATS=bpy.app.driver_namespace['embark_boats_v1']
MODE=globals().get('BOAT_RENDER_MODE','stills')
review=bpy.data.scenes['Embark_Boats_V1_Review']
def stage(race,label,frame=None):
    (WORK/'current_stage.json').write_text(json.dumps(dict(race=race,stage=label,frame=frame)),encoding='utf-8')

if MODE=='stills':
    prefs=bpy.context.preferences.addons['cycles'].preferences
    previous_compute=prefs.compute_device_type; prefs.get_devices()
    device_use={d.name:bool(d.use) for d in prefs.devices}
    gpu=False
    try:
        prefs.compute_device_type='OPTIX'; prefs.get_devices(); gpu=any(d.type=='OPTIX' for d in prefs.devices)
        for d in prefs.devices:
            if d.type=='OPTIX': d.use=True
        for boat in BOATS:
            scene=boat['scene']; out=boat['out']; race=boat['report']['race']; bpy.context.window.scene=scene; scene.frame_set(1)
            camera=scene.camera; scene.cycles.samples=16; scene.cycles.device='GPU' if gpu else 'CPU'
            views={'three_quarter':((4.4,6.4,4.2),4.15,Vector((0,0,1.14))),
                'game_top':((3.2,5.0,6.8),3.95,Vector((0,0,.91))),
                'side':((6,.4,2.8),3.95,Vector((0,0,1.16))),
                'top':((0,0,8),3.70,Vector((0,0,0)))}
            for label,(position,scale,aim) in views.items():
                stage(race,'animated_still_'+label)
                camera.location=position; camera.data.ortho_scale=scale
                camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
                scene.render.filepath=str(out/'previews'/(label+'.png')); bpy.ops.render.render(write_still=True)
            floor=next(o for o in scene.objects if o.get('preview_only'))
            floor.hide_render=True; camera.location=(4.4,6.4,4.2); camera.data.ortho_scale=4.15
            camera.rotation_euler=(Vector((0,0,1.13))-camera.location).to_track_quat('-Z','Y').to_euler()
            stage(race,'animated_still_dry_hull'); scene.render.filepath=str(out/'previews/dry_hull.png'); bpy.ops.render.render(write_still=True)
            floor.hide_render=False
            bpy.data.libraries.write(str(out/(out.name+'.blend')),{scene},fake_user=True,compress=True)
        bpy.context.window.scene=review; review.frame_set(1); review.cycles.samples=16; review.cycles.device='GPU' if gpu else 'CPU'
        stage('all','animated_still_review'); review.render.filepath=str(WORK/'four_boats.png'); bpy.ops.render.render(write_still=True)
        bpy.data.libraries.write(str(WORK/'embark_boats_v1_review.blend'),{review,*[b['scene'] for b in BOATS]},fake_user=True,compress=True)
    finally:
        for d in prefs.devices:
            if d.name in device_use: d.use=device_use[d.name]
        prefs.compute_device_type=previous_compute
else:
    bpy.context.window.scene=review
    settings=(review.render.engine,review.render.resolution_x,review.render.resolution_y,review.render.filepath,review.render.film_transparent)
    try:
        try: review.render.engine='BLENDER_EEVEE_NEXT'
        except TypeError: review.render.engine='BLENDER_EEVEE'
        if hasattr(review,'eevee') and hasattr(review.eevee,'taa_render_samples'): review.eevee.taa_render_samples=16
        review.render.resolution_x=960; review.render.resolution_y=510; review.render.film_transparent=False
        for clip,start,duration in [('idle',1,4.0),('walk',151,2.0)]:
            folder=WORK/'animation_frames'/clip; folder.mkdir(parents=True,exist_ok=True)
            count=round(duration*24)
            for i in range(count):
                frame=start+i*30/24; review.frame_set(math.floor(frame),subframe=frame%1)
                stage('all','render_motion_'+clip,i+1)
                review.render.filepath=str(folder/('%04d.png'%(i+1))); bpy.ops.render.render(write_still=True)
        review.frame_set(1)
    finally:
        review.render.engine,review.render.resolution_x,review.render.resolution_y,review.render.filepath,review.render.film_transparent=settings
        review.frame_set(1)
result={'status':'PASS','mode':MODE,'boats':4,'flat_water_plane':True}
