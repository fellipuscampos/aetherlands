"""Rig the approved editable Goblin and bake Idle/Walk/Attack via Blender MCP."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Goblin_Raider_V3'; S=1.3/3.3
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
source=ROOT/'art_source/goblin_raider_v3'; out=ROOT/'assets/generated/goblins/goblin_raider_v3'
parts=[o for o in scene.objects if o.type=='MESH' and o.get('part')!='StudioGround']
assert len(parts)==49
assert NAME+'_Rig' not in bpy.data.objects, 'Existing rig: preserve manual edits.'
# Keep an isolated copy of the approved static source before adding animation.
backup=source/'goblin_raider_v3_static.blend'
if not backup.exists(): bpy.data.libraries.write(str(backup),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
specs={}
def bone(n,h,t,p=None): specs[n]=(Vector(h)*S,Vector(t)*S,p)
bone('root',(0,0,0),(0,0,.25))
bone('pelvis',(0,.01,1.50),(0,.01,1.80),'root')
bone('chest',(0,.01,1.91),(0,.07,2.53),'pelvis')
bone('head',(0,-.15,2.52),(0,-.15,3.05),'chest')
bone('rag_front',(0,-.22,1.585),(0,-.22,1.30),'pelvis')
bone('rag_back',(0,.24,1.585),(0,.24,1.30),'pelvis')
bone('loot',(.40,-.14,1.70),(.40,-.14,1.40),'pelvis')
for side,k in [('l',1),('r',-1)]:
    bone('shoulder_'+side,(k*.38,.055,2.44),(k*.46,.055,2.44),'chest')
    bone('upper_arm_'+side,(k*.46,.055,2.44),(k*.61,-.005,1.99),'shoulder_'+side)
    bone('forearm_'+side,(k*.61,-.005,1.99),(k*.69,-.11,1.52),'upper_arm_'+side)
    bone('hand_'+side,(k*.69,-.11,1.52),(k*.703,-.13,1.35),'forearm_'+side)
    bone('thigh_'+side,(k*.18,.01,1.39),(k*.235,-.05,.89),'pelvis')
    bone('shin_'+side,(k*.235,-.05,.89),(k*.255,.025,.23),'thigh_'+side)
    bone('foot_'+side,(k*.255,.025,.23),(k*.255,-.40,.23),'shin_'+side)
bone('weapon',(-.703,-.13,1.402),(-.78,-.47,1.05),'hand_r')
collection=bpy.data.collections.new(NAME+'_06_RIG'); scene.collection.children.link(collection)
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); collection.objects.link(rig)
rig.parent=bpy.data.objects[NAME+'_ROOT']
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,parent) in specs.items():
    b=arm.edit_bones.new(n); b.head=h; b.tail=t
    if parent: b.parent=arm.edit_bones[parent]
    b.use_deform=n!='root'
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True; arm.display_type='STICK'
mapping={'Chest':'chest','UpperBack':'chest','Abdomen':'pelvis','Pelvis':'pelvis',
         'Belt':'pelvis','BeltKnot':'pelvis','RagFront':'rag_front','RagBack':'rag_back'}
for o in parts:
    part=o['part']
    if part in ('ChestStrap','BackStrap'):
        groups={n:o.vertex_groups.new(name=n) for n in ('pelvis','chest')}
        for v in o.data.vertices:
            w=max(0,min(1,(v.co.z/S-1.70)/.48))
            for n,weight in [('pelvis',1-w),('chest',w)]:
                if weight>0: groups[n].add([v.index],weight,'REPLACE')
        o['bone']='pelvis/chest weighted strap'
    else:
        n=mapping.get(part)
        if part.startswith('Loot_'): n='loot'
        if part.startswith('Dagger_'): n='weapon'
        if any(c.name.endswith('02_FACE_EARS') for c in o.users_collection): n='head'
        for prefix,target in [('Shoulder','shoulder'),('UpperArm','upper_arm'),('Elbow','forearm'),
                              ('Forearm','forearm'),('Hand','hand'),('Thigh','thigh'),('Knee','shin'),
                              ('Shin','shin'),('Foot','foot'),('AnkleWrap','foot')]:
            if part.startswith(prefix+'_'): n=target+'_'+part[-1]
        assert n,part
        o.vertex_groups.new(name=n).add(list(range(len(o.data.vertices))),1,'REPLACE'); o['bone']=n
    mod=o.modifiers.new('Block_preserving_skin','ARMATURE'); mod.object=rig
    o.parent=rig

rest={b.name:b.matrix_local.copy() for b in arm.bones}
restq={n:m.to_quaternion() for n,m in rest.items()}
resthead={b.name:b.head_local.copy() for b in arm.bones}
restvec={b.name:b.tail_local-b.head_local for b in arm.bones}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def rotate(n,xyz):
    # Author in character axes, convert to each bone's own rest orientation.
    rig.pose.bones[n].rotation_quaternion=restq[n].inverted()@Euler(xyz,'XYZ').to_quaternion()@restq[n]
def offset(v): rig.pose.bones['pelvis'].location=restq['pelvis'].inverted()@Vector(v)
targets={}; contact={}; unreachable=[]
def plant(side,target,clip,frame):
    thigh=rig.pose.bones['thigh_'+side]; shin=rig.pose.bones['shin_'+side]; foot=rig.pose.bones['foot_'+side]
    bpy.context.view_layer.update(); hip=thigh.head.copy(); target=Vector(target)
    l1=restvec[thigh.name].length; l2=restvec[shin.name].length
    line=target-hip; distance=line.length
    if distance>l1+l2+1e-5: unreachable.append((clip,frame,side,distance-l1-l2))
    d=max(.001,min(distance,l1+l2-1e-6)); direction=line.normalized()
    along=(l1*l1-l2*l2+d*d)/(2*d); height=math.sqrt(max(0,l1*l1-along*along))
    pole=Vector((0,-1,0)); pole=(pole-direction*pole.dot(direction)).normalized()
    knee=hip+direction*along+pole*height
    q=restvec[thigh.name].rotation_difference(knee-hip)@restq[thigh.name]
    thigh.matrix=Matrix.Translation(hip)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    q=restvec[shin.name].rotation_difference(target-knee)@restq[shin.name]
    shin.matrix=Matrix.Translation(knee)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    foot.matrix=Matrix.Translation(target)@restq[foot.name].to_matrix().to_4x4()
    bpy.context.view_layer.update(); targets[(clip,frame,side)]=tuple(target)
def bake(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=pb.name)
        pb.keyframe_insert(data_path='location',frame=frame,group=pb.name)
rig.animation_data_create(); clips={}
def action(name,end,loop,nla,description):
    a=bpy.data.actions.new(name); a.use_fake_user=True; rig.animation_data.action=a
    clips[name]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':nla,'description':description}
    return a

action('Goblin_Idle',61,True,1,'Cautious breathing, small head/ear silhouette motion, planted feet.')
for f in range(1,62):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/60; wave=math.sin(p); breath=(1-math.cos(p))/2
    offset((.002*wave,0,-.012-.003*breath)); rotate('chest',(.035+.014*wave,0,.008*math.sin(p*2)))
    rotate('head',(-.025-.010*wave,0,.020*math.sin(p)))
    for side,k in [('l',1),('r',-1)]:
        rotate('upper_arm_'+side,(-.045+.015*wave,-k*.08,0))
        rotate('forearm_'+side,(-.09+.018*wave,0,0))
    rotate('loot',(.012*wave,0,.013*math.sin(p-.3)))
    rotate('rag_front',(-.06,0,0)); rotate('rag_back',(.045,0,0))
    for side in ('l','r'): plant(side,resthead['foot_'+side],'Goblin_Idle',f)
    bake(f)

action('Goblin_Walk',21,True,81,'Quick crouched in-place walk; opposing arms, 58% stance and short foot lift.')
def footpath(t):
    t%=1
    if t<.58: return -.075+.15*t/.58,0,True
    a=(t-.58)/.42; ease=a*a*(3-2*a)
    return .075-.15*ease,.043*math.sin(math.pi*a)**1.4,False
for f in range(1,22):
    scene.frame_set(f); reset(); t=(f-1)/20; p=math.tau*t
    offset((.008*math.sin(p),-.006,-.031+.005*math.cos(p*2)))
    rotate('pelvis',(0,0,.035*math.sin(p)))
    rotate('chest',(.09,0,-.065*math.sin(p))); rotate('head',(-.07,0,.035*math.sin(p)))
    rotate('upper_arm_l',(-.10+.28*math.cos(p),-.12,0))
    rotate('upper_arm_r',(-.12-.23*math.cos(p),.08,0))
    rotate('forearm_l',(-.23-.07*math.sin(p),0,0)); rotate('forearm_r',(-.20+.05*math.sin(p),0,0))
    rotate('hand_r',(.05*math.cos(p),0,0)); rotate('loot',(.035*math.sin(p-.5),.035*math.sin(p),0))
    rotate('rag_front',(-.22-.15*abs(math.cos(p)),0,0)); rotate('rag_back',(.16+.13*abs(math.cos(p)),0,0))
    for side,phase in [('l',0),('r',.5)]:
        dy,lift,stance=footpath(t+phase); plant(side,resthead['foot_'+side]+Vector((0,dy,lift)),'Goblin_Walk',f)
        contact[(f,side)]=stance
    bake(f)
clips['Goblin_Walk']['suggested_translation_mps']=.15/(.58*20/24)

attack=action('Goblin_Attack',29,False,121,'Short dagger thrust: anticipation 1-8, strike 12, follow-through 15, recovery 29.')
# x upper arm, x forearm, x wrist, chest forward, chest twist, pelvis forward, pelvis down.
poses={1:(-.045,-.09,0,.035,0,0,-.012),
       6:(.25,-.95,.12,-.02,-.16,.008,-.025),
       8:(.32,-1.02,.15,-.025,-.20,.012,-.028),
       12:(-1.22,-.12,.58,.15,.20,-.047,-.042),
       15:(-1.30,-.08,.60,.17,.23,-.050,-.044),
       20:(-.55,-.46,.23,.075,.08,-.018,-.028),
       29:(-.045,-.09,0,.035,0,0,-.012)}
for f in range(1,30):
    scene.frame_set(f); reset(); lo=max(k for k in poses if k<=f); hi=min(k for k in poses if k>=f)
    t=0 if lo==hi else (f-lo)/(hi-lo); t=t*t*(3-2*t); v=[a+(b-a)*t for a,b in zip(poses[lo],poses[hi])]
    intensity=math.sin(math.pi*(f-1)/28)
    offset((-.008*intensity,v[5],v[6])); rotate('chest',(v[3],0,v[4])); rotate('head',(-.025-.5*(v[3]-.035),0,-v[4]*.65))
    rotate('upper_arm_r',(v[0],.08+.10*intensity,0)); rotate('forearm_r',(v[1],0,0)); rotate('hand_r',(v[2],0,0))
    rotate('upper_arm_l',(-.045-.23*intensity,-.08-.12*intensity,0)); rotate('forearm_l',(-.09-.30*intensity,0,0))
    rotate('rag_front',(-.06-.15*intensity,0,0)); rotate('rag_back',(.045+.08*intensity,0,0))
    rotate('loot',(.06*math.sin(math.tau*(f-1)/28),0,-.003840323))
    for side in ('l','r'): plant(side,resthead['foot_'+side],'Goblin_Attack',f)
    bake(f)
clips['Goblin_Attack']['impact_frame']=12
assert not unreachable,unreachable
for data in clips.values():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    for label,frame in ([('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else [('START',1),('ANTICIPATION',8),('IMPACT',12),('FOLLOW_THROUGH',15),('RECOVERED',29)]):
        a.pose_markers.new(label).frame=frame
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['nla_start'],data['action']); strip.extrapolation='NOTHING'
    strip.action_frame_start=1; strip.action_frame_end=data['end']; strip.blend_type='REPLACE'
    scene.timeline_markers.new(name,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=149; scene.frame_set(1)
rig['notes']='Editable separate block meshes; baked analytic foot planting; no runtime IK or external dependencies.'
rig['walk_in_place_speed_mps']=clips['Goblin_Walk']['suggested_translation_mps']
scene['animations_requested']=True
st={'name':NAME,'scene':scene,'rig':rig,'meshes':parts,'source':str(source),'out':str(out),'clips':clips,'targets':targets,'contact':contact}
bpy.app.driver_namespace['goblin_animation']=st
result={'bones':len(specs),'meshes':len(parts),'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()},'unreachable_targets':len(unreachable)}
