"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='veil_archon_blocky_v4'; NAME='Veil_Archon_Blocky_V4'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/veil_archon_blocky_v4_review'
assert NAME not in bpy.data.scenes, 'Preserve previous work.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'scripts/data/UnitDatabase.gd',ROOT/'assets/generated/magic/elder_lich/elder_lich.glb']
for stem in ['archdemon_blocky_v5_animated','seraph_blocky_v4_animated','elder_lich_blocky_v3_animated','elder_lich_blocky_v2']:
    folder=ROOT/'assets/generated/grand_manifestations'/stem
    protected.extend(folder/(stem+'.'+ext) for ext in ('glb','blend'))
protected.append(ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb')
for relative in [
    'assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1.glb',
    'assets/generated/humans/human_necromancer_v1/human_necromancer_v1.glb',
    'assets/generated/grand_manifestations/elder_lich_blocky_v1/elder_lich_blocky_v1.glb',
    'assets/generated/grand_manifestations/elder_lich_blocky_v1/elder_lich_blocky_v1.blend']:
    protected.append(ROOT/relative)
protected.extend(ROOT/'assets/generated/grand_manifestations'/'nature_avatar_blocky_v1'/('nature_avatar_blocky_v1.'+ext) for ext in ('glb','blend'))
protected.extend(ROOT/'assets/generated/grand_manifestations'/'nature_avatar_blocky_v2'/('nature_avatar_blocky_v2.'+ext) for ext in ('glb','blend'))
for stem in ['nature_avatar_blocky_v3','nature_avatar_blocky_v4','nature_avatar_blocky_v5_animated']:
    protected.extend(ROOT/'assets/generated/grand_manifestations'/stem/(stem+'.'+ext) for ext in ('glb','blend'))
protected.extend(ROOT/'assets/generated/humans/human_arcanist_v1'/('human_arcanist_v1.'+ext) for ext in ('glb','blend'))
if (ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v1/veil_archon_blocky_v1.glb').is_file():
    protected.append(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v1/veil_archon_blocky_v1.glb')
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v2'/('veil_archon_blocky_v2.'+ext) for ext in ('glb','blend'))
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v3'/('veil_archon_blocky_v3.'+ext) for ext in ('glb','blend'))
old_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
col=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(col)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=bpy.data.objects.new(NAME+'_ROOT',None); col.objects.link(root); root.empty_display_size=.2
parts=[]
def mesh_part(label,vertices,faces,bone,kind,R=None):
    R=R if R is not None else Matrix.Identity(3)
    me=bpy.data.meshes.new(NAME+'_'+label); me.from_pydata(vertices,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(me); bm.free(); me.update()
    o=bpy.data.objects.new(me.name,me); col.objects.link(o)
    o['rig_bone']=bone; o['kind']=kind; o['local_rotation']=list(R.to_euler('XYZ'))
    o['primitive']='closed planar sharp-edged prism; flat shaded; rigid pivot'
    parts.append(o); return o

def box(label,center,size,bone,kind='iron',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); s=Vector(size)*.5
    vs=[c+R@Vector((x*s.x,y*s.y,z*s.z)) for x,y,z in
        [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh_part(label,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,kind,R)

def prism(label,profile,depth,center,bone,kind='iron',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); n=len(profile)
    vs=[c+R@Vector((x,y,z)) for y in (-depth/2,depth/2) for x,z in profile]
    fs=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    fs.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vs,fs,bone,kind,R)

def frame(label,center,width,height,rim,depth,bone,kind='edge',R=None):
    # One closed annulus with a real opening, not a black rectangle drawn onto a box.
    R=R if R is not None else Matrix.Identity(3); c=Vector(center)
    outline=[(-width/2,-height/2),(width/2,-height/2),(width/2,height/2),(-width/2,height/2)]
    inner=[(-width/2+rim,-height/2+rim),(width/2-rim,-height/2+rim),(width/2-rim,height/2-rim),(-width/2+rim,height/2-rim)]
    vs=[c+R@Vector((x,y,z)) for y in (-depth/2,depth/2) for contour in (outline,inner) for x,z in contour]
    fs=[]
    for i in range(4):
        j=(i+1)%4
        fs.extend([(i,j,4+j,4+i),(8+i,12+i,12+j,8+j),(i,8+i,8+j,j),(4+i,4+j,12+j,12+i)])
    return mesh_part(label,vs,fs,bone,kind,R)

def beam(label,a,b,width,depth,bone,kind='iron'):
    a,b=Vector(a),Vector(b); R=(b-a).to_track_quat('Z','Y').to_matrix()
    return box(label,(a+b)/2,(width,depth,(b-a).length),bone,kind,R)

# A continuous floating armored apparition, following the second user reference.
centers={'body':Vector((0,.04,1.90)), 'chest':Vector((0,.03,2.54)),
 'head':Vector((0,.02,3.07)), 'halo':Vector((0,.02,3.40)),
 'core':Vector((0,-.28,2.49)), 'tail':Vector((0,.055,1.52)),
 'tail_L':Vector((-.25,.12,1.63)), 'tail_R':Vector((.25,.12,1.63))}
parents={'body':'root','chest':'body','head':'chest','halo':'head','core':'chest',
 'tail':'body','tail_L':'body','tail_R':'body'}
for side,s in [('L',-1),('R',1)]:
    for name,c,parent in [
      ('shoulder',(s*.69,.025,2.88),'chest'),
      ('upper_arm',(s*.91,.025,2.71),'chest'),
      ('forearm',(s*1.08,-.03,2.02),'upper_arm_'+side),
      ('hand',(s*1.12,-.08,1.20),'forearm_'+side)]:
        centers[name+'_'+side]=Vector(c); parents[name+'_'+side]=parent

def loft(label,rings,bone,kind='armor'):
    # Eight flat facets per section: thick in depth, square cuts, no rounded bevels.
    vs=[]
    for z,w,d,y in rings:
        cut=min(w,d)*.22
        vs.extend((x,y+q,z) for x,q in [(-w+cut,-d),(w-cut,-d),(w,-d+cut),
          (w,d-cut),(w-cut,d),(-w+cut,d),(-w,d-cut),(-w,-d+cut)])
    fs=[tuple(reversed(range(8))),tuple(range((len(rings)-1)*8,len(rings)*8))]
    for k in range(len(rings)-1):
        for i in range(8):
            a=k*8+i;b=k*8+(i+1)%8;c=(k+1)*8+(i+1)%8;d=(k+1)*8+i
            fs.extend([(a,b,c),(a,c,d)])
    return mesh_part(label,vs,fs,bone,kind)

# The back and lower torso form one tapering silhouette, not a skeleton or robe.
loft('Dark_Central_Cuirass',[(1.46,.17,.13,.20),(1.93,.25,.19,.20),
 (2.38,.33,.20,.20),(2.82,.40,.19,.22)],'chest')
loft('Long_Suspended_Body_Point',[(.32,.035,.035,.11),(.64,.075,.060,.09),
 (1.02,.14,.09,.08),(1.45,.23,.13,.08),(1.80,.30,.16,.09)],'tail')

for side,s in [('L',-1),('R',1)]:
    # Broad collar tips flare outward, then fold down into the chest.
    collar=[(.18,2.83),(.56,2.71),(.94,2.85),(1.12,3.06),(.72,2.99),(.30,3.08)]
    prism(side+'_Swept_Collar',[(s*x,z) for x,z in collar],.36,(0,-.06,0),'shoulder_'+side,'edge')
    chest=[(.30,2.78),(.68,2.82),(.61,2.51),(.49,2.30),(.32,2.18),(.28,2.31)]
    prism(side+'_Open_Pectoral_Plate',[(s*x,z) for x,z in chest],.21,(0,-.095,0),'chest','armor')
    trim=[(.35,2.78),(.67,2.83),(.65,2.76),(.36,2.69)]
    prism(side+'_Collar_Azure_Seam',[(s*x,z) for x,z in trim],.022,(0,-.255,0),'shoulder_'+side,'facet')
    waist=[(.10,1.58),(.30,1.73),(.46,2.11),(.31,2.21),(.22,1.97),(.10,1.83)]
    prism(side+'_Waist_Sweep',[(s*x,z) for x,z in waist],.23,(0,-.11,0),'body','edge')
    waistglow=[(.23,1.80),(.33,1.91),(.41,2.10),(.365,2.15),(.29,1.96)]
    prism(side+'_Waist_Mana_Inlay',[(s*x,z) for x,z in waistglow],.019,(0,-.237,0),'body','energy')
    # Two articulated armor segments with exposed mana links; square palms below.
    beam(side+'_Upper_Arm_Mana_Link',(s*.90,.035,2.70),(s*1.08,-.03,2.02),.11,.10,'upper_arm_'+side,'energy')
    upper=[(.76,2.55),(.93,2.79),(1.10,2.64),(1.03,2.21),(1.13,2.06),(.97,2.01),(.84,2.22)]
    prism(side+'_Upper_Arm_Casing',[(s*x,z) for x,z in upper],.30,(0,.04,0),'upper_arm_'+side,'armor')
    # Only one outward spur per arm, rather than a cloud of spines.
    spur=[(1.03,2.39),(1.17,2.47),(1.29,2.67),(1.25,2.38),(1.12,2.23)]
    prism(side+'_Elbow_Swept_Spur',[(s*x,z) for x,z in spur],.19,(0,.075,0),'upper_arm_'+side,'edge')
    beam(side+'_Forearm_Mana_Link',(s*1.08,-.03,2.02),(s*1.12,-.08,1.19),.10,.10,'forearm_'+side,'energy')
    lower=[(.98,1.87),(1.14,2.00),(1.27,1.84),(1.28,1.43),(1.18,1.17),(.99,1.35),(.95,1.60)]
    prism(side+'_Long_Angular_Vambrace',[(s*x,z) for x,z in lower],.33,(0,-.02,0),'forearm_'+side,'armor')
    front=[(1.025,1.45),(1.10,1.53),(1.14,1.92),(1.10,1.94),(1.035,1.75)]
    prism(side+'_Forearm_Azure_Seam',[(s*x,z) for x,z in front],.021,(0,-.198,0),'forearm_'+side,'facet')
    box(side+'_Square_Floating_Hand',(s*1.115,-.08,1.11),(.205,.23,.24),'hand_'+side,'edge')
    # The outer gauntlet flows into a single clipped blade, keeping the silhouette sinister.
    cuff=[(1.20,1.50),(1.31,1.61),(1.30,1.09),(1.17,.91),(1.13,.91),(1.20,1.21)]
    prism(side+'_Gauntlet_Downward_Blade',[(s*x,z) for x,z in cuff],.19,(0,.095,0),'hand_'+side,'armor')
    skirt=[(.21,1.67),(.40,1.77),(.45,1.52),(.34,1.04),(.29,.87),(.25,1.21)]
    prism(side+'_Lower_Armor_Fin',[(s*x,z) for x,z in skirt],.18,(0,.13,0),'tail_'+side,'armor')

# One simple cubic mana core floats in the open upper chest.
box('Azure_Mana_Core',centers['core'],(.29,.29,.29),'core','core',
    Euler((math.radians(12),math.radians(18),math.radians(14))).to_matrix())

# An abstract face plate with one narrow blue slit replaces the skull completely.
loft('Faceless_Crown_Mask',[(2.96,.07,.09,-.01),(3.09,.16,.12,-.01),
 (3.24,.20,.11,.0)],'head','edge')
box('Single_Crown_Light_Slit',(0,-.141,3.135),(.18,.015,.025),'head','energy')
beam('Crown_Neck_Energy',(0,.05,2.85),(0,.05,3.02),.075,.075,'head','energy')

def crown_annulus(label,outer,inner,z,thickness,kind):
    n=len(outer)
    vs=[(x,y,z+dz) for dz in (-thickness/2,thickness/2) for ring in (outer,inner) for x,y in ring]
    fs=[]
    for i in range(n):
        j=(i+1)%n
        fs.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
          (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    return mesh_part(label,vs,fs,'halo',kind)

# A broad horizontal octagonal blade halo, strongly visible from the game's camera.
outer=[(-.82,-.08),(-.59,-.30),(.59,-.30),(.82,-.08),(.82,.08),(.59,.30),(-.59,.30),(-.82,.08)]
inner=[(-.62,-.035),(-.47,-.19),(.47,-.19),(.62,-.035),(.62,.035),(.47,.19),(-.47,.19),(-.62,.035)]
crown_annulus('Wide_Horizontal_Crown',outer,inner,3.39,.065,'edge')
glow_outer=[(x*.98,y*.98) for x,y in outer]
glow_inner=[(x*1.045,y*1.10) for x,y in inner]
crown_annulus('Crown_Azure_Surface',glow_outer,glow_inner,3.426,.015,'energy')
for side,s in [('L',-1),('R',1)]:
    profile=[(.61,3.34),(.92,3.41),(.92,3.445),(.73,3.465),(.57,3.42)]
    prism(side+'_Crown_Swept_Tip',[(s*x,z) for x,z in profile],.085,(0,0,0),'halo','energy')

coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
GROUND=.35
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+GROUND))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}

# Metric pixel atlas: black stone, spectral blue bone and azure mana, 64 pixels per meter.
DENSITY=64; PAD=2; islands=[]
for o in parts:
    me=o.data; me.uv_layers.new(name='Metric_Pixel_UV'); R=Euler(o['local_rotation'],'XYZ').to_matrix()
    for p in me.polygons:
        n=p.normal.normalized(); up=R@Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.001: up=R@Vector((0,1,0)); up-=n*up.dot(n)
        up.normalize(); right=up.cross(n).normalized()
        coords=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        lo=Vector((min(v.x for v in coords),min(v.y for v in coords))); coords=[v-lo for v in coords]
        islands.append(dict(obj=o,polygon=p.index,normal=R.transposed()@n,coords=coords,
            w=max(1,math.ceil(max(v.x for v in coords)*DENSITY)),h=max(1,math.ceil(max(v.y for v in coords)*DENSITY))))
def pack(size):
    x=y=PAD; row=0
    for it in sorted(islands,key=lambda d:(-d['h'],-d['w'])):
        w,h=it['w']+2*PAD,it['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        it['x']=x+PAD; it['y']=y+PAD; x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (512,1024,2048) if pack(s))
# Restrained directional pixel painting. Blue energy is confined to joints, crown and core.
palette={'armor':(27,37,47),'edge':(48,66,78),'facet':(49,92,133),
 'energy':(66,151,221),'core':(86,163,240)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal']
    base=np.array(palette[kind],dtype=float);rng=np.random.default_rng(450020+index)
    yy,xx=np.indices((h,w))
    clusters=rng.integers(-3,4,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255);emission=np.zeros((h,w,3),dtype=np.float32)
    if kind in ('armor','edge'):
        rgb[yy>=h-1]=base+13
        rgb[xx<1]=base+8
        if h>10 and w>6:
            # A few broad brush marks suggest hard mineral plates, without noisy random pixels.
            for k in range(max(1,w*h//420)):
                x=int(rng.integers(1,max(2,w-2)));y=int(rng.integers(1,max(2,h-2)))
                rgb[y:y+2,x:x+4]=base+int(rng.choice([-5,6]))
    elif kind=='facet':
        rgb[xx<1]=base+24;emission=rgb/255*.07
    elif kind=='energy':
        rgb[yy>=h-1]=[137,205,251];emission=rgb/255*.30
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx>w*.23)&(xx<w*.72)&(yy>h*.22)&(yy<h*.75)]=[153,211,250]
        rgb[(xx<1)|(yy<1)]=[52,115,194]
        emission=rgb/255*.60
    light=1.1 if n.z>.8 else .74 if n.z<-.8 else 1 if n.y<0 else .88
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)

images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(data.reshape(-1)); im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png'))
    im.file_format='PNG'; im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.new(NAME+'_Dark_Armor_Azure_Crown_Core'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.90
bsdf.inputs['Specular IOR Level'].default_value=.14
for im,socket in zip(images,['Base Color','Emission Color']):
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=im; node.interpolation='Closest'
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
bsdf.inputs['Emission Strength'].default_value=.8
for o in parts: o.data.materials.append(mat)

# Only rigid pivots are prepared. No skin bending, NLA or animation is added at this model stage.
arm=bpy.data.armatures.new(NAME+'_Prepared_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); col.objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=arm.edit_bones.new('root'); b.head=(0,0,0); b.tail=(0,0,.2); b.use_deform=False
for n,c in centers.items():
    b=arm.edit_bones.new(n); b.head=c; b.tail=c+Vector((0,0,.15))
for n in centers: arm.edit_bones[n].parent=arm.edit_bones[parents[n]]
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    o.parent=rig; o.modifiers.new('Prepared_Rigid_Pivots','ARMATURE').object=rig
rig['status']='Suspended dark armored apparition: broad swept collar, long articulated arms, tapered floating body, faceless crown mask, horizontal azure blade halo and one exposed cubic chest core. No skull, skeletal ribs or feet.'

def aim(o,p): o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.13,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45; scene.world=world
for label,pos,power,color in [('Key',(-4,-6,8),850,(.94,.98,1)),('Fill',(5,-3,5),550,(.79,.88,1)),('Rim',(0,5,7),850,(.9,1,.96))]:
    data=bpy.data.lights.new(NAME+'_'+label,'AREA'); data.energy=power; data.size=5; data.color=color
    o=bpy.data.objects.new(data.name,data); studio.objects.link(o); o.location=pos; aim(o,(0,0,1.8))
me=bpy.data.meshes.new(NAME+'_StudioFloorMesh'); me.from_pydata([(-200,-200,-.01),(200,-200,-.01),(200,200,-.01),(-200,200,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_StudioFloor',me); studio.objects.link(floor)
gm=bpy.data.materials.new(NAME+'_Floor'); gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.07,.09,.13,1)
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(gm)
data=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera)
data.type='ORTHO'; data.ortho_scale=4.8; camera.location=(3,-11,4.0); aim(camera,(0,0,1.85)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Suspended dark armored apparition: broad swept collar, long articulated arms, tapered floating body, faceless crown mask, horizontal azure blade halo and one exposed cubic chest core. No skull, skeletal ribs or feet.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
