"""Repair the elf elbow and orc mallet in the live Blender MCP session."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
import numpy as np

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/settlers_review'
namespace={}
source=(ROOT/'tools/art_pipeline/animate_settlers_mcp.py').read_text(encoding='utf-8').split('\nfor asset in ASSETS:')[0]
exec(compile(source,'animate_settlers_mcp.py','exec'),namespace)
assets=namespace['ASSETS']; review=namespace['REVIEW']; pose=namespace['pose']; shape_hash=namespace['shape_hash']
baseline=bpy.app.driver_namespace.setdefault('settlers_grip_fix_before',{
    a['report']['race']:{'hashes':{o['part']:shape_hash(o) for o in a['parts']},
                       'vertices':{o['part']:[v.co.copy() for v in o.data.vertices] for o in a['parts']}}
    for a in assets})

def curves(action):
    return [c for layer in action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]

def curve_hash(action,exclude=()):
    data=[(c.data_path,c.array_index,[(list(k.co),k.interpolation) for k in c.keyframe_points]) for c in curves(action)
          if not any('"'+name+'"' in c.data_path for name in exclude)]
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()

elf=next(a for a in assets if a['report']['race']=='elf')
rig=elf['rig']; names=('upper_arm_r','forearm_r','hand_r'); before={clip:curve_hash(action,names) for clip,action in elf['actions'].items()}
bpy.context.window.scene=elf['scene']; animation=rig.animation_data
animation.action=None; animation.use_nla=False
try:
    for clip,action in elf['actions'].items():
        animation.action=action; previous={}
        count=namespace['LENGTHS'][clip]
        for frame in range(1,count+1):
            desired=pose('elf',clip,(frame-1)/(count-1),elf['bones'],elf['chains'])
            for name in names:
                bone=rig.pose.bones[name]; rest=rig.data.bones[name].matrix_local
                bone.matrix_basis=rest.inverted()@desired[name]@rest
                if name in previous and previous[name].dot(bone.rotation_quaternion)<0: bone.rotation_quaternion.negate()
                previous[name]=bone.rotation_quaternion.copy()
                bone.keyframe_insert('rotation_quaternion',frame=frame,group=name)
                bone.keyframe_insert('location',frame=frame,group=name)
        for curve in curves(action):
            if any('"'+name+'"' in curve.data_path for name in names):
                for key in curve.keyframe_points: key.interpolation='LINEAR'
        assert curve_hash(action,names)==before[clip], 'Unrelated elf animation channels changed'
finally:
    animation.action=None; animation.use_nla=True
    for bone in rig.pose.bones: bone.matrix_basis.identity()

orc=next(a for a in assets if a['report']['race']=='orc')
elf_tools=[o for o in elf['parts'] if o['part']=='Walking_staff' or o['part'].startswith('Staff_')]
tools=[o for o in orc['parts'] if o['part'].startswith('Mallet_')]
assert len(tools)>=3
for asset in (elf,orc):
    namespace['correct_tool_grips'](asset,asset['chains'],baseline[asset['report']['race']]['vertices'])

def vertices(obj,delta):
    return np.array([list(delta[obj['animation_bone']]@v.co) for v in obj.data.vertices])

def separation(a,b):
    """Signed separating-axis gap between two closed cuboids, in meters."""
    ae=[a[i]-a[0] for i in (1,2,4)]; be=[b[i]-b[0] for i in (1,2,4)]
    axes=[np.cross(e[i],e[j]) for e in (ae,be) for i,j in ((0,1),(1,2),(2,0))]
    axes += [np.cross(x,y) for x in ae for y in be]
    gaps=[]
    for axis in axes:
        norm=np.linalg.norm(axis)
        if norm<1e-10: continue
        axis=axis/norm; aa=a@axis; bb=b@axis
        gaps.append(max(bb.min()-aa.max(),aa.min()-bb.max()))
    return float(max(gaps))

checks=[]
for asset in assets:
    race=asset['report']['race']; hashes={o['part']:shape_hash(o) for o in asset['parts']}
    changed=[name for name in hashes if hashes[name]!=baseline[race]['hashes'][name]]
    expected=set(o['part'] for o in tools) if race=='orc' else (set(o['part'] for o in elf_tools) if race=='elf' else set())
    assert set(changed)==expected,(race,changed)
    if race not in ('elf','orc'): continue
    bpy.context.window.scene=asset['scene']
    asset['animation']=namespace['validate'](asset,asset['rig'],asset['bones'],asset['chains'],hashes)
    asset['report']['animation']=asset['animation']
    by={o['part']:o for o in asset['parts']}; clips={}
    for clip,count in namespace['LENGTHS'].items():
        min_elbow=1e9; min_forward=1e9; gaps={}; min_staff_gap=1e9
        grip_contact=0
        for frame in np.linspace(0,count-1,2*count-1):
            asset['scene'].frame_set(namespace['STARTS'][clip]+int(frame),subframe=float(frame%1)); asset['scene'].view_layers[0].update()
            rig=asset['rig']; delta={b.name:b.matrix@rig.data.bones[b.name].matrix_local.inverted() for b in rig.pose.bones}
            if race=='elf':
                a,b,c,g=asset['chains']['arm_r']; shoulder=delta['chest']@a; elbow=delta['forearm_r']@b; wrist=delta['hand_r']@c
                min_elbow=min(min_elbow,elbow.y-wrist.y); min_forward=min(min_forward,shoulder.y-wrist.y)
                for obj in elf_tools:
                    for part in ('Forearm_r','UpperArm_r','Chest','Belly','Pelvis','Thigh_r','Shin_r'):
                        gap=separation(vertices(obj,delta),vertices(by[part],delta))
                        assert gap>.0001,(race,clip,frame,obj['part'],part,'staff intersects body',gap)
                        if part=='Forearm_r': min_staff_gap=min(min_staff_gap,gap)
                contact=separation(vertices(by['Walking_staff'],delta),vertices(by['Hand_r'],delta))
                assert contact<-.005,('Elf lost staff grip',clip,frame,contact)
                grip_contact=max(grip_contact,contact)
            else:
                for tool in tools:
                    for part in ('Forearm_r','UpperArm_r','Chest','Belly','Pelvis','Thigh_r','Shin_r'):
                        key=tool['part']+' / '+part
                        gap=separation(vertices(tool,delta),vertices(by[part],delta))
                        gaps[key]=min(gaps.get(key,1e9),gap)
                        assert gap>.0001,(race,clip,frame,key,'tool intersects body',gap)
                contact=separation(vertices(by['Mallet_handle'],delta),vertices(by['Hand_r'],delta))
                assert contact<-.005,('Orc lost mallet grip',clip,frame,contact)
                grip_contact=max(grip_contact,contact)
        if race=='elf':
            assert min_elbow>.05 and min_forward>.10,(clip,'elf backwards elbow',min_elbow,min_forward)
            clips[clip]=dict(frames=count,samples=2*count-1,min_elbow_behind_wrist_m=min_elbow,min_wrist_forward_of_shoulder_m=min_forward,min_staff_forearm_gap_m=min_staff_gap,hand_contact=True)
        else: clips[clip]=dict(frames=count,samples=2*count-1,minimum_clearance_m=min(gaps.values()),pair_clearances_m=gaps,hand_contact=True)
    asset['report']['grip_correction']=dict(status='PASS',changed_geometry=changed,changed_animation_bones=list(names) if race=='elf' else [],clips=clips)
    asset['scene'].frame_set(1)
    checks.append(dict(race=race,**asset['report']['grip_correction']))
bpy.context.window.scene=review['scene']; review['scene'].frame_set(161)
report=dict(status='PASS',pipeline='Live Blender MCP localhost:9876',assets=checks,human_and_dwarf_unchanged=True,all_unrelated_geometry_unchanged=True,unrelated_elf_animation_channels_unchanged=True)
(WORK/'grip_fix/validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(ROOT/'docs/settlers_grip_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(ROOT/'docs/settlers_animation_blender_validation.json').write_text(json.dumps(dict(status='PASS',verified=4,clips=8,fps=48,review_scene=review['scene'].name,assets=[dict(race=a['report']['race'],animation=a['animation'],arm_correction=a['report']['arm_correction']) for a in assets]),ensure_ascii=False,indent=2),encoding='utf-8')
result=report
