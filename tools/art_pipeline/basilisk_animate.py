"""Rig the approved static Basilisk and bake Idle/Walk/Attack via Blender MCP.
Same method as the other models: rigid block skinning (each part follows the single
bone stored in obj['rig_bone']), FK delivery rig, both feet planted with an analytic
two-bone solve (thigh + tarsus) baked into the bones, bending like the rest pose.
Refuses to replace an existing rig.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Basilisk_Blocky_V1'; OUT=ROOT/'assets/generated/basilisks/basilisk_blocky_v1'
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
assert NAME+'_Rig' not in bpy.data.objects, 'Existing rig: preserve manual animation edits.'
root=bpy.data.objects[NAME+'_ROOT']
parts=[o for o in scene.objects if o.type=='MESH' and not o.name.endswith('StudioGround')]
for o in parts:
    if o.matrix_basis!=Matrix.Identity(4):
        o.data.transform(o.matrix_basis); o.matrix_basis=Matrix.Identity(4)

specs={}
def bone(n,h,t,p=None): specs[n]=(Vector(h),Vector(t),p)
bone('root',(0,0,0),(0,0,.25))
bone('body',(0,.15,1.0),(0,-.35,1.12),'root')
bone('neck_01',(0,-.40,1.24),(0,-.54,1.56),'body')
bone('neck_02',(0,-.54,1.56),(0,-.52,1.84),'neck_01')
bone('head',(0,-.52,1.84),(0,-.80,1.92),'neck_02')
bone('jaw',(0,-.66,1.83),(0,-.86,1.66),'head')
TAIL=[((0,.28,1.02),(0,.66,.86)),((0,.62,.88),(0,.94,.58)),((0,.90,.60),(.10,1.25,.30)),((.08,1.22,.32),(.30,1.55,.12)),
      ((.28,1.52,.12),(.10,1.88,.08)),((.12,1.85,.08),(-.20,2.12,.10))]
for i,(h,t) in enumerate(TAIL):
    bone('tail_%02d'%(i+1),h,t,'body' if i==0 else 'tail_%02d'%i)
LEGS={}
for side,k in [('l',1),('r',-1)]:
    dy=-.06*k
    bone('wing_'+side,(k*.33,-.25,1.25),(k*.36,.40,.95),'body')
    bone('thigh_'+side,(k*.225,.03,.98),(k*.23,.20,.66),'body')
    bone('tarsus_'+side,(k*.23,.20,.66),(k*.25,.02+dy,.07),'thigh_'+side)
    bone('foot_'+side,(k*.25,.02+dy,.07),(k*.25,-.20+dy,.05),'tarsus_'+side)
    LEGS[side]=('thigh_'+side,'tarsus_'+side,'foot_'+side)

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
for o in parts:
    n=o['rig_bone']; assert n in specs,(o.name,n)
    o.vertex_groups.clear()
    o.vertex_groups.new(name=n).add(list(range(len(o.data.vertices))),1,'REPLACE'); o['bone']=n
    for m in [m for m in o.modifiers if m.type=='ARMATURE']: o.modifiers.remove(m)
    mod=o.modifiers.new('Block_preserving_skin','ARMATURE'); mod.object=rig
    o.parent=rig

rest={b.name:b.matrix_local.copy() for b in arm.bones}
restq={n:m.to_quaternion() for n,m in rest.items()}
resthead={b.name:b.head_local.copy() for b in arm.bones}
restvec={b.name:b.tail_local-b.head_local for b in arm.bones}
POLE={}
for leg,(a,b,c) in LEGS.items():
    hip,knee,ankle=resthead[a],resthead[b],resthead[c]; d=(ankle-hip).normalized()
    POLE[leg]=((knee-hip)-d*(knee-hip).dot(d)).normalized()
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def rotate(n,xyz):
    # Character axes (X right, -Y forward, Z up): +X leans an upward bone forward and
    # pitches a forward bone's tip down; +Z swings a forward tip towards +X.
    rig.pose.bones[n].rotation_quaternion=restq[n].inverted()@Euler(xyz,'XYZ').to_quaternion()@restq[n]
def offset(v): rig.pose.bones['body'].location=restq['body'].inverted()@Vector(v)
targets={}; unreachable=[]
def plant(leg,target,clip,frame):
    a,b,c=LEGS[leg]; upper=rig.pose.bones[a]; lower=rig.pose.bones[b]; foot=rig.pose.bones[c]
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
    foot.matrix=Matrix.Translation(target)@restq[c].to_matrix().to_4x4()   # toes stay flat
    bpy.context.view_layer.update(); targets[(clip,frame,leg)]=tuple(target)
def bake(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=pb.name)
        pb.keyframe_insert(data_path='location',frame=frame,group=pb.name)
def tail_wave(p,amp=1.0,lift=0.0):
    # A sideways serpent wave travelling from the rump to the tip.
    for i in range(6):
        rotate('tail_%02d'%(i+1),(lift*(i<2),0,amp*(.03+.025*i)*math.sin(p-.75*i)))
rig.animation_data_create(); clips={}
def action(name,end,loop,nla,description):
    a=bpy.data.actions.new(name); a.use_fake_user=True; rig.animation_data.action=a
    clips[name]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':nla,'description':description}
    return a
FOOT={leg:resthead[c] for leg,(a,b,c) in LEGS.items()}

# IDLE: cobra-like neck sway, jerky bird head tilts, tongue flicks, tail-tip swish,
# a wing ruffle, breathing. Feet planted.
action('Basilisk_Idle',49,True,1,'Serpent neck sway, bird head tilts, tongue flicks, tail swish, wing ruffle; feet planted.')
for f in range(1,50):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/48; wave=math.sin(p); breath=(1-math.cos(p))/2
    offset((0,0,-.012*breath))
    rotate('body',(-.02*breath,0,.015*wave))
    rotate('neck_01',(.04*math.sin(p),0,.06*math.sin(p)))
    rotate('neck_02',(-.04*math.sin(p),0,.03*math.sin(p+.6)))      # small yaw relative to the neck base: clears the hackle collar
    tilt=round(math.sin(2*p)*2)/2                                 # stepped, bird-like head tilts
    rotate('head',(.05*math.sin(p+1),.10*tilt,.06*math.sin(p+1.2)))
    flick=max(0,math.sin(4*p))**6
    rotate('jaw',(-.10*flick,0,0))                                 # mouth closes a little between tongue flicks
    rotate('wing_l',(0,-.03*breath,-.02*breath)); rotate('wing_r',(0,.03*breath,.02*breath))
    tail_wave(p,.8,.05)                                            # slight lift: the tail tip lies close to the ground
    for leg in LEGS: plant(leg,FOOT[leg],'Basilisk_Idle',f)
    bake(f)

# WALK: rooster strut in place (head held back then thrust forward on every step),
# serpent wave down the tail, 60% stance.
action('Basilisk_Walk',29,True,61,'Rooster strut in place: head thrust on every step, serpent wave along the tail, 60% stance.')
HALF=.17; LIFT=.12; STANCE=.60
def footpath(t):
    t%=1
    if t<STANCE: return -HALF+2*HALF*t/STANCE,0
    a=(t-STANCE)/(1-STANCE); ease=a*a*(3-2*a)
    return HALF-2*HALF*ease,LIFT*math.sin(math.pi*a)**1.2
for f in range(1,30):
    scene.frame_set(f); reset(); t=(f-1)/28; p=math.tau*t
    offset((.02*math.sin(p),0,-.03-.015*math.cos(2*p)))
    rotate('body',(.03,0,.04*math.sin(p)))
    s=(2*t)%1; thrust=(s/.7) if s<.7 else 1-(s-.7)/.3            # slow pull back, fast thrust
    rotate('neck_01',(.10-.16*thrust,0,-.04*math.sin(p)))
    rotate('neck_02',(-.06+.12*thrust,0,.03*math.sin(p)))
    rotate('head',(.04,0,.03*math.sin(p)))
    rotate('jaw',(-.06,0,0))
    rotate('wing_l',(0,-.04*abs(math.sin(p)),0)); rotate('wing_r',(0,.04*abs(math.sin(p)),0))
    tail_wave(p,1.3)
    for leg,phase in [('l',0),('r',.5)]:
        dy,lift=footpath(t+phase); plant(leg,FOOT[leg]+Vector((0,dy,lift)),'Basilisk_Walk',f)
    bake(f)
clips['Basilisk_Walk']['suggested_translation_mps']=2*HALF/(STANCE*28/24)

# ATTACK: cobra strike. Neck coils back into an S with wings flared (1-10), strikes
# forward and down with the mouth wide (10-13), BITES at IMPACT 14, recovers (33).
action('Basilisk_Attack',33,False,101,'Cobra strike: coil and wing flare 1-10, strike 10-13, bite at impact 14, recovery to 33.')
# body_y, body_z, body_pitch, neck1, neck2, head, jaw, wing_flare, tail_lift
poses={1:(0,0,0,0,0,0,0,0,0),
       10:(.08,-.04,-.10,-.38,.30,-.20,.30,.45,.18),
       13:(-.10,-.06,.18,.42,.18,.30,.55,.30,-.05),
       14:(-.12,-.065,.20,.46,.20,.34,-.08,.25,-.06),
       18:(-.10,-.05,.16,.38,.16,.28,-.05,.15,0),
       33:(0,0,0,0,0,0,0,0,0)}
for f in range(1,34):
    scene.frame_set(f); reset(); lo=max(k for k in poses if k<=f); hi=min(k for k in poses if k>=f)
    t=0 if lo==hi else (f-lo)/(hi-lo); t=t*t*(3-2*t); v=[a+(b-a)*t for a,b in zip(poses[lo],poses[hi])]
    offset((0,v[0],v[1])); rotate('body',(v[2],0,0))
    rotate('neck_01',(v[3],0,0)); rotate('neck_02',(v[4],0,0)); rotate('head',(v[5],0,0)); rotate('jaw',(v[6],0,0))
    rotate('wing_l',(0,-v[7],-v[7]*.6)); rotate('wing_r',(0,v[7],v[7]*.6))
    tail_wave(math.tau*(f-1)/32,1.6,v[8])
    for leg in LEGS: plant(leg,FOOT[leg],'Basilisk_Attack',f)
    bake(f)
clips['Basilisk_Attack']['impact_frame']=14
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
rig['notes']='Editable separate block meshes; rigid skinning; baked analytic foot planting; no runtime IK.'
rig['walk_in_place_speed_mps']=clips['Basilisk_Walk']['suggested_translation_mps']
scene['animations_requested']=True
bpy.app.driver_namespace['basilisk_animation']={'name':NAME,'scene':scene,'rig':rig,'root':root,'meshes':parts,
 'out':str(OUT),'clips':clips,'targets':targets,'legs':LEGS}
result={'bones':len(specs),'meshes':len(parts),'unreachable_targets':len(unreachable),'poles':{k:[round(x,2) for x in v] for k,v in POLE.items()},
        'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
