"""Build an editable, three-meter infernal manifestation through the live Blender MCP."""
import bpy, bmesh, math, json, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Euler, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='archdemon_blocky_v1'; NAME='Infernal_Archdemon_Blocky_V1'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/archdemon_blocky_v1_review'
assert NAME not in bpy.data.scenes, 'Preserve an existing source scene.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'scripts/data/UnitDatabase.gd',
    ROOT/'assets/generated/magic/archdemon/archdemon.glb',
    ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4_animated/seraph_blocky_v4_animated.glb',
    ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4_animated/seraph_blocky_v4_animated.blend',
    ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb']
old_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
col=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(col)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=bpy.data.objects.new(NAME+'_ROOT',None); col.objects.link(root); root.empty_display_size=.2
parts=[]
centers={'body':Vector((0,0,1.15)), 'chest':Vector((0,0,1.69)),
    'head':Vector((0,0,2.20)), 'furnace':Vector((0,-.32,1.92)),
    'tail_1':Vector((0,.29,1.13)), 'tail_2':Vector((0,.64,.91)),
    'tail_3':Vector((.32,.90,.60))}
parents={'body':'root','chest':'body','head':'chest','furnace':'chest',
    'tail_1':'body','tail_2':'tail_1','tail_3':'tail_2'}

def mesh_part(label,vertices,faces,bone,kind,R=None):
    R=R if R is not None else Matrix.Identity(3)
    me=bpy.data.meshes.new(NAME+'_'+label); me.from_pydata(vertices,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    o=bpy.data.objects.new(me.name,me); col.objects.link(o)
    o['rig_bone']=bone; o['kind']=kind; o['local_rotation']=list(R.to_euler('XYZ'))
    o['primitive']='closed sharp-edged prism; flat shaded; rigid pivot'
    parts.append(o); return o

def box(label,center,size,bone,kind='obsidian',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); s=Vector(size)*.5
    vertices=[c+R@Vector((x*s.x,y*s.y,z*s.z)) for x,y,z in
        [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh_part(label,vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,kind,R)

def prism(label,profile,depth,center,bone,kind='obsidian',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); n=len(profile)
    vertices=[c+R@Vector((x,y,z)) for y in (-depth/2,depth/2) for x,z in profile]
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    faces.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vertices,faces,bone,kind,R)

def beam(label,a,b,width,depth,bone,kind='obsidian'):
    a,b=Vector(a),Vector(b); R=(b-a).to_track_quat('Z','Y').to_matrix()
    return box(label,(a+b)/2,(width,depth,(b-a).length),bone,kind,R)

def tapered_box(label,center,height,upper,lower,bone,kind):
    c=Vector(center); vertices=[]
    for z,size in [(-height/2,lower),(height/2,upper)]:
        w,d=size
        vertices.extend(c+Vector((x*w/2,y*d/2,z)) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)])
    return mesh_part(label,vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,kind)

# Broad, armored torso with a single contained infernal furnace as the visual focus.
tapered_box('Chest_Carapace',(0,.015,1.93),.62,(1.04,.55),(.70,.43),'chest','obsidian')
box('Waist',(0,.025,1.45),(.62,.39,.40),'body','red_armor')
box('Pelvis',(0,.02,1.22),(.68,.39,.25),'body','obsidian')
box('Belt',(0,-.005,1.30),(.72,.43,.085),'body','brass')
prism('Belt_Seal',[(-.105,-.04),(.105,-.04),(.105,.07),(.06,.07),(.06,.11),(-.06,.11),(-.06,.07),(-.105,.07)],.05,(0,-.245,1.30),'body','charred_horn')
box('Neck',(0,.045,2.25),(.29,.30,.19),'head','obsidian')
box('Head',(0,-.005,2.45),(.48,.42,.46),'head','face')
prism('Jaw',[(-.24,.10),(.24,.10),(.24,-.06),(.14,-.06),(.14,-.16),(-.14,-.16),(-.14,-.06),(-.24,-.06)],.31,(0,-.015,2.25),'head','obsidian')
prism('Chin_Flame',[(-.035,.04),(.035,.04),(.035,-.07),(.018,-.07),(.018,-.12),(-.018,-.12),(-.018,-.07),(-.035,-.07)],.026,(0,-.180,2.20),'head','ember')
box('Furnace_Recess',(0,-.29,1.94),(.23,.07,.38),'chest','void')
prism('Furnace_Flame',[(-.055,-.15),(.055,-.15),(.055,-.035),(.08,-.035),(.08,.04),(.04,.04),(.04,.12),(.005,.12),(.005,.19),(-.03,.19),(-.03,.065),(-.065,.065),(-.065,-.015),(-.055,-.015)],.027,(0,-.336,1.91),'furnace','fire')
box('Furnace_Heart',(0,-.355,1.91),(.039,.015,.20),'furnace','white_fire')

