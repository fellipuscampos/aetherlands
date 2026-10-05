"""Static Goblin raider, using the approved Troll's cuboid language and UV scale.
Run INSIDE Blender through the MCP client. No rig or animation is generated.
"""
import bpy
import bmesh
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Goblin_Raider_V3'; S=1.3/3.3
OUT=ROOT/'assets/generated/goblins/goblin_raider_v3'
SOURCE=ROOT/'art_source/goblin_raider_v3'
OUT.mkdir(parents=True,exist_ok=True); SOURCE.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').write_text('',encoding='utf-8')
if NAME in bpy.data.scenes: raise RuntimeError('Goblin scene exists; preserve manual edits.')
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
collections={}
for label in ['01_BODY','02_FACE_EARS','03_CLOTHING_LOOT','04_DAGGER','05_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
def mesh(name,verts,faces,region,collection='01_BODY',up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v)*S for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['paint_up']=list(up)
    obj['construction']='Flat cuboid or simple extruded prism; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def box(name,center,size,region,collection='01_BODY',angle=0):
    c=Vector(center); a,b,d=[v/2 for v in size]; verts=[]
    for sz in (-1,1):
        for sy in (-1,1):
            for sx in (-1,1):
                q=Vector((sx*a,sy*b,sz*d))
                q=Vector((math.cos(angle)*q.x+math.sin(angle)*q.z,q.y,-math.sin(angle)*q.x+math.cos(angle)*q.z))
                verts.append(c+q)
    return mesh(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],region,collection)
def beam(name,start,end,width,depth,region,collection='01_BODY'):
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector((0,1,0)).cross(axis).normalized(); v=axis.cross(u).normalized()
    verts=[c+u*x*width/2+v*y*depth/2 for c in (a,b) for y in (-1,1) for x in (-1,1)]
    up=axis if axis.z>=0 else -axis
    return mesh(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],region,collection,up)
def profile(name,points,yfun,thickness,region,collection):
    n=len(points); verts=[(x,yfun(x,z)+offset,z) for offset in (0,thickness) for x,z in points]
    faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,region,collection)

# Same structural division as Troll, but narrow waist, thin limbs and large head.
box('Chest',(0,.07,2.31),(.76,.47,.63),'chest')
box('Abdomen',(0,.01,1.81),(.53,.38,.37),'abdomen')
box('Pelvis',(0,.01,1.50),(.60,.43,.25),'rag','03_CLOTHING_LOOT')
box('UpperBack',(0,.19,2.58),(.57,.37,.17),'skin')
box('Head',(0,-.245,2.86),(.78,.60,.78),'face','02_FACE_EARS')
box('Muzzle_Jaw',(0,-.376,2.475),(.65,.46,.18),'jaw','02_FACE_EARS')
box('Mouth',(0,-.612,2.565),(.56,.018,.072),'mouth','02_FACE_EARS')
# Long narrow hooked nose: a single extruded side profile, not an orc snout.
# Extrusion along X makes a clean blade-like profile when viewed from the side.
nose_yz=[(-.52,2.965),(-.63,2.985),(-.99,2.67),(-1.035,2.555),
         (-.90,2.59),(-.66,2.80),(-.52,2.79)]
n=len(nose_yz)
verts=[(x,y,z) for x in (-.095,.095) for y,z in nose_yz]
faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh('Long_Hooked_Nose',verts,faces,'nose','02_FACE_EARS')
for side,suffix in [(1,'l'),(-1,'r')]:
    # Broad attached roots, very long lateral points, and an asymmetric notch.
    outline=[(side*.345,2.76),(side*.54,2.79),(side*1.025,3.22),
             (side*1.02,3.30),(side*.52,3.105),(side*.345,3.08)]
    profile('Long_Ear_'+suffix,outline,lambda x,z:-.33+(abs(x)-.345)*.19,.12,'ear','02_FACE_EARS')
    box('Brow_'+suffix,(side*.224,-.567,2.966),(.33,.07,.095),'brow','02_FACE_EARS',side*-.19)
    # Small uneven teeth in mouth, not the Troll's oversized tusks.
    box('Tooth_'+suffix,(side*(.17 if side==1 else .235),-.630,2.555),
        (.060,.035,.070 if side==1 else .05),'bone','02_FACE_EARS')
    shoulder=(side*.46,.055,2.44); elbow=(side*.61,-.005,1.99); wrist=(side*.69,-.11,1.52)
    box('Shoulder_'+suffix,(side*.465,.055,2.455),(.29,.40,.27),'skin')
    beam('UpperArm_'+suffix,shoulder,elbow,.20,.245,'limb')
    box('Elbow_'+suffix,elbow,(.17,.19,.16),'skin')
    beam('Forearm_'+suffix,(side*.614,-.005,2.025),wrist,.235,.27,'limb')
    if side==1: box('Hand_'+suffix,(side*.703,-.13,1.398),(.28,.32,.255),'hand')
    hip=(side*.18,.01,1.39); knee=(side*.235,-.05,.89); ankle=(side*.255,.025,.23)
    beam('Thigh_'+suffix,hip,knee,.24,.29,'limb')
    box('Knee_'+suffix,knee,(.195,.235,.15),'skin')
    beam('Shin_'+suffix,(side*.236,-.04,.94),ankle,.19,.23,'limb')
    box('Foot_'+suffix,(side*.258,-.15,.115),(.325,.57,.23),'boot','03_CLOTHING_LOOT')
    # One coarse ankle wrapping per leg, no tiny belts or detailed fingers.
    box('AnkleWrap_'+suffix,(side*.255,.025,.31),(.214,.254,.14),'wrap','03_CLOTHING_LOOT')

