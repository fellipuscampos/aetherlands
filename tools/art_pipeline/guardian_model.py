"""Static Guardian V1 (Guardião, v2_unit_guardian): evolution of the Squire V1 — the SAME
character, joints and proportions (so every Squire clip, Shield Wall included, carries over),
ONE step more armour (user: the all-steel first pass left nothing for the Sentinel, the next
evolution): a MAIL hauberk (chest, belly, sleeves, skirt) under a blue surcoat with the silver
tower of the Guardian line, a steel Norman nasal helm (same face, now with a short beard), the
Squire's leather shoulders/bracers/trousers/boots, and the same round shield reinforced (steel
rim and boss) and painted with the tower. Full plate is reserved for the Sentinel.
One block per body part (head, shoulder, chest, belly, pelvis, thigh, shin, foot, upper arm,
forearm, hand); armour read from thickness + paint; no visible coplanar faces (check_coplanar).
Fitted to exactly 1.80 m. Run INSIDE Blender through the MCP client. No rig or animation here.
Real meters, front = -Y, ground at Z=0, origin between the feet. Left side = +X (_l).
Prepend REBUILD=True to discard an existing scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Guardian_V1'
OUT=ROOT/'assets/generated/humans/guardian_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Guardian scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_ARMS','04_LEGS','05_GEAR','06_CLOTH','07_STUDIO']:
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
# ---------------- legs: thin wool thigh, THICK boot shaft (shin), boot; left foot forward ----------------
# User edit in Blender (2026-10-04): shin and foot moved so each leg is STRAIGHT (shin right under the thigh),
# keeping only the small stance offset between the two legs.
for side,t_ in ((1,'l'),(-1,'r')):
    x=side*.115; ly=-.035 if side==1 else .03
    box('Foot_'+t_,(x,ly-.04,.05),(.18,.28,.10),'boot','foot_'+t_,'04_LEGS')
    box('Shin_'+t_,(x,ly,.29),(.16,.18,.38),'boot_shaft','shin_'+t_,'04_LEGS')
    box('Thigh_'+t_,(x,ly,.68),(.13,.15,.40),'trousers','thigh_'+t_,'04_LEGS')

# ---------------- pelvis (belt + gambeson skirt), belly (quilted), chest (leather jerkin), head ----------------
box('Pelvis',(0,0,.96),(.40,.22,.16),'mail_skirt','hips','01_BODY')
box('Buckle',(0,-.115,1.00),(.07,.03,.05),'brass','hips','01_BODY')
box('Belly',(0,0,1.12),(.32,.20,.16),'mail','chest','01_BODY')
box('Chest',(0,0,1.34),(.44,.25,.28),'surcoat','chest','01_BODY')              # mail hauberk under a blue surcoat
box('TabardFront',(0,-.127,.86),(.20,.03,.30),'tabard','hips','06_CLOTH')          # rank tabard below the belt
box('TabardBack',(0,.127,.86),(.24,.03,.30),'tabard','hips','06_CLOTH')
box('Head',(0,-.005,1.615),(.27,.27,.27),'face','head','02_HEAD')
# Steel nasal helm: brow band, cap enclosing the head top, low dome, nasal guard in front of the nose.
# Norman nasal helm: the cap comes DOWN over the forehead and the sides of the head to the brows (not a hat).
box('HelmBand',(0,-.005,1.675),(.32,.32,.03),'steel','head','02_HEAD')
box('HelmCap',(0,-.005,1.735),(.30,.30,.14),'helm','head','02_HEAD')
box('HelmDome',(0,-.005,1.825),(.20,.20,.04),'steel','head','02_HEAD')
box('Nasal',(0,-.152,1.6175),(.03,.02,.075),'steel','head','02_HEAD')

# ---------------- arms: shoulder cube joins the chest (sunk 2 cm into it, top 1 cm above it) ----------------
for side,t_ in ((1,'l'),(-1,'r')):
    box('Shoulder_'+t_,(side*.28,0,1.40),(.16,.22,.18),'shoulder','upper_arm_'+t_,'03_ARMS')
# Shield-wall stance: both forearms forward; left fist on the shield's centre grip, right hand on the rim.
ARMS={'l':(Vector((.28,0,1.33)),Vector((.27,-.10,1.08)),Vector((.23,-.34,1.10))),
      'r':(Vector((-.28,0,1.33)),Vector((-.27,-.11,1.08)),Vector((-.18,-.35,1.11)))}
HAND={}
for t_,(S,E,W) in ARMS.items():
    F=(W-E).normalized()
    beam('UpperArm_'+t_,S,E,.12,.13,'mail','upper_arm_'+t_,'03_ARMS',side=X)
    beam('Forearm_'+t_,E-F*.02,W,.16,.17,'bracer','forearm_'+t_,'03_ARMS',side=X)
    Hf=W+F*.10; HAND[t_]=(W,Hf,F)
    beam('Hand_'+t_,W,Hf,.12,.13,'glove','hand_'+t_,'03_ARMS',side=X)

# ---------------- round wooden shield: crossed boxes at DIFFERENT thicknesses (no coplanar faces) ----------------
th=math.radians(10); SA=Vector((math.cos(th),math.sin(th),0)); SB=Vector((-math.sin(th),math.cos(th),0)); NS=-SB
Wl,Hfl,Fl=HAND['l']
SC=Hfl+NS*.035; SC.x=.10; SC.z=1.08
# Same round shield as the Squire (crossed boxes, thicknesses 6-7 mm apart), reinforced and painted.
fbox('ShieldMid',SC,SA,SB,Z,(.52,.056,.52),'round_heraldic','hand_l','05_GEAR')
fbox('ShieldWide',SC,SA,SB,Z,(.60,.028,.40),'round_heraldic','hand_l','05_GEAR')
fbox('ShieldTall',SC,SA,SB,Z,(.40,.042,.60),'round_heraldic','hand_l','05_GEAR')
fbox('ShieldBoss',SC+NS*.04,SA,SB,Z,(.12,.05,.12),'steel','hand_l','05_GEAR')
fbox('ShieldGrip',Hfl-Fl*.03,SA,SB,Z,(.04,.04,.16),'glove','hand_l','05_GEAR')     # bar through the fist

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
FIT=1.80/max(v.co.z for o in parts for v in o.data.vertices)
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

TARGET=Vector((0,-.10,.92))
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
cam.type='ORTHO'; cam.ortho_scale=2.5; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static Guardian V1 (Guardião): the Squire one step up — mail hauberk under a blue tower surcoat, Norman nasal helm, reinforced painted round shield, leather kept elsewhere; same joints as the Squire; 1.80 m.'
scene['animations_requested']=False
bpy.app.driver_namespace['guardian']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET,'hero_scale':HERO_SCALE}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords),'min_z':min(c.z for c in coords),
        'y':[min(c.y for c in coords),max(c.y for c in coords)],'x':[min(c.x for c in coords),max(c.x for c in coords)],
        'coplanar_overlaps':check_coplanar()}