for sign in (-1,1):
    side='L' if sign<0 else 'R'
    # Inset chest armor slopes toward the core; no smooth muscle sculpting.
    plate=[(.10,2.19),(.48,2.20),(.48,2.04),(.37,1.87),(.20,1.80),(.10,1.86)]
    prism(side+'_Pectoral',[(sign*x,z) for x,z in plate],.075,(0,-.286,0),'chest','red_armor')
    beam(side+'_Collar_Edge',(sign*.13,-.333,2.20),(sign*.49,-.333,2.23),.035,.026,'chest','brass')
    for i in range(2):
        box(side+'_Abdominal_Plate_'+str(i),(sign*.165,-.216,1.55-i*.13),(.25,.07,.092),'body','obsidian')
    prism(side+'_Hip_Plate',[(sign*x,z) for x,z in [(.16,.13),(.34,.16),(.43,-.08),(.43,-.21),(.25,-.21),(.16,-.12)]],.39,(0,.04,1.15),'body','red_armor')

# Two high swept horns: long stepped hooks, with a lighter charred tip.
horn=[(.18,2.56),(.37,2.55),(.37,2.61),(.48,2.61),(.48,2.80),(.53,2.80),(.53,2.99),(.45,2.99),(.45,3.10),(.35,3.10),(.35,3.21),(.26,3.21),(.26,3.02),(.34,3.02),(.34,2.89),(.36,2.89),(.36,2.73),(.26,2.73),(.26,2.69),(.18,2.69)]
tip=[(.26,3.02),(.35,3.02),(.35,3.10),(.35,3.21),(.26,3.21)]
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    prism(side+'_Crown_Horn',[(sign*x,z) for x,z in horn],.21,(0,.025,0),'head','charred_horn')
    # The tip occupies its own front layer instead of adding rounded horn geometry.
    prism(side+'_Horn_Tip',[(sign*x,z) for x,z in tip],.026,(0,-.098,0),'head','horn_tip')
    prism(side+'_Cheek_Horn',[(sign*x,z) for x,z in [(.19,2.40),(.35,2.39),(.35,2.43),(.44,2.43),(.44,2.54),(.36,2.54),(.36,2.50),(.24,2.50)]],.15,(0,.06,0),'head','charred_horn')

