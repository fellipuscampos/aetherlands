"""Rig the approved static Wyvern and bake Idle/Walk/Attack via Blender MCP.
Rigid block skinning (each part follows obj['rig_bone']) EXCEPT the membranes that
connect the wing to the body: each of their corners follows the bone it is anchored
to (shoulder->upper_arm, elbow->forearm, knuckle->hand, flank->chest), so the skin
stretches between bones instead of tearing or cutting through the body. All four
supports (two hind feet, two wing knuckles) are planted with a baked analytic
two-bone solve, bending like the approved rest pose. Refuses to replace a rig.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Wyvern_Blocky_V1'; OUT=ROOT/'assets/generated/wyverns/wyvern_blocky_v1'
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
assert NAME+'_Rig' not in bpy.data.objects, 'Existing rig: preserve manual animation edits.'
root=bpy.data.objects[NAME+'_ROOT']
parts=[o for o in scene.objects if o.type=='MESH' and not o.name.endswith('StudioGround')]
for o in parts:
    if o.matrix_basis!=Matrix.Identity(4):
        o.data.transform(o.matrix_basis); o.matrix_basis=Matrix.Identity(4)
def short(o): return o.name.removeprefix(NAME+'_')

HZ=-.46
specs={}
def bone(n,h,t,p=None): specs[n]=(Vector(h),Vector(t),p)
bone('root',(0,0,0),(0,0,.25))
bone('hips',(0,.40,.76),(0,.0,.78),'root')
bone('chest',(0,.0,.78),(0,-.75,.80),'hips')
bone('neck_01',(0,-.78,.88),(0,-1.15,1.08),'chest')
bone('neck_02',(0,-1.12,1.06),(0,-1.45,1.22),'neck_01')
bone('neck_03',(0,-1.42,1.20),(0,-1.75,1.28),'neck_02')
bone('head',(0,-1.75,1.28),(0,-2.40,1.33),'neck_03')
bone('jaw',(0,-2.0,1.71+HZ),(0,-2.60,1.446+HZ),'head')
TAIL=[((0,.78,.80),(0,1.30,.66)),((0,1.25,.67),(.10,1.85,.48)),((.08,1.80,.49),(.28,2.40,.30)),((.26,2.35,.31),(.30,2.95,.17)),((.29,2.90,.175),(.15,3.40,.10))]
for i,(h,t) in enumerate(TAIL): bone('tail_%02d'%(i+1),h,t,'hips' if i==0 else 'tail_%02d'%i)
LIMBS={}; ANCHOR={}
for side,k in [('l',1),('r',-1)]:
    shoulder=(k*.33,-.55,.86); elbow=(k*.62,-.80,.56); W=(k*.66,-.94,.12)
    bone('upper_arm_'+side,shoulder,elbow,'chest')
    bone('forearm_'+side,elbow,W,'upper_arm_'+side)
    bone('hand_'+side,W,(k*.66,-1.12,.10),'forearm_'+side)
    bone('thigh_'+side,(k*.30,.45,.72),(k*.40,.20,.36),'hips')
    bone('shin_'+side,(k*.40,.20,.36),(k*.40,.48,.07),'thigh_'+side)
    bone('foot_'+side,(k*.40,.48,.07),(k*.40,.20,.05),'shin_'+side)
    LIMBS['wing_'+side]=('upper_arm_'+side,'forearm_'+side,'hand_'+side)
    LIMBS['hind_'+side]=('thigh_'+side,'shin_'+side,'foot_'+side)
    ANCHOR[side]=[(Vector(shoulder),'upper_arm_'+side),(Vector(elbow),'forearm_'+side),(Vector(W),'hand_'+side),
                  (Vector((k*.37,.20,.95)),'chest')]

collection=bpy.data.collections.new(NAME+'_07_RIG'); scene.collection.children.link(collection)
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); collection.objects.link(rig)
rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,parent) in specs.items():
    b=arm.edit_bones.new(n); b.head=h; b.tail=t
    if parent: b.parent=arm.edit_bones[parent]
    b.use_deform=n!='root'
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True; arm.display_type='STICK'
STRETCH=('Membrane5_','MembraneElbow_','MembraneArm_')
weighted=[]
for o in parts:
    o.vertex_groups.clear()
    for m in [m for m in o.modifiers if m.type=='ARMATURE']: o.modifiers.remove(m)
    if short(o).startswith(STRETCH):
        # Each corner follows the bone it is anchored to (nearest anchor point).
        # A corner vertex sits on its anchor point (within the membrane half-thickness);
        # any other vertex (finger tips, scallop point) follows the panel's own bone.
        side=short(o)[-1]; groups={}
        for v in o.data.vertices:
            point,n=min(ANCHOR[side],key=lambda a:(a[0]-v.co).length)
            if (point-v.co).length>.05: n=o['rig_bone']
            if n not in groups: groups[n]=o.vertex_groups.new(name=n)
            groups[n].add([v.index],1,'REPLACE')
        o['bone']='stretch:'+','.join(sorted(groups)); weighted.append(short(o))
    else:
        n=o['rig_bone']; assert n in specs,(o.name,n)
        o.vertex_groups.new(name=n).add(list(range(len(o.data.vertices))),1,'REPLACE'); o['bone']=n
    mod=o.modifiers.new('Block_preserving_skin','ARMATURE'); mod.object=rig
    o.parent=rig

rest={b.name:b.matrix_local.copy() for b in arm.bones}
restq={n:m.to_quaternion() for n,m in rest.items()}
resthead={b.name:b.head_local.copy() for b in arm.bones}
restvec={b.name:b.tail_local-b.head_local for b in arm.bones}
POLE={}
for leg,(a,b,c) in LIMBS.items():
    hip,knee,ankle=resthead[a],resthead[b],resthead[c]; d=(ankle-hip).normalized()
    POLE[leg]=((knee-hip)-d*(knee-hip).dot(d)).normalized()
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def rotate(n,xyz):
    # Character axes (X right, -Y forward, Z up): +X pitches a forward-pointing tip
    # down / leans an upward bone forward; +Z swings a forward tip towards +X.
    rig.pose.bones[n].rotation_quaternion=restq[n].inverted()@Euler(xyz,'XYZ').to_quaternion()@restq[n]
def offset(v): rig.pose.bones['hips'].location=restq['hips'].inverted()@Vector(v)
targets={}; unreachable=[]
def plant(leg,target,clip,frame,end_rot=(0,0,0)):
    a,b,c=LIMBS[leg]; upper=rig.pose.bones[a]; lower=rig.pose.bones[b]; end=rig.pose.bones[c]
    bpy.context.view_layer.update(); hip=upper.head.copy(); target=Vector(target)
    l1=restvec[a].length; l2=restvec[b].length
    line=target-hip; distance=line.length
    if distance>l1+l2+1e-5: unreachable.append((clip,frame,leg,distance-l1-l2))
    d=max(.001,min(distance,l1+l2-1e-6)); direction=line.normalized()
    along=(l1*l1-l2*l2+d*d)/(2*d); height=math.sqrt(max(0,l1*l1-along*along))
    pole=(POLE[leg]-direction*POLE[leg].dot(direction)).normalized()
    knee=hip+direction*along+pole*height
    q=restvec[a].rotation_difference(knee-hip)@restq[a]
    upper.matrix=Matrix.Translation(hip)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    q=restvec[b].rotation_difference(target-knee)@restq[b]
    lower.matrix=Matrix.Translation(knee)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    # The planted end keeps its rest orientation (optionally swung, e.g. a wing fan
    # folding/flaring about the knuckle), so feet and knuckles never tilt into the ground.
    end.matrix=Matrix.Translation(target)@(Euler(end_rot,'XYZ').to_quaternion()@restq[c]).to_matrix().to_4x4()
    bpy.context.view_layer.update(); targets[(clip,frame,leg)]=tuple(target)
def bake(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=pb.name)
        pb.keyframe_insert(data_path='location',frame=frame,group=pb.name)
def tail_wave(p,amp=1.0,lift=0.0):
    for i in range(5):
        rotate('tail_%02d'%(i+1),(lift*(i<2),0,amp*(.04+.03*i)*math.sin(p-.8*i)))   # +X raises a backward tail
def fan(side,amount):
    # Wing fan flare about the knuckle: swings the fingers outwards and back.
    k=1 if side=='l' else -1
    return (0,0,-k*amount)
rig.animation_data_create(); clips={}
def action(name,end,loop,nla,description):
    a=bpy.data.actions.new(name); a.use_fake_user=True; rig.animation_data.action=a
    clips[name]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':nla,'description':description}
    return a
END={leg:resthead[c] for leg,(a,b,c) in LIMBS.items()}

# IDLE: low prowl at rest - breathing, head swaying low, a snarl (jaw), wing fans
# flexing, tail swish. All four supports planted.
action('Wyvern_Idle',49,True,1,'Low rest: breathing, head sway, snarl, wing fans flexing, tail swish; supports planted.')
for f in range(1,50):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/48; wave=math.sin(p); breath=(1-math.cos(p))/2
    offset((0,0,-.012*breath))
    rotate('chest',(.02*breath,0,.015*wave))
    rotate('neck_01',(.03*breath,0,.05*wave)); rotate('neck_02',(-.02*breath,0,.04*math.sin(p+.5)))
    rotate('neck_03',(0,0,.03*math.sin(p+1))); rotate('head',(.04*math.sin(2*p),0,.04*math.sin(p+1.3)))
    snarl=max(0,math.sin(2*p))**3
    rotate('jaw',(-.05+.05*snarl,0,0))       # the mouth is open at rest; teeth meet after ~0.09 rad of closing
    tail_wave(p,.9,.03)
    for leg in LIMBS:
        rot=fan(leg[-1],.05*breath) if leg.startswith('wing') else (0,0,0)
        plant(leg,END[leg],'Wyvern_Idle',f,rot)
    bake(f)

# WALK: low quadruped prowl in place on hind feet and wing knuckles, lateral sequence
# (hind L, wing L, hind R, wing R), 62% stance; neck counter-sways, tail waves.
action('Wyvern_Walk',29,True,61,'Low prowl in place on feet and wing knuckles; lateral sequence, 62% stance, tail wave.')
STANCE=.62
GAIT={'hind_l':(0,.16,.10),'wing_l':(.25,.13,.10),'hind_r':(.5,.16,.10),'wing_r':(.75,.13,.10)}
WING_BACK=Vector((0,.10,0))       # knuckles work slightly behind rest: arm reach stays in range
def footpath(t,half,lift):
    t%=1
    if t<STANCE: return -half+2*half*t/STANCE,0
    a=(t-STANCE)/(1-STANCE); ease=a*a*(3-2*a)
    return half-2*half*ease,lift*math.sin(math.pi*a)**1.2
for f in range(1,30):
    scene.frame_set(f); reset(); t=(f-1)/28; p=math.tau*t
    offset((.02*math.sin(p),0,-.02-.012*math.cos(2*p)))
    rotate('hips',(0,.02*math.sin(p),.04*math.sin(p))); rotate('chest',(0,-.02*math.sin(p),-.05*math.sin(p)))
    rotate('neck_01',(.02,0,.05*math.sin(p))); rotate('neck_02',(0,0,-.03*math.sin(p))); rotate('head',(.02*math.cos(2*p),0,-.03*math.sin(p)))
    rotate('jaw',(-.04,0,0))
    tail_wave(p,1.3,.03)
    for leg,(phase,half,lift) in GAIT.items():
        dy,h=footpath(t+phase,half,lift); base=END[leg]+(WING_BACK if leg.startswith('wing') else Vector((0,0,.006)))   # 6 mm: shin end-cap corner clears the ground
        rot=fan(leg[-1],.04*h/lift) if leg.startswith('wing') else (0,0,0)
        plant(leg,base+Vector((0,dy,h)),'Wyvern_Walk',f,rot)
    bake(f)
clips['Wyvern_Walk']['suggested_translation_mps']=2*.16/(STANCE*28/24)

# ATTACK: neck coils back in an S with the wings flared in threat (1-10), lunges
# forward and down with the jaws wide (10-13), SNAPS shut at IMPACT 14, recovers (33).
action('Wyvern_Attack',33,False,101,'Coil and wing flare 1-10, lunge 10-13, jaws snap at impact 14, recovery to 33.')
# body_y, body_z, chest_pitch, n1, n2, n3, head, jaw, flare, tail_lift
# The jaw snaps from wide open (+0.26) to just short of the teeth meeting (-0.08).
poses={1:(0,0,0,0,0,0,0,-.05,0,0),
       10:(.04,-.02,-.06,-.30,-.20,.25,-.15,.18,.22,.18),
       13:(-.12,-.01,.02,.10,-.10,-.08,.04,.26,.12,.06),      # strike stays at head height:
       14:(-.14,-.01,.03,.12,-.10,-.08,.06,-.08,.10,.06),      # the neck reaches forward, it
       18:(-.12,-.01,.02,.10,-.08,-.06,.05,-.07,.06,.04),      # does not dive; tail kept up
       33:(0,0,0,0,0,0,0,-.05,0,0)}
for f in range(1,34):
    scene.frame_set(f); reset(); lo=max(k for k in poses if k<=f); hi=min(k for k in poses if k>=f)
    t=0 if lo==hi else (f-lo)/(hi-lo); t=t*t*(3-2*t); v=[a+(b-a)*t for a,b in zip(poses[lo],poses[hi])]
    offset((0,v[0],v[1])); rotate('chest',(v[2],0,0))
    rotate('neck_01',(v[3],0,0)); rotate('neck_02',(v[4],0,0)); rotate('neck_03',(v[5],0,0)); rotate('head',(v[6],0,0)); rotate('jaw',(v[7],0,0))
    tail_wave(math.tau*(f-1)/32,1.5,v[9])
    for leg in LIMBS:
        rot=fan(leg[-1],v[8]) if leg.startswith('wing') else (0,0,0)
        lift=Vector() if leg.startswith('wing') else Vector((0,0,.006))   # shin end-cap corner clears the ground
        plant(leg,END[leg]+lift,'Wyvern_Attack',f,rot)
    bake(f)
clips['Wyvern_Attack']['impact_frame']=14
assert not unreachable,unreachable

for data in clips.values():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    marks=[('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else \
          [('START',1),('COIL',10),('IMPACT',14),('RECOVERED',33)]
    for label,frame in marks: a.pose_markers.new(label).frame=frame
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['nla_start'],data['action']); strip.extrapolation='NOTHING'
    strip.action_frame_start=1; strip.action_frame_end=data['end']; strip.blend_type='REPLACE'
    scene.timeline_markers.new(name,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=133; scene.frame_set(1)
rig['notes']='Rigid block skinning; stretch-weighted wing-to-body membranes; baked analytic planting of feet and wing knuckles; no runtime IK.'
rig['walk_in_place_speed_mps']=clips['Wyvern_Walk']['suggested_translation_mps']
scene['animations_requested']=True
bpy.app.driver_namespace['wyvern_animation']={'name':NAME,'scene':scene,'rig':rig,'root':root,'meshes':parts,
 'out':str(OUT),'clips':clips,'targets':targets,'legs':LIMBS}
result={'bones':len(specs),'meshes':len(parts),'stretch_membranes':weighted,'unreachable_targets':len(unreachable),
        'poles':{k:[round(x,2) for x in v] for k,v in POLE.items()},
        'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
