"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='veil_archon_blocky_v5'; NAME='Veil_Archon_Blocky_V5'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/veil_archon_blocky_v5_review'
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
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v4'/('veil_archon_blocky_v4.'+ext) for ext in ('glb','blend'))
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

# Strict voxel geometry: all silhouettes are orthogonal steps, not sloping polygon plates.
centers={'body':Vector((0,.07,1.86)),'chest':Vector((0,.07,2.55)),
 'head':Vector((0,.02,3.12)),'core':Vector((0,-.31,2.49)),
 'crown_L':Vector((-.12,.02,3.12)),'crown_R':Vector((.12,.02,3.12)),
 'tail':Vector((0,.06,1.72)),'tail_L':Vector((-.24,.10,1.52)),
 'tail_R':Vector((.24,.10,1.52))}
parents={'body':'root','chest':'body','head':'chest','core':'chest',
 'crown_L':'head','crown_R':'head','tail':'body','tail_L':'body','tail_R':'body'}
for side,s in [('L',-1),('R',1)]:
    for name,c,parent in [('shoulder',(s*.70,.06,2.75),'chest'),
      ('upper_arm',(s*.88,.05,2.64),'chest'),
      ('forearm',(s*1.06,-.01,2.05),'upper_arm_'+side),
      ('hand',(-1.12,-.24,2.37) if side=='L' else (1.36,-.24,1.31),'forearm_'+side)]:
        centers[name+'_'+side]=Vector(c);parents[name+'_'+side]=parent

def stepped(label,profile,depth,y,bone,kind='dark',side=1):
    for a,b in zip(profile,profile[1:]+profile[:1]):
        assert abs(a[0]-b[0])<1e-7 or abs(a[1]-b[1])<1e-7,(label,a,b)
    return prism(label,[(side*x,z) for x,z in profile],depth,(0,y,0),bone,kind)

# The lower body drifts to one side as it narrows, like the reference's suspended black root.
tail=[(-.10,.24),(.02,.24),(.02,.48),(.10,.48),(.10,.88),(.18,.88),
 (.18,1.20),(.26,1.20),(.26,1.60),(.36,1.60),(.36,1.92),(.28,1.92),
 (.28,2.12),(.40,2.12),(.40,2.34),(-.40,2.34),(-.40,2.12),
 (-.28,2.12),(-.28,1.82),(-.20,1.82),(-.20,1.50),(-.12,1.50),
 (-.12,1.10),(-.20,1.10),(-.20,.80),(-.14,.80),(-.14,.48),(-.10,.48)]
stepped('Suspended_Stepped_Body',tail,.30,.14,'tail')
box('Recessed_Chest_Back',(0,.22,2.53),(.54,.30,.58),'chest','dark')

# A continuous dark V collar; its ends rise, its center falls over the chest opening.
collar=[(.08,2.64),(.24,2.64),(.24,2.60),(.40,2.60),(.40,2.44),
 (.56,2.44),(.56,2.52),(.72,2.52),(.72,2.60),(.88,2.60),
 (.88,2.68),(1.04,2.68),(1.04,2.84),(1.12,2.84),(1.12,3.00),
 (.96,3.00),(.96,2.92),(.72,2.92),(.72,2.84),(.40,2.84),
 (.40,2.76),(.08,2.76)]
rim=[(.24,2.68),(.40,2.68),(.40,2.64),(.56,2.64),(.56,2.72),
 (.80,2.72),(.80,2.80),(1.00,2.80),(1.00,2.88),(.80,2.88),
 (.80,2.84),(.56,2.84),(.56,2.76),(.24,2.76)]
