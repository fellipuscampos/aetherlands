import bpy,json,sys
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from build_elf_troops import reset_pose
result=[]
for stem in ('orc_squire_v1','orc_sentinel_v1','orc_rogue_v1','orc_guardian_v1'):
    with bpy.data.libraries.load(str(ROOT/'assets/generated/orcs'/stem/(stem+'.blend')),link=False) as (src,dst): dst.scenes=src.scenes
    scene=dst.scenes[0]; bpy.context.window.scene=scene; rig=next(o for o in scene.objects if o.type=='ARMATURE')
    reset_pose(rig,scene)
    issues=[(o['part'],min(v.co.z for v in o.data.vertices)) for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio') and min(v.co.z for v in o.data.vertices)<-.001]
    joints=[]
    for track in rig.animation_data.nla_tracks:
        for other in rig.animation_data.nla_tracks: other.mute=other!=track
        strip=track.strips[0]
        for fraction in (0,.5,1):
            scene.frame_set(round(strip.frame_start+fraction*(strip.frame_end-strip.frame_start))); bpy.context.view_layer.update()
            for side in ('l','r'):
                joints.append((track.name,fraction,side,(rig.pose.bones['upper_arm_'+side].tail-rig.pose.bones['forearm_'+side].head).length,(rig.pose.bones['forearm_'+side].tail-rig.pose.bones['hand_'+side].head).length))
    result.append(dict(stem=stem,below_floor=issues,joints=joints))
(ROOT/'art_source/orc_troops/issues.json').write_text(json.dumps(result,indent=2))
result={'status':'PASS','models':len(result)}
