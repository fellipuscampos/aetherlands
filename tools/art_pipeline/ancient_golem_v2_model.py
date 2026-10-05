"""Static Ancient Golem V2 ("Ancião da Floresta", golem), copying the user's voxel golem
reference but made of nature (no sword): a hunched, gorilla-like golem whose body is a
mass of dark living roots, armoured by pale carved stone plates (engraved spirals).
Low head thrust forward with a heavy stone jaw and brow, glowing green eyes and ferns
growing on top; stacked stone pauldrons; the right arm armoured with a stone gauntlet and
fist, the left arm a bare tangle of roots ending in root claws with roots dangling; bent
legs with big stone thigh and shin plates. Green energy veins glow inside the roots.
Built like the approved bestiary: big blocks, tapered blocks only for claws, roots and
ferns; the pixel art carries the detail. Metric UV (64 px/m). Every part records its
future bone (obj['rig_bone']). Run INSIDE Blender via the MCP client. Real meters,
front = -Y, ground at Z=0. No rig/animation yet.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Ancient_Golem_V2'
OUT=ROOT/'assets/generated/ancient_golems/ancient_golem_v2'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Ancient Golem scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_ARMS','04_LEGS','05_GROWTH','06_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,bone,collection,up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['rig_bone']=bone; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Cuboid / tapered block; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def box(name,center,size,region,bone,collection='01_BODY',rot=(0,0,0)):
    R=Euler([math.radians(a) for a in rot],'XYZ').to_matrix(); c=Vector(center); a,b,d=[v/2 for v in size]
    verts=[c+R@Vector((sx*a,sy*b,sz*d)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,R@Vector((0,0,1)))
def taper(a,b,w0,h0,w1=None,h1=None,extend=.03):
    # Block from a to b; width horizontal, height ~vertical; tapers if end sizes given.
    w1=w0 if w1 is None else w1; h1=h0 if h1 is None else h1
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); a=a-axis*extend; b=b+axis*extend
    side=Vector((-axis.y,axis.x,0))
    if side.length<1e-6: side=Vector((1,0,0))
    side.normalize(); upv=side.cross(axis).normalized()
    if upv.z<0: upv=-upv
    return [c+side*x*w/2+upv*y*h/2 for c,w,h in ((a,w0,h0),(b,w1,h1)) for y in (-1,1) for x in (-1,1)],axis
def beam(name,a,b,w0,h0,region,bone,collection='01_BODY',w1=None,h1=None):
    verts,axis=taper(a,b,w0,h0,w1,h1); return mesh(name,verts,CUBE,region,bone,collection,axis if axis.z>=0 else -axis)
def chain(name,points,widths,region,bone,collection):
    # Consecutive tapered blocks in one object (twisted horns, root spikes, claws, tail).
    verts=[]; faces=[]
    for i in range(len(points)-1):
        faces+=[tuple(len(verts)+k for k in f) for f in CUBE]
        verts+=taper(points[i],points[i+1],widths[i],widths[i],widths[i+1],widths[i+1])[0]
    return mesh(name,verts,faces,region,bone,collection)

# Root body, hunched forward; stone plates armour it.
box('Pelvis',(0,.12,1.04),(.84,.62,.42),'root','hips','01_BODY')
box('Torso',(0,-.12,1.56),(1.12,.92,1.02),'root','chest','01_BODY',rot=(25,0,0))
box('BackPlate',(0,.16,2.04),(1.24,.74,.42),'stone','chest','01_BODY',rot=(25,0,0))
box('ChestPlate',(.10,-.60,1.28),(.70,.20,.56),'stone','chest','01_BODY',rot=(12,0,-8))
# Head low and forward: stone head, brow, heavy jaw, glowing eyes, ferns on top.
box('Head',(0,-.78,1.96),(.70,.62,.52),'stone','head','02_HEAD',rot=(10,0,0))
box('Brow',(0,-1.08,2.16),(.82,.24,.16),'stone','head','02_HEAD',rot=(10,0,0))
box('Jaw',(0,-.86,1.54),(.80,.62,.40),'stone','jaw','02_HEAD',rot=(4,0,0))
for s,tag in ((1,'L'),(-1,'R')):
    box('Eye_'+tag,(s*.16,-1.095,2.04),(.15,.04,.08),'glow','head','02_HEAD',rot=(10,0,0))
verts=[]; faces=[]
for a,b,w in [((-.18,-.70,2.20),(-.52,-.40,2.52),.20),((.10,-.62,2.22),(.30,-.30,2.60),.22),((.26,-.80,2.20),(.58,-.70,2.44),.16)]:
    faces+=[tuple(len(verts)+q for q in f) for f in CUBE]; verts+=taper(a,b,w,.04,.04,.03,.02)[0]
mesh('Ferns',verts,faces,'leaf','head','02_HEAD')
# Stacked stone pauldrons.
for s,tag in ((1,'L'),(-1,'R')):
    box('Pauldron_'+tag,(s*.86,-.06,2.12),(.72,.84,.54),'stone','shoulder_'+tag.lower(),'03_ARMS',rot=(18,0,s*-10))
    box('PauldronTop_'+tag,(s*.92,.02,2.44),(.54,.62,.28),'stone','shoulder_'+tag.lower(),'03_ARMS',rot=(18,0,s*-16))
# Right arm (-X): root upper arm, stone gauntlet and fist hanging to the ground.
beam('UpperArm_R',(-.92,-.12,1.96),(-1.00,-.40,1.28),.42,.46,'root','upper_arm_r','03_ARMS')
box('Gauntlet_R',(-1.02,-.46,.94),(.62,.66,.74),'stone','forearm_r','03_ARMS',rot=(8,0,0))
box('Fist_R',(-1.02,-.54,.34),(.70,.70,.52),'stone','fist_r','03_ARMS')
# Left arm (+X): a bare tangle of roots, root claws, roots dangling below the hand.
beam('UpperArm_L',(.92,-.12,1.96),(1.00,-.36,1.24),.46,.50,'root','upper_arm_l','03_ARMS')
beam('Forearm_L',(1.00,-.36,1.30),(1.04,-.52,.56),.54,.58,'root','forearm_l','03_ARMS',.46,.50)
verts=[]; faces=[]
for dx in (-.16,0,.16):
    faces+=[tuple(len(verts)+q for q in f) for f in CUBE]
    verts+=taper((1.04+dx,-.62,.56),(1.04+dx*1.3,-.86,.24),.12,.12,.04,.04,.02)[0]
mesh('RootClaws_L',verts,faces,'root','hand_l','03_ARMS')
verts=[]; faces=[]
for dx,dy,ln in ((-.18,-.40,.46),(.14,-.34,.36),(.02,-.56,.28)):
    faces+=[tuple(len(verts)+q for q in f) for f in CUBE]
    verts+=taper((1.04+dx,dy,.62),(1.04+dx*1.2,dy-.04,.62-ln),.08,.08,.03,.03,.02)[0]
mesh('RootStrands_L',verts,faces,'root','hand_l','03_ARMS')
# Bent legs: stone thigh plates angled forward, stone shins, wide feet.
for s,tag in ((1,'L'),(-1,'R')):
    side=tag.lower()
    box('Thigh_'+tag,(s*.42,-.16,.86),(.56,.64,.62),'stone','thigh_'+side,'04_LEGS',rot=(-32,0,0))
    box('Shin_'+tag,(s*.42,-.30,.38),(.54,.60,.56),'stone','shin_'+side,'04_LEGS')
    box('Foot_'+tag,(s*.42,-.40,.10),(.66,.86,.20),'stone','shin_'+side,'04_LEGS')

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
        islands.append({'obj':obj,'polygon':p.index,'coords':co,'normal':normal,'right':right,'up':up,
                        'minimum':minimum,'offset':p.center.dot(normal),'center':p.center.copy(),
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
SIZE=next(s for s in (256,512,1024,2048) if pack(s))

TARGET=Vector((0,-.25,1.30))
studio=collections['06_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6.5,8.5),1250,6,(1,.92,.81)),('Fill',(6.5,-3,6.5),620,6,(.78,.86,1)),('Rim',(0,6.5,8.5),1350,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','06_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=3.9; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static Ancient Golem V2: hunched root golem armoured with carved stone plates, low head with heavy jaw, glowing green eyes, ferns, stacked pauldrons, stone gauntlet arm and bare root arm, bent legs.'
bpy.app.driver_namespace['ancient_golem']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'below_ground':sorted({o['part'] for o in parts for v in o.data.vertices if v.co.z<-1e-4}),
        'size_xy':[max(c.x for c in coords)-min(c.x for c in coords),max(c.y for c in coords)-min(c.y for c in coords)]}
