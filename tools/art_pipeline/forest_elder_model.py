"""Static Forest Elder ("Ancião Arbóreo"), a Curupira-inspired forest spirit, using the
approved cuboid language and metric UV (64 px/m) of the bestiary. Run INSIDE Blender
through the MCP client. Real meters, front = -Y, feet at Z=0. Feet point BACKWARDS
(heel in front, root-claw toes behind). Every part records the single bone it must
follow (obj['rig_bone']); forest_elder_rig.py builds the rig from these.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Forest_Elder_V1'
OUT=ROOT/'assets/generated/forest_elders/forest_elder_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Forest Elder scene exists; preserve manual edits.')
    old=bpy.data.scenes[NAME]
    for c in list(old.collection.children):
        for o in list(c.objects): bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(c)
    for o in list(old.collection.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
    for store in (bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.worlds,bpy.data.cameras,bpy.data.lights,bpy.data.armatures):
        for block in list(store):
            if block.name.startswith(NAME+'_'): store.remove(block)
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
collections={}
for label in ['01_BODY','02_HEAD_CROWN','03_LIMBS','04_RITUAL','05_STUDIO']:
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
    # rot in degrees (XYZ). +X leans the top forward (-Y).
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
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection)
def prism_y(name,outline_xz,y_center,thickness,region,bone,collection):
    k=len(outline_xz); verts=[(x,y_center+off,z) for off in (-thickness/2,thickness/2) for x,z in outline_xz]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection)

# Trunk of old wood: broad chest leaning slightly forward, narrower abdomen, pelvis.
box('Chest',(0,.0,1.92),(.86,.52,.62),'bark','chest',rot=(6,0,0))
box('Abdomen',(0,.02,1.46),(.62,.42,.40),'bark','spine',rot=(3,0,0))
box('Pelvis',(0,.02,1.17),(.66,.44,.26),'bark','pelvis')

# Head: wood block wearing a carved spirit MASK; one carved brow ridge directly above
# the glowing eyes; a root-and-moss beard; a crown of flame-leaves (Curupira's red hair).
box('Head',(0,-.06,2.40),(.46,.42,.46),'bark','head','02_HEAD_CROWN')
box('Mask',(0,-.29,2.38),(.42,.06,.40),'mask','head','02_HEAD_CROWN')
box('Brow',(0,-.335,2.47),(.44,.08,.07),'mask_dark','head','02_HEAD_CROWN')
prism_y('Beard',[(-.18,2.20),(.18,2.20),(.16,2.02),(.10,1.94),(.05,2.00),(0,1.90),(-.05,1.99),(-.10,1.93),(-.16,2.03)],
        -.31,.05,'beard','head','02_HEAD_CROWN')
prism_x('Crown_Center',[(-.20,2.60),(.20,2.60),(.24,2.78),(.14,2.74),(.16,2.92),(.06,2.84),(.04,3.06),(-.04,2.88),(-.10,2.96),(-.12,2.80),(-.20,2.84)],
        0,.12,'crown','head','02_HEAD_CROWN')
# Front-facing flame crest so the red crown also reads from the front / game camera.
prism_y('Crown_Front',[(-.28,2.58),(.28,2.58),(.30,2.76),(.22,2.70),(.20,2.88),(.12,2.78),(.08,2.98),(.02,2.84),(-.04,3.02),(-.10,2.82),(-.16,2.92),(-.20,2.74),(-.28,2.80)],
        .0,.08,'crown','head','02_HEAD_CROWN')
for side,suffix in [(1,'l'),(-1,'r')]:
    X=lambda x:side*x
    prism_x('Crown_Mid_'+suffix,[(-.16,2.58),(.18,2.58),(.20,2.74),(.12,2.70),(.10,2.86),(.02,2.76),(-.04,2.90),(-.08,2.74),(-.16,2.76)],
            X(.13),.10,'crown','head','02_HEAD_CROWN')
    prism_x('Crown_Side_'+suffix,[(-.10,2.50),(.18,2.50),(.22,2.66),(.14,2.62),(.10,2.76),(.02,2.66),(-.06,2.72),(-.10,2.60)],
            X(.235),.07,'crown','head','02_HEAD_CROWN')

    # Arms: mossy shoulder, long bark arms, big hands with branch-claw fingers.
    box('Shoulder_'+suffix,(X(.58),.0,2.10),(.36,.42,.34),'bark_moss','shoulder_'+suffix,'03_LIMBS')
    beam('UpperArm_'+suffix,(X(.60),.0,2.00),(X(.72),-.08,1.52),.22,.24,'bark','upper_arm_'+suffix,'03_LIMBS')
    beam('Forearm_'+suffix,(X(.72),-.08,1.54),(X(.805),-.19,.97),.25,.27,'bark_runes','forearm_'+suffix,'03_LIMBS')   # sinks into the hand: no gap at the wrist
    box('Hand_'+suffix,(X(.81),-.20,.92),(.26,.30,.20),'bark','hand_'+suffix,'03_LIMBS')
    for k,(dx,dy) in enumerate(((-.08,-.06),(0,-.09),(.08,-.06))):
        beam('Finger%d_%s'%(k,suffix),(X(.81+dx),-.20+dy,.86),(X(.81+dx*1.8),-.20+dy*1.6-.06,.52),.07,.07,'branch','hand_'+suffix,'03_LIMBS',.025,.025)
    beam('Thumb_'+suffix,(X(.71),-.30,.92),(X(.66),-.44,.72),.06,.06,'branch','hand_'+suffix,'03_LIMBS',.02,.02)

    # Legs ending in BACKWARD feet: heel in front, root-claw toes pointing back.
    beam('Thigh_'+suffix,(X(.22),.02,1.10),(X(.26),-.04,.62),.26,.30,'bark','thigh_'+suffix,'03_LIMBS')
    beam('Shin_'+suffix,(X(.26),-.04,.64),(X(.27),.04,.14),.21,.23,'bark','shin_'+suffix,'03_LIMBS')
    box('Foot_'+suffix,(X(.27),.16,.06),(.22,.42,.12),'bark_moss','foot_'+suffix,'03_LIMBS')
    for k,dx in enumerate((-.07,0,.07)):
        beam('Toe%d_%s'%(k,suffix),(X(.27+dx),.33,.06),(X(.27+dx*1.5),.52,.02),.06,.06,'branch','foot_'+suffix,'03_LIMBS',.02,.02)

# Ritual: woven red-ochre sash with a hanging tail (left), leaf skirt front and back,
# carved talisman on the chest (right), a vine bound round the left upper arm.
box('Sash',(0,.02,1.28),(.70,.48,.10),'sash','pelvis','04_RITUAL')
beam('SashTail',(.37,-.20,1.25),(.42,-.24,.90),.12,.03,'sash','sash_tail','04_RITUAL')
prism_y('LeafSkirt_Front',[(-.30,1.20),(.30,1.20),(.30,.86),(.22,.80),(.15,.88),(.07,.78),(0,.86),(-.08,.77),(-.16,.87),(-.24,.79),(-.30,.86)],
        -.26,.04,'leaves','skirt_front','04_RITUAL')
prism_y('LeafSkirt_Back',[(-.32,1.20),(.32,1.20),(.32,.90),(.20,.84),(.10,.92),(-.04,.83),(-.18,.91),(-.32,.85)],
        .27,.04,'leaves','skirt_back','04_RITUAL')
# Branches growing from the shoulders (tree spirit, not a walking tree); left one larger.
beam('Branch_l',(.55,.10,2.22),(.74,.30,2.72),.10,.10,'branch','shoulder_l','04_RITUAL',.035,.035)
beam('Twig_l',(.66,.21,2.50),(.86,.24,2.64),.06,.06,'branch','shoulder_l','04_RITUAL',.02,.02)
beam('Branch_r',(-.56,.10,2.22),(-.68,.24,2.52),.08,.08,'branch','shoulder_r','04_RITUAL',.03,.03)
box('Talisman',(-.14,-.30,1.98),(.13,.04,.17),'talisman','chest','04_RITUAL',rot=(6,0,0))
beam('Vine_l',(.635,-.025,1.88),(.67,-.045,1.72),.26,.28,'vine','upper_arm_l','04_RITUAL')

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

TARGET=Vector((0,-.05,1.45))
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6.5,8.5),1300,6,(1,.92,.81)),('Fill',(6.5,-3,6.5),650,6,(.78,.86,1)),('Rim',(0,6,8.5),1450,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','05_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=3.5; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static Forest Elder: Curupira-inspired forest spirit. Old wood and bark body, carved mask with glowing eyes, flame-leaf crown, branch-claw hands, BACKWARD feet, leaf skirt, woven sash, talisman, vine.'
bpy.app.driver_namespace['forest_elder']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'width_m':max(c.x for c in coords)-min(c.x for c in coords)}
