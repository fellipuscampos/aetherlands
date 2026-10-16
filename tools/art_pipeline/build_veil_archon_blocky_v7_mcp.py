"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='veil_archon_blocky_v7'; NAME='Veil_Archon_Blocky_V7'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/veil_archon_blocky_v7_review'
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

# Sculpted unions of cuboids, with genuine depth and a large open chest cavity.
centers={'body':Vector((0,.10,1.94)),'chest':Vector((0,.10,2.52)),
 'head':Vector((0,.01,3.00)),'core':Vector((0,.0,2.46)),
 'crown_L':Vector((-.13,-.06,3.12)),'crown_R':Vector((.13,-.06,3.12)),
 'tail':Vector((0,.11,1.68)),'tail_L':Vector((-.28,.16,1.65)),
 'tail_R':Vector((.28,.16,1.65))}
parents={'body':'root','chest':'body','head':'chest','core':'chest',
 'crown_L':'head','crown_R':'head','tail':'body','tail_L':'body','tail_R':'body'}
for side,s in [('L',-1),('R',1)]:
    for name,c,parent in [('shoulder',(s*.64,.08,2.88),'chest'),
      ('upper_arm',(s*.87,.10,2.68),'chest'),
      ('forearm',(s*1.10,.06,2.03),'upper_arm_'+side),
      ('hand',(-1.14,-.36,2.43) if side=='L' else (1.33,-.36,1.41),'forearm_'+side)]:
        centers[name+'_'+side]=Vector(c);parents[name+'_'+side]=parent

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

def steps(label,profile,depth,y,bone,kind='shell',side=1):
    for a,b in zip(profile,profile[1:]+profile[:1]):
        assert abs(a[0]-b[0])<1e-7 or abs(a[1]-b[1])<1e-7,(label,a,b)
    return prism(label,[(side*x,z) for x,z in profile],depth,(0,y,0),bone,kind)

# One crooked, deeply sculpted floating root beneath a narrow waist.
solid('Crooked_Suspended_Body',[
 ((0,.13,1.83),(.50,.36,.36)),((.04,.15,1.57),(.42,.31,.28)),
 ((.08,.16,1.33),(.32,.26,.28)),((.08,.14,1.09),(.25,.22,.28)),
 ((.025,.12,.86),(.22,.19,.24)),((-.025,.09,.65),(.18,.16,.22)),
 ((-.045,.05,.46),(.14,.12,.20)),((-.06,.035,.30),(.10,.09,.16))],'tail')
solid('Waist_Heart', [((0,.10,2.00),(.52,.38,.24)),((0,.10,2.14),(.34,.32,.16))],'body','ridge')

for side,s in [('L',-1),('R',1)]:
    # Wide inverted-V shoulders made of rising cuboid layers, not thin diagonal plates.
    solid(side+'_Swept_V_Collar',[
      ((.22,.015,2.77),(.40,.36,.16)),((.49,.035,2.85),(.30,.40,.18)),
      ((.73,.065,2.94),(.28,.43,.19)),((.96,.095,3.04),(.27,.37,.18)),
      ((1.115,.12,3.115),(.15,.25,.15)),
      ((.55,.075,2.69),(.24,.30,.24)),((.76,.105,2.77),(.26,.34,.26))],
      'shoulder_'+side,'ridge',s)
    # Chest shell encloses a real hollow that remains clear of the rotating cube.
    solid(side+'_Open_Chest_Shell',[
      ((.42,.065,2.52),(.20,.43,.56)),((.35,.095,2.25),(.22,.38,.20)),
      ((.25,.115,2.13),(.23,.33,.15)),((.48,.20,2.71),(.25,.30,.19))],
      'chest','shell',s)
    # Thin inner mineral facets on recessed surfaces make the opening legible.
    solid(side+'_Inner_Chest_Lip',[
      ((.315,-.158,2.51),(.055,.026,.30)),((.265,-.108,2.285),(.10,.026,.065))],
      'chest','edge',s)
    # Outer backward thorns are slender cuboids with clipped, square ends.
    solid(side+'_Raised_Dorsal_Spur',[
      ((.69,.29,2.79),(.13,.20,.26)),((.75,.34,3.00),(.105,.15,.18)),
      ((.79,.38,3.145),(.075,.11,.13))],'shoulder_'+side,'shell',s)
    solid(side+'_Upper_Arm_Carapace',[
      ((.91,.12,2.62),(.31,.38,.31)),((.98,.13,2.35),(.28,.34,.30)),
      ((1.065,.12,2.12),(.23,.30,.24)),((1.15,.17,2.49),(.13,.22,.26)),
      ((1.225,.20,2.68),(.075,.14,.14))],'upper_arm_'+side,'shell',s)
    # The dangling outer sleeve has changing depth as well as width.
    solid(side+'_Long_Sculpted_Arm_Mantle',[
      ((1.065,.135,1.90),(.27,.34,.31)),((1.10,.14,1.65),(.31,.37,.27)),
      ((1.08,.17,1.40),(.31,.33,.28)),((1.00,.20,1.15),(.23,.26,.26)),
      ((.965,.22,.94),(.16,.19,.22)),((.965,.235,.78),(.105,.13,.14)),
      ((1.26,.20,1.66),(.11,.20,.24)),((1.32,.23,1.84),(.075,.13,.14))],
      'forearm_'+side,'shell',s)
    # Rear root fins are short accents; the principal body ends in one long point.
    solid(side+'_Rear_Root_Fin',[
      ((.31,.23,1.61),(.18,.22,.28)),((.34,.255,1.38),(.14,.18,.24)),
      ((.33,.28,1.18),(.095,.13,.19))],'tail_'+side,'shell',s)

