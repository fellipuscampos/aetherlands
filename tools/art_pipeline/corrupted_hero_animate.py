"""Rigid-bone rig + baked Idle / Walk / Attack for the live Corrupted Hero V1 (tired old
knight, iron-block mace resting on the ground, tower shield held in guard), via Blender MCP.
Flat rig (every bone a child of root, one bone per rigid group): each pose is a world-space
delta D written as pose_bone.matrix = D @ rest, computed by forward kinematics about joint
pivots measured on the live meshes. Legs use an analytic two-bone IK (knee bends forward,
feet planted or sliding on the ground); a ground guard turns the right wrist whenever the
mace head would sink into the floor, so the mace rests/drags on the ground.
A shared neutral BASE (hips 3 cm lower, knees slightly bent) starts/ends every clip, so the
Godot crossfades are clean (all clips key the same bones).
- Hero_Idle (72 f, loop): heavy tired breathing, head hangs and sways, shield arm sags and
  lifts, mace on the ground.
- Hero_Walk (32 f, loop, in place): heavy step, hip bob/roll, trunk counter-twist, mace dragging.
- Hero_Attack (40 f): raises the mace over and behind the head twisting the trunk, smashes it
  down on the ground ahead (impact frame 22), recovers to the tired stance.
- Hero_Block (18 f): Shield Block reaction — ducks behind the tower shield, shoves it forward
  and up with the left arm, the knees give and the body is pushed back by the impact (frame 6),
  recovers to the tired stance.
REBAKE=True rebuilds an existing rig/actions.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

NAME='Corrupted_Hero_V1'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
st=bpy.app.driver_namespace['corrupted_hero']
root=bpy.data.objects[NAME+'_ROOT']
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\corrupted_hero_v1')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
CLIPS=('Hero_Idle','Hero_Walk','Hero_Attack','Hero_Block')
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
else:
    bpy.data.libraries.write(str(source/'corrupted_hero_v1_static.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for n in CLIPS:
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
for m in list(scene.timeline_markers):
    if m.name.startswith('Hero_'): scene.timeline_markers.remove(m)

def P(n): return bpy.data.objects[NAME+'_'+n]
def verts(n): return [v.co.copy() for v in P(n).data.vertices]
def avg(vs): return sum(vs,Vector())/len(vs)
def top4(n): return avg(sorted(verts(n),key=lambda v:v.z)[-4:])
def bot4(n): return avg(sorted(verts(n),key=lambda v:v.z)[:4])
def first4(n): return avg(verts(n)[:4])
def last4(n): return avg(verts(n)[4:])

# Joints measured on the live meshes.
J={}
J['HIP']=avg(verts('Waist')); J['WAIST']=top4('Waist'); J['NECK']=bot4('Head')
J['SH_r']=top4('UpperArm_r')+Vector((0,0,.05)); J['EL_r']=bot4('UpperArm_r'); J['WR_r']=bot4('Forearm_r')
J['SH_l']=first4('UpperArm_l')+Vector((0,0,.05)); J['EL_l']=last4('UpperArm_l'); J['WR_l']=last4('Forearm_l')
for t in ('l','r'):
    J['HJ_'+t]=top4('Thigh_'+t); J['KN_'+t]=bot4('Thigh_'+t); J['AN_'+t]=bot4('Shin_'+t)
# Shoulder cubes ride with the chest (the arm pivots under them), so a raised arm never spins the cube.
override={'Shoulder_l':'chest','Shoulder_r':'chest'}
part_bone={o['part']:override.get(o['part'],o['rig_bone']) for o in parts}
bones={'root':(Vector((0,0,0)),Vector((0,0,.3))),'hips':(J['HIP'],J['HIP']+Vector((0,0,.2))),
       'chest':(J['WAIST'],J['NECK']),'head':(J['NECK'],J['NECK']+Vector((0,0,.3)))}
for t in ('l','r'):
    bones['upper_arm_'+t]=(J['SH_'+t],J['EL_'+t]); bones['forearm_'+t]=(J['EL_'+t],J['WR_'+t])
    bones['hand_'+t]=(J['WR_'+t],J['WR_'+t]+(J['WR_'+t]-J['EL_'+t]).normalized()*.15)
    bones['thigh_'+t]=(J['HJ_'+t],J['KN_'+t]); bones['shin_'+t]=(J['KN_'+t],J['AN_'+t])
    bones['foot_'+t]=(J['AN_'+t],J['AN_'+t]+Vector((0,-.2,0)))
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
    mod=o.modifiers.new('Rigid_Hero_Parts','ARMATURE'); mod.object=rig; o.parent=rig
rig['notes']='Flat rigid rig, one bone per part group; legs by baked two-bone IK; mace ground guard on the right wrist.'
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
MACE=[v for v in verts('MaceHead')]
def mace_min(Dhand): return min((Dhand@v).z for v in MACE)
BASE_DROP=.03
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
    # Ground guard: turn the right wrist until the iron head just rests on (or above) the floor.
    if mace_min(D['hand_r'])<.003:
        best=None
        for step in range(1,60):
            for sgn in (1,-1):
                cand=D['forearm_r']@about(J['WR_r'],qx(arm_r[2]+sgn*step))
                if mace_min(cand)>=.003: best=cand; break
            if best is not None: break
        if best is None: problems.append(('mace',CUR[0]))
        else: D['hand_r']=best
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

# Idle: heavy tired breathing.
new_action('Hero_Idle',73,True,1,'Heavy tired breathing, head hangs and sways, shield arm sags and lifts, mace resting on the ground.')
for f in range(1,74):
    p=math.tau*(f-1)/72; br=(1-math.cos(p))/2
    # Every term is zero at frame 1, so the idle starts exactly on the shared BASE pose.
    D=pose(off=(0,0,-.018*br),chest_q=qx(3.0*br),head_q=qx(4*math.sin(p)+2*br)@qz(3*math.sin(p)),
           arm_r=(1.2*math.sin(p),0,0),arm_l=(-3*math.sin(p)+2*br,2*math.sin(p),0))
    bake(f,D)

# Walk: heavy step in place, mace dragging.
CYCLE=32; STRIDE=.40; DUTY=.60; LIFT=.11
def foot_track(phase,base):
    phase%=1.0
    if phase<DUTY:
        y=base.y-STRIDE/2+STRIDE*(phase/DUTY); z=base.z; sw=0.0
    else:
        s=(phase-DUTY)/(1-DUTY); y=base.y+STRIDE/2-STRIDE*smooth(s); z=base.z+LIFT*math.sin(math.pi*s); sw=math.sin(math.pi*s)
    return Vector((base.x,y,z)),sw
new_action('Hero_Walk',33,True,91,'Heavy tired step in place: hip bob and roll, trunk counter-twist, head nods, mace dragging on the ground.')
for f in range(1,34):
    ph=(f-1)/CYCLE; p=math.tau*ph
    fl,swl=foot_track(ph,J['AN_l']); fr,swr=foot_track(ph+.5,J['AN_r'])
    D=pose(off=(0,0,-.05-.025*math.cos(2*p)),hips_q=qy(2.5*math.sin(p))@qz(4*math.sin(p)),
           chest_q=qz(-6*math.sin(p))@qx(2),head_q=qx(3*math.cos(2*p))@qz(3*math.sin(p)),
           arm_r=(5*math.sin(p),0,0),arm_l=(-2+3*math.cos(2*p),0,0),
           feet=(fl,fr),feet_q=(qx(-12*swl),qx(-12*swr)))
    bake(f,D)

# Attack: overhead smash with the mace.
new_action('Hero_Attack',41,False,141,'Raises the mace over and behind the head twisting the trunk, smashes it down on the ground ahead (impact 22), recovers to the tired stance.')
#      off              chest_x twist head  upper  fore  hand  shield_upper
K={1: ((0,0,0),          0,    0,    0,     0,     0,    0,    0),
   10:((0,.04,-.01),   -10,  -16,   -6,  -195,   -70,   0,   -6),
   16:((0,.05,-.01),   -12,  -20,   -8,  -212,   -82,   0,   -8),
   22:((0,-.10,-.08),   14,   12,    8,   -58,    -6,  12,   -4),
   27:((0,-.10,-.08),   14,   10,    8,   -55,    -4,  12,   -4),
   41:((0,0,0),          0,    0,    0,     0,     0,    0,    0)}
ks=sorted(K)
for f in range(1,42):
    lo=max(k for k in ks if k<=f); hi=min(k for k in ks if k>=f); t=0 if lo==hi else smooth((f-lo)/(hi-lo))
    A,B=K[lo],K[hi]; L=lambda i:A[i]+(B[i]-A[i])*t
    off=tuple(a+(b-a)*t for a,b in zip(A[0],B[0]))
    D=pose(off=off,chest_q=qz(L(2))@qx(L(1)),head_q=qx(L(3)),arm_r=(L(4),L(5),L(6)),arm_l=(L(7),0,0))
    bake(f,D)

# Block: Shield Block reaction (one-shot, plays when the hero negates a hit in game).
new_action('Hero_Block',19,False,201,'Shield Block: ducks behind the tower shield, shoves it forward/up, knees give and the body is pushed back by the impact (frame 6), recovers.')
#      off               chest_x twist head  arm_l (upper, fore, hand)  arm_r
BK={1: ((0,0,0),           0,    0,    0,   (0,0,0),                  (0,0,0)),
    6: ((0,.08,-.07),      9,  -14,   12,   (-28,-16,0),              (5,0,0)),
    10:((0,.07,-.06),      8,  -12,   10,   (-26,-14,0),              (4,0,0)),
    19:((0,0,0),           0,    0,    0,   (0,0,0),                  (0,0,0))}
ks=sorted(BK)
for f in range(1,20):
    lo=max(k for k in ks if k<=f); hi=min(k for k in ks if k>=f); t=0 if lo==hi else smooth((f-lo)/(hi-lo))
    A,B=BK[lo],BK[hi]; L=lambda i:A[i]+(B[i]-A[i])*t
    off=tuple(a+(b-a)*t for a,b in zip(A[0],B[0])); al=tuple(a+(b-a)*t for a,b in zip(A[4],B[4])); ar=tuple(a+(b-a)*t for a,b in zip(A[5],B[5]))
    D=pose(off=off,chest_q=qz(L(2))@qx(L(1)),head_q=qx(L(3)),arm_l=al,arm_r=ar)
    bake(f,D)

MARKERS={'Hero_Idle':[('LOOP_START',1),('LOOP_END',73)],'Hero_Walk':[('LOOP_START',1),('LOOP_END',33)],
         'Hero_Attack':[('START',1),('WINDUP',16),('IMPACT',22),('RECOVERED',41)],'Hero_Block':[('START',1),('IMPACT',6),('RECOVERED',19)]}
for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    for label,fr in MARKERS[n]: a.pose_markers.new(label).frame=fr
clips['Hero_Attack']['impact_frame']=22
clips['Hero_Walk']['speed_m_s']=STRIDE/(CYCLE/24)
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=221; scene.frame_set(1)

def close(A,B,tol=2e-4): return all(abs(A[r][c]-B[r][c])<tol for r in range(4) for c in range(4))
chk=[]
idle=stats['Hero_Idle']['poses']; walk=stats['Hero_Walk']['poses']; atk=stats['Hero_Attack']['poses']
if not all(close(idle[1][n],idle[73][n]) for n in ORDER): chk.append('idle loop not closed')
if not all(close(walk[1][n],walk[33][n]) for n in ORDER): chk.append('walk loop not closed')
if not all(close(atk[1][n],idle[1][n],2e-3) for n in ORDER if n not in ('hand_r',)): chk.append('attack does not start at the idle base')
if not all(close(atk[41][n],atk[1][n]) for n in ORDER): chk.append('attack does not end where it starts')
blk=stats['Hero_Block']['poses']
if not all(close(blk[1][n],idle[1][n],2e-3) for n in ORDER if n!='hand_r') or not all(close(blk[19][n],blk[1][n]) for n in ORDER): chk.append('block does not start/end at the idle base')
for clip,s in stats.items():
    if s['min_z']<-.01: chk.append('%s goes below the ground (%.3f)'%(clip,s['min_z']))
summary={}
for pr in problems: summary.setdefault(pr[0]+':'+pr[1],0); summary[pr[0]+':'+pr[1]]+=1
validation={'problems':chk,'ik_and_guard':summary,'min_z':{k:round(v['min_z'],4) for k,v in stats.items()}}
st.update({'scene':scene,'parts':parts,'rig':rig,'clips':clips,'source':str(source),'root':root,'animation_validation':validation,
           'material':bpy.data.materials[NAME+'_PixelArt']})
result={'bones':len(arm.bones),'validation':validation,'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
