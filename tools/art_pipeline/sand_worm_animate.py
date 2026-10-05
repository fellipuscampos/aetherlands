"""Rigid-bone rig + baked Idle / Attack / Burrow / Emerge for the live Sand Worm V1, via
Blender MCP. One bone per rigid group, all parented straight to `root` (flat), so each pose
is written as an armature-space matrix D @ rest with no inherited scale.

Every pose comes from the BODY PATH: segment i sits at body coordinate b_i (its arc along
the body from the head joint) on some rail, with a rotation-minimising frame (parallel
transport from the tail end, exactly like sand_worm_model.py). D = move rest frame -> new
frame, so the chain never separates. Parts more than ~0.5 m under the ground shrink to
scale ~0 (hidden even near water/cliffs); every clip keys location, rotation AND scale on
every bone, so crossfades in Godot stay clean.
- Worm_Idle (72 f, loop): cobra sway of the column (fore/aft + sideways), head looks
  around, antennae/claws/jaw twitch, leg wave on the raised segments; grounded legs planted.
- Worm_Attack (36 f): rears back with jaw and claws wide, strikes forwards/down, claws snap
  shut on impact (frame 16), recovers.
- Worm_Burrow (48 f): the column curls forward into an arch and the head plunges into the
  sand inside the tile; the body flows along the arch after it, tail last.
- Worm_Emerge (48 f): the head bursts up from a hole at the tile centre, the column rises
  and settles (ease-out), the back of the body surfaces behind, roar at the end.
REBAKE=True rebuilds an existing rig/actions.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

st=bpy.app.driver_namespace['sand_worm']; NAME=st['name']; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
root=bpy.data.objects[NAME+'_ROOT']
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\sand_worm_v1')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
CLIPS=('Worm_Idle','Worm_Attack','Worm_Burrow','Worm_Emerge')
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
else:
    bpy.data.libraries.write(str(source/'sand_worm_v1_static.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for n in CLIPS:
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
for m in list(scene.timeline_markers):
    if m.name.startswith('Worm_'): scene.timeline_markers.remove(m)

# ---------------- body path (identical construction to sand_worm_model.py) ----------------
def catmull(points,samples=24):
    pts=[Vector(q) for q in points]; pts=[pts[0]*2-pts[1]]+pts+[pts[-1]*2-pts[-2]]; out=[]
    for i in range(1,len(pts)-2):
        p0,p1,p2,p3=pts[i-1],pts[i],pts[i+1],pts[i+2]
        for k in range(samples):
            t=k/samples; t2=t*t; t3=t2*t
            out.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t2+(-p0+3*p1-3*p2+p3)*t3))
    out.append(pts[-2]); return out
Z=Vector((0,0,1))
class Rail:
    """Polyline with arc length and rotation-minimising frames. F points towards the head
    (decreasing index). Frames are transported from an anchor (default: last point, U = Z)."""
    def __init__(self,pts,anchor=None,anchor_up=None):
        self.P=[Vector(p) for p in pts]; n=len(self.P); self.A=[0.0]
        for i in range(1,n): self.A.append(self.A[-1]+(self.P[i]-self.P[i-1]).length)
        self.T=[(self.P[max(0,i-1)]-self.P[min(n-1,i+1)]).normalized() for i in range(n)]
        if anchor is None: anchor=n-1; anchor_up=(Z-self.T[-1]*Z.dot(self.T[-1])).normalized()
        U=[None]*n; U[anchor]=anchor_up
        for i in range(anchor-1,-1,-1):
            u=self.T[i+1].rotation_difference(self.T[i])@U[i+1]; U[i]=(u-self.T[i]*u.dot(self.T[i])).normalized()
        for i in range(anchor+1,n):
            u=self.T[i-1].rotation_difference(self.T[i])@U[i-1]; U[i]=(u-self.T[i]*u.dot(self.T[i])).normalized()
        self.U=U; self.L=self.A[-1]
    def at(self,s):
        if s<0:   # linear extension beyond the head end
            F=self.T[0]; U=self.U[0]; return self.P[0]+F*(-s),F,U.cross(F).normalized(),U
        if s>self.L:
            F=self.T[-1]; U=self.U[-1]; return self.P[-1]-F*(s-self.L),F,U.cross(F).normalized(),U
        i=next(k for k in range(1,len(self.A)) if self.A[k]>=s) if s>0 else 1
        t=(s-self.A[i-1])/max(1e-9,self.A[i]-self.A[i-1])
        F=self.T[i-1].lerp(self.T[i],t).normalized(); U=self.U[i-1].lerp(self.U[i],t); U=(U-F*U.dot(F)).normalized()
        return self.P[i-1].lerp(self.P[i],t),F,U.cross(F).normalized(),U
PATH=[Vector(p) for p in st['path']]; REST_D=catmull(PATH); REST=Rail(REST_D)
assert abs(REST.L-st['path_length'])<1e-6
SEG=st['segments']; NSEG=len(SEG)
def mat(F,X,U): return Matrix((X,F,U)).transposed()
def part(n): return bpy.data.objects[NAME+'_'+n]
def avg(vs): return sum(vs,Vector())/len(vs)
def verts(n): return [v.co.copy() for v in part(n).data.vertices]

# Body elements: head (b=0), segments, tail. Rest placement from the rest rail.
BODY={'head':0.0}
for i,s in enumerate(SEG): BODY[s['bone']]=s['s']
BODY['tail']=REST.L-.06
REST_PL={}
for e,b in BODY.items():
    p,F,X,U=REST.at(b); REST_PL[e]=(p,mat(F,X,U))
P0=REST.P[0]; HX=Vector((1,0,0)); HF=Vector((0,-1,-.30)).normalized(); HU=HF.cross(HX).normalized()
HEAD_C=avg(verts('Skull'))
mouth=verts('Mouth'); HINGE=avg(sorted(mouth,key=lambda v:v.dot(HF))[:4])
PIV={}
for t in ('l','r'):
    PIV['claw_'+t]=avg(verts('ClawBase_'+t))
    PIV['antenna_'+t]=avg(verts('Antenna_'+t)[:4])
LEG_ROOT={}; LEG_SEG={}
for i in range(NSEG):
    for t in ('l','r'):
        n='leg_%02d_%s'%(i+1,t); LEG_ROOT[n]=avg(verts('Leg_%02d_%s'%(i+1,t))[:4]); LEG_SEG[n]=SEG[i]['bone']
F0=REST.at(0)[1]; HEAD_ALIGN=HF.rotation_difference(F0)     # turns the head to point along the body

# ---------------- armature ----------------
part_bone={o['part']:o['rig_bone'] for o in parts}
bone_names=['root','head','jaw','claw_l','claw_r','antenna_l','antenna_r']+[s['bone'] for s in SEG]+['tail']+sorted(LEG_ROOT)
assert set(part_bone.values())<=set(bone_names),set(part_bone.values())-set(bone_names)
def bone_span(n):
    if n=='root': return Vector((0,0,0)),Vector((0,0,.3))
    if n in REST_PL: p,R=REST_PL[n]; return p,p+R.col[1]*.25
    if n=='jaw': return HINGE,HINGE+HF*.25
    if n in PIV: return PIV[n],PIV[n]+HF*.2
    if n in LEG_ROOT:
        p=LEG_ROOT[n]; R=REST_PL[LEG_SEG[n]][1]; side=1 if n.endswith('_l') else -1; return p,p+R.col[0]*side*.2
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm)
bpy.data.collections[NAME+'_01_BODY'].objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n in bone_names:
    h,t_=bone_span(n); b=arm.edit_bones.new(n); b.head=h; b.tail=t_; b.roll=0
    if n!='root': b.parent=arm.edit_bones['root']; b.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT'); arm.display_type='STICK'
for o in parts:
    b=o['rig_bone']; o.vertex_groups.new(name=b).add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    mod=o.modifiers.new('Rigid_Worm_Parts','ARMATURE'); mod.object=rig; o.parent=rig
rig['notes']='Flat rigid rig (every bone child of root), one bone per part group; poses baked from the body path.'
rest={b.name:b.matrix_local.copy() for b in arm.bones}

# ---------------- pose maths ----------------
def Tm(v): return Matrix.Translation(Vector(v))
def about(p,q): return Tm(p)@q.to_matrix().to_4x4()@Tm(-Vector(p))
def qax(axis,deg): return Quaternion(Vector(axis),math.radians(deg))
def move(e,p2,R2):
    p,R=REST_PL[e]; return Tm(p2)@(R2@R.transposed()).to_4x4()@Tm(-p)
def smooth(t): t=max(0.0,min(1.0,t)); return t*t*(3-2*t)
def hide_scale(depth):
    return 1.0 if depth<.30 else max(.02,1.0-(depth-.30)/.40*.98)
def pose_D(rail,q0=0.0,in_place=None,head_q=Quaternion(),jaw=0.0,claw=0.0,ant=(0.0,0.0),legs=None,hide=False):
    """Body elements on `rail` at q0+b (or a given D in `in_place`), then attached parts."""
    D={'root':Matrix.Identity(4)}; center={}
    for e,b in BODY.items():
        if in_place and e in in_place: D[e]=in_place[e]
        else:
            p,F,X,U=rail.at(q0+b); D[e]=move(e,p,mat(F,X,U))
    D['head']=D['head']@about(P0,head_q)
    D['jaw']=D['head']@about(HINGE,qax(HX,jaw))
    for t,side in (('l',1),('r',-1)):
        D['claw_'+t]=D['head']@about(PIV['claw_'+t],qax(HU,side*claw))
        D['antenna_'+t]=D['head']@about(PIV['antenna_'+t],qax(HU,side*ant[0])@qax(HX,-ant[1]))
    for n,seg in LEG_SEG.items():
        i=int(n[4:6])-1; side=1 if n.endswith('_l') else -1
        lift=legs(i,side) if legs else 0.0          # + lifts the leg (dorsal), - tucks it under the belly
        D[n]=D[seg]@about(LEG_ROOT[n],qax(REST_PL[seg][1].col[1],side*lift))
    scale={n:1.0 for n in D}
    if hide:
        group={e:e for e in BODY}
        for n in ('jaw','claw_l','claw_r','antenna_l','antenna_r'): group[n]='head'
        for n,seg in LEG_SEG.items(): group[n]=seg
        for e in BODY:
            c=D[e]@(HEAD_C if e=='head' else REST_PL[e][0]); center[e]=c; scale[e]=hide_scale(-c.z)
        for n,g in group.items():
            s=scale[g]
            if s<1.0:
                c=center[g]; D[n]=Tm(c)@Matrix.Diagonal((s,s,s,1))@Tm(-c)@D[n]
            scale[n]=s
    return D,scale

def bend_rail(theta,psi):
    """Rest path with the raised column bent progressively from its base (lengths kept)."""
    base=6*24; b_base=REST.A[base]; new=[p.copy() for p in REST_D]
    for i in range(base-1,-1,-1):
        w=(b_base-REST.A[i])/b_base
        R=(qax((0,1,0),psi*w)@qax((1,0,0),theta*w)).to_matrix()
        new[i]=new[i+1]+R@(REST_D[i]-REST_D[i+1])
    return Rail(new)

# Burrow rail Q: deep under the dive hole -> hole (inside the tile, in front) -> arch -> joins
# the rest path at its column base -> rest ground tail. Frames anchored at the tail end, so the
# ground part keeps its rest frames.
ARCH=[(0,-0.74,-6.0),(0,-0.74,-2.0),(0,-0.74,-0.6),(0,-0.73,0.0),(0,-0.70,0.50),(0,-0.58,1.00),(0,-0.34,1.30),
      (0,-0.08,1.26),(0,0.06,0.94),(0,0.08,0.64)]
arch_d=catmull(ARCH+[tuple(PATH[6]),tuple(PATH[7]),tuple(PATH[8])])
Q=Rail(arch_d[:len(ARCH)*24]+REST_D[6*24:])
q_join=Q.A[len(ARCH)*24]; b_base=REST.A[6*24]; q0A=q_join-b_base
q_hole=Q.A[3*24]
# Emerge rail E: rest column down to PATH[5], then straight down through a hole at the tile
# centre. Frames anchored at the head with the rest frame, so the column matches the rest.
emerge_d=catmull([tuple(PATH[4]),tuple(PATH[5]),(0,0.05,0.40),(0,0.05,0.0),(0,0.05,-0.8),(0,0.05,-6.0)])
E=Rail(REST_D[:5*24]+emerge_d[24:],anchor=0,anchor_up=REST.U[0])
b5=REST.A[5*24]

def resample_blend(a):
    """Body path blended from the rest J (a=0) to the burrow arch (a=1), on the rest samples
    (so a=0 is exactly the rest rail)."""
    return Rail([p.lerp(Q.at(q0A+REST.A[j])[0],a) for j,p in enumerate(REST_D)])

# ---------------- keying ----------------
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
previous={}; clips={}; stats={}
def apply(D):
    for n in bone_names: rig.pose.bones[n].matrix=D[n]@rest[n]
    bpy.context.view_layer.update()
def key(f):
    for b in rig.pose.bones:
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion)<0: b.rotation_quaternion.negate()
        previous[b.name]=b.rotation_quaternion.copy()
        for path in ('location','rotation_quaternion','scale'): b.keyframe_insert(data_path=path,frame=f,group=b.name)
rig.animation_data_create()
PART_VERTS={o.name:(o['rig_bone'],[v.co.copy() for v in o.data.vertices]) for o in parts}
def measure(name,f,D,scale):
    s=stats.setdefault(name,{'min_visible_z':9.0,'poses':{}})
    for bone,vs in PART_VERTS.values():
        if scale.get(bone,1.0)<.5: continue
        m=D[bone]; s['min_visible_z']=min(s['min_visible_z'],min((m@v).z for v in vs))
    s['poses'][f]={n:D[n].copy() for n in ('head','seg_01','seg_05','tail','leg_03_l')}
def new_action(n,end,loop,start,desc):
    a=bpy.data.actions.new(n); a.use_fake_user=True; rig.animation_data.action=a; previous.clear()
    clips[n]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':start,'description':desc}
def bake(name,f,D,scale): apply(D); key(f); measure(name,f,D,scale)

# Idle: cobra sway; grounded segments (and their legs) stay put.
RAISED={i for i,s in enumerate(SEG) if not s['grounded']}
new_action('Worm_Idle',73,True,1,'Cobra sway of the raised column, head looks around, antennae/claws/jaw twitch, leg wave on the raised segments; grounded legs planted.')
for f in range(1,74):
    p=math.tau*(f-1)/72
    rail=bend_rail(2.5*math.sin(p),5.0*math.sin(p+.6))
    D,sc=pose_D(rail,head_q=qax(HU,8*math.sin(p+1.2))@qax(HX,3*math.sin(2*p)),jaw=4*(1-math.cos(2*p))/2,
                claw=5+5*math.sin(2*p),ant=(6*math.sin(2*p+.5),5*math.sin(3*p)),
                legs=lambda i,side:(9*math.sin(2*p-i*.9) if i in RAISED else 0.0))
    bake('Worm_Idle',f,D,sc)

# Attack: rear back (wide jaw/claws), strike forwards/down, snap shut on impact (16), recover.
new_action('Worm_Attack',37,False,101,'Rears back with jaw and claws wide, strikes forwards/down, claws snap shut on impact (frame 16), recovers.')
AK={1:(0,0,0,0),8:(-20,-18,28,30),12:(-24,-20,32,34),16:(52,24,10,-8),20:(50,22,6,-6),28:(14,6,2,2),37:(0,0,0,0)}
ks=sorted(AK)
for f in range(1,38):
    lo=max(k for k in ks if k<=f); hi=min(k for k in ks if k>=f); t=0 if lo==hi else smooth((f-lo)/(hi-lo))
    th,hp,jw,cl=(a+(b-a)*t for a,b in zip(AK[lo],AK[hi]))
    flare=max(0.0,-th)/24*14
    D,sc=pose_D(bend_rail(th,0.0),head_q=qax(HX,hp),jaw=jw,claw=cl,ant=(0.0,-hp*.6),
                legs=lambda i,side:(flare if i in RAISED else 0.0))
    bake('Worm_Attack',f,D,sc)

# Burrow: curl into the arch (1-14), then flow along it into the dive hole (14-48).
new_action('Worm_Burrow',49,False,161,'Column curls forward into an arch, the head plunges into the sand inside the tile and the body flows after it along the arch, tail last.')
TRAVEL=REST.L+1.4
for f in range(1,50):
    if f<=14:
        a=smooth((f-1)/13); rail=resample_blend(a); q0=0.0
    else:
        a=1.0; rail=Q; u=(f-14)/34; q0=q0A-TRAVEL*(u*u*(2.2-1.2*u))     # accelerating dive, slight ease at the end
    D,sc=pose_D(rail,q0,head_q=Quaternion().slerp(HEAD_ALIGN,a),jaw=10*a,claw=-6*a,ant=(-20*a,25*a),
                legs=lambda i,side:-38*a,hide=True)
    bake('Worm_Burrow',f,D,sc)

# Emerge: head bursts up the centre hole, overshoots and settles; back surfaces behind; roar.
new_action('Worm_Emerge',49,False,231,'The head bursts up from a hole at the tile centre, the column rises and settles, the back of the body surfaces behind it, roar with claws wide.')
S0=b5+.76+1.0
GROUND=[e for e in BODY if e!='head' and BODY[e]>=b5]; GROUND.sort(key=lambda e:BODY[e])
for f in range(1,50):
    # Column rises with a strong ease-out and no overshoot (overshoot opened a gap to the
    # back segments still surfacing behind it).
    shift=S0 if f<=4 else S0*(1-min(1.0,(f-4)/24))**3
    align=1.0-smooth((f-20)/12)
    in_place={}
    for r,e in enumerate(GROUND):
        d=1.4*(1-smooth((f-(7+3*r))/12)); in_place[e]=Tm((0,0,-d))
    roar=smooth((f-28)/6)*(1-smooth((f-38)/10))
    ground_bones={s['bone'] for s in SEG if BODY[s['bone']]>=b5}
    def legs(i,side,f=f):
        seg=SEG[i]['bone']
        if seg in ground_bones:
            r=GROUND.index(seg); return -38*(1-smooth((f-(13+3*r))/8))
        return -38*(1-smooth((f-22)/12))
    D,sc=pose_D(E,shift,in_place=in_place,head_q=Quaternion().slerp(HEAD_ALIGN,align),jaw=30*roar,claw=32*roar-4*(1-roar)*(f<30),
                ant=(-20*align,25*align),legs=legs,hide=True)
    bake('Worm_Emerge',f,D,sc)

# ---------------- finish: interpolation, markers, NLA ----------------
for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
events={'Worm_Idle':[('LOOP_START',1),('LOOP_END',73)],'Worm_Attack':[('START',1),('WINDUP',12),('IMPACT',16),('RECOVERED',37)],
        'Worm_Burrow':[('START',1),('ARCHED',14),('HIDDEN',49)],'Worm_Emerge':[('HIDDEN',1),('SURFACE',8),('ROAR',34),('RECOVERED',49)]}
for n,ev in events.items():
    for label,fr in ev: clips[n]['action'].pose_markers.new(label).frame=fr
clips['Worm_Attack']['impact_frame']=16
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=279; scene.frame_set(1)

# ---------------- validation (from the baked matrices) ----------------
def close(A,B,tol=1e-4): return all(abs(A[r][c]-B[r][c])<tol for r in range(4) for c in range(4))
I=Matrix.Identity(4); problems=[]
idle=stats['Worm_Idle']['poses']
if not all(close(idle[1][n],idle[73][n]) for n in idle[1]): problems.append('idle loop not closed')
for clip,f in (('Worm_Idle',1),('Worm_Attack',1),('Worm_Attack',37),('Worm_Burrow',1),('Worm_Emerge',49)):
    if clip!='Worm_Idle' and not all(close(m,I,2e-3) for m in stats[clip]['poses'][f].values()): problems.append('%s frame %d is not the rest pose'%(clip,f))
for clip in ('Worm_Idle','Worm_Attack'):
    if stats[clip]['min_visible_z']<-.01: problems.append('%s goes below the ground (%.3f)'%(clip,stats[clip]['min_visible_z']))
validation={'problems':problems,'min_visible_z':{k:round(v['min_visible_z'],4) for k,v in stats.items()},
            'burrow':{'q_hole':q_hole,'q0_arch':q0A,'arch_head_joint_above_hole_m':q0A-q_hole}}
mat_=bpy.data.materials[NAME+'_PixelArt']
st.update({'scene':scene,'parts':parts,'rig':rig,'clips':clips,'source':str(source),'material':mat_,'root':root,'animation_validation':validation})
result={'bones':len(arm.bones),'validation':validation,
        'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
