"""Static Giant Spider, using the approved cuboid language and metric UV (64 px/m) of
the bestiary. Run INSIDE Blender through the MCP client. Real meters, front = -Y,
ground at Z=0. Cephalothorax + waist + large raised abdomen; 8 legs of only TWO
segments each (femur up to a high knee, tibia down to the ground); chelicerae with
fangs, short palps, six geometric eyes. Every part records the single bone it must
follow (obj['rig_bone']); spider_rig.py builds the rig from these.
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Giant_Spider_V1'
OUT=ROOT/'assets/generated/spiders/giant_spider_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Spider scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_LEGS','04_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,bone,collection='01_BODY',up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['rig_bone']=bone; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid or simple tapered prism; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def box(name,center,size,region,bone,collection='01_BODY',rot=(0,0,0)):
    # rot in degrees (XYZ). +X tips the front (-Y) end down.
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

# Body: low cephalothorax (front tipped down), a short waist, a big abdomen raised
# at the rear for a memorable silhouette, spinnerets at its tip.
box('Cephalothorax',(0,-.30,.55),(.70,.70,.34),'carapace','cephalothorax',rot=(6,0,0))
box('Waist',(0,.12,.58),(.24,.26,.18),'carapace_dark','abdomen')
# Abdomen stepped like voxels (main block + smaller rear cap) so it reads rounded, not a cube.
box('Abdomen',(0,.68,.74),(.92,.90,.66),'abdomen','abdomen',rot=(-14,0,0))   # set back: clears the 4th femurs
box('AbdomenRear',(0,1.18,.87),(.66,.30,.48),'abdomen','abdomen',rot=(-14,0,0))
box('Spinnerets',(0,1.38,.93),(.22,.12,.18),'carapace_dark','abdomen',rot=(-14,0,0))

# Front: six glowing eyes (2 big, 4 small), chelicerae with curved fangs, short palps.
for side,suffix in [(1,'l'),(-1,'r')]:
    X=lambda x:side*x
    box('EyeBig_'+suffix,(X(.085),-.655,.70),(.10,.04,.08),'eye','cephalothorax','02_HEAD',rot=(6,0,0))
    box('EyeSide_'+suffix,(X(.21),-.625,.71),(.06,.04,.055),'eye','cephalothorax','02_HEAD',rot=(6,0,0))
    box('EyeTop_'+suffix,(X(.07),-.60,.77),(.055,.05,.04),'eye','cephalothorax','02_HEAD',rot=(6,0,0))
    beam('Chelicera_'+suffix,(X(.10),-.60,.58),(X(.10),-.74,.40),.13,.13,'chelicera','chelicera_'+suffix,'02_HEAD',.11,.11)
    beam('Fang_'+suffix,(X(.10),-.745,.43),(X(.045),-.80,.29),.06,.06,'fang','chelicera_'+suffix,'02_HEAD',.015,.015)
    beam('Palp_'+suffix,(X(.24),-.60,.52),(X(.30),-.84,.36),.07,.07,'leg','palp_'+suffix,'02_HEAD',.045,.045)

    # Legs: two segments each. Femur rises from the cephalothorax side to a high knee,
    # tibia falls to the ground. Front pair raised a little (ready to strike).
    for i,(yaw,y0,reach,foot_z) in enumerate([(52,-.50,1.20,.16),(22,-.38,1.30,0),(-14,-.24,1.30,0),(-44,-.10,1.22,0)]):
        a=math.radians(yaw); d=Vector((side*math.cos(a),-math.sin(a),0))
        hip=Vector((X(.30),y0,.56)); knee=hip+d*.55+Vector((0,0,.46)); foot=hip+d*reach; foot.z=foot_z+.02
        n=i+1
        beam('Leg%d_Femur_%s'%(n,suffix),hip,knee,.16,.17,'leg','leg%d_femur_%s'%(n,suffix),'03_LEGS',.13,.14)
        beam('Leg%d_Tibia_%s'%(n,suffix),knee-(knee-foot).normalized()*-.03,foot,.12,.13,'leg_tip','leg%d_tibia_%s'%(n,suffix),'03_LEGS',.045,.05)

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

TARGET=Vector((0,.15,.50))
studio=collections['04_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-4.5,-5.5,7.5),1100,6,(1,.92,.81)),('Fill',(6,-2.5,5.5),560,6,(.78,.86,1)),('Rim',(0,6,7),1200,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','04_STUDIO')
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
scene['description']='Static giant spider: low cephalothorax, raised abdomen with venom markings, 8 two-segment legs, chelicerae with fangs, palps, six glowing eyes.'
bpy.app.driver_namespace['spider']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'length_m':max(c.y for c in coords)-min(c.y for c in coords),'width_m':max(c.x for c in coords)-min(c.x for c in coords)}
