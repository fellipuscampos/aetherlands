"""FK delivery rig with analytically planted feet, baked to three actions/NLA."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

state=bpy.app.driver_namespace['troll_refinement']; scene=state['scene']; parts=state['parts']
NAME=state['name']; S=state['scale']; specs=state['bone_specs']; report=state['report']
bpy.context.window.scene=scene
if bpy.data.objects.get(NAME+'_Rig'): raise RuntimeError('Rig exists; preserve animation edits.')
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); parts.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name,(head,tail,parent) in specs.items():
    bone=arm.edit_bones.new(name); bone.head=Vector(head)*S; bone.tail=Vector(tail)*S
    if parent: bone.parent=arm.edit_bones[parent]
    bone.use_deform=name!='root'
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True; arm.display_type='OCTAHEDRAL'
for obj in list(parts.objects):
    if obj.type!='MESH': continue
    obj.vertex_groups.new(name=obj['bone']).add(list(range(len(obj.data.vertices))),1,'REPLACE')

def join(objs,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name; obj.data.name=name+'_Mesh'; obj.parent=rig
    mod=obj.modifiers.new('Skin','ARMATURE'); mod.object=rig
    return obj
body=join([o for o in parts.objects if o.type=='MESH' and o['bone']!='weapon'],NAME+'_Body')
weapon=join([o for o in parts.objects if o.type=='MESH' and o['bone']=='weapon'],NAME+'_Club')
state['rig']=rig; state['meshes']=[body,weapon]
rig['notes']='Block-preserving FK skin. Feet solved analytically and baked; no runtime IK dependency. Cloth pivots prevent thigh penetration.'
rig['height_m']=2.5; rig['forward_axis']='Blender -Y / glTF +Z'; rig['walk_in_place_speed_mps']=.34/(.60*28/24)

leg_names={f'{part}_{side}' for part in ('thigh','shin','foot') for side in ('l','r')}
rest={b.name:b.matrix_local.copy() for b in arm.bones}
restq={name:mat.to_quaternion() for name,mat in rest.items()}
resthead={b.name:b.head_local.copy() for b in arm.bones}
restvec={b.name:b.tail_local-b.head_local for b in arm.bones}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION' if pb.name in leg_names else 'XYZ'

def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_euler=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def rotate(name,value): rig.pose.bones[name].rotation_euler=value
def pelvis_offset(value): rig.pose.bones['pelvis'].location=restq['pelvis'].inverted()@Vector(value)

foot_targets={}; unreachable=[]
def plant(side,target,frame,clip):
    thigh=rig.pose.bones['thigh_'+side]; shin=rig.pose.bones['shin_'+side]; foot=rig.pose.bones['foot_'+side]
    bpy.context.view_layer.update()
    hip=thigh.head.copy(); target=Vector(target)
    length1=restvec[thigh.name].length; length2=restvec[shin.name].length
    line=target-hip; dist=line.length
    if dist>length1+length2+.00001: unreachable.append((clip,frame,side,dist-length1-length2))
    d=max(.001,min(dist,length1+length2-.000001)); direction=line.normalized()
    along=(length1*length1-length2*length2+d*d)/(2*d)
    height=math.sqrt(max(0,length1*length1-along*along))
    pole=Vector((0,-1,0)); pole=(pole-direction*pole.dot(direction)).normalized()
    knee=hip+direction*along+pole*height
    q=restvec[thigh.name].rotation_difference(knee-hip)@restq[thigh.name]
    thigh.matrix=Matrix.Translation(hip)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    q=restvec[shin.name].rotation_difference(target-knee)@restq[shin.name]
    shin.matrix=Matrix.Translation(knee)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    foot.matrix=Matrix.Translation(target)@restq[foot.name].to_matrix().to_4x4()
    bpy.context.view_layer.update()
    foot_targets[(clip,frame,side)]=tuple(target)

def bake(frame):
    for pb in rig.pose.bones:
        path='rotation_quaternion' if pb.name in leg_names else 'rotation_euler'
        pb.keyframe_insert(data_path=path,frame=frame,group=pb.name)
        pb.keyframe_insert(data_path='location',frame=frame,group=pb.name)

clips={}
rig.animation_data_create()
def new_action(name):
    action=bpy.data.actions.new(name); action.use_fake_user=True
    rig.animation_data.action=action
    return action

idle=new_action('Troll_Idle')
for frame in range(1,50):
    scene.frame_set(frame); reset()
    phase=math.tau*(frame-1)/48; wave=math.sin(phase); breath=(1-math.cos(phase))/2
    pelvis_offset((0,0,-.006*breath))
    rotate('spine_01',(.010*wave,0,0)); rotate('chest',(-.017*wave,0,.005*math.sin(phase*2)))
    rotate('head',(.007*wave,0,-.005*math.sin(phase*2)))
    for side,sign in [('l',1),('r',-1)]:
        rotate('shoulder_'+side,(.008*wave,0,sign*.007*wave))
        rotate('upper_arm_'+side,(.010*math.sin(phase-.2)-.010*math.sin(-.2),0,sign*.008*wave))
        rotate('forearm_'+side,(-.009*wave,0,0))
    rotate('hand_r',(.012*wave,0,0))
    rotate('loincloth_front',(-.018*breath,0,0))
    for side in ('l','r'): plant(side,resthead['foot_'+side],frame,'Troll_Idle')
    bake(frame)
clips['Troll_Idle']={'action':idle,'start':1,'end':49,'loop':True,'nla_start':1,'description':'Subtle breathing; planted feet; restrained arm and weapon motion'}

walk=new_action('Troll_Walk'); walk_contact={}
def foot_path(phase):
    phase%=1; half_stride=.17; contact=phase<.60
    if contact:
        y=-half_stride+2*half_stride*phase/.60; lift=0
    else:
        t=(phase-.60)/.40
        ease=t*t*(3-2*t)
        y=half_stride-2*half_stride*ease; lift=.09*math.sin(math.pi*t)**1.2
    return y,lift,contact
for frame in range(1,30):
    scene.frame_set(frame); reset(); t=(frame-1)/28; phase=math.tau*t
    pelvis_offset((.022*math.sin(phase),0,-.045+.008*math.cos(2*phase)))
    rotate('pelvis',(0,0,.025*math.sin(phase)))
    rotate('spine_01',(.035,0,-.025*math.sin(phase)))
    rotate('chest',(.025,0,.043*math.sin(phase)))
    rotate('head',(-.035,0,-.02*math.sin(phase)))
    rotate('upper_arm_l',(.23*math.cos(phase),0,-.025))
    rotate('upper_arm_r',(-.135*math.cos(phase),0,.018))
    rotate('forearm_l',(-.13-.035*math.sin(phase),0,0))
    rotate('forearm_r',(-.09+.028*math.sin(phase),0,0))
    rotate('hand_r',(.035*math.sin(phase-.4),0,0))
    rotate('loincloth_front',(-.12-.12*abs(math.cos(phase)),0,0))
    rotate('loincloth_back',(.08+.08*abs(math.cos(phase)),0,0))
    for side,offset in [('l',0),('r',.5)]:
        dy,lift,contact=foot_path(t+offset)
        target=resthead['foot_'+side]+Vector((0,dy,lift))
        plant(side,target,frame,'Troll_Walk')
        walk_contact[(frame,side)]=contact
    bake(frame)
clips['Troll_Walk']={'action':walk,'start':1,'end':29,'loop':True,'nla_start':61,
 'description':'28-frame heavy in-place gait, 60% stance, planted support foot, opposite arm swing',
 'suggested_translation_mps':.34/(.60*28/24)}

# Sampled smooth-step stages make the acceleration into impact explicit.
attack=new_action('Troll_Attack')
attack_keys={
 1:{'upper_arm_r':(0,0,0),'forearm_r':(0,0,0),'hand_r':(0,0,0),'chest':(0,0,0),'pelvis_z':0},
 7:{'upper_arm_r':(-.65,0,.10),'forearm_r':(-.60,0,0),'hand_r':(.08,0,0),'chest':(-.02,0,-.10),'pelvis_z':-.025},
 13:{'upper_arm_r':(-2.05,0,.20),'forearm_r':(-.90,0,0),'hand_r':(.15,0,0),'chest':(-.10,0,-.17),'pelvis_z':-.015},
 17:{'upper_arm_r':(-2.05,0,.20),'forearm_r':(-.90,0,0),'hand_r':(.15,0,0),'chest':(-.10,0,-.17),'pelvis_z':-.018},
 21:{'upper_arm_r':(-.70,0,.05),'forearm_r':(-.10,0,0),'hand_r':(.85,0,0),'chest':(.25,0,.16),'pelvis_z':-.035},
 24:{'upper_arm_r':(-.30,0,.04),'forearm_r':(.10,0,0),'hand_r':(.60,0,0),'chest':(.28,0,.20),'pelvis_z':-.042},
 30:{'upper_arm_r':(-.40,0,.08),'forearm_r':(-.35,0,0),'hand_r':(.15,0,0),'chest':(.08,0,.05),'pelvis_z':-.018},
 37:{'upper_arm_r':(0,0,0),'forearm_r':(0,0,0),'hand_r':(0,0,0),'chest':(0,0,0),'pelvis_z':0}}
keyframes=sorted(attack_keys)
for frame in range(1,38):
    scene.frame_set(frame); reset()
    lo=max(f for f in keyframes if f<=frame); hi=min(f for f in keyframes if f>=frame)
    t=0 if hi==lo else (frame-lo)/(hi-lo); ease=t*t*(3-2*t)
    pose={}
    for n,a in attack_keys[lo].items():
        b=attack_keys[hi][n]
        pose[n]=a+(b-a)*ease if isinstance(a,(float,int)) else tuple(x+(y-x)*ease for x,y in zip(a,b))
    pelvis_offset((0,0,pose.pop('pelvis_z')))
    for n,value in pose.items(): rotate(n,value)
    intensity=math.sin(math.pi*(frame-1)/36)
    rotate('upper_arm_l',(-.28*intensity,0,-.16*intensity)); rotate('forearm_l',(-.23*intensity,0,0))
    rotate('head',(-pose['chest'][0]*.65,0,-pose['chest'][2]*.6))
    rotate('loincloth_front',(-.06*intensity,0,0)); rotate('loincloth_back',(.035*intensity,0,0))
    for side in ('l','r'): plant(side,resthead['foot_'+side],frame,'Troll_Attack')
    bake(frame)
clips['Troll_Attack']={'action':attack,'start':1,'end':37,'loop':False,'nla_start':101,
 'description':'Wind-up 1-13, hold 13-17, impact frame 21, follow-through 24, recovery to 37',
 'impact_frame':21}
assert not unreachable,unreachable

# Linear interpolation between per-frame samples avoids curve overshoot below
# the ground. The sampled trajectories themselves use sine/smooth-step curves.
for data in clips.values():
    action=data['action']
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    action['loop']=data['loop']; action['fps']=24
    if data['loop']:
        action.pose_markers.new('LOOP_START').frame=data['start']
        action.pose_markers.new('LOOP_END').frame=data['end']
    else:
        for f,label in [(1,'START'),(13,'WINDUP'),(21,'IMPACT'),(24,'FOLLOW_THROUGH'),(37,'RECOVERED')]:
            action.pose_markers.new(label).frame=f

# Organized NLA timeline: one named track per clip, non-overlapping placement.
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['nla_start'],data['action'])
    strip.action_frame_start=data['start']; strip.action_frame_end=data['end']
    strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'; strip.use_auto_blend=False
    scene.timeline_markers.new(name,frame=data['nla_start'])
scene.frame_start=1; scene.frame_end=137; scene.frame_set(1); reset(); bpy.context.view_layer.update()
state['clips']=clips; state['foot_targets']=foot_targets; state['walk_contact']=walk_contact
report['bone_count']=len(specs); report['bones']=list(specs)
report['animations']={name:{k:v for k,v in data.items() if k!='action'} for name,data in clips.items()}
report['skinning']='Rigid block skinning; feet use baked analytic IK, runtime FK only'
bpy.ops.wm.save_as_mainfile(filepath=str(Path(state['source'])/'troll_blocky_v3_refinement_work.blend'))
result={'rig_bones':len(specs),'actions':report['animations'],'unreachable_foot_targets':len(unreachable)}