# Hollow upper body at the back; the center is physically empty in front and on both sides.
solid('Chest_Rear_Arch',[
 ((-.35,.34,2.53),(.14,.16,.55)),((.35,.34,2.53),(.14,.16,.55)),
 ((0,.34,2.82),(.78,.16,.14)),((0,.34,2.23),(.67,.16,.14))],'chest','shell')
box('Crimson_Mana_Core',centers['core'],(.30,.30,.30),'core','core',
    Euler((math.radians(10),math.radians(12),math.radians(11))).to_matrix())

# The tiny central void belongs to the crown, rather than a humanoid head or mask.
solid('Crown_Heart_Void',[
 ((-.09,-.035,3.04),(.08,.13,.22)),((.09,-.035,3.04),(.08,.13,.22)),
 ((0,-.035,2.94),(.18,.13,.07)),((0,-.035,3.155),(.22,.13,.07))],'head','ridge')
horn=[(.02,3.00),(.14,3.00),(.14,3.10),(.30,3.10),(.30,3.20),
 (.50,3.20),(.50,3.26),(.76,3.26),(.76,3.30),(1.06,3.30),
 (1.06,3.34),(.90,3.34),(.90,3.38),(.68,3.38),(.68,3.36),
 (.46,3.36),(.46,3.30),(.24,3.30),(.24,3.22),(.12,3.22),(.12,3.16),(.02,3.16)]
for side,s in [('L',-1),('R',1)]:
    steps(side+'_Open_Arcane_Crown',horn,.105,-.08,'crown_'+side,'crown',s)

# Energy arms are three-dimensional cuboids with a broad palm. They sit forward of the sleeve.
solid('Raised_Left_Spectral_Arm',[
 ((-1.075,-.29,2.105),(.13,.13,.22)),((-1.12,-.33,2.29),(.11,.12,.21))],
 'forearm_L','energy')
box('Left_Square_Spectral_Palm',(-1.14,-.36,2.44),(.19,.17,.19),'hand_L','energy')
solid('Right_Spectral_Arm',[
 ((1.08,-.29,1.985),(.13,.13,.19)),((1.15,-.31,1.83),(.12,.12,.20)),
 ((1.23,-.335,1.67),(.12,.11,.19)),((1.31,-.36,1.505),(.11,.10,.18))],
 'forearm_R','energy')
box('Right_Square_Spectral_Palm',(1.34,-.37,1.385),(.18,.17,.19),'hand_R','energy')

