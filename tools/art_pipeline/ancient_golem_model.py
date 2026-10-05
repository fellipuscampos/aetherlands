"""Static Ancient Golem ("Ancião da Floresta", golem version), after the user's golem
references (Minecraft iron golem proportions, mossy rock golem, vine-wrapped golem,
crystal golem). Built like the approved bestiary: big mirrored blocks, nearly
axis-aligned; tapered blocks only for crystals; the pixel art carries the detail.
Hulking stance: huge long arms with massive fists almost touching the ground, short
thick legs, a small head sunk between high stone shoulders with a heavy brow and
glowing eyes, a glowing core in the chest, stone plates over dark root/wood joints,
moss and foliage heaped on the back and shoulders, a cluster of glowing crystals on one
shoulder; vines with flowers and glowing runes are painted.
Metric UV (64 px/m). Every part records its future bone (obj['rig_bone']). Run INSIDE
Blender via the MCP client. Real meters, front = -Y, ground at Z=0. No rig/animation yet.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Ancient_Golem_V1'
OUT=ROOT/'assets/generated/ancient_golems/ancient_golem_v1'
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

# Torso: a massive stone chest leaning forward over a dark root pelvis.
box('Pelvis',(0,.06,1.14),(.92,.62,.42),'root','hips','01_BODY')
box('Chest',(0,.04,1.86),(1.70,1.00,1.10),'stone','chest','01_BODY',rot=(8,0,0))
box('Belly',(0,-.02,1.32),(1.20,.80,.40),'stone','chest','01_BODY')
box('Core',(0,-.48,1.56),(.40,.12,.36),'glow','chest','01_BODY',rot=(8,0,0))
# Head sunk between high shoulders: small stone head, heavy brow, glowing eyes.
box('Head',(0,-.40,2.24),(.58,.52,.50),'stone','head','02_HEAD',rot=(8,0,0))
box('Brow',(0,-.66,2.42),(.72,.20,.16),'stone','head','02_HEAD',rot=(8,0,0))
for s,tag in ((1,'L'),(-1,'R')):
    box('Eye_'+tag,(s*.13,-.665,2.26),(.12,.04,.06),'glow','head','02_HEAD',rot=(8,0,0))
# Shoulders: big stone pauldrons rising above the head.
for s,tag in ((1,'L'),(-1,'R')):
    box('Shoulder_'+tag,(s*.96,.04,2.36),(.74,.92,.62),'stone','shoulder_'+tag.lower(),'03_ARMS')
# Arms: root upper arms, huge stone forearms, massive fists with knuckle blocks.
for s,tag in ((1,'L'),(-1,'R')):
    side=tag.lower()
    box('UpperArm_'+tag,(s*1.04,-.02,1.78),(.48,.54,.80),'root','upper_arm_'+side,'03_ARMS')
    box('Forearm_'+tag,(s*1.08,-.10,.98),(.68,.74,.92),'stone','forearm_'+side,'03_ARMS')
    box('Fist_'+tag,(s*1.10,-.14,.32),(.78,.82,.52),'stone','fist_'+side,'03_ARMS')
    verts=[]; faces=[]
    for k,dx in enumerate((-.25,0,.25)):
        c=Vector((s*1.10+dx,-.58,.36-.03*k)); a,b,dd=.125,.06,.15
        faces+=[tuple(len(verts)+q for q in f) for f in CUBE]
        verts+=[c+Vector((x*a,y*b,z*dd)) for z in (-1,1) for y in (-1,1) for x in (-1,1)]
    mesh('Knuckles_'+tag,verts,faces,'stone','fist_'+side,'03_ARMS')
# Legs: short thick root thighs, stone shins, wide stone feet.
for s,tag in ((1,'L'),(-1,'R')):
    side=tag.lower()
    box('Thigh_'+tag,(s*.36,.06,.84),(.50,.54,.46),'root','thigh_'+side,'04_LEGS')
    box('Shin_'+tag,(s*.38,.02,.44),(.58,.64,.52),'stone','shin_'+side,'04_LEGS')
    box('Foot_'+tag,(s*.38,-.06,.10),(.70,.88,.20),'stone','shin_'+side,'04_LEGS')
# Growth: moss and foliage heaped on the back and shoulders, glowing crystals on the right.
box('MossBack',(0,.30,2.48),(1.56,.62,.30),'moss','chest','05_GROWTH',rot=(8,0,0))
box('Foliage_1',(-.30,.40,2.74),(.62,.56,.40),'leaf','chest','05_GROWTH')
box('Foliage_2',(.34,.30,2.70),(.50,.50,.34),'leaf','chest','05_GROWTH')
box('Foliage_L',(1.00,.18,2.74),(.56,.60,.24),'leaf','shoulder_l','05_GROWTH')
verts=[]; faces=[]
for base,tip,w in [((-.94,.10,2.62),(-.98,.06,3.06),.16),((-1.12,.22,2.62),(-1.24,.26,2.92),.12),((-.80,.26,2.62),(-.74,.34,2.86),.10)]:
    faces+=[tuple(len(verts)+q for q in f) for f in CUBE]; verts+=taper(base,tip,w,w,.03,.03,.02)[0]
mesh('Crystals_R',verts,faces,'crystal','shoulder_r','05_GROWTH')

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

TARGET=Vector((0,0,1.45))
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
cam.type='ORTHO'; cam.ortho_scale=4.2; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static Ancient Golem: hulking stone golem over dark root joints, huge arms and fists, head sunk between shoulders, glowing eyes, core and crystals, moss and foliage on the back.'
bpy.app.driver_namespace['ancient_golem']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'below_ground':sorted({o['part'] for o in parts for v in o.data.vertices if v.co.z<-1e-4}),
        'size_xy':[max(c.x for c in coords)-min(c.x for c in coords),max(c.y for c in coords)-min(c.y for c in coords)]}
