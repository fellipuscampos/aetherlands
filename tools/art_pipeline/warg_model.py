"""Static Warg (fantasy wolf), using the approved Troll/Goblin/Minotaur/Skeleton
cuboid language and metric UV (64 px/m). Run INSIDE Blender through the MCP client.
No rig or animation. Real meters, front = -Y, paws at Z=0. Every part records the
single bone it must follow (obj['rig_bone']) for a future quadruped rig.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Warg_V1'
OUT=ROOT/'assets/generated/wargs/warg_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Warg scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_LEGS','04_FUR','05_STUDIO']:
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
    # Straight or tapered cuboid along start->end; tapered sides stay planar.
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector((0,1,0)).cross(axis)
    if u.length<1e-6: u=Vector((1,0,0))
    u.normalize(); v=axis.cross(u).normalized()
    ew=width if end_width is None else end_width; ed=depth if end_depth is None else end_depth
    verts=[c+u*x*w/2+v*y*d/2 for c,w,d in ((a,width,depth),(b,ew,ed)) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,up or (axis if axis.z>=0 else -axis))
def prism_x(name,outline_yz,x_center,thickness,region,bone,collection):
    # Side-profile plate: (y,z) outline extruded along X.
    k=len(outline_yz); verts=[(x_center+off,y,z) for off in (-thickness/2,thickness/2) for y,z in outline_yz]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
    faces += [(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection)

def prism_y(name,outline_xz,y_center,thickness,region,bone,collection):
    # Front-facing plate: (x,z) outline extruded along Y.
    k=len(outline_xz); verts=[(x,y_center+off,z) for off in (-thickness/2,thickness/2) for x,z in outline_xz]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
    faces += [(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection)

# V2 (after review): low crouched lunge, head forward and low, front legs reaching,
# hind legs folded like a spring. Fur is read through overlapping ragged plates
# (mane, chest ruff, cheeks, shoulder and hip flaps) and strand texture, not spikes.
box('Chest',(0,-.22,.64),(.60,.56,.46),'chest','chest',rot=(6,0,0))
box('Hips',(0,.30,.70),(.50,.52,.40),'hips','hips',rot=(-5,0,0))
beam('Neck',(0,-.45,.74),(0,-.80,.78),.40,.42,'neck','neck')
box('Mane',(0,-.56,.74),(.68,.24,.52),'mane','neck','04_FUR',rot=(25,0,0))
prism_y('ChestRuff',[(-.16,.62),(.16,.62),(.16,.33),(.09,.27),(.03,.34),(-.03,.26),(-.10,.33),(-.16,.29)],
        -.51,.05,'ruff','chest','04_FUR')

# Head: broad skull, strong snout, big dark nose, jaw open in a snarl.
box('Head',(0,-.92,.80),(.42,.40,.36),'head','head','02_HEAD')
box('Snout',(0,-1.26,.74),(.26,.32,.20),'muzzle','head','02_HEAD')
box('Nose',(0,-1.44,.80),(.15,.06,.09),'nose','head','02_HEAD')
box('Jaw',(0,-1.20,.58),(.22,.30,.08),'jaw','jaw','02_HEAD',rot=(12,0,0))
for side,suffix in [(1,'l'),(-1,'r')]:
    X=lambda x:side*x
    box('Brow_'+suffix,(X(.10),-1.125,.90),(.14,.05,.05),'brow','head','02_HEAD',rot=(0,side*-16,0))
    beam('Fang_'+suffix,(X(.08),-1.38,.65),(X(.08),-1.38,.585),.034,.034,'fang','head','02_HEAD',.012,.012,up=(0,0,1))
    # Upright, slightly forward ears (alert, aggressive).
    beam('Ear_'+suffix,(X(.13),-.84,.95),(X(.17),-.90,1.18),.13,.08,'ear','head','02_HEAD',.03,.03)
    # Cheek ruff flaring back over the mane, ragged edge.
    prism_x('Cheek_'+suffix,[(-1.06,.62),(-.92,.60),(-.74,.58),(-.66,.63),(-.72,.68),(-.62,.72),(-.70,.77),(-.84,.82),(-1.06,.80)],
            X(.215),.07,'cheek','head','04_FUR')

    # Front legs reach forward (lunge); shoulder fur flap overlaps the upper leg.
    beam('FrontUpper_'+suffix,(X(.25),-.36,.56),(X(.31),-.68,.30),.16,.18,'leg_upper','front_upper_'+suffix,'03_LEGS')
    beam('FrontLower_'+suffix,(X(.31),-.68,.32),(X(.34),-.86,.07),.12,.13,'leg_lower','front_lower_'+suffix,'03_LEGS')
    box('FrontPaw_'+suffix,(X(.34),-.95,.05),(.19,.26,.10),'paw','front_paw_'+suffix,'03_LEGS')
    box('FrontClaws_'+suffix,(X(.34),-1.095,.025),(.17,.05,.04),'claws','front_paw_'+suffix,'03_LEGS')
    prism_x('ShoulderFur_'+suffix,[(-.24,.66),(-.52,.66),(-.58,.50),(-.52,.36),(-.46,.42),(-.40,.33),(-.34,.40),(-.27,.34),(-.22,.46)],
            X(.355),.05,'flap','front_upper_'+suffix,'04_FUR')
    # Hind legs folded under the body: thigh forward-down, shin back-down to the paw.
    beam('HindThigh_'+suffix,(X(.22),.38,.72),(X(.26),.14,.36),.18,.22,'leg_upper','hind_thigh_'+suffix,'03_LEGS')
    beam('HindLower_'+suffix,(X(.26),.14,.38),(X(.27),.46,.10),.12,.13,'leg_lower','hind_lower_'+suffix,'03_LEGS')
    box('HindPaw_'+suffix,(X(.27),.40,.05),(.18,.26,.10),'paw','hind_paw_'+suffix,'03_LEGS')
    box('HindClaws_'+suffix,(X(.27),.245,.025),(.16,.05,.04),'claws','hind_paw_'+suffix,'03_LEGS')
    prism_x('HipFur_'+suffix,[(.10,.86),(.52,.86),(.56,.66),(.48,.52),(.42,.58),(.34,.48),(.26,.56),(.18,.47),(.10,.58)],
            X(.37),.05,'flap','hind_thigh_'+suffix,'04_FUR')

# Bushy tail streaming straight back (speed line): base, then a fuller tip that tapers.
beam('Tail_Base',(0,.54,.82),(0,.86,.88),.17,.18,'tail','tail_01')
beam('Tail_Tip',(0,.83,.88),(0,1.16,.86),.23,.22,'tail_tip','tail_02',end_width=.11,end_depth=.11)

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

TARGET=Vector((0,-.20,.52))
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-3.5,-4.5,6.5),620,4,(1,.92,.81)),('Fill',(4.5,-2,4.5),300,4,(.78,.86,1)),('Rim',(0,4,5.5),700,3,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','05_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=2.9; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static warg V2: crouched lunging blocky fantasy wolf, layered fur plates (mane, chest ruff, cheeks, shoulder/hip flaps), strand-textured grey fur, snarl with fangs, yellow eyes.'
scene['animations_requested']=False
bpy.app.driver_namespace['warg']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'length_m':max(c.y for c in coords)-min(c.y for c in coords),'width_m':max(c.x for c in coords)-min(c.x for c in coords)}
