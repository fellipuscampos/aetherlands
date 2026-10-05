"""Rigid-bone rig + baked clips for the live BladeHero V1 (Herói da Lâmina, legendary), via Blender
MCP. The Blade Hero is a copy of the Weapon Master (same joints) fitted to 2.00 m, so this is
blade_hero_animate.py with the BladeHero names and every ABSOLUTE distance of the clips (body
offsets, steps, the Power Strike grip path) scaled by S = body height / 1.80 — the poses keep the
proportions of the 1.80 m troops. Plays every clip of the line: Idle, Walk, Attack, PowerStrike
(Golpe Poderoso, impact frame 26) and ArcAttack (Ataque em Arco, arm extended). REBAKE=True rebuilds.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

NAME='BladeHero_V1'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
st=bpy.app.driver_namespace['blade_hero']
root=bpy.data.objects[NAME+'_ROOT']
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\blade_hero_v1')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
CLIPS=('BladeHero_Idle','BladeHero_Walk','BladeHero_Attack','BladeHero_PowerStrike','BladeHero_ArcAttack')
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
else:
    bpy.data.libraries.write(str(source/'blade_hero_v1_static.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for n in CLIPS:
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
for m in list(scene.timeline_markers):
    if m.name.startswith('BladeHero_'): scene.timeline_markers.remove(m)

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
# Clip distances were authored for the 1.80 m body: scale them with this body (gear excluded).
S=max(v.co.z for o in parts if not o.users_collection[0].name.endswith('05_GEAR') for v in o.data.vertices)/1.80
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
    mod=o.modifiers.new('Rigid_BladeHero_Parts','ARMATURE'); mod.object=rig; o.parent=rig
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
    D['hips']=Tm(Vector(off)*S+Vector((0,0,-BASE_DROP*S)))@about(J['HIP'],hips_q)
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

# Idle: ready to fight — every term is zero at frame 1 (starts on the shared BASE).
new_action('BladeHero_Idle',73,True,1,'Ready to fight: weight shift leg to leg, hatchet bobbing, left fist in guard, head watching, breathing.')
for f in range(1,74):
    p=math.tau*(f-1)/72; br=(1-math.cos(2*p))/2
    D=pose(off=(.02*math.sin(p),0,-.01*br),hips_q=qy(2*math.sin(p)),chest_q=qx(1.5*br)@qz(3*math.sin(p)),
           head_q=qz(8*math.sin(p))@qx(-2*br),arm_r=(-4*br,3*math.sin(2*p),2*math.sin(2*p)),arm_l=(-3*br,2*math.sin(p),0))
    bake(f,D)

# Walk: light step; arms counter-swing with the legs (hatchet arm and guard arm).
CYCLE=28; STRIDE=.36*S; DUTY=.60; LIFT=.09*S
def foot_track(phase,base):
    phase%=1.0
    if phase<DUTY:
        y=base.y-STRIDE/2+STRIDE*(phase/DUTY); z=base.z; sw=0.0
    else:
        s=(phase-DUTY)/(1-DUTY); y=base.y+STRIDE/2-STRIDE*smooth(s); z=base.z+LIFT*math.sin(math.pi*s); sw=math.sin(math.pi*s)
    return Vector((base.x,y,z)),sw
new_action('BladeHero_Walk',29,True,91,'Light step in place: arms counter-swinging with the legs, hip bob, small trunk counter-twist.')
for f in range(1,30):
    ph=(f-1)/CYCLE; p=math.tau*ph
    fl,swl=foot_track(ph,J['AN_l']); fr,swr=foot_track(ph+.5,J['AN_r'])
    D=pose(off=(0,0,-.035-.018*math.cos(2*p)),hips_q=qz(5*math.sin(p))@qy(1.5*math.sin(p)),
           chest_q=qz(-6*math.sin(p))@qx(3),head_q=qz(2*math.sin(p))@qx(-2),
           arm_r=(7*math.sin(p),2*math.cos(2*p),0),arm_l=(-7*math.sin(p),2*math.cos(2*p),0),
           feet=(fl,fr),feet_q=(qx(-10*swl),qx(-10*swr)))
    bake(f,D)

# Attack: overhead hatchet chop with a step of the left foot.
new_action('BladeHero_Attack',33,False,141,'Overhead hatchet chop: raises the hatchet behind the head twisting the trunk, steps in with the left foot and chops down forward (impact 15), recovers.')
#      off               chest_x twist  head  r_upper r_fore r_hand  l_upper  step
K={1: ((0,0,0),           0,     0,    0,     0,     0,     0,      0,     0.0),
   # Windup: arm up in front, forearm opened so the hatchet points UP and BACK over the head.
   8: ((0,.04,0),        -6,   -14,   -4,  -120,    72,     0,     10,     0.0),
   11:((0,.045,0),       -7,   -16,   -5,  -128,    78,     0,     12,     0.0),
   15:((0,-.14,-.05),    14,    14,    6,   -30,    30,    30,    -12,     1.0),
   19:((0,-.14,-.05),    13,    12,    5,   -28,    28,    28,    -10,     1.0),
   33:((0,0,0),           0,     0,    0,     0,     0,     0,      0,     0.0)}
ks=sorted(K)
for f in range(1,34):
    lo=max(k for k in ks if k<=f); hi=min(k for k in ks if k>=f); t=0 if lo==hi else smooth((f-lo)/(hi-lo))
    A,B=K[lo],K[hi]; L=lambda i:A[i]+(B[i]-A[i])*t
    off=tuple(a+(b-a)*t for a,b in zip(A[0],B[0])); step=L(8)
    lift=.06*math.sin(math.pi*step) if 0<step<1 and hi in (15,33) else 0.0
    front=J['AN_l']+Vector((0,-.17*step,lift))*S
    D=pose(off=off,chest_q=qz(L(2))@qx(L(1)),head_q=qx(L(3)),arm_r=(L(4),L(5),L(6)),arm_l=(L(7),0,0),
           feet=(front,J['AN_r']),feet_q=(qx(-8*math.sin(math.pi*step)) if lift>0 else Quaternion(),Quaternion()))
    bake(f,D)

# Power Strike (Golpe Poderoso): one-handed leaping full-arc blow, so it fits every skin of the line
# (hatchet now, sword later, and the left hand stays free for a shield). The weapon (any haft/grip in
# hand_r) is posed by its grip point P and swing angle phi — haft direction (0,-sin phi, cos phi): 0 = up,
# 90 = forward, <0 = back over the shoulder — and the weapon arm reaches it by two-bone IK. The left arm is
# FK: it points at the target while coiling and swings back at the impact (counterweight).
WEAPON_PART='SwordGrip'
wv=verts(WEAPON_PART); AXW=(avg(wv[4:])-avg(wv[:4])).normalized()
GR=avg(verts('Hand_r')); PHI0=math.degrees(math.atan2(-AXW.y,AXW.z))
LA={t:(J['EL_'+t]-J['SH_'+t]).length for t in 'lr'}; LB={t:(J['WR_'+t]-J['EL_'+t]).length for t in 'lr'}
def arm_ik(t,Dc,target,pole_local):
    S=J['SH_'+t]; E=J['EL_'+t]; W=J['WR_'+t]
    S2=Dc@S; W2=Vector(target); l1,l2=LA[t],LB[t]; d=(W2-S2).length
    if d>(l1+l2)*.9995: problems.append(('arm_reach',CUR[0],t,round(d-(l1+l2),4))); d=(l1+l2)*.9995; W2=S2+(W2-S2).normalized()*d
    u=(W2-S2).normalized(); pole=Dc.to_3x3()@Vector(pole_local); pole=(pole-u*pole.dot(u)).normalized()
    a=math.acos(max(-1,min(1,(l1*l1+d*d-l2*l2)/(2*l1*d))))
    E2=S2+u*math.cos(a)*l1+pole*math.sin(a)*l1
    R1=(E-S).normalized().rotation_difference((E2-S2).normalized()).to_matrix().to_4x4()
    R2=(W-E).normalized().rotation_difference((W2-E2).normalized()).to_matrix().to_4x4()
    return Tm(S2)@R1@Tm(-S),Tm(E2)@R2@Tm(-E)
def blend_bone(n,A,B,w):
    # Blend two deltas in BONE space (head position + orientation), so the arm never detaches mid-blend.
    la,qa,_=(A@rest[n]).decompose(); lb,qb,_=(B@rest[n]).decompose()
    if qa.dot(qb)<0: qb.negate()
    return Matrix.LocRotScale(la.lerp(lb,w),qa.slerp(qb,w),None)@rest[n].inverted()
POLE_R=(-.8,.1,-.6)                                       # weapon elbow out and down
new_action('BladeHero_PowerStrike',49,False,181,'Golpe Poderoso: coils with the weapon loaded behind the back and the left arm pointing at the target, leaps into a full overhead arc and smashes it down low in front (impact 26, held), recovers. One-handed: shared by the line skins.')
#       grip P (right)         phi   off                chest_x twist head  l_up  l_fore step  ease-into-key
# Heavy longsword (~1.0 m): impact angle 130 deg (not 135) so the longer blade's tip clears the ground.
PK={1: (tuple(GR/S),            PHI0, (0,0,0),            0,     0,    0,    0,    0,   0.0, 's'),
    10:((-.40,.20,1.52),      -100, (0,.06,-.08),     -10,   -18,   -4,  -45,   40,   0.0, 's'),   # coil: weapon loaded behind the back
    18:((-.42,.22,1.55),      -106, (0,.07,-.09),     -12,   -20,   -5,  -48,   42,   0.0, 's'),   # tension hold
    22:((-.26,-.06,1.80),        0, (0,-.04,-.02),     -2,   -6,   -2,  -35,   20,   0.5, 'in'),  # leaping, weapon over the top
    26:((-.16,-.50,.74),       130, (0,-.24,-.20),     28,    18,   -8,   38,  -20,   1.0, 'lin'), # IMPACT: low and forward, left arm thrown back
    32:((-.16,-.50,.73),       131, (0,-.24,-.21),     29,    18,   -8,   40,  -22,   1.0, 's'),   # impact held
    40:((-.24,-.20,1.12),       60, (0,-.08,-.07),     10,     6,    4,   10,   -8,   0.3, 's'),   # recovering
    48:(tuple(GR/S),            PHI0, (0,0,0),            0,     0,    0,    0,    0,   0.0, 's')}
pks=sorted(PK)
def ik_weight(f): return smooth((f-1)/8) if f<10 else (1.0 if f<=36 else smooth((48-f)/10))
for f in range(1,50):
    fk=min(f,48); lo=max(k for k in pks if k<=fk); hi=min(k for k in pks if k>=fk); u=0 if lo==hi else (fk-lo)/(hi-lo)
    ease=PK[hi][9]; t=u*u if ease=='in' else (u if ease=='lin' else smooth(u))
    A,B=PK[lo],PK[hi]; L=lambda i:A[i]+(B[i]-A[i])*t
    P=Vector(A[0]).lerp(Vector(B[0]),t)*S; phi=L(1); off=Vector(A[2]).lerp(Vector(B[2]),t); step=L(8)
    if 26<=f<=31: off=off+Vector((.008*math.sin(f*2.6),0,-.01*math.exp(-(f-26)*.6)))   # impact shudder
    lift=.08*math.sin(math.pi*step) if 0<step<1 else 0.0
    front=J['AN_l']+Vector((0,-.34*step,lift))*S
    D=pose(off=tuple(off),chest_q=qz(L(4))@qx(L(3)),head_q=qz(-.5*L(4))@qx(L(5)),arm_l=(L(6),L(7),0),
           feet=(front,J['AN_r']),feet_q=(qx(-8*math.sin(math.pi*step)) if lift>0 else Quaternion(),Quaternion()))
    w=ik_weight(f)
    if w>0:
        R=qx(phi-PHI0); H=Tm(P)@R.to_matrix().to_4x4()@Tm(-GR)
        up,fo=arm_ik('r',D['chest'],H@J['WR_r'],POLE_R)
        for n,M in (('upper_arm_r',up),('forearm_r',fo),('hand_r',H)): D[n]=M if w>=1 else blend_bone(n,D[n],M,w)
    bake(f,D)

# Arc Attack (Ataque em Arco): flat sweep. The sword is posed by grip P, heading psi (0 = front, +90 = the
# character's right, -90 = his left; horizontal direction (-sin psi, -cos psi, 0)) and a small pitch; its edge
# leads the sweep (right to left). Rest weapon frame (axis, edge) is mapped onto (A, E).
BLW=(Vector((0,-1,0))-AXW*Vector((0,-1,0)).dot(AXW)).normalized()     # rest edge: forward, square to the axis
REST_F=Matrix((AXW,BLW,AXW.cross(BLW))).transposed()
def weapon_rot(psi,pitch):
    s,c=math.sin(math.radians(psi)),math.cos(math.radians(psi)); pc,ps=math.cos(math.radians(pitch)),math.sin(math.radians(pitch))
    A_=Vector((-s*pc,-c*pc,ps)); E=Vector((c,-s,0))                         # E: sweep direction (psi decreasing)
    E=(E-A_*E.dot(A_)).normalized()
    return (Matrix((A_,E,A_.cross(E))).transposed()@REST_F.transposed()).to_4x4()
new_action('BladeHero_ArcAttack',41,False,241,'Ataque em Arco: coils right with the sword level pointing back, turns the body and sweeps the blade ~250 deg flat around, right to left (front at 19), holds the follow-through, recovers. Shared by the line evolutions.')
#       arm reach           psi  pitch  off               hips  chest head_turn l_up l_fore step  ease
AK={1: (.70,                 118,  -8, (0,0,0),             0,    0,    0,       0,    0,  0.0, 's'),
    10:(.97,                 118,  -8, (0,.03,-.07),      -20,  -30,   30,     -40,   45,  0.0, 's'),   # coiled right, sword back
    13:(.97,                 121,  -8, (0,.03,-.08),      -22,  -32,   32,     -42,   46,  0.0, 's'),   # tension
    19:(.97,                   0,  -6, (0,-.06,-.10),       0,    5,   -2,     -10,   10,  0.6, 'in'),  # blade crosses the front
    24:(.97,                -100,  -8, (0,-.10,-.10),      30,   44,  -36,      30,    5,  1.0, 'lin'), # follow-through, left side
    28:(.97,                -104,  -9, (0,-.10,-.11),      31,   46,  -37,      32,    6,  1.0, 's'),   # held
    40:(.70,                -104,  -9, (0,0,0),             0,    0,    0,       0,    0,  0.0, 's')}
aks=sorted(AK); ARM_REACH=LA['r']+LB['r']
def arc_weight(f): return smooth((f-1)/8) if f<10 else (1.0 if f<=29 else smooth((40-f)/10))
for f in range(1,42):
    fk=min(f,40); lo=max(k for k in aks if k<=fk); hi=min(k for k in aks if k>=fk); u=0 if lo==hi else (fk-lo)/(hi-lo)
    ease=AK[hi][10]; t=u*u if ease=='in' else (u if ease=='lin' else smooth(u))
    A,B=AK[lo],AK[hi]; L=lambda i:A[i]+(B[i]-A[i])*t
    ext=L(0); off=Vector(A[3]).lerp(Vector(B[3]),t); step=L(9)
    lift=.05*math.sin(math.pi*step) if 0<step<1 else 0.0
    front=J['AN_l']+Vector((.06*step,-.22*step,lift))*S                              # weight steps onto the front foot
    D=pose(off=tuple(off),hips_q=qz(L(4)),chest_q=qz(L(5)),head_q=qz(L(6)),arm_l=(L(7),L(8),0),
           feet=(front,J['AN_r']),feet_q=(qz(L(4)*.5)@(qx(-6*math.sin(math.pi*step)) if lift>0 else Quaternion()),qz(L(4)*.5)))
    w=arc_weight(f)
    if w>0:
        # ARM EXTENDED: the wrist goes out from the shoulder along the blade heading (arm a little lower than the
        # blade), at `ext` of the full arm reach; the sword continues the arm's line.
        psi,pitch=math.radians(L(1)),math.radians(L(2)-2)
        S2=D['chest']@J['SH_r']; W=S2+Vector((-math.sin(psi)*math.cos(pitch),-math.cos(psi)*math.cos(pitch),math.sin(pitch)))*ext*ARM_REACH
        H=Tm(W)@weapon_rot(L(1),L(2))@Tm(-J['WR_r'])
        up,fo=arm_ik('r',D['chest'],W,POLE_R)
        for n,M in (('upper_arm_r',up),('forearm_r',fo),('hand_r',H)): D[n]=M if w>=1 else blend_bone(n,D[n],M,w)
    bake(f,D)

MARKERS={'BladeHero_Idle':[('LOOP_START',1),('LOOP_END',73)],'BladeHero_Walk':[('LOOP_START',1),('LOOP_END',29)],
         'BladeHero_Attack':[('START',1),('WINDUP',11),('IMPACT',15),('RECOVERED',33)],
         'BladeHero_PowerStrike':[('START',1),('COILED',10),('RELEASE',18),('IMPACT',26),('RECOVERED',49)],
         'BladeHero_ArcAttack':[('START',1),('COILED',10),('RELEASE',13),('IMPACT',19),('FOLLOW_THROUGH',24),('RECOVERED',41)]}

for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    for label,fr in MARKERS[n]: a.pose_markers.new(label).frame=fr
clips['BladeHero_Attack']['impact_frame']=15; clips['BladeHero_PowerStrike']['impact_frame']=26; clips['BladeHero_ArcAttack']['impact_frame']=19
clips['BladeHero_Walk']['speed_m_s']=STRIDE/(CYCLE/24)
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=281; scene.frame_set(1)

def close(A,B,tol=2e-4): return all(abs(A[r][c]-B[r][c])<tol for r in range(4) for c in range(4))
chk=[]
idle=stats['BladeHero_Idle']['poses']; walk=stats['BladeHero_Walk']['poses']; atk=stats['BladeHero_Attack']['poses']; pw=stats['BladeHero_PowerStrike']['poses']; arc=stats['BladeHero_ArcAttack']['poses']
if not all(close(idle[1][n],idle[73][n]) for n in ORDER): chk.append('idle loop not closed')
if not all(close(walk[1][n],walk[29][n]) for n in ORDER): chk.append('walk loop not closed')
if not all(close(atk[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('attack does not start at the idle base')
if not all(close(atk[33][n],atk[1][n]) for n in ORDER): chk.append('attack does not end where it starts')
if not all(close(pw[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('power strike does not start at the idle base')
if not all(close(pw[49][n],pw[1][n]) for n in ORDER): chk.append('power strike does not end where it starts')
if not all(close(arc[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('arc attack does not start at the idle base')
if not all(close(arc[41][n],arc[1][n]) for n in ORDER): chk.append('arc attack does not end where it starts')
for clip,s in stats.items():
    if s['min_z']<-.01: chk.append('%s goes below the ground (%.3f)'%(clip,s['min_z']))
summary={}
for pr in problems: summary.setdefault(pr[0]+':'+pr[1],0); summary[pr[0]+':'+pr[1]]+=1
validation={'problems':chk,'ik':summary,'min_z':{k:round(v['min_z'],4) for k,v in stats.items()}}
st.update({'scene':scene,'parts':parts,'rig':rig,'clips':clips,'source':str(source),'root':root,'animation_validation':validation,
           'material':bpy.data.materials[NAME+'_PixelArt']})
result={'bones':len(arm.bones),'validation':validation,'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