# Arms use a single articulated shoulder, short forearms and compact three-finger claws.
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side; flame='palm_fire_'+side
    shoulder=Vector((sign*.62,.025,2.10)); elbow=Vector((sign*.88,-.015,1.64)); wrist=Vector((sign*.92,-.20,1.23))
    centers[upper]=shoulder; centers[fore]=elbow; centers[hand]=wrist; centers[flame]=Vector((sign*.93,-.38,1.22))
    parents.update({upper:'chest',fore:upper,hand:fore,flame:hand})
    beam(side+'_Upper_Arm',shoulder,elbow,.31,.34,upper,'red_armor')
    box(side+'_Shoulder_Carapace',(sign*.65,.015,2.12),(.55,.56,.30),upper,'obsidian')
    prism(side+'_Shoulder_Flare',[(sign*x,z) for x,z in [(.58,2.24),(.93,2.24),(.93,2.35),(1.05,2.35),(1.05,2.49),(.94,2.49),(.94,2.41),(.74,2.41),(.74,2.35),(.58,2.35)]],.33,(0,.065,0),upper,'obsidian')
    box(side+'_Shoulder_Front',(sign*.67,-.278,2.13),(.40,.026,.13),upper,'red_armor')
    beam(side+'_Shoulder_Lip',(sign*.44,-.299,2.235),(sign*.89,-.299,2.235),.027,.027,upper,'brass')
    beam(side+'_Forearm',elbow,wrist,.31,.31,fore,'obsidian')
    beam(side+'_Gauntlet',elbow*.42+wrist*.58,wrist,.39,.36,fore,'red_armor')
    beam(side+'_Gauntlet_Ridge',(sign*.95,-.234,1.56),(sign*.97,-.358,1.26),.042,.035,fore,'ember')
    box(side+'_Palm',(sign*.93,-.22,1.14),(.28,.25,.21),hand,'obsidian')
    for i,offset in enumerate([-.095,0,.095]):
        x=sign*.93+offset; z=1.018-(.025 if i==1 else 0)
        box(side+'_Finger_'+str(i),(x,-.265,z),(.068,.13,.15),hand,'obsidian')
        box(side+'_Claw_'+str(i),(x,-.335,z-.046),(.063,.10,.060),hand,'horn_tip')
    box(side+'_Thumb',(sign*.765,-.27,1.12),(.080,.18,.14),hand,'obsidian')
    # A contained flame in each palm, not an opaque cloud covering the hands.
    box(side+'_Palm_Fire',(sign*.93,-.396,1.22),(.10,.105,.11),flame,'fire')
    box(side+'_Palm_Fire_Heart',(sign*.93,-.456,1.225),(.046,.020,.056),flame,'white_fire')
    box(side+'_Palm_Flame_Tip',(sign*.90,-.396,1.322),(.048,.058,.071),flame,'ember')

# Bent, hoofed legs give a heavy demonic stance without realistic joints.
for sign in (-1,1):
    side='L' if sign<0 else 'R'; thigh='thigh_'+side; shin='shin_'+side; foot='foot_'+side
    hip=Vector((sign*.245,.02,1.17)); knee=Vector((sign*.35,-.12,.70)); ankle=Vector((sign*.36,.09,.285))
    centers.update({thigh:hip,shin:knee,foot:ankle}); parents.update({thigh:'body',shin:thigh,foot:shin})
    beam(side+'_Thigh',hip,knee,.33,.34,thigh,'red_armor')
    box(side+'_Knee',(sign*.35,-.142,.69),(.34,.37,.20),shin,'obsidian')
    beam(side+'_Shin',knee,ankle,.235,.26,shin,'obsidian')
    beam(side+'_Shin_Plate',(sign*.35,-.285,.65),(sign*.36,-.078,.32),.15,.05,shin,'red_armor')
    box(side+'_Hoof',(sign*.36,-.08,.172),(.38,.46,.245),foot,'obsidian')
    box(side+'_Cloven_Hoof_Line',(sign*.36,-.317,.152),(.03,.019,.15),foot,'void')
    box(side+'_Hoof_Cap',(sign*.36,-.135,.303),(.29,.31,.055),foot,'charred_horn')

prism('Waist_Banner',[(-.13,.15),(.13,.15),(.13,-.17),(.065,-.17),(.065,-.24),(-.01,-.24),(-.01,-.20),(-.09,-.20),(-.09,-.26),(-.13,-.26)],.038,(0,-.23,1.12),'body','cloth')

