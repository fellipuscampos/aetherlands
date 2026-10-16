"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='veil_archon_blocky_v3'; NAME='Veil_Archon_Blocky_V3'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/veil_archon_blocky_v3_review'
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

# User reference: a spectral rib cage within massive, fractured black crescent carapaces.
centers={'body':Vector((0,.045,1.66)),'chest':Vector((0,.03,2.15)),
 'head':Vector((0,-.015,2.62)),'core':Vector((0,-.47,2.045)),
 'carapace_L':Vector((-.74,.075,2.22)),'carapace_R':Vector((.74,.075,2.22)),
 'blade_L':Vector((-.82,.015,1.40)),'blade_R':Vector((.82,.015,1.40)),
 'hip_L':Vector((-.24,.07,1.47)),'hip_R':Vector((.24,.07,1.47)),
 'tail_center':Vector((0,.065,1.17)),'tail_L':Vector((-.13,.115,1.12)),
 'tail_R':Vector((.13,.10,1.14))}
parents={'body':'root','chest':'body','head':'chest','core':'chest',
 'carapace_L':'chest','carapace_R':'chest','blade_L':'body','blade_R':'body',
 'hip_L':'body','hip_R':'body','tail_center':'body','tail_L':'body','tail_R':'body'}
def shell(label,profile,depth,center,bone,kind='obsidian'):
    # A planar inclined front, thick outer edge and flat back give a solid angular carapace.
    c=Vector(center); n=len(profile)
    vs=[c+Vector((x,-depth*.35-.32*(abs(x)-.70),z)) for x,z in profile]
    vs.extend(c+Vector((x,depth*.5,z)) for x,z in profile)
    fs=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    fs.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vs,fs,bone,kind)
def blue_inlay(label,profile,host_depth,center,bone):
    c=Vector(center); n=len(profile)
    front=[c+Vector((x,-host_depth*.35-.32*(abs(x)-.70)-.007,z)) for x,z in profile]
    vs=front+[v+Vector((0,.022,0)) for v in front]
    fs=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    fs.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vs,fs,bone,'blue_facet')

# The exposed structure is built from short rectangular ribs around an energy spine.
box('Spectral_Cervical_Spine',(0,.035,2.35),(.072,.072,.45),'chest','energy_dim')
box('Spectral_Abdominal_Spine',(0,.055,1.63),(.067,.07,.58),'body','energy_dim')
for i,z in enumerate((2.45,2.31,2.16,2.00,1.85)):
    for side,s in [('L',-1),('R',1)]:
        width=.30 if i<3 else .25
        a=(s*.075,-.025,z); b=(s*(width+.075),-.025,z+.060 if i<3 else z+.025)
        beam(side+'_Spectral_Rib_'+str(i),a,b,.062,.058,'chest','bone_blue')
        box(side+'_Rib_Outer_Knot_'+str(i),(s*(width+.075),-.010,z+.065 if i<3 else z+.035),(.060,.10,.083),'chest','bone_blue')
for side,s in [('L',-1),('R',1)]:
    beam(side+'_Spectral_Clavicle',(s*.065,.005,2.45),(s*.39,.01,2.50),.055,.056,'chest','bone_blue')
    beam(side+'_Outer_Collar_Shard',(s*.39,.04,2.48),(s*.61,.045,2.58),.15,.17,'chest','obsidian')
box('Spectral_Skull',(0,-.008,2.635),(.30,.28,.29),'head','skull_blue')
box('Spectral_Skull_Jaw',(0,-.027,2.435),(.25,.235,.074),'head','jaw_blue')
box('Skull_Neck_Link',(0,.025,2.49),(.074,.080,.13),'head','energy_dim')
prism('Blue_Soul_Flame',[(-.046,2.69),(.049,2.69),(.049,2.84),(.023,2.84),(.023,2.98),(-.013,2.98),
 (-.013,2.85),(-.046,2.85)],.045,(0,.13,0),'head','energy_dim')
box('Azure_Mana_Core',centers['core'],(.38,.38,.38),'core','core',Euler((math.radians(14),math.radians(20),math.radians(16))).to_matrix())

# The two dominant crescent shields are solid masses with stepped tips and blue inner facets.
outer=[(.72,1.59),(.96,1.59),(.96,1.77),(1.18,1.77),(1.18,1.94),(1.31,1.94),
 (1.31,2.22),(1.19,2.22),(1.19,2.48),(1.06,2.48),(1.06,2.71),(.94,2.71),
 (.94,3.13),(.84,3.13),(.84,2.83),(.73,2.83),(.73,2.59),(.66,2.59),(.66,2.32),(.59,2.32),
 (.59,2.09),(.68,2.09),(.68,1.84),(.72,1.84)]
