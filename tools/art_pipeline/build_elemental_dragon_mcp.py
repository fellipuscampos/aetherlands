"""Create the Primordial as a coiled, wingless, blocky eastern dragon via MCP."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix,Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
CONFIG=globals().get('DRAGON_CONFIG',{})
STEM=CONFIG.get('stem','elemental_dragon_v1'); NAME=CONFIG.get('name','Elemental_Dragon_V1')
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/elemental_dragon_review'
assert not (OUT/(STEM+'.glb')).exists(), 'Preserve the existing dragon.'
OUT.mkdir(parents=True,exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
REVIEW.mkdir(parents=True,exist_ok=True); (REVIEW/'.gdignore').touch()
previous_scenes=set(bpy.data.scenes.keys())
protected={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
           for p in (ROOT/'assets/generated/grand_manifestations').glob('*/*.glb')}
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
root=bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
root['gameplay_id']='v2_manifestation_elemental_primordial'
parts=[]; pivots={'root':(Vector((0,0,0)),Vector((0,0,.2)),None)}
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]

def mesh(label,verts,faces,bone,kind,weights=None):
    data=bpy.data.meshes.new(STEM+'_'+label); data.from_pydata(verts,[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), label
    assert bm.calc_volume(signed=True)>1e-9,label
    bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(data.name,data); scene.collection.objects.link(obj)
    obj['part']=label; obj['rig_bone']=bone; obj['surface']=kind; obj['dragon_part']=True
    obj['_weights_json']=json.dumps(weights) if weights else ''
    parts.append(obj); return obj

def box(label,c,size,bone,kind,R=None):
    c=Vector(c); R=R if R is not None else Matrix.Identity(3)
    return mesh(label,[c+R@Vector((x*size[0]/2,y*size[1]/2,z*size[2]/2))
        for z in (-1,1) for y in (-1,1) for x in (-1,1)],FACES,bone,kind)

def beam(label,a,b,width,depth,bone,kind):
    a,b=Vector(a),Vector(b); z=(b-a).normalized()
    x=Vector((1,0,0)); x-=z*x.dot(z)
    if x.length<.01: x=Vector((0,1,0)); x-=z*x.dot(z)
    x.normalize(); y=z.cross(x)
    return box(label,(a+b)/2,(width,depth,(b-a).length),bone,kind,Matrix((x,y,z)).transposed())

def spike(label,base,tip,width,depth,bone,kind):
    base,tip=Vector(base),Vector(tip); z=(tip-base).normalized()
    x=Vector((1,0,0)); x-=z*x.dot(z)
    if x.length<.01: x=Vector((0,1,0)); x-=z*x.dot(z)
    x.normalize(); y=z.cross(x)
    verts=[base+x*sx*width/2+y*sy*depth/2 for sy in (-1,1) for sx in (-1,1)]+[tip]
    return mesh(label,verts,[(0,2,3,1),(0,1,4),(1,3,4),(3,2,4),(2,0,4)],bone,kind)

# A vertical open spiral: the lower tail and upper neck overlap only in
# projection, with depth clearance between the turns and space for the core.
controls=CONFIG.get('controls',[(-.10,-.08,.32),(-.66,.28,.40),(-1.03,.43,.70),(-.92,.38,1.02),
    (-.45,.34,1.17),(.18,.36,.98),(.86,.29,.87),(1.10,.22,1.19),
    (1.04,.19,1.80),(.73,.23,2.17),(.13,.27,2.30),(-.56,.25,2.19),
    (-.98,.14,1.88),(-1.04,.02,1.36),(-.79,-.06,1.09),(-.42,-.10,1.13),
    (.03,-.23,1.30),(.34,-.36,1.69),(.35,-.39,2.11),(.42,-.48,2.48)])
control=[Vector(p) for p in controls]
def catmull(a,b,c,d,t):
    return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
dense=[]
for j in range(len(control)-1):
    for k in range(16): dense.append(catmull(control[max(0,j-1)],control[j],control[j+1],control[min(j+2,len(control)-1)],k/16))
dense.append(control[-1]); lengths=[0.0]
for a,b in zip(dense,dense[1:]): lengths.append(lengths[-1]+(b-a).length)
points=[]; N=40
for i in range(N):
    distance=lengths[-1]*i/(N-1)
    j=next((j for j in range(len(lengths)-1) if lengths[j+1]>=distance),len(lengths)-2)
    points.append(dense[j].lerp(dense[j+1],(distance-lengths[j])/(lengths[j+1]-lengths[j])))
frames=[]; widths=[]
previous_tangent=None; previous_front=None
for i,p in enumerate(points):
    tangent=(points[min(N-1,i+1)]-points[max(0,i-1)]).normalized()
    if CONFIG.get('parallel_transport_frames',False) and previous_tangent is not None:
        front=previous_tangent.rotation_difference(tangent)@previous_front
    else:
        front=Vector((0,-1,0))
    front-=tangent*front.dot(tangent)
    if front.length<.01:
        front=Vector((0,0,1)); front-=tangent*front.dot(tangent)
    front.normalize()
    right=front.cross(tangent).normalized()
    frames.append(Matrix((right,front,tangent)).transposed())
    widths.append(.09+.32*min(1,i/9))
    previous_tangent=tangent.copy(); previous_front=front.copy()
for j in range(N-1):
    index=N-1-j
    pivots['spine_%02d'%j]=(points[index],points[index-1],('root' if j==0 else 'spine_%02d'%(j-1)))
def spine_for(i): return 'spine_%02d'%min(N-2,N-1-i)
verts=[]; weights=[]
for i,(p,R,w) in enumerate(zip(points,frames,widths)):
    verts.extend(p+R@Vector((sx*w/2,sy*w*.46,0)) for sy in (-1,1) for sx in (-1,1))
    bone=spine_for(i)
    joint=min(N-2,max(0,N-2-i))
    influence={bone:.5,'spine_%02d'%joint:.5} if bone!='spine_%02d'%joint else {bone:1.0}
    weights.extend([influence]*4)
faces=[(0,1,3,2),tuple(4*(N-1)+j for j in (0,2,3,1))]
for i in range(N-1):
    a=4*i; b=a+4
    faces.extend([(a,a+1,b+1,b),(a+1,a+3,b+3,b+1),(a+3,a+2,b+2,b+3),(a+2,a,b,b+2)])
mesh('Continuous_serpentine_body',verts,faces,'spine_00','body',weights)

# Broad square belly scales, small mineral dorsal crests and side scutes.
for i in range(2,N-1):
    a,b=points[i],points[i+1]; R=frames[i]; w=widths[i]; bone=spine_for(i)
    front=R@Vector((0,1,0)); middle=(a+b)/2
    box('Belly_scale_%02d'%i,middle+front*(w*.46+.014),(w*.72,.034,(b-a).length*.82),bone,'belly',R)
    if i%2==0:
        radial=Vector((middle.x,0,middle.z-1.55)); axis=R@Vector((0,0,1))
        radial-=axis*radial.dot(axis)
        if radial.length<.05: radial=-front
        radial.normalize()
        if CONFIG.get('body_spikes',True):
            spike('Dorsal_crystal_%02d'%i,middle+radial*w*.40,middle+radial*(w*.42+.18),.10,.10,bone,'mane')
        for side in (-1,1):
            box('Side_scale_%02d_%d'%(i,side),middle+(R@Vector((side*w*.47,.015,0))),(.035,w*.45,(b-a).length*.62),bone,'scale',R)

head=Vector((.42,-.58,2.60)); pivots['head']=(head,head+Vector((0,-.4,0)),'spine_00')
pivots['jaw']=(Vector((.42,-.69,2.35)),Vector((.42,-1.04,2.35)),'head')
box('Dragon_skull',head,(.55,.44,.39),'head','scale')
box('Upper_muzzle',(.42,-.91,2.49),(.43,.42,.22),'head','scale')
box('Dark_mouth',(.42,-.94,2.365),(.405,.39,.055),'head','dark')
box('Lower_jaw',(.42,-.92,2.32),(.42,.40,.105),'jaw','belly')
box('Nose_bridge',(.42,-1.115,2.525),(.40,.070,.11),'head','body')
for side in (-1,1):
    x=head.x+side*.195
    box('Cheek_%d'%side,(head.x+side*.276,-.66,2.48),(.095,.28,.23),'head','body')
    box('Eye_socket_%d'%side,(x,-.807,2.685),(.13,.034,.090),'head','dark')
    box('Luminous_eye_%d'%side,(x,-.829,2.685),(.085,.016,.040),'head','eye')
    box('Eye_pupil_%d'%side,(x-side*.014,-.840,2.683),(.018,.007,.041),'head','dark')
    box('Brow_%d'%side,(x,-.832,2.744),(.16,.04,.051),'head','body',Euler((0,side*.10,side*.08)).to_matrix())
    box('Nostril_%d'%side,(head.x+side*.12,-1.155,2.535),(.055,.012,.028),'head','dark')
    for k in range(2): spike('Fang_%d_%d'%(side,k),(head.x+side*.168,-1.035+k*.16,2.405),(head.x+side*.168,-1.02+k*.16,2.345),.045,.045,'head','ivory')
    horn_a=Vector((head.x+side*.19,-.43,2.76)); horn_b=horn_a+Vector((side*.10,.10,.28))
    horn_c=horn_b+Vector((side*.07,.13,.16)); horn='antler_'+str(side)
    pivots[horn]=(horn_a,horn_b,'head')
    beam('Antler_base_'+str(side),horn_a,horn_b,.080,.075,horn,'gold')
    beam('Antler_crown_'+str(side),horn_b,horn_c,.055,.05,horn,'ivory')
    spike('Antler_branch_'+str(side),horn_b-Vector((0,0,.05)),horn_b+Vector((side*.12,-.12,.17)),.065,.06,horn,'gold')
    whisker=[Vector((head.x+side*.20,-1.08,2.425)),Vector((head.x+side*.41,-1.11,2.45)),
             Vector((head.x+side*.64,-.97,2.62)),Vector((head.x+side*.72,-.82,2.67))]
    for k in range(3):
        bone='whisker_%d_%d'%(side,k)
        pivots[bone]=(whisker[k],whisker[k+1],('head' if k==0 else 'whisker_%d_%d'%(side,k-1)))
        beam('Whisker_%d_%d'%(side,k),whisker[k],whisker[k+1],.027,.025,bone,'ivory')
    for k in range(4 if CONFIG.get('head_spikes',True) else 0):
        base=Vector((head.x+side*.235,-.34+k*.04,2.60-k*.12))
        spike('Head_mane_%d_%d'%(side,k),base,base+Vector((side*(.14+k*.01),.17,.17)),.13,.10,'head','mane')
    spike('Chin_beard_'+str(side),(head.x+side*.07,-.99,2.27),(head.x+side*.15,-.88,2.04),.085,.07,'jaw','mane')

def leg(label,a,b,c,attach):
    a,b,c=Vector(a),Vector(b),Vector(c)
    pivots[label]=(a,b,attach); pivots[label+'_fore']=(b,c,label)
    pivots[label+'_paw']=(c,c+Vector((0,-.17,-.04)),label+'_fore')
    beam(label+'_upper',a,b,.15,.14,label,'body')
    box(label+'_knee',b,(.18,.17,.17),label+'_fore','scale')
    beam(label+'_lower',b,c,.125,.12,label+'_fore','scale')
    box(label+'_palm',c+Vector((0,-.035,-.015)),(.20,.19,.105),label+'_paw','body')
    for toe in (-1,0,1):
        base=c+Vector((toe*.066,-.105,-.005))
        spike(label+'_claw_'+str(toe),base,base+Vector((toe*.017,-.13,-.075)),.050,.055,label+'_paw','ivory')

if CONFIG.get('legs',True):
    leg('fore_l',(.21,-.39,2.05),(-.18,-.58,1.86),(-.57,-.79,1.60),'spine_02')
    leg('fore_r',(.54,-.39,2.05),(.92,-.57,1.84),(1.15,-.76,1.57),'spine_02')
    leg('hind_l',(-.62,-.11,1.13),(-.97,-.34,.85),(-1.12,-.52,.56),spine_for(N-9))
    leg('hind_r',(-.23,-.11,1.13),(.04,-.32,.82),(.29,-.53,.55),spine_for(N-9))

# Preserve the approved head proportions while projecting its whole rig forward.
head_shift=Vector(CONFIG.get('head_shift',(0,0,0)))
head_bones={'head','jaw'}|{name for name in pivots if name.startswith(('antler_','whisker_'))}
for obj in parts:
    if obj['rig_bone'] in head_bones:
        for v in obj.data.vertices: v.co+=head_shift
        obj.data.update()
for name in head_bones:
    a,b,parent=pivots[name]; pivots[name]=(a+head_shift,b+head_shift,parent)
tail_bone='spine_%02d'%(N-2)
for side in (-1,0,1):
    spike('Tail_flame_'+str(side),points[0]+Vector((side*.045,0,.02)),points[0]+Vector((side*.16,-.07,-.15)),.10,.08,tail_bone,'mane')

# The primordial heart is a free cubic pearl, not a painted patch on the body.
core=Vector(CONFIG.get('core',(0,-1.10,1.50))); pivots['core']=(core,core+Vector((0,0,.20)),'root')
core_R=Euler(tuple(math.radians(a) for a in (20,32,12))).to_matrix()
box('Elemental_cubic_heart',core,(.48,)*3,'core','core',core_R)
for axis in range(3):
    other=[j for j in range(3) if j!=axis]
    for sa in (-1,1):
        for sb in (-1,1):
            c=Vector(); c[other[0]]=sa*.242; c[other[1]]=sb*.242
            size=[.014]*3; size[axis]=.495
            box('Heart_edge_%d_%d_%d'%(axis,sa,sb),core+core_R@c,size,'core','gold',core_R)

# Apply a single uniform scale: 3 m of actual geometry, plus an air gap.
coords=[v.co for o in parts for v in o.data.vertices]
low=min(v.z for v in coords); high=max(v.z for v in coords); factor=3.0/(high-low)
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-low)*factor+.35))
for obj in parts:
    for v in obj.data.vertices: v.co=normalized(v.co)
    obj.data.update()
pivots={name:(normalized(a),normalized(b),parent) if name!='root' else (a,b,parent) for name,(a,b,parent) in pivots.items()}

# Per-face metric UVs: restrained rectangular mineral pixels, 64 pixels/m.
DENSITY=64; PAD=2; islands=[]
for obj in parts:
    obj.data.uv_layers.new(name='PixelUV')
    for face in obj.data.polygons:
        n=face.normal.normalized(); up=Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.001: up=Vector((0,1,0)); up-=n*up.dot(n)
        up.normalize(); right=up.cross(n).normalized()
        coords=[Vector((obj.data.vertices[i].co.dot(right),obj.data.vertices[i].co.dot(up))) for i in face.vertices]
        bottom=Vector((min(c.x for c in coords),min(c.y for c in coords))); coords=[c-bottom for c in coords]
        islands.append(dict(obj=obj,face=face.index,coords=coords,w=max(1,math.ceil(max(c.x for c in coords)*DENSITY)),h=max(1,math.ceil(max(c.y for c in coords)*DENSITY))))
def pack(size):
    x=y=PAD; row=0
    for it in sorted(islands,key=lambda d:(-d['h'],-d['w'])):
        w,h=it['w']+2*PAD,it['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        it.update(x=x+PAD,y=y+PAD); x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (1024,2048) if pack(s))
palette={'body':(38,73,80),'scale':(64,105,115),'belly':(159,174,153),'gold':(178,143,84),
    'ivory':(219,219,181),'mane':(93,160,180),'eye':(113,221,237),'dark':(18,31,39),'core':(65,191,225)}
pixels=np.ones((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,:3]=0
emission=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; kind=it['obj']['surface']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(724117+index); yy,xx=np.indices((h,w))
    noise=rng.integers(-5,6,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+noise[:,:,None],0,255); energy=np.zeros((h,w,3),dtype=float)
    if kind in ('body','scale','belly','gold'):
        for patch in range(max(1,w*h//120)):
            x=int(rng.integers(0,w)); y=int(rng.integers(0,h))
            rgb[y:y+2,x:x+max(2,w//5)]=np.clip(base+int(rng.choice([-10,8])),0,255)
    if kind=='core':
        rgb[:]=base
        rgb[(xx>w*.22)&(xx<w*.73)&(yy>h*.26)&(yy<h*.73)]=(141,229,243)
        energy=rgb/255*.8
    elif kind=='eye': energy=rgb/255*.55
    elif kind=='mane': energy=rgb/255*.045
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=rgb/255
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    emission[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(energy,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    face=it['obj'].data.polygons[it['face']]
    for li,c in zip(face.loop_indices,it['coords']): it['obj'].data.uv_layers.active.data[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
images=[]
for suffix,values in [('albedo',pixels),('emission',emission)]:
    image=bpy.data.images.new(STEM+'_'+suffix,SIZE,SIZE,alpha=True)
    image.pixels.foreach_set(values.ravel()); image.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png')); image.file_format='PNG'; image.save(); image.pack(); images.append(image)
material=bpy.data.materials.new(STEM+'_Pixel_Material'); material.use_nodes=True
bsdf=material.node_tree.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value=.88
bsdf.inputs['Specular IOR Level'].default_value=.16; bsdf.inputs['Emission Strength'].default_value=1.0
for im,socket in zip(images,['Base Color','Emission Color']):
    tex=material.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.interpolation='Closest'
    material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[socket])

arm=bpy.data.armatures.new(STEM+'_Skeleton'); rig=bpy.data.objects.new(STEM+'_Rig',arm); scene.collection.objects.link(rig); rig.parent=root
for obj in scene.objects: obj.select_set(False)
rig.select_set(True); bpy.context.view_layer.objects.active=rig; bpy.ops.object.mode_set(mode='EDIT')
for name,(a,b,parent) in pivots.items():
    bone=arm.edit_bones.new(name); bone.head=a; bone.tail=b
for name,(a,b,parent) in pivots.items():
    if parent: arm.edit_bones[name].parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for obj in parts:
    obj.data.materials.append(material); obj.parent=rig
    data=json.loads(obj['_weights_json']) if obj['_weights_json'] else [{obj['rig_bone']:1.0}]*len(obj.data.vertices)
    for index,influences in enumerate(data):
        for name,weight in influences.items():
            group=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name); group.add([index],weight,'REPLACE')
    obj.modifiers.new('Dragon_Skin','ARMATURE').object=rig
    for face in obj.data.polygons: face.use_smooth=False

# Runtime: one material and one skinned mesh; source keeps individual parts.
vertices=[]; faces=[]; uvs=[]; groups={}; triangles=0
for obj in parts:
    start=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    for v in obj.data.vertices:
        for influence in v.groups:
            name=obj.vertex_groups[influence.group].name
            groups.setdefault(name,[]).append((start+v.index,influence.weight))
    obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
data=bpy.data.meshes.new(STEM+'_Runtime'); data.from_pydata(vertices,[],faces); data.update(); data.materials.append(material)
uv=data.uv_layers.new(name='PixelUV')
for loop,value in zip(uv.data,uvs): loop.uv=value
runtime=bpy.data.objects.new(STEM+'_Body',data); scene.collection.objects.link(runtime); runtime.parent=rig
for name,rows in groups.items():
    group=runtime.vertex_groups.new(name=name)
    for index,weight in rows: group.add([index],weight,'REPLACE')
runtime.modifiers.new('Dragon_Skin','ARMATURE').object=rig
for obj in scene.objects: obj.select_set(False)
for obj in (root,rig,runtime): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=False,export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
bpy.data.objects.remove(runtime,do_unlink=True)

def aim(obj,point): obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(STEM+'_World'); world.use_nodes=True; scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.13,.18,1); world.node_tree.nodes['Background'].inputs[1].default_value=.45
for label,pos,power in [('Key',(-4,-6,7),850),('Fill',(5,-3,5),450),('Rim',(0,5,6),900)]:
    light=bpy.data.lights.new(STEM+'_'+label,'AREA'); light.energy=power; light.size=5
    obj=bpy.data.objects.new(light.name,light); scene.collection.objects.link(obj); obj.location=pos; aim(obj,(0,0,1.7))
camera_data=bpy.data.cameras.new(STEM+'_Camera'); camera_data.type='ORTHO'; camera_data.ortho_scale=4.4
camera=bpy.data.objects.new(camera_data.name,camera_data); scene.collection.objects.link(camera); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'; scene.frame_start=scene.frame_end=1
coords=[v.co for obj in parts for v in obj.data.vertices]
low=[min(v[j] for v in coords) for j in range(3)]; high=[max(v[j] for v in coords) for j in range(3)]
report={'name':'Primordial dos Elementos','gameplay_id':'v2_manifestation_elemental_primordial','stem':STEM,
    'pipeline':'live Blender MCP','concept':CONFIG.get('concept','Wingless eastern dragon in an open vertical spiral, with an exposed cubic elemental heart'),
    'height_m':high[2]-low[2],'ground_clearance_m':low[2],'size_m':[b-a for a,b in zip(low,high)],
    'parts':len(parts),'triangles':triangles,'meshes':1,'materials':1,'atlas_size':SIZE,
    'prepared_bones':list(arm.bones.keys()),'spine_bones':N-1,'animations':0,'flight_animation_ready':True,
    'continuous_skinned_body':True,'four_clawed_legs':CONFIG.get('legs',True),'body_spikes':CONFIG.get('body_spikes',True),
    'head_spikes':CONFIG.get('head_spikes',True),'body_surrounds_core':CONFIG.get('body_surrounds_core',False),
    'wings':False,'antlers':True,'articulated_whiskers':True,
    'core_bone':'core','core_center_m':list(pivots['core'][0]),'pixel_filter':'NEAREST',
    'source_front':'Blender -Y / Godot +Z','references':list(protected.keys())}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
for view,pos in [('three_quarter',(5,-9,4.4)),('front',(0,-9,2.1)),('back',(-5,9,4.3)),('side',(9,-.3,3.4))]:
    camera.location=pos; aim(camera,(0,-.1,1.8)); scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(5,-9,4.4); aim(camera,(0,-.1,1.8))
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert previous_scenes.issubset(set(bpy.data.scenes.keys()))
for relative,digest in protected.items(): assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()==digest
bpy.app.driver_namespace[STEM]={'scene':scene,'rig':rig,'root':root,'parts':parts,'report':report,'images':images}
result={k:report[k] for k in ['height_m','ground_clearance_m','parts','triangles','spine_bones','animations']}
