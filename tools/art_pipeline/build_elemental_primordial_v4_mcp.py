"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='elemental_primordial_blocky_v4'; NAME='Elemental_Primordial_Blocky_V4'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/elemental_primordial_blocky_v4_review'
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


# User reference: a hunched black-rock creature, vast forelimbs, a small many-eyed head,
# and a crown of enormous cyan mineral columns physically rooted into its back.
C=Vector((0,-.38,1.54))
centers={'body':Vector((0,.28,1.95)),'core':C.copy(),'neck':Vector((0,-.10,2.61)),
 'head':Vector((0,-.91,2.45)),'jaw':Vector((0,-1.01,2.02))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def shape(label,cuboids,bone,kind='stone',R=None,pivot=None):
    o=solid(label,cuboids,bone,kind)
    if R is not None:
        p=Vector(pivot if pivot is not None else cuboids[0][0])
        for v in o.data.vertices:v.co=p+R@(v.co-p)
        o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    return o

# An actual thick body around the recessed heart. No square frame across the chest.
shape('Deep_Rock_Torso',[
 ((0,.44,2.03),(1.62,.56,1.20)),
 ((-.84,.16,2.09),(.56,1.15,1.14)),((.84,.16,2.09),(.56,1.15,1.14)),
 ((0,.54,1.43),(1.36,.60,.42)),((0,.93,1.73),(1.21,.74,.94))],'body','dark')
shape('Hunched_Upper_Back',[
 ((0,.28,2.60),(1.72,1.21,.41)),((0,.50,2.80),(1.25,.87,.25)),
 ((0,.70,2.79),(.85,.63,.22))],'body','stone')
for side,label in [(-1,'L'),(1,'R')]:
    shape('Great_Overlapping_Shoulder_'+label,[
     ((side*1.11,.04,2.45),(.89,1.15,.94)),
     ((side*1.21,.16,2.79),(.62,.93,.41)),
     ((side*1.34,.27,2.93),(.34,.64,.28))],'body','stone',
     Euler((math.radians(-12),math.radians(side*17),math.radians(side*-8))).to_matrix(),(side*1.11,.04,2.45))
    beam('Sweeping_Cowl_'+label,(side*1.21,-.38,2.76),(side*.83,-.57,1.97),.31,.46,'body','ridge')
    shape('Broken_Pectoral_Rock_'+label,[
     ((side*.85,-.40,1.89),(.31,.48,.66)),
     ((side*.78,-.41,1.55),(.24,.38,.29))],'body','stone',
     Euler((0,math.radians(side*10),0)).to_matrix(),(side*.85,-.40,1.89))
    shape('Forward_Thorax_Slab_'+label,[
     ((side*.65,-.65,1.61),(.27,.53,.75)),
     ((side*.63,-.60,1.18),(.24,.55,.33))],'body','stone')
    # Two front mineral outcrops pierce the dark shoulder mass.
    box('Shoulder_Crystal_'+label,(side*.95,-.23,2.78),(.28,.35,.61),'body','crystal',
        Euler((math.radians(-12),math.radians(side*29),0)).to_matrix())

shape('Lower_Thorax_Rock',[
 ((0,-.42,.90),(1.37,.65,.30)),
 ((-.44,-.53,.96),(.44,.40,.16)),((.44,-.53,.94),(.44,.40,.18))],'body','dark')

# A tiny, sheltered arthropod-like face under the massive mineral cowl.
beam('Connected_Neck',(0,-.07,2.66),(0,-.99,2.55),.65,.39,'neck','dark')
shape('Inset_Creature_Head',[
 ((0,-1.12,2.34),(.66,.49,.65)),((0,-1.11,2.60),(.48,.44,.18)),
 ((0,-1.16,2.09),(.53,.40,.23))],'head','face')
box('Recessed_Dark_Face',(0,-1.373,2.34),(.47,.023,.53),'head','face')
for side,label in [(-1,'L'),(1,'R')]:
    for i,(z,x) in enumerate([(2.50,.17),(2.34,.20),(2.18,.17)]):
        box('Luminous_Eye_'+label+str(i),(side*x,-1.397,z),(.079,.019,.102),'head','eye',
            Euler((0,math.radians(side*22),0)).to_matrix())
    shape('Angular_Face_Guard_'+label,[
     ((side*.37,-1.02,2.36),(.17,.47,.47)),
     ((side*.36,-1.02,2.10),(.16,.39,.25))],'head','ridge',
     Euler((0,math.radians(side*13),0)).to_matrix(),(side*.37,-1.02,2.36))
box('Small_Beast_Jaw',(0,-1.13,1.955),(.46,.45,.16),'jaw','dark')
box('Jaw_Cyan_Fault',(0,-1.365,1.945),(.26,.018,.054),'jaw','seam')

# Massive knuckle-bearing forelimbs and smaller splayed rear legs preserve the selected quadruped.
for side,label in [(-1,'L'),(1,'R')]:
    for front in (True,False):
        tag=('front_' if front else 'rear_')+label
        hip=Vector((side*(1.16 if front else .72),-.02 if front else .84,2.40 if front else 1.64))
        knee=Vector((side*(1.40 if front else .98),-.34 if front else 1.13,1.49 if front else .90))
        wrist=Vector((side*(1.51 if front else 1.13),-.81 if front else .98,.53 if front else .28))
        upper=tag+'_upper';lower=tag+'_lower';paw=tag+'_paw'
        centers.update({upper:hip,lower:knee,paw:wrist});parents.update({upper:'body',lower:upper,paw:lower})
        beam('Connected_Leg_'+tag,hip,knee,.48 if front else .35,.58 if front else .39,upper,'dark')
        if front:
            box('Heavy_Upper_Limb_'+tag,(hip+knee)/2,(.64,.77,1.00),upper,'stone',
                (knee-hip).to_track_quat('Z','Y').to_matrix())
            shape('Forearm_Monolith_'+tag,[
             ((0,0,.25),(.83,.86,.66)),((0,-.04,-.27),(.69,.77,.49)),
             ((side*.28,.05,.42),(.36,.67,.37))],lower,'stone',
             (knee-wrist).to_track_quat('Z','Y').to_matrix(),(0,0,0))
            # This local cuboid sculpture is placed along the lower limb as a single rigid block.
            o=parts[-1];d=(knee+wrist)/2
            for v in o.data.vertices:v.co+=d
            o.data.update()
            beam('Outer_Forearm_Ridge_'+tag,knee+Vector((side*.30,.06,.08)),wrist+Vector((side*.28,.04,.07)),.21,.21,lower,'dark')
        else:
            beam('Rear_Shin_'+tag,knee,wrist,.32,.37,lower,'dark')
            box('Rear_Haunch_'+tag,(hip+knee)/2,(.53,.62,.81),upper,'stone',
                (knee-hip).to_track_quat('Z','Y').to_matrix())
        if front:
            shape('Broad_Knuckle_Paw_'+tag,[
             ((wrist.x,wrist.y-.08,.275),(.84,1.02,.55)),
             ((wrist.x,wrist.y-.06,.55),(.66,.75,.34))],paw,'dark')
            for k in (-1,0,1):
                box('Rock_Knuckle_'+tag+str(k),(wrist.x+k*.26,wrist.y-.62,.22),(.22,.25,.28),paw,'stone')
        else:
            shape('Rear_Paw_'+tag,[
             ((wrist.x,wrist.y-.06,.16),(.57,.67,.32)),
             ((wrist.x,wrist.y-.03,.31),(.39,.46,.24))],paw,'dark')

# Huge square-section crystal columns, embedded into the upper back. Stepped ends stay voxel.
for label,x,y,z,w,d,h,rx,ry in [
 ('Central',0,.54,3.16,.85,.70,1.45,-13,0),
 ('Left',-.67,.38,3.05,.47,.56,1.23,-11,-22),
 ('Right',.68,.49,3.00,.50,.57,1.19,-15,24),
 ('Outer_Left',-1.16,.49,2.95,.33,.44,.83,-9,-34),
 ('Outer_Right',1.18,.60,2.85,.34,.43,.77,-14,36)]:
    bone='crystal_'+label.lower();base=Vector((x,y,z-h/2));centers[bone]=base;parents[bone]='body'
    shape('Back_Crystal_'+label,[
     ((x,y,z),(w,d,h)),((x,y,z+h/2-.03),(w*.80,d*.83,.22))],bone,'crystal',
     Euler((math.radians(rx),math.radians(ry),0)).to_matrix(),base)
    box('Rooted_Crystal_Collar_'+label,base+Vector((0,0,.14)),(w+ .16,d+.14,.35),'body','dark')

box('Recessed_Cubic_Elemental_Heart',C,(.54,.54,.54),'core','core',
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
# Charcoal and warm dark stone frame cyan mineral columns, following the user's reference.
palette={'stone':(54,53,50),'dark':(31,33,33),'ridge':(76,74,67),'face':(33,40,40),
 'crystal':(40,110,121),'seam':(74,190,200),'eye':(122,236,232),'core':(101,208,216)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(461826+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-5,6,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge','face'):
        rgb[yy>=h-1]=base+12;rgb[yy<1]=base-8
        for _ in range(max(1,w*h//230)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+5]=base+int(rng.choice([-13,11]))
        if w>18 and h>20:
            x=int(w*.38)
            for y in range(3,h-3):
                q=max(2,min(w-3,x+((y//7)%3)-1));rgb[y,q:q+1]=base-18
        if kind=='face' and 'Recessed_Dark_Face' in o.name:
            # Pixel-cut teeth along the lower face, without separate rounded mouth geometry.
            rgb[(yy<h*.16)&(xx>w*.14)&(xx<w*.86)]=[14,22,22]
            for x in range(max(1,w//6),w-max(1,w//6),max(2,w//6)):
                rgb[max(0,int(h*.08)):max(1,int(h*.13)),x:x+1]=[111,125,117]
    elif kind=='crystal':
        # Depth comes from large interrupted mineral bands, not repetitive noisy pixels.
        rgb[xx<2]=[105,191,195];rgb[xx>=w-2]=[117,218,221]
        rgb[yy>=h-2]=[73,163,172]
        if w>7 and h>12:
            vein=(xx>w*.46)&(xx<w*.60)&(yy<h*.57)
            rgb[vein]=[73,163,174]
            for j in range(4):
                x=int(w*(.19+j*.16));y=int(h*(.11+j*.06));height=int(h*(.20+j*.08))
                rgb[y:min(h,y+height),x:min(w,x+max(1,w//8))]=[54+j*8,133+j*11,143+j*11]
            rgb[(yy<h*.18)&(xx>w*.24)&(xx<w*.77)]=[114,212,213]
        emission=rgb/255*.07
    elif kind in ('seam','eye'):
        rgb[:]=base;rgb[yy>=h-1]=np.minimum(255,base+23);emission=rgb/255*(.28 if kind=='seam' else .70)
    elif kind=='core':
        rgb[:]=[116,222,225];rgb[(xx<2)|(yy<2)]=[61,159,177]
        rgb[(xx>=w-2)|(yy>=h-2)]=[194,247,242]
        rgb[(xx>w*.22)&(xx<w*.68)&(yy>h*.35)&(yy<h*.71)]=[185,242,238]
        emission=rgb/255*.70
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
mat=bpy.data.materials.new(NAME+'_Charcoal_Creature_Cyan_Crystals'); mat.use_nodes=True
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
rig['status']='User-reference-inspired hunched quadrupedal black-rock colossus, massive knuckle-bearing forelimbs, smaller splayed rear legs, a sheltered six-eyed creature head, layered charcoal plates, five huge cyan stepped crystal columns rooted into its back, two smaller shoulder outcrops and a recessed cubic elemental heart. Three meters tall; sharp voxel geometry and pixel-painted mineral textures.'

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
data.type='ORTHO'; data.ortho_scale=4.8; camera.location=(4,-11,4.0); aim(camera,(0,.20,1.50)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='User-reference-inspired hunched quadrupedal black-rock colossus, massive knuckle-bearing forelimbs, smaller splayed rear legs, a sheltered six-eyed creature head, layered charcoal plates, five huge cyan stepped crystal columns rooted into its back, two smaller shoulder outcrops and a recessed cubic elemental heart. Three meters tall; sharp voxel geometry and pixel-painted mineral textures.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
