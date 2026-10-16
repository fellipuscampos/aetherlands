"""Three-meter living grove avatar of the druidic school."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='nature_avatar_blocky_v1'; NAME='Nature_Avatar_Blocky_V1'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/nature_avatar_blocky_v1_review'
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

# A living grove given a single deliberate silhouette; no stone armor or floating parts.
centers={'body':Vector((0,.08,1.1)),'chest':Vector((0,.05,1.95)),'head':Vector((0,.02,2.46)),'sapling':Vector((0,-.21,1.56))}
parents={'body':'root','chest':'body','head':'chest','sapling':'chest'}
box('Heartwood_Back',(0,.20,1.93),(.74,.25,.82),'chest','bark_dark')
box('Trunk_Lower',(0,.06,1.19),(.72,.55,.50),'body','bark')
box('Living_Hollow_Shadow',(0,.061,1.92),(.45,.07,.63),'chest','hollow')
# The trunk has a real front opening surrounding a living sprout.
for side,s in [('L',-1),('R',1)]:
    prism(side+'_Hollow_Trunk_Rail',[(s*x,z) for x,z in [(.21,1.53),(.46,1.53),(.46,1.76),(.51,1.76),(.51,2.14),(.39,2.14),(.39,2.36),(.25,2.36),(.25,2.11),(.21,2.11)]],.50,(0,.01,0),'chest','bark')
    beam(side+'_Chest_Cut_Edge',(s*.235,-.25,1.63),(s*.235,-.25,2.13),.055,.025,'chest','cut_wood')
box('Hollow_Upper_Lintel',(0,-.01,2.27),(.64,.47,.16),'chest','bark')
box('Hollow_Root_Sill',(0,-.045,1.56),(.66,.55,.15),'chest','bark')
box('Sapling_Soil',(0,-.15,1.647),(.31,.22,.065),'chest','moss')
beam('Sapling_Stem',(0,-.22,1.67),(.015,-.22,2.08),.048,.042,'sapling','sapwood')
for label,a,b,w in [('Left',(.005,-.22,1.86),(-.15,-.22,1.98),.12),('Right',(.015,-.22,1.98),(.145,-.22,2.11),.11)]:
    beam('Sapling_'+label+'_Twig',a,b,.026,.022,'sapling','sapwood')
    box('Sapling_'+label+'_Leaf',b,(w,.055,.09),'sapling','fresh_leaf',Euler((0,math.radians(-20 if label=='Left' else 20),0)).to_matrix())
box('Sapling_Apical_Bud',(.016,-.22,2.13),(.075,.065,.075),'sapling','fresh_leaf')
# A carved wooden face with recessed eyes; features remain texture-sized and cubic.
box('Neck',(0,.02,2.34),(.26,.32,.20),'head','bark_dark')
prism('Ancient_Wooden_Mask',[(-.28,-.23),(.28,-.23),(.28,.17),(.20,.17),(.20,.29),(-.20,.29),(-.20,.17),(-.28,.17)],.39,(0,.015,2.53),'head','mask')
for side,s in [('L',-1),('R',1)]:
    box(side+'_Eye_Recess',(s*.12,-.186,2.57),(.12,.016,.065),'head','hollow')
    box(side+'_Amber_Eye',(s*.12,-.198,2.57),(.063,.012,.032),'head','amber')
    box(side+'_Mask_Brow',(s*.12,-.202,2.625),(.17,.025,.045),'head','cut_wood')
box('Mask_Chin',(0,-.17,2.315),(.22,.12,.095),'head','cut_wood')
# Branch crown: broad empty spaces and a few strong forks instead of a busy halo.
for side,s in [('L',-1),('R',1)]:
    beam(side+'_Crown_Base',(s*.18,.07,2.69),(s*.32,.07,2.89),.13,.13,'head','bark')
    beam(side+'_Crown_Rising_Bough',(s*.32,.07,2.87),(s*.44,.07,3.10 if s<0 else 3.04),.095,.095,'head','bark')
    beam(side+'_Crown_Outer_Fork',(s*.32,.07,2.88),(s*.63,.07,2.99),.084,.085,'head','bark')
    box(side+'_Crown_Cut_Tip',(s*.44,.07,3.10 if s<0 else 3.04),(.094,.093,.045),'head','cut_wood')
    box(side+'_Crown_Leaf_Cluster',(s*.64,.075,2.97),(.22,.19,.105),'head','leaf_light')
# Connected wooden arms, square hands, shoulder foliage attached to the upper-arm pivots.
for side,s in [('L',-1),('R',1)]:
    shoulder=Vector((s*.55,.01,2.15)); elbow=Vector((s*.78,-.045,1.63)); wrist=Vector((s*.83,-.20,1.20))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist}); parents.update({upper:'chest',fore:upper,hand:fore})
    beam(side+'_Wooden_Upper_Arm',shoulder,elbow,.25,.27,upper,'bark')
    box(side+'_Elbow_Knot',elbow,(.25,.27,.21),fore,'bark_dark')
    beam(side+'_Wooden_Forearm',elbow,wrist,.29,.29,fore,'bark')
    box(side+'_Square_Root_Hand',wrist+Vector((0,-.015,-.105)),(.36,.36,.33),hand,'bark')
    box(side+'_Hand_Moss',(s*.83,-.025,1.24),(.33,.16,.045),hand,'moss')
    # Three deliberate layers, each built from contiguous angular leaf masses.
    for j,(x,y,z,size,kind) in enumerate([
        (.56,.025,2.38,(.55,.53,.20),'leaf_light'),
        (.68,.04,2.23,(.64,.63,.20),'leaf'),
        (.76,.105,2.065,(.59,.67,.17),'leaf_dark'),
        (.52,.34,2.19,(.43,.31,.25),'leaf')]):
        box(side+'_Leaf_Mantle_'+str(j),(s*x,y,z),size,upper,kind)
    box(side+'_Mantle_Outer_Step',(s*.995,.075,2.145),(.19,.38,.16),upper,'leaf')
    # One quiet moss patch on each forearm follows the actual branch surface.
    beam(side+'_Forearm_Moss',elbow+Vector((s*.153,.03,-.04)),wrist+Vector((s*.153,.03,.05)),.022,.14,fore,'moss')
# Legs are sturdy roots, not boots or stone-golem columns.
for side,s in [('L',-1),('R',1)]:
    hip=Vector((s*.245,.075,1.07)); knee=Vector((s*.32,.035,.61)); ankle=Vector((s*.385,-.035,.20))
    thigh='thigh_'+side; shin='shin_'+side; foot='root_foot_'+side
    centers.update({thigh:hip,shin:knee,foot:ankle}); parents.update({thigh:'body',shin:thigh,foot:shin})
    beam(side+'_Upper_Root',hip,knee,.33,.38,thigh,'bark')
    box(side+'_Root_Knee',knee,(.34,.37,.22),shin,'bark_dark')
    beam(side+'_Lower_Root',knee,ankle,.31,.36,shin,'bark')
    # Flat soles all contact Z=0; tapering stepped tips read as spread roots.
    box(side+'_Root_Heel',(s*.385,.01,.105),(.40,.47,.21),foot,'bark')
    box(side+'_Root_Front',(s*.385,-.29,.073),(.29,.34,.146),foot,'bark')
    box(side+'_Root_Outer',(s*.64,.01,.068),(.29,.24,.136),foot,'bark')
    box(side+'_Root_Rear',(s*.43,.34,.062),(.23,.26,.124),foot,'bark')
    box(side+'_Root_Moss',(s*.38,-.13,.222),(.30,.34,.047),foot,'moss')
# Sparse leaves growing from the waist; keep the hollow and mask unobstructed.
for side,s in [('L',-1),('R',1)]:
    box(side+'_Hip_Leaf',(s*.37,.015,1.16),(.34,.51,.17),'body','leaf_dark')
    box(side+'_Hip_Leaf_Step',(s*.44,.07,1.05),(.21,.36,.13),'body','leaf')

coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
GROUND=0.0
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+GROUND))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}

# Metric pixel atlas: forest bark, cut wood and layered foliage, 64 pixels per meter.
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
# Current forest bark/foliage colors, clustered pixel paint at 64 pixels per meter.
palette={'bark':(106,76,47),'bark_dark':(75,54,36),'cut_wood':(174,137,84),
 'sapwood':(139,111,64),'mask':(147,119,73),'hollow':(29,35,24),
 'leaf':(69,112,53),'leaf_light':(92,132,61),'leaf_dark':(48,100,69),
 'moss':(80,109,55),'fresh_leaf':(138,176,76),'amber':(247,201,100)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(20261011+index)
    yy,xx=np.indices((h,w))
    clusters=rng.integers(-8,9,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255)
    if kind in ('bark','bark_dark','mask','sapwood'):
        # Angular long grain, short breaks, no noisy marble pattern.
        grain=((xx//2*19+yy//15*7)%23)<3
        rgb[grain]=np.maximum(0,base-18)
        highlight=(xx%11==2)&(yy%29<18)
        rgb[highlight]=np.minimum(255,base+10)
        if w>14 and h>15:
            cx=w//2+int(rng.integers(-3,4)); cy=h//2
            ring=np.maximum(abs(xx-cx),abs((yy-cy)//2))
            rgb[(ring==3)|(ring==5)]=np.maximum(0,base-15)
    elif kind=='cut_wood':
        ring=np.maximum(abs(xx-w//2),abs(yy-h//2))//3%5
        rgb[ring==0]=base-24; rgb[ring==1]=base+8
    elif kind.startswith('leaf') or kind in ('moss','fresh_leaf'):
        leafnoise=rng.integers(-12,13,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
        rgb=np.clip(base+leafnoise[:,:,None],0,255)
        if h>6: rgb[:2]=np.maximum(0,rgb[:2]-13)
    elif kind=='hollow': rgb=np.broadcast_to(base,(h,w,3)).copy()
    elif kind=='amber': rgb=np.broadcast_to(base,(h,w,3)).copy(); rgb[h//2:,w//2:]=[255,225,151]
    face_light=1.06 if n.z>.8 else .78 if n.z<-.8 else 1 if n.y<0 else .89
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*face_light/255,0,1)
    emission=np.zeros((h,w,3),dtype=np.float32)
    if kind=='amber': emission=tile[:,:,:3]*.65
    # The sprout is living plant matter, not a mana cube or necromantic core.
    if kind=='fresh_leaf': emission=tile[:,:,:3]*.06
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
mat=bpy.data.materials.new(NAME+'_Ancient_Wood_Leaf_Amber'); mat.use_nodes=True
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
rig['status']='Static grounded living grove: connected root limbs, hollow trunk, sapling, carved mask and branch crown.'

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
data.type='ORTHO'; data.ortho_scale=4.3; camera.location=(3,-11,4.0); aim(camera,(0,0,1.5)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Three-meter druidic nature avatar: ancient living wood, root feet, layered forest foliage, branching crown and a living sapling protected in the hollow trunk.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
