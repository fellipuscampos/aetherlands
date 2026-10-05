"""Rigid-bone rig + baked clips for the live GriffonRider V1 (Cavaleiro de Grifo, legendary), via Blender MCP. A copy of
the Armored Cavalier (same horse + rider rig, 28 bones) with the whole mount scaled up by 2.00/1.80, so this is
armored_cavalier_animate.py with the GriffonRider names and every ABSOLUTE distance of the clips (neck and rearing
pivots, body offsets and bounce, the lance grip path of the Attack and the Charge) scaled by S (measured on the horse
body) — the poses keep their proportions. Clips: Idle (72 f, loop), Walk (18 f gallop, loop), Attack (half-rear +
lunge and lance thrust, impact 15) and Charge (Carga / Investida: arrival mid-gallop, lance couched, braking hit at
frame 11). Ground clamp on the hooves. REBAKE=True rebuilds.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

NAME='GriffonRider_V1'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
st=bpy.app.driver_namespace['griffon_rider']
root=bpy.data.objects[NAME+'_ROOT']
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\griffon_rider_v1')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
CLIPS=('GriffonRider_Idle','GriffonRider_Walk','GriffonRider_Attack','GriffonRider_Charge')
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
else:
    bpy.data.libraries.write(str(source/'griffon_rider_v1_static.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for n in CLIPS:
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
for m in list(scene.timeline_markers):
    if m.name.startswith('GriffonRider_'): scene.timeline_markers.remove(m)

def P(n): return bpy.data.objects[NAME+'_'+n]
def verts(n): return [v.co.copy() for v in P(n).data.vertices]
def avg(vs): return sum(vs,Vector())/len(vs)
def top4(n): return avg(sorted(verts(n),key=lambda v:v.z)[-4:])
def bot4(n): return avg(sorted(verts(n),key=lambda v:v.z)[:4])
def first4(n): return avg(verts(n)[:4])
def last4(n): return avg(verts(n)[4:])

# ---------------- joints ----------------
# The mount is scaled up (2.00/1.80): every ABSOLUTE distance of the clips is scaled by S, measured on the horse body.
S=avg(verts('HorseBody')).z/1.10
NECK_TILT=math.radians(32.0); NP=Vector((0,-.50,1.20))*S
NB=Vector((0,math.cos(NECK_TILT),math.sin(NECK_TILT))); NC=Vector((0,-math.sin(NECK_TILT),math.cos(NECK_TILT)))
LEGS=('fl','fr','bl','br')
J={'BODY':avg(verts('HorseBody')),'NECK':NP.copy(),'HEADJ':NP+NC*.58*S,'TAIL':top4('HorseTail'),
   'REAR':Vector((0,.42,.86))*S}                                        # rearing pivot: the hind hip line
for n in LEGS: J['HIP_'+n]=top4('HorseThigh_'+n); J['KNEE_'+n]=top4('HorseCannon_'+n)
J['HIPC']=avg(verts('Pelvis')); J['WAIST']=top4('Pelvis'); J['NECKR']=bot4('Head')
for t in ('l','r'):
    J['SH_'+t]=first4('UpperArm_'+t)+Vector((0,0,.03)); J['EL_'+t]=last4('UpperArm_'+t); J['WR_'+t]=last4('Forearm_'+t)
    J['HJ_'+t]=first4('Thigh_'+t); J['KN_'+t]=first4('Shin_'+t); J['AN_'+t]=last4('Shin_'+t)

override={'Shoulder_l':'chest','Shoulder_r':'chest'}
for t in ('l','r'):
    override['Rein_'+t+'1']='horse_head'; override['Rein_'+t+'2']='horse_neck'; override['Rein_'+t+'3']='hand_l'
part_bone={o['part']:override.get(o['part'],o['rig_bone']) for o in parts}
up=Vector((0,0,.25))
bones={'root':(Vector((0,0,0)),Vector((0,0,.3))),
       'horse_body':(J['BODY'],J['BODY']+Vector((0,-.4,0))),'horse_neck':(J['NECK'],J['NECK']+NC*.5),
       'horse_head':(J['HEADJ'],J['HEADJ']-NB*.4),'horse_tail':(J['TAIL'],J['TAIL']-up)}
for n in LEGS:
    bones['horse_thigh_'+n]=(J['HIP_'+n],J['KNEE_'+n]); bones['horse_cannon_'+n]=(J['KNEE_'+n],J['KNEE_'+n]-Vector((0,0,.40)))
bones['hips']=(J['HIPC'],J['HIPC']+Vector((0,0,.2))); bones['chest']=(J['WAIST'],J['NECKR']); bones['head']=(J['NECKR'],J['NECKR']+Vector((0,0,.3)))
for t in ('l','r'):
    bones['upper_arm_'+t]=(J['SH_'+t],J['EL_'+t]); bones['forearm_'+t]=(J['EL_'+t],J['WR_'+t])
    bones['hand_'+t]=(J['WR_'+t],J['WR_'+t]+(J['WR_'+t]-J['EL_'+t]).normalized()*.12)
    bones['thigh_'+t]=(J['HJ_'+t],J['KN_'+t]); bones['shin_'+t]=(J['KN_'+t],J['AN_'+t]); bones['foot_'+t]=(J['AN_'+t],J['AN_'+t]+Vector((0,-.15,0)))
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
    mod=o.modifiers.new('Rigid_GriffonRider_Parts','ARMATURE'); mod.object=rig; o.parent=rig
rig['notes']='Flat rigid rig: horse bones (body/neck/head/tail/thigh/cannon) + the rider (human troop bones) riding the horse body.'
rest={b.name:b.matrix_local.copy() for b in arm.bones}
ORDER=list(bones)

def Tm(v): return Matrix.Translation(Vector(v))
def about(p,q): return Tm(p)@q.to_matrix().to_4x4()@Tm(-Vector(p))
def qx(d): return Quaternion((1,0,0),math.radians(d))
def qy(d): return Quaternion((0,1,0),math.radians(d))
def qz(d): return Quaternion((0,0,1),math.radians(d))
I4=Matrix.Identity(4); QI=Quaternion()

def pose(off=(0,0,0),pitch=0.0,pitch_pivot=None,neck=0.0,head=0.0,tail=(0.0,0.0),legs=None,
         r_off=(0,0,0),hips_q=QI,chest_q=QI,head_q=QI,arm_r=(0,0,0),arm_l=(0,0,0)):
    """Horse (positive pitch = nose down; positive thigh = leg swings BACK; positive cannon = folds back) and the
    rider composed on the horse body."""
    D={'root':I4.copy()}
    D['horse_body']=Tm(Vector(off)*S)@about(pitch_pivot if pitch_pivot is not None else J['BODY'],qx(pitch))
    D['horse_neck']=D['horse_body']@about(J['NECK'],qx(neck))
    D['horse_head']=D['horse_neck']@about(J['HEADJ'],qx(head))
    D['horse_tail']=D['horse_body']@about(J['TAIL'],qx(tail[0])@qy(tail[1]))
    for n in LEGS:
        th,cn=(legs or {}).get(n,(0.0,0.0))
        D['horse_thigh_'+n]=D['horse_body']@about(J['HIP_'+n],qx(th))
        D['horse_cannon_'+n]=D['horse_thigh_'+n]@about(J['KNEE_'+n],qx(cn))
    base=D['horse_body']@Tm(Vector(r_off)*S)
    D['hips']=base@about(J['HIPC'],hips_q)
    D['chest']=D['hips']@about(J['WAIST'],chest_q)
    D['head']=D['chest']@about(J['NECKR'],head_q)
    for t,a in (('r',arm_r),('l',arm_l)):
        D['upper_arm_'+t]=D['chest']@about(J['SH_'+t],qx(a[0]))
        D['forearm_'+t]=D['upper_arm_'+t]@about(J['EL_'+t],qx(a[1]))
        D['hand_'+t]=D['forearm_'+t]@about(J['WR_'+t],qx(a[2]))
        for b in ('thigh_','shin_','foot_'): D[b+t]=D['hips']            # seated: legs ride the hips
    return D

HOOVES=[(P('HorseHoof_'+n),'horse_cannon_'+n) for n in LEGS]
HOOF_V={n:[v.co.copy() for v in o.data.vertices] for o,n in HOOVES}
def ground_clamp(D):
    low=min((D[b]@v).z for b,vs in HOOF_V.items() for v in vs)
    if low<0:
        L=Tm((0,0,-low))
        for n in ORDER: D[n]=L@D[n]
    return D

for b in rig.pose.bones: b.rotation_mode='QUATERNION'
previous={}; clips={}; stats={}; problems=[]; CUR=['']
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

# ---------------- Idle: every term is zero at frame 1 (the shared BASE) ----------------
new_action('GriffonRider_Idle',73,True,1,'The horse breathes, nods and swishes its tail; the rider breathes and looks around.')
for f in range(1,74):
    p=math.tau*(f-1)/72; br=(1-math.cos(2*p))/2
    D=pose(off=(0,0,.006*br),pitch=.4*math.sin(p),neck=2.5*math.sin(p),head=3.5*math.sin(p),
           tail=(3*(1-math.cos(p))/2,7*math.sin(2*p)),
           legs={'fl':(1.5*math.sin(p),0.0),'fr':(-1.5*math.sin(p),0.0)},
           chest_q=qx(1.5*br-.4*math.sin(p)),head_q=qz(9*math.sin(p))@qx(-1.5*br),
           arm_r=(-2*br,1.5*math.sin(2*p),0),arm_l=(-2.5*math.sin(p),0,0))
    bake(f,ground_clamp(D))

# ---------------- Walk: in-place GALLOP (transverse: hind L, hind R, fore L, fore R) ----------------
CYCLE=18
PHASE={'bl':0.0,'br':.12,'fl':.50,'fr':.62}
new_action('GriffonRider_Walk',CYCLE+1,True,91,'In-place gallop: transverse leg sequence with knee folds, body rock and bounce, head bob, tail streaming; the rider keeps upright.')
for f in range(1,CYCLE+2):
    ph=(f-1)/CYCLE; g=math.tau*ph
    legs={}
    for n,phi in PHASE.items():
        a=math.tau*(ph+phi)
        legs[n]=(26*math.sin(a),58*max(0.0,-math.cos(a)))                  # knee folds while the leg swings forward
    rock=4.5*math.sin(g+.9)
    D=pose(off=(0,0,.05*(1-math.cos(g))/2),pitch=rock,neck=7*math.sin(g+.9),head=-3*math.sin(g+.9),
           tail=(32+5*math.sin(g),4*math.sin(g+1.3)),legs=legs,
           r_off=(0,0,.012*math.sin(g)),chest_q=qx(-.8*rock+4),head_q=qx(.5*rock),
           arm_r=(-2*math.sin(g),0,0),arm_l=(-3*math.sin(g+.9),2*math.sin(g+.9),0))
    bake(f,ground_clamp(D))

# ---------------- Attack: half-rear, then lunge and lance thrust (IK on the lance arm) ----------------
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
def blend_bone(n,A_,B_,w):
    la,qa,_=(A_@rest[n]).decompose(); lb,qb,_=(B_@rest[n]).decompose()
    if qa.dot(qb)<0: qb.negate()
    return Matrix.LocRotScale(la.lerp(lb,w),qa.slerp(qb,w),None)@rest[n].inverted()
lv=verts('LanceHaft'); AXW=(avg(lv[4:])-avg(lv[:4])).normalized()
GR=avg(verts('Hand_r')); PHI0=math.degrees(math.atan2(-AXW.y,AXW.z))
POLE_R=(-.8,.2,-.5)
new_action('GriffonRider_Attack',33,False,121,'Lance charge: the horse half-rears on its hind legs while the rider lifts the lance back, then lunges forward as the lance comes down and thrusts (impact 15), holds, recovers.')
#      horse: off(y,z)  pitch neck head  fore(th,cn)   hind(th,cn)   | rider: chest  grip P (rest-rider space)  phi   ease
K={1: ((0,0),          0,    0,   0,   (0,0),        (0,0),          0,  None,                  PHI0, 's'),
   9: ((.05,0),       -10,  -9,  -5,   (-38,72),     (10,0),        -6,  (-.30,.08,2.02),        -18, 's'),   # half-rear, lance lifted back
   15:((-.24,0),        5,   8,   4,   (-12,18),     (22,10),       14,  (-.24,-.48,1.84),       100, 'in'),  # LUNGE + thrust
   20:((-.25,0),        5,   7,   4,   (-12,16),     (21,10),       15,  (-.24,-.50,1.83),       101, 's'),   # hold
   33:((0,0),          0,    0,   0,   (0,0),        (0,0),          0,  None,                  PHI0, 's')}
ks=sorted(K)
def lerp(a,b,t): return a+(b-a)*t
def ik_weight(f): return smooth((f-1)/6) if f<7 else (1.0 if f<=24 else smooth((33-f)/9))
for f in range(1,34):
    lo=max(k for k in ks if k<=f); hi=min(k for k in ks if k>=f); u=0 if lo==hi else (f-lo)/(hi-lo)
    t=u*u if K[hi][9]=='in' else smooth(u)
    A,B=K[lo],K[hi]
    oy=lerp(A[0][0],B[0][0],t); pitch=lerp(A[1],B[1],t); neck=lerp(A[2],B[2],t); head=lerp(A[3],B[3],t)
    fore=(lerp(A[4][0],B[4][0],t),lerp(A[4][1],B[4][1],t)); hind=(lerp(A[5][0],B[5][0],t),lerp(A[5][1],B[5][1],t))
    hind_comp=(hind[0]-pitch,hind[1])                                   # cancel the body pitch: hind legs stay planted while it rears
    chest=lerp(A[6],B[6],t)
    D=pose(off=(0,oy,0),pitch=pitch,pitch_pivot=J['REAR'],neck=neck,head=head,tail=(10*abs(math.sin(math.pi*u)) if hi in (9,15) else 0,0),
           legs={'fl':fore,'fr':(fore[0]*.85,fore[1]*.9),'bl':hind_comp,'br':(hind_comp[0]*.9,hind_comp[1])},
           chest_q=qx(chest-.6*pitch))
    w=ik_weight(f)
    if w>0:
        PA=Vector(A[7])*S if A[7] is not None else GR; PB=Vector(B[7])*S if B[7] is not None else GR
        Pr=PA.lerp(PB,t); phi=lerp(A[8],B[8],t)
        Rl=qx(phi-PHI0).to_matrix().to_4x4()
        H=D['chest']@Tm(Pr)@Rl@Tm(-GR)                                  # the lance hand, riding the rider's chest
        upm,fo=arm_ik('r',D['chest'],H@J['WR_r'],POLE_R)
        for n,M in (('upper_arm_r',upm),('forearm_r',fo),('hand_r',H)): D[n]=M if w>=1 else blend_bone(n,D[n],M,w)
    bake(f,ground_clamp(D))

# ---------------- Charge (Carga / Investida): the arrival of a charge — the game moves the unit tile by tile (gallop)
# and THEN attacks, so this clip starts mid-gallop (blends from the run), couches the lance during the last strides,
# hits with the whole momentum (the horse brakes: forelegs braced forward, haunches dropping; the rider is thrown
# forward and drives the lance in), holds the push, lifts the lance and settles to the rest pose. ----------------
def gallop_params(ph):
    legs={}
    for n,phi in PHASE.items():
        a=math.tau*(ph+phi); legs[n]=(26*math.sin(a),58*max(0.0,-math.cos(a)))
    g=math.tau*ph; rock=4.5*math.sin(g+.9)
    return {'oy':0.0,'oz':.05*(1-math.cos(g))/2,'pitch':rock,'neck':7*math.sin(g+.9),'head':-3*math.sin(g+.9),
            'tail':(32+5*math.sin(g),4*math.sin(g+1.3)),'legs':legs,'chest':-.8*rock+4}
IMPACT={'oy':-.18,'oz':0.0,'pitch':-6.0,'neck':-6.0,'head':-4.0,'tail':(24.0,0.0),
        'legs':{'fl':(-26.0,4.0),'fr':(-22.0,6.0),'bl':(-14.0,26.0),'br':(-12.0,24.0)},'chest':16.0}
REST={'oy':0.0,'oz':0.0,'pitch':0.0,'neck':0.0,'head':0.0,'tail':(0.0,0.0),'legs':{n:(0.0,0.0) for n in LEGS},'chest':0.0}
def mix(ws):
    out={'legs':{}}
    for k in ('oy','oz','pitch','neck','head','chest'): out[k]=sum(w*p[k] for w,p in ws)
    out['tail']=tuple(sum(w*p['tail'][i] for w,p in ws) for i in range(2))
    for n in LEGS: out['legs'][n]=tuple(sum(w*p['legs'][n][i] for w,p in ws) for i in range(2))
    return out
#        grip P (rest-rider space)    phi
CH_LANCE={1:(None,PHI0), 6:((-.26,-.30,1.80),95.0), 9:((-.26,-.32,1.80),95.0), 11:((-.24,-.47,1.81),100.0),
          20:((-.24,-.48,1.81),101.0), 37:(None,PHI0)}
cks=sorted(CH_LANCE)
def ch_weight(f): return smooth((f-1)/5) if f<6 else (1.0 if f<=22 else smooth((36-f)/14))
new_action('GriffonRider_Charge',37,False,161,'Charge (Carga): starts mid-gallop with the lance coming down to couched, hits with the momentum at frame 11 (the horse brakes, the rider drives the lance in), holds the push, lifts the lance and settles to rest.')
for f in range(1,38):
    wg=1.0 if f<=6 else smooth((10-f)/4)                       # gallop fades out over the braking strides
    wi=smooth((f-6)/5) if f<=11 else (1.0 if f<=18 else smooth((34-f)/16))
    wi=min(wi,1.0-wg) if f<=11 else wi
    wr=max(0.0,1.0-wg-wi)
    S_=mix([(wg,gallop_params((f-1)/12)),(wi,IMPACT),(wr,REST)])   # a faster 12-frame stride at full speed
    if 11<=f<=14: S_['oy']+=-.03*math.sin(math.pi*(f-11)/3)    # the shove of the hit
    hind={n:(S_['legs'][n][0]-S_['pitch'],S_['legs'][n][1]) for n in ('bl','br')}
    D=pose(off=(0,S_['oy'],S_['oz']),pitch=S_['pitch'],pitch_pivot=J['REAR'],neck=S_['neck'],head=S_['head'],tail=S_['tail'],
           legs={'fl':S_['legs']['fl'],'fr':S_['legs']['fr'],'bl':hind['bl'],'br':hind['br']},chest_q=qx(S_['chest']-.6*S_['pitch']))
    w=ch_weight(f)
    if w>0:
        lo=max(k for k in cks if k<=f); hi=min(k for k in cks if k>=f); u=0 if lo==hi else (f-lo)/(hi-lo); tt=smooth(u)
        PA=Vector(CH_LANCE[lo][0])*S if CH_LANCE[lo][0] is not None else GR; PB=Vector(CH_LANCE[hi][0])*S if CH_LANCE[hi][0] is not None else GR
        Pr=PA.lerp(PB,tt); phi=lerp(CH_LANCE[lo][1],CH_LANCE[hi][1],tt)
        H=D['chest']@Tm(Pr)@qx(phi-PHI0).to_matrix().to_4x4()@Tm(-GR)
        upm,fo=arm_ik('r',D['chest'],H@J['WR_r'],POLE_R)
        for n,M in (('upper_arm_r',upm),('forearm_r',fo),('hand_r',H)): D[n]=M if w>=1 else blend_bone(n,D[n],M,w)
    bake(f,ground_clamp(D))

MARKERS={'GriffonRider_Idle':[('LOOP_START',1),('LOOP_END',73)],'GriffonRider_Walk':[('LOOP_START',1),('LOOP_END',CYCLE+1)],
         'GriffonRider_Attack':[('START',1),('REAR',9),('IMPACT',15),('RECOVERED',33)],
         'GriffonRider_Charge':[('GALLOP',1),('COUCHED',6),('IMPACT',11),('RECOVERED',37)]}
for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    for label,fr in MARKERS[n]: a.pose_markers.new(label).frame=fr
clips['GriffonRider_Attack']['impact_frame']=15; clips['GriffonRider_Charge']['impact_frame']=11
clips['GriffonRider_Walk']['speed_m_s']=2.2
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=197; scene.frame_set(1)

def close(A,B,tol=2e-4): return all(abs(A[r][c]-B[r][c])<tol for r in range(4) for c in range(4))
chk=[]
idle=stats['GriffonRider_Idle']['poses']; walk=stats['GriffonRider_Walk']['poses']; atk=stats['GriffonRider_Attack']['poses']; chg=stats['GriffonRider_Charge']['poses']
if not all(close(idle[1][n],idle[73][n]) for n in ORDER): chk.append('idle loop not closed')
if not all(close(walk[1][n],walk[CYCLE+1][n]) for n in ORDER): chk.append('walk loop not closed')
if not all(close(atk[1][n],idle[1][n],2e-3) for n in ORDER): chk.append('attack does not start at the idle base')
if not all(close(atk[33][n],atk[1][n]) for n in ORDER): chk.append('attack does not end where it starts')
if not all(close(chg[37][n],idle[1][n],2e-3) for n in ORDER): chk.append('charge does not end at the idle base')
for clip,s in stats.items():
    if s['min_z']<-.01: chk.append('%s goes below the ground (%.3f)'%(clip,s['min_z']))
summary={}
for pr in problems: summary.setdefault(pr[0]+':'+pr[1],0); summary[pr[0]+':'+pr[1]]+=1
validation={'problems':chk,'ik':summary,'min_z':{k:round(v['min_z'],4) for k,v in stats.items()}}
st.update({'scene':scene,'parts':parts,'rig':rig,'clips':clips,'source':str(source),'root':root,'animation_validation':validation,
           'material':bpy.data.materials[NAME+'_PixelArt']})
result={'bones':len(arm.bones),'validation':validation,'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
