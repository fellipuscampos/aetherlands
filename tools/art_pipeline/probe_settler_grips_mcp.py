"""Inspect grips in the native Blender editor and render clear side views."""
import bpy, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/settlers_review/grip_fix'
WORK.mkdir(parents=True,exist_ok=True)
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
assets=bpy.app.driver_namespace['settlers_v1_assets']
review=bpy.app.driver_namespace['settlers_v1_review']; scene=review['scene']; camera=scene.camera
bpy.context.window.scene=scene
state=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.cycles.samples,scene.render.filepath)
hidden={o:o.hide_render for o in scene.objects if o.type=='FONT'}
prefs=bpy.context.preferences.addons['cycles'].preferences; compute=prefs.compute_device_type; device=scene.cycles.device
try:
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    if any(d.type=='OPTIX' and d.use for d in prefs.devices): scene.cycles.device='GPU'
except (TypeError,RuntimeError): pass
rows=[]
try:
    scene.render.resolution_x=scene.render.resolution_y=720; scene.cycles.samples=16
    for index,asset in enumerate(assets):
        race=asset['report']['race']
        if race not in ('elf','orc'): continue
        rig=asset['review_rig']; by={o['part']:o for o in asset['parts']}
        for i,col in enumerate(review['collections']): col.hide_render=i!=index
        for o in hidden: o.hide_render=True
        for clip,frame in [('idle',1),('walk',179)]:
            scene.frame_set(frame); bpy.context.view_layer.update()
            delta={b.name:b.matrix@rig.data.bones[b.name].matrix_local.inverted() for b in rig.pose.bones}
            a,b,c,g=asset['chains']['arm_r']
            joint={n:list(delta[k]@v) for n,k,v in [('shoulder','upper_arm_r',a),('elbow','forearm_r',b),('wrist','hand_r',c),('grip','hand_r',g)]}
            tools={o['part']:[list(delta[o['animation_bone']]@v.co) for v in o.data.vertices] for o in asset['parts'] if 'Mallet' in o['part'] or 'Staff' in o['part'] or o['part']=='Walking_staff'}
            rows.append(dict(race=race,clip=clip,frame=frame,joints=joint,tools=tools))
            target=review['roots'][index].location+Vector((-.18,-.08,.88))
            camera.data.ortho_scale=1.95
            camera.location=target+Vector((-4,-2.1,1.2)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(WORK/(globals().get('GRIP_PHASE','before')+'_'+race+'_'+clip+'.png'))
            bpy.ops.render.render(write_still=True)
finally:
    for col in review['collections']: col.hide_render=False
    for o,hide in hidden.items(): o.hide_render=hide
    camera.location,camera.rotation_euler,camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.cycles.samples,scene.render.filepath=state
    prefs.compute_device_type=compute; scene.cycles.device=device
    scene.frame_set(161)
(WORK/(globals().get('GRIP_PHASE','before')+'_poses.json')).write_text(json.dumps(rows,indent=2),encoding='utf-8')
result={'status':'PASS','poses':rows,'renders':4}
