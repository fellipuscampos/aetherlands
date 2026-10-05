"""Static Minotaur, using the approved Troll/Goblin cuboid language and UV scale.
Run INSIDE Blender through the MCP client. No rig or animation is generated.
Coordinates are real meters (front = -Y, feet at Z=0). Prepend REBUILD=True to
discard an existing unpainted scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Minotaur_Blocky_V1'
OUT=ROOT/'assets/generated/minotaurs/minotaur_blocky_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Minotaur scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD_HORNS','03_GEAR','04_LABRYS','05_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,collection='01_BODY',up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid or simple extruded prism; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def box(name,center,size,region,collection='01_BODY',rot=(0,0,0)):
    # rot in degrees (XYZ). +X rotation leans the top of the block forward (-Y).
    R=Euler([math.radians(a) for a in rot],'XYZ').to_matrix(); c=Vector(center); a,b,d=[v/2 for v in size]
    verts=[c+R@Vector((sx*a,sy*b,sz*d)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,CUBE,region,collection,R@Vector((0,0,1)))
def beam(name,start,end,width,depth,region,collection='01_BODY',end_width=None,end_depth=None):
    # Straight or tapered cuboid along start->end. Tapered sides stay planar.
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector((0,1,0)).cross(axis).normalized(); v=axis.cross(u).normalized()
    ew=width if end_width is None else end_width; ed=depth if end_depth is None else end_depth
    verts=[c+u*x*w/2+v*y*d/2 for c,w,d in ((a,width,depth),(b,ew,ed)) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,collection,axis if axis.z>=0 else -axis)
def profile(name,points,yfun,thickness,region,collection):
    n=len(points); verts=[(x,yfun(x,z)+offset,z) for offset in (0,thickness) for x,z in points]
    faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,region,collection)
def slab(name,origin,e1,e2,outline,thickness,region,collection,up):
    o=Vector(origin); e1=Vector(e1).normalized(); e2=Vector(e2).normalized(); n=e1.cross(e2).normalized(); k=len(outline)
    verts=[o+e1*s+e2*t+n*off for off in (-thickness/2,thickness/2) for s,t in outline]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
    faces += [(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,collection,up)

# Trunk: same division as Troll (chest / abdomen / pelvis), but hunched forward
# with a bull hump rising behind the head instead of a neck.
box('Pelvis',(0,.03,1.13),(.64,.44,.24),'cloth','03_GEAR')
box('Abdomen',(0,-.02,1.42),(.70,.42,.36),'abdomen',rot=(6,0,0))
box('Chest',(0,-.06,1.86),(1.05,.62,.62),'chest',rot=(14,0,0))
box('Hump',(0,.07,2.13),(.80,.46,.26),'hump',rot=(18,0,0))

# Bovine head pushed forward and down; muzzle and jaw are separate blocks.
box('Head',(0,-.44,2.19),(.50,.50,.46),'head','02_HEAD_HORNS')
box('Muzzle',(0,-.79,2.07),(.38,.32,.26),'muzzle','02_HEAD_HORNS')
box('Jaw',(0,-.645,1.895),(.34,.43,.09),'jaw','02_HEAD_HORNS')
box('Forelock',(0,-.56,2.445),(.26,.22,.07),'fur_dark','02_HEAD_HORNS')
# Square iron nose ring in front of the muzzle, hanging past the jaw line.
for side,suffix in [(1,'l'),(-1,'r')]:
    beam('NoseRing_'+suffix,(side*.058,-.962,2.035),(side*.058,-.962,1.855),.024,.03,'iron','02_HEAD_HORNS')
box('NoseRing_Bottom',(0,-.962,1.858),(.14,.03,.024),'iron','02_HEAD_HORNS')
box('NoseRing_Top',(0,-.962,2.032),(.14,.03,.024),'iron','02_HEAD_HORNS')

for side,suffix in [(1,'l'),(-1,'r')]:
    X=lambda x:side*x
    # Angry brows: inner ends lower. Bovine ears droop sideways under the horns.
    box('Brow_'+suffix,(X(.12),-.705,2.335),(.18,.05,.055),'brow','02_HEAD_HORNS',rot=(0,side*-14,0))
    box('Ear_'+suffix,(X(.32),-.37,2.25),(.20,.08,.09),'ear','02_HEAD_HORNS',rot=(0,side*20,0))
    # Large horns: four tapered segments sweeping out, up and forward.
    pts=[(X(.13),-.40,2.37),(X(.36),-.40,2.44),(X(.56),-.43,2.53),(X(.68),-.50,2.65),(X(.71),-.59,2.77)]
    widths=[.16,.15,.125,.095,.05]
    for i in range(4):
        a,b=Vector(pts[i]),Vector(pts[i+1]); d=(b-a).normalized()
        h=beam('Horn_%s%d'%(suffix,i),a-d*.035,b,widths[i],widths[i],'horn','02_HEAD_HORNS',widths[i+1],widths[i+1])
        h['horn_segment']=i
    box('HornBase_'+suffix,(X(.20),-.40,2.40),(.17,.19,.10),'fur_dark','02_HEAD_HORNS')

    # Heavy arms: shoulder, upper arm, elbow, thicker forearm, iron bracer, fist.
    box('Shoulder_'+suffix,(X(.70),-.05,2.02),(.44,.52,.42),'shoulder')
    beam('UpperArm_'+suffix,(X(.72),-.05,1.95),(X(.81),-.13,1.50),.30,.34,'upper_arm')
    box('Elbow_'+suffix,(X(.81),-.13,1.50),(.27,.31,.18),'skin')
    beam('Forearm_'+suffix,(X(.81),-.13,1.54),(X(.86),-.23,1.04),.35,.38,'forearm')
    beam('Bracer_'+suffix,(X(.834),-.178,1.30),(X(.858),-.226,1.07),.39,.42,'iron','03_GEAR')
    if side==1: box('Hand_'+suffix,(X(.865),-.25,.92),(.31,.34,.30),'hand')

    # Legs end in cloven hooves with an iron band at the fetlock.
    beam('Thigh_'+suffix,(X(.22),.05,1.10),(X(.25),-.06,.60),.30,.34,'thigh')
    box('Knee_'+suffix,(X(.25),-.06,.60),(.26,.29,.16),'skin')
    beam('Shin_'+suffix,(X(.25),-.05,.64),(X(.27),.03,.14),.24,.27,'shin')
    box('AnkleBand_'+suffix,(X(.27),.03,.26),(.275,.305,.075),'iron','03_GEAR')
    box('Hoof_'+suffix,(X(.27),-.02,.09),(.29,.38,.18),'hoof')

# Belt holds the crimson loincloth flaps underneath it; iron buckle plate.
box('Belt',(0,.03,1.235),(.72,.58,.10),'belt','03_GEAR')
box('Buckle',(0,-.266,1.235),(.17,.04,.13),'iron','03_GEAR')
profile('LoinFront',[(-.24,1.25),(.24,1.25),(.24,.85),(.14,.79),(.06,.85),(-.02,.76),(-.10,.83),(-.18,.79),(-.24,.85)],
        lambda x,z:-.24-(1.25-z)*.32,.03,'cloth','03_GEAR')
profile('LoinBack',[(-.28,1.25),(.28,1.25),(.28,.90),(.12,.86),(.03,.92),(-.12,.85),(-.28,.90)],
        lambda x,z:.27+(1.25-z)*.22,.03,'cloth','03_GEAR')
# Bull tail over the back flap, ending in a dark tuft.
beam('Tail',(0,.30,1.17),(0,.47,.80),.07,.07,'tail')
box('TailTuft',(0,.475,.72),(.11,.11,.18),'fur_dark')

# Right fist: single hollow cuboid with a channel aligned to the labrys haft.
grip=Vector((-.865,-.25,.92)); axis=Vector((0,-.60,-.80)).normalized()
u=Vector((1,0,0)); v=axis.cross(u).normalized()
outer=[(-.155,-.17),(.155,-.17),(.155,.17),(-.155,.17)]
inner=[(-.046,-.046),(.046,-.046),(.046,.046),(-.046,.046)]
verts=[]
for depth in (-.15,.15):
    for ring in (outer,inner): verts += [grip+axis*depth+u*x+v*y for x,y in ring]
faces=[]
for i in range(4):
    k=(i+1)%4
    faces += [(i,k,k+8,i+8),(i+4,i+12,k+12,k+4),(i,i+4,k+4,k),(i+8,k+8,k+12,i+12)]
mesh('Hand_r',verts,faces,'hand')

# Labrys (double-bit war axe) hanging forward/down from the grip, like the
# Troll's club and Goblin's dagger: never inside the forearm.
beam('Labrys_Haft',grip-axis*.24,grip+axis*1.02,.085,.085,'wood','04_LABRYS')
beam('Labrys_Pommel',grip-axis*.31,grip-axis*.22,.12,.12,'iron','04_LABRYS')
beam('Labrys_Cap',grip+axis*1.00,grip+axis*1.07,.11,.11,'iron','04_LABRYS')
for start,end in [(.17,.23),(.26,.32)]:
    beam('Labrys_Wrap_%d'%round(start*100),grip+axis*start,grip+axis*end,.097,.097,'wrap','04_LABRYS')
head=grip+axis*.84
beam('Labrys_Socket',head-axis*.14,head+axis*.14,.135,.135,'iron_dark','04_LABRYS')
bit=[(.05,-.09),(.15,-.12),(.29,-.22),(.36,-.20),(.36,.20),(.29,.22),(.15,.12),(.05,.09)]
for sign,suffix in [(1,'A'),(-1,'B')]:
    outline=[(sign*s,t) for s,t in bit]
    if sign<0: outline.reverse()
    blade=slab('Labrys_Blade_'+suffix,head,u,axis,outline,.05,'blade','04_LABRYS',-axis)
    blade['edge_dir']=list(u*sign)

# Exact metric projection, matching Troll/Goblin: 64 px per Blender meter.
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

# Studio identical in spirit to the Troll/Goblin review renders.
TARGET=Vector((0,-.15,1.30))
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6.5,8),1200,6,(1,.92,.81)),('Fill',(6.5,-3,6),600,6,(.78,.86,1)),('Rim',(0,5,8),1350,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','05_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=3.25; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static minotaur brute. Troll/Goblin block construction, hunched bull body, large horns, hooves, crimson loincloth, iron bracers, labrys.'
scene['animations_requested']=False
bpy.app.driver_namespace['minotaur_blocky']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'width_m':max(c.x for c in coords)-min(c.x for c in coords),'density_px_per_meter':DENSITY}
