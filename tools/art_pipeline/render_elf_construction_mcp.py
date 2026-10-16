"""Render the new site in the live Blender, without changing any other scene."""
import bpy, math, json
from mathutils import Vector

asset=bpy.app.driver_namespace['elf_construction_v1']; scene=asset['scene']; OUT=asset['out']; WORK=asset['work']
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
for obj in asset['studio'].objects:
    if obj.type=='MESH' and obj.name.startswith('Preview_floor'):
        for vertex in obj.data.vertices: vertex.co.z=-.001
MODE=globals().get('CONSTRUCTION_RENDER_MODE','stills')
camera=scene.camera
def aim(position,scale,target=(0,0,.24)):
    camera.location=position; camera.data.ortho_scale=scale
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
def progress(stage,frame=0):
    (WORK/'current_stage.json').write_text(json.dumps(dict(stage=stage,frame=frame)),encoding='utf-8')
if MODE=='stills':
    prefs=bpy.context.preferences.addons['cycles'].preferences; old=prefs.compute_device_type
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    for d in prefs.devices:
        if d.type=='OPTIX': d.use=True
    scene.cycles.device='GPU'; scene.cycles.samples=24
    for name,pos,scale in [('three_quarter',(2.4,-3.5,2.9),2.55),('game_top',(2.4,-3.5,5.0),2.42),('back',(-2.4,3.5,2.9),2.55),('top',(0,0,7),2.2)]:
        progress(name); scene.frame_set(16); aim(pos,scale)
        scene.render.filepath=str(OUT/'previews'/(name+'.png')); bpy.ops.render.render(write_still=True)
    progress('worker_detail'); scene.frame_set(16); aim((.20,-3.0,1.0),.53,(.20,.278,.46))
    scene.render.filepath=str(OUT/'previews/worker_detail.png'); bpy.ops.render.render(write_still=True)
    progress('ground_worker_detail'); scene.frame_set(1); aim((-1.5,2.0,.95),.55,(-.40,-.335,.25))
    scene.render.filepath=str(OUT/'previews/ground_worker_detail.png'); bpy.ops.render.render(write_still=True)
    progress('hammer_raised'); scene.frame_set(40)
    scene.render.filepath=str(OUT/'previews/hammer_raised.png'); bpy.ops.render.render(write_still=True)
    aim((2.4,-3.5,2.9),2.55); scene.frame_set(1)
    prefs.compute_device_type=old
else:
    old=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.cycles.samples)
    # Eevee keeps the 108-frame review quick; source/export animation remains 30 fps.
    try: scene.render.engine='BLENDER_EEVEE_NEXT'
    except TypeError: scene.render.engine='BLENDER_EEVEE'
    if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'): scene.eevee.taa_render_samples=16
    prefs=bpy.context.preferences.addons['cycles'].preferences; previous=prefs.compute_device_type
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    for d in prefs.devices:
        if d.type=='OPTIX': d.use=True
    scene.render.resolution_x=760; scene.render.resolution_y=760
    close=MODE=='hammer_motion'
    if close: aim((-1.5,2.0,.95),.55,(-.40,-.335,.25))
    else: aim((2.4,-3.5,2.9),2.55)
    folder=WORK/('hammer_animation_frames' if close else 'animation_frames_final'); folder.mkdir(exist_ok=True)
    for i in range(36 if close else 108):
        frame=1+i*30/18; scene.frame_set(math.floor(frame),subframe=frame%1)
        progress('motion',i+1); scene.render.filepath=str(folder/('%04d.png'%(i+1))); bpy.ops.render.render(write_still=True)
    scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.cycles.samples=old
    prefs.compute_device_type=previous; scene.frame_set(1); aim((2.4,-3.5,2.9),2.55)
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/(OUT.name+'.blend')),{scene},fake_user=True,compress=True)
result={'status':'PASS','mode':MODE}
