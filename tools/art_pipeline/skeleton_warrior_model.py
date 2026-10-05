"""Static Skeleton Warrior, using the approved Troll/Goblin/Minotaur cuboid
language and metric UV (64 px/m). Run INSIDE Blender through the MCP client.
No rig or animation. Design units are scaled by S so the total height
(helmet included) is 1.85 m. Front = -Y, feet at Z=0. Every part records the
bone it must follow (obj['rig_bone']) so armour/cloth stay attached in a future rig.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Skeleton_Warrior_V1'; HEIGHT=1.85; DESIGN_TOP=2.0175; S=HEIGHT/DESIGN_TOP
OUT=ROOT/'assets/generated/skeletons/skeleton_warrior_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Skeleton scene exists; preserve manual edits.')
    old=bpy.data.scenes[NAME]
    for c in list(old.collection.children):
        for o in list(c.objects): bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(c)
    for o in list(old.collection.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
    for store in (bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.worlds,bpy.data.cameras,bpy.data.lights):
        for block in list(store):
            if block.name.startswith(NAME): store.remove(block)
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
collections={}
for label in ['01_BONES','02_SKULL','03_ARMOUR_CLOTH','04_SWORD','05_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,bone,collection='01_BONES',up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v)*S for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['rig_bone']=bone; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid or simple extruded prism; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def box(name,center,size,region,bone,collection='01_BONES',rot=(0,0,0)):
    # rot in degrees (XYZ). +X leans the top forward (-Y); +Y lowers the +X end.
    R=Euler([math.radians(a) for a in rot],'XYZ').to_matrix(); c=Vector(center); a,b,d=[v/2 for v in size]
    verts=[c+R@Vector((sx*a,sy*b,sz*d)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,R@Vector((0,0,1)))
def beam(name,start,end,width,depth,region,bone,collection='01_BONES'):
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector((0,1,0)).cross(axis).normalized(); v=axis.cross(u).normalized()
    verts=[c+u*x*width/2+v*y*depth/2 for c in (a,b) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,axis if axis.z>=0 else -axis)
def lerp(a,b,t): return tuple(x+(y-x)*t for x,y in zip(a,b))
def profile(name,points,yfun,thickness,region,bone,collection):
    n=len(points); verts=[(x,yfun(x,z)+offset,z) for offset in (0,thickness) for x,z in points]
    faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,region,bone,collection)
def slab(name,origin,e1,e2,outline,thickness,region,bone,collection,up):
    o=Vector(origin); n=e1.cross(e2).normalized(); k=len(outline)
    verts=[o+e1*s+e2*t+n*off for off in (-thickness/2,thickness/2) for s,t in outline]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
    faces += [(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection,up)

# Trunk: ribcage (chest), lumbar spine (belly), pelvis. Slight forward lean.
box('Ribcage',(0,.0,1.42),(.38,.23,.33),'ribs','chest',rot=(8,0,0))
beam('Spine',(0,.05,1.01),(0,.035,1.30),.08,.08,'spine','spine')
box('Pelvis',(0,.02,.96),(.31,.17,.13),'pelvis','pelvis')
beam('Neck',(0,.0,1.55),(0,-.03,1.67),.065,.065,'spine','head')
for side,suffix in [(1,'l'),(-1,'r')]:
    beam('Clavicle_'+suffix,(side*.03,-.115,1.565),(side*.24,-.03,1.585),.05,.05,'bone','chest')

# Skull: large for readability, separate jaw (mandible).
box('Skull',(0,-.05,1.785),(.32,.31,.29),'skull','head','02_SKULL')
box('Jaw',(0,-.105,1.622),(.25,.21,.075),'jaw','jaw','02_SKULL')
# Damaged, slightly askew rusty helmet: cap + rim band.
box('Helmet_Cap',(0,-.05,1.94),(.33,.32,.09),'rust','head','03_ARMOUR_CLOTH',rot=(0,5,0))
box('Helmet_Rim',(0,-.05,1.895),(.345,.335,.04),'rust_dark','head','03_ARMOUR_CLOTH',rot=(0,5,0))
# Short central comb, so the cap reads as an old soldier's helmet.
box('Helmet_Comb',(0,-.07,1.995),(.045,.24,.035),'rust_dark','head','03_ARMOUR_CLOTH',rot=(0,5,0))

for side,suffix in [(1,'l'),(-1,'r')]:
    X=lambda x:side*x
    # Arms: humerus head, upper arm, forearm, simplified hand (no fingers modelled).
    box('Shoulder_'+suffix,(X(.24),-.025,1.55),(.12,.13,.12),'bone','shoulder_'+suffix)
    beam('UpperArm_'+suffix,(X(.25),-.025,1.53),(X(.28),-.045,1.20),.085,.09,'bone','upper_arm_'+suffix)
    beam('Forearm_'+suffix,(X(.28),-.045,1.22),(X(.30),-.10,.93),.09,.095,'bone','forearm_'+suffix)
    if side==1: box('Hand_'+suffix,(X(.305),-.115,.865),(.11,.12,.13),'hand','hand_'+suffix)
    # Legs: thigh and shin meet directly (no separate knee block), simple feet.
    beam('Thigh_'+suffix,(X(.11),.02,.95),(X(.125),-.03,.50),.10,.105,'bone','thigh_'+suffix)
    beam('Shin_'+suffix,(X(.125),-.03,.53),(X(.125),.0,.06),.09,.095,'bone','shin_'+suffix)
    box('Foot_'+suffix,(X(.125),-.06,.04),(.14,.29,.08),'foot','foot_'+suffix)

# Broken pauldron on the LEFT shoulder only: two overlapping plates, outer lower.
box('Pauldron_Plate',(.255,-.025,1.625),(.18,.20,.045),'rust','shoulder_l','03_ARMOUR_CLOTH',rot=(0,24,0))
box('Pauldron_Lame',(.325,-.025,1.565),(.11,.18,.04),'rust_dark','shoulder_l','03_ARMOUR_CLOTH',rot=(0,48,0))
# Rusty bracer on the sword (right) forearm, greave on the left shin.
fa=((-.28,-.045,1.22),(-.30,-.10,.93))
beam('Bracer_r',lerp(*fa,.32),lerp(*fa,.86),.125,.13,'rust','forearm_r','03_ARMOUR_CLOTH')
sh=((.125,-.03,.53),(.125,.0,.06))
beam('Greave_l',lerp(*sh,.15),lerp(*sh,.62),.125,.13,'rust','shin_l','03_ARMOUR_CLOTH')

# Belt over the pelvis; torn faded tabard flaps tucked under it (front/back).
box('Belt',(0,.02,1.0),(.34,.25,.055),'leather','pelvis','03_ARMOUR_CLOTH')
box('Buckle',(.05,-.108,1.0),(.065,.02,.06),'rust_dark','pelvis','03_ARMOUR_CLOTH')
profile('TabardFront',[(-.13,1.01),(.13,1.01),(.13,.70),(.08,.64),(.04,.69),(-.01,.60),(-.06,.67),(-.10,.63),(-.13,.68)],
        lambda x,z:-.095-(1.01-z)*.26,.02,'cloth','tabard_front','03_ARMOUR_CLOTH')
profile('TabardBack',[(-.14,1.01),(.14,1.01),(.14,.74),(.07,.70),(.02,.75),(-.06,.69),(-.14,.73)],
        lambda x,z:.11+(1.01-z)*.20,.02,'cloth','tabard_back','03_ARMOUR_CLOTH')

# Right fist: one hollow cuboid with a channel aligned to the sword grip.
GRIP=Vector((-.305,-.115,.87)); AXIS=Vector((0,-.45,-.89)).normalized()
U=Vector((1,0,0)); V=AXIS.cross(U).normalized()    # V lies in the swing (YZ) plane
outer=[(-.056,-.062),(.056,-.062),(.056,.062),(-.056,.062)]
inner=[(-.021,-.021),(.021,-.021),(.021,.021),(-.021,.021)]
verts=[]
for depth in (-.062,.062):
    for ring in (outer,inner): verts += [GRIP+AXIS*depth+U*x+V*y for x,y in ring]
faces=[]
for i in range(4):
    k=(i+1)%4
    faces += [(i,k,k+8,i+8),(i+4,i+12,k+12,k+4),(i,i+4,k+4,k),(i+8,k+8,k+12,i+12)]
mesh('Hand_r',verts,faces,'hand','hand_r')

# Rusty, chipped arming sword. The blade's width runs along V, so its EDGE
# (not the flat) leads any swing in the sagittal plane.
beam('Sword_Pommel',GRIP-AXIS*.135,GRIP-AXIS*.085,.06,.06,'rust_dark','weapon','04_SWORD')
beam('Sword_Grip',GRIP-AXIS*.095,GRIP+AXIS*.095,.038,.038,'grip','weapon','04_SWORD')
mesh_guard=beam('Sword_Guard',GRIP+AXIS*.11-V*.115,GRIP+AXIS*.11+V*.115,.04,.034,'rust','weapon','04_SWORD')
blade=[(.042,0),(.041,.26),(.027,.29),(.040,.32),(.037,.58),(.022,.71),(0,.80),(-.024,.73),
       (-.035,.56),(-.040,.47),(-.029,.445),(-.041,.42),(-.042,0)]
b=slab('Sword_Blade',GRIP+AXIS*.125,V,AXIS,blade,.022,'blade','weapon','04_SWORD',-AXIS)
b['edge_dir']=list(V)

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
SIZE=256
if not pack(SIZE): SIZE=512; assert pack(SIZE), 'Metric atlas exceeds 512; never shrink islands to fit.'

# Studio identical in spirit to the approved review renders.
TARGET=Vector((0,-.05,.92))
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-3.5,-4.5,6.5),560,4,(1,.92,.81)),('Fill',(4.5,-2,4.5),280,4,(.78,.86,1)),('Rim',(0,3.5,5.5),640,3,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200/S,-200/S,-.004/S),(200/S,-200/S,-.004/S),(200/S,200/S,-.004/S),(-200/S,200/S,-.004/S)],[(0,1,2,3)],'studio','none','05_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=2.3; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static skeleton warrior: undead old soldier, blocky bones, damaged rusty helmet, broken left pauldron, right bracer, left greave, torn faded tabard, rusty chipped sword.'
scene['animations_requested']=False
bpy.app.driver_namespace['skeleton_warrior']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET,'scale':S}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'width_m':max(c.x for c in coords)-min(c.x for c in coords),'density_px_per_meter':DENSITY}