# A short segmented tail stays behind the silhouette, ready for rigid animation.
beam('Tail_Base',centers['tail_1'],centers['tail_2'],.12,.12,'tail_1','red_armor')
beam('Tail_Middle',centers['tail_2'],centers['tail_3'],.10,.10,'tail_2','red_armor')
beam('Tail_End',centers['tail_3'],(.58,1.01,.68),.08,.08,'tail_3','red_armor')
prism('Tail_Spade',[(-.12,0),(-.12,.10),(-.04,.10),(-.04,.20),(.04,.20),(.04,.10),(.12,.10),(.12,0),(.04,-.09),(-.04,-.09)],.09,(.60,1.01,.72),'tail_3','obsidian',Euler((0,.48,.25)).to_matrix())

# Broad bat membranes. The outline uses actual square stair steps and three hanging tips.
outline=[(.52,1.95),(.50,2.20),(.72,2.34),(.72,2.50),(.98,2.50),(.98,2.68),(1.30,2.68),(1.30,2.88),(1.52,2.88),(1.52,2.80),(1.72,2.80),(1.72,2.72),(1.90,2.72),(1.90,2.62),(2.10,2.62),(2.10,2.56),(2.04,2.56),(2.04,2.20),(1.95,2.20),(1.95,1.85),(1.85,1.85),(1.85,1.40),(1.72,1.40),(1.72,1.57),(1.64,1.57),(1.64,1.79),(1.52,1.79),(1.52,1.90),(1.39,1.90),(1.39,1.76),(1.27,1.76),(1.27,1.46),(1.13,1.46),(1.13,1.65),(1.02,1.65),(1.02,1.85),(.89,1.85),(.89,1.98),(.74,1.98),(.74,1.94)]
leading=[(.57,2.14),(.74,2.31),(.74,2.47),(1.00,2.47),(1.00,2.65),(1.32,2.65),(1.32,2.85),(1.50,2.85),(1.50,2.77),(1.70,2.77),(1.70,2.69),(1.88,2.69),(1.88,2.59),(2.07,2.59),(2.07,2.52),(1.83,2.52),(1.83,2.62),(1.65,2.62),(1.65,2.70),(1.45,2.70),(1.45,2.78),(1.40,2.78),(1.40,2.58),(1.07,2.58),(1.07,2.40),(.81,2.40),(.81,2.25),(.62,2.04)]
for sign in (-1,1):
    side='L' if sign<0 else 'R'; bone='wing_'+side
    pivot=Vector((sign*.52,.30,2.09)); centers[bone]=pivot; parents[bone]='chest'
    begin=len(parts)
    prism(side+'_Wing_Membrane',[(sign*x,z) for x,z in outline],.085,(0,.41,0),bone,'membrane')
    prism(side+'_Wing_Leading_Edge',[(sign*x,z) for x,z in leading],.085,(0,.346,0),bone,'obsidian')
    beam(side+'_Wing_Arm',(sign*.53,.34,2.12),(sign*1.32,.34,2.76),.10,.10,bone,'obsidian')
    box(side+'_Wing_Knuckle',(sign*1.40,.34,2.78),(.19,.16,.19),bone,'charred_horn')
    # Foreground supports follow the membrane fan and leave the red surface readable.
    beam(side+'_Wing_Outer_Finger_A',(sign*1.45,.342,2.74),(sign*1.96,.342,2.60),.060,.065,bone,'obsidian')
    beam(side+'_Wing_Outer_Finger_B',(sign*1.96,.342,2.60),(sign*1.82,.342,1.46),.060,.065,bone,'obsidian')
    beam(side+'_Wing_Inner_Finger',(sign*1.41,.342,2.70),(sign*1.205,.342,1.51),.058,.065,bone,'obsidian')
    box(side+'_Wing_Thumb',(sign*1.42,.32,2.93),(.10,.11,.15),bone,'horn_tip')
    # Sweep the wings backwards, exposing the front of the torso and the arm pivots.
    R=Euler((0,0,math.radians(sign*14))).to_matrix()
    for o in parts[begin:]:
        # Record the world-to-original transform for metric membrane painting.
        o['wing_sign']=sign; o['wing_pivot']=list(pivot); o['wing_sweep']=sign*14
        for v in o.data.vertices: v.co=pivot+R@(v.co-pivot)
        o['local_rotation']=list((R@Euler(o['local_rotation'],'XYZ').to_matrix()).to_euler('XYZ'))
        o.data.update()

