"""Static Forest Guardian V2 ("Ancião da Floresta"): an elite, predatory forest guardian.
A quadruped wedge of ancient wood and mossy stone, heavy and wide at the front, low at the
rear; a low wooden skull sunk between stone pauldrons, angry V brows, intense yellow-green
eyes, an open jaw with splinter teeth and a glowing throat, twisted horns curving forward,
raised root spikes along the back around an embedded glowing core, thick pillar legs (no
knees) on stone hooves with root claws. Built like the approved bestiary: big mirrored,
nearly axis-aligned blocks; tapered blocks only for horns, spikes, teeth and claws. Metric
UV (64 px/m). Every part records the bone it will follow (obj['rig_bone']). Run INSIDE
Blender via the MCP client. Real meters, front = -Y, ground at Z=0. No rig/animation yet.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Forest_Guardian_V2'
OUT=ROOT/'assets/generated/forest_guardians/forest_guardian_v2'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Forest Guardian scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_LEGS','05_STUDIO']:
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
def cuboid(center,size,R):
    c=Vector(center); a,b,d=[v/2 for v in size]
    return [c+R@Vector((sx*a,sy*b,sz*d)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
def rotation(rot): return Euler([math.radians(a) for a in rot],'XYZ').to_matrix()
def box(name,center,size,region,bone,collection,rot=(0,0,0)):
    R=rotation(rot); return mesh(name,cuboid(center,size,R),CUBE,region,bone,collection,R@Vector((0,0,1)))
# Same construction as the approved bestiary: big mirrored blocks, nearly axis-aligned;
# tapered blocks only for horns, spikes, teeth and claws. The pixel art carries the detail.
def taper(a,b,w0,h0,w1,h1,extend=.03):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); a=a-axis*extend; b=b+axis*extend
    side=Vector((-axis.y,axis.x,0))
    if side.length<1e-6: side=Vector((1,0,0))
    side.normalize(); upv=side.cross(axis).normalized()
    if upv.z<0: upv=-upv
    return [c+side*x*w/2+upv*y*h/2 for c,w,h in ((a,w0,h0),(b,w1,h1)) for y in (-1,1) for x in (-1,1)]
def chain(name,points,widths,region,bone,collection):
    # Consecutive tapered blocks in one object (twisted horns, raised roots, claws, teeth).
    verts=[]; faces=[]
    for i in range(len(points)-1):
        faces+=[tuple(len(verts)+k for k in f) for f in CUBE]
        verts+=taper(points[i],points[i+1],widths[i],widths[i],widths[i+1],widths[i+1])
    return mesh(name,verts,faces,region,bone,collection)
def group(name,segments,region,bone,collection):
    verts=[]; faces=[]
    for seg in segments:
        faces+=[tuple(len(verts)+k for k in f) for f in CUBE]; verts+=seg
    return mesh(name,verts,faces,region,bone,collection)

# Body: a wedge, heavy and wide at the front, low and narrower at the rear, with mossy
# stone pauldrons over the front legs.
box('Chest',(0,-.45,1.25),(1.80,1.10,1.10),'bark','body','01_BODY')
box('Hind',(0,.55,1.00),(1.30,1.10,.80),'bark','body','01_BODY')
for s,tag in ((1,'L'),(-1,'R')):
    box('Pauldron_'+tag,(s*.88,-.50,1.56),(.56,.80,.52),'stone','body','01_BODY')
# Elemental core embedded between the shoulders, raised roots along the back.
box('Core',(0,-.45,1.84),(.44,.44,.16),'glow','body','01_BODY')
for s,tag in ((1,'L'),(-1,'R')):
    for i,(y,z,hgt) in enumerate([(-.62,1.80,.62),(-.12,1.80,.50),(.36,1.40,.42)]):
        base=Vector((s*.40,y,z-.04)); mid=base+Vector((s*.05,.14,hgt*.55)); tip=base+Vector((s*.16,.40,hgt))
        chain(f'RootSpike_{tag}{i+1}',[base,mid,tip],[.24,.16,.05],'bark','body','01_BODY')

# Head: a low wooden skull sunk between the shoulders, angry V brows of stone, intense
# eyes, an open jaw with splinter teeth and a glowing throat, twisted horns curving forward.
box('Skull',(0,-1.20,1.05),(.80,.70,.60),'bark','head','02_HEAD')
box('Jaw',(0,-1.26,.62),(.70,.60,.20),'bark','jaw','02_HEAD',rot=(14,0,0))
box('Throat',(0,-1.12,.76),(.50,.30,.10),'glow','head','02_HEAD')
for s,tag in ((1,'L'),(-1,'R')):
    box('Brow_'+tag,(s*.20,-1.56,1.30),(.40,.16,.14),'stone','head','02_HEAD',rot=(0,-s*15,0))
    box('Eye_'+tag,(s*.19,-1.565,1.18),(.18,.04,.08),'glow','head','02_HEAD')
    chain('Horn_'+tag,[(s*.32,-1.15,1.28),(s*.62,-1.20,1.52),(s*.74,-1.45,1.82),(s*.64,-1.64,2.02)],[.20,.15,.10,.04],'bark','head','02_HEAD')
group('Teeth_Upper',[taper((x,-1.50,.79),(x,-1.50,.64),.08,.08,.02,.02,.01) for x in (-.26,-.09,.09,.26)],'tooth','head','02_HEAD')
group('Teeth_Lower',[taper((x,-1.48,.66),(x,-1.48,.78),.08,.08,.02,.02,.01) for x in (-.18,.18)],'tooth','jaw','02_HEAD')

# Legs: thick pillars (no knees) on heavy stone hooves; root claws on the front hooves.
for s,tag in ((1,'L'),(-1,'R')):
    box('FrontLeg_'+tag,(s*.74,-.55,.58),(.62,.66,.96),'bark','front_leg_'+tag.lower(),'03_LEGS')
    box('FrontHoof_'+tag,(s*.76,-.60,.13),(.78,.84,.26),'stone','front_leg_'+tag.lower(),'03_LEGS')
    group('FrontClaws_'+tag,[taper((s*.76+d,-.96,.16),(s*.76+d*1.15,-1.20,.03),.13,.13,.04,.04,.01) for d in (-.25,0,.25)],
          'claw','front_leg_'+tag.lower(),'03_LEGS')
    box('HindLeg_'+tag,(s*.54,.70,.40),(.52,.56,.64),'bark','hind_leg_'+tag.lower(),'03_LEGS')
    box('HindHoof_'+tag,(s*.56,.66,.11),(.64,.70,.22),'stone','hind_leg_'+tag.lower(),'03_LEGS')

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

TARGET=Vector((0,-.30,1.05))
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
cam.type='ORTHO'; cam.ortho_scale=3.9; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static Forest Guardian V2: predatory front-heavy quadruped of ancient wood and mossy stone; low wooden skull with angry brows, intense eyes, open jaw with splinter teeth and glowing throat, twisted forward horns, raised root spikes, embedded glowing core, stone hooves with root claws.'
bpy.app.driver_namespace['forest_guardian']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'below_ground':sorted({o['part'] for o in parts for v in o.data.vertices if v.co.z<-1e-4}),
        'size_xy':[max(c.x for c in coords)-min(c.x for c in coords),max(c.y for c in coords)-min(c.y for c in coords)]}
