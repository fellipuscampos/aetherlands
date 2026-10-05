"""Rig the user-approved static Skeleton Warrior and bake Idle/Walk/Attack via Blender MCP.
Same method as the Minotaur: rigid block skinning (each part follows the single
bone stored in obj['rig_bone']), FK delivery rig, feet planted with an analytic
two-bone solve baked into the bones. Refuses to replace an existing rig.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Skeleton_Warrior_V1'; S=1.85/2.0175
OUT=ROOT/'assets/generated/skeletons/skeleton_warrior_v1'
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
assert NAME+'_Rig' not in bpy.data.objects, 'Existing rig: preserve manual animation edits.'
root=bpy.data.objects[NAME+'_ROOT']
parts=[o for o in scene.objects if o.type=='MESH' and not o.name.endswith('StudioGround')]
for o in parts:
    if o.matrix_basis!=Matrix.Identity(4):
        o.data.transform(o.matrix_basis); o.matrix_basis=Matrix.Identity(4)

GRIP=Vector((-.305,-.115,.87)); AXIS=Vector((0,-.45,-.89)).normalized()
specs={}
def bone(n,h,t,p=None): specs[n]=(Vector(h)*S,Vector(t)*S,p)
bone('root',(0,0,0),(0,0,.25))
bone('pelvis',(0,.02,.95),(0,.03,1.08),'root')
bone('spine',(0,.04,1.01),(0,.035,1.27),'pelvis')
bone('chest',(0,.035,1.27),(0,0,1.56),'spine')
bone('head',(0,-.02,1.58),(0,-.05,1.95),'chest')
bone('jaw',(0,-.01,1.63),(0,-.21,1.62),'head')
bone('tabard_front',(0,-.095,1.0),(0,-.19,.64),'pelvis')
bone('tabard_back',(0,.11,1.0),(0,.17,.72),'pelvis')
for side,k in [('l',1),('r',-1)]:
    bone('shoulder_'+side,(k*.06,-.03,1.56),(k*.25,-.025,1.53),'chest')
    bone('upper_arm_'+side,(k*.25,-.025,1.53),(k*.28,-.045,1.21),'shoulder_'+side)
    bone('forearm_'+side,(k*.28,-.045,1.21),(k*.30,-.10,.93),'upper_arm_'+side)
    bone('hand_'+side,(k*.30,-.10,.93),(k*.305,-.12,.80),'forearm_'+side)
    bone('thigh_'+side,(k*.11,.02,.95),(k*.125,-.03,.51),'pelvis')
    bone('shin_'+side,(k*.125,-.03,.51),(k*.125,0,.08),'thigh_'+side)
    bone('foot_'+side,(k*.125,0,.08),(k*.125,-.20,.08),'shin_'+side)
bone('weapon',GRIP,GRIP+AXIS*.30,'hand_r')

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
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def rotate(n,xyz):
    # Character axes (X right, -Y forward, Z up): +X tips a hanging limb back /
    # a torso forward; -X raises an arm forward. Converted to the bone rest frame.
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

# The sword arm carries the blade with a half-bent elbow in every clip's base
# pose (Idle, Walk, start/end of Attack), so crossfades stay clean.
CARRY=.30

# IDLE: undead sway, slow head tilt, two quick jaw chatters, dangling arms.
action('Skeleton_Idle',49,True,1,'Undead sway, head tilt, jaw chatter twice, dangling arms, sword carried; feet planted.')
for f in range(1,50):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/48; wave=math.sin(p); breath=(1-math.cos(p))/2
    offset((.006*wave,0,-.006*breath))
    rotate('spine',(.03+.010*wave,0,.015*wave)); rotate('chest',(.02-.012*breath,0,-.012*wave))
    # No head yaw/roll in any clip: the square skull's corners would sweep into the
    # left pauldron, which sits right beside it. Nods only.
    rotate('head',(-.03+.03*math.sin(p*2),0,0))
    chatter=max(0,math.sin(p*4))**3 if math.sin(p)>0 else 0
    rotate('jaw',(.04+.16*chatter,0,0))
    for side,k in [('l',1),('r',-1)]:
        rotate('shoulder_'+side,(0,-k*.025*breath,0))
        rotate('upper_arm_'+side,(.03*math.sin(p-.6+k*.8)-.03*math.sin(-.6+k*.8),-k*.03,0))
        rotate('forearm_'+side,(-.06-.03*breath-(CARRY if side=='r' else 0),0,0))
    rotate('hand_r',(.03*math.sin(p-.8)-.03*math.sin(-.8),0,0))
    rotate('tabard_front',(-.03*breath,0,.02*wave)); rotate('tabard_back',(.025*breath,0,-.02*wave))
    for side in ('l','r'): plant(side,resthead['foot_'+side],'Skeleton_Idle',f)
    bake(f)

# WALK: stiff, slightly hunched shamble in place; 60% stance, bobbing skull.
action('Skeleton_Walk',29,True,61,'28-frame stiff undead walk in place; 60% stance, head bob, opposite arm swing, sword carried.')
HALF=.13; LIFT=.07; STANCE=.60
def footpath(t):
    t%=1
    if t<STANCE: return -HALF+2*HALF*t/STANCE,0,True
    a=(t-STANCE)/(1-STANCE); ease=a*a*(3-2*a)
    return HALF-2*HALF*ease,LIFT*math.sin(math.pi*a)**1.2,False
for f in range(1,30):
    scene.frame_set(f); reset(); t=(f-1)/28; p=math.tau*t
    offset((.016*math.sin(p),0,-.030-.010*math.cos(2*p)))
    rotate('pelvis',(0,0,.04*math.sin(p)))
    rotate('spine',(.06,0,-.03*math.sin(p))); rotate('chest',(.04,0,.06*math.sin(p)))
    rotate('head',(-.06+.05*math.cos(2*p),0,0))
    rotate('jaw',(.05+.05*max(0,math.cos(2*p)),0,0))
    rotate('upper_arm_l',(.30*math.cos(p),-.05,0)); rotate('upper_arm_r',(-.18*math.cos(p),.04,0))
    rotate('forearm_l',(-.18-.06*math.sin(p),0,0)); rotate('forearm_r',(-CARRY-.12+.04*math.sin(p),0,0))   # higher carry: tip clears the ground
    rotate('hand_r',(.05*math.sin(p-.4),0,0))
    rotate('tabard_front',(-.08-.12*abs(math.cos(p)),0,0)); rotate('tabard_back',(.06+.08*abs(math.cos(p)),0,0))
    for side,phase in [('l',0),('r',.5)]:
        dy,lift,stance=footpath(t+phase); plant(side,resthead['foot_'+side]+Vector((0,dy*S,lift*S)),'Skeleton_Walk',f)
        contact[(f,side)]=stance
    bake(f)
clips['Skeleton_Walk']['suggested_translation_mps']=2*HALF*S/(STANCE*28/24)

# ATTACK: one-handed overhead sword chop. Wind-up 1-9 (sword raised past the
# head, chest twisted back, jaw dropped), fast swing, IMPACT 13, follow-through
# 16, recovery to 29. Blade width lies in the swing plane: the edge leads.
action('Skeleton_Attack',29,False,101,'Overhead sword chop: wind-up 1-9, impact 13, follow-through 16, recovery 29.')
# ua_x, ua_y, fa_x, hand_x, chest_x, chest_z, spine_x, pelvis_y, pelvis_z, jaw, head_x
poses={1:(0,0,-CARRY,0, 0,0,0, 0,0, .04,0),
       7:(-2.20,-.24,-.95,.20, -.12,-.24,-.05, .015,-.012, .14,-.10),
       9:(-2.35,-.28,-1.05,.25, -.14,-.27,-.06, .020,-.015, .16,-.12),
       12:(-1.40,-.05,-.35,-.05, .18,.10,.08, -.020,-.035, .10,.02),
       13:(-1.00,.08,-.10,-.15, .26,.17,.12, -.030,-.045, .08,.06),
       16:(-.85,.06,-.10,-.02, .27,.18,.12, -.032,-.048, .06,.06),
       22:(-.30,.03,-.30,.10, .10,.06,.04, -.012,-.020, .04,.02),
       29:(0,0,-CARRY,0, 0,0,0, 0,0, .04,0)}
for f in range(1,30):
    scene.frame_set(f); reset(); lo=max(k for k in poses if k<=f); hi=min(k for k in poses if k>=f)
    t=0 if lo==hi else (f-lo)/(hi-lo); t=t*t*(3-2*t); v=[a+(b-a)*t for a,b in zip(poses[lo],poses[hi])]
    intensity=math.sin(math.pi*(f-1)/28)
    offset((.008*intensity,v[7],v[8])); rotate('spine',(v[6],0,v[5]*.4)); rotate('chest',(v[4],0,v[5]))
    rotate('head',(v[10]-.5*v[4],0,0)); rotate('jaw',(v[9],0,0))
    rotate('upper_arm_r',(v[0],v[1],0)); rotate('forearm_r',(v[2],0,0)); rotate('hand_r',(v[3],0,0))
    rotate('shoulder_r',(0,.08*intensity,0))
    rotate('upper_arm_l',(-.30*intensity,-.16*intensity,0)); rotate('forearm_l',(-.40*intensity,0,0))
    rotate('tabard_front',(-.08*intensity,0,0)); rotate('tabard_back',(.06*intensity,0,0))
    for side in ('l','r'): plant(side,resthead['foot_'+side],'Skeleton_Attack',f)
    bake(f)
clips['Skeleton_Attack']['impact_frame']=13
assert not unreachable,unreachable

for data in clips.values():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    marks=[('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else \
          [('START',1),('WINDUP',9),('IMPACT',13),('FOLLOW_THROUGH',16),('RECOVERED',29)]
    for label,frame in marks: a.pose_markers.new(label).frame=frame
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['nla_start'],data['action']); strip.extrapolation='NOTHING'
    strip.action_frame_start=1; strip.action_frame_end=data['end']; strip.blend_type='REPLACE'
    scene.timeline_markers.new(name,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=129; scene.frame_set(1)
rig['notes']='Editable separate block meshes; rigid skinning; baked analytic foot planting; no runtime IK.'
rig['walk_in_place_speed_mps']=clips['Skeleton_Walk']['suggested_translation_mps']
scene['animations_requested']=True
bpy.app.driver_namespace['skeleton_animation']={'name':NAME,'scene':scene,'rig':rig,'root':root,'meshes':parts,
 'out':str(OUT),'clips':clips,'targets':targets,'contact':contact}
result={'bones':len(specs),'meshes':len(parts),'unreachable_targets':len(unreachable),
        'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
