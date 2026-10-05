"""Static Wyvern, using the approved cuboid language and metric UV (64 px/m) of the
bestiary (Troll, Goblin, Minotaur, Skeleton, Warg, Basilisk). Run INSIDE Blender
through the MCP client. No rig or animation. Real meters, front = -Y, ground at Z=0.
Correct wyvern anatomy: two hind legs, and the WINGS ARE THE FORELIMBS (upper arm,
forearm, clawed hand on the ground, three wing fingers carrying the membrane).
Every part records the single bone it must follow (obj['rig_bone']).
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Wyvern_Blocky_V1'
OUT=ROOT/'assets/generated/wyverns/wyvern_blocky_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Wyvern scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_LEGS','04_WINGS','05_TAIL','06_STUDIO']:
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
def tri_slab(name,p0,p1,p2,thickness,region,bone,collection):
    # Thin triangular membrane panel with real thickness (closed prism).
    a,b,c=Vector(p0),Vector(p1),Vector(p2); n=(b-a).cross(c-a).normalized()*thickness/2
    verts=[a-n,b-n,c-n,a+n,b+n,c+n]
    faces=[(2,1,0),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]
    return mesh(name,verts,faces,region,bone,collection)
def prism_z(name,outline_xy,z_center,thickness,region,bone,collection):
    k=len(outline_xy); verts=[(x,y,z_center+off) for off in (-thickness/2,thickness/2) for x,y in outline_xy]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
    faces += [(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection,(0,1,0))
def spine(name,base,direction,length,width,bone,collection='01_BODY'):
    b=Vector(base); d=Vector(direction).normalized()
    return beam(name,b,b+d*length,width,width*.8,'bone_spike',bone,collection,width*.22,width*.18)

def poly_slab(name,points,thickness,region,bone,collection):
    # Planar membrane panel (any convex/concave outline) with real thickness.
    pts=[Vector(p) for p in points]; n=(pts[1]-pts[0]).cross(pts[2]-pts[0]).normalized()*thickness/2
    k=len(pts); verts=[p-n for p in pts]+[p+n for p in pts]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,bone,collection)
def lerp(a,b,t): return Vector(a).lerp(Vector(b),t)
SPIKE_DIR=Vector((0,.45,.89)).normalized()
def spikes_along(prefix,a,b,depth0,depth1,ts,length0,length1,width,bone,collection):
    # Row of short pale dorsal spines on top of a beam segment, leaning back.
    for k,t in enumerate(ts):
        base=lerp(a,b,t); axis=(Vector(b)-Vector(a)).normalized()
        upv=(Vector((0,0,1))-axis*axis.z).normalized()
        base=base+upv*((depth0+(depth1-depth0)*t)/2-.02)
        L=length0+(length1-length0)*t
        beam('%s_%d'%(prefix,k),base,base+SPIKE_DIR*L,width,width*.8,'bone_spike',bone,collection,width*.25,width*.2)

# V3 (after review): same reference-driven look, but (1) the body is much lower, and
# (2) the forelimb reads as ONE wing: thin dark wing-bone arm (no separate leg/foot),
# the wing's wrist knuckle is what touches the ground (two pale thumb claws), the five
# fan fingers grow from that knuckle, and membrane joins the arm to the body.
HZ=-.46          # head drop (head carried low, near the ground)
box('Chest',(0,-.40,.78),(.66,.85,.62),'chest','chest')
box('Hips',(0,.40,.76),(.58,.80,.56),'hips','hips')
neck=[((0,-.78,.88),(0,-1.15,1.08),.36,.38,.32,.34),((0,-1.12,1.06),(0,-1.45,1.22),.32,.34,.29,.31),((0,-1.42,1.20),(0,-1.75,1.28),.29,.31,.27,.29)]
for i,(a,b,w0,d0,w1,d1) in enumerate(neck):
    beam('Neck_%d'%(i+1),a,b,w0,d0,'neck','neck_%02d'%(i+1),'01_BODY',w1,d1)
    spikes_along('Spike_Neck%d'%(i+1),a,b,d0,d1,(.35,.85) if i<2 else (.5,),.15,.13,.08,'neck_%02d'%(i+1),'01_BODY')

# Boxy head, upper jaw (snout), lower jaw dropped wide open, block teeth on both jaws.
box('Skull',(0,-1.95,1.78+HZ),(.38,.48,.32),'skull','head','02_HEAD')
box('Snout',(0,-2.40,1.79+HZ),(.30,.46,.18),'snout','head','02_HEAD')
box('Jaw',(0,-2.28,1.53+HZ),(.28,.66,.11),'jaw','jaw','02_HEAD',rot=(24,0,0))
for side,suffix in [(1,'l'),(-1,'r')]:
    X=lambda x:side*x
    for k,y in enumerate((-2.28,-2.38,-2.48,-2.58)):
        box('ToothUp%d_%s'%(k,suffix),(X(.12),y,1.67+HZ),(.045,.045,.07),'tooth','head','02_HEAD')
    for k,y in enumerate((-2.15,-2.27,-2.39,-2.51)):
        ztop=1.71+(y+2.0)*.44+HZ
        box('ToothLow%d_%s'%(k,suffix),(X(.11),y,ztop+.025),(.045,.045,.07),'tooth','jaw','02_HEAD')
    box('Eye_'+suffix,(X(.185),-2.08,1.84+HZ),(.03,.10,.06),'eye','head','02_HEAD',rot=(0,0,side*-25))
    box('Brow_'+suffix,(X(.178),-2.09,1.905+HZ),(.08,.18,.045),'brow','head','02_HEAD',rot=(20,0,side*-25))
    beam('Horn_'+suffix,(X(.12),-1.85,1.93+HZ),(X(.20),-1.38,2.10+HZ),.10,.10,'bone','head','02_HEAD',.03,.03)
    beam('HornLow_'+suffix,(X(.18),-1.82,1.80+HZ),(X(.28),-1.45,1.84+HZ),.08,.08,'bone','head','02_HEAD',.025,.025)

    # WING = FORELIMB. Thin wing-bone arm (same dark bone as the fingers), elbow out, the
    # wrist knuckle on the ground with two pale thumb claws; fingers fan from the knuckle.
    shoulder=Vector((X(.33),-.55,.86)); elbow=Vector((X(.62),-.80,.56)); W=Vector((X(.66),-.94,.12))
    beam('UpperArm_'+suffix,shoulder,elbow,.11,.12,'wing_bone','upper_arm_'+suffix,'04_WINGS',.09,.10)
    beam('Forearm_'+suffix,elbow,W,.09,.10,'wing_bone','forearm_'+suffix,'04_WINGS',.08,.09)
    box('WristKnuckle_'+suffix,(X(.66),-.96,.06),(.13,.15,.12),'wing_bone','hand_'+suffix,'04_WINGS')
    for k,dx in enumerate((-.035,.035)):
        beam('ThumbClaw%d_%s'%(k,suffix),(X(.66+dx),-1.02,.05),(X(.66+dx*1.5),-1.13,.012),.045,.04,'claw','hand_'+suffix,'04_WINGS',.012,.012)
    tips=[Vector((X(.95),-.70,1.95)),Vector((X(1.15),-.10,1.80)),Vector((X(1.25),.50,1.45)),Vector((X(1.20),1.05,.98)),Vector((X(1.05),1.40,.52))]
    for k,tip in enumerate(tips):
        w0=.075 if k==0 else .055
        beam('WingFinger%d_%s'%(k+1,suffix),W,tip,w0,w0,'wing_bone','hand_'+suffix,'04_WINGS',.03,.03)
        d=(tip-W).normalized()
        beam('WingTip%d_%s'%(k+1,suffix),tip-d*.04,tip+d*.12,.045,.045,'claw','hand_'+suffix,'04_WINGS',.012,.012)
    for k in range(4):
        a,b=tips[k],tips[k+1]; m=W.lerp(a.lerp(b,.5),.86)          # scallop: midpoint pulled towards the knuckle (stays planar)
        poly_slab('Membrane%d_%s'%(k+1,suffix),[W,a,m,b],.025,'membrane','hand_'+suffix,'04_WINGS')
    flank=Vector((X(.37),.20,.95))
    poly_slab('Membrane5_%s'%suffix,[W,tips[4],W.lerp(tips[4].lerp(flank,.5),.88),flank],.025,'membrane','hand_'+suffix,'04_WINGS')
    # Arm membranes: elbow web and the skin from shoulder to knuckle to flank, so the
    # arm visibly belongs to the wing instead of reading as a separate front leg.
    poly_slab('MembraneElbow_%s'%suffix,[shoulder,elbow,W],.025,'membrane','forearm_'+suffix,'04_WINGS')
    poly_slab('MembraneArm_%s'%suffix,[shoulder,W,flank],.025,'membrane','upper_arm_'+suffix,'04_WINGS')

    # Hind legs, deeply bent under the low body: thigh, shin, foot with three pale claws.
    beam('Thigh_'+suffix,(X(.30),.45,.72),(X(.40),.20,.36),.24,.28,'limb','thigh_'+suffix,'03_LEGS')
    beam('Shin_'+suffix,(X(.40),.20,.38),(X(.40),.48,.07),.16,.18,'limb','shin_'+suffix,'03_LEGS')
    box('Foot_'+suffix,(X(.40),.34,.05),(.20,.34,.10),'hand','foot_'+suffix,'03_LEGS')
    for k,dx in enumerate((-.06,.0,.06)):
        beam('FootClaw%d_%s'%(k,suffix),(X(.40+dx),.19,.05),(X(.40+dx*1.3),.07,.012),.05,.045,'claw','foot_'+suffix,'03_LEGS',.014,.014)

# Back spines on chest and hips.
for k,y in enumerate((-.65,-.30,.05)):
    b=Vector((0,y,1.07)); beam('Spike_Back_%d'%k,b,b+SPIKE_DIR*.15,.09,.07,'bone_spike','chest','01_BODY',.022,.018)
for k,y in enumerate((.30,.62)):
    b=Vector((0,y,1.02)); beam('Spike_Hips_%d'%k,b,b+SPIKE_DIR*.13,.085,.07,'bone_spike','hips','01_BODY',.02,.016)

# Long tail grown from the hips through a tapered root, spines along its whole top.
tail=[((0,.78,.80),(0,1.30,.66),.40,.38,.30,.28),((0,1.25,.67),(.10,1.85,.48),.30,.28,.24,.22),((.08,1.80,.49),(.28,2.40,.30),.24,.22,.18,.17),
      ((.26,2.35,.31),(.30,2.95,.17),.18,.17,.12,.11),((.29,2.90,.175),(.15,3.40,.10),.12,.11,.06,.06)]
for i,(a,b,w0,d0,w1,d1) in enumerate(tail):
    beam('Tail_%d'%(i+1),a,b,w0,d0,'tail','tail_%02d'%(i+1),'05_TAIL',w1,d1)
    spikes_along('Spike_Tail%d'%(i+1),a,b,d0,d1,(.30,.80) if i<3 else (.5,),.12-.018*i,.10-.016*i,.07-.009*i,'tail_%02d'%(i+1),'05_TAIL')

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
# Large wing membranes may need 1024 at the same 64 px/m (density never reduced to fit).
SIZE=next(s for s in (256,512,1024) if pack(s))

TARGET=Vector((0,.40,.85))
studio=collections['06_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6,9),1400,6,(1,.92,.81)),('Fill',(6.5,-2.5,6.5),700,6,(.78,.86,1)),('Rim',(0,7,8),1500,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','06_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=6.6; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static wyvern V3 (low body, wing-arm as the only forelimb; reference-driven: fan wings, toothed open jaws, spine row, long body): two hind legs, wings are the forelimbs (hand planted, three wing fingers, membrane), long head, fiery eyes, short horns, few dorsal spines, tapered tail with spade.'
scene['animations_requested']=False
bpy.app.driver_namespace['wyvern']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords)-min(c.z for c in coords),'min_z':min(c.z for c in coords),
        'length_m':max(c.y for c in coords)-min(c.y for c in coords),'width_m':max(c.x for c in coords)-min(c.x for c in coords)}
