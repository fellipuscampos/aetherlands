"""Rigid-bone rig + baked Idle / Walk / Attack (shield bash) for the live Guardian Champion V1 (Campeão Guardião, legendary: same joints/clips as the line, Shield Wall inherited; 2.00 m),
via Blender MCP. Same machinery as corrupted_hero_animate.py: flat rig (every bone a child of
root, one bone per rigid group), each pose a world-space delta D written as
pose_bone.matrix = D @ rest, forward kinematics about joint pivots measured on the live meshes,
legs by analytic two-bone IK (knee forward, feet planted or sliding). Shoulder cubes ride with
the chest. A shared neutral BASE (hips 2 cm lower, knees barely bent) starts/ends every clip.
- Champion_Idle (72 f, loop): alert guard behind the shield — breathing, weight shift from leg to
  leg, head scanning left/right, shield bobbing slightly.
- Champion_Walk (28 f, loop, in place): lighter, quicker step than the hero, shield kept up in
  front, hip bob and small counter-twist.
- Champion_Attack (30 f): shield bash — pulls shield and body back, steps in with the left foot and
  shoves the shield forward with both arms (impact frame 13), recovers to the guard.
- Champion_ShieldWall (24 f): Shield Wall technique activation — widens the stance, crouches and
  RAISES the shield to face height with both arms; the shield lands with a small impact jolt
  (frame 12) and he ends braced, peeking over the rim. Its last frame IS the first frame of:
- Champion_ShieldWallHold (48 f, loop): the braced shield-wall posture held while the defence buff
  lasts — tense breathing, tiny shield tremble.
REBAKE=True rebuilds an existing rig/actions.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

NAME='Guardian_Champion_V1'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
st=bpy.app.driver_namespace['guardian_champion']
root=bpy.data.objects[NAME+'_ROOT']
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\guardian_champion_v1')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
CLIPS=('Champion_Idle','Champion_Walk','Champion_Attack','Champion_ShieldWall','Champion_ShieldWallHold')
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
else:
    bpy.data.libraries.write(str(source/'guardian_champion_v1_static.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for n in CLIPS:
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
for m in list(scene.timeline_markers):
    if m.name.startswith('Champion_'): scene.timeline_markers.remove(m)

def P(n): return bpy.data.objects[NAME+'_'+n]
def verts(n): return [v.co.copy() for v in P(n).data.vertices]
def avg(vs): return sum(vs,Vector())/len(vs)
def top4(n): return avg(sorted(verts(n),key=lambda v:v.z)[-4:])
def bot4(n): return avg(sorted(verts(n),key=lambda v:v.z)[:4])
def first4(n): return avg(verts(n)[:4])
def last4(n): return avg(verts(n)[4:])

J={}
J['HIP']=avg(verts('Pelvis')); J['WAIST']=top4('Pelvis'); J['NECK']=bot4('Head')
for t in ('l','r'):
    J['SH_'+t]=first4('UpperArm_'+t)+Vector((0,0,.03)); J['EL_'+t]=last4('UpperArm_'+t); J['WR_'+t]=last4('Forearm_'+t)
    J['HJ_'+t]=top4('Thigh_'+t); J['KN_'+t]=bot4('Thigh_'+t); J['AN_'+t]=bot4('Shin_'+t)
override={'Shoulder_l':'chest','Shoulder_r':'chest'}
part_bone={o['part']:override.get(o['part'],o['rig_bone']) for o in parts}
bones={'root':(Vector((0,0,0)),Vector((0,0,.3))),'hips':(J['HIP'],J['HIP']+Vector((0,0,.2))),
       'chest':(J['WAIST'],J['NECK']),'head':(J['NECK'],J['NECK']+Vector((0,0,.3)))}
for t in ('l','r'):
    bones['upper_arm_'+t]=(J['SH_'+t],J['EL_'+t]); bones['forearm_'+t]=(J['EL_'+t],J['WR_'+t])
    bones['hand_'+t]=(J['WR_'+t],J['WR_'+t]+(J['WR_'+t]-J['EL_'+t]).normalized()*.12)
    bones['thigh_'+t]=(J['HJ_'+t],J['KN_'+t]); bones['shin_'+t]=(J['KN_'+t],J['AN_'+t])
    bones['foot_'+t]=(J['AN_'+t],J['AN_'+t]+Vector((0,-.15,0)))
assert set(part_bone.values())<=set(bones),set(part_bone.values())-set(bones)
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm)
bpy.data.collections[NAME+'_01_BODY'].objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t_) in bones.items():
    b=arm.edit_bones.new(n); b.head=h; b.tail=t_; b.roll=0
    if n!='root': b.parent=arm.edit_bones['root']; b.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT'); arm.display_type='STICK'
for o in parts:
    b=part_bone[o['part']]; o['rig_bone']=b
    o.vertex_groups.new(name=b).add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    mod=o.modifiers.new('Rigid_Champion_Parts','ARMATURE'); mod.object=rig; o.parent=rig
rig['notes']='Flat rigid rig, one bone per part group; legs by baked two-bone IK; shoulder cubes ride with the chest.'
rest={b.name:b.matrix_local.copy() for b in arm.bones}
ORDER=list(bones)

def Tm(v): return Matrix.Translation(Vector(v))
def about(p,q): return Tm(p)@q.to_matrix().to_4x4()@Tm(-Vector(p))
def qx(d): return Quaternion((1,0,0),math.radians(d))
def qy(d): return Quaternion((0,1,0),math.radians(d))
def qz(d): return Quaternion((0,0,1),math.radians(d))
L1={t:(J['KN_'+t]-J['HJ_'+t]).length for t in 'lr'}; L2={t:(J['AN_'+t]-J['KN_'+t]).length for t in 'lr'}
problems=[]; CUR=['']
def leg(t,Dh,target,foot_q):
    A=J['HJ_'+t]; K=J['KN_'+t]; C=J['AN_'+t]
    A2=Dh@A; C2=Vector(target); l1,l2=L1[t],L2[t]; d=(C2-A2).length
    if d>(l1+l2)*.9995: problems.append(('reach',CUR[0],t,round(d-(l1+l2),4))); d=(l1+l2)*.9995; C2=A2+(C2-A2).normalized()*d
    u=(C2-A2).normalized(); pole=Dh.to_3x3()@Vector((0,-1,0)); pole=(pole-u*pole.dot(u)).normalized()
    a=math.acos(max(-1,min(1,(l1*l1+d*d-l2*l2)/(2*l1*d))))
    B2=A2+u*math.cos(a)*l1+pole*math.sin(a)*l1
    R1=(K-A).normalized().rotation_difference((B2-A2).normalized()).to_matrix().to_4x4()
    R2=(C-K).normalized().rotation_difference((C2-B2).normalized()).to_matrix().to_4x4()
    return Tm(A2)@R1@Tm(-A),Tm(B2)@R2@Tm(-K),Tm(C2)@foot_q.to_matrix().to_4x4()@Tm(-C)
BASE_DROP=.02
def pose(off=(0,0,0),hips_q=Quaternion(),chest_q=Quaternion(),head_q=Quaternion(),
         arm_r=(0,0,0),arm_l=(0,0,0),feet=None,feet_q=None):
    D={'root':Matrix.Identity(4)}
    D['hips']=Tm(Vector(off)+Vector((0,0,-BASE_DROP)))@about(J['HIP'],hips_q)
    D['chest']=D['hips']@about(J['WAIST'],chest_q)
    D['head']=D['chest']@about(J['NECK'],head_q)
    for t,a in (('r',arm_r),('l',arm_l)):
        D['upper_arm_'+t]=D['chest']@about(J['SH_'+t],qx(a[0]))
        D['forearm_'+t]=D['upper_arm_'+t]@about(J['EL_'+t],qx(a[1]))
        D['hand_'+t]=D['forearm_'+t]@about(J['WR_'+t],qx(a[2]))
    for i,t in enumerate(('l','r')):
        tgt=Vector(feet[i]) if feet else J['AN_'+t]
        fq=feet_q[i] if feet_q else Quaternion()
        D['thigh_'+t],D['shin_'+t],D['foot_'+t]=leg(t,D['hips'],tgt,fq)
    return D
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
previous={}; clips={}; stats={}
PART_VERTS={o.name:(o['rig_bone'],[v.co.copy() for v in o.data.vertices]) for o in parts}
def bake(f,D):
    for n in ORDER: rig.pose.bones[n].matrix=D[n]@rest[n]
    bpy.context.view_layer.update()
    for b in rig.pose.bones:
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion)<0: b.rotation_quaternion.negate()
        previous[b.name]=b.rotation_quaternion.copy()
        b.keyframe_insert(data_path='location',frame=f,group=b.name); b.keyframe_insert(data_path='rotation_quaternion',frame=f,group=b.name)
    s=stats.setdefault(CUR[0],{'min_z':9.0,'poses':{}})
    for bone,vs in PART_VERTS.values():
        s['min_z']=min(s['min_z'],min((D[bone]@v).z for v in vs))
    s['poses'][f]={n:D[n].copy() for n in ORDER}
rig.animation_data_create()
def new_action(n,end,loop,start,desc):
    a=bpy.data.actions.new(n); a.use_fake_user=True; rig.animation_data.action=a; previous.clear(); CUR[0]=n
    clips[n]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':start,'description':desc}
def smooth(t): t=max(0.0,min(1.0,t)); return t*t*(3-2*t)

# Idle: alert guard — every term is zero at frame 1 (starts on the shared BASE).
new_action('Champion_Idle',73,True,1,'Alert guard behind the shield: breathing, weight shift leg to leg, head scanning, shield bobbing slightly.')
for f in range(1,74):
    p=math.tau*(f-1)/72; br=(1-math.cos(2*p))/2
    D=pose(off=(.018*math.sin(p),0,-.008*br),hips_q=qy(1.5*math.sin(p)),chest_q=qx(1.5*br)@qy(-1.0*math.sin(p)),
           head_q=qz(10*math.sin(p))@qx(-2*br),arm_l=(-2*br,1.5*br,0),arm_r=(-2*br,1.5*br,0))
    bake(f,D)

# Walk: lighter, quicker step; shield kept up in front.
CYCLE=28; STRIDE=.34; DUTY=.60; LIFT=.09
def foot_track(phase,base):
    phase%=1.0
    if phase<DUTY:
        y=base.y-STRIDE/2+STRIDE*(phase/DUTY); z=base.z; sw=0.0
    else:
        s=(phase-DUTY)/(1-DUTY); y=base.y+STRIDE/2-STRIDE*smooth(s); z=base.z+LIFT*math.sin(math.pi*s); sw=math.sin(math.pi*s)
    return Vector((base.x,y,z)),sw
new_action('Champion_Walk',29,True,91,'Lighter, quicker step in place: shield kept up in front, hip bob, small trunk counter-twist.')
for f in range(1,30):
    ph=(f-1)/CYCLE; p=math.tau*ph
    fl,swl=foot_track(ph,J['AN_l']); fr,swr=foot_track(ph+.5,J['AN_r'])
    D=pose(off=(0,0,-.035-.018*math.cos(2*p)),hips_q=qz(4*math.sin(p))@qy(1.5*math.sin(p)),
           chest_q=qz(-5*math.sin(p))@qx(3),head_q=qz(2*math.sin(p))@qx(-2),
           arm_l=(-2+2*math.cos(2*p),1.5*math.cos(2*p),0),arm_r=(-2+2*math.cos(2*p),1.5*math.cos(2*p),0),
           feet=(fl,fr),feet_q=(qx(-10*swl),qx(-10*swr)))
    bake(f,D)

# Attack: shield bash with a step of the left foot.
new_action('Champion_Attack',31,False,141,'Shield bash: pulls the shield and body back, steps in with the left foot and shoves the shield forward with both arms (impact 13), recovers to the guard.')
#      off               chest_x twist  head  upper  fore  step(0..1)
K={1: ((0,0,0),           0,     0,    0,     0,    0,    0.0),
   7: ((0,.05,-.02),     -8,    -8,   -4,    14,  -10,    0.0),
   13:((0,-.15,-.05),    12,     6,    6,   -34,   26,    1.0),
   17:((0,-.15,-.05),    11,     5,    5,   -32,   24,    1.0),
   31:((0,0,0),           0,     0,    0,     0,    0,    0.0)}
ks=sorted(K)
for f in range(1,32):
    lo=max(k for k in ks if k<=f); hi=min(k for k in ks if k>=f); t=0 if lo==hi else smooth((f-lo)/(hi-lo))
    A,B=K[lo],K[hi]; L=lambda i:A[i]+(B[i]-A[i])*t
    off=tuple(a+(b-a)*t for a,b in zip(A[0],B[0])); step=L(6)
    lift=.06*math.sin(math.pi*step) if 0<step<1 and hi in (13,31) else 0.0
    front=J['AN_l']+Vector((0,-.17*step,lift))
    D=pose(off=off,chest_q=qz(L(2))@qx(L(1)),head_q=qx(L(3)),arm_l=(L(4),L(5),0),arm_r=(L(4),L(5),0),
           feet=(front,J['AN_r']),feet_q=(qx(-8*math.sin(math.pi*step)) if lift>0 else Quaternion(),Quaternion()))
    bake(f,D)

# Shield Wall: braced pose = crouch, wide stance, shield raised to face height (forearms kept level).
BRACE={'off':Vector((0,-.03,-.08)),'chest':9.0,'head':11.0,'upper':-86.0,'fore':84.0,'step_l':Vector((0,-.08,0)),'step_r':Vector((0,.05,0))}
def wall_pose(k,jolt=0.0,breath=0.0,tremble=0.0):
    # k: 0 = shared BASE, 1 = full brace. jolt: extra crouch/shield drop of the landing. breath/tremble: hold loop.
    off=BRACE['off']*k+Vector((0,0,-.025*jolt-.008*breath))
    up=BRACE['upper']*k+4*jolt+tremble; fo=BRACE['fore']*k-3*jolt-tremble
    feet=(J['AN_l']+BRACE['step_l']*k,J['AN_r']+BRACE['step_r']*k)
    return pose(off=tuple(off),chest_q=qx(BRACE['chest']*k+2*jolt+1.5*breath),head_q=qx(BRACE['head']*k),
                arm_l=(up,fo,0),arm_r=(up,fo,0),feet=feet)
new_action('Champion_ShieldWall',25,False,181,'Shield Wall activation: widens the stance, crouches and raises the shield to face height with both arms; the shield lands with an impact jolt (frame 12); ends braced (= first frame of Champion_ShieldWallHold).')
for f in range(1,26):
    k=smooth((f-1)/11)                                   # raise 1..12
    jolt=math.sin(math.pi*min(1.0,max(0.0,(f-12)/8)))    # landing jolt 12..20, back to 0
    bake(f,wall_pose(k,jolt))
new_action('Champion_ShieldWallHold',49,True,221,'Shield Wall held while the defence buff lasts: braced behind the raised shield, tense breathing, tiny shield tremble.')
for f in range(1,50):
    p=math.tau*(f-1)/48
    bake(f,wall_pose(1.0,0.0,(1-math.cos(p))/2,.8*math.sin(3*p)))

MARKERS={'Champion_Idle':[('LOOP_START',1),('LOOP_END',73)],'Champion_Walk':[('LOOP_START',1),('LOOP_END',29)],
         'Champion_Attack':[('START',1),('WINDUP',7),('IMPACT',13),('RECOVERED',31)],
         'Champion_ShieldWall':[('START',1),('SHIELD_UP',12),('BRACED',25)],'Champion_ShieldWallHold':[('LOOP_START',1),('LOOP_END',49)]}
for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    for label,fr in MARKERS[n]: a.pose_markers.new(label).frame=fr
clips['Champion_Attack']['impact_frame']=13
clips['Champion_Walk']['speed_m_s']=STRIDE/(CYCLE/24)
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=271; scene.frame_set(1)

def close(A,B,tol=2e-4): return all(abs(A[r][c]-B[r][c])<tol for r in range(4) for c in range(4))
chk=[]
idle=stats['Champion_Idle']['poses']; walk=stats['Champion_Walk']['poses']; atk=stats['Champion_Attack']['poses']
if not all(close(idle[1][n],idle[73][n]) for n in ORDER): chk.append('idle loop not closed')
if not all(close(walk[1][n],walk[29][n]) for n in ORDER): chk.append('walk loop not closed')
if not all(close(atk[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('attack does not start at the idle base')
if not all(close(atk[31][n],atk[1][n]) for n in ORDER): chk.append('attack does not end where it starts')
wall=stats['Champion_ShieldWall']['poses']; hold=stats['Champion_ShieldWallHold']['poses']
if not all(close(wall[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('shield wall does not start at the idle base')
if not all(close(wall[25][n],hold[1][n]) for n in ORDER): chk.append('shield wall does not end on the hold pose')
if not all(close(hold[1][n],hold[49][n]) for n in ORDER): chk.append('shield wall hold loop not closed')
for clip,s in stats.items():
    if s['min_z']<-.01: chk.append('%s goes below the ground (%.3f)'%(clip,s['min_z']))
summary={}
for pr in problems: summary.setdefault(pr[0]+':'+pr[1],0); summary[pr[0]+':'+pr[1]]+=1
validation={'problems':chk,'ik':summary,'min_z':{k:round(v['min_z'],4) for k,v in stats.items()}}
st.update({'scene':scene,'parts':parts,'rig':rig,'clips':clips,'source':str(source),'root':root,'animation_validation':validation,
           'material':bpy.data.materials[NAME+'_PixelArt']})
result={'bones':len(arm.bones),'validation':validation,'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
