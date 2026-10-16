"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='elemental_primordial_blocky_v1'; NAME='Elemental_Primordial_Blocky_V1'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/elemental_primordial_blocky_v1_review'
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
protected.extend(p for ext in ('glb','blend') if (p:=ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v5'/('veil_archon_blocky_v5.'+ext)).is_file())
protected.extend(p for ext in ('glb','blend') if (p:=ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v6'/('veil_archon_blocky_v6.'+ext)).is_file())
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v7'/('veil_archon_blocky_v7.'+ext) for ext in ('glb','blend'))
for stem in ['veil_archon_blocky_v8','veil_archon_blocky_v9_animated']:
    protected.extend(ROOT/'assets/generated/grand_manifestations'/stem/(stem+'.'+ext) for ext in ('glb','blend'))
for relative in ['assets/generated/humans/human_elementalist_v1/human_elementalist_v1.glb',
 'assets/generated/humans/buildings/elemental_observatory_hex_v1/elemental_observatory_hex_v1.glb',
 'assets/generated/humans/buildings/elemental_ritual_hex_v1/elemental_ritual_hex_v1.glb']:
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

def solid(label,cuboids,bone,kind='shell',side=1):
    # Boolean union on a cuboid grid. Dissolving coplanar internal edges preserves a closed mesh.
    bounds=[]
    for center,size in cuboids:
        c=Vector((side*center[0],center[1],center[2]));h=Vector(size)/2
        bounds.append((c-h,c+h))
    axes=[sorted(set(round(v[i],6) for a,b in bounds for v in (a,b))) for i in range(3)]
    occ=set()
    for i in range(len(axes[0])-1):
        for j in range(len(axes[1])-1):
            for k in range(len(axes[2])-1):
                p=Vector(tuple((axes[t][q]+axes[t][q+1])/2 for t,q in enumerate((i,j,k))))
                if any(all(a[t]<p[t]<b[t] for t in range(3)) for a,b in bounds):occ.add((i,j,k))
    vertices=[];faces=[];indices={}
    patterns=[((-1,0,0),[(0,0,0),(0,0,1),(0,1,1),(0,1,0)]),
      ((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),
      ((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),
      ((0,1,0),[(0,1,0),(0,1,1),(1,1,1),(1,1,0)]),
      ((0,0,-1),[(0,0,0),(0,1,0),(1,1,0),(1,0,0)]),
      ((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)])]
    for cell in sorted(occ):
        for direction,pattern in patterns:
            if tuple(a+b for a,b in zip(cell,direction)) in occ:continue
            face=[]
            for d in pattern:
                key=tuple(a+b for a,b in zip(cell,d))
                if key not in indices:
                    indices[key]=len(vertices);vertices.append(tuple(axes[t][key[t]] for t in range(3)))
                face.append(indices[key])
            faces.append(face)
    o=mesh_part(label,vertices,faces,bone,kind)
    bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update()
    bmesh.ops.dissolve_limit(bm,angle_limit=.0001,verts=list(bm.verts),edges=list(bm.edges),use_dissolve_boundaries=False,delimit=set())
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    assert all(max(abs(c) for c in p.normal)>.9999 for p in o.data.polygons),label
    return o


# A four-element living tempest, sculpted as thick cuboid cloud masses and an open vortex.
C=Vector((0,-.18,2.11));centers={'body':C.copy(),'core':C.copy()};parents={'body':'root','core':'root'}
def cluster(label,cuboids,bone,kind,pivot=None):
    if bone not in centers:
        centers[bone]=Vector(pivot if pivot is not None else cuboids[0][0]);parents[bone]='body'
    return solid(label,cuboids,bone,kind)

# A deep grey cloud crown sweeps behind the exposed nucleus, with an opening at the front.
cluster('Broad_Storm_Cloud_Crown',[
 ((-.80,.24,2.75),(.50,.62,.38)),((-.43,.25,2.96),(.49,.58,.36)),
 ((0,.30,3.02),(.51,.57,.36)),((.43,.28,2.91),(.50,.58,.40)),
 ((.82,.25,2.75),(.45,.53,.37)),((.10,.44,2.72),(.53,.38,.35))],
 'crown','cloud',(0,.28,2.78))
cluster('Upper_Pale_Wind_Ridge',[
 ((-.52,.02,3.08),(.35,.28,.18)),((-.23,.05,3.20),(.31,.28,.17)),
 ((.07,.06,3.22),(.32,.27,.17)),((.36,.06,3.09),(.33,.29,.18))],
 'crown_ridge','mist',(0,.06,3.08))
cluster('Rear_Descending_Storm_Wall',[
 ((.60,.63,2.49),(.42,.31,.36)),((.35,.66,2.20),(.44,.32,.37)),
 ((.02,.66,1.95),(.40,.32,.34)),((-.27,.59,1.73),(.39,.34,.31))],
 'rear_cloud','cloud',(.19,.63,2.12))

# Charred mineral blocks and two voxel flames form the fire side of the tempest.
cluster('Charred_Fire_Carapace',[
 ((-.88,.03,2.59),(.48,.43,.36)),((-.97,.05,2.32),(.43,.42,.31)),
 ((-.85,.025,2.08),(.38,.41,.27)),((-.70,.04,1.88),(.32,.36,.25))],
 'fire_shell','ember',(-.85,.03,2.34))
flame=[(-.14,0),(.14,0),(.14,.17),(.08,.17),(.08,.37),(.02,.37),(.02,.51),
 (-.04,.51),(-.04,.30),(-.11,.30),(-.11,.12),(-.14,.12)]
for i,(x,y,z,angle) in enumerate([(-1.08,.08,2.61,-13),(-.73,.18,2.74,12)]):
    bone='flame_'+str(i);centers[bone]=Vector((x,y,z));parents[bone]='fire_shell'
    prism('Voxel_Fire_Plume_'+str(i),flame,.21,(x,y,z),bone,'flame',Euler((0,math.radians(angle),0)).to_matrix())

# The water mass has solid angular ice, with stepped crystal tips and pixel-painted depth.
cluster('Water_Ice_Carapace',[
 ((.88,-.005,2.57),(.43,.40,.41)),((1.00,.02,2.24),(.41,.43,.36)),
 ((.86,.015,1.94),(.40,.38,.33)),((.66,.055,1.72),(.35,.34,.27))],
 'water_shell','ice',(.89,.02,2.25))
crystal=[(-.14,-.18),(.14,-.18),(.14,.20),(.08,.20),(.08,.39),(.015,.39),
 (.015,.52),(-.045,.52),(-.045,.31),(-.10,.31),(-.10,.03),(-.14,.03)]
for i,(x,y,z,angle) in enumerate([(1.10,.12,2.49,18),(.87,.24,2.73,-9)]):
    bone='ice_spire_'+str(i);centers[bone]=Vector((x,y,z));parents[bone]='water_shell'
    prism('Stepped_Ice_Spire_'+str(i),crystal,.25,(x,y,z),bone,'ice_light',Euler((0,math.radians(angle),0)).to_matrix())

# Earth closes the lower flank: a single sculpted floating boulder, with mineral strata.
cluster('Earth_Basalt_Anchor',[
 ((-.73,.005,1.62),(.55,.48,.39)),((-.58,.04,1.34),(.46,.42,.27)),
 ((-.89,.06,1.52),(.32,.40,.27)),((-.64,.16,1.73),(.34,.36,.28))],
 'earth_anchor','stone',(-.71,.07,1.53))
cluster('Earth_Mineral_Crest',[
 ((-.77,-.259,1.65),(.33,.06,.11)),((-.59,-.204,1.37),(.22,.06,.09))],
 'earth_crest','mineral',(-.68,-.23,1.56))

# Three open, thick square wind curls rotate as they narrow, forming the floating funnel.
for label,z,r,w,angle in [('upper',1.39,.58,.19,-18),('middle',1.02,.42,.16,24),('lower',.67,.27,.13,65)]:
    bone='wind_'+label;centers[bone]=Vector((0,.06,z));parents[bone]='body'
    profile=[(-r,-r),(r,-r),(r,-r+w),(-r+w,-r+w),(-r+w,r-w),
      (r-w,r-w),(r-w,.10),(r,.10),(r,r),(-r,r)]
    R=Euler((math.radians(90),0,math.radians(angle))).to_matrix()
    prism('Open_Wind_Vortex_'+label,profile,w,(0,.06,z),bone,'wind',R)
cluster('Terminal_Mist_Point',[
 ((.10,.085,.43),(.20,.18,.20)),((.055,.055,.285),(.12,.13,.15))],
 'mist_tip','mist',(.055,.055,.33))

# Two substantial cloud curls add weather mass without a halo or an exterior cable.
cluster('Left_Wind_Shoulder',[
 ((-1.07,.24,1.98),(.35,.36,.27)),((-1.20,.26,2.17),(.21,.29,.21)),
 ((-1.21,.29,2.33),(.17,.25,.18))],'left_gust','cloud',(-1.12,.25,2.14))
cluster('Right_Mist_Sweep',[
 ((.85,.12,1.48),(.35,.34,.24)),((1.05,.15,1.65),(.27,.31,.21)),
 ((1.16,.18,1.81),(.18,.24,.20))],'right_gust','mist',(.98,.15,1.64))

# The single white-cyan cube is physically suspended in the clear eye of the tempest.
box('Cyan_Elemental_Heart',C,(.55,.55,.55),'core','core',
    Euler((math.radians(15),math.radians(18),math.radians(14))).to_matrix())

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
# Quiet voxel cloud strata, deep ice and molten fissures; the nucleus carries all four focal colors.
palette={'cloud':(51,76,86),'mist':(141,163,164),'ember':(47,44,41),
 'flame':(216,119,32),'ice':(53,126,148),'ice_light':(111,182,197),
 'stone':(81,81,68),'mineral':(125,143,111),'wind':(103,142,150),'core':(115,204,211)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(144920+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    clusters=rng.integers(-5,6,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255)
    if kind in ('cloud','mist','wind'):
        # Pixel bands follow the air flow, without painting every underlying voxel-cell boundary.
        if h>9:
            stripe=(yy//max(3,h//4))%3
            rgb[stripe==1]=np.clip(rgb[stripe==1]+7,0,255)
            rgb[yy>=h-1]=base+17;rgb[yy<1]=base-13
        if kind=='wind':
            rgb[(xx+yy//4)%13==0]=base+18;emission=rgb/255*.025
    elif kind=='ember':
        rgb[yy>=h-1]=base+15
        if n.y<-.65 and w>8 and h>8:
            x=max(2,w//2)
            for y in range(2,h-2):
                q=x+((y//5)%3)-1
                rgb[y,q:q+1]=[238,139,36];emission[y,q:q+1]=[.40,.16,.018]
                if y%7==0 and q+2<w:rgb[y,q:q+3]=[220,105,22];emission[y,q:q+3]=[.33,.10,.009]
    elif kind=='flame':
        rgb[xx>w*.38]=[238,154,45];rgb[(xx>w*.48)&(xx<w*.65)]=[255,210,96]
        rgb[yy>=h-2]=[249,173,57];emission=rgb/255*.48
    elif kind in ('ice','ice_light'):
        rgb[xx<2]=base*.73;rgb[xx>=w-2]=np.minimum(255,base+39)
        if h>8 and w>8:
            for y in range(2,h-2):
                q=min(w-2,max(1,w//3+y//6));rgb[y,q:q+1]=np.minimum(255,base+42)
        emission=rgb/255*.055
    elif kind in ('stone','mineral'):
        rgb[yy>=h-2]=base+16
        for _ in range(max(1,w*h//145)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+4]=base+int(rng.choice([-18,15]))
    else:
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[49,137,164]
        rgb[(xx>w*.24)&(xx<w*.76)&(yy>h*.24)&(yy<h*.76)]=[211,240,238]
        for x,y,color in [(w*.20,h*.20,(229,139,48)),(w*.78,h*.20,(115,154,107)),
          (w*.20,h*.78,(78,170,218)),(w*.78,h*.78,(228,236,225))]:
            x=int(x);y=int(y);rgb[max(0,y-1):min(h,y+2),max(0,x-1):min(w,x+2)]=color
        emission=rgb/255*.70
    light=1.08 if n.z>.8 else .74 if n.z<-.8 else 1 if n.y<0 else .87
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)

images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(data.reshape(-1)); im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png'))
    im.file_format='PNG'; im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.new(NAME+'_Four_Elements_Storm_Cyan_Heart'); mat.use_nodes=True
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
rig['status']='Three-meter suspended living tempest: broad cuboid cloud crown, charred fire flank with voxel amber flames, stepped blue ice, a mineral earth anchor, three narrowing open wind curls and one central cyan cubic elemental heart. Weather-control manifestation shared by all civilizations.'

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
scene['description']='Three-meter suspended living tempest: broad cuboid cloud crown, charred fire flank with voxel amber flames, stepped blue ice, a mineral earth anchor, three narrowing open wind curls and one central cyan cubic elemental heart. Weather-control manifestation shared by all civilizations.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
