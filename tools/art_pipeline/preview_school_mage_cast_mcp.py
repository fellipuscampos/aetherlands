"""Six casting poses of the first completed mage of a race, live MCP only."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/school_mages_animation_review'
review=bpy.app.driver_namespace[MAGE_RACE+'_school_mage_review_v1']; scene=review['scene']; camera=scene.camera
assets=bpy.app.driver_namespace[MAGE_RACE+'_school_mage_assets_v1']; asset=next(a for a in assets if a['report']['school']==MAGE_SCHOOL); index=assets.index(asset)
bpy.context.window.scene=scene
settings=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.cycles.samples,scene.cycles.device)
prefs=bpy.context.preferences.addons['cycles'].preferences; compute=prefs.compute_device_type
fonts={o:o.hide_render for o in scene.objects if o.type=='FONT'}
folder=WORK/'blender_cast_poses'/MAGE_RACE; folder.mkdir(parents=True,exist_ok=True)
try:
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    for device in prefs.devices:
        if device.type=='OPTIX': device.use=True; scene.cycles.device='GPU'
    for i,col in enumerate(review['collections']): col.hide_render=i!=index
    for obj in fonts: obj.hide_render=True
    scene.render.resolution_x=scene.render.resolution_y=600; scene.cycles.samples=6
    target=review['roots'][index].location+Vector((0,-.12,.95 if MAGE_RACE=='dwarf' else 1.30 if MAGE_RACE=='orc' else 1.1))
    camera.data.ortho_scale=2.6 if MAGE_RACE=='dwarf' else 3.5 if MAGE_RACE=='orc' else 3.05
    camera.location=target+Vector((2.5,-5,1.8)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    for number,fraction in enumerate((0,.24,.39,.58,.80,1)):
        (WORK/'current_stage.json').write_text(json.dumps(dict(asset=asset['root'].name,stage='render_cast_pose',phase=fraction)),encoding='utf-8')
        scene.frame_set(241+round(fraction*144)); scene.render.filepath=str(folder/(str(number)+'.png')); bpy.ops.render.render(write_still=True)
finally:
    for col in review['collections']: col.hide_render=False
    for obj,hidden in fonts.items(): obj.hide_render=hidden
    camera.location,camera.rotation_euler,camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.cycles.samples,scene.cycles.device=settings
    prefs.compute_device_type=compute; scene.frame_set(1)
result=dict(status='PASS',race=MAGE_RACE,casting_poses=6)
