"""Static Basilisk (mythic rooster + serpent hybrid), using the approved cuboid
language and metric UV (64 px/m) of Troll/Goblin/Minotaur/Skeleton/Warg.
Run INSIDE Blender through the MCP client. No rig or animation. Real meters,
front = -Y, feet at Z=0. Every part records the single bone it must follow
(obj['rig_bone']) for a future rig. Prepend REBUILD=True to discard an existing
(unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Basilisk_Blocky_V1'
OUT=ROOT/'assets/generated/basilisks/basilisk_blocky_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Basilisk scene exists; preserve manual edits.')
    old=bpy.data.scenes[NAME]
    for c in list(old.collection.children):
        for o in list(c.objects): bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(c)
    for o in list(old.collection.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
    for store in (bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.worlds,bpy.data.cameras,bpy.data.lights):
        for block in list(store):
            if block.name.startswith(NAME+'_'): store.remove(block)
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
collections={}
for label in ['01_BODY','02_HEAD','03_LEGS','04_FEATHERS','05_TAIL','06_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,bone,collection='01_BODY',up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['rig_bone']=bone; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid or simple extruded prism; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def box(name,center,size,region,bone,collection='01_BODY',rot=(0,0,0)):
    # rot in degrees (XYZ). +X tips the front (-Y) end down; +Y lowers the +X end.
    R=Euler([math.radians(a) for a in rot],'XYZ').to_matrix(); c=Vector(center); a,b,d=[v/2 for v in size]
    verts=[c+R@Vector((sx*a,sy*b,sz*d)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,R@Vector((0,0,1)))
def beam(name,start,end,width,depth,region,bone,collection='01_BODY',end_width=None,end_depth=None,up=None):
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector((0,1,0)).cross(axis)
    if u.length<1e-6: u=Vector((1,0,0))
    u.normalize(); v=axis.cross(u).normalized()
    ew=width if end_width is None else end_width; ed=depth if end_depth is None else end_depth
    verts=[c+u*x*w/2+v*y*d/2 for c,w,d in ((a,width,depth),(b,ew,ed)) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,up or (axis if axis.z>=0 else -axis))
def prism_x(name,outline_yz,x_center,thickness,region,bone,collection):
    k=len(outline_yz); verts=[(x_center+off,y,z) for off in (-thickness/2,thickness/2) for y,z in outline_yz]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
    faces += [(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection)

def prism_y(name,outline_xz,y_center,thickness,region,bone,collection):
    k=len(outline_xz); verts=[(x,y_center+off,z) for off in (-thickness/2,thickness/2) for x,z in outline_xz]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
    faces += [(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection)

# V2 (after review). Plumage (body, breast, thighs, wings, hackles, plumes) vs reptile
# (head, upper neck, throat, tail, legs) is a hard material split; the head is a
# viper skull with a rooster comb; wings are three layered feather plates; a tapered
# rump bridges the bird body into the serpent tail.

# Body: tilted bird torso, projecting breast with a ragged feather ruff.
box('Body',(0,.02,1.05),(.62,.80,.58),'body','body',rot=(-18,0,0))
box('Breast',(0,-.40,1.04),(.54,.30,.50),'breast','body',rot=(-22,0,0))
prism_y('BreastRuff',[(-.22,.96),(.22,.96),(.22,.76),(.15,.69),(.08,.76),(0,.66),(-.08,.76),(-.15,.69),(-.22,.76)],
        -.62,.05,'ruff','body','04_FEATHERS')
# Rump: the body tapers into the tail; feathers end on it with a ragged edge, scales begin.
beam('Rump',(0,.28,1.02),(0,.66,.86),.50,.46,'rump','tail_01','05_TAIL',.32,.30)

# Long S neck: feathered base (hackle collar), scaly upper neck and throat.
beam('Neck_Low',(0,-.40,1.24),(0,-.54,1.56),.26,.28,'neck_low','neck_01')
beam('Neck_High',(0,-.55,1.52),(0,-.52,1.84),.22,.24,'neck_high','neck_02')
prism_y('Hackle_Back',[(-.17,1.62),(.17,1.62),(.17,1.36),(.10,1.29),(.04,1.37),(-.03,1.27),(-.10,1.36),(-.17,1.30)],
        -.29,.05,'hackle','neck_01','04_FEATHERS')

# Viper skull pitched down at the target, wide jaw hinges, rooster comb on top.
box('Head',(0,-.58,1.93),(.26,.32,.22),'head','head','02_HEAD',rot=(12,0,0))
box('JawHinge',(0,-.50,1.85),(.32,.16,.14),'head','head','02_HEAD',rot=(12,0,0))
beam('Beak_Upper',(0,-.72,1.93),(0,-.91,1.83),.16,.13,'beak','head','02_HEAD',.06,.06)
beam('Beak_Hook',(0,-.89,1.85),(0,-.93,1.75),.06,.06,'beak_tip','head','02_HEAD',.025,.025)
beam('Beak_Lower',(0,-.70,1.80),(0,-.86,1.66),.15,.06,'jaw','jaw','02_HEAD',.06,.04)
beam('Tongue',(0,-.78,1.79),(0,-.97,1.72),.025,.02,'tongue','jaw','02_HEAD')
prism_x('Comb',[(-.72,2.0),(-.44,2.05),(-.40,2.18),(-.46,2.15),(-.48,2.27),(-.54,2.19),(-.58,2.31),(-.63,2.20),(-.68,2.25),(-.72,2.12)],
        0,.05,'comb','head','02_HEAD')
prism_x('Wattle',[(-.62,1.79),(-.70,1.78),(-.72,1.65),(-.66,1.59),(-.61,1.67)],0,.06,'comb','jaw','02_HEAD')
for side,suffix in [(1,'l'),(-1,'r')]:
    X=lambda x:side*x
    # Glowing venom eye set in the skull side, facing slightly forward; ONE brow ridge
    # directly above it, sloping down towards the beak (angry), overhanging the eye.
    box('Eye_'+suffix,(X(.122),-.69,1.95),(.03,.115,.07),'eye','head','02_HEAD',rot=(12,0,side*-30))
    box('Brow_'+suffix,(X(.115),-.69,2.012),(.085,.18,.045),'brow','head','02_HEAD',rot=(24,0,side*-30))
    beam('Fang_'+suffix,(X(.05),-.80,1.87),(X(.05),-.80,1.76),.032,.032,'fang','head','02_HEAD',.01,.01,up=(0,0,1))
    beam('TongueFork_'+suffix,(X(.006),-.96,1.725),(X(.035),-1.03,1.705),.018,.016,'tongue','jaw','02_HEAD')
    prism_x('Hackle_'+suffix,[(-.64,1.66),(-.46,1.56),(-.30,1.36),(-.30,1.22),(-.36,1.29),(-.42,1.18),(-.48,1.27),(-.55,1.18),(-.60,1.31),(-.66,1.42)],
            X(.145),.05,'hackle','neck_01','04_FEATHERS')
    # Folded wing: coverts, secondaries and long primaries layered outwards and backwards.
    prism_x('WingCoverts_'+suffix,[(-.28,1.30),(.02,1.28),(.20,1.18),(.16,1.12),(.10,1.16),(.06,1.10),(-.02,1.14),(-.08,1.08),(-.16,1.13),(-.26,1.16)],
            X(.330),.05,'wing_coverts','wing_'+suffix,'04_FEATHERS')
    prism_x('WingSecondaries_'+suffix,[(-.20,1.20),(.10,1.18),(.32,1.04),(.26,.98),(.20,1.02),(.14,.95),(.06,1.00),(-.02,.94),(-.10,1.00),(-.18,1.04)],
            X(.352),.045,'wing_secondaries','wing_'+suffix,'04_FEATHERS')
    prism_x('WingPrimaries_'+suffix,[(-.05,1.10),(.20,1.06),(.48,.90),(.52,.84),(.42,.86),(.44,.80),(.32,.85),(.30,.78),(.18,.86),(.02,.94)],
            X(.372),.04,'wing_primaries','wing_'+suffix,'04_FEATHERS')

    # Raptor legs: feathered drumstick, long scaly tarsus, three clawed toes, rooster spur.
    dy=-.06*side
    # Outer face sits 1.5 cm outside the body side: coplanar faces z-fight (black patches).
    box('Thigh_'+suffix,(X(.225),.10,.80),(.20,.30,.36),'thigh','thigh_'+suffix,'03_LEGS',rot=(22,0,0))
    beam('Tarsus_'+suffix,(X(.23),.20,.66),(X(.25),.02+dy,.07),.09,.10,'tarsus','tarsus_'+suffix,'03_LEGS')
    beam('Spur_'+suffix,(X(.235),.15+dy*.6,.33),(X(.24),.27+dy*.6,.26),.045,.045,'claw','tarsus_'+suffix,'03_LEGS',.012,.012)
    box('Foot_'+suffix,(X(.25),.0+dy,.03),(.14,.14,.06),'foot','foot_'+suffix,'03_LEGS')
    for name,(ex,ey) in [('Mid',(0,-.30)),('Out',(.14,-.24)),('In',(-.11,-.25))]:
        beam('Toe%s_%s'%(name,suffix),(X(.25),-.03+dy,.03),(X(.25+ex),ey+dy,.025),.055,.05,'toe','foot_'+suffix,'03_LEGS',.035,.035)

# Rooster sickle feathers arching off the rump.
prism_x('Plume_A',[(.40,1.10),(.54,1.36),(.74,1.48),(.96,1.40),(1.07,1.20),(.96,1.25),(.80,1.32),(.62,1.24),(.50,1.04)],.05,.04,'plume','tail_01','04_FEATHERS')
prism_x('Plume_B',[(.38,1.04),(.50,1.26),(.68,1.34),(.86,1.26),(.94,1.10),(.84,1.14),(.70,1.20),(.56,1.14),(.46,.99)],-.05,.04,'plume','tail_01','04_FEATHERS')

# Serpent tail continues from the rump, falls to the ground and snakes sideways in an S.
tail=[((0,.62,.88),(0,.94,.58),.30,.24),((0,.90,.60),(.10,1.25,.30),.24,.19),((.08,1.22,.32),(.30,1.55,.12),.19,.14),
      ((.28,1.52,.12),(.10,1.88,.08),.14,.10),((.12,1.85,.08),(-.20,2.12,.10),.10,.035)]
for i,(a,b,w0,w1) in enumerate(tail):
    beam('Tail_%d'%(i+1),a,b,w0,w0,'tail','tail_%02d'%(i+2),'05_TAIL',w1,w1)

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

TARGET=Vector((0,.50,1.0))
studio=collections['06_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-4,-5,7.5),900,5,(1,.92,.81)),('Fill',(5.5,-2,5.5),440,5,(.78,.86,1)),('Rim',(0,6,6.5),1000,4,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','06_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=3.6; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static basilisk V2: rooster + serpent hybrid, viper skull, plumage vs scales split, layered folded wings, rump-to-tail transition. Reared S neck, comb and wattle, hooked beak with fangs, venom eyes, hackle and wing feather plates, sickle plumes, raptor legs with spurs, long serpent tail.'
scene['animations_requested']=False
bpy.app.driver_namespace['basilisk']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'length_m':max(c.y for c in coords)-min(c.y for c in coords),'width_m':max(c.x for c in coords)-min(c.x for c in coords)}
