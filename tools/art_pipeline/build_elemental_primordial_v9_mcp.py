"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='elemental_primordial_blocky_v9'; NAME='Elemental_Primordial_Blocky_V9'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/elemental_primordial_blocky_v9_review'
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
for relative in ['assets/generated/grand_manifestations/elemental_primordial_blocky_v1/elemental_primordial_blocky_v1.glb',
 'assets/generated/grand_manifestations/elemental_primordial_blocky_v1/elemental_primordial_blocky_v1.blend',
 'assets/generated/ancient_golems/ancient_golem_v2/ancient_golem_v2.glb',
 'assets/generated/trolls/troll_blocky_v3/troll_blocky_v3.glb']:
    protected.append(ROOT/relative)
for relative in ['assets/generated/grand_manifestations/elemental_primordial_blocky_v2/elemental_primordial_blocky_v2.glb',
 'assets/generated/grand_manifestations/elemental_primordial_blocky_v2/elemental_primordial_blocky_v2.blend',
 'assets/generated/wargs/warg_v1/warg_v1.glb','assets/generated/basilisks/basilisk_blocky_v1/basilisk_blocky_v1.glb']:
    protected.append(ROOT/relative)
for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v3'/('elemental_primordial_blocky_v3.'+ext))
for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v4'/('elemental_primordial_blocky_v4.'+ext))
for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v5'/('elemental_primordial_blocky_v5.'+ext))
for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v6'/('elemental_primordial_blocky_v6.'+ext))
for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v7'/('elemental_primordial_blocky_v7.'+ext))
for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v8'/('elemental_primordial_blocky_v8.'+ext))
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
    o['source_part_label']=label; o['rig_bone']=bone; o['kind']=kind; o['local_rotation']=list(R.to_euler('XYZ'))
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


# Preserve the pixel painting on every approved upper-body face exactly.
legacy_path=OUT/'v6_texture_indices.json'
legacy=bpy.app.driver_namespace.get('elemental_primordial_blocky_v6')
if legacy:
    old_texture_indices={it['obj'].name.removeprefix('Elemental_Primordial_Blocky_V6_')+'|'+str(it['polygon']):i for i,it in enumerate(legacy['islands'])}
    legacy_path.write_text(json.dumps(old_texture_indices),encoding='utf-8')
else:
    old_texture_indices=json.loads(legacy_path.read_text(encoding='utf-8'))

