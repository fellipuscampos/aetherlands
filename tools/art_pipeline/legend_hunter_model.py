"""Static LegendHunter V1 (Caçador de Lendas, v2_legendary_legend_hunter): the SUPREME (legendary) unit of
the human Archer line, like the Blade Hero for the Warrior line and the Guardian Champion for the
Guardian line. Built from a COPY of the Elite Marksman (same parts, joints and bow rig, so it plays every
clip of the line) and fitted to 2.00 m of BODY (the longbow rises above). Ennobled with GOLD (allowed on
supreme units only) and a trophy: the white PELT of a legendary beast — a white-fur hood PAINTED on the
head with a gold rim (head pieces are painted, never blocks) and a pelt cape down the back. Mail shirt
under ONE plain iron breastplate with a gold edge (no emblem, no separate plates), iron pauldrons and
vambraces with a gold edge only (no stripes), leather boots with white fur cuffs, the face shown (no
mask), a gold-tipped longbow, a gold-banded quiver, white/gold fletching. Not magical. One block per body
part; no visible coplanar faces (check_coplanar). Run INSIDE Blender through the MCP client. Real meters,
front = -Y, ground at Z=0, origin between the feet. Left side = +X (_l). Prepend REBUILD=True to rebuild.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='LegendHunter_V1'
OUT=ROOT/'assets/generated/humans/legend_hunter_v1'
OUT.mkdir(parents=True,exist_ok=True)
if NAME in bpy.data.scenes:
    if not globals().get('REBUILD'): raise RuntimeError('LegendHunter scene exists; preserve manual edits.')
    old=bpy.data.scenes[NAME]
    for c in list(old.collection.children):
        for o in list(c.objects): bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(c)
    for o in list(old.collection.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
    for store in (bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.worlds,bpy.data.cameras,bpy.data.lights,bpy.data.armatures,bpy.data.actions):
        for block in list(store):
            if block.name.startswith(NAME+'_'): store.remove(block)
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
collections={}
for label in ['01_BODY','02_HEAD','03_ARMS','04_LEGS','05_GEAR','06_CLOTH','07_STUDIO']:
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
X=Vector((1,0,0)); Y=Vector((0,1,0)); Z=Vector((0,0,1))
def mesh(name,verts,faces,region,bone,collection,up=(0,0,1)):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(obj)
    obj['part']=name; obj['region']=region; obj['rig_bone']=bone; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj)
    return obj
def fbox(name,center,A,B,C,size,region,bone,collection):
    # Cuboid in a local frame A (width), B (depth/along), C (height). Vertex order z*4+y*2+x.
    c=Vector(center); a,b,d=[v/2 for v in size]
    verts=[c+A*sx*a+B*sy*b+C*sz*d for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,C)
def box(name,center,size,region,bone,collection):
    return fbox(name,center,X,Y,Z,size,region,bone,collection)
def beam(name,start,end,width,depth,region,bone,collection,end_width=None,end_depth=None,side=None):
    # Cuboid (or tapered spike) along start->end; `side` fixes the width axis.
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector(side) if side else Y.cross(axis)
    if u.length<1e-6: u=X.copy()
    u=(u-axis*u.dot(axis)).normalized(); v=axis.cross(u).normalized()
    ew=width if end_width is None else end_width; ed=depth if end_depth is None else end_depth
    verts=[c+u*x*w/2+v*y*d/2 for c,w,d in ((a,width,depth),(b,ew,ed)) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,bone,collection,axis if axis.z>=0 else -axis)

# Clean fit (user review): blocks are STACKED (touching faces only) instead of sunk into each other,
# and no two parts share a visible coplanar face (that is what flickered — z-fighting). Neighbour
# faces always differ by >= 8 mm; check_coplanar() below enforces it.
# ---------------- legs: thin wool thigh, THICK boot shaft (shin), boot; left foot forward ----------------
# User edit in Blender (2026-10-04): shin and foot moved so each leg is STRAIGHT (shin right under the thigh),
# keeping only the small stance offset between the two legs.
for side,t_ in ((1,'l'),(-1,'r')):
    x=side*.115; ly=-.035 if side==1 else .03
    box('Foot_'+t_,(x,ly-.04,.05),(.18,.28,.10),'boot','foot_'+t_,'04_LEGS')
    box('Shin_'+t_,(x,ly,.29),(.16,.18,.38),'elite_boot','shin_'+t_,'04_LEGS')
    box('Thigh_'+t_,(x,ly,.68),(.13,.15,.40),'trousers','thigh_'+t_,'04_LEGS')

# ---------------- pelvis (belt + gambeson skirt), belly (quilted), chest (leather jerkin), head ----------------
box('Pelvis',(0,0,.96),(.40,.22,.16),'mail_skirt','hips','01_BODY')
box('Buckle',(0,-.115,1.00),(.07,.03,.05),'brass','hips','01_BODY')
box('Belly',(0,0,1.12),(.32,.20,.16),'mail','chest','01_BODY')
box('Chest',(0,0,1.34),(.44,.25,.28),'legend_hunter_chest','chest','01_BODY')       # mail shirt under ONE plain iron breastplate, quiver strap
box('Head',(0,-.005,1.615),(.27,.27,.27),'face_hood','head','02_HEAD')
# User edit in Blender (2026-10-04): the hood/cowl BLOCKS were deleted; the hood is PAINTED on the head block
# instead (legend_hunter_paint_save.py, region 'face_hood').

# ---------------- arms: shoulder cube joins the chest (sunk 2 cm into it, top 1 cm above it) ----------------
# Light troop: quilted cloth on both shoulders (no armour).
box('Shoulder_l',(.285,0,1.405),(.17,.23,.19),'elite_pauldron','upper_arm_l','03_ARMS')   # plain iron
box('Shoulder_r',(-.285,0,1.405),(.17,.23,.19),'elite_pauldron','upper_arm_r','03_ARMS')
# Ready stance: the left hand holds the bow upright in front-left; the right (draw) arm hangs relaxed.
ARMS={'l':(Vector((.28,0,1.33)),Vector((.30,-.06,1.09)),Vector((.27,-.28,1.02))),
      'r':(Vector((-.28,0,1.33)),Vector((-.31,.02,1.08)),Vector((-.30,-.08,.86)))}
HAND={}
for t_,(S,E,W) in ARMS.items():
    F=(W-E).normalized()
    beam('UpperArm_'+t_,S,E,.12,.13,'mail','upper_arm_'+t_,'03_ARMS',side=X)
    beam('Forearm_'+t_,E-F*.02,W,.16,.17,'steel_bracer','forearm_'+t_,'03_ARMS',side=X)
    Hf=W+F*.10; HAND[t_]=(W,Hf,F)
    beam('Hand_'+t_,W,Hf,.12,.13,'glove','hand_'+t_,'03_ARMS',side=X)

# ---------------- bow (left hand): upright stave of stepped blocks, string behind, all axis-aligned ----------------
# The stave bows AWAY from the legend_hunter: from the grip, each limb segment steps back (+Y) toward the string.
# Segments touch end to end (no overlap -> no coplanar faces) and get thinner toward the tips.
Wl,Hfl,Fl=HAND['l']
GB=(Wl+Hfl)/2                                                         # grip centre, inside the fist
box('BowGrip',GB,(.07,.075,.14),'bow_grip','hand_l','05_GEAR')
for sgn,t_ in ((1,'u'),(-1,'d')):
    z0=GB.z+sgn*.07
    for k,(ln,dy,sx,sy) in enumerate(((.30,.01,.056,.06),(.27,.06,.044,.05),(.20,.13,.034,.042))):   # LONGBOW: longer limbs
        box('BowLimb_%s%d'%(t_,k+1),(GB.x,GB.y+dy,z0+sgn*ln/2),(sx,sy,ln),'bow_wood','hand_l','05_GEAR'); z0+=sgn*ln
TIP_UP=GB.z+.07+.30+.27+.20; TIP_DN=GB.z-.07-.30-.27-.20
# String in TWO halves meeting at the nocking point (own bones string_u / string_d), so the Attack can pull it
# into a V to the drawing hand. The nocking point sits a little above the grip centre, like on a real bow.
SY=GB.y+.13+.021+.004; ZN=GB.z+.075
box('StringUp',(GB.x,SY,(TIP_UP+ZN)/2),(.008,.008,TIP_UP-ZN),'bow_string','string_u','05_GEAR')
box('StringDown',(GB.x,SY,(ZN+TIP_DN)/2),(.008,.008,ZN-TIP_DN),'bow_string','string_d','05_GEAR')
# Nocked arrow (own bone 'arrow'): nock on the string, shaft forward past the stave on its left side.
AX0=GB.x+.036
box('ArrowShaft',(AX0,SY-.36,ZN),(.012,.72,.012),'arrow_shaft','arrow','05_GEAR')
box('ArrowHead',(AX0,SY-.72-.025,ZN),(.026,.05,.026),'arrow_head','arrow','05_GEAR')
box('ArrowFletch',(AX0,SY-.06,ZN),(.004,.09,.036),'fletching','arrow','05_GEAR')
# ---------------- quiver on the back (right side), fletchings showing over the right shoulder ----------------
box('Quiver',(-.16,.165,1.35),(.11,.09,.46),'quiver','chest','05_GEAR')
# Trophy: the WHITE PELT of a legendary beast hangs from the shoulders down the back (the quiver rides over it).
box('PeltCape',(0,.14,1.22),(.40,.03,.52),'pelt','chest','06_CLOTH')
box('Arrows',(-.16,.165,1.65),(.08,.06,.14),'fletching','chest','05_GEAR')   # peeks over the right shoulder
# Longbow: straight iron nock caps on the tips (no recurve).
box('BowCap_u',(GB.x,GB.y+.13,TIP_UP+.03),(.03,.036,.06),'gold','hand_l','05_GEAR')
box('BowCap_d',(GB.x,GB.y+.13,TIP_DN-.03),(.03,.036,.06),'gold','hand_l','05_GEAR')
# Hunting knife sheathed at the back of the belt (right side).
box('Knife',(-.17,.14,.90),(.04,.05,.22),'knife','hips','05_GEAR')   # 1 cm off the pelt cape plane

def check_coplanar(tol=.004):
    """Visible z-fighting candidates: faces of DIFFERENT parts with the same outward normal, on the same
    plane (< tol) and overlapping. Returns [(part_a, part_b)]."""
    faces=[]
    for o in parts:
        me=o.data; c=sum((v.co for v in me.vertices),Vector())/len(me.vertices)
        for poly in me.polygons:
            vs=[me.vertices[i].co.copy() for i in poly.vertices]; fc=sum(vs,Vector())/len(vs)
            n=poly.normal.normalized()
            if n.dot(fc-c)<0: n=-n                     # outward
            faces.append((o['part'],n,n.dot(fc),vs))
    hits=set()
    for i in range(len(faces)):
        pa,na,da,va=faces[i]
        for j in range(i+1,len(faces)):
            pb,nb,db,vb=faces[j]
            if pa==pb or na.dot(nb)<.999 or abs(da-db)>tol: continue
            # In-plane axes aligned with the world (axis-aligned faces get exact rectangles, no false overlaps).
            u=(X if abs(na.x)<.9 else Y); u=(u-na*u.dot(na)).normalized(); w=na.cross(u)
            ra=[(v.dot(u),v.dot(w)) for v in va]; rb=[(v.dot(u),v.dot(w)) for v in vb]
            ov_u=min(max(x for x,_ in ra),max(x for x,_ in rb))-max(min(x for x,_ in ra),min(x for x,_ in rb))
            ov_w=min(max(y for _,y in ra),max(y for _,y in rb))-max(min(y for _,y in ra),min(y for _,y in rb))
            if ov_u>.002 and ov_w>.002: hits.add(tuple(sorted((pa,pb))))
    return sorted(hits)

# Fit every human troop to exactly 1.80 m (feet stay on the ground).
# The BODY measures 1.80 m; the tall longbow (05_GEAR) may rise above it.
FIT=2.00/max(v.co.z for o in parts if not o.users_collection[0].name.endswith('05_GEAR') for v in o.data.vertices)   # legendary: 2.00 m body
for o in parts:
    for v in o.data.vertices: v.co*=FIT
    o.data.update()
HERO_SCALE=FIT

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

TARGET=Vector((0,-.10,.92))
studio=collections['07_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-5,-6,9),1400,6,(1,.92,.81)),('Fill',(6.5,-2.5,6.5),700,6,(.78,.86,1)),('Rim',(0,7,8),1500,5,(.80,.92,1))]:
    d=bpy.data.lights.new(NAME+'_'+n,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=pos; aim(o,TARGET)
floor=mesh('StudioGround',[(-200,-200,-.004),(200,-200,-.004),(200,200,-.004),(-200,200,-.004)],[(0,1,2,3)],'studio','none','07_STUDIO')
parts.remove(floor)
ground=bpy.data.materials.new(NAME+'_StudioGround'); ground.use_nodes=True
ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
ground.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(ground)
cam=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',cam); studio.objects.link(camera)
cam.type='ORTHO'; cam.ortho_scale=2.5; camera.location=TARGET+Vector((6,-12,5.6)); aim(camera,TARGET); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Static LegendHunter V1 (Caçador de Lendas, legendary): supreme Archer-line unit — white beast-pelt hood (painted, gold rim) and pelt cape, mail under one plain iron breastplate with gold trim, gold-edged iron pauldrons and vambraces, white fur boot cuffs, gold-tipped longbow, gold-banded quiver, white/gold fletching; not magical; 2.00 m body.'
scene['animations_requested']=False
bpy.app.driver_namespace['legend_hunter']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':TARGET,'hero_scale':HERO_SCALE}
coords=[v.co for o in parts for v in o.data.vertices]
result={'scene':NAME,'parts':len(parts),'islands':len(islands),'atlas_size':SIZE,
        'height_m':max(c.z for c in coords),'min_z':min(c.z for c in coords),
        'y':[min(c.y for c in coords),max(c.y for c in coords)],'x':[min(c.x for c in coords),max(c.x for c in coords)],
        'coplanar_overlaps':check_coplanar()}
