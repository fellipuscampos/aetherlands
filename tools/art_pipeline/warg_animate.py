"""Rig the approved static Warg (quadruped) and bake Idle/Walk/Attack via Blender MCP.
Same method as the humanoids: rigid block skinning (each part follows the single
bone stored in obj['rig_bone']), FK delivery rig, and all four legs planted with
an analytic two-bone solve baked into the bones. Each leg bends towards the same
side as in the approved rest pose (pole taken from the rest geometry).
Refuses to replace an existing rig.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Warg_V1'; OUT=ROOT/'assets/generated/wargs/warg_v1'
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
bone('hips',(0,.40,.72),(0,.0,.70),'root')
bone('chest',(0,.0,.70),(0,-.45,.70),'hips')
bone('neck',(0,-.45,.74),(0,-.78,.78),'chest')
bone('head',(0,-.78,.78),(0,-1.20,.78),'neck')
bone('jaw',(0,-1.06,.62),(0,-1.34,.57),'head')
bone('tail_01',(0,.54,.82),(0,.85,.88),'hips')
bone('tail_02',(0,.85,.88),(0,1.16,.86),'tail_01')
LEGS={}
for side,k in [('l',1),('r',-1)]:
    bone('front_upper_'+side,(k*.25,-.36,.56),(k*.31,-.68,.30),'chest')
    bone('front_lower_'+side,(k*.31,-.68,.30),(k*.34,-.86,.07),'front_upper_'+side)
    bone('front_paw_'+side,(k*.34,-.86,.07),(k*.34,-1.08,.05),'front_lower_'+side)
    bone('hind_thigh_'+side,(k*.22,.38,.72),(k*.26,.14,.36),'hips')
    bone('hind_lower_'+side,(k*.26,.14,.36),(k*.27,.46,.10),'hind_thigh_'+side)
    bone('hind_paw_'+side,(k*.27,.46,.10),(k*.27,.26,.06),'hind_lower_'+side)
    LEGS['front_'+side]=('front_upper_'+side,'front_lower_'+side,'front_paw_'+side)
    LEGS['hind_'+side]=('hind_thigh_'+side,'hind_lower_'+side,'hind_paw_'+side)

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
# Rest-pose bend direction of every leg (unit vector from the hip->paw line to the joint).
POLE={}
for leg,(a,b,c) in LEGS.items():
    hip,knee,ankle=resthead[a],resthead[b],resthead[c]; d=(ankle-hip).normalized()
    POLE[leg]=((knee-hip)-d*(knee-hip).dot(d)).normalized()
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def rotate(n,xyz):
    # Character axes (X right, -Y forward, Z up), converted to the bone rest frame.
    # +X pitches a forward-pointing (-Y) bone's tip DOWN; +Z swings a forward tip towards +X.
    rig.pose.bones[n].rotation_quaternion=restq[n].inverted()@Euler(xyz,'XYZ').to_quaternion()@restq[n]
def offset(v): rig.pose.bones['hips'].location=restq['hips'].inverted()@Vector(v)
targets={}; unreachable=[]
def plant(leg,target,clip,frame):
    a,b,c=LEGS[leg]; upper=rig.pose.bones[a]; lower=rig.pose.bones[b]; paw=rig.pose.bones[c]
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
    paw.matrix=Matrix.Translation(target)@restq[c].to_matrix().to_4x4()   # paws stay flat
    bpy.context.view_layer.update(); targets[(clip,frame,leg)]=tuple(target)
def bake(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=pb.name)
        pb.keyframe_insert(data_path='location',frame=frame,group=pb.name)
rig.animation_data_create(); clips={}
def action(name,end,loop,nla,description):
    a=bpy.data.actions.new(name); a.use_fake_user=True; rig.animation_data.action=a
    clips[name]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':nla,'description':description}
    return a
PAW={leg:resthead[c] for leg,(a,b,c) in LEGS.items()}

# IDLE: stalking in the approved crouch. Breathing through chest, low growl
# (jaw twitches), head weaving slightly, tail swaying. All paws planted.
action('Warg_Idle',49,True,1,'Stalking crouch: breathing, low growl jaw twitch, head weave, tail sway; paws planted.')
for f in range(1,50):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/48; wave=math.sin(p); breath=(1-math.cos(p))/2
    offset((0,0,-.010*breath))
    rotate('chest',(.02*breath,0,.012*wave))      # breathing lowers the chest: front legs stay in reach
    rotate('neck',(.03*breath,0,-.02*wave)); rotate('head',(-.02*breath+.02*math.sin(2*p),0,.04*math.sin(p)))
    growl=max(0,math.sin(3*p))**4
    rotate('jaw',(.04+.10*growl,0,0))
    rotate('tail_01',(-.05*breath,0,.12*math.sin(p))); rotate('tail_02',(0,0,.16*math.sin(p-.7)))
    for leg in LEGS: plant(leg,PAW[leg],'Warg_Idle',f)
    bake(f)

# WALK: low predatory prowl in place, lateral-sequence quadruped gait
# (LH, LF, RH, RF a quarter cycle apart), 65% stance. Front paws work slightly
# behind their outstretched rest position so the stride stays within reach.
action('Warg_Walk',29,True,61,'Low prowl in place: lateral-sequence gait (LH, LF, RH, RF), 65% stance, head low and steady.')
HALF=.12; LIFT=.07; STANCE=.65
FRONT_BACK=Vector((0,.15,0))
PHASE={'hind_l':0,'front_l':.25,'hind_r':.5,'front_r':.75}
def footpath(t):
    t%=1
    if t<STANCE: return -HALF+2*HALF*t/STANCE,0
    a=(t-STANCE)/(1-STANCE); ease=a*a*(3-2*a)
    return HALF-2*HALF*ease,LIFT*math.sin(math.pi*a)**1.2
for f in range(1,30):
    scene.frame_set(f); reset(); t=(f-1)/28; p=math.tau*t
    offset((.012*math.sin(p),0,-.025-.010*math.cos(4*p)))
    rotate('hips',(0,.03*math.sin(p),.04*math.sin(p)))
    rotate('chest',(0,-.03*math.sin(p+math.pi/2),-.05*math.sin(p+math.pi/2)))
    rotate('neck',(.05,0,.03*math.sin(p))); rotate('head',(-.04+.02*math.cos(4*p),0,-.03*math.sin(p)))
    rotate('jaw',(.06,0,0))
    rotate('tail_01',(.03,0,.14*math.sin(p))); rotate('tail_02',(0,0,.18*math.sin(p-.8)))
    for leg in LEGS:
        dy,lift=footpath(t+PHASE[leg]); base=PAW[leg]+(FRONT_BACK if leg.startswith('front') else Vector())
        plant(leg,base+Vector((0,dy,lift)),'Warg_Walk',f)
    bake(f)
clips['Warg_Walk']['suggested_translation_mps']=2*HALF/(STANCE*28/24)

# ATTACK: pounce-bite. Coil back and down (1-10), spring forward with the jaw
# wide open (10-14), SNAP shut at IMPACT 15, hold, recover to the crouch (33).
action('Warg_Attack',33,False,101,'Pounce-bite: coil 1-10, spring 10-14, jaw snaps at impact 15, recovery to 33.')
# body_y, body_z, chest_pitch, neck_pitch, head_pitch, jaw, tail_pitch, front_lift
# The rest front legs are almost straight, so the coil LOWERS and tips the chest
# down (shoulders get closer to the paws) instead of pulling the body back.
poses={1:(0,0,0,0,0,.04,0,0),
       10:(.03,-.08,.10,.0,-.08,.18,-.25,0),   # head stays level on the prey: cheeks clear the front legs
       13:(-.24,.06,-.12,-.18,-.10,.62,.20,.08),
       15:(-.30,.02,-.04,-.08,.06,.02,.15,.03),
       19:(-.28,-.01,0,-.02,.08,.04,.05,0),
       33:(0,0,0,0,0,.04,0,0)}
for f in range(1,34):
    scene.frame_set(f); reset(); lo=max(k for k in poses if k<=f); hi=min(k for k in poses if k>=f)
    t=0 if lo==hi else (f-lo)/(hi-lo); t=t*t*(3-2*t); v=[a+(b-a)*t for a,b in zip(poses[lo],poses[hi])]
    offset((0,v[0],v[1]))
    rotate('chest',(v[2],0,0)); rotate('neck',(v[3],0,0)); rotate('head',(v[4],0,0)); rotate('jaw',(v[5],0,0))
    rotate('tail_01',(v[6],0,0)); rotate('tail_02',(v[6]*.6,0,0))
    for leg in LEGS:
        target=PAW[leg].copy()
        if leg.startswith('front'): target+=Vector((0,min(v[0],0)*.55,v[7]))   # reach only forward; never slide back on the coil
        plant(leg,target,'Warg_Attack',f)
    bake(f)
clips['Warg_Attack']['impact_frame']=15
assert not unreachable,unreachable

for data in clips.values():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    marks=[('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else \
          [('START',1),('COIL',10),('IMPACT',15),('RECOVERED',33)]
    for label,frame in marks: a.pose_markers.new(label).frame=frame
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['nla_start'],data['action']); strip.extrapolation='NOTHING'
    strip.action_frame_start=1; strip.action_frame_end=data['end']; strip.blend_type='REPLACE'
    scene.timeline_markers.new(name,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=133; scene.frame_set(1)
rig['notes']='Editable separate block meshes; rigid skinning; baked analytic paw planting on four legs; no runtime IK.'
rig['walk_in_place_speed_mps']=clips['Warg_Walk']['suggested_translation_mps']
scene['animations_requested']=True
bpy.app.driver_namespace['warg_animation']={'name':NAME,'scene':scene,'rig':rig,'root':root,'meshes':parts,
 'out':str(OUT),'clips':clips,'targets':targets,'legs':LEGS}
result={'bones':len(specs),'meshes':len(parts),'unreachable_targets':len(unreachable),'poles':{k:[round(x,2) for x in v] for k,v in POLE.items()},
        'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
