"""Rigid-bone rig + baked Idle / Walk / Attack for the live Ancient Golem V2 (gorilla
knuckle-walking stance), via Blender MCP.
Every bone pose is computed as a rigid delta D (world transform of its parts) and written
with pose_bone.matrix = D @ rest, parent-first, then keyed. Fists and feet are placed by
an analytic two-bone IK (shoulder-elbow-wrist / hip-knee-ankle) that keeps the rest bend
plane (no twist), so planted fists and feet stay flat and fixed on the ground.
- Golem_Idle (72 f, loop): heavy breathing through the chest, small body sway, slow look
  around, fists and feet planted.
- Golem_Walk (32 f, loop, in place): gorilla knuckle-walk, diagonal pairs (left fist +
  right foot, then right fist + left foot), crouched body with bob, chest yaw towards the
  reaching arm; planted limbs slide back at the walk speed.
- Golem_Attack (40 f): rears up with both fists raised over the head, roars, then lunges
  and hammers both fists into the ground ahead (impact frame 20), recovers.
REBAKE=True rebuilds an existing rig/actions.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

NAME='Ancient_Golem_V2'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
root=bpy.data.objects[NAME+'_ROOT']
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\ancient_golem_v2')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
CLIPS=('Golem_Idle','Golem_Walk','Golem_Attack')
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
else:
    bpy.data.libraries.write(str(source/'ancient_golem_v2_static.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for n in CLIPS:
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
for m in list(scene.timeline_markers):
    if m.name.startswith('Golem_'): scene.timeline_markers.remove(m)

def part(n): return bpy.data.objects[NAME+'_'+n]
def avg(pts): return sum(pts,Vector())/len(pts)
def ends(n,top=True):
    vs=sorted([v.co.copy() for v in part(n).data.vertices],key=lambda v:v.z); return avg(vs[-4:] if top else vs[:4])
# Joints measured on the live meshes.
HIP=Vector((0,.12,1.10))
NECK=Vector((0,-.718,1.356))
jaw_top=sorted([v.co.copy() for v in part('Jaw').data.vertices],key=lambda v:v.z)[-4:]
HINGE=avg(sorted(jaw_top,key=lambda v:v.y)[-2:])
J={}
for s,tag in ((1,'l'),(-1,'r')):
    J['S_'+tag]=Vector((s*.92,-.46,1.78)); J['E_'+tag]=Vector((s*1.02,-1.06,1.10)); J['W_'+tag]=Vector((s*1.04,-1.30,.52))
    J['F_'+tag]=Vector((s*1.04,-1.40,.26))
    T=tag.upper(); J['H_'+tag]=ends('Thigh_'+T,True); J['K_'+tag]=(ends('Thigh_'+T,False)+ends('Shin_'+T,True))/2
    J['A_'+tag]=Vector((s*.42,.06,.14))

# Armature: one bone per rigid group.
bones={'root':((0,0,0),(0,0,.3),None),'hips':(HIP,HIP+Vector((0,0,.3)),'root'),'chest':(HIP,Vector((0,-.40,1.70)),'hips'),
       'head':(NECK,Vector((0,-.97,1.62)),'chest'),'jaw':(HINGE,HINGE+Vector((0,-.3,0)),'head')}
for t in ('l','r'):
    bones['upper_arm_'+t]=(J['S_'+t],J['E_'+t],'chest'); bones['forearm_'+t]=(J['E_'+t],J['W_'+t],'upper_arm_'+t)
    bones['fist_'+t]=(J['W_'+t],J['F_'+t],'forearm_'+t)
    bones['thigh_'+t]=(J['H_'+t],J['K_'+t],'hips'); bones['shin_'+t]=(J['K_'+t],J['A_'+t],'thigh_'+t)
    bones['foot_'+t]=(J['A_'+t],J['A_'+t]+Vector((0,-.25,0)),'shin_'+t)
part_bone={'Pelvis':'hips','Torso':'chest','Pauldron_L':'chest','Pauldron_R':'chest','Head':'head','Brow':'head',
           'Eye_L':'head','Eye_R':'head','Jaw':'jaw'}
for T in ('L','R'):
    t=T.lower(); part_bone.update({'UpperArm_'+T:'upper_arm_'+t,'Gauntlet_'+T:'forearm_'+t,'Fist_'+T:'fist_'+t,
                                   'Thigh_'+T:'thigh_'+t,'Shin_'+T:'shin_'+t,'Foot_'+T:'foot_'+t})
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm)
bpy.data.collections[NAME+'_01_BODY'].objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t_,p) in bones.items():
    b=arm.edit_bones.new(n); b.head=h; b.tail=t_; b.roll=0
    if p: b.parent=arm.edit_bones[p]; b.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT'); arm.display_type='STICK'
for o in parts:
    b=part_bone[o['part']]; o['rig_bone']=b
    o.vertex_groups.new(name=b).add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    mod=o.modifiers.new('Rigid_Golem_Parts','ARMATURE'); mod.object=rig; o.parent=rig
rig['notes']='Rigid one-bone-per-part rig; fists and feet driven by baked two-bone IK.'
rest={b.name:b.matrix_local.copy() for b in arm.bones}
depth={}
for b in arm.bones:
    d=0; q=b
    while q.parent: d+=1; q=q.parent
    depth[b.name]=d
order=sorted(rest,key=lambda n:depth[n])

def Tm(v): return Matrix.Translation(Vector(v))
def about(p,q): return Tm(p)@q.to_matrix().to_4x4()@Tm(-Vector(p))
def qx(d): return Quaternion((1,0,0),math.radians(d))
def qy(d): return Quaternion((0,1,0),math.radians(d))
def qz(d): return Quaternion((0,0,1),math.radians(d))
def frame(u,pole):
    u=u.normalized(); v=(pole-u*pole.dot(u)).normalized(); w=u.cross(v); return Matrix((u,v,w)).transposed()
problems=[]; CUR=['']
def two_bone(A,B,C,A2,C2,R_parent,label):
    # Rest chain A-B-C, new root A2 and end C2; bend plane = rest plane carried by R_parent.
    l1=(B-A).length; l2=(C-B).length; d=(C2-A2).length
    if d>(l1+l2)*.999: problems.append(('reach',CUR[0],label,round(d,3),round(l1+l2,3))); d=(l1+l2)*.999
    pole_rest=(B-A)-(C-A).normalized()*(B-A).dot((C-A).normalized())
    pole=R_parent@pole_rest; u=(C2-A2).normalized()
    pole=(pole-u*pole.dot(u)).normalized()
    a=math.acos(max(-1,min(1,(l1*l1+d*d-l2*l2)/(2*l1*d))))
    B2=A2+u*math.cos(a)*l1+pole*math.sin(a)*l1
    pr=pole_rest
    R1=frame(B2-A2,R_parent@pr)@frame(B-A,pr).transposed()
    R2=frame(C2-B2,R_parent@pr)@frame(C-B,pr).transposed()
    return Tm(A2)@R1.to_4x4()@Tm(-A),Tm(B2)@R2.to_4x4()@Tm(-B),R2
def pose(f,body_off=(0,0,0),body_q=Quaternion(),chest_q=Quaternion(),head_q=Quaternion(),jaw_deg=0.0,fists=None,fist_w=(1,1),feet=None,feet_q=None):
    D={'root':Matrix.Identity(4)}
    D['hips']=Tm(body_off)@about(HIP,body_q)
    D['chest']=D['hips']@about(HIP,chest_q)
    D['head']=D['chest']@about(NECK,head_q)
    D['jaw']=D['head']@about(HINGE,qx(jaw_deg))
    for i,t in enumerate(('l','r')):
        S2=D['chest']@J['S_'+t]; F2=Vector(fists[i]) if fists else J['F_'+t]
        W2=F2-(J['F_'+t]-J['W_'+t])
        D['upper_arm_'+t],D['forearm_'+t],R2=two_bone(J['S_'+t],J['E_'+t],J['W_'+t],S2,W2,D['chest'].to_3x3(),'arm_'+t+'@%d'%f)
        rq=R2.to_quaternion().slerp(Quaternion(),fist_w[i])
        D['fist_'+t]=Tm(W2)@rq.to_matrix().to_4x4()@Tm(-J['W_'+t])
        H2=D['hips']@J['H_'+t]; A2=Vector(feet[i]) if feet else J['A_'+t]
        D['thigh_'+t],D['shin_'+t],_=two_bone(J['H_'+t],J['K_'+t],J['A_'+t],H2,A2,D['hips'].to_3x3(),'leg_'+t+'@%d'%f)
        fq=feet_q[i] if feet_q else Quaternion()
        D['foot_'+t]=Tm(A2)@fq.to_matrix().to_4x4()@Tm(-J['A_'+t])
    level=None
    for n in order:
        if level is not None and depth[n]!=level: bpy.context.view_layer.update()
        level=depth[n]; rig.pose.bones[n].matrix=D[n]@rest[n]
    bpy.context.view_layer.update()
previous={}
def key(f):
    for b in rig.pose.bones:
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion)<0: b.rotation_quaternion.negate()
        previous[b.name]=b.rotation_quaternion.copy()
        b.keyframe_insert(data_path='location',frame=f,group=b.name); b.keyframe_insert(data_path='rotation_quaternion',frame=f,group=b.name)
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
rig.animation_data_create(); clips={}
def new_action(n,end,loop,start,desc):
    a=bpy.data.actions.new(n); a.use_fake_user=True; rig.animation_data.action=a; previous.clear(); CUR[0]=n
    clips[n]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':start,'description':desc}
def smooth(t): t=max(0,min(1,t)); return t*t*(3-2*t)
FL,FR=J['F_l'],J['F_r']; AL,AR=J['A_l'],J['A_r']

# Idle: breathing, sway, look around; everything planted.
new_action('Golem_Idle',73,True,1,'Heavy breathing through the chest, small sway, slow look around; fists and feet planted.')
for f in range(1,74):
    p=math.tau*(f-1)/72; br=(1-math.cos(p))/2
    pose(f,body_off=(0,0,-.025*br),body_q=qy(1.2*math.sin(p)),chest_q=qx(2.0*br),
         head_q=qz(7*math.sin(p))@qx(-3*math.sin(2*p)),jaw_deg=2*br)
    key(f)

# Walk: gorilla knuckle-walk in place, diagonal pairs.
CYCLE=32; STRIDE_ARM=.38; STRIDE_LEG=.40; DUTY=.62; SPEED=STRIDE_LEG/(CYCLE/24)
def limb(phase,base,stride,lift,shift=0.0):
    phase%=1.0; y0=base.y+shift
    if phase<DUTY: y=y0-stride/2+stride*(phase/DUTY); z=base.z
    else:
        s=(phase-DUTY)/(1-DUTY); y=y0+stride/2-stride*smooth(s); z=base.z+lift*math.sin(math.pi*s)
    return Vector((base.x,y,z)),(phase>=DUTY)
new_action('Golem_Walk',33,True,91,'Gorilla knuckle-walk in place: diagonal pairs, crouched body bob, chest yaw towards the reaching arm.')
for f in range(1,34):
    ph=(f-1)/CYCLE; p=math.tau*ph
    fl,_=limb(ph,FL,STRIDE_ARM,.22,.18); fr,_=limb(ph+.5,FR,STRIDE_ARM,.22,.18)
    al,swl=limb(ph+.5,AL,STRIDE_LEG,.16); ar,swr=limb(ph,AR,STRIDE_LEG,.16)
    fq=[qx(-14*math.sin(math.pi*((x-DUTY)/(1-DUTY)))) if sw else Quaternion() for x,sw in (((ph+.5)%1,swl),((ph)%1,swr))]
    pose(f,body_off=(0,0,-.11-.03*math.cos(2*p)),body_q=qy(2.5*math.sin(p)),chest_q=qz(-6*math.cos(p))@qx(2),
         head_q=qz(4*math.cos(p))@qx(-2),jaw_deg=0,fists=(fl,fr),feet=(al,ar),feet_q=fq)
    key(f)

# Attack: rear up, fists overhead, roar, hammer the ground ahead.
new_action('Golem_Attack',41,False,141,'Rears up with both fists overhead and roars, then lunges and hammers both fists into the ground ahead (impact 20), recovers.')
K={1:((0,0,0),0,0,0,(-1.40,.26,1.04),1),
   6:((0,.04,0),-10,-6,6,(-1.20,.70,.98),.5),
   12:((0,.06,0),-28,-16,18,(-.66,2.40,.62),0),
   16:((0,.05,0),-30,-18,20,(-.60,2.50,.60),0),
   20:((0,-.30,-.05),12,4,10,(-1.62,.26,.90),1),
   24:((0,-.32,-.07),14,6,6,(-1.62,.26,.90),1),
   32:((0,-.12,-.03),6,2,2,(-1.48,.26,1.00),1),
   41:((0,0,0),0,0,0,(-1.40,.26,1.04),1)}
keys=sorted(K)
for f in range(1,42):
    lo=max(k for k in keys if k<=f); hi=min(k for k in keys if k>=f)
    t=0 if lo==hi else smooth((f-lo)/(hi-lo))
    a,b=K[lo],K[hi]
    lerp=lambda x,y:x+(y-x)*t
    off=tuple(lerp(x,y) for x,y in zip(a[0],b[0])); cp=lerp(a[1],b[1]); hp=lerp(a[2],b[2]); jw=lerp(a[3],b[3])
    fy,fz,fx=(lerp(x,y) for x,y in zip(a[4],b[4])); w=lerp(a[5],b[5])
    pose(f,body_off=off,chest_q=qx(cp),head_q=qx(hp),jaw_deg=jw,fists=((fx,fy,fz),(-fx,fy,fz)),fist_w=(w,w))
    key(f)

for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    events=[('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else [('START',1),('WINDUP',12),('IMPACT',20),('RECOVERED',41)]
    for label,fr in events: a.pose_markers.new(label).frame=fr
clips['Golem_Attack']['impact_frame']=20
clips['Golem_Walk']['speed_m_s']=SPEED
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=181; scene.frame_set(1)
mat=bpy.data.materials[NAME+'_PixelArt']
bpy.app.driver_namespace['ancient_golem'].update({'scene':scene,'parts':parts,'rig':rig,'clips':clips,'source':str(source),'material':mat,'root':root})
summary={}
for pr in problems: summary.setdefault(pr[1]+':'+pr[2].split('@')[0],[]).append(round(pr[3]-pr[4],4))
result={'bones':len(arm.bones),'ik_problems':{k:{'frames':len(v),'max_excess':max(v)} for k,v in summary.items()},
        'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