# Direct reconstruction of the supplied creature's composition in large Hytale-like blocks.
# The enormous arms hang in front, above six articulated cuboid walking legs. One dominant cyan
# crystal mass rises above the carapace; the tiny head sits low inside the stone collar.
C=Vector((0,-.08,1.51))
centers={'body':Vector((0,.40,1.78)),'core':C.copy(),'neck':Vector((0,.04,2.37)),
 'head':Vector((0,-.73,2.18)),'jaw':Vector((0,-.82,1.79))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def hexa(label,center,lower,upper,height,bone,kind='stone',angles=(0,0,0)):
    # Eight corners and six large planar quad faces. Sharp boxes and modest rectangular tapers.
    c=Vector(center);R=Euler(tuple(math.radians(a) for a in angles)).to_matrix()
    vs=[c+R@Vector((x*s[0]/2,y*s[1]/2,z*height/2)) for z,s in [(-1,lower),(1,upper)]
        for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    return mesh_part(label,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,kind,R)

def slab(label,center,size,bone,kind='stone',angles=(0,0,0)):
    return box(label,center,size,bone,kind,Euler(tuple(math.radians(a) for a in angles)).to_matrix())

# A deep physical body, leaving a cavity around the buried cubic heart.
slab('Deep_Back',(0,.76,1.92),(1.30,.45,1.43),'body','dark',(-5,0,0))
for side,label in [(-1,'L'),(1,'R')]:
    slab('Thorax_Side_'+label,(side*.80,.20,1.98),(.48,1.30,1.23),'body','stone')
slab('Pelvis_Behind_Heart',(0,.74,1.09),(.76,.39,.33),'body','dark')

# The reference's broad, tall asymmetric shell. The head is below these masses, not atop them.
for side,label in [(-1,'L'),(1,'R')]:
    slab('Outer_Carapace_'+label,(side*1.09,.13,2.25),(.60,.89,1.03),'body','stone',(-8,side*26,side*-6))
    slab('Back_Carapace_'+label,(side*.86,.54,2.44),(.62,.89,.64),'body','dark',(-15,side*15,0))
    slab('High_Oblique_Rock_'+label,(side*.91,-.16,2.57),(.39,.58,.87),'body','ridge',(-10,side*24,side*-5))
    # One or two large squared cuts at the ends, instead of rounded voxel boulder contours.
    profile=[(-.21,-.54),(.10,-.54),(.10,-.40),(.28,-.40),(.28,.40),(.15,.40),
             (.15,.61),(-.19,.61),(-.19,.39),(-.28,.39),(-.28,-.30),(-.21,-.30)]
    prism('Face_Enclosing_Rock_'+label,profile,.32,(side*.67,-.58,2.00),'body','dark',
        Euler((math.radians(-8),math.radians(side*25),0)).to_matrix())

# The large diagonal stone blade crossing the lower face/throat on the right is key to the image.
beam('Right_Crossing_Breastplate',(.94,-.69,1.97),(.20,-.76,1.38),.32,.29,'body','ridge')
beam('Left_Descending_Breastplate',(-.66,-.70,1.83),(-.24,-.74,1.20),.25,.26,'body','stone')
slab('Low_Point_Of_Carapace',(0,-.66,1.02),(.37,.34,.31),'body','dark',(0,0,0))

# Small insect-like face: eyes are pixel-painted into its planar front, never separate buttons.
beam('Sheltered_Neck',(0,.14,2.47),(0,-.73,2.25),.46,.31,'neck','dark')
hexa('Small_Six_Eyed_Head',(0,-.81,1.99),(.29,.29),(.49,.33),.49,'head','face',(7,0,0))
slab('Small_Lower_Jaw',(0,-.86,1.737),(.28,.30,.12),'jaw','face',(7,0,0))
for side,label in [(-1,'L'),(1,'R')]:
    slab('Head_Cheek_'+label,(side*.25,-.77,1.985),(.13,.31,.36),'head','dark',(5,side*16,0))

# Every new limb piece is an actual eight-vertex cuboid: no silhouette extrusion,
# curved outline, tapered loft, pyramid, bevel or rounded surface.
def block(label,center,size,bone,kind='stone',R=None):
    o=box(label,center,size,bone,kind,R);o['construction']='cuboid';return o

def block_link(label,a,b,width,depth,bone,kind='stone'):
    o=beam(label,a,b,width,depth,bone,kind);o['construction']='cuboid';return o

# Long lateral roots support three independently articulated walking legs on each side.
for side,label in [(-1,'L'),(1,'R')]:
    block('Crab_Leg_Socket_Rail_'+label,(side*.76,.49,1.22),(.32,1.66,.36),'body','dark')

for side,label in [(-1,'L'),(1,'R')]:
    shoulder=Vector((side*.94,-.14,2.23));elbow=Vector((side*.91,-.51,1.38))
    upper='arm_'+label;fore='forearm_'+label;claw='pincer_'+label
    centers.update({upper:shoulder,fore:elbow});parents.update({upper:'body',fore:upper})
    # Retain the approved upper-arm attachment; all lower anatomy is rebuilt from blocks.
    beam('Upper_Arm_'+label,shoulder,elbow,.44,.52,upper,'dark')
    slab('Upper_Arm_Rock_'+label,(shoulder+elbow)/2,(.54,.59,.88),upper,'stone',(-21,side*-2,0))

    palm=Vector((side*.95,-.78,1.05))
    block('Massive_Cuboid_Chela_'+label,palm,(.78,.74,.70),fore,'stone')
    # The fixed jaw descends from the outside of the palm, with an angular inward bite.
    fixed_root=Vector((side*1.21,-.80,.78));fixed_bend=Vector((side*1.16,-.86,.43))
    fixed_tip=Vector((side*1.08,-.89,.27))
    block_link('Fixed_Pincer_Main_Block_'+label,fixed_root,fixed_bend,.29,.55,fore,'stone')
    block_link('Fixed_Pincer_Bite_Block_'+label,fixed_bend,fixed_tip,.20,.43,fore,'dark')
    # A separate bulky moving jaw opposes it. The open space is between these two real volumes.
    moving_root=Vector((side*.66,-.78,.76));moving_bend=Vector((side*.71,-.85,.42))
    moving_tip=Vector((side*.80,-.89,.27))
    centers[claw]=moving_root;parents[claw]=fore
    block_link('Moving_Pincer_Main_Block_'+label,moving_root,moving_bend,.26,.51,claw,'stone')
    block_link('Moving_Pincer_Bite_Block_'+label,moving_bend,moving_tip,.18,.40,claw,'dark')

    # Six walking legs form a front/middle/rear support footprint, not a pair of human thighs.
    for row,root_y,hinge_y,knee_y,tip_y,hinge_x,knee_x,tip_x in [
      ('front',-.12,-.30,-.58,-.86,1.13,1.40,1.63),
      ('middle',.49,.60,.67,.74,1.24,1.63,1.99),
      ('rear',1.04,1.31,1.56,1.80,1.14,1.43,1.72)]:
        tag=row+'_'+label
        hip=Vector((side*.79,root_y,1.39));hinge=Vector((side*hinge_x,hinge_y,1.48))
        knee=Vector((side*knee_x,knee_y,.73));contact=Vector((side*tip_x,tip_y,.08))
        terminal_root=contact+Vector((0,0,.07));mid=(knee+terminal_root)/2
        coxa='coxa_'+tag;merus='merus_'+tag;tibia='tibia_'+tag
        centers.update({coxa:hip,merus:hinge,tibia:knee})
        parents.update({coxa:'body',merus:coxa,tibia:merus})
        block_link('Crab_Coxa_Block_'+tag,hip,hinge,.34,.38,coxa,'dark')
        block('Crab_High_Joint_Block_'+tag,hinge,(.42,.43,.39),merus,'stone')
        block_link('Crab_Merus_Block_'+tag,hinge,knee,.36,.40,merus,'stone')
        block_link('Crab_Tibia_Upper_Block_'+tag,knee,mid,.29,.32,tibia,'dark')
        block_link('Crab_Tibia_Lower_Block_'+tag,mid,terminal_root,.19,.22,tibia,'dark')
        # Narrow squared end. No broad sole, toes or custom needle-shaped mesh.
        o=block('Crab_Contact_Tip_Block_'+tag,contact,(.12,.15,.16),tibia,'dark')
        o['walking_leg']=tag;o['ground_contact_source']=list(contact-Vector((0,0,.08)))


# Recreate the asymmetrical cluster, dominated by one broad central crystal rather than a crown.
crystals=[
 ('central',.03,.43,2.87,(1.02,.76),(.83,.65),1.12,-7,-3),
 ('left_inner',-.68,.33,2.70,(.37,.44),(.30,.36),.84,-9,-14),
 ('left_outer',-1.02,.10,2.49,(.29,.38),(.24,.30),.62,-8,-24),
 ('right_high',.88,.40,2.93,(.33,.38),(.28,.32),.61,-8,22),
 ('right_outer',1.15,.48,2.75,(.52,.53),(.40,.44),.63,-12,-27)]
for label,x,y,z,lower,upper,h,rx,ry in crystals:
    bone='crystal_'+label;centers[bone]=Vector((x,y,z-h/2));parents[bone]='body'
    hexa('Reference_Crystal_'+label,(x,y,z),lower,upper,h,bone,'crystal',(rx,ry,0))
for side,label in [(-1,'L'),(1,'R')]:
    hexa('Embedded_Cyan_Stone_'+label,(side*.76,-.29,2.20),(.23,.30),(.31,.32),.33,'body','crystal',(-13,side*29,0))

box('Internal_Cubic_Mana_Heart',C,(.58,.58,.58),'core','core',
    Euler((math.radians(10),math.radians(15),math.radians(25))).to_matrix())

coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
GROUND=0.0
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
# Restrained pixel-painted Hytale materials on large flat blocks. No gridded brick bands.
palette={'stone':(64,61,58),'dark':(30,31,30),'ridge':(79,73,65),'face':(38,43,39),
 'crystal':(39,92,102),'core':(101,211,217)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    paint_index=old_texture_indices.get(o['source_part_label']+'|'+str(it['polygon']),index)
    rng=np.random.default_rng(663513+paint_index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-3,4,(math.ceil(h/5),math.ceil(w/5))).repeat(5,0).repeat(5,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge','face'):
        # Broad, hand-placed pixel mineral patches, not dense speckle or continuous panel edging.
        for _ in range(max(1,w*h//430)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h))
            rgb[y:y+max(1,h//11),x:x+max(1,w//9)]=base+int(rng.choice([-7,7]))
        if w>17 and h>21 and paint_index%3==0:
            for y in range(4,h-3):
                q=max(1,min(w-2,int(w*.68)+((y//7)%3)-1));rgb[y,q:q+1]=base-12
        if kind=='face' and 'Small_Six_Eyed_Head' in o.name and n.y<-.90:
            for row,(height,width) in enumerate([(.72,.29),(.50,.30),(.30,.22)]):
                for side in (-1,1):
                    x=int(w*(.5+side*width));y=int(h*height)
                    # Six small, slanted pixel eyes integrated into the face, like the image.
                    for dy in range(2):
                        q=x+side*dy
                        rgb[max(0,y+dy):min(h,y+dy+1),max(0,q-1):min(w,q+2)]=[106,204,211]
                        emission[max(0,y+dy):min(h,y+dy+1),max(0,q-1):min(w,q+2)]=[.17,.48,.52]
            mask=(yy<h*.17)&(yy>h*.06)&(xx>w*.27)&(xx<w*.73);rgb[mask]=[16,21,19]
            for x in range(int(w*.29),int(w*.71),3):rgb[int(h*.14):int(h*.19),x:x+1]=[104,112,96]
    elif kind=='crystal':
        # Random small mineral pixels only. No bands, columns, diagrams, glyphs or painted lines.
        cyan=np.array([(31,83,94),(39,96,107),(45,107,117),(52,117,127)],dtype=float)
        field=rng.choice(4,(math.ceil(h/3),math.ceil(w/3)),p=[.16,.46,.28,.10])
        field=field.repeat(3,0).repeat(3,1)[:h,:w]
        rgb=cyan[field];emission=rgb/255*.025
    elif kind=='core':
        rgb[:]=[110,213,219];rgb[(xx>w*.22)&(xx<w*.69)&(yy>h*.32)&(yy<h*.70)]=[166,237,237]
        emission=rgb/255*.57
    light=1.04 if n.z>.8 else .80 if n.z<-.8 else 1 if n.y<0 else .90
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
mat=bpy.data.materials.new(NAME+'_Standing_Crab_Cuboid_Limbs'); mat.use_nodes=True
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
rig['status']='Upright blocky crab mini boss: six imposing independently articulated cuboid walking legs, three on each side, form a balanced support footprint. Two massive cuboid palms have opposing angular block jaws and separate moving-jaw pivots. All new appendages are built only from eight-vertex cuboids. Approved carapace, face, upper-arm roots, cyan pixel crystals and internal cubic heart retained. Three meters tall.'

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
data.type='ORTHO'; data.ortho_scale=5.2; camera.location=(5,-11,4.4); aim(camera,(0,.20,1.50)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Upright blocky crab mini boss: six imposing independently articulated cuboid walking legs, three on each side, form a balanced support footprint. Two massive cuboid palms have opposing angular block jaws and separate moving-jaw pivots. All new appendages are built only from eight-vertex cuboids. Approved carapace, face, upper-arm roots, cyan pixel crystals and internal cubic heart retained. Three meters tall.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
