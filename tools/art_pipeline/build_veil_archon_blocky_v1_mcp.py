"""Three-meter empty ceremonial sovereign of Arcanism, an exposed azure cube and a fractured gate."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='veil_archon_blocky_v1'; NAME='Veil_Archon_Blocky_V1'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/veil_archon_blocky_v1_review'
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

# A sovereign of folded space: an empty ceremonial mantle, a visible core and a fractured gate.
centers={'body':Vector((0,.04,1.36)),'chest':Vector((0,.015,2.15)),
 'crown':Vector((0,.02,2.77)),'core':Vector((0,-.235,2.04)),
 'mantle_L':Vector((-.70,.02,2.46)),'mantle_R':Vector((.70,.02,2.46)),
 'hand_L':Vector((-1.10,-.33,1.80)),'hand_R':Vector((1.10,-.33,1.80)),
 'veil_L':Vector((-.36,.035,1.63)),'veil_R':Vector((.36,.035,1.63)),
 'veil_back':Vector((0,.32,2.45))}
parents={'body':'root','chest':'body','crown':'chest','core':'chest',
 'mantle_L':'chest','mantle_R':'chest','hand_L':'chest','hand_R':'chest',
 'veil_L':'body','veil_R':'body','veil_back':'chest'}

# An intentionally generous opening leaves the cube free to turn in the future animations.
for side,s in [('L',-1),('R',1)]:
    prism(side+'_Empty_Mantle_Chest_Rail',[(s*x,z) for x,z in [(.48,1.57),(.65,1.57),(.65,1.86),(.72,1.86),(.72,2.31),(.61,2.31),(.61,2.50),(.48,2.50)]],.36,(0,.015,0),'chest','blue')
    box(side+'_Chest_Silver_Inner_Edge',(s*.48,-.18,2.035),(.027,.027,.78),'chest','silver')
box('Ceremonial_High_Collar',(0,.015,2.59),(.99,.47,.16),'chest','blue_dark')
beam('Collar_Left_Silver',(-.48,-.232,2.59),(0,-.26,2.51),.065,.034,'chest','silver')
beam('Collar_Right_Silver',(0,-.26,2.51),(.48,-.232,2.59),.065,.034,'chest','silver')
box('Lower_Mantle_Bridge',(0,.07,1.49),(.95,.40,.14),'body','blue_dark')
box('Lower_Bridge_Silver_Line',(0,-.14,1.51),(.83,.028,.045),'body','silver_dim')
box('Arcane_Heart_Cube',centers['core'],(.50,.50,.50),'core','core',Euler((math.radians(14),math.radians(20),math.radians(18))).to_matrix())

# There is no face or head beneath this open, floating crown.
for side,s in [('L',-1),('R',1)]:
    prism(side+'_Crown_Upright',[(s*x,z) for x,z in [(.125,2.71),(.23,2.71),(.23,2.93),(.18,2.93),(.18,3.10),(.125,3.10)]],.23,(0,.015,0),'crown','silver')
    box(side+'_Crown_Inner_Blue',(s*.116,-.116,2.86),(.025,.024,.30),'crown','blue')
box('Crown_Top_Bridge',(0,.015,3.015),(.43,.23,.065),'crown','silver')
box('Crown_Central_Tine',(0,.015,3.125),(.095,.17,.17),'crown','silver_light')
box('Crown_Lower_Sill',(0,.015,2.715),(.39,.22,.055),'crown','blue_dark')

# Broad, stepped ceremonial shoulders. Only one major mass and a clear silver edge per side.
for side,s in [('L',-1),('R',1)]:
    bone='mantle_'+side
    profile=[(s*x,z) for x,z in [(.43,2.31),(.43,2.59),(.64,2.59),(.64,2.69),(.95,2.69),(1.22,2.49),
      (1.22,2.26),(1.05,2.26),(1.05,2.18),(.66,2.18),(.66,2.31)]]
    prism(side+'_Royal_Arcane_Mantle',profile,.53,(0,.035,0),bone,'blue')
    beam(side+'_Shoulder_Silver_Crest',(s*.65,-.248,2.64),(s*.96,-.248,2.64),.065,.035,bone,'silver_light')
    beam(side+'_Shoulder_Silver_Slope',(s*.96,-.248,2.64),(s*1.17,-.248,2.485),.065,.035,bone,'silver')
    box(side+'_Shoulder_Outer_Silver',(s*1.19,-.25,2.37),(.045,.035,.19),bone,'silver_dim')
    box(side+'_Shoulder_Inset',(s*.86,-.253,2.405),(.20,.018,.11),bone,'blue_dark')
    # One square-spiral arcane motif, painted in the shoulder inset, replaces scattered crystals.
    hand='hand_'+side
    box(side+'_Floating_Wrist_Cuff',(s*1.10,-.33,1.89),(.34,.37,.27),hand,'blue_dark')
    box(side+'_Cuff_Silver_Rim',(s*1.10,-.33,2.005),(.37,.40,.065),hand,'silver')
    box(side+'_Single_Square_Hand',(s*1.10,-.35,1.58),(.43,.42,.44),hand,'silver_dim')
    box(side+'_Hand_Blue_Facet',(s*1.10,-.571,1.59),(.28,.02,.28),hand,'blue')

# A hollow robe made of three broad planes. Its lower ends float, rather than form feet.
for side,s,bottom in [('L',-1,.39),('R',1,.48)]:
    bone='veil_'+side
    profile=[(s*x,z) for x,z in [(.16,1.62),(.54,1.62),(.54,1.35),(.65,1.35),(.65,.93),(.57,.93),(.57,bottom+.19),
      (.46,bottom+.19),(.46,bottom),(.32,bottom),(.32,bottom+.13),(.20,bottom+.13),(.20,1.10),(.16,1.10)]]
    R=Euler((math.radians(-4),math.radians(-s*4),0)).to_matrix()
    prism(side+'_Floating_Veil',profile,.11,(0,-.015,0),bone,'veil',R)
    beam(side+'_Veil_Silver_Edge',(s*.44,-.096,1.56),(s*.49,-.055,bottom+.20),.033,.022,bone,'silver_dim')
profile=[(-.39,2.49),(.39,2.49),(.39,1.55),(.50,1.55),(.50,.90),(.36,.90),(.36,.47),(.20,.47),(.20,.31),
 (-.12,.31),(-.12,.43),(-.34,.43),(-.34,.72),(-.49,.72),(-.49,1.47),(-.39,1.47)]
prism('Rear_Royal_Veil',profile,.12,(0,.335,0),'veil_back','veil_dark')
box('Rear_Veil_Silver_Collar',(0,.405,2.455),(.73,.025,.045),'veil_back','silver')

# Four large L-shaped portal fragments form one broken square, not a cloud of orbiting debris.
R=Matrix.Rotation(math.pi/4,3,'Y'); portal_center=Vector((0,.65,1.92))
corner=[(.47,.99),(1.04,.99),(1.04,.41),(.88,.41),(.88,.83),(.47,.83)]
for i,(sx,sz) in enumerate([(-1,1),(1,1),(1,-1),(-1,-1)]):
    bone='portal_corner_'+str(i); c=portal_center+R@Vector((sx*.755,0,sz*.70))
    centers[bone]=c; parents[bone]='root'
    prism('Fractured_Veil_Gate_'+str(i),[(sx*x,sz*z) for x,z in corner],.13,portal_center,bone,'portal',R)

coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
GROUND=.25
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
# Current Arcanist palette: midnight blue cloth, silver and azure mana. Metric pixel paint.
palette={'blue':(49,72,115),'blue_dark':(29,43,71),'veil':(49,72,115),'veil_dark':(38,54,87),
 'silver':(156,170,181),'silver_light':(206,220,229),'silver_dim':(113,133,154),
 'portal':(137,154,177),'core':(108,179,248)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(61200+index); yy,xx=np.indices((h,w))
    noise=rng.integers(-6,7,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+noise[:,:,None],0,255); emission=np.zeros((h,w,3),dtype=np.float32)
    if kind in ('veil','veil_dark'):
        for cx in range(5,w-3,13):
            for cy in range(h):
                bend=1 if cy//15%3==1 else 0
                rgb[cy,cx+bend:cx+bend+2]*=.77
                rgb[cy,cx+bend+2:cx+bend+3]*=1.14
        rgb[:2]*=.72
    elif kind.startswith('silver') or kind=='portal':
        rgb[yy<2]=base*.77; rgb[yy>=h-2]=np.minimum(255,base*1.12)
        if kind=='portal' and n.y<-.8:
            # One continuous pixel inscription per fragment, with a quiet blue emission.
            mask=((xx//3+yy//3)%9==0)&(xx>2)&(xx<w-2)&(yy>2)&(yy<h-2)
            rgb[mask]=[88,137,200]; emission[mask]=np.array((88,137,200))/255*.25
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[58,113,207]
        rgb[(xx>w*.28)&(xx<w*.76)&(yy>h*.25)&(yy<h*.76)]=[185,221,255]
        for _ in range(4):
            cx=int(rng.integers(2,max(3,w-3))); cy=int(rng.integers(2,max(3,h-3)))
            rgb[cy:cy+2,cx:cx+2]=[224,243,255]
    if 'Shoulder_Inset' in o.name and n.y<-.8 and w>6 and h>4:
        # An open square spiral recalls the school's portals, rather than a healing cross.
        rgb[h-2,1:w-1]=[118,165,219]
        rgb[1:h-1,w-2]=[118,165,219]
        rgb[1,3:w-1]=[118,165,219]
        rgb[1:max(2,h-3),3]=[118,165,219]
        if h>6: rgb[h-4,3:max(4,w-4)]=[118,165,219]
    light=1.06 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .86
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    if kind=='core': emission=tile[:,:,:3]*.90
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
mat=bpy.data.materials.new(NAME+'_Ceremonial_Blue_Silver_Azure_Core'); mat.use_nodes=True
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
rig['status']='Static Veil Archon: faceless open crown, empty broad mantle, exposed azure cube core, floating square hands, suspended veils and four large portal fragments.'

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
data.type='ORTHO'; data.ortho_scale=4.6; camera.location=(3,-11,4.0); aim(camera,(0,0,1.75)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Three-meter Veil Archon of Arcanism: empty blue and silver ceremonial mantle, faceless floating crown, broad shoulders, two suspended square hands, exposed azure cube and one fractured dimensional gate. Shared by civilizations.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