box('Belt',(0,.01,1.625),(.65,.47,.105),'belt','03_CLOTHING_LOOT')
box('BeltKnot',(-.13,-.248,1.622),(.14,.045,.10),'wrap','03_CLOTHING_LOOT')
profile('RagFront',[(-.28,1.585),(.25,1.585),(.25,1.16),(.09,1.16),(.09,1.20),(-.08,1.20),(-.08,1.12),(-.28,1.12)],
        lambda x,z:-.22-(1.58-z)*.33,.032,'rag','03_CLOTHING_LOOT')
profile('RagBack',[(-.28,1.575),(.28,1.575),(.28,1.20),(.02,1.20),(.02,1.16),(-.28,1.16)],
        lambda x,z:.23+(1.58-z)*.20,.032,'rag','03_CLOTHING_LOOT')
# Narrow diagonal vest strap leaves most of the thin green torso readable.
beam('ChestStrap',(-.285,-.190,2.58),(.245,-.213,1.67),.115,.035,'belt','03_CLOTHING_LOOT')
strap_path=[(-.285,.332,2.58),(.050,.332,2.005),(.079,.225,1.955),(.245,.247,1.67)]
strap_side=Vector((.91,0,.53)).normalized()
verts=[Vector(c)+strap_side*x*.0575+Vector((0,y*.0175,0))
       for c in strap_path for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
faces=[(3,2,1,0)]
for j in range(len(strap_path)-1):
    faces.extend([(j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i) for i in range(4)])
faces.append((12,13,14,15))
mesh('BackStrap',verts,faces,'belt','03_CLOTHING_LOOT',(-.53,0,.91))

# Loot bag on the left hip, tucked between forearm and body. Pale leather differs
# from the dark belt; two visible square gold edges identify stolen coins.
box('Loot_Pouch',(.47,.045,1.445),(.30,.31,.35),'pouch','03_CLOTHING_LOOT')
box('Loot_Pouch_Flap',(.47,-.123,1.545),(.32,.045,.16),'pouch_flap','03_CLOTHING_LOOT')
box('Loot_Pouch_Neck',(.47,.04,1.662),(.22,.235,.095),'belt','03_CLOTHING_LOOT')
box('Loot_Gold_01',(.405,.005,1.73),(.105,.05,.065),'gold','03_CLOTHING_LOOT',-.14)
box('Loot_Gold_02',(.535,.025,1.735),(.085,.06,.070),'gold','03_CLOTHING_LOOT',.20)
box('Loot_Tie',(.47,-.153,1.547),(.066,.026,.063),'wrap','03_CLOTHING_LOOT')
for obj in parts:
    if obj['part'].startswith('Loot_'):
        for vertex in obj.data.vertices: vertex.co+=Vector((-.07,-.18,0))*S
        obj.data.update()

# Right fist and simple salvaged dagger share a real grip axis.
grip=Vector((-.703,-.13,1.402)); axis=Vector((-.16,-.69,-.71)).normalized()
u=Vector((1,0,0)); u=(u-axis*u.dot(axis)).normalized(); v=axis.cross(u).normalized()
outer=[(-.14,-.13),(.14,-.13),(.14,.13),(-.14,.13)]
inner=[(-.046,-.046),(.046,-.046),(.046,.046),(-.046,.046)]
verts=[]
for depth in (-.155,.155):
    for ring in (outer,inner): verts += [grip+axis*depth+u*x+v*y for x,y in ring]
faces=[]
for i in range(4):
    k=(i+1)%4
    faces += [(i,k,k+8,i+8),(i+4,i+12,k+12,k+4),(i,i+4,k+4,k),(i+8,k+8,k+12,i+12)]
mesh('Hand_r',verts,faces,'hand')
beam('Dagger_Grip',grip-axis*.19,grip+axis*.25,.081,.081,'belt','04_DAGGER')
beam('Dagger_Guard',grip+axis*.20-u*.14,grip+axis*.20+u*.14,.055,.08,'iron','04_DAGGER')
verts=[]
for distance,width in [(.25,.115),(.55,.09),(.83,.005)]:
    center=grip+axis*distance
    verts += [center+u*x*width+v*y*.025 for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
faces=[(3,2,1,0)]
for j in range(2): faces.extend([(j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i) for i in range(4)])
faces.append((8,9,10,11))
mesh('Dagger_Blade',verts,faces,'blade','04_DAGGER',-axis)

# Exact metric projection, matching the Troll: 64 px per Blender meter.
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
        islands.append({'obj':obj,'polygon':p.index,'coords':co,'normal':normal,
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
if not pack(SIZE): SIZE=512; assert pack(SIZE)

# Soft studio with the same palette as the approved Troll's review renders.
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-3,-4,6),430,4,(1,.92,.81)),('Fill',(4,-2,4),220,4,(.78,.86,1)),('Rim',(0,3,5),500,3,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,(0,0,.65))
floor=mesh('StudioGround',[(-200,-200,-.022),(200,-200,-.022),(200,200,-.022),(-200,200,-.022)],[(0,1,2,3)],'studio','05_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=1.75; camera.location=(3,-6,2.8); aim(camera,(0,-.03,.65)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static green goblin raider. Approved Troll block construction, thin limbs, large head, long nose and ears, loot pouch, crude dagger.'
scene['animations_requested']=False
bpy.app.driver_namespace['goblin_raider']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'source':str(SOURCE),'scale':S}
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'target_height_m':1.3,'density_px_per_meter':64,'animations':0,'rig':False}
