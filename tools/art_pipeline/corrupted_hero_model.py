"""Static Corrupted Hero V1 (Herói Corrompido), composition approved by the user: ONE block
per body part, exactly like the Troll/Minotaur — head, chest, belly, waist, thigh, shin,
foot, shoulder, upper arm, forearm, hand. Armour is read from each block's THICKNESS
(thick forearm/shin/chest = plate, thin upper arm/thigh = mail, belly = cloth, hand =
leather) and from the paint; no stacked plates. Long separated limbs, the shoulder cube
joins the arm to the chest. Tired, old and ragged: trunk hunched forward, head hanging,
right arm hanging. Iron-block mace (wooden haft) resting on the ground in the right hand;
left arm reaching forward, fist on the centre grip of a tower shield held in guard; slate-blue tabard strips. Grey plate / slate-blue cloth / brown leather palette.
Run INSIDE Blender through the MCP client. No rig or animation yet. Real meters, front = -Y,
ground at Z=0, origin between the feet. Left side = +X (_l). Every part records its future
bone (obj['rig_bone']). Prepend REBUILD=True to discard an existing scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Corrupted_Hero_V1'
OUT=ROOT/'assets/generated/corrupted_heroes/corrupted_hero_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Corrupted hero scene exists; preserve manual edits.')
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

# ---------------- legs: thin mail thigh, thick plate shin (+ knee), plate foot ----------------
for side,t_ in ((1,'l'),(-1,'r')):
    x=side*.17
    box('Foot_'+t_,(x,-.05,.07),(.30,.40,.14),'foot','foot_'+t_,'04_LEGS')
    box('Shin_'+t_,(x,0,.38),(.28,.30,.48),'shin','shin_'+t_,'04_LEGS')
    box('Thigh_'+t_,(x,0,.85),(.23,.25,.46),'mail','thigh_'+t_,'04_LEGS')

# ---------------- waist, belly, chest, head ----------------
box('Waist',(0,0,1.19),(.62,.36,.22),'waist','hips','01_BODY')
box('Buckle',(0,-.19,1.25),(.12,.03,.09),'gold','hips','01_BODY')
box('Belly',(0,0,1.40),(.54,.32,.20),'cloth','chest','01_BODY')
box('Chest',(0,0,1.70),(.70,.40,.40),'chest','chest','01_BODY')
box('Head',(0,-.01,2.13),(.44,.44,.46),'helm','head','02_HEAD')
box('TabardFront',(0,-.20,.88),(.24,.04,.58),'cloth','hips','06_CLOTH')
box('TabardBack',(0,.20,.86),(.30,.04,.62),'cloth','hips','06_CLOTH')

# ---------------- arms: shoulder cube joins the chest; thin mail arm, thick plate forearm, glove ----------------
ARM={}
for side,t_ in ((1,'l'),(-1,'r')):
    x=side*.505
    box('Shoulder_'+t_,(x,0,1.76),(.30,.36,.30),'shoulder','upper_arm_'+t_,'03_ARMS')
    if t_=='l': continue                    # the shield arm is built after the hunch, reaching forward
    ARM[t_]=[box('UpperArm_'+t_,(x,0,1.42),(.20,.22,.38),'mail','upper_arm_'+t_,'03_ARMS'),
             box('Forearm_'+t_,(x,0,1.04),(.28,.30,.38),'forearm','forearm_'+t_,'03_ARMS'),
             box('Hand_'+t_,(x,-.01,.76),(.22,.24,.18),'glove','hand_'+t_,'03_ARMS')]

# ---------------- tired old hero: hunch ----------------
# The trunk (belly, chest, shoulders, head) tips forward about the top of the waist; the head
# hangs a little more. The arms keep hanging straight down (dead weight): they only follow
# their shoulder joint. Gear is built afterwards from the moved hands.
from mathutils import Matrix
def rotate(objs,angle,pivot):
    R=Matrix.Rotation(math.radians(angle),4,'X'); P=Vector(pivot)
    for o in objs:
        for v in o.data.vertices: v.co=P+(R@(v.co-P))
        o.data.update()
    return R,P
def part(n): return next(o for o in parts if o['part']==n)
HUNCH_DEG=14; WAIST_TOP=(0,0,1.30); NECK=(0,0,1.90)
# Progressive bend like a spine (no rigid "sliding" step): belly half, chest full, head a bit more.
rotate([part('Head')],5,NECK)
rotate([part('Belly')],HUNCH_DEG/2,WAIST_TOP)
R,P=rotate([part(n) for n in ('Chest','Head','Shoulder_l','Shoulder_r')],HUNCH_DEG,WAIST_TOP)
HAND={}
for t_,side in (('r',-1),):
    J=Vector((side*.505,0,1.76)); d=(P+(R@(J-P)))-J
    for o in ARM[t_]:
        for v in o.data.vertices: v.co+=d
        o.data.update()
    HAND[t_]=Vector((side*.505,-.01,.76))+d

# ---------------- mace (right hand): long wooden haft, leather grip, square iron head resting on the ground ----------------
G=HAND['r']+Vector((0,-.01,.0)); D=Vector((-.22,-.42,-.88)).normalized()
HEAD_SIZE=.26
def head_min_z(L):
    c=G+D*L; u=(X-D*D.x).normalized(); v=D.cross(u)
    return min((c+u*sx*HEAD_SIZE/2+v*sy*HEAD_SIZE/2+D*sz*HEAD_SIZE/2).z for sx in (-1,1) for sy in (-1,1) for sz in (-1,1))
L=.70
L+=(head_min_z(L)-.004)/(-D.z)           # slide the head along the haft until it just rests on the ground
beam('MaceGrip',G-D*.12,G+D*.14,.085,.085,'grip','hand_r','05_GEAR',side=X)
beam('MaceHaft',G+D*.14,G+D*(L-HEAD_SIZE/2+.02),.075,.075,'haft','hand_r','05_GEAR',side=X)
beam('MaceHead',G+D*(L-HEAD_SIZE/2),G+D*(L+HEAD_SIZE/2),HEAD_SIZE,HEAD_SIZE,'iron_head','hand_r','05_GEAR',side=X)

# ---------------- shield arm reaching forward + tower shield held in guard ----------------
# Left arm: upper arm down and a little forward from the (hunched) shoulder, forearm nearly
# horizontal pointing forward, fist closed on a leather grip bar at the centre of the shield's
# back (tower-shield centre grip). The shield stands just in front of the fist, turned to the
# front-left: it is clearly HELD, not floating.
S=P+(R@(Vector((.505,0,1.62))-P))                   # top of the upper arm, under the shoulder cube
E=S+Vector((.0,-.10,-.34)); W=E+Vector((.02,-.34,.06)); F=(W-E).normalized()
beam('UpperArm_l',S,E,.20,.22,'mail','upper_arm_l','03_ARMS',side=X)
beam('Forearm_l',E-F*.04,W,.28,.30,'forearm','forearm_l','03_ARMS',side=X)
Hf=W+F*.17
beam('Hand_l',W,Hf,.22,.24,'glove','hand_l','03_ARMS',side=X)
th=math.radians(15); SA=Vector((math.cos(th),math.sin(th),0)); SB=Vector((-math.sin(th),math.cos(th),0))
NS=-SB                                               # shield front: towards the front-left
SC=Hf+NS*.045+SA*.02; SC.z=Hf.z-.05
fbox('ShieldSlab',SC,SA,SB,Z,(.48,.08,1.20),'shield','hand_l','05_GEAR')
fbox('ShieldRidge',SC-SB*.05+Z*.03,SA,SB,Z,(.07,.04,.96),'shield_ridge','hand_l','05_GEAR')
fbox('ShieldTop',SC+Z*.62,SA,SB,Z,(.52,.10,.05),'shield_ridge','hand_l','05_GEAR')
fbox('ShieldGrip',Hf-F*.05,SA,SB,Z,(.06,.07,.30),'grip','hand_l','05_GEAR')   # bar through the fist

# Hero scale: grow the whole figure about the origin (feet stay on the ground).
HERO_SCALE=1.12
for o in parts:
    for v in o.data.vertices: v.co*=HERO_SCALE
    o.data.update()

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

TARGET=Vector((0,-.05,1.30))
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
cam.type='ORTHO'; cam.ortho_scale=3.8; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static Corrupted Hero V1: tired old ragged knight, one block per body part (Troll/Minotaur logic), trunk hunched 14 deg, arms hanging; iron-block mace resting on the ground, tower shield left.'
scene['animations_requested']=False
bpy.app.driver_namespace['corrupted_hero']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET,'hero_scale':HERO_SCALE}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords),'min_z':min(c.z for c in coords),
        'y':[min(c.y for c in coords),max(c.y for c in coords)],'x':[min(c.x for c in coords),max(c.x for c in coords)]}
