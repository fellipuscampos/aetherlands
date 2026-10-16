"""Three-meter empty ceremonial sovereign of Arcanism, an exposed azure cube and a fractured gate."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='veil_archon_blocky_v2'; NAME='Veil_Archon_Blocky_V2'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/veil_archon_blocky_v2_review'
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

# A faceless arcane sovereign: folded ceremonial cloth, an open cowl and one exposed mana cube.
centers={'body':Vector((0,.07,1.38)),'chest':Vector((0,.045,2.12)),
 'crown':Vector((0,.03,2.73)),'core':Vector((0,-.29,2.465)),
 'mantle_L':Vector((-.69,.035,2.40)),'mantle_R':Vector((.69,.035,2.38)),
 'hand_L':Vector((-1.025,-.34,1.66)),'hand_R':Vector((1.075,-.37,1.71)),
 'veil_front':Vector((0,-.025,1.76)),'veil_back':Vector((0,.355,2.48)),
 'veil_side_L':Vector((-.55,.02,1.81)),'veil_side_R':Vector((.55,.02,1.81))}
parents={name:('root' if name=='body' else 'body' if name.startswith('veil_front') else 'chest') for name in centers}
parents['chest']='body'; parents['veil_side_L']=parents['veil_side_R']='body'
def trim(label,points,width,depth,bone,kind='silver'):
    for i in range(len(points)-1): beam(label+'_'+str(i),points[i],points[i+1],width,depth,bone,kind)

# The pointed, asymmetrical cowl surrounds the nucleus, rather than placing a box above it.
left=[(-.07,1.96),(-.39,2.08),(-.64,2.39),(-.64,2.78),(-.54,2.78),(-.54,2.96),(-.24,3.22),(.025,3.22),
 (.025,3.04),(-.26,2.86),(-.43,2.68),(-.43,2.31),(-.21,2.12),(-.025,2.09)]
right=[(.025,2.09),(.24,2.17),(.44,2.38),(.44,2.69),(.26,2.88),(-.025,3.045),(-.025,3.22),
 (.26,3.13),(.54,2.88),(.64,2.65),(.59,2.30),(.42,2.07),(.15,1.94)]
prism('Left_Pointing_Arcane_Cowl',left,.34,(0,.025,0),'crown','cloth')
prism('Right_Pointing_Arcane_Cowl',right,.32,(0,.04,0),'crown','cloth_dark')
trim('Left_Cowl_Silver_Edge',[(-.23,-.159,2.12),(-.50,-.159,2.40),(-.50,-.159,2.76),(-.21,-.159,3.05)],.050,.030,'crown')
trim('Right_Cowl_Silver_Edge',[(.25,-.133,2.15),(.51,-.133,2.40),(.50,-.133,2.71),(.20,-.133,3.02)],.047,.029,'crown','silver_dim')
prism('Cowl_Sovereign_Crest',[(-.055,-.085),(.055,-.085),(.055,.035),(.025,.035),(.025,.11),(-.025,.11),(-.025,.035),(-.055,.035)],.035,(0,-.125,3.19),'crown','silver_light')
box('Exposed_Azure_Mana_Core',centers['core'],(.44,.44,.44),'core','core',Euler((math.radians(13),math.radians(18),math.radians(16))).to_matrix())

# Broad sloped shoulder plates and a layered blue mantle create a regal silhouette.
for side,s in [('L',-1),('R',1)]:
    bone='mantle_'+side; dz=.04 if s<0 else -.015
    profile=[(s*x,z+dz) for x,z in [(.43,2.33),(.43,2.44),(.68,2.65),(.91,2.57),(1.20,2.38),
       (1.20,2.25),(.99,2.20),(.81,2.32),(.55,2.32)]]
    prism(side+'_Silver_Ceremonial_Shoulder',profile,.47,(0,.025,0),bone,'silver')
    # The inner silver layer follows the same cut, rather than forming a rectangular inset panel.
    profile=[(s*x,z+dz) for x,z in [(.48,2.42),(.68,2.58),(.89,2.51),(1.11,2.365),(1.11,2.31),(.87,2.40),(.67,2.49)]]
    prism(side+'_Shoulder_Highlight_Plane',profile,.024,(0,-.224,0),bone,'silver_light')
    profile=[(s*x,z) for x,z in [(.53,2.40),(.93,2.36),(1.10,2.19),(1.10,1.98),(.99,1.98),(.99,1.83),
       (.82,1.83),(.82,1.95),(.68,1.95),(.68,2.12),(.59,2.21)]]
    prism(side+'_Draped_Blue_Mantle',profile,.45,(0,.06,0),bone,'cloth')
    trim(side+'_Mantle_Silver_Hem',[(s*1.055,-.18,2.13),(s*1.055,-.18,2.03),(s*.93,-.18,1.94)],.024,.018,bone,'silver_dim')
    hand='hand_'+side; c=Vector((-1.025,-.34,1.48)) if side=='L' else Vector((1.075,-.37,1.53))
    R=Euler((math.radians(-6),math.radians(s*9),math.radians(s*4))).to_matrix()
    box(side+'_Single_Suspended_Hand',c,(.36,.36,.36),hand,'silver_dim',R)
    box(side+'_Hand_Blue_Binding',c+Vector((0,0,.14)),(.365,.365,.048),hand,'cloth_dark',R)
    # Thin arcane inscriptions are painted into the cuff; no fingers or monitor-like hand panels.

# A pleated, closed cloth volume with an irregular hem. The front never splits into two leg shapes.
def pleated_veil(label,bone,kind,center,widths,hems,y_offsets,depth):
    c=Vector(center); n=7; xs=[-1,-2/3,-1/3,0,1/3,2/3,1]
    vs=[]
    for row,(width,height,ybase) in enumerate(zip(widths,hems,y_offsets)):
        zrow=height if isinstance(height,list) else [height]*n
        front=[c+Vector((x*width/2,ybase+(-.035 if i%2==0 else .055),zrow[i])) for i,x in enumerate(xs)]
        back=[v+Vector((0,depth,0)) for v in reversed(front)]
        vs.extend(front+back)
    ring=2*n; fs=[]
    fs.append(tuple(reversed(range(ring))))
    for row in range(len(widths)-1):
        for i in range(ring):
            j=(i+1)%ring; a=row*ring; b=(row+1)*ring
            fs.append((a+i,a+j,b+j,b+i))
    fs.append(tuple((len(widths)-1)*ring+i for i in range(ring)))
    o=mesh_part(label,vs,fs,bone,kind)
    # Each folded face is planar: metric UVs remain exact even where the hem changes height.
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces)); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free(); o.data.update()
    return o
pleated_veil('Front_Folded_Royal_Veil','veil_front','cloth',(0,-.055,0),[1.10,.98,.64],
  [1.79,1.08,[.49,.39,.33,.21,.34,.43,.51]],[-.005,-.08,-.035],.085)
pleated_veil('Rear_Great_Mantle','veil_back','cloth_dark',(0,.33,0),[1.05,1.19,1.12],
  [2.52,1.27,[.55,.44,.43,.34,.48,.56,.65]],[.01,.095,.16],.09)
for side,s in [('L',-1),('R',1)]:
    profile=[(s*x,z) for x,z in [(.43,1.83),(.65,1.83),(.74,1.43),(.74,1.05),(.64,1.05),(.64,.73),(.52,.73),(.52,.91),(.40,.91),(.40,1.27)]]
    prism(side+'_Outer_Robe_Fold',profile,.115,(0,.10,0),'veil_side_'+side,'cloth_mid')
    trim(side+'_Robe_Silver_Thread',[(s*.54,-.108,1.72),(s*.47,-.145,1.23),(s*.29,-.066,.58)],.024,.014,'veil_front','silver_dim')
prism('Lower_Arcane_Lapel',[(-.44,1.93),(-.20,2.01),(0,1.88),(.22,2.01),(.43,1.94),(.24,1.75),(0,1.67),(-.25,1.77)],.16,(0,-.055,0),'chest','cloth_dark')
trim('Lapel_Silver_Line',[(-.37,-.145,1.91),(0,-.145,1.75),(.37,-.145,1.91)],.036,.022,'chest')

# One subtly engraved fractured portal supports the silhouette instead of overwhelming it.
R=Matrix.Rotation(math.pi/4,3,'Y'); gate=Vector((0,.655,1.86))
profile=[(.45,.97),(1.055,.97),(1.055,.365),(.90,.365),(.90,.815),(.45,.815)]
for i,(sx,sz) in enumerate([(-1,1),(1,1),(1,-1),(-1,-1)]):
    bone='gate_fragment_'+str(i); centers[bone]=gate+R@Vector((sx*.76,0,sz*.67)); parents[bone]='root'
    prism('Fractured_Arcane_Gate_'+str(i),[(sx*x,sz*z) for x,z in profile],.11,gate,bone,'portal',R)
    a=gate+R@Vector((sx*.50,-.064,sz*.925)); b=gate+R@Vector((sx*1.005,-.064,sz*.925))
    end=gate+R@Vector((sx*1.005,-.064,sz*.415))
    trim('Gate_Silver_Inlay_'+str(i),[a,b,end],.026,.018,bone,'portal_edge')

coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
GROUND=.35
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+GROUND))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}

# Metric pixel atlas: blue ceremonial cloth, silver and azure mana, 64 pixels per meter.
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
# Restrained cloth folds and weathered silver; the cube is the only strong light source.
palette={'cloth':(36,57,98),'cloth_dark':(23,36,62),'cloth_mid':(43,65,104),
 'silver':(137,156,174),'silver_light':(182,200,215),'silver_dim':(98,124,150),
 'portal':(64,86,121),'portal_edge':(124,155,190),'core':(88,157,239)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(128100+index); yy,xx=np.indices((h,w))
    clusters=rng.integers(-6,7,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255); emission=np.zeros((h,w,3),dtype=np.float32)
    if kind.startswith('cloth'):
        rgb[:2]*=.76
        if h>10 and w>7:
            for x in range(4,w-2,11):
                rgb[:,x:x+1]*=.78; rgb[:,x+1:x+2]*=1.10
    elif kind.startswith('silver') or kind=='portal_edge':
        rgb[yy<1]=base*.76; rgb[yy>=h-1]=np.minimum(255,base*1.10)
        for _ in range(max(1,w*h//170)):
            x=int(rng.integers(0,w)); y=int(rng.integers(0,h))
            rgb[y:y+1,x:x+2]=np.maximum(0,base-15)
    elif kind=='portal' and n.y<-.8:
        mask=((xx//3+2*(yy//4))%13==1)&(xx>2)&(xx<w-2)&(yy>2)&(yy<h-2)
        rgb[mask]=[101,153,212]; emission[mask]=np.array((101,153,212))/255*.12
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[47,102,191]
        rgb[(xx>w*.30)&(xx<w*.75)&(yy>h*.25)&(yy<h*.73)]=[157,207,249]
        for _ in range(3):
            x=int(rng.integers(2,max(3,w-3))); y=int(rng.integers(2,max(3,h-3)))
            rgb[y:y+2,x:x+2]=[209,235,253]
    light=1.05 if n.z>.8 else .76 if n.z<-.8 else 1 if n.y<0 else .85
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    if kind=='core': emission=tile[:,:,:3]*.78
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
mat=bpy.data.materials.new(NAME+'_Sovereign_Cowl_Folded_Veil_Azure_Core'); mat.use_nodes=True
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
rig['status']='Static Veil Archon: exposed azure core in a pointed open cowl, sloped silver ceremonial shoulders, folded midnight-blue mantle, plain square floating hands and a restrained fractured portal.'

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
data.type='ORTHO'; data.ortho_scale=4.5; camera.location=(3,-11,4.0); aim(camera,(0,0,1.85)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Three-meter Veil Archon of Arcanism: faceless pointed cowl framing one azure cube, sculpted silver shoulders, folded midnight-blue robe with an irregular floating hem, plain suspended square hands and a darker engraved portal. Shared by civilizations.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