for side,s in [('L',-1),('R',1)]:
    stepped(side+'_Broad_V_Collar',collar,.34,.015,'shoulder_'+side,'dark',s)
    stepped(side+'_Collar_Top_Ridge',rim,.045,-.174,'shoulder_'+side,'ridge',s)
    # Armor grows inward to frame the cubic nucleus; no skeletal bars or face.
    chest=[(.28,2.56),(.44,2.56),(.44,2.64),(.60,2.64),(.60,2.48),
      (.52,2.48),(.52,2.24),(.40,2.24),(.40,2.08),(.24,2.08),
      (.24,2.20),(.32,2.20),(.32,2.40),(.28,2.40)]
    stepped(side+'_Chest_Carapace',chest,.24,.005,'chest','dark',s)
    waist=[(.12,1.64),(.28,1.64),(.28,1.80),(.40,1.80),(.40,1.96),
      (.48,1.96),(.48,2.12),(.36,2.12),(.36,2.04),(.28,2.04),
      (.28,1.88),(.20,1.88),(.20,1.76),(.12,1.76)]
    stepped(side+'_Jagged_Waist_Sweep',waist,.24,-.035,'body','ridge',s)
    veins=[(.20,1.80),(.26,1.80),(.26,1.92),(.34,1.92),(.34,2.04),
      (.40,2.04),(.40,2.12),(.34,2.12),(.34,2.08),(.28,2.08),
      (.28,1.98),(.20,1.98)]
    stepped(side+'_Waist_Rose_Mana',veins,.024,-.17,'body','energy',s)
    # Long jagged black sleeves follow the reference, with a single outswept upper thorn.
    upper=[(.76,2.36),(.84,2.36),(.84,2.16),(.92,2.16),(.92,2.00),
      (1.08,2.00),(1.08,2.12),(1.16,2.12),(1.16,2.40),(1.24,2.40),
      (1.24,2.64),(1.16,2.64),(1.16,2.56),(1.04,2.56),
      (1.04,2.72),(.88,2.72),(.88,2.60),(.76,2.60)]
    stepped(side+'_Stepped_Upper_Arm',upper,.29,.035,'upper_arm_'+side,'dark',s)
    upperlight=[(.86,2.20),(.92,2.20),(.92,2.40),(1.00,2.40),(1.00,2.56),
      (.94,2.56),(.94,2.46),(.86,2.46)]
    stepped(side+'_Upper_Arm_Mana',upperlight,.028,-.128,'upper_arm_'+side,'energy',s)
    mantle=[(.96,.72),(1.04,.72),(1.04,.88),(1.16,.88),(1.16,1.04),
      (1.28,1.04),(1.28,1.48),(1.20,1.48),(1.20,1.80),
      (1.12,1.80),(1.12,2.00),(.96,2.00),(.96,1.80),(.88,1.80),
      (.88,1.52),(.96,1.52)]
    stepped(side+'_Long_Broken_Arm_Mantle',mantle,.25,.055,'forearm_'+side,'dark',s)
    outer=[(1.18,1.36),(1.26,1.36),(1.26,1.68),(1.34,1.68),
      (1.34,1.92),(1.26,1.92),(1.26,1.80),(1.18,1.80)]
    stepped(side+'_Mantle_Outer_Thorn',outer,.16,.11,'forearm_'+side,'ridge',s)
    fin=[(.24,.90),(.32,.90),(.32,1.18),(.40,1.18),(.40,1.50),
      (.48,1.50),(.48,1.66),(.32,1.66),(.32,1.50),(.24,1.50)]
    stepped(side+'_Lower_Body_Fin',fin,.17,.14,'tail_'+side,'dark',s)

# Asymmetric spellcaster pose: left spectral arm raised, right extended down and outward.
left=[(-1.18,2.08),(-1.06,2.08),(-1.06,2.40),(-1.18,2.40)]
stepped('Raised_Left_Mana_Forearm',left,.10,-.22,'forearm_L','energy')
box('L_Square_Mana_Palm',(-1.12,-.24,2.435),(.17,.16,.17),'hand_L','energy')
right=[(.98,1.96),(1.08,1.96),(1.08,1.82),(1.20,1.82),(1.20,1.62),
 (1.32,1.62),(1.32,1.46),(1.40,1.46),(1.40,1.28),(1.30,1.28),
 (1.30,1.38),(1.22,1.38),(1.22,1.54),(1.10,1.54),(1.10,1.74),(.98,1.74)]
