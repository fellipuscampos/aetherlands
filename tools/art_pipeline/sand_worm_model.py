"""Static Sand Worm V1 (Verme Colossal, kind colossal_worm): a centipede-like burrowing
worm in the approved cuboid language and metric UV (64 px/m) of the bestiary. Run INSIDE
Blender through the MCP client. No rig or animation yet. Real meters, front = -Y,
ground at Z=0, origin = the ONE logical (attackable) tile, under the rearing front.

Rest pose is fully ABOVE the ground and close to ONE hex: a tall rearing column over the
origin tile like a cobra, and a short tail lying on its legs behind it ("J").
Built for the future Burrow / Emerge clips (it has no Walk): the body is a chain of equal
segments laid along one smooth path, each segment (and each leg) its own future bone
(obj['rig_bone']), so a clip only has to slide the chain along a path that dives into
the ground at the origin (anything below Z=0 is hidden by the terrain prism in game).
Prepend REBUILD=True to discard an existing (unpainted) scene of the same name.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Sand_Worm_V1'
OUT=ROOT/'assets/generated/sand_worms/sand_worm_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('Sand worm scene exists; preserve manual edits.')
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
for label in ['01_BODY','02_HEAD','03_LEGS','05_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,bone,collection='01_BODY',up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['rig_bone']=bone; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def fbox(name,center,X,F,U,size,region,bone,collection='01_BODY'):
    # Cuboid in a local frame: X lateral, F along the body (towards the head), U dorsal.
    c=Vector(center); a,b,d=[v/2 for v in size]
    verts=[c+X*sx*a+F*sy*b+U*sz*d for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,U)
def box(name,center,size,region,bone,collection):
    return fbox(name,center,Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)),size,region,bone,collection)
def beam(name,start,end,width,depth,region,bone,collection,end_width=None,end_depth=None,up=None):
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector((0,1,0)).cross(axis)
    if u.length<1e-6: u=Vector((1,0,0))
    u.normalize(); v=axis.cross(u).normalized()
    ew=width if end_width is None else end_width; ed=depth if end_depth is None else end_depth
    verts=[c+u*x*w/2+v*y*d/2 for c,w,d in ((a,width,depth),(b,ew,ed)) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,up or (axis if axis.z>=0 else -axis))

# ---- Body path (X,Y,Z) of segment centres, from the head joint backwards: a tall, nearly
# vertical rearing column over the origin and a short tail lying behind it ("J"), so the
# whole worm stays close to ONE hex. Frames are
# rotation-minimising (parallel transport from the tail), so segments never twist; X stays
# the body's left/right.
# Colossal scale: grows UP and THICK (head joint at 2.8 m, ~30% thicker), not longer.
COLUMN=[(0,-0.20,2.80),(0,-0.08,2.48),(0,0.00,2.06),(0,0.04,1.60),(0,0.03,1.16),(0,0.04,0.76),(0,0.15,0.46)]
# Short tail lying on the ground behind the column, with a gentle sideways curve ("J").
TAIL=[(0.05,0.47,0.37),(0.20,0.79,0.34),(0.44,1.03,0.31)]
PATH=COLUMN+TAIL
def catmull(points,samples=24):
    pts=[Vector(q) for q in points]; pts=[pts[0]*2-pts[1]]+pts+[pts[-1]*2-pts[-2]]; out=[]
    for i in range(1,len(pts)-2):
        p0,p1,p2,p3=pts[i-1],pts[i],pts[i+1],pts[i+2]
        for k in range(samples):
            t=k/samples; t2=t*t; t3=t2*t
            out.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t2+(-p0+3*p1-3*p2+p3)*t3))
    out.append(pts[-2]); return out
DENSE=catmull(PATH); ARC=[0.0]
for i in range(1,len(DENSE)): ARC.append(ARC[-1]+(DENSE[i]-DENSE[i-1]).length)
LENGTH=ARC[-1]
TAN=[(DENSE[max(0,i-1)]-DENSE[min(len(DENSE)-1,i+1)]).normalized() for i in range(len(DENSE))]   # towards the head
UPS=[None]*len(DENSE); Z=Vector((0,0,1))
UPS[-1]=(Z-TAN[-1]*Z.dot(TAN[-1])).normalized()
for i in range(len(DENSE)-2,-1,-1):
    UPS[i]=(TAN[i+1].rotation_difference(TAN[i])@UPS[i+1]); UPS[i]=(UPS[i]-TAN[i]*UPS[i].dot(TAN[i])).normalized()
def at(s):
    s=max(0.0,min(LENGTH,s))
    i=next(k for k in range(1,len(ARC)) if ARC[k]>=s) if s>0 else 1
    t=(s-ARC[i-1])/max(1e-9,ARC[i]-ARC[i-1])
    F=TAN[i-1].lerp(TAN[i],t).normalized(); U=UPS[i-1].lerp(UPS[i],t); U=(U-F*U.dot(F)).normalized()
    return DENSE[i-1].lerp(DENSE[i],t),F,U.cross(F).normalized(),U

LEG_S=1.25; SEGMENTS=9; SPACING=(LENGTH-0.20)/SEGMENTS
segment_info=[]
for i in range(SEGMENTS):
    k=i/(SEGMENTS-1); s=SPACING*(i+.5)
    p,F,X,U=at(s)
    w=.78-.26*k; h=.60-.16*k; bone='seg_%02d'%(i+1)
    region='collar' if i==0 else 'segment'
    fbox('Segment_%02d'%(i+1),p,X,F,U,(w,SPACING*1.18,h),region,bone,'01_BODY')
    # Dorsal tergite: wider than the core and half sunk into its top, so every ring reads.
    fbox('Tergite_%02d'%(i+1),p+U*(h*.5)-F*SPACING*.06,X,F,U,(w+.10,SPACING*.86,.15),'collar_plate' if i==0 else 'tergite',bone,'01_BODY')
    # One leg pair per segment: out from the flank, knee up, then down. Segments lying on the
    # ground plant the claw tip on Z=0; rearing ones hold the legs splayed towards the belly.
    grounded=U.z>.85
    for side,sx in ((1,'l'),(-1,'r')):
        root=p+X*side*(w*.44)-U*(h*.12)
        knee=root+X*side*LEG_S*(.18+.04*(1-k))+U*.10-F*.04
        tip=knee+X*side*LEG_S*.10-F*.07
        tip=Vector((tip.x,tip.y,.01)) if grounded else tip-U*(h*.35+.10)
        beam('Leg_%02d_%s'%(i+1,sx),root,knee,.11,.105,'leg','leg_%02d_%s'%(i+1,sx),'03_LEGS',.10,.095)
        beam('LegTip_%02d_%s'%(i+1,sx),knee,tip,.10,.095,'leg_tip','leg_%02d_%s'%(i+1,sx),'03_LEGS',.05,.045)
    segment_info.append({'bone':bone,'s':s,'center':list(p),'width':w,'height':h,'grounded':grounded})

# Tail: last tapered segment plus two long pale rear legs (cerci) trailing back.
p,F,X,U=at(LENGTH-.06)
fbox('TailTip',p,X,F,U,(.42,.26,.34),'segment','tail','01_BODY')
for side,sx in ((1,'l'),(-1,'r')):
    a=p+X*side*.13+U*.05-F*.08; b=a+X*side*.24-F*.34+U*.20
    beam('Cercus_%s'%sx,a,b,.09,.08,'cercus','tail','01_BODY',.02,.02)
X=Vector((1,0,0))

# ---- Head: boxy black skull pitched to look forward/down, forcipules, antennae, eyes.
HEAD_S=1.30; head_first=len(parts)
P0=DENSE[0]; HF=Vector((0,-1,-.30)).normalized(); HU=HF.cross(X).normalized()
HL=.56; hc=P0+HF*(HL*.5-.10)+HU*.02
def hp(x,f,u): return hc+X*x+HF*f+HU*u
fbox('Skull',hc,X,HF,HU,(.70,HL,.40),'skull','head','02_HEAD')
fbox('HeadPlate',hp(0,-.04,.20),X,HF,HU,(.58,.40,.08),'head_plate','head','02_HEAD')
fbox('Clypeus',hp(0,.30,.02),X,HF,HU,(.50,.08,.26),'clypeus','head','02_HEAD')
fbox('Mouth',hp(0,.24,-.22),X,HF,HU,(.34,.16,.08),'mouth','jaw','02_HEAD')
for k,x in enumerate((-.12,-.04,.04,.12)):
    fbox('Tooth_%d'%k,hp(x,.31,-.20),X,HF,HU,(.045,.04,.07),'tooth','jaw','02_HEAD')
for side,sx in ((1,'l'),(-1,'r')):
    # Forcipules (venom claws): base block, then two beams curling inwards to a black tip.
    fbox('ClawBase_'+sx,hp(side*.24,.18,-.22),X,HF,HU,(.16,.22,.14),'claw_base','claw_'+sx,'02_HEAD')
    a=hp(side*.26,.26,-.23); b=hp(side*.34,.50,-.26); c=hp(side*.12,.70,-.28)
    beam('Fang_'+sx,a,b,.11,.10,'fang','claw_'+sx,'02_HEAD',.09,.085)
    beam('FangTip_'+sx,b,c,.09,.085,'fang_tip','claw_'+sx,'02_HEAD',.02,.02)
    # Antennae: two segments, forwards and out, thinning to the tip.
    a=hp(side*.22,.20,.18); b=hp(side*.34,.40,.44); c=hp(side*.50,.50,.66)
    beam('Antenna_'+sx,a,b,.06,.06,'antenna','antenna_'+sx,'02_HEAD',.05,.05)
    beam('AntennaTip_'+sx,b,c,.05,.05,'antenna_tip','antenna_'+sx,'02_HEAD',.018,.018)
    # One eye per side on the top front corner (reads from the high game camera), one brow above it.
    fbox('Eye_'+sx,hp(side*.24,.16,.205),X,HF,HU,(.17,.15,.03),'eye','head','02_HEAD')
    fbox('Brow_'+sx,hp(side*.24,.04,.235),X,HF,HU,(.21,.09,.06),'brow','head','02_HEAD')

for obj in parts[head_first:]:
    for v in obj.data.vertices: v.co=P0+(v.co-P0)*HEAD_S
    obj.data.update()

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

TARGET=Vector((0,.15,1.45))
studio=collections['05_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6,9),1400,6,(1,.92,.81)),('Fill',(6.5,-2.5,6.5),700,6,(.78,.86,1)),('Rim',(0,7,8),1500,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','05_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.62,.50,.33,1)   # desert-sand floor
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=5.6; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static sand worm V1 (centipede-like, kind colossal_worm): fully above ground: tall rearing column over the origin tile, short tail lying behind it (J); one leg pair per segment.'
scene['animations_requested']=False
bpy.app.driver_namespace['sand_worm']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET,
 'path':[list(p) for p in PATH],'path_length':LENGTH,'spacing':SPACING,'segments':segment_info}
coords=[v.co for o in parts for v in o.data.vertices]
above=[c for c in coords if c.z>0]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,'path_length':LENGTH,'spacing':SPACING,
        'height_m':max(c.z for c in coords),'min_z':min(c.z for c in coords),
        'visible_y':[min(c.y for c in above),max(c.y for c in above)],'width_m':max(c.x for c in coords)-min(c.x for c in coords)}
