"""Static Swordsman V1 (Espadachim, v2_unit_swordsman): first evolution of the human Warrior
line (damage), built from a COPY of the Warrior (same parts, joints and proportions, 1.80 m of
BODY; the sword may rise above it). One step up from the Warrior, leaving room for the Master:
riveted leather BRIGANDINE over the gambeson (chest + belly), hardened-leather pauldrons on BOTH
shoulders (iron plate on the sword arm), leather bracers and gloves, wool trousers, boots, the
blue team sash; bareheaded seasoned fighter — auburn hair (hair block), blue headband with a knot,
short beard. Weapon: an ARMING SWORD (leather grip, brass pommel, iron guard, steel blade) in the
same fighting stance as the Warrior, and an empty scabbard on the left hip. One block per body
part; no visible coplanar faces (check_coplanar). Run INSIDE Blender through the MCP client.
Real meters, front = -Y, ground at Z=0, origin between the feet. Left side = +X (_l).
Prepend REBUILD=True to rebuild.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Swordsman_V1'
OUT=ROOT/'assets/generated/humans/swordsman_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Swordsman scene exists; preserve manual edits.')
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
box('Pelvis',(0,0,.96),(.40,.22,.16),'pelvis_sash','hips','01_BODY')
box('Buckle',(0,-.115,1.00),(.07,.03,.05),'brass','hips','01_BODY')
box('Belly',(0,0,1.12),(.32,.20,.16),'brigandine','chest','01_BODY')
box('Chest',(0,0,1.34),(.44,.25,.28),'brigandine_chest','chest','01_BODY')   # riveted leather brigandine
box('Head',(0,-.005,1.615),(.27,.27,.27),'face','head','02_HEAD')
# Bareheaded: a hair block on top of the head, a blue cloth headband across the brow, its knot at the back.
box('Hair',(0,-.005,1.765),(.285,.285,.06),'hair','head','02_HEAD')
box('Headband',(0,-.005,1.68),(.29,.29,.04),'band','head','02_HEAD')
box('BandKnot',(0,.15,1.68),(.07,.03,.06),'band','head','02_HEAD')

# ---------------- arms: shoulder cube joins the chest (sunk 2 cm into it, top 1 cm above it) ----------------
# Hardened-leather pauldrons on BOTH shoulders; the sword arm's one is bigger and iron-plated.
box('Shoulder_l',(.285,0,1.405),(.17,.23,.19),'shoulder','upper_arm_l','03_ARMS')
box('Shoulder_r',(-.29,0,1.41),(.18,.24,.20),'shoulder_plate','upper_arm_r','03_ARMS')
# Fighting stance: right arm raises the hatchet beside the head, left fist up in guard in front of the chest.
ARMS={'l':(Vector((.28,0,1.33)),Vector((.29,-.12,1.10)),Vector((.18,-.30,1.24))),
      'r':(Vector((-.285,0,1.33)),Vector((-.33,-.06,1.08)),Vector((-.30,-.20,1.30)))}
HAND={}
for t_,(S,E,W) in ARMS.items():
    F=(W-E).normalized()
    beam('UpperArm_'+t_,S,E,.12,.13,'gambeson','upper_arm_'+t_,'03_ARMS',side=X)
    beam('Forearm_'+t_,E-F*.02,W,.16,.17,'bracer','forearm_'+t_,'03_ARMS',side=X)
    Hf=W+F*.10; HAND[t_]=(W,Hf,F)
    beam('Hand_'+t_,W,Hf,.12,.13,'glove','hand_'+t_,'03_ARMS',side=X)

# ---------------- arming sword (right hand): leather grip through the fist, brass pommel, iron guard, steel blade ----------------
Wr,Hfr,Fr=HAND['r']
G=(Wr+Hfr)/2; AX=Vector((0,-.45,.89)).normalized()                  # blade axis: up and forward, point toward the enemy
BL=Vector((0,-1,0)); BL=(BL-AX*BL.dot(AX)).normalized()              # edge direction (forward)
beam('SwordGrip',G-AX*.08,G+AX*.09,.04,.04,'sword_grip','hand_r','05_GEAR',side=X)
fbox('SwordPommel',G-AX*.10,X,BL,AX,(.06,.06,.05),'brass','hand_r','05_GEAR')
fbox('SwordGuard',G+AX*.105,X,BL,AX,(.05,.22,.04),'sword_guard','hand_r','05_GEAR')
fbox('SwordBlade',G+AX*.48,X,BL,AX,(.016,.065,.73),'sword_blade','hand_r','05_GEAR')
# Empty scabbard hanging on the left hip (outside the thigh, rides with the hips).
box('Scabbard',(.222,.03,.66),(.05,.08,.66),'scabbard','hips','05_GEAR')

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
# The BODY measures 1.80 m; gear (the raised sword) may rise above it.
FIT=1.80/max(v.co.z for o in parts if not o.users_collection[0].name.endswith('05_GEAR') for v in o.data.vertices)
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
scene['description']='Static Swordsman V1 (Espadachim): Warrior evolution — riveted leather brigandine, two pauldrons (iron-plated on the sword arm), bareheaded with a blue headband and short beard, arming sword and scabbard; fighting stance; 1.80 m body.'
scene['animations_requested']=False
bpy.app.driver_namespace['swordsman']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET,'hero_scale':HERO_SCALE}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords),'min_z':min(c.z for c in coords),
        'y':[min(c.y for c in coords),max(c.y for c in coords)],'x':[min(c.x for c in coords),max(c.x for c in coords)],
        'coplanar_overlaps':check_coplanar()}