stepped('Outstretched_Right_Mana_Forearm',right,.10,-.22,'forearm_R','energy')
box('R_Square_Mana_Palm',(1.35,-.24,1.245),(.17,.16,.17),'hand_R','energy')

# No skull, helmet, neck, mouth, or human mask. The crown grows from a small dark void.
head=[(-.08,2.98),(.08,2.98),(.08,3.10),(.16,3.10),(.16,3.22),
 (.08,3.22),(.08,3.28),(-.08,3.28),(-.08,3.22),(-.16,3.22),
 (-.16,3.10),(-.08,3.10)]
stepped('Faceless_Crown_Void',head,.16,.025,'head','dark')
# Open horns instead of an octagonal angel halo: shallow steps sweep to long side points.
horn=[(.04,3.12),(.16,3.12),(.16,3.20),(.32,3.20),(.32,3.28),
 (.56,3.28),(.56,3.32),(.88,3.32),(.88,3.36),(1.00,3.36),
 (1.00,3.40),(.76,3.40),(.76,3.44),(.48,3.44),(.48,3.40),
 (.72,3.40),(.72,3.36),(.48,3.36),(.48,3.32),(.24,3.32),
 (.24,3.24),(.12,3.24),(.12,3.20),(.04,3.20)]
for side,s in [('L',-1),('R',1)]:
    stepped(side+'_Open_Rose_Crown_Horn',horn,.072,-.04,'crown_'+side,'energy',s)

box('Rose_Mana_Core',centers['core'],(.32,.32,.32),'core','core',
    Euler((math.radians(10),math.radians(14),math.radians(10))).to_matrix())
# Explicitly enforce the user's blocky requirement on every solid except the rotating cube.
for o in parts:
    if o['rig_bone']=='core':continue
    for p in o.data.polygons:
        assert max(abs(c) for c in p.normal)> .99999,('Non-voxel face',o.name,p.index)

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
# The supplied reference's dark mineral armor and red-magenta energy, painted in coarse pixels.
palette={'dark':(22,28,32),'ridge':(47,61,65),'energy':(195,35,91),'core':(219,48,111)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal']
    base=np.array(palette[kind],dtype=float);rng=np.random.default_rng(570020+index)
    yy,xx=np.indices((h,w))
    clusters=rng.integers(-4,5,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255);emission=np.zeros((h,w,3),dtype=np.float32)
    if kind in ('dark','ridge'):
        rgb[yy>=h-1]=base+12;rgb[xx<1]=base+7
        if h>8:
            for k in range(max(1,w*h//180)):
                x=int(rng.integers(0,w));y=int(rng.integers(0,h))
                rgb[y:y+2,x:x+4]=base+int(rng.choice([-5,8]))
    elif kind=='energy':
        rgb[xx<1]=[238,76,136];rgb[yy>=h-1]=[252,134,176]
        emission=rgb/255*.45
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx>w*.23)&(xx<w*.73)&(yy>h*.22)&(yy<h*.75)]=[249,145,187]
        rgb[(xx<1)|(yy<1)]=[167,22,72];emission=rgb/255*.65
    light=1.08 if n.z>.8 else .74 if n.z<-.8 else 1 if n.y<0 else .87
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
mat=bpy.data.materials.new(NAME+'_Stepped_Obsidian_Magenta_Core'); mat.use_nodes=True
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
rig['status']='Strict stepped voxel apparition inspired by the supplied image: open magenta crown horns, continuous broad V collar, long broken dark arm mantles, asymmetric spectral arms, drifting tapered body and one cubic magenta chest nucleus. No skull, robot mask, diagonal plate geometry or closed halo.'

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
scene['description']='Strict stepped voxel apparition inspired by the supplied image: open magenta crown horns, continuous broad V collar, long broken dark arm mantles, asymmetric spectral arms, drifting tapered body and one cubic magenta chest nucleus. No skull, robot mask, diagonal plate geometry or closed halo.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
