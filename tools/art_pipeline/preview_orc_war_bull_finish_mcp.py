"""Render the native Blender NLA clips for visual animation review."""
import sys,json,numpy as np,bpy
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
from orc_troop_assets import ROOT,OUT,ASSETS
from build_elf_troops import reset_pose
from glb_pose_math import PoseModel
from build_orc_troops import load_scene

result={'assets':[]}
for row in ASSETS:
    if row['key'] not in ('cavalier','griffon_rider'):continue
    stem=row['stem'];report=json.loads((OUT/stem/(stem+'_report.json')).read_text(encoding='utf-8'))
    signature=report['mount_refinement']['motion_signature']
    scene=load_scene(OUT/stem/(stem+'.blend'))
    assert scene.get('mount_motion_signature')==signature
    bpy.context.window.scene=scene;rig=next(o for o in scene.objects if o.type=='ARMATURE');root=rig.parent
    model=PoseModel(OUT/stem/(stem+'.glb'));reset_pose(rig,scene)
    camera=scene.camera;camera.data.type='ORTHO';camera.data.ortho_scale=3.80
    target=root.matrix_world@Vector((0,-.16,1.42));camera.location=target+Vector((6,-12,4.6))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
    destination=ROOT/'docs/previews/orc_troops/bull_motion_frames'/stem;destination.mkdir(parents=True,exist_ok=True)
    clips=[];matrix_error=0.
    conversion=np.array([[1,0,0,0],[0,0,-1,0],[0,1,0,0],[0,0,0,1]])
    for track in rig.animation_data.nla_tracks:
        reset_pose(rig,scene);track.mute=False;strip=track.strips[0];strip.use_animated_influence=False;strip.influence=1.;duration=float(report['clips'][track.name])
        # Evaluate the saved action directly; NLA caches can retain a manually
        # reset pose after repeated library appends in the review session.
        for other in rig.animation_data.nla_tracks:other.mute=True
        rig.animation_data.action=strip.action;rig.animation_data.action_slot=strip.action_slot
        rig.update_tag(refresh={'OBJECT','DATA','TIME'})
        for index in range(8):
            f=round(index/7*duration*24);scene.frame_set(round(strip.action_frame_start)+f+1);scene.frame_set(round(strip.action_frame_start)+f);bpy.context.view_layer.update()
            world=model.worlds(track.name,f/24);inverse=np.linalg.inv(world[model.parent[model.by_name['root']]])
            evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
            for name in model.names:
                expected=conversion@inverse@world[model.by_name[name]]
                error=float(abs(np.array(evaluated.pose.bones[name].matrix)-expected).max());matrix_error=max(matrix_error,error)
                assert error<.0001,(stem,track.name,f,name,'saved Blender action differs from GLB',error)
            scene.render.filepath=str(destination/(track.name+'_'+str(index)+'.png'));bpy.ops.render.render(write_still=True)
        clips.append(track.name)
    reset_pose(rig,scene)
    for track in rig.animation_data.nla_tracks:track.mute=False
    scene.frame_set(1)
    result['assets'].append({'stem':stem,'clips':clips,'saved_action_glb_matrix_error':matrix_error})
(ROOT/'docs/orc_war_bull_motion_preview_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