# Rigid angular poses retain square cross sections and make the silhouette less architectural.
upper={side:Matrix.Rotation(math.radians(7 if side=='L' else -7),3,'Y') for side in ('L','R')}
fore={side:Matrix.Rotation(math.radians(5 if side=='L' else -5),3,'Y') for side in ('L','R')}
tail_R=Matrix.Rotation(math.radians(5),3,'Y')
original_centers={n:c.copy() for n,c in centers.items()}
def apply_pose(v,bone):
    R=Matrix.Identity(3)
    for side in ('L','R'):
        if bone in ('upper_arm_'+side,'forearm_'+side,'hand_'+side):
            c=original_centers['upper_arm_'+side];v=c+upper[side]@(v-c);R=upper[side]@R
        if bone in ('forearm_'+side,'hand_'+side):
            c=original_centers['upper_arm_'+side]+upper[side]@(original_centers['forearm_'+side]-original_centers['upper_arm_'+side])
            v=c+fore[side]@(v-c);R=fore[side]@R
    if bone in ('tail','tail_L','tail_R'):
        c=original_centers['tail'];v=c+tail_R@(v-c);R=tail_R@R
    v+=Vector((0,0,.07 if bone in ('head','crown_L','crown_R') else -.08))
    return v,R
for o in parts:
    bone=o['rig_bone']
    for v in o.data.vertices:v.co,R=apply_pose(v.co,bone)
    o['local_rotation']=list((R@Euler(o['local_rotation'],'XYZ').to_matrix()).to_euler('XYZ'))
    o.data.update()
for n,c in original_centers.items():centers[n]=apply_pose(c,n)[0]

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
# Mineral layers, painted creases and sparse arcane red fissures, matching the accepted bosses' pixel scale.
palette={'shell':(24,39,44),'ridge':(49,71,76),'edge':(80,105,109),
 'energy':(134,22,57),'crown':(176,31,73),'core':(192,34,88)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal']
    base=np.array(palette[kind],dtype=float);rng=np.random.default_rng(670020+index)
    yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    clusters=rng.integers(-4,5,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255)
    if kind in ('shell','ridge','edge'):
        # Broad lighter mineral planes, two-pixel cracks, and edge wear give each volume weight.
        rgb[yy>=h-2]=base+8;rgb[xx<1]=base+12
        for _ in range(max(1,w*h//150)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h))
            rgb[y:y+2,x:x+int(rng.integers(2,6))]=base+int(rng.choice([-7,10,14]))
        if kind=='shell' and n.y<-.8 and w>8 and h>10 and ('Chest' in o.name or 'Upper_Arm' in o.name):
            # One short branching fissure per broad inner plate, integrated into the pixel map.
            x=max(2,w//2); y0=max(2,h//4)
            for y in range(y0,min(h-2,y0+max(3,h//3))):
                q=x+(y-y0)//5
                if q>=w-2:break
                rgb[y,q:q+1]=[169,35,75];emission[y,q:q+1]=[.20,.025,.05]
    elif kind in ('energy','crown'):
        # Dark red edges and one pale interior stripe keep the energy from looking like pink plastic.
        rgb[(xx<1)|(yy<1)]=base*.6
        stripe=(xx==max(1,w//2)) if w<h else (yy==max(1,h//2))
        rgb[stripe]=[241,93,141]
        rgb[yy>=h-1]=[222,58,116]
        emission=rgb/255*(.32 if kind=='energy' else .5)
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx>w*.26)&(xx<w*.74)&(yy>h*.26)&(yy<h*.74)]=[248,127,171]
        rgb[(xx<1)|(yy<1)]=[126,18,51];emission=rgb/255*.62
    light=1.07 if n.z>.8 else .73 if n.z<-.8 else 1 if n.y<0 else .85
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
mat=bpy.data.materials.new(NAME+'_Sculpted_Mineral_Open_Chest_Core'); mat.use_nodes=True
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
rig['status']='Floating voxel apparition following the dark spectral reference: open blade crown, broad swept collar, hollow tapered chest enclosing a cubic mana core, long crooked carapace sleeves and asymmetric spectral arms. Broad contiguous mineral faces, rotated cuboid limbs, concentrated crimson-magenta energy.'

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
scene['description']='Floating voxel apparition following the dark spectral reference: open blade crown, broad swept collar, hollow tapered chest enclosing a cubic mana core, long crooked carapace sleeves and asymmetric spectral arms. Broad contiguous mineral faces, rotated cuboid limbs, concentrated crimson-magenta energy.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
