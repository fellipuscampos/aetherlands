"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='elemental_primordial_blocky_v5'; NAME='Elemental_Primordial_Blocky_V5'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/elemental_primordial_blocky_v5_review'
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


# Reference-led rebuild: a mineral creature sculpted from irregular voxel boulders,
# not stacked armor boxes. Its little tapered face is buried under the enormous back.
C=Vector((0,.02,1.65))
centers={'body':Vector((0,.55,1.95)),'core':C.copy(),'neck':Vector((0,-.15,2.50)),
 'head':Vector((0,-.74,2.35)),'jaw':Vector((0,-.90,2.04))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def shape(label,cuboids,bone,kind='stone',R=None,pivot=None):
    o=solid(label,cuboids,bone,kind)
    if R is not None:
        p=Vector(pivot if pivot is not None else cuboids[0][0])
        for v in o.data.vertices:v.co=p+R@(v.co-p)
        o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    return o

def rock(label,center,size,bone,kind='stone',angles=(0,0,0),grid=(5,5,7),seed=0):
    # A coarse superellipsoid cut by offset planes: broad broken faces and stepped corners.
    # Every occupied cell is a real cuboid, dissolved into one closed flat-shaded solid.
    c=Vector(center);s=Vector(size);nx,ny,nz=grid;boxes=[]
    for i in range(nx):
        for j in range(ny):
            for k in range(nz):
                x=(i+.5)/nx*2-1;y=(j+.5)/ny*2-1;z=(k+.5)/nz*2-1
                if abs(x)**3.2+abs(y)**3.2+abs(z)**3.2>1.04:continue
                if x*.40+y*.31+z*.54> .92+(seed%3)*.035:continue
                p=c+Vector((x*s.x/2,y*s.y/2,z*s.z/2))
                boxes.append((p,(s.x/nx,s.y/ny,s.z/nz)))
    return shape(label,boxes,bone,kind,Euler(tuple(math.radians(a) for a in angles)).to_matrix(),c)

# A deep torso leaves space for the heart. Irregular side masses close its silhouette.
rock('Heavy_Back_Mass',(0,1.04,2.18),(1.70,.76,1.46),'body','dark',grid=(7,5,7))
for side,label in [(-1,'L'),(1,'R')]:
    rock('Thorax_Mass_'+label,(side*.96,.36,2.03),(.64,1.64,1.44),'body','stone',grid=(5,7,7),seed=1)
rock('Compact_Hindquarters',(0,.96,1.37),(1.32,.54,.55),'body','dark',grid=(7,5,3))
rock('Great_Hunched_Withers',(0,.45,2.67),(1.66,1.47,.61),'body','stone',angles=(-7,0,0),grid=(7,7,3))

for side,label in [(-1,'L'),(1,'R')]:
    rock('Broken_Shoulder_Mass_'+label,(side*1.19,.14,2.51),(1.02,1.22,1.16),'body','stone',
         angles=(-10,side*19,side*-9),grid=(5,5,7),seed=2 if side<0 else 1)
    # Thick overlapping oblique rock blades enclose the face like the reference's carapace.
    profile=[(-.28,-.53),(-.10,-.53),(-.10,-.39),(.10,-.39),(.10,-.22),(.25,-.22),
      (.25,.39),(.12,.39),(.12,.56),(-.13,.56),(-.13,.42),(-.28,.42)]
    prism('High_Cowl_Blade_'+label,profile,.38,(side*.84,-.42,2.31),'body','ridge',
          Euler((math.radians(-14),math.radians(side*30),0)).to_matrix())
    # A low V of broken rock hides most of the cubic heart; it is no longer out on the surface.
    beam('Sloped_Breast_Rock_'+label,(side*.77,-.61,1.92),(side*.31,-.65,1.00),.25,.30,'body','stone')
    rock('Upper_Arm_Root_'+label,(side*1.24,-.01,2.20),(.68,.87,.75),'body','dark',angles=(0,side*8,0),grid=(5,5,5))

# Tapered, recessed six-eyed head. Its silhouette has no rectangular face plate or visor.
beam('Buried_Neck',(0,.05,2.65),(0,-.73,2.49),.57,.36,'neck','dark')
face=[(-.27,.43),(.27,.43),(.27,.30),(.31,.30),(.31,-.04),(.23,-.04),
 (.23,-.22),(.13,-.22),(.13,-.33),(-.13,-.33),(-.13,-.22),(-.23,-.22),
 (-.23,-.04),(-.31,-.04),(-.31,.30),(-.27,.30)]
prism('Tapered_Creature_Head',face,.40,(0,-.96,2.18),'head','face')
for side,label in [(-1,'L'),(1,'R')]:
    for i,(z,x) in enumerate([(2.46,.17),(2.29,.20),(2.09,.14)]):
        box('Small_Luminous_Eye_'+label+str(i),(side*x,-1.181,z),(.057,.035,.077),'head','eye',
            Euler((0,math.radians(side*27),0)).to_matrix())
    rock('Rock_Cheek_'+label,(side*.35,-.86,2.22),(.27,.51,.66),'head','stone',
         angles=(0,side*19,0),grid=(3,5,5))
    shape('Split_Mandible_'+label,[
     ((side*.105,-1.005,1.93),(.17,.34,.19)),
     ((side*.15,-1.00,2.015),(.19,.36,.11))],'jaw','dark')

# Colossal irregular forearms, without cuffs, knee caps or decorated fist panels.
for side,label in [(-1,'L'),(1,'R')]:
    for front in (True,False):
        tag=('front_' if front else 'rear_')+label
        hip=Vector((side*(1.27 if front else .73),.02 if front else .94,2.35 if front else 1.58))
        knee=Vector((side*(1.46 if front else .99),-.30 if front else 1.17,1.47 if front else .88))
        wrist=Vector((side*(1.60 if front else 1.15),-.75 if front else 1.03,.48 if front else .26))
        upper=tag+'_upper';lower=tag+'_lower';paw=tag+'_paw'
        centers.update({upper:hip,lower:knee,paw:wrist});parents.update({upper:'body',lower:upper,paw:lower})
        beam('Living_Limb_Joint_'+tag,hip,knee,.42 if front else .31,.51 if front else .34,upper,'dark')
        if front:
            rock('Upper_Rock_Limb_'+tag,(hip+knee)/2,(.69,.81,1.02),upper,'stone',
                 angles=(-13,side*8,0),grid=(5,5,7),seed=side+2)
            rock('Colossal_Forearm_'+tag,(knee+wrist)/2,(.91,1.02,1.22),lower,'stone',
                 angles=(-22,side*8,side*-3),grid=(5,5,7),seed=1)
            rock('Inner_Forearm_Shadow_'+tag,(knee+wrist)/2+Vector((side*-.22,-.02,-.13)),(.43,.91,.78),lower,'dark',
                 angles=(-19,side*12,0),grid=(3,5,5))
            rock('Great_Clawed_Paw_'+tag,(wrist.x,wrist.y-.10,.32),(.87,1.02,.64),paw,'dark',grid=(5,5,3))
            for k in (-1,1):
                # Two blunt hooked mineral talons, part of the actual paw rather than boxed knuckles.
                shape('Hooked_Rock_Claw_'+tag+str(k),[
                 ((wrist.x+k*.24,wrist.y-.60,.22),(.25,.26,.32)),
                 ((wrist.x+k*.24,wrist.y-.66,.095),(.24,.32,.15))],paw,'dark')
        else:
            rock('Rear_Haunch_'+tag,(hip+knee)/2,(.55,.61,.89),upper,'stone',angles=(-17,side*-14,0),grid=(5,5,5))
            beam('Rear_Shin_'+tag,knee,wrist,.32,.37,lower,'dark')
            rock('Rear_Paw_'+tag,(wrist.x,wrist.y-.04,.16),(.62,.73,.32),paw,'dark',grid=(5,5,3))

# Broken crystalline slabs, no mounting rings, neon frames or identical capped tubes.
for label,x,y,z,w,d,h,rx,ry in [
 ('Central',-.10,.87,3.12,.91,.72,1.57,-10,3),
 ('Left',-.77,.57,3.05,.57,.58,1.18,-8,-18),
 ('Right',.82,.72,2.99,.54,.63,1.07,-13,21),
 ('Outer_Left',-1.24,.48,2.91,.37,.48,.67,-13,-32),
 ('Outer_Right',1.28,.65,2.86,.38,.49,.63,-14,33)]:
    bone='crystal_'+label.lower();base=Vector((x,y,z-h/2));centers[bone]=base;parents[bone]='body'
    shape('Fractured_Back_Crystal_'+label,[
     ((x,y,z),(w,d,h)),
     ((x-w*.12,y,z+h/2+.035),(w*.64,d*.83,.21)),
     ((x+w*.27,y,z+h/2-.018),(w*.27,d*.75,.12))],bone,'crystal',
     Euler((math.radians(rx),math.radians(ry),0)).to_matrix(),base)
for side,label in [(-1,'L'),(1,'R')]:
    shape('Shoulder_Crystal_Shards_'+label,[
     ((side*.98,-.20,2.60),(.23,.31,.52)),
     ((side*1.11,-.15,2.66),(.14,.26,.33))],'body','crystal',
     Euler((math.radians(-14),math.radians(side*30),0)).to_matrix(),(side*.98,-.20,2.40))
box('Buried_Cubic_Elemental_Heart',C,(.62,.62,.62),'core','core',
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
# Broken charcoal mineral faces and opaque cyan crystalline slabs, without framed panel painting.
palette={'stone':(55,52,48),'dark':(30,30,29),'ridge':(69,64,57),'face':(39,43,40),
 'crystal':(34,99,111),'eye':(112,219,223),'core':(127,224,226)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(552431+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-5,6,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge','face'):
        for _ in range(max(1,w*h//240)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+4]=base+int(rng.choice([-11,10]))
        if w>13 and h>13:
            for y in range(2,h-2):
                q=max(1,min(w-2,int(w*.38)+((y//6)%4)-1));rgb[y,q:q+1]=base-14
        if kind=='face' and n.y<-.8 and w>15 and h>20:
            mouth=(yy>h*.12)&(yy<h*.23)&(xx>w*.27)&(xx<w*.73)
            rgb[mouth]=[16,20,19]
            for x in range(int(w*.29),int(w*.71),max(2,w//8)):
                rgb[int(h*.20):int(h*.24),x:x+1]=[117,126,113]
    elif kind=='crystal':
        # Uneven large veins and a luminous broken root, rather than rectangular neon rims.
        if w>6 and h>10:
            for j in range(5):
                x=int(w*(.08+j*.18));y=int(h*(.035+j*.055));vh=int(h*(.24+(j%3)*.14))
                rgb[y:min(h,y+vh),x:min(w,x+max(1,w//7))]=[52+j*7,136+j*9,147+j*8]
            trace=(xx==max(1,int(w*.78)))&(yy<h*.68)
            rgb[trace]=[120,205,209]
            rgb[(yy<h*.10)&(xx>w*.24)&(xx<w*.65)]=[131,223,223]
        emission=rgb/255*.04
    elif kind=='eye':
        rgb[:]=base;emission=rgb/255*.60
    elif kind=='core':
        rgb[:]=[153,231,232];rgb[(xx<1)|(yy<1)]=[95,193,204]
        rgb[(xx>=w-1)|(yy>=h-1)]=[194,247,242]
        rgb[(xx>w*.27)&(xx<w*.66)&(yy>h*.37)&(yy<h*.68)]=[205,250,241]
        emission=rgb/255*.67
    light=1.05 if n.z>.8 else .79 if n.z<-.8 else 1 if n.y<0 else .89
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
mat=bpy.data.materials.new(NAME+'_Broken_Rock_Creature_Cyan_Slabs'); mat.use_nodes=True
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
rig['status']='User reference translated into a physical voxel mineral creature: irregular hunched charcoal boulders, immense forearms with blunt hooked claws, small splayed rear legs, a tapered six-eyed face buried below its carapace, oblique overlapping breast rocks, huge broken cyan crystal slabs rooted in its back, and a cubic mana heart deep inside the torso. Three meters tall.'

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
scene['description']='User reference translated into a physical voxel mineral creature: irregular hunched charcoal boulders, immense forearms with blunt hooked claws, small splayed rear legs, a tapered six-eyed face buried below its carapace, oblique overlapping breast rocks, huge broken cyan crystal slabs rooted in its back, and a cubic mana heart deep inside the torso. Three meters tall.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
