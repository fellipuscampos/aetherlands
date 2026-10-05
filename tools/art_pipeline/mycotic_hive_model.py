"""Static Mycotic Hive V3 ("Colmeia Micótica"): a glowing orb-organism held by dark
claw branches on a short trunk with spreading roots, after the user's reference (orange
bulb in a cage of dark branches, curled horn on top, small glowing berries). Built from
FEW cuboids like the rest of the bestiary: the orb is three crossed boxes (voxel ball),
each claw/root/horn is a short chain of boxes. Metric UV (64 px/m), Mana Devourer
albedo + emission convention. Run INSIDE Blender through the MCP client. Real meters,
front = -Y, ground at Z=0. No rig/animation yet.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Mycotic_Hive_V3'
OUT=ROOT/'assets/generated/mycotic_hives/mycotic_hive_v3'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Mycotic Hive scene exists; preserve manual edits.')
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
for label in ['01_ORB','02_CLAWS','03_TRUNK_ROOTS','05_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,collection,up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Cuboids only; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def cuboid(center,size,R):
    c=Vector(center); a,b,d=[v/2 for v in size]
    return [c+R@Vector((sx*a,sy*b,sz*d)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
def rotation(rot): return Euler([math.radians(a) for a in rot],'XYZ').to_matrix()
def box(name,center,size,region,collection,rot=(0,0,0),matrix=None):
    R=matrix if matrix is not None else rotation(rot)
    return mesh(name,cuboid(center,size,R),CUBE,region,collection,R@Vector((0,0,1)))
def boxes(name,specs,region,collection,up=(0,0,1)):
    # Several closed cuboids in ONE object (vein strips, root segments, feeler links).
    verts=[]; faces=[]
    for spec in specs:
        faces+=[tuple(len(verts)+k for k in f) for f in CUBE]; verts+=spec if isinstance(spec,list) else cuboid(*spec)
    return mesh(name,verts,faces,region,collection,up)
def link(a,b,w,h,extend=.03):
    # Cuboid from a to b (rectangular faces): width horizontal, height ~vertical.
    a,b=Vector(a),Vector(b); axis=(b-a).normalized()
    side=Vector((-axis.y,axis.x,0))
    if side.length<1e-6: side=Vector((1,0,0))
    side.normalize(); upv=side.cross(axis).normalized()
    if upv.z<0: upv=-upv
    return ((a+b)/2,((b-a).length+2*extend,w,h),Matrix((axis,side,upv)).transposed())
def taper(a,b,w0,h0,w1,h1,extend=.03):
    # Tapered block from a to b (like the minotaur horns): width horizontal, height ~vertical.
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); a=a-axis*extend; b=b+axis*extend
    side=Vector((-axis.y,axis.x,0))
    if side.length<1e-6: side=Vector((1,0,0))
    side.normalize(); upv=side.cross(axis).normalized()
    if upv.z<0: upv=-upv
    return [c+side*x*w/2+upv*y*h/2 for c,w,h in ((a,w0,h0),(b,w1,h1)) for y in (-1,1) for x in (-1,1)]
def polar(deg,r,z=0.0): a=math.radians(deg); return Vector((r*math.cos(a),r*math.sin(a),z))

# Twisted trunk widening into five blade roots spread over the ground.
box('Trunk_Base',(0,0,.20),(.72,.72,.40),'bark','03_TRUNK_ROOTS',rot=(0,0,12))
box('Trunk_Mid',(.02,-.01,.56),(.50,.50,.36),'bark','03_TRUNK_ROOTS',rot=(0,0,-6))
box('Trunk_Neck',(0,.01,.82),(.38,.38,.24),'bark','03_TRUNK_ROOTS',rot=(0,0,20))
for i,az in enumerate([18,90,160,232,302]):
    boxes('Root_%d'%(i+1),[taper(polar(az,.18,.34),polar(az+6,.72,.12),.34,.20,.26,.14),
                           taper(polar(az+6,.72,.12),polar(az+14,1.18,.05),.26,.14,.12,.06)],'root','03_TRUNK_ROOTS')
# Glowing orb: a central block with three crossing blocks = voxel ball.
box('Orb_Core',(0,0,1.55),(1.10,1.10,1.06),'orb','01_ORB')
# Same-axis sizes differ by more than the idle pulse (9%), so faces never become coplanar.
box('Orb_X',(0,0,1.55),(1.34,.76,.76),'orb','01_ORB')
box('Orb_Y',(0,0,1.55),(.78,1.34,.68),'orb','01_ORB')
box('Orb_Z',(0,0,1.55),(.90,.90,1.34),'orb','01_ORB')
# Three claw branches twisting up over the orb faces and closing on its crown.
for i,(az0,tw) in enumerate([(300,28),(70,-24),(180,30)]):
    path=[(0,.22,.86),(.15,.64,1.02),(.40,.76,1.44),(.70,.74,1.88),(1.0,.44,2.26),(1.2,.12,2.36)]
    pts=[polar(az0+tw*f,r,z) for f,r,z in path]
    ws=[.24,.21,.18,.15,.11,.08]
    boxes('Claw_%d'%(i+1),[taper(pts[k],pts[k+1],ws[k],ws[k],ws[k+1],ws[k+1],.04) for k in range(5)],'bark','02_CLAWS')
# Curled horn rising where the claws meet.
boxes('Horn',[taper((0,0,2.30),(.04,.04,2.58),.22,.22,.16,.16),taper((.04,.04,2.58),(.16,.12,2.78),.16,.16,.10,.10),
              taper((.16,.12,2.78),(.32,.14,2.86),.10,.10,.04,.04,.02)],'bark','02_CLAWS')
# Two small glowing berries on the orb's crown.
box('Berry_1',(.28,-.30,2.28),(.22,.22,.22),'orb','01_ORB',rot=(0,0,15))
box('Berry_2',(-.30,.24,2.26),(.18,.18,.18),'orb','01_ORB',rot=(0,0,-20))

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

TARGET=Vector((0,0,1.30))
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6.5,8.5),1250,6,(1,.92,.81)),('Fill',(6.5,-3,6.5),620,6,(.78,.86,1)),('Rim',(0,6.5,8.5),1350,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','05_STUDIO')
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
scene['description']='Static Mycotic Hive V3 (few cuboids): glowing voxel-ball orb held by three twisting claw branches on a twisted trunk with five blade roots, curled horn and two glowing berries on top.'
bpy.app.driver_namespace['mycotic_hive']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'quads_only':all(len(p.vertices)==4 for o in parts for p in o.data.polygons),
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'below_ground':sorted({o['part'] for o in parts for v in o.data.vertices if v.co.z<-1e-4}),
        'size_xy':[max(c.x for c in coords)-min(c.x for c in coords),max(c.y for c in coords)-min(c.y for c in coords)]}
