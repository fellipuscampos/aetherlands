"""Inspect anatomical elbow/wrist rotation, beyond matrix continuity."""
import bpy,json,math,sys,importlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/school_mages_animation_review'
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
import school_mage_motion as m; importlib.reload(m)
rows=[]
for race in ('human','elf','dwarf','orc'):
    a=bpy.app.driver_namespace[race+'_school_mage_assets_v1'][0]
    for clip,count in m.LENGTHS.items():
        arms={side:dict(elbow_roll=0,wrist_angle=0,step_degrees=0) for side in ('l','r')}; previous={}
        for i in range(count):
            pose=m.pose(race,clip,i/(count-1),a['bones'],a['chains'])
            for side in ('l','r'):
                up=pose['upper_arm_'+side].to_quaternion(); fore=pose['forearm_'+side].to_quaternion(); hand=pose['hand_'+side].to_quaternion()
                axis=(a['chains']['arm_'+side][2]-a['chains']['arm_'+side][1]).normalized()
                relative=up.inverted()@fore
                swing=axis.rotation_difference(relative@axis)
                twist=swing.inverted()@relative
                angle=math.degrees(twist.angle); angle=min(angle,360-angle)
                arms[side]['elbow_roll']=max(arms[side]['elbow_roll'],angle)
                angle=math.degrees((fore.inverted()@hand).angle); angle=min(angle,360-angle)
                arms[side]['wrist_angle']=max(arms[side]['wrist_angle'],angle)
                for name in ('upper_arm_'+side,'forearm_'+side,'hand_'+side):
                    q=pose[name].to_quaternion()
                    if name in previous:
                        angle=math.degrees(previous[name].rotation_difference(q).angle);angle=min(angle,360-angle)
                        arms[side]['step_degrees']=max(arms[side]['step_degrees'],angle)
                    previous[name]=q
        rows.append(dict(race=race,clip=clip,arms=arms))
report=dict(revision=m.REVISION,assets=rows)
(WORK/('arm_logic_audit_revision_'+str(m.REVISION)+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
result=report
