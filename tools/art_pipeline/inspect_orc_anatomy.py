import bpy,json,sys,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo');sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from build_elf_troops import BODY,reset_pose
if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
out=ROOT/'art_source/orc_troops/pose_correction';out.mkdir(exist_ok=True)
records=[]
for stem in ('orc_squire_v1','orc_sentinel_v1','orc_warrior_v1','orc_archer_v1','orc_cavalier_v1','orc_rogue_v1'):
    with bpy.data.libraries.load(str(ROOT/'assets/generated/orcs'/stem/(stem+'.blend')),link=False) as (src,dst):dst.scenes=src.scenes
    scene=dst.scenes[0];bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE');reset_pose(rig,scene)
    by={o['part']:o for o in scene.objects if o.type=='MESH' and o.get('part')}
    rest={n:dict(head=list(b.head_local),tail=list(b.tail_local),matrix=[list(x) for x in b.matrix_local]) for n,b in rig.data.bones.items()}
    boxes={n:dict(center=list(sum((v.co for v in by[n].data.vertices),Vector())/8),vertices=[list(v.co) for v in by[n].data.vertices]) for n in BODY}
    clips=[]
    for track in list(rig.animation_data.nla_tracks)[:3]:
        reset_pose(rig,scene);track.mute=False;strip=track.strips[0]
        scene.frame_set(round(strip.frame_start+(strip.frame_end-strip.frame_start)*.35));bpy.context.view_layer.update()
        actual=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
        posed={}
        for name in BODY:
            obj=by[name];bone=obj['rig_bone'];change=actual.pose.bones[bone].matrix@rig.data.bones[bone].matrix_local.inverted()
            points=[actual.matrix_world@change@v.co for v in obj.data.vertices]
            posed[name]=dict(min=[min(p[i] for p in points) for i in range(3)],max=[max(p[i] for p in points) for i in range(3)])
        clips.append(dict(name=track.name,frame=scene.frame_current,boxes=posed))
        scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
        target=Vector((0,0,1.3 if 'cavalier' in stem else 1.05));camera=scene.camera
        camera.location=target+Vector((3,-9,2.5));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale=3.4 if 'cavalier' in stem else 2.7
        scene.render.filepath=str(out/(stem+'_'+track.name+'.png'));bpy.ops.render.render(write_still=True)
    records.append(dict(stem=stem,bones=rest,boxes=boxes,clips=clips))
(out/'anatomy.json').write_text(json.dumps(records,indent=2))
result=dict(status='PASS',models=len(records),preview_dir=str(out))
