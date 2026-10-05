"""Rigid-bone rig + baked Idle / Walk / Attack (draw and loose) for the live Archer V1 (Arqueiro), via
Blender MCP. Same machinery as warrior_animate.py (the Archer is a copy of the Warrior: same joints)
plus three bones for the bow: the string is two halves (string_u / string_d) hinged at the bow tips
that rotate AND stretch along their length so the string forms a V to the drawing hand, and the
arrow has its own bone (nocked on the bow at rest, flies on release, hidden at ~0 scale inside the
quiver while a new one is drawn). Flat rig, world-space deltas D @ rest, legs and (in the Attack)
arms by two-bone IK, a shared BASE starts/ends every clip.
- Archer_Idle (72 f, loop): ready, arrow nocked — weight shift, breathing, head watching.
- Archer_Walk (28 f, loop, in place): light step, arms counter-swinging, arrow kept nocked.
- Archer_Attack (48 f): ranged shot — the right hand takes the string at the nock, the WHOLE archer
  pivots side-on (feet included, left shoulder to the target; head turned to aim), pushes the bow out and draws to the cheek (full draw at 18), aims, LOOSES (frame
  27: the string snaps back with a small vibration, the arrow flies off), takes a new arrow from
  the quiver over the shoulder, nocks it and settles back to the ready stance.
- Archer_PreciseShot (56 f): Disparo Preciso (technique: x1.40 Attack, +1 range) — slower and deliberate:
  lower stance leaning back, the bow raised aiming UP (~14 deg) and drawn to the ear (full draw 22), a
  long steadying aim, a stronger loose at 35 (big string vibration, fast rising arrow, bow kick, draw hand
  flies back), reload. Both shots come from one shot() function (timing/pose tables).
REBAKE=True rebuilds an existing rig/actions.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

NAME='Archer_V1'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
st=bpy.app.driver_namespace['archer']
root=bpy.data.objects[NAME+'_ROOT']
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\archer_v1')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
CLIPS=('Archer_Idle','Archer_Walk','Archer_Attack','Archer_PreciseShot')
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
else:
    bpy.data.libraries.write(str(source/'archer_v1_static.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for n in CLIPS:
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
for m in list(scene.timeline_markers):
    if m.name.startswith('Archer_'): scene.timeline_markers.remove(m)

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
# Bow bones: each string half hinges at its bow tip (head) and points to the nocking point (tail); the arrow bone
# runs from its nock to its point.
TIPU=top4('StringUp'); NOCK=bot4('StringUp'); TIPD=bot4('StringDown')
_sh=verts('ArrowShaft'); _ymax=max(v.y for v in _sh); _ymin=min(v.y for v in _sh)
ARR_N=avg([v for v in _sh if v.y>_ymax-1e-4]); ARR_T=avg([v for v in _sh if v.y<_ymin+1e-4])
bones['string_u']=(TIPU,NOCK); bones['string_d']=(TIPD,NOCK); bones['arrow']=(ARR_N,ARR_T)
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
    mod=o.modifiers.new('Rigid_Archer_Parts','ARMATURE'); mod.object=rig; o.parent=rig
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
    D['string_u']=D['string_d']=D['arrow']=D['hand_l']          # string straight, arrow nocked: they ride the bow
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
        b.keyframe_insert(data_path='scale',frame=f,group=b.name)          # string stretch, hidden arrow
    s=stats.setdefault(CUR[0],{'min_z':9.0,'poses':{}})
    for bone,vs in PART_VERTS.values():
        s['min_z']=min(s['min_z'],min((D[bone]@v).z for v in vs))
    s['poses'][f]={n:D[n].copy() for n in ORDER}
rig.animation_data_create()
def new_action(n,end,loop,start,desc):
    a=bpy.data.actions.new(n); a.use_fake_user=True; rig.animation_data.action=a; previous.clear(); CUR[0]=n
    clips[n]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':start,'description':desc}
def smooth(t): t=max(0.0,min(1.0,t)); return t*t*(3-2*t)

# Idle: ready, arrow nocked — every term is zero at frame 1 (starts on the shared BASE).
new_action('Archer_Idle',73,True,1,'Ready, arrow nocked: weight shift leg to leg, the bow bobbing a little, head watching, breathing.')
for f in range(1,74):
    p=math.tau*(f-1)/72; br=(1-math.cos(2*p))/2
    D=pose(off=(.02*math.sin(p),0,-.01*br),hips_q=qy(2*math.sin(p)),chest_q=qx(1.5*br)@qz(3*math.sin(p)),
           head_q=qz(8*math.sin(p))@qx(-2*br),arm_r=(-4*br,3*math.sin(2*p),2*math.sin(2*p)),arm_l=(-3*br,2*math.sin(p),0))
    bake(f,D)

# Walk: light step; arms counter-swing with the legs (draw arm and bow arm).
CYCLE=28; STRIDE=.36; DUTY=.60; LIFT=.09
def foot_track(phase,base):
    phase%=1.0
    if phase<DUTY:
        y=base.y-STRIDE/2+STRIDE*(phase/DUTY); z=base.z; sw=0.0
    else:
        s=(phase-DUTY)/(1-DUTY); y=base.y+STRIDE/2-STRIDE*smooth(s); z=base.z+LIFT*math.sin(math.pi*s); sw=math.sin(math.pi*s)
    return Vector((base.x,y,z)),sw
new_action('Archer_Walk',29,True,91,'Light step in place: arms counter-swinging with the legs, hip bob, small trunk counter-twist.')
for f in range(1,30):
    ph=(f-1)/CYCLE; p=math.tau*ph
    fl,swl=foot_track(ph,J['AN_l']); fr,swr=foot_track(ph+.5,J['AN_r'])
    D=pose(off=(0,0,-.035-.018*math.cos(2*p)),hips_q=qz(5*math.sin(p))@qy(1.5*math.sin(p)),
           chest_q=qz(-6*math.sin(p))@qx(3),head_q=qz(2*math.sin(p))@qx(-2),
           arm_r=(7*math.sin(p),2*math.cos(2*p),0),arm_l=(-7*math.sin(p),2*math.cos(2*p),0),
           feet=(fl,fr),feet_q=(qx(-10*swl),qx(-10*swr)))
    bake(f,D)

# ---------------- Attack: draw and loose ----------------
LA={s:(J['EL_'+s]-J['SH_'+s]).length for s in 'lr'}; LB={s:(J['WR_'+s]-J['EL_'+s]).length for s in 'lr'}
def arm_ik(s,Dc,target,pole_local):
    S=J['SH_'+s]; E=J['EL_'+s]; W=J['WR_'+s]
    S2=Dc@S; W2=Vector(target); l1,l2=LA[s],LB[s]; d=(W2-S2).length
    if d>(l1+l2)*.9995: problems.append(('arm_reach',CUR[0],s,round(d-(l1+l2),4))); d=(l1+l2)*.9995; W2=S2+(W2-S2).normalized()*d
    u=(W2-S2).normalized(); pole=Dc.to_3x3()@Vector(pole_local); pole=(pole-u*pole.dot(u)).normalized()
    a=math.acos(max(-1,min(1,(l1*l1+d*d-l2*l2)/(2*l1*d))))
    E2=S2+u*math.cos(a)*l1+pole*math.sin(a)*l1
    R1=(E-S).normalized().rotation_difference((E2-S2).normalized()).to_matrix().to_4x4()
    R2=(W-E).normalized().rotation_difference((W2-E2).normalized()).to_matrix().to_4x4()
    return Tm(S2)@R1@Tm(-S),Tm(E2)@R2@Tm(-E)
def blend_bone(n,A_,B_,w):
    la,qa,sa=(A_@rest[n]).decompose(); lb,qb,sb=(B_@rest[n]).decompose()
    if qa.dot(qb)<0: qb.negate()
    return Matrix.LocRotScale(la.lerp(lb,w),qa.slerp(qb,w),sa.lerp(sb,w))@rest[n].inverted()
def outer(a): return Matrix(((a.x*a.x,a.x*a.y,a.x*a.z),(a.y*a.x,a.y*a.y,a.y*a.z),(a.z*a.x,a.z*a.y,a.z*a.z)))
def string_half(tip,Dh,nock_w):
    # Hinge at the bow tip (riding the bow), rotate toward the nock point and stretch along the half's length.
    tip_w=Dh@tip; a0=NOCK-tip; L0=a0.length; a0n=a0.normalized(); v=nock_w-tip_w; s_=max(v.length/L0,1e-3)
    Rh=Dh.to_3x3().normalized()
    R_=(Rh@a0n).rotation_difference(v.normalized()).to_matrix()@Rh
    M=(R_@(Matrix.Identity(3)+outer(a0n)*(s_-1))).to_4x4()
    return Tm(tip_w)@M@Tm(-tip)
ARR_DIR=(ARR_T-ARR_N).normalized()
def arrow_at(nock_w,dir_w,scale=1.0):
    M=ARR_DIR.rotation_difference(Vector(dir_w).normalized()).to_matrix().to_4x4()
    if scale!=1.0: M=M@Matrix.Scale(scale,4)
    return Tm(nock_w)@M@Tm(-ARR_N)
GRr=avg(verts('Hand_r')); GB_=avg(verts('BowGrip'))
REST_PT=ARR_N+ARR_DIR*(ARR_N.y-GB_.y)                 # where the arrow crosses the stave (arrow rest)
AOFF=ARR_N-NOCK                                       # arrow nock sits beside the string nock (left of the stave)
Q_REST=top4('Arrows')+Vector((0,0,.02))               # top of the quiver arrows (rides the chest)
POLE_L=(.2,0,-1); POLE_R=(-1,.2,.15)                  # chest space: bow elbow down; draw elbow to the body's right = BACK in a side-on stance
def right_fist_to(D,X,pole):
    W=X-(GRr-J['WR_r'])
    for _ in range(3):
        up,fo=arm_ik('r',D['chest'],W,pole); W=X-fo.to_3x3()@(GRr-J['WR_r'])
    return arm_ik('r',D['chest'],W,pole)
def interp(table,f,ev):
    ks=sorted(table); lo=max(k for k in ks if k<=f); hi=min(k for k in ks if k>=f)
    if lo==hi: return ev(table[lo])
    t_=smooth((f-lo)/(hi-lo)); a_,b_=ev(table[lo]),ev(table[hi])
    return [x+(y-x)*t_ for x,y in zip(a_,b_)] if isinstance(a_,(list,tuple)) else a_.lerp(b_,t_)
def shot(name,nla_start,desc,BOW,BODY,HAND,ANCHOR,T):
    """One draw-and-loose clip. SIDE-ON STANCE (user: the first version was all contorted — only the trunk
    turned while hips and legs faced front): the WHOLE body pivots (yaw, feet included) so the left shoulder
    points at the target (-Y); the trunk adds almost nothing and only the head turns back to aim. Nocking
    happens with the bow CLOSE to the body (the side-on draw shoulder cannot reach an extended bow); the bow
    is pushed out only while the string is drawn (push-pull).
    BOW: frame -> bow grip (world) or None (rest). BODY: frame -> (yaw, chest twist, head turn, head tilt,
    lean (chest pitch, <0 = back), crouch dz). HAND: frame -> right fist target spec. T: timing."""
    E=T['end']; NK,RL,QV,ND=T['nock'],T['release'],T['quiver'],T['nocked']
    new_action(name,E,False,nla_start,desc)
    def ik_weight(f): return smooth((f-1)/4) if f<5 else (1.0 if f<=E-5 else smooth((E-f)/5))
    release=None
    for f in range(1,E+1):
        yaw,chest,hturn,htilt,lean,dz=interp(BODY,f,lambda v:v)
        # Feet pivot with the body (rotate about the origin); a foot lifts a little while turning.
        Rz_=qz(yaw); a0,a1=T['turn_in']; b0,b1=T['turn_out']
        tin=a0<=f<=a1; tout=b0<=f<=b1
        fl_=Rz_@J['AN_l']+Vector((0,0,.035*math.sin(math.pi*(f-a0)/(a1-a0)) if tin else 0))
        fr_=Rz_@J['AN_r']+Vector((0,0,.035*math.sin(math.pi*(f-b0)/(b1-b0)) if tout else 0))
        D=pose(off=(0,0,dz),hips_q=qz(yaw),chest_q=qz(chest)@qx(lean),head_q=qz(hturn)@qx(htilt),feet=(fl_,fr_),feet_q=(Rz_,Rz_))
        w=ik_weight(f)
        grip=interp(BOW,f,lambda v:Vector(GB_) if v is None else Vector(v))
        sway=T['aim'](f)                                    # aiming tremor / breathing (world offset)
        grip=grip+sway
        Hl=Tm(grip-GB_)                                     # bow stays upright: the bow hand only translates
        upl,fol=arm_ik('l',D['chest'],Hl@J['WR_l'],POLE_L)
        nock_w=Hl@NOCK
        def ev_hand(spec):
            k=spec[0]
            if k=='rest': return D['forearm_r']@GRr
            if k=='nock': return nock_w
            if k=='anchor': return Vector(ANCHOR)+sway*.5
            if k=='quiver': return D['chest']@Q_REST
            return Vector(spec[1])
        fist=interp(HAND,f,ev_hand)
        upr,for_=right_fist_to(D,fist,POLE_R)
        IK={'upper_arm_l':upl,'forearm_l':fol,'hand_l':Hl,'upper_arm_r':upr,'forearm_r':for_,'hand_r':for_}
        for n,M in IK.items(): D[n]=M if w>=1 else blend_bone(n,D[n],M,w)
        Dh=D['hand_l']; nock_rest_w=Dh@NOCK; fist_w=D['forearm_r']@GRr
        # String: straight -> held by the fist (nock..release-1) -> snaps on release with a vibration.
        if NK<=f<RL: sn=fist_w
        elif f in T['vib']: sn=nock_rest_w+Vector((0,T['vib'][f],0))
        else: sn=nock_rest_w
        D['string_u']=string_half(TIPU,Dh,sn); D['string_d']=string_half(TIPD,Dh,sn)
        # Arrow: nocked -> on the string while drawing -> flies on release -> hidden -> new one from the quiver -> nocked.
        if f<NK or f>=ND: D['arrow']=Dh
        elif f<RL:
            an=fist_w+AOFF; rp=Dh@REST_PT; D['arrow']=arrow_at(an,rp-an)
            release=(an.copy(),(rp-an).normalized())
        elif f in T['flight']:
            n0,d0=release; D['arrow']=arrow_at(n0+d0*T['flight'][f],d0)
        elif f<QV: D['arrow']=arrow_at(D['chest']@Q_REST,Vector((0,0,1)),1e-3)
        else:
            u_=(f-QV)/(ND-QV); dir_=Vector((0,0,1)).lerp(ARR_DIR,smooth(u_)).normalized()
            D['arrow']=arrow_at(fist_w+AOFF,dir_,1e-3 if f==QV else 1.0)
        bake(f,D)

# Basic Attack: quick shot, level aim (full draw 18, loose 27).
shot('Archer_Attack',141,'Ranged shot: takes the string at the nock, the whole body pivots side-on, pushes the bow out and draws to the cheek (full draw 18), aims, looses (27: string snaps, arrow flies), takes a new arrow from the quiver, nocks it, settles back.',
     BOW={1:None, 6:(.02,-.32,1.18), 10:(-.10,-.30,1.26), 18:(-.14,-.66,1.51), 26:(-.14,-.66,1.51), 28:(-.14,-.69,1.50),
          36:(-.08,-.40,1.30), 42:(-.02,-.32,1.18), 49:None},
     BODY={1:(0,0,0,0,0,0), 6:(-30,-2,25,0,0,0), 10:(-70,-4,62,2,0,0), 18:(-75,-5,70,4,0,0), 26:(-75,-5,70,4,0,0), 30:(-75,-5,70,3,0,0),
           36:(-70,-4,60,0,0,0), 42:(-30,-2,25,0,0,0), 49:(0,0,0,0,0,0)},
     HAND={1:('rest',), 6:('nock',), 10:('nock',), 18:('anchor',), 26:('anchor',), 29:('pt',(-.18,.02,1.55)), 31:('pt',(-.18,.02,1.55)),
           36:('quiver',), 42:('nock',), 49:('rest',)},
     ANCHOR=Vector((-.18,-.08,1.52)),                     # beside the right cheek; arrow line above the bow arm
     T={'end':49,'nock':6,'release':27,'quiver':36,'nocked':42,'turn_in':(2,9),'turn_out':(42,48),
        'vib':{27:-.05,28:.02,29:-.008},'flight':{27:.5,28:1.3,29:2.4},
        'aim':lambda f: Vector((.003*math.sin(f*3.1),0,.003*math.cos(f*2.3))) if f in (26,27) else Vector()})

# Precise Shot (Disparo Preciso: x1.40 Attack, +1 range): slower and deliberate — lower wider stance leaning
# back a little, the bow raised AIMING UP (~14 deg, the longer range), the string drawn to the ear, a long hold
# with slow breathing whose tremor settles, then a stronger loose: bigger string vibration, the arrow leaves
# faster on a rising line, the bow kicks forward/down and the draw hand flies back past the ear.
def precise_aim(f):
    if 22<=f<=34:
        s=(f-22)/12; amp=.006*(1-s)+.0015                          # tremor fades as he steadies
        return Vector((amp*math.sin(f*2.7),0,amp*math.cos(f*1.9)+.008*math.sin(math.pi*s)))   # + one slow breath
    return Vector()
shot('Archer_PreciseShot',201,'Disparo Preciso: lower stance leaning back, the bow raised aiming up (longer range), draws to the ear (full draw 22), long steadying aim, strong loose (35: big string vibration, arrow flies fast on a rising line, bow kicks, draw hand flies back), reloads from the quiver, settles back.',
     BOW={1:None, 6:(.02,-.32,1.18), 11:(-.10,-.30,1.30), 22:(-.12,-.60,1.63), 34:(-.12,-.60,1.63), 36:(-.12,-.645,1.59),
          38:(-.11,-.62,1.58), 45:(-.08,-.40,1.30), 51:(-.02,-.32,1.18), 57:None},
     BODY={1:(0,0,0,0,0,0), 6:(-30,-2,25,0,0,0), 11:(-75,-4,64,0,-2,-.02), 22:(-80,-5,72,-6,-7,-.04), 34:(-80,-5,72,-6,-7,-.04),
           38:(-80,-5,70,-4,-5,-.04), 45:(-70,-4,60,0,0,-.01), 51:(-30,-2,25,0,0,0), 57:(0,0,0,0,0,0)},
     HAND={1:('rest',), 6:('nock',), 11:('nock',), 22:('anchor',), 34:('anchor',), 37:('pt',(-.21,.10,1.60)), 39:('pt',(-.21,.10,1.60)),
           45:('quiver',), 51:('nock',), 57:('rest',)},
     ANCHOR=Vector((-.20,-.03,1.56)),                     # deeper draw: to the ear
     T={'end':57,'nock':6,'release':35,'quiver':45,'nocked':51,'turn_in':(2,10),'turn_out':(51,56),
        'vib':{35:-.07,36:.035,37:-.018,38:.008},'flight':{35:.8,36:2.0,37:3.4},
        'aim':precise_aim})

MARKERS={'Archer_Idle':[('LOOP_START',1),('LOOP_END',73)],'Archer_Walk':[('LOOP_START',1),('LOOP_END',29)],
         'Archer_Attack':[('START',1),('NOCK',6),('FULL_DRAW',18),('RELEASE',27),('RELOAD',36),('NOCKED',42),('RECOVERED',49)],
         'Archer_PreciseShot':[('START',1),('NOCK',6),('FULL_DRAW',22),('STEADY',34),('RELEASE',35),('RELOAD',45),('NOCKED',51),('RECOVERED',57)]}

for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    for label,fr in MARKERS[n]: a.pose_markers.new(label).frame=fr
clips['Archer_Attack']['impact_frame']=27; clips['Archer_PreciseShot']['impact_frame']=35   # the arrow leaves the bow
clips['Archer_Walk']['speed_m_s']=STRIDE/(CYCLE/24)
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=257; scene.frame_set(1)

def close(A,B,tol=2e-4): return all(abs(A[r][c]-B[r][c])<tol for r in range(4) for c in range(4))
chk=[]
idle=stats['Archer_Idle']['poses']; walk=stats['Archer_Walk']['poses']; atk=stats['Archer_Attack']['poses']; ps=stats['Archer_PreciseShot']['poses']
if not all(close(idle[1][n],idle[73][n]) for n in ORDER): chk.append('idle loop not closed')
if not all(close(walk[1][n],walk[29][n]) for n in ORDER): chk.append('walk loop not closed')
if not all(close(atk[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('attack does not start at the idle base')
if not all(close(atk[49][n],atk[1][n]) for n in ORDER): chk.append('attack does not end where it starts')
if not all(close(ps[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('precise shot does not start at the idle base')
if not all(close(ps[57][n],ps[1][n]) for n in ORDER): chk.append('precise shot does not end where it starts')
for clip,s in stats.items():
    if s['min_z']<-.01: chk.append('%s goes below the ground (%.3f)'%(clip,s['min_z']))
summary={}
for pr in problems: summary.setdefault(pr[0]+':'+pr[1],0); summary[pr[0]+':'+pr[1]]+=1
validation={'problems':chk,'ik':summary,'min_z':{k:round(v['min_z'],4) for k,v in stats.items()}}
st.update({'scene':scene,'parts':parts,'rig':rig,'clips':clips,'source':str(source),'root':root,'animation_validation':validation,
           'material':bpy.data.materials[NAME+'_PixelArt']})
result={'bones':len(arm.bones),'validation':validation,'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
