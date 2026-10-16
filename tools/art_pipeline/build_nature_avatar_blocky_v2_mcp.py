"""Three-meter living grove avatar of the druidic school."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='nature_avatar_blocky_v2'; NAME='Nature_Avatar_Blocky_V2'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/nature_avatar_blocky_v2_review'
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

# Reference: a headless root brute, a large arch around the exposed core and a hollow body.
centers={'body':Vector((0,.075,1.20)),'chest':Vector((0,.075,2.04)),
         'crown':Vector((0,.085,2.40)),'core':Vector((0,-.03,2.55)),
         'hanging_root_L':Vector((-.10,.01,1.38)),'hanging_root_R':Vector((.09,.08,1.36))}
parents={'body':'root','chest':'body','crown':'chest','core':'chest','hanging_root_L':'body','hanging_root_R':'body'}
def root_path(label,points,width,depth,bone,kind='wood'):
    for i in range(len(points)-1):
        beam(label+'_'+str(i),points[i],points[i+1],width*(1-.10*i),depth,bone,kind)
def splinter(label,a,b,width,bone,kind='wood_light'):
    # Closed, stepped wooden blade, with a square-ended tip and no rounded cone.
    a,b=Vector(a),Vector(b); length=(b-a).length
    R=(b-a).to_track_quat('Z','Y').to_matrix()
    profile=[(-width/2,0),(width/2,0),(width/2,length*.35),(width*.24,length*.35),
        (width*.24,length*.73),(width*.09,length*.73),(width*.09,length),
        (-width*.09,length),(-width*.09,length*.73),(-width*.24,length*.73),(-width*.24,length*.35),(-width/2,length*.35)]
    return prism(label,profile,width*.65,a,bone,kind,R)

# The torso remains see-through: a few major crossing roots form its outer structure.
root_path('Left_Trunk',[(-.33,.14,1.26),(-.47,.11,1.69),(-.38,.10,2.10),(-.57,.095,2.38)],.24,.30,'chest','wood')
root_path('Right_Trunk',[(.29,.15,1.23),(.41,.14,1.62),(.44,.08,2.09),(.61,.08,2.29)],.22,.28,'chest','wood')
root_path('Back_Spine',[(.15,.30,1.29),(.05,.33,1.79),(-.10,.30,2.17),(0,.27,2.45)],.15,.16,'chest','bark')
root_path('Crossed_Upper_Root',[(-.49,-.11,2.16),(-.18,-.24,2.03),(.15,-.20,2.14),(.53,-.07,2.31)],.17,.19,'chest','wood_light')
root_path('Pelvic_Root',[(-.41,-.065,1.18),(-.22,-.16,1.34),(.17,-.16,1.46),(.43,-.025,1.55)],.24,.27,'body','wood')
root_path('Pelvic_Back',[(-.30,.24,1.20),(.08,.31,1.40),(.35,.20,1.45)],.19,.24,'body','bark')

# Tall angular arch: the core occupies the place where a normal creature's face would be.
root_path('Core_Arch_Left',[(-.12,-.10,2.15),(-.39,-.09,2.41),(-.41,-.01,2.77),(-.23,.035,2.99),(.09,.05,3.07)],.18,.20,'crown','wood_light')
root_path('Core_Arch_Right',[(.19,-.10,2.15),(.42,-.04,2.37),(.44,.04,2.70),(.31,.05,2.94),(.07,.05,3.05)],.17,.19,'crown','wood')
root_path('Core_Back_Bough',[(-.31,.26,2.32),(-.30,.30,2.65),(-.11,.30,2.84),(.23,.27,2.81),(.36,.24,2.54)],.11,.14,'crown','bark')
splinter('Crown_Broken_Tip',(-.17,.015,2.99),(-.27,.02,3.16),.12,'crown')
box('Exposed_Druidic_Core',centers['core'],(.39,.39,.39),'core','core',Euler((math.radians(18),math.radians(25),math.radians(17))).to_matrix())
# Thin living root tendrils hang below the core without covering its front.
for i,(x,y,bottom) in enumerate([(-.15,.045,1.66),(.12,.10,1.73),(.03,.23,1.54)]):
    root_path('Inner_Vine_'+str(i),[(x,y,2.31),(x*.75,y,2.03),(x*.8+.035,y,bottom)],.028,.031,'chest','vine')

# Asymmetric root shoulders and heavy low hands follow the reference's proportions.
for side,s in [('L',-1),('R',1)]:
    shoulder=Vector((s*.61,.075,2.21 if s<0 else 2.17))
    elbow=Vector((s*.83,.015,1.60 if s<0 else 1.58)); wrist=Vector((s*1.02,-.11,.95))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist}); parents.update({upper:'chest',fore:upper,hand:fore})
    beam(side+'_Root_Upper_Arm',shoulder,elbow,.25,.30,upper,'bark')
    root_path(side+'_Upper_Outer_Root',[shoulder+Vector((s*.09,-.14,.08)),elbow+Vector((s*.075,-.12,.08)),elbow+Vector((0,-.13,-.06))],.18,.15,upper,'wood')
    box(side+'_Shoulder_Root_Knot',shoulder+Vector((s*.025,0,.01)),(.39,.40,.36),upper,'bark')
    beam(side+'_Forearm_Trunk',elbow,wrist,.33,.35,fore,'wood')
    beam(side+'_Forearm_Outer_Bark',elbow+Vector((s*.15,.10,-.04)),wrist+Vector((s*.16,.10,.06)),.13,.19,fore,'bark')
    root_path(side+'_Forearm_Winding_Root',[elbow+Vector((-s*.09,-.18,-.03)),(s*.96,-.22,1.30),wrist+Vector((s*.12,-.13,-.05))],.12,.11,fore,'wood_light')
    R=Euler((math.radians(-8),math.radians(s*12),math.radians(-s*5))).to_matrix()
    box(side+'_Single_Block_Hand',wrist+Vector((s*.055,-.035,-.225)),(.43,.42,.53),hand,'wood',R)
    beam(side+'_Hand_Bark_Ridge',wrist+Vector((s*.18,.105,-.07)),wrist+Vector((s*.19,.105,-.41)),.11,.20,hand,'bark')
    # A few large moss masses and seed pods, rather than a dense set of red growths.
    for i,(offset,size,kind) in enumerate([
        ((s*.06,-.18,.12),(.25,.16,.22),'moss'),
        ((-s*.10,.10,.17),(.22,.19,.18),'moss_dark'),
        ((s*.15,.01,-.05),(.16,.20,.22),'moss')]):
        box(side+'_Shoulder_Moss_'+str(i),shoulder+Vector(offset),size,upper,kind)
    box(side+'_Forearm_Moss',(s*.94,-.18,1.18),(.18,.13,.22),fore,'moss_dark')
    box(side+'_Wrist_Seed_Pod',wrist+Vector((-s*.13,-.18,.035)),(.10,.10,.13),fore,'seed')
    splinter(side+'_Elbow_Splinter',elbow+Vector((s*.105,.085,-.04)),elbow+Vector((s*.32,.10,.14)),.115,fore)
    splinter(side+'_Hand_Splinter',wrist+Vector((s*.16,.12,-.18)),wrist+Vector((s*.38,.12,-.42)),.15,hand)
    tip_count=3 if s<0 else 2
    for i in range(tip_count):
        a=shoulder+Vector((s*(.055+i*.10),.055,.10-i*.035))
        b=a+Vector((s*(.16+i*.10),.025,.34-i*.035))
        splinter(side+'_Shoulder_Broken_Bough_'+str(i),a,b,.12 if i else .16,upper)

# Thin, splayed root legs make the massive arms and hollow chest more imposing.
for side,s in [('L',-1),('R',1)]:
    hip=Vector((s*.24,.095,1.34)); knee=Vector((s*.38,.08,.75)); ankle=Vector((s*.46,-.025,.18))
    thigh='thigh_'+side; shin='shin_'+side; foot='root_foot_'+side
    centers.update({thigh:hip,shin:knee,foot:ankle}); parents.update({thigh:'body',shin:thigh,foot:shin})
    beam(side+'_Thigh_Root',hip,knee,.22,.27,thigh,'bark')
    beam(side+'_Thigh_Outer_Root',hip+Vector((s*.13,-.08,.015)),knee+Vector((s*.12,-.08,-.045)),.15,.16,thigh,'wood')
    box(side+'_Knee_Knot',knee,(.25,.29,.24),shin,'bark')
    beam(side+'_Shin_Root',knee,ankle,.22,.24,shin,'wood')
    beam(side+'_Shin_Dark_Ridge',knee+Vector((s*.09,.08,-.05)),ankle+Vector((s*.075,.08,.06)),.095,.13,shin,'bark')
    box(side+'_Root_Heel',(s*.46,.015,.09),(.29,.33,.18),foot,'wood')
    box(side+'_Root_Front',(s*.46,-.215,.055),(.21,.25,.11),foot,'wood')
    box(side+'_Root_Side',(s*.65,-.015,.044),(.25,.18,.088),foot,'bark')
    box(side+'_Knee_Moss',knee+Vector((-s*.065,-.155,.045)),(.18,.10,.20),shin,'moss_dark')
    box(side+'_Hip_Moss',hip+Vector((s*.12,-.13,.01)),(.22,.18,.22),thigh,'moss')
    splinter(side+'_Hip_Broken_Root',hip+Vector((s*.08,.045,.04)),hip+Vector((s*.28,.08,.25)),.12,thigh)
root_path('Waist_Hanging_Root_L',[(-.10,.01,1.38),(-.14,-.025,1.08),(-.11,-.025,.82)],.055,.07,'hanging_root_L','vine')
root_path('Waist_Hanging_Root_R',[(.09,.08,1.36),(.08,.02,1.06),(.13,.02,.70)],.065,.08,'hanging_root_R','vine')

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
# Weathered pale wood, deeply separated bark ridges, restrained moss and luminous green core.
palette={'wood':(133,121,94),'wood_light':(174,159,120),'bark':(76,69,48),
         'moss':(75,108,51),'moss_dark':(49,78,46),'vine':(84,105,47),
         'seed':(155,120,58),'core':(136,238,88)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(91000+index); yy,xx=np.indices((h,w))
    noise=rng.integers(-7,8,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+noise[:,:,None],0,255)
    if kind in ('wood','wood_light','bark','vine'):
        # Grain follows each actual root segment; no identical concentric square motif on every face.
        grain=((xx//2*13+yy//19*5)%19)<2
        rgb[grain]=np.maximum(0,base-23)
        light=(xx%9==3)&(yy%23<17); rgb[light]=np.minimum(255,base+13)
        if min(w,h)>9:
            for _ in range(max(1,w*h//220)):
                cx=int(rng.integers(2,w-2)); cy=int(rng.integers(1,h-1)); length=int(rng.integers(3,9))
                rgb[cy:cy+length,cx:cx+1]=np.maximum(0,base-35)
    elif kind.startswith('moss'):
        clusters=rng.integers(-12,13,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
        rgb=np.clip(base+clusters[:,:,None],0,255)
    elif kind=='core':
        # Broad bright center and a calm dark perimeter; one solid cube with a single texture.
        d=np.maximum(abs((xx+.5)/w-.5),abs((yy+.5)/h-.5))
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[d>.36]=[75,173,56]; rgb[d<.19]=[194,255,148]; rgb[d<.09]=[232,255,202]
    light=1.06 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .87
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    emission=tile[:,:,:3]*.85 if kind=='core' else np.zeros((h,w,3),dtype=np.float32)
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
mat=bpy.data.materials.new(NAME+'_Weathered_Roots_Green_Core'); mat.use_nodes=True
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
rig['status']='Static root entity with hollow body, massive connected arms, angular crown arch and a separate exposed green cube core.'

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
scene['description']='Three-meter root avatar inspired by the user reference: no face, hollow intertwined wooden torso, angular root arch, exposed green cube core, heavy low block hands, splinters and moss.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
