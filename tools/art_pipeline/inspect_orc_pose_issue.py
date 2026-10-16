import bpy,json,sys,numpy as np
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo');sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from build_elf_troops import reset_pose
stem='orc_sentinel_v1'
with bpy.data.libraries.load(str(ROOT/'assets/generated/orcs'/stem/(stem+'.blend')),link=False) as (src,dst):dst.scenes=src.scenes
scene=dst.scenes[0];bpy.context.window.scene=scene;rig=next(o for o in scene.objects if o.type=='ARMATURE')
records=[]
for track in rig.animation_data.nla_tracks:
    reset_pose(rig,scene);track.mute=False;strip=track.strips[0]
    for f in (0,.25,.5,.75,1):
        scene.frame_set(round(strip.frame_start+f*(strip.frame_end-strip.frame_start)));bpy.context.view_layer.update()
        actual=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
        for side in ('l','r'):
            u=actual.pose.bones['upper_arm_'+side];a=actual.pose.bones['forearm_'+side];h=actual.pose.bones['hand_'+side]
            records.append(dict(clip=track.name,frame=scene.frame_current,fraction=f,side=side,
                gap=(u.tail-a.head).length,gap2=(a.tail-h.head).length,
                upper_matrix=[list(x) for x in u.matrix],fore_matrix=[list(x) for x in a.matrix],
                parents=[u.parent.name,a.parent.name,h.parent.name],lengths=[u.length,a.length],
                arm_head=list(u.head),arm_tail=list(u.tail),fore_head=list(a.head)))
(ROOT/'art_source/orc_troops/pose_issue.json').write_text(json.dumps(records,indent=2))
result={'status':'PASS','worst':max(records,key=lambda r:max(r['gap'],r['gap2']))}
