"""Static Ancient Arboreal ("Ancião da Floresta"): an elite beast of the forest, rebuilt
from scratch as a PREDATOR, built the same way as the approved wolf/minotaur/wyvern:
a few big mirrored blocks, two-segment limbs, tapered blocks only for horns, spikes,
fangs and claws; the pixel art carries the detail.
Silhouette: a huge shoulder hump, a thick neck under a ruff of bark plates, the head low
and thrust forward with a long predatory muzzle, open jaw and fangs, angry stone brows,
glowing eyes and twisted horns swept back; massive forearms with root claws, lower
hindquarters, mossy boulders on the shoulders, root spikes along the spine, a rib cage of
roots over a glowing elemental core in the chest, and a heavy root tail.
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
NAME='Ancient_Arboreal_V1'
OUT=ROOT/'assets/generated/ancient_arboreals/ancient_arboreal_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Ancient Arboreal scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_LEGS','04_GROWTH','05_STUDIO']:
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

# Body: shoulder hump high, body sloping down to lower hindquarters.
box('Chest',(0,-.40,1.30),(1.30,1.00,1.00),'bark','chest','01_BODY',rot=(8,0,0))
box('Hump',(0,-.32,1.96),(1.10,.92,.50),'bark','chest','01_BODY',rot=(8,0,0))
box('Waist',(0,.22,1.22),(1.06,.66,.78),'bark','hips','01_BODY')
box('Hips',(0,.76,1.12),(1.00,.92,.78),'bark','hips','01_BODY',rot=(-6,0,0))
# Rib cage of roots over a glowing elemental core in the chest.
box('Core',(0,-.86,.98),(.54,.12,.44),'glow','chest','01_BODY',rot=(8,0,0))
for i,x in enumerate((-.18,0,.18)):
    beam('Rib_%d'%(i+1),(x,-.96,1.22),(x*1.2,-.92,.74),.08,.08,'root','chest','01_BODY')
# Mossy boulders on the shoulders, root spikes along the spine.
for s,tag in ((1,'L'),(-1,'R')):
    box('Boulder_'+tag,(s*.60,-.46,1.86),(.52,.78,.50),'stone','chest','01_BODY',rot=(8,0,s*-6))
for i,(y,z,h,w) in enumerate([(-.50,2.18,.62,.26),(-.08,2.10,.54,.24),(.36,1.60,.42,.22),(.74,1.52,.34,.18)]):
    base=Vector((0,y,z-.04)); chain('Spike_%d'%(i+1),[base,base+Vector((0,.12,h*.55)),base+Vector((0,.36,h))],[w,w*.6,.04],'root','chest' if i<2 else 'hips','01_BODY')

# Neck and head: thick neck under a ruff of bark plates, head low and forward with a long
# predatory muzzle, open jaw, fangs, angry stone brows, glowing eyes, twisted horns.
beam('Neck',(0,-.84,1.42),(0,-1.30,1.26),.72,.70,'bark','neck','02_HEAD')
box('Ruff',(0,-1.02,1.50),(1.30,.30,.92),'plate','neck','02_HEAD',rot=(28,0,0))
box('Head',(0,-1.48,1.22),(.80,.66,.62),'bark','head','02_HEAD')
box('Muzzle',(0,-2.02,1.12),(.56,.62,.34),'bark','head','02_HEAD')
box('Nose',(0,-2.33,1.22),(.32,.08,.14),'stone','head','02_HEAD')
box('Jaw',(0,-1.96,.84),(.50,.66,.16),'bark','jaw','02_HEAD',rot=(18,0,0))
for s,tag in ((1,'L'),(-1,'R')):
    box('Brow_'+tag,(s*.22,-1.83,1.44),(.34,.14,.13),'stone','head','02_HEAD',rot=(0,-s*18,0))
    box('Eye_'+tag,(s*.22,-1.815,1.33),(.17,.04,.07),'glow','head','02_HEAD')
    beam('FangUp_'+tag,(s*.20,-2.24,.98),(s*.20,-2.24,.78),.08,.08,'fang','head','02_HEAD',.02,.02)
    beam('FangLow_'+tag,(s*.13,-2.18,.86),(s*.13,-2.20,1.00),.07,.07,'fang','jaw','02_HEAD',.02,.02)
    chain('Horn_'+tag,[(s*.34,-1.42,1.48),(s*.64,-1.38,1.70),(s*.82,-1.14,1.98),(s*.78,-.86,2.26)],[.24,.18,.11,.04],'root','head','02_HEAD')

# Legs: massive two-segment forelegs with root claws, lower hind legs.
for s,tag in ((1,'L'),(-1,'R')):
    side=tag.lower()
    beam('Arm_'+tag,(s*.60,-.46,1.42),(s*.70,-.72,.72),.50,.54,'bark','front_upper_'+side,'03_LEGS')
    beam('Forearm_'+tag,(s*.70,-.72,.74),(s*.72,-.86,.22),.48,.52,'bark','front_lower_'+side,'03_LEGS')
    box('FrontPaw_'+tag,(s*.72,-.98,.12),(.62,.72,.24),'stone','front_paw_'+side,'03_LEGS')
    verts=[]; faces=[]
    for d in (-.22,0,.22):
        faces+=[tuple(len(verts)+k for k in f) for f in [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]]
        verts+=taper((s*.72+d,-1.30,.16),(s*.72+d*1.1,-1.58,.03),.14,.14,.04,.04,.01)[0]
    mesh('FrontClaws_'+tag,verts,faces,'claw','front_paw_'+side,'03_LEGS',(0,-1,0))
    beam('Thigh_'+tag,(s*.46,.80,1.12),(s*.52,.54,.56),.44,.52,'bark','hind_upper_'+side,'03_LEGS')
    beam('Shin_'+tag,(s*.52,.54,.58),(s*.54,.92,.20),.32,.36,'bark','hind_lower_'+side,'03_LEGS')
    box('HindPaw_'+tag,(s*.54,.88,.10),(.46,.60,.20),'stone','hind_paw_'+side,'03_LEGS')
    verts=[]; faces=[]
    for d in (-.12,.12):
        faces+=[tuple(len(verts)+k for k in f) for f in CUBE]
        verts+=taper((s*.54+d,.60,.12),(s*.54+d,.42,.02),.10,.10,.03,.03,.01)[0]
    mesh('HindClaws_'+tag,verts,faces,'claw','hind_paw_'+side,'03_LEGS',(0,-1,0))
# Heavy root tail.
chain('Tail',[(0,1.14,1.24),(0,1.56,1.04),(0,1.94,.90)],[.30,.20,.06],'root','tail','01_BODY')

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

TARGET=Vector((0,-.20,1.10))
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6.5,8.5),1250,6,(1,.92,.81)),('Fill',(6.5,-3,6.5),620,6,(.78,.86,1)),('Rim',(0,6.5,8.5),1350,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','05_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=4.8; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static Ancient Arboreal: predatory forest beast of ancient wood, roots, mossy stone and glowing fissures.'
bpy.app.driver_namespace['ancient_arboreal']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'below_ground':sorted({o['part'] for o in parts for v in o.data.vertices if v.co.z<-1e-4}),
        'size_xy':[max(c.x for c in coords)-min(c.x for c in coords),max(c.y for c in coords)-min(c.y for c in coords)]}