# Height includes crown and hooves. The ground origin remains usable on the map.
coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+.02))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}

# UV islands preserve a 64px/m pixel size on every planar face.
DENSITY=64; PAD=2; islands=[]
for o in parts:
    me=o.data; me.uv_layers.new(name='Metric_Pixel_UV'); R=Euler(o['local_rotation'],'XYZ').to_matrix()
    for p in me.polygons:
        n=p.normal.normalized(); up=R@Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.001: up=R@Vector((0,1,0)); up-=n*up.dot(n)
        up.normalize(); right=up.cross(n).normalized()
        coords=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        lo=Vector((min(v.x for v in coords),min(v.y for v in coords))); coords=[v-lo for v in coords]
        islands.append(dict(obj=o,polygon=p.index,normal=R.transposed()@n,coords=coords,lo=lo,right=right,up=up,n=n,
            plane=me.vertices[p.vertices[0]].co.dot(n),
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
palette={'obsidian':(48,40,48),'red_armor':(98,33,39),'charred_horn':(76,57,48),'horn_tip':(177,140,96),
    'brass':(164,103,53),'void':(18,14,19),'face':(45,35,41),'cloth':(81,25,33),'membrane':(123,34,40),
    'fire':(255,125,28),'white_fire':(255,224,116),'ember':(240,74,19)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind])/255
    tile=np.zeros((h,w,4),dtype=np.float32); tile[:,:,3]=1; emission=np.zeros((h,w,3),dtype=np.float32)
    tile[:,:,:3]=base
    if kind not in ('fire','white_fire','ember','void'):
        shade=1.07 if n.z>.8 else .76 if n.z<-.8 else 1 if n.y<0 else .89
        # Sparse clusters use small value changes, rather than multicolor noise.
        rng=np.random.default_rng(2100+index)
        for yy in range(0,h,4):
            for xx in range(0,w,4):
                value=float(rng.choice([.93,1.,1.,1.035]))
                tile[yy:yy+4,xx:xx+4,:3]=np.minimum(base*shade*value,1)
        if kind!='membrane' and min(w,h)>4:
            tile[-1:,:,:3]=np.minimum(base*shade*1.20,1)
            tile[:,0,:3]=base*shade*.82
        if kind in ('brass','horn_tip') and w>5 and h>5:
            tile[1:h-1,1:2,:3]=np.minimum(base*1.25,1)
        if kind=='membrane' and abs(n.y)>.8:
            # Paint broad fan folds in original wing coordinates, aligned front and back.
            pivot=Vector(o['wing_pivot']); sweep=Euler((0,0,math.radians(o['wing_sweep']))).to_matrix()
            ray_start=Vector((1.43,2.76))
            rays=[Vector((.57,2.02)),Vector((1.20,1.47)),Vector((1.82,1.40)),Vector((2.06,2.57))]
            for yy in range(h):
                for xx in range(w):
                    world=it['right']*(it['lo'].x+(xx+.5)/DENSITY)+it['up']*(it['lo'].y+(yy+.5)/DENSITY)+it['n']*it['plane']
                    raw=Vector((world.x/factor,world.y/factor,(world.z-.02)/factor+zmin))
                    original=pivot+sweep.transposed()@(raw-pivot); point=Vector((abs(original.x),original.z))
                    nearest=10
                    for end in rays:
                        ray=end-ray_start; t=max(0,min(1,(point-ray_start).dot(ray)/ray.length_squared))
                        nearest=min(nearest,(point-(ray_start+t*ray)).length)
                    q=.72 if nearest<.018 else .90 if nearest<.045 else 1.08 if nearest<.09 else 1.0
                    tile[yy,xx,:3]*=q
        if kind=='face' and n.y<-.8 and w>15 and h>15:
            # Square eyes and a carved maw. No nose, human skin, spherical eyeballs or floating face planes.
            tile[:,:,:3]=np.array((41,29,35))/255
            def mark(x0,y0,x1,y1,color,glow=False):
                xa,xb=round(w*x0),round(w*x1); ya,yb=round(h*y0),round(h*y1)
                tile[ya:yb,xa:xb,:3]=np.array(color)/255
                if glow: emission[ya:yb,xa:xb]=np.array(color)/255
            mark(.03,.67,.46,.79,(25,18,24)); mark(.54,.67,.97,.79,(25,18,24))
            mark(.11,.63,.39,.70,(255,148,36),True); mark(.61,.63,.89,.70,(255,148,36),True)
            mark(.17,.65,.32,.70,(255,225,112),True); mark(.68,.65,.83,.70,(255,225,112),True)
            mark(.37,.70,.46,.74,(255,103,23),True); mark(.54,.70,.63,.74,(255,103,23),True)
            mark(.21,.22,.79,.35,(19,12,17)); mark(.29,.17,.71,.24,(19,12,17))
            mark(.29,.22,.71,.25,(225,64,17),True)
            mark(.28,.27,.37,.35,(179,143,97)); mark(.63,.27,.72,.35,(179,143,97))
    elif kind in ('fire','white_fire','ember'):
        emission[:,:,:3]=tile[:,:,:3]
        if kind=='fire' and min(w,h)>4:
            tile[1:h-1,1:w-1,:3]=np.array((255,164,46))/255; emission=tile[:,:,:3].copy()
    padded=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    epad=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=padded
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=epad
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(data.reshape(-1)); im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png'))
    im.file_format='PNG'; im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.new(NAME+'_Obsidian_Crimson_Ember'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.88
bsdf.inputs['Specular IOR Level'].default_value=.15
for im,socket in zip(images,['Base Color','Emission Color']):
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=im; node.interpolation='Closest'
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
bsdf.inputs['Emission Strength'].default_value=1.1
for o in parts: o.data.materials.append(mat)

arm=bpy.data.armatures.new(NAME+'_Prepared_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm)
col.objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=arm.edit_bones.new('root'); b.head=(0,0,0); b.tail=(0,0,.20); b.use_deform=False
for n,c in centers.items():
    b=arm.edit_bones.new(n); b.head=c; b.tail=c+Vector((0,0,.15))
for n in centers: arm.edit_bones[n].parent=arm.edit_bones[parents[n]]
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    o.parent=rig; o.modifiers.new('Prepared_Rigid_Pivots','ARMATURE').object=rig
rig['status']='Static model. One weight per vertex; shoulder, elbow, wrist, wing, furnace and tail pivots prepared.'

def aim(o,p): o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.17,.20,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5; scene.world=world
for label,pos,power,color in [('Key',(-4,-6,8),1050,(1,.92,.81)),('Fill',(5,-3,5),750,(.83,.89,1)),('Rim',(0,5,7),1100,(1,.55,.30))]:
    data=bpy.data.lights.new(NAME+'_'+label,'AREA'); data.energy=power; data.size=5; data.color=color
    o=bpy.data.objects.new(data.name,data); studio.objects.link(o); o.location=pos; aim(o,(0,0,1.6))
me=bpy.data.meshes.new(NAME+'_StudioFloorMesh'); me.from_pydata([(-200,-200,-.01),(200,-200,-.01),(200,200,-.01),(-200,200,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_StudioFloor',me); studio.objects.link(floor)
gm=bpy.data.materials.new(NAME+'_Floor'); gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.09,.11,.14,1)
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(gm)
data=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera)
data.type='ORTHO'; data.ortho_scale=4.7; camera.location=(3,-10,4.1); aim(camera,(0,.15,1.53)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Infernal archdemon: obsidian carapace, broad crimson bat wings, stepped crown horns, cloven hooves and a contained ember furnace; three meters.'
scene['stage']='Static model only; shared civilization design.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
