"""Rig the user-approved static Minotaur and bake Idle/Walk/Attack via Blender MCP.
Same method as Troll/Goblin V3: rigid block skinning (one bone per part), FK
delivery rig, feet planted with an analytic two-bone solve baked into the bones.
Run INSIDE Blender through blender_mcp_client.py. Refuses to replace an existing rig.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Minotaur_Blocky_V1'
OUT=ROOT/'assets/generated/minotaurs/minotaur_blocky_v1'
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
assert NAME+'_Rig' not in bpy.data.objects, 'Existing rig: preserve manual animation edits.'
root=bpy.data.objects[NAME+'_ROOT']
parts=[o for o in scene.objects if o.type=='MESH' and not o.name.endswith('StudioGround')]
def short(o): return o.name.removeprefix(NAME+'_').split('.')[0]
# Bake any object-level offsets (e.g. hand-moved ankle bands) into the mesh so
# every part shares the identity transform of the rig.
for o in parts:
    if o.matrix_basis!=Matrix.Identity(4):
        o.data.transform(o.matrix_basis); o.matrix_basis=Matrix.Identity(4)

GRIP=Vector((-.865,-.25,.92)); AXIS=Vector((0,-.60,-.80)).normalized()
specs={}
def bone(n,h,t,p=None): specs[n]=(Vector(h),Vector(t),p)
bone('root',(0,0,0),(0,0,.25))
bone('pelvis',(0,.03,1.10),(0,.02,1.38),'root')
bone('spine',(0,.02,1.25),(0,-.04,1.58),'pelvis')
bone('chest',(0,-.04,1.58),(0,-.12,2.20),'spine')
bone('head',(0,-.30,2.05),(0,-.40,2.45),'chest')
bone('jaw',(0,-.45,1.92),(0,-.85,1.90),'head')
bone('loin_front',(0,-.24,1.25),(0,-.36,.85),'pelvis')
bone('loin_back',(0,.28,1.25),(0,.36,.88),'pelvis')
bone('tail',(0,.30,1.17),(0,.47,.80),'pelvis')
for side,k in [('l',1),('r',-1)]:
    bone('shoulder_'+side,(k*.30,-.05,2.02),(k*.72,-.05,1.95),'chest')
    bone('upper_arm_'+side,(k*.72,-.05,1.95),(k*.81,-.13,1.52),'shoulder_'+side)
    bone('forearm_'+side,(k*.81,-.13,1.52),(k*.86,-.23,1.04),'upper_arm_'+side)
    bone('hand_'+side,(k*.86,-.23,1.04),(k*.865,-.25,.80),'forearm_'+side)
    bone('thigh_'+side,(k*.22,.05,1.10),(k*.25,-.06,.60),'pelvis')
    bone('shin_'+side,(k*.25,-.06,.60),(k*.27,.03,.17),'thigh_'+side)
    bone('foot_'+side,(k*.27,.03,.17),(k*.27,-.25,.17),'shin_'+side)
bone('weapon',GRIP,GRIP+AXIS*.55,'hand_r')

collection=bpy.data.collections.new(NAME+'_06_RIG'); scene.collection.children.link(collection)
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); collection.objects.link(rig)
rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,parent) in specs.items():
    b=arm.edit_bones.new(n); b.head=h; b.tail=t
    if parent: b.parent=arm.edit_bones[parent]
    b.use_deform=n!='root'
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True; arm.display_type='STICK'

fixed={'Chest':'chest','Abdomen':'spine','Pelvis':'pelvis','Belt':'pelvis','Buckle':'pelvis',
       'LoinFront':'loin_front','LoinBack':'loin_back','Tail':'tail','TailTuft':'tail','Jaw':'jaw'}
prefixes=[('Shoulder','shoulder'),('UpperArm','upper_arm'),('Elbow','forearm'),('Forearm','forearm'),
          ('Bracer','forearm'),('Hand','hand'),('Thigh','thigh'),('Knee','shin'),('Shin','shin'),
          ('AnkleBand','foot'),('Hoof','foot')]
for o in parts:
    part=short(o); n=fixed.get(part)
    if part.startswith('Labrys_'): n='weapon'
    elif n is None and any(c.name.endswith('02_HEAD_HORNS') for c in o.users_collection): n='head'
    for prefix,target in prefixes:
        if part.startswith(prefix+'_'): n=target+'_'+part.split('_')[1][0]
    assert n in specs,(part,n)
    o.vertex_groups.clear()
    o.vertex_groups.new(name=n).add(list(range(len(o.data.vertices))),1,'REPLACE'); o['bone']=n
    for m in [m for m in o.modifiers if m.type=='ARMATURE']: o.modifiers.remove(m)
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
    # Authored in character axes (X right, -Y forward, Z up), converted to the bone's rest frame.
    # +X tips a hanging limb backwards / a torso forwards; -X raises an arm forwards.
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

# The axe arm always carries the labrys with a bent elbow (same in Idle/Walk and
# at the start/end of Attack) so clips crossfade cleanly and the head never drags.
CARRY=.40
# IDLE: heavy breathing through chest and shoulders, a slow snort of the head,
# swaying tail and labrys, hooves planted. 48-frame loop (2.0 s).
action('Minotaur_Idle',49,True,1,'Heavy breathing, shoulders rise, slow head snort, tail and labrys sway; hooves planted.')
for f in range(1,50):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/48; wave=math.sin(p); breath=(1-math.cos(p))/2
    offset((0,0,-.010*breath))
    rotate('spine',(.012*wave,0,0)); rotate('chest',(-.028*breath+.010,0,.006*math.sin(p*2)))
    rotate('head',(.030*breath-.010+.012*math.sin(p*2),0,.020*math.sin(p)))
    rotate('jaw',(.035*breath,0,0))
    for side,k in [('l',1),('r',-1)]:
        rotate('shoulder_'+side,(0,-k*.035*breath,0))
        rotate('upper_arm_'+side,(.012*math.sin(p-.4)-.012*math.sin(-.4),-k*.010*breath,0))
        rotate('forearm_'+side,(-.020*breath-(CARRY if side=='r' else 0),0,0))
    rotate('hand_r',(.025*math.sin(p-.8)-.025*math.sin(-.8),0,0))
    rotate('tail',(.05*math.sin(p),0,.10*math.sin(p)))
    rotate('loin_front',(-.020*breath,0,0)); rotate('loin_back',(.015*breath,0,0))
    for side in ('l','r'): plant(side,resthead['foot_'+side],'Minotaur_Idle',f)
    bake(f)

# WALK: heavy hunched stomp in place, 60% stance, low pelvis, the empty arm
# swings wide while the axe arm swings less (weight).
action('Minotaur_Walk',29,True,61,'28-frame heavy hunched stomp in place; 60% stance, opposite arm swing, axe arm damped.')
HALF=.17; LIFT=.10; STANCE=.60
def footpath(t):
    t%=1
    if t<STANCE: return -HALF+2*HALF*t/STANCE,0,True
    a=(t-STANCE)/(1-STANCE); ease=a*a*(3-2*a)
    return HALF-2*HALF*ease,LIFT*math.sin(math.pi*a)**1.2,False
for f in range(1,30):
    scene.frame_set(f); reset(); t=(f-1)/28; p=math.tau*t
    offset((.022*math.sin(p),0,-.050-.012*math.cos(2*p)))
    rotate('pelvis',(0,0,.030*math.sin(p)))
    rotate('spine',(.05,0,-.025*math.sin(p))); rotate('chest',(.06,0,.050*math.sin(p)))
    rotate('head',(-.09+.02*math.cos(2*p),0,-.030*math.sin(p)))
    rotate('jaw',(.02+.02*math.cos(2*p),0,0))
    rotate('shoulder_l',(0,-.02*math.cos(2*p),0)); rotate('shoulder_r',(0,.02*math.cos(2*p),0))
    rotate('upper_arm_l',(.26*math.cos(p),-.04,0)); rotate('upper_arm_r',(-.15*math.cos(p),.03,0))
    # The axe arm carries the labrys with a bent elbow so the head clears the ground.
    rotate('forearm_l',(-.16-.05*math.sin(p),0,0)); rotate('forearm_r',(-CARRY+.03*math.sin(p),0,0))
    rotate('hand_r',(.05*math.sin(p-.4),0,0))
    rotate('tail',(.10+.05*math.sin(2*p),0,.16*math.sin(p)))
    rotate('loin_front',(-.10-.12*abs(math.cos(p)),0,0)); rotate('loin_back',(.08+.08*abs(math.cos(p)),0,0))
    for side,phase in [('l',0),('r',.5)]:
        dy,lift,stance=footpath(t+phase); plant(side,resthead['foot_'+side]+Vector((0,dy,lift)),'Minotaur_Walk',f)
        contact[(f,side)]=stance
    bake(f)
clips['Minotaur_Walk']['suggested_translation_mps']=2*HALF/(STANCE*28/24)

# ATTACK: one-handed overhead labrys chop with a roar. The labrys bits lie in the
# swing plane, so the lower edge (not the flat) leads into the target at impact. Wind-up 1-13 (axe raised
# behind the head, chest twisted back, jaw open), swing 13-19, IMPACT 19,
# follow-through 23, recovery to 37.
action('Minotaur_Attack',37,False,101,'Overhead labrys chop with roar: wind-up 1-13, impact 19, follow-through 23, recovery 37.')
# With the arm raised past horizontal, -Y abducts it (keeps the haft clear of the right horn).
# ua_x, ua_y, fa_x, hand_x, chest_x, chest_z, spine_x, pelvis_y, pelvis_z, jaw, head_x
poses={1:(0,0,-CARRY,0, 0,0,0, 0,0, 0,0),
       9:(-2.25,-.26,-.95,.20, -.13,-.24,-.06, .020,-.020, .30,-.10),
       13:(-2.40,-.30,-1.05,.25, -.16,-.27,-.07, .025,-.025, .34,-.12),
       17:(-1.45,-.05,-.35,.05, .20,.10,.09, -.030,-.060, .22,.02),
       19:(-1.00,.08,-.10,.10, .30,.18,.14, -.040,-.075, .16,.08),
       23:(-.85,.06,-.10,.20, .31,.19,.14, -.042,-.078, .10,.08),
       30:(-.30,.03,-.30,.10, .12,.07,.05, -.015,-.030, .03,.03),
       37:(0,0,-CARRY,0, 0,0,0, 0,0, 0,0)}
for f in range(1,38):
    scene.frame_set(f); reset(); lo=max(k for k in poses if k<=f); hi=min(k for k in poses if k>=f)
    t=0 if lo==hi else (f-lo)/(hi-lo); t=t*t*(3-2*t); v=[a+(b-a)*t for a,b in zip(poses[lo],poses[hi])]
    intensity=math.sin(math.pi*(f-1)/36)
    offset((.010*intensity,v[7],v[8])); rotate('spine',(v[6],0,v[5]*.4)); rotate('chest',(v[4],0,v[5]))
    rotate('head',(v[10]-.5*v[4],0,-v[5]*.6)); rotate('jaw',(v[9],0,0))
    rotate('upper_arm_r',(v[0],v[1],0)); rotate('forearm_r',(v[2],0,0)); rotate('hand_r',(v[3],0,0))
    rotate('shoulder_r',(0,.10*intensity,0))
    rotate('upper_arm_l',(-.30*intensity,-.14*intensity,0)); rotate('forearm_l',(-.35*intensity,0,0))
    rotate('tail',(.10*intensity,0,.18*math.sin(math.tau*(f-1)/36)))
    rotate('loin_front',(-.08*intensity,0,0)); rotate('loin_back',(.05*intensity,0,0))
    for side in ('l','r'): plant(side,resthead['foot_'+side],'Minotaur_Attack',f)
    bake(f)
clips['Minotaur_Attack']['impact_frame']=19
assert not unreachable,unreachable

for data in clips.values():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    marks=[('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else \
          [('START',1),('WINDUP',13),('IMPACT',19),('FOLLOW_THROUGH',23),('RECOVERED',37)]
    for label,frame in marks: a.pose_markers.new(label).frame=frame
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['nla_start'],data['action']); strip.extrapolation='NOTHING'
    strip.action_frame_start=1; strip.action_frame_end=data['end']; strip.blend_type='REPLACE'
    scene.timeline_markers.new(name,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=137; scene.frame_set(1)
rig['notes']='Editable separate block meshes; rigid skinning; baked analytic hoof planting; no runtime IK.'
rig['walk_in_place_speed_mps']=clips['Minotaur_Walk']['suggested_translation_mps']
scene['animations_requested']=True
bpy.app.driver_namespace['minotaur_animation']={'name':NAME,'scene':scene,'rig':rig,'root':root,'meshes':parts,
 'out':str(OUT),'clips':clips,'targets':targets,'contact':contact}
result={'bones':len(specs),'meshes':len(parts),'unreachable_targets':len(unreachable),
        'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()},
        'bone_map':{short(o):o['bone'] for o in parts}}