inner=[(.675,1.87),(.747,1.93),(.747,2.14),(.69,2.14),(.69,2.36),(.755,2.36),(.755,2.60),
 (.82,2.60),(.82,2.83),(.88,2.83),(.88,3.00),(.84,3.00),(.84,2.80),(.77,2.80),
 (.77,2.56),(.70,2.56),(.70,2.31),(.635,2.31),(.635,2.11),(.675,2.11)]
for side,s in [('L',-1),('R',1)]:
    bone='carapace_'+side; dz=.075 if s<0 else 0.
    profile=[(s*x,z+dz) for x,z in outer]
    shell(side+'_Massive_Black_Crescent',profile,.51 if s<0 else .46,(0,.08,0),bone)
    # The blue facet lies just forward of the inner carapace face, not on a floating overlay.
    blue_inlay(side+'_Blue_Crescent_Inner_Facet',[(s*x,z+dz) for x,z in inner],.51 if s<0 else .46,(0,.08,0),bone)
    # One broad angled plate creates the carapace's broken shoulder ridge.
    ridge=[(.78,2.04),(1.02,2.04),(1.02,2.20),(1.22,2.20),(1.22,2.43),(1.12,2.43),(.97,2.62),(.78,2.40)]
    prism(side+'_Outer_Shield_Fracture',[(s*x,z+dz) for x,z in ridge],.11,(0,-.215,0),bone,'obsidian_mid')
    # A separate long blade below each shield floats across a visible fracture gap.
    lower=[(.69,.45),(.79,.45),(.79,.65),(.90,.65),(.90,.88),(1.01,.88),(1.01,1.15),(.90,1.15),
      (.90,1.41),(.75,1.50),(.65,1.28),(.65,1.00),(.59,1.00),(.59,.82),(.69,.82)]
    dz_lower=.025 if s>0 else 0.
    shell(side+'_Suspended_Lower_Blade',[(s*x,z+dz_lower) for x,z in lower],.28,(0,.025,0),'blade_'+side)
    bevel=[(.705,.56),(.743,.56),(.743,.76),(.79,.76),(.79,1.03),(.74,1.03),(.70,.88),(.70,.71)]
    blue_inlay(side+'_Lower_Blue_Facet',[(s*x,z+dz_lower) for x,z in bevel],.28,(0,.025,0),'blade_'+side)

# Broken pelvic brackets and a few large dorsal fragments frame the empty spectral abdomen.
for side,s in [('L',-1),('R',1)]:
    hip=[(.11,1.12),(.28,1.12),(.28,1.28),(.41,1.28),(.41,1.48),(.33,1.48),(.33,1.68),
      (.23,1.76),(.18,1.57),(.18,1.34),(.11,1.34)]
    prism(side+'_Fractured_Pelvic_Arc',[(s*x,z) for x,z in hip],.20,(0,.035,0),'hip_'+side,'obsidian_mid')
    beam(side+'_Pelvic_Energy_Link',(s*.075,.045,1.36),(s*.22,.045,1.57),.048,.054,'body','bone_blue')
    bone='dorsal_'+side; centers[bone]=Vector((s*.47,.35,2.34)); parents[bone]='chest'
    back=[(.26,1.80),(.39,1.80),(.39,2.10),(.62,2.10),(.62,2.41),(.55,2.41),(.55,2.71),(.45,2.71),(.45,2.46),(.31,2.34)]
    prism(side+'_Dorsal_Obsidian_Blade',[(s*x,z) for x,z in back],.18,(0,.34,0),bone,'obsidian')

# Three angular mana wisps fade the lower silhouette; there are no feet or ordinary legs.
for label,x,depth,bottom in [('center',0,.075,.31),('L',-.13,.058,.49),('R',.13,.059,.58)]:
    profile=[(-.037,1.19),(.039,1.19),(.039,.81),(.023,.81),(.023,bottom+.12),(.011,bottom+.12),(.011,bottom),
      (-.014,bottom),(-.014,.66),(-.030,.66),(-.030,.92),(-.037,.92)]
    prism('Suspended_Mana_Wisp_'+label,profile,depth,(x,.095,0),'tail_'+label,'energy_dim')

