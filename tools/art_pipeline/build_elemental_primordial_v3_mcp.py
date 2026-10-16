"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='elemental_primordial_blocky_v3'; NAME='Elemental_Primordial_Blocky_V3'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/elemental_primordial_blocky_v3_review'
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


# A colossal mineral predator on four legs. All contours use rigid cuboids and stepped solids.
C=Vector((0,-.79,1.72))
centers={'body':Vector((0,.25,1.82)),'core':C.copy(),'neck':Vector((0,-.48,2.43)),
 'head':Vector((0,-1.04,2.54)),'jaw':Vector((0,-1.12,2.22))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def shape(label,cuboids,bone,kind='stone',R=None,pivot=None):
    o=solid(label,cuboids,bone,kind)
    if R is not None:
        p=Vector(pivot if pivot is not None else cuboids[0][0])
        for v in o.data.vertices:v.co=p+R@(v.co-p)
        o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    return o

shape('Solid_Chest_And_Back',[
 ((0,.04,2.03),(1.53,.74,1.10)),((0,.57,1.91),(1.40,1.28,1.06)),
 ((0,1.18,1.70),(1.12,.92,.93)),((0,.56,1.39),(1.07,1.29,.39))],'body')
shape('Raised_Withers',[
 ((0,-.05,2.54),(1.25,1.13,.45)),((0,.21,2.73),(.91,.81,.23)),
 ((0,.51,2.69),(.66,.42,.19))],'body','ridge')
# Broad overlapping scapula slabs slope into the forelegs; no humanoid shoulder pads.
for side,label in [(-1,'L'),(1,'R')]:
    rot=Euler((math.radians(-9),math.radians(side*13),0)).to_matrix()
    shape('Great_Scapula_'+label,[
     ((side*.77,-.24,2.25),(.60,1.08,.86)),
     ((side*.86,-.29,2.55),(.48,.85,.36)),
     ((side*.92,-.15,2.72),(.33,.57,.27))],'body','stone',rot,(side*.77,-.24,2.25))
    shape('Open_Chest_Plate_'+label,[
     ((side*.77,-.65,1.93),(.36,.45,.67)),
     ((side*.72,-.63,1.51),(.28,.34,.27))],'body','ridge')
    box('Scapula_Fault_'+label,(side*1.016,-.41,2.45),(.048,.44,.16),'body','seam',
        Euler((0,0,math.radians(side*8))).to_matrix())

# A thick downward-reaching neck joins a broad, snarling, forward-facing mineral head.
beam('Muscular_Mineral_Neck',(0,-.37,2.49),(0,-1.02,2.62),.86,.68,'neck','dark')
shape('Predator_Cranium',[
 ((0,-1.25,2.69),(.98,.75,.56)),((0,-1.59,2.57),(.83,.55,.44)),
 ((0,-1.82,2.51),(.76,.57,.34))],'head','stone')
box('Dark_Maw_Interior',(0,-1.68,2.31),(.64,.69,.13),'head','mouth')
shape('Powerful_Lower_Jaw',[
 ((0,-1.59,2.20),(.81,1.01,.18)),((0,-1.27,2.27),(.92,.43,.23))],'jaw','ridge')
box('Muzzle_End',(0,-2.115,2.49),(.35,.04,.10),'head','dark')
for side,label in [(-1,'L'),(1,'R')]:
    # Two distinct recessed eyes and slanted brows make a predator, rather than a visor helmet.
    box('Eye_Socket_'+label,(side*.30,-1.884,2.73),(.24,.038,.15),'head','dark')
    box('Eye_'+label,(side*.30,-1.913,2.73),(.16,.018,.072),'head','eye',
        Euler((0,math.radians(side*-10),0)).to_matrix())
    box('Heavy_Brow_'+label,(side*.31,-1.885,2.835),(.34,.22,.13),'head','ridge',
        Euler((0,math.radians(side*15),0)).to_matrix())
    shape('Cheek_Plate_'+label,[
     ((side*.47,-1.20,2.50),(.22,.50,.39)),
     ((side*.52,-1.00,2.37),(.21,.27,.25))],'head','dark',
       Euler((math.radians(-12),math.radians(side*17),0)).to_matrix(),(side*.47,-1.20,2.50))
    shape('Backswept_Crown_Horn_'+label,[
     ((side*.39,-1.12,2.94),(.24,.38,.27)),
     ((side*.43,-.88,3.045),(.21,.35,.21)),
     ((side*.47,-.68,3.105),(.13,.27,.13))],'head','dark')
    # Block-cut saber fangs lie beside the mouth and clear the cubic throat/chest heart.
    shape('Great_Crystal_Fang_'+label,[
     ((side*.31,-2.17,2.30),(.14,.18,.30)),
     ((side*.31,-2.21,2.105),(.11,.14,.15)),
     ((side*.31,-2.24,2.025),(.065,.10,.075))],'head','crystal')
    for k in range(2):
        box('Lower_Tooth_'+label+str(k),(side*(.13+k*.19),-1.98,2.335),(.075,.12,.13),'jaw','crystal')

# Front legs are long and heavy; the rear legs have a clear animal hock, rather than human knees.
for side,label in [(-1,'L'),(1,'R')]:
    for front in (True,False):
        tag=('front_' if front else 'rear_')+label
        hip=Vector((side*(.87 if front else .60),-.33 if front else 1.13,2.13 if front else 1.69))
        knee=Vector((side*(1.02 if front else .77),-.56 if front else 1.44,1.17 if front else 1.01))
        wrist=Vector((side*(1.08 if front else .74),-.93 if front else 1.05,.36))
        upper=tag+'_upper';lower=tag+'_lower';paw=tag+'_paw'
        centers.update({upper:hip,lower:knee,paw:wrist});parents.update({upper:'body',lower:upper,paw:lower})
        beam('Connected_Leg_'+tag,hip,knee,.47 if front else .43,.60 if front else .53,upper,'dark')
        box('Animal_Joint_'+tag,knee,(.46,.47,.37),lower,'stone')
        beam('Heavy_Lower_Leg_'+tag,knee,wrist,.43 if front else .35,.51 if front else .43,lower,'stone')
        rot=(wrist-knee).to_track_quat('Z','Y').to_matrix()
        box('Leg_Outer_Plate_'+tag,(hip+knee)/2+Vector((side*.18,.01,.05)),(.33,.73,.55),upper,'ridge',
            (knee-hip).to_track_quat('Z','Y').to_matrix())
        shape('Beast_Paw_'+tag,[
         ((wrist.x,wrist.y-.12,.18),(.65 if front else .55,.86 if front else .72,.36)),
         ((wrist.x,wrist.y-.05,.36),(.47,.56,.24))],paw,'dark')
        for k in (-1,0,1):
            box('Square_Claw_'+tag+str(k),(wrist.x+k*(.195 if front else .165),wrist.y-(.58 if front else .49),.13),
                (.13,.24,.15),paw,'crystal')

# Attached mineral plates follow the curved spine; all face edges remain square and sharp.
for i,(y,z,w,h) in enumerate([(.18,2.88,.32,.37),(.67,2.71,.29,.35),(1.09,2.41,.25,.31),(1.45,2.13,.20,.26)]):
    box('Dorsal_Crest_'+str(i),(0,y,z),(w,.36,h),'body','ridge',Euler((math.radians(20),0,0)).to_matrix())
    if i<3:box('Cold_Crest_Inlay_'+str(i),(0,y-.13,z+.06),(w*.78,.045,h*.48),'body','seam',Euler((math.radians(20),0,0)).to_matrix())

tailpoints=[Vector((0,1.44,1.63)),Vector((0,2.02,1.20)),Vector((.20,2.51,.95)),Vector((.45,2.83,1.16))]
last='body'
for i,(a,b) in enumerate(zip(tailpoints,tailpoints[1:])):
    name='tail_'+str(i);centers[name]=a;parents[name]=last;last=name
    beam('Articulated_Mineral_Tail_'+str(i),a,b,.35-i*.07,.37-i*.07,name,'dark')
box('Tail_Crystal_Tip',tailpoints[-1],(.27,.30,.31),last,'crystal',Euler((math.radians(-22),0,0)).to_matrix())
box('Cubic_Elemental_Heart',C,(.48,.48,.48),'core','core',
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
# Closely related mineral tones, pixel-cut faults and pale cyan energy. No four-color robot limbs.
palette={'stone':(49,67,77),'dark':(29,40,49),'ridge':(73,94,103),'crystal':(154,195,199),
 'seam':(66,158,176),'eye':(167,243,241),'mouth':(12,20,27),'core':(92,200,216)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(350831+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-5,6,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge'):
        rgb[yy>=h-1]=base+14;rgb[yy<1]=base-8
        for _ in range(max(1,w*h//220)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+4]=base+int(rng.choice([-12,12]))
        # Sparse, irregular faults; no concentric panel borders or uniform horizontal brick bands.
        if w>16 and h>16 and index%3==0:
            x=int(w*.42)
            for y in range(3,h-4):
                q=max(2,min(w-3,x+((y//6)%3)-1))
                rgb[y,q:q+1]=base-20
                if y>h*.3 and y<h*.7:
                    rgb[y,q+1:q+2]=[72,140,152];emission[y,q+1:q+2]=[.02,.065,.075]
    elif kind=='crystal':
        rgb[xx<2]=base-28;rgb[xx>=w-2]=np.minimum(255,base+23);emission=rgb/255*.018
    elif kind in ('seam','eye'):
        rgb[:]=base;rgb[yy>=h-1]=np.minimum(255,base+35);emission=rgb/255*(.30 if kind=='seam' else .65)
    elif kind=='core':
        rgb[:]=[111,218,224]
        # A single bright solid energy cube, with sparse pixel highlights on its face.
        rgb[(xx<2)|(yy<2)]=[65,156,176]
        rgb[(xx>=w-2)|(yy>=h-2)]=[194,246,241]
        rgb[(xx>w*.18)&(xx<w*.65)&(yy>h*.37)&(yy<h*.68)]=[174,239,235]
        rgb[(xx>w*.25)&(xx<w*.39)&(yy>h*.68)&(yy<h*.81)]=[206,251,245]
        emission=rgb/255*.66
    light=1.04 if n.z>.8 else .78 if n.z<-.8 else 1 if n.y<0 else .88
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
mat=bpy.data.materials.new(NAME+'_Primal_Mineral_Predator_Cyan_Heart'); mat.use_nodes=True
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
rig['status']='Colossal quadrupedal mineral predator with high massive withers, a low rear body, muscular connected legs, large clawed paws, a saber-fanged head, swept horns, a jointed tail and a single cyan cubic heart exposed between the chest plates. Three meters tall, sharp blocky cuboid anatomy and pixel mineral textures.'

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
data.type='ORTHO'; data.ortho_scale=6.0; camera.location=(7,-10,5.0); aim(camera,(0,.20,1.50)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Colossal quadrupedal mineral predator with high massive withers, a low rear body, muscular connected legs, large clawed paws, a saber-fanged head, swept horns, a jointed tail and a single cyan cubic heart exposed between the chest plates. Three meters tall, sharp blocky cuboid anatomy and pixel mineral textures.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
