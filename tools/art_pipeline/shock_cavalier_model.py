"""Static ShockCavalier V1 (Cavaleiro de Choque, v2_unit_shock_cavalier): the aggressive first evolution of the
human cavalry line, built from a COPY of the Cavalier (same parts, joints, horse and rider rig) so it plays every
Cavalier clip (Idle, Walk = gallop, Attack, Charge). One step up, heavier: the rider wears MAIL (chest, belly,
upper arms; leather pauldrons) with an iron helm and a mail coif PAINTED on the head (head pieces are painted),
and carries a heavier lance (thicker haft, bigger head, a square VAMPLATE above the hand) with the blue pennant.
The horse is BLACK, with a blue CAPARISON down both flanks and a steel CHANFRON painted on its face (the head
stays ONE rectangle with the face painted; reins routed outside the head and neck). One block per body part; no
visible coplanar faces (check_coplanar). Built at real scale (no fit). Run INSIDE Blender through the MCP
client. Real meters, front = -Y, ground at Z=0, origin under the horse's middle. Left side = +X (_l).
Prepend REBUILD=True to rebuild.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='ShockCavalier_V1'
OUT=ROOT/'assets/generated/humans/shock_cavalier_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('ShockCavalier scene exists; preserve manual edits.')
    old=bpy.data.scenes[NAME]
    for c in list(old.collection.children):
        for o in list(c.objects): bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(c)
    for o in list(old.collection.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
    for store in (bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.worlds,bpy.data.cameras,bpy.data.lights,bpy.data.armatures,bpy.data.actions):
        for block in list(store):
            if block.name.startswith(NAME+'_'): store.remove(block)
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
collections={}
for label in ['01_BODY','02_HEAD','03_ARMS','04_LEGS','05_GEAR','06_CLOTH','07_HORSE','07_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
X=Vector((1,0,0)); Y=Vector((0,1,0)); Z=Vector((0,0,1))
def mesh(name,verts,faces,region,bone,collection,up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['rig_bone']=bone; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def fbox(name,center,A,B,C,size,region,bone,collection):
    # Cuboid in a local frame A (width), B (depth/along), C (height). Vertex order z*4+y*2+x.
    c=Vector(center); a,b,d=[v/2 for v in size]
    verts=[c+A*sx*a+B*sy*b+C*sz*d for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,C)
def box(name,center,size,region,bone,collection):
    return fbox(name,center,X,Y,Z,size,region,bone,collection)
def beam(name,start,end,width,depth,region,bone,collection,end_width=None,end_depth=None,side=None):
    # Cuboid (or tapered spike) along start->end; `side` fixes the width axis.
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector(side) if side else Y.cross(axis)
    if u.length<1e-6: u=X.copy()
    u=(u-axis*u.dot(axis)).normalized(); v=axis.cross(u).normalized()
    ew=width if end_width is None else end_width; ed=depth if end_depth is None else end_depth
    verts=[c+u*x*w/2+v*y*d/2 for c,w,d in ((a,width,depth),(b,ew,ed)) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,axis if axis.z>=0 else -axis)

# Clean fit (user review): blocks are STACKED (touching faces only) instead of sunk into each other,
# and no two parts share a visible coplanar face (that is what flickered — z-fighting). Neighbour
# faces always differ by >= 8 mm; check_coplanar() below enforces it.

# ================= HORSE (Minecraft-mob construction: few big axis-aligned mirrored blocks) =================
# Compact so the whole mount fits one hex (~1.9 m muzzle to tail). Front = -Y.
box('HorseBody',(0,0,1.10),(.46,1.20,.52),'horse_body','horse_body','07_HORSE')          # barrel: x+-.23, y+-.60, z .84-1.36
# Neck + head as ONE group tilted forward (user: the first, upright neck with a flat head looked dreadful; reference:
# the Minecraft horse). Frame: pivot at the front top of the barrel, local Z up the neck, local -Y forward; the
# whole group pitches forward by NECK_TILT so the neck leans out and the long head points forward-DOWN.
NECK_TILT=math.radians(32.0)
NP=Vector((0,-.50,1.20))
NA=Vector((1,0,0)); NB=Vector((0,math.cos(NECK_TILT),math.sin(NECK_TILT))); NC=Vector((0,-math.sin(NECK_TILT),math.cos(NECK_TILT)))
def nk(x,y,z): return NP+NA*x+NB*y+NC*z                               # neck-frame point -> world
def nbox(name,c,size,region,bone): return fbox(name,nk(*c),NA,NB,NC,size,region,bone,'07_HORSE')
# Second pass (user: "the horse has no brain, look at that neck"): the first tilted head was a thin plank glued to the
# FRONT of the neck, so the neck and mane rose above and behind it — no skull. Now, like the Minecraft horse: a thick
# neck whose top end goes INTO a tall skull block sitting ON the neck (its back flush with the mane, ears on top),
# and a narrower muzzle block stepped down in front of it.
nbox('HorseNeck',(0,0,.30),(.26,.36,.62),'horse_neck','horse_neck')        # local y +-.18, z -.01..+.61
nbox('HorseMane',(0,.205,.40),(.10,.05,.78),'horse_mane','horse_neck')     # along the back of the neck up to the poll
# Third pass (user: a horse has no separate beak-like muzzle — the face is ONE big rectangle with the face painted on it,
# as in the reference): one long head block from the poll to the nose; nostrils, mouth, eyes, blaze and bridle are pixel art.
nbox('HorseHead',(0,-.22,.66),(.28,.78,.30),'horse_head','horse_head')     # y -.61..+.17 (wraps the neck top, 1 cm off the neck's back face), z .51-.81
for side,t_ in ((1,'l'),(-1,'r')):
    nbox('HorseEar_'+t_,(side*.08,.08,.86),(.06,.05,.10),'horse_ear','horse_head')
    nbox('HorseBit_'+t_,(side*.15,-.50,.56),(.02,.05,.05),'brass','horse_head')    # bit ring on the side of the head, near the mouth
box('HorseTail',(0,.655,1.05),(.10,.11,.50),'horse_tail','horse_tail','07_HORSE')       # hangs from the back top
# Legs: thigh / cannon / hoof, every block a different size (no coplanar faces); bones per upper/lower leg.
for side,t_ in ((1,'l'),(-1,'r')):
    for end,yy in (('f',-.42),('b',.42)):
        n=end+t_
        box('HorseThigh_'+n,(side*.14,yy,.65),(.15,.18,.38),'horse_leg','horse_thigh_'+n,'07_HORSE')
        box('HorseCannon_'+n,(side*.14,yy,.26),(.12,.14,.40),'horse_cannon_'+('front' if end=='f' else 'back'),'horse_cannon_'+n,'07_HORSE')
        box('HorseHoof_'+n,(side*.14,yy-.005,.03),(.14,.17,.06),'horse_hoof','horse_cannon_'+n,'07_HORSE')
# Tack: blue team saddle blanket (top + side panels), leather saddle with pommel and cantle, iron stirrups.
box('SaddleBlanket',(0,-.02,1.37),(.52,.56,.03),'saddle_blanket','horse_body','07_HORSE')
for side,t_ in ((1,'l'),(-1,'r')):
    box('BlanketSide_'+t_,(side*.24,0,1.16),(.02,1.04,.42),'saddle_blanket','horse_body','07_HORSE')   # CAPARISON: covers the flanks
box('Saddle',(0,-.02,1.42),(.36,.40,.08),'saddle','horse_body','07_HORSE')
box('SaddlePommel',(0,-.20,1.49),(.14,.06,.08),'saddle','horse_body','07_HORSE')
box('SaddleCantle',(0,.16,1.50),(.26,.06,.10),'saddle','horse_body','07_HORSE')

# ================= RIDER (the human troop base, SEATED on the saddle) =================
# Same blocks and proportions as the standing troops (1.80 m standing); the upper body rides dz above.
DZ=.56; DY=-.02
def up(v): return Vector((v[0],v[1]+DY,v[2]+DZ))
box('Pelvis',up((0,0,.96)),(.40,.22,.16),'pelvis_sash','hips','01_BODY')
box('Buckle',up((0,-.115,1.00)),(.07,.03,.05),'brass','hips','01_BODY')
box('Belly',up((0,0,1.12)),(.32,.20,.16),'mail','chest','01_BODY')
box('Chest',up((0,0,1.34)),(.44,.25,.28),'mail_chest','chest','01_BODY')
box('Head',up((0,-.005,1.615)),(.27,.27,.27),'face_coif','head','02_HEAD')     # iron helm + mail coif PAINTED on the head
for side,t_ in ((1,'l'),(-1,'r')):
    box('Shoulder_'+t_,up((side*.28,0,1.40)),(.16,.22,.18),'shoulder','upper_arm_'+t_,'03_ARMS')
# Legs straddle the horse: thigh forward-down outside the blanket, shin down to the stirrup.
for side,t_ in ((1,'l'),(-1,'r')):
    H=Vector((side*.115,-.02,1.49)); K=Vector((side*.34,-.26,1.20)); A=Vector((side*.33,-.16,.86))
    beam('Thigh_'+t_,H,K,.13,.15,'trousers','thigh_'+t_,'04_LEGS',side=Y)
    beam('Shin_'+t_,K+(A-K).normalized()*-.02,A,.16,.18,'boot_shaft','shin_'+t_,'04_LEGS',side=Y)
    box('Foot_'+t_,(side*.33,-.22,.80),(.18,.28,.10),'boot','foot_'+t_,'04_LEGS')
    box('Stirrup_'+t_,(side*.33,-.20,.735),(.20,.12,.03),'iron','foot_'+t_,'07_HORSE')
# Arms: the right hand holds the lance upright beside the shoulder, the left hand the reins over the withers.
ARMS={'l':(up((.28,0,1.33)),up((.31,-.10,1.10)),up((.20,-.34,1.10))),
      'r':(up((-.28,0,1.33)),up((-.32,-.06,1.09)),up((-.30,-.24,1.14)))}
HAND={}
for t_,(S,E,W) in ARMS.items():
    F=(W-E).normalized()
    beam('UpperArm_'+t_,S,E,.12,.13,'mail','upper_arm_'+t_,'03_ARMS',side=X)
    beam('Forearm_'+t_,E-F*.02,W,.16,.17,'bracer','forearm_'+t_,'03_ARMS',side=X)
    Hf=W+F*.10; HAND[t_]=(W,Hf,F)
    beam('Hand_'+t_,W,Hf,.12,.13,'glove','hand_'+t_,'03_ARMS',side=X)
# ---------------- lance (right hand): ash haft, iron head, blue pennant streaming back ----------------
Wr,Hfr,Fr=HAND['r']
G=(Wr+Hfr)/2; AX=Vector((0,-.16,.99)).normalized()                  # upright, tilted a little forward
BLp=(Y-AX*Y.dot(AX)).normalized()                                   # square to the haft (no sheared blocks)
beam('LanceHaft',G-AX*.55,G+AX*1.32,.055,.055,'lance_haft','hand_r','05_GEAR',side=X)   # heavier haft
fbox('LanceHead',G+AX*1.42,X,BLp,AX,(.07,.07,.20),'iron','hand_r','05_GEAR')
fbox('LanceTip',G+AX*1.56,X,BLp,AX,(.04,.04,.08),'iron','hand_r','05_GEAR')
fbox('LanceVamplate',G+AX*.13,X,BLp,AX,(.16,.16,.03),'iron','hand_r','05_GEAR')   # square hand guard of a heavy lance
fbox('Pennant',G+AX*1.13+BLp*.15,X,BLp,AX,(.008,.28,.18),'pennant','hand_r','05_GEAR')
# ---------------- reins: from each bit ring back ALONG THE SIDE of the neck, then over the withers to the left fist ----------------
# (user: the first, straight reins cut through the horse's head.) Each rein is three thin segments whose path stays
# outside the head (x +-.14 in the neck frame), outside the neck (x +-.13) and, only once
# BEHIND the mane (neck-frame y > .23), turns in to the hand — no segment crosses the horse.
Wl,Hfl,Fl=HAND['l']
GL=(Wl+Hfl)/2
for side,t_ in ((1,'l'),(-1,'r')):
    P0=nk(side*.15,-.50,.56); P1=nk(side*.19,.02,.34); P2=nk(side*.19,.27,.40)
    beam('Rein_'+t_+'1',P0,P1,.012,.012,'rein','hand_l','05_GEAR')
    beam('Rein_'+t_+'2',P1,P2,.012,.012,'rein','hand_l','05_GEAR')
    beam('Rein_'+t_+'3',P2,GL+Vector((side*.02,0,0)),.012,.012,'rein','hand_l','05_GEAR')

def check_coplanar(tol=.004):
    """Visible z-fighting candidates: faces of DIFFERENT parts with the same outward normal, on the same
    plane (< tol) and overlapping. Returns [(part_a, part_b)]."""
    faces=[]
    for o in parts:
        me=o.data; c=sum((v.co for v in me.vertices),Vector())/len(me.vertices)
        for poly in me.polygons:
            vs=[me.vertices[i].co.copy() for i in poly.vertices]; fc=sum(vs,Vector())/len(vs)
            n=poly.normal.normalized()
            if n.dot(fc-c)<0: n=-n                     # outward
            faces.append((o['part'],n,n.dot(fc),vs))
    hits=set()
    for i in range(len(faces)):
        pa,na,da,va=faces[i]
        for j in range(i+1,len(faces)):
            pb,nb,db,vb=faces[j]
            if pa==pb or na.dot(nb)<.999 or abs(da-db)>tol: continue
            # In-plane axes aligned with the world (axis-aligned faces get exact rectangles, no false overlaps).
            u=(X if abs(na.x)<.9 else Y); u=(u-na*u.dot(na)).normalized(); w=na.cross(u)
            ra=[(v.dot(u),v.dot(w)) for v in va]; rb=[(v.dot(u),v.dot(w)) for v in vb]
            ov_u=min(max(x for x,_ in ra),max(x for x,_ in rb))-max(min(x for x,_ in ra),min(x for x,_ in rb))
            ov_w=min(max(y for _,y in ra),max(y for _,y in rb))-max(min(y for _,y in ra),min(y for _,y in rb))
            if ov_u>.002 and ov_w>.002: hits.add(tuple(sorted((pa,pb))))
    return sorted(hits)

# Fit every human troop to exactly 1.80 m (feet stay on the ground).
FIT=1.0   # mounted: built at real scale (the rider has the standing troops' 1.80 m proportions); no fit
for o in parts:
    for v in o.data.vertices: v.co*=FIT
    o.data.update()
HERO_SCALE=FIT

# Exact metric projection, matching the approved models: 64 px per Blender meter.
DENSITY=64; PAD=2; islands=[]
for obj in parts:
    me=obj.data; bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    for p in me.polygons:
        normal=p.normal.normalized(); desired=Vector(obj['paint_up'])
        up=desired-normal*desired.dot(normal)
        if up.length<.001: up=Vector((0,1,0))-normal*normal.y
        if up.length<.001: up=Vector((1,0,0))-normal*normal.x
        up.normalize(); right=up.cross(normal).normalized()
        co=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        minimum=Vector((min(c.x for c in co),min(c.y for c in co))); co=[c-minimum for c in co]
        islands.append({'obj':obj,'polygon':p.index,'coords':co,'normal':normal,'right':right,
                        'w':max(1,math.ceil(max(c.x for c in co)*DENSITY)),
                        'h':max(1,math.ceil(max(c.y for c in co)*DENSITY))})
def pack(size):
    x=y=PAD; row=0
    for island in sorted(islands,key=lambda i:(-i['h'],-i['w'])):
        w,h=island['w']+2*PAD,island['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        island['x']=x+PAD; island['y']=y+PAD; x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (256,512,1024) if pack(s))

TARGET=Vector((0,-.25,1.45))
studio=collections['07_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6,9),1400,6,(1,.92,.81)),('Fill',(6.5,-2.5,6.5),700,6,(.78,.86,1)),('Rim',(0,7,8),1500,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','07_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=4.4; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static ShockCavalier V1 (Cavaleiro de Choque): heavier evolution of the ShockCavalier — rider in mail with a painted iron helm and mail coif, heavy lance with a vamplate; black horse with a blue caparison over the flanks and a steel chanfron painted on the face; same rig.'
scene['animations_requested']=False
bpy.app.driver_namespace['shock_cavalier']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET,'hero_scale':HERO_SCALE}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords),'min_z':min(c.z for c in coords),
        'y':[min(c.y for c in coords),max(c.y for c in coords)],'x':[min(c.x for c in coords),max(c.x for c in coords)],
        'coplanar_overlaps':check_coplanar()}