# Four substantial free chips echo the reference without adding a cloud of tiny debris.
for i,(x,y,z,w,h,angle) in enumerate([(-1.39,.09,2.52,.16,.28,-14),(-1.16,.13,2.93,.12,.21,15),
  (1.465,.12,2.24,.16,.25,12),(1.17,.075,1.46,.13,.22,-16)]):
    bone='free_fragment_'+str(i); centers[bone]=Vector((x,y,z)); parents[bone]='root'
    profile=[(-w/2,-h/2),(w/2,-h/2),(w/2,h*.19),(w*.15,h*.19),(w*.15,h/2),(-w/2,h/2)]
    prism('Free_Obsidian_Fragment_'+str(i),profile,.13,(x,y,z),bone,'obsidian_mid',Euler((0,math.radians(angle),0)).to_matrix())

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
# The current game's cube-skull motifs are repainted as cold spectral bone, alongside black stone.
import random
skeleton_source=(ROOT/'tools/art_pipeline/skeleton_warrior_paint_save.py').read_text(encoding='utf-8')
exec(skeleton_source[skeleton_source.index('# Aged ivory bone ramp'):skeleton_source.index('pixels=[0.0]')],globals())
GLOW=(109,215,251); GLOW_HI=(205,245,255)
palette={'obsidian':(17,23,32),'obsidian_mid':(29,38,51),'blue_facet':(46,81,126),
 'bone_blue':(137,177,202),'energy_dim':(64,154,215),'core':(73,160,248),
 'skull_blue':(140,180,201),'jaw_blue':(140,180,201)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(148800+index); yy,xx=np.indices((h,w))
    clusters=rng.integers(-4,5,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255); emission=np.zeros((h,w,3),dtype=np.float32)
    if kind.startswith('obsidian'):
        # Large plane divisions and sparse square cuts keep the dark silhouettes readable.
        if h>8:
            rgb[yy<2]=np.maximum(0,base-7); rgb[yy>=h-2]=base+8
        for _ in range(max(1,w*h//170)):
            x=int(rng.integers(0,w)); y=int(rng.integers(0,h))
            rgb[y:y+2,x:x+3]=np.clip(base+int(rng.choice([-9,7,13])),0,255)
    elif kind=='blue_facet':
        rgb[xx<2]=base*.76; rgb[xx>=w-2]=base*1.17
        emission=rgb/255*.13
    elif kind in ('skull_blue','jaw_blue'):
        item=dict(it); item['obj']={'region':'skull' if kind=='skull_blue' else 'jaw','part':o.name}
        painted=np.asarray(paint(item,index),dtype=np.float32)[::-1]
        brightness=np.clip((painted[:,:,0]*.3+painted[:,:,1]*.59+painted[:,:,2]*.11-34)/202,0,1)
        rgb=np.array((18,31,45))+brightness[:,:,None]*np.array((143,166,174))
        for glow in (GLOW,GLOW_HI):
            mask=np.all(painted==np.array(glow),axis=2)
            rgb[mask]=glow; emission[mask]=np.array(glow)/255*.65
    elif kind=='bone_blue':
        rgb[yy<1]=base*.82; rgb[yy>=h-1]=base*1.08
        emission=rgb/255*.11
    elif kind=='energy_dim':
        rgb[(xx+yy//5)%5==0]=[86,184,238]
        emission=rgb/255*.26
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[36,93,187]
        rgb[(xx>w*.3)&(xx<w*.73)&(yy>h*.27)&(yy<h*.72)]=[143,210,252]
        for _ in range(3):
            x=int(rng.integers(2,max(3,w-3))); y=int(rng.integers(2,max(3,h-3)))
            rgb[y:y+2,x:x+2]=[205,240,255]
    light=1.08 if n.z>.8 else .75 if n.z<-.8 else 1 if n.y<0 else .85
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    if kind=='core': emission=tile[:,:,:3]*.92
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
mat=bpy.data.materials.new(NAME+'_Obsidian_Spectral_Bone_Azure_Core'); mat.use_nodes=True
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
rig['status']='Static reference-inspired Veil Archon: massive fractured black carapaces, exposed spectral ribs, a small cubic skull, suspended blades, mana wisps and a separate azure cube core.'

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
scene['description']='Three-meter Veil Archon following the supplied reference: black fractured crescent shields and blades around a spectral rib cage, current-game cubic skull, exposed azure mana cube, blue inner facets and suspended lower wisps. Shared by civilizations.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
