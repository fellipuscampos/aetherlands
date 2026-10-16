"""A suspended hollow infernal relic, following the user's armored revenant reference."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='elder_lich_blocky_v1'; NAME='Elder_Lich_Blocky_V1'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/elder_lich_blocky_v1_review'
assert NAME not in bpy.data.scenes, 'Preserve previous work.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'scripts/data/UnitDatabase.gd',ROOT/'assets/generated/magic/elder_lich/elder_lich.glb']
for stem in ['archdemon_blocky_v5_animated','seraph_blocky_v4_animated']:
    folder=ROOT/'assets/generated/grand_manifestations'/stem
    protected.extend(folder/(stem+'.'+ext) for ext in ('glb','blend'))
protected.append(ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb')
old_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
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

# An ancient mortal mage: hooded skull, worn vestments, connected arms and a fading lower body.
centers={'body':Vector((0,.04,1.72)),'chest':Vector((0,.04,2.19)),'head':Vector((0,.04,2.72))}
parents={'body':'root','chest':'body','head':'chest'}
box('Withered_Torso',(0,.055,2.19),(.50,.38,.52),'chest','shadow')
box('Spectral_Spine',(0,-.150,2.22),(.065,.035,.43),'chest','spirit_dim')
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    for j,z in enumerate((2.32,2.21,2.10)):
        box(side+'_Ancient_Rib_'+str(j),(sign*.132,-.182,z),(.19,.040,.056),'chest','bone')
    # Broad, asymmetric stepped lapels frame the remaining rib cage.
    prism(side+'_Mantle_Lapel',[(sign*x,z) for x,z in [(.11,2.42),(.36,2.42),(.49,2.32),(.49,2.19),(.33,2.19),(.33,1.97),(.24,1.97),(.24,2.30),(.11,2.30)]],.095,(0,-.125,0),'chest','cloth')
    beam(side+'_Collar_Trim',(sign*.12,-.195,2.40),(sign*.35,-.195,2.31),.036,.025,'chest','brass')
box('Neck_Remnant',(0,.005,2.50),(.095,.13,.15),'head','bone')

# Deep square cowl, with a real opening around a small weathered cubic skull.
box('Hood_Back',(0,.285,2.80),(.65,.115,.54),'head','cloth_dark')
box('Hood_Roof',(0,.035,3.025),(.63,.66,.14),'head','cloth')
box('Hood_Roof_Step',(0,.085,3.112),(.49,.51,.065),'head','cloth')
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    profile=[(sign*x,z) for x,z in [(.245,2.965),(.365,2.965),(.415,2.845),(.415,2.625),(.345,2.625),(.345,2.510),(.235,2.510),(.235,2.61),(.265,2.61),(.265,2.82),(.245,2.82)]]
    prism(side+'_Deep_Cowl',profile,.60,(0,.01,0),'head','cloth')
    box(side+'_Cowl_Inner_Shadow',(sign*.232,.006,2.77),(.055,.44,.33),'head','shadow')
    box(side+'_Hood_Edge',(sign*.296,-.302,2.81),(.031,.018,.27),'head','brass_dark')
box('Skull',(0,-.021,2.756),(.402,.365,.378),'head','skull_face')
box('Skull_Jaw',(0,-.047,2.535),(.292,.290,.067),'head','bone')
# A small antique diadem identifies a sovereign necromancer rather than a heavily armored monster.
box('Diadem_Band',(0,-.288,3.035),(.43,.046,.055),'head','brass')
for label,x,height in [('Center',0,.115),('Left',-.147,.068),('Right',.147,.068)]:
    box('Diadem_'+label,(x,-.286,3.066+height/2),(.043,.045,height),'head','brass')

box('Waist_Worn_Robe',(0,.07,1.79),(.46,.40,.33),'body','cloth_dark')
box('Antique_Belt',(0,-.015,1.765),(.49,.45,.060),'body','brass_dark')
box('Belt_Clasp',(0,-.256,1.765),(.11,.023,.095),'body','brass')
# A modest relic necklace, not an exposed energy core.
for sign in (-1,1): beam(('L' if sign<0 else 'R')+'_Relic_Chain',(sign*.09,-.242,2.35),(0,-.267,2.27),.014,.014,'chest','brass_dark')
box('Relic_Setting',(0,-.272,2.255),(.072,.028,.095),'chest','brass')
box('Relic_Green_Seal',(0,-.291,2.257),(.036,.012,.050),'chest','glow')

# Long robes taper and break into square-ended strips. No boots or ordinary legs.
for side,sign in [('L',-1),('R',1)]:
    name='robe_front_'+side; centers[name]=Vector((sign*.18,-.165,1.72)); parents[name]='body'
    profile=[(sign*x,z) for x,z in [(.035,1.74),(.355,1.74),(.355,1.36),(.40,1.36),(.40,.94),(.43,.94),(.43,.56),(.35,.56),(.35,.42),(.24,.42),(.24,.63),(.12,.63),(.12,.52),(.035,.52)]]
    prism(side+'_Front_Vestment',profile,.078,(0,-.163,0),name,'cloth')
    # Worn vertical edging is broad enough to survive the game's high camera.
    box(side+'_Vertical_Stole',(sign*.08,-.209,1.20),(.038,.018,.97),name,'brass_dark')
    box(side+'_Stole_Lower_End',(sign*.08,-.209,.705),(.082,.018,.034),name,'brass_dark')
    name='robe_side_'+side; centers[name]=Vector((sign*.35,.095,1.72)); parents[name]='body'
    profile=[(-.19,1.75),(.19,1.75),(.19,1.26),(.26,1.26),(.26,.70),(.19,.70),(.19,.34),(.08,.34),(.08,.50),(-.12,.50),(-.12,.75),(-.19,.75)]
    # Side panels face outward, perpendicular to the front panels.
    R=Matrix.Rotation(sign*math.pi/2,3,'Z')
    prism(side+'_Side_Vestment',profile,.085,(sign*.365,.12,0),name,'cloth_dark',R)

# One heavy cape with staggered square hems, forming a quiet, readable silhouette.
for label,x,w,bottom in [('Left',-.285,.285,.40),('Center',0,.33,.31),('Right',.285,.285,.48)]:
    offset={'Left':Vector((0,0,0)),'Center':Vector((0,.018,-.003)),'Right':Vector((0,.036,-.006))}[label]
    bone='cape_'+label.lower(); centers[bone]=Vector((x,.265,2.40))+offset; parents[bone]='chest'
    profile=[(-w/2,2.42),(w/2,2.42),(w/2,1.45),(w/2+.08,1.45),(w/2+.08,bottom+.15),(w/2-.01,bottom+.15),(w/2-.01,bottom),(-w/2+.025,bottom),(-w/2+.025,bottom+.23),(-w/2-.075,bottom+.23),(-w/2-.075,1.29),(-w/2,1.29)]
    R=Euler((math.radians(7),0,0)).to_matrix()
    profile=[(px,pz-2.42) for px,pz in profile]
    prism(label+'_Ancient_Cape',profile,.072,Vector((x,.265,2.42))+offset,bone,'cape',R)
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    box(side+'_Mantle_Shoulder',(sign*.415,.025,2.365),(.35,.48,.125),'chest','cloth')
    box(side+'_Shoulder_Edging',(sign*.415,-.213,2.378),(.31,.022,.038),'chest','brass_dark')

# Arms remain anatomically continuous. Cubic bone hands match the game's hand language.
for side,sign in [('L',-1),('R',1)]:
    shoulder=Vector((sign*.45,.016,2.33)); elbow=Vector((sign*.555,-.055,1.955))
    wrist=Vector((sign*.635,-.330,1.845)) if side=='L' else Vector((sign*.495,-.370,1.905))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist})
    parents.update({upper:'chest',fore:upper,hand:fore})
    beam(side+'_Robe_Upper_Sleeve',shoulder,elbow,.262,.272,upper,'cloth')
    beam(side+'_Sleeve_Edge',elbow+Vector((0,0,.055)),elbow+Vector((0,0,-.026)),.280,.283,upper,'brass_dark')
    beam(side+'_Forearm_Bone',elbow,wrist,.093,.092,fore,'bone')
    beam(side+'_Forearm_Spectral_Remnant',elbow+Vector((0,.012,0)),wrist+Vector((0,.012,0)),.070,.070,fore,'spirit_dim')
    box(side+'_Square_Hand',wrist,(.168,.17,.145),hand,'bone')
    box(side+'_Wrist_Wrap',wrist+Vector((0,.033,.056)),(.177,.115,.035),hand,'cloth_dark')

# Staff and an open research tome distinguish the ancient scholar from a pure-energy manifestation.
centers['staff']=Vector((-.663,-.334,1.845)); parents['staff']='hand_L'
beam('Old_Staff_Shaft',(-.663,-.334,.58),(-.663,-.334,2.63),.069,.069,'staff','wood')
for z in (.62,1.40,2.51): box('Staff_Binding_'+str(z),(-.663,-.334,z),(.093,.091,.055),'staff','brass_dark')
for sign in (-1,1):
    beam(('Left' if sign<0 else 'Right')+'_Staff_Crook',(-.663+sign*.061,-.334,2.53),(-.663+sign*.132,-.334,2.77),.064,.067,'staff','bone')
    box(('Left' if sign<0 else 'Right')+'_Staff_Fork_End',(-.663+sign*.132,-.334,2.79),(.065,.066,.090),'staff','bone')
prism('Staff_Grave_Flame',[(-.062,2.59),(.067,2.59),(.067,2.73),(.025,2.73),(.025,2.87),(-.018,2.87),(-.018,2.80),(-.046,2.80),(-.046,2.69),(-.062,2.69)],.062,(-.663,-.334,0),'staff','glow')
centers['tome']=Vector((.523,-.416,1.992)); parents['tome']='hand_R'
R=Euler((math.radians(43),0,math.radians(-8))).to_matrix(); c=centers['tome']
for side,sign in [('Left',-1),('Right',1)]:
    box('Tome_'+side+'_Cover',c+R@Vector((sign*.115,0,-.025)),(.234,.302,.027),'tome','book_cover',R)
    box('Tome_'+side+'_Pages',c+R@Vector((sign*.112,0,.013)),(.211,.274,.056),'tome','paper',R)
box('Tome_Spine',c+R@Vector((0,0,-.004)),(.037,.30,.079),'tome','brass_dark',R)

# Residual spirit only emerges below the torn robe, not as an orbiting cube or a humanoid pair of legs.
for label,x,bottom,y in [('Left',-.145,.16,.07),('Center',.025,.10,.02),('Right',.188,.22,.11)]:
    bone='spectral_tail_'+label.lower(); centers[bone]=Vector((x,y,.88)); parents[bone]='body'
    profile=[(-.083,1.00),(.083,1.00),(.083,.54),(.043,.54),(.043,bottom+.07),(.013,bottom+.07),(.013,bottom),(-.034,bottom),(-.034,.37),(-.066,.37),(-.066,.66),(-.083,.66)]
    prism(label+'_Spectral_Remnant',profile,.11,(x,y,0),bone,'spirit_dim')

coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
GROUND=.20
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+GROUND))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}

# One metric nearest-filtered atlas with old slate/iron, square wear and woven red stoles.
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
palette={'cloth':(65,48,91),'cloth_dark':(42,35,61),'cape':(51,39,73),'shadow':(19,26,31),
         'bone':(180,179,154),'skull_face':(190,189,164),'brass':(151,126,79),'brass_dark':(105,91,67),
         'spirit_dim':(79,134,112),'glow':(89,220,149),'wood':(65,50,54),
         'book_cover':(68,42,69),'paper':(193,185,146)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind])/255
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=base
    emission=np.zeros((h,w,3),dtype=np.float32)
    shade=1.07 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .86
    tile[:,:,:3]*=shade
    rng=np.random.default_rng(18000+index)
    if kind not in ('glow','spirit_dim','shadow'):
        for _ in range(max(1,w*h//130)):
            xx=int(rng.integers(0,w)); yy=int(rng.integers(0,h))
            pw=int(rng.integers(2,5)); ph=int(rng.integers(1,4))
            tile[yy:yy+ph,xx:xx+pw,:3]=base*shade*float(rng.choice([.88,.94,1.06,1.12]))
    if kind in ('cloth','cloth_dark','cape') and min(w,h)>6:
        # Broad worn vertical folds and restrained hems; no modern checkerboard panels.
        for xx in range(5,w-3,12): tile[:,xx:xx+2,:3]*=.86
        tile[:2,:,:3]*=.78
        if 'Front_Vestment' in o.name or 'Ancient_Cape' in o.name:
            tile[2:4,2:w-2,:3]=np.array((107,91,76))/255
            for xx in range(4,w-3,13):
                tile[5:9,xx:xx+2,:3]=np.array((121,107,80))/255
                tile[6:8,xx-1:xx+3,:3]=np.array((121,107,80))/255
    elif kind in ('brass','brass_dark'):
        if h>2: tile[-1:,:,:3]=base*1.13
        if w>2: tile[:,0,:3]=base*.74
    elif kind=='wood':
        for xx in range(2,w,4): tile[:,xx:xx+1,:3]*=.80
    elif kind=='paper' and n.z>.7 and min(w,h)>8:
        for yy,length in [(3,w-5),(6,w-7),(9,w-6),(12,w-8)]:
            if yy<h-2: tile[yy:yy+1,3:max(4,length),:3]=np.array((85,67,63))/255
        tile[:,0:1,:3]*=.75
    elif kind=='skull_face' and n.y<-.8:
        # Minecraft-like square sockets and painted teeth; no anatomical protruding nose.
        def rect(x0,y0,x1,y1,rgb,emit=False):
            x0,x1=round(x0*w),round(x1*w); y0,y1=round(y0*h),round(y1*h)
            tile[y0:y1,x0:x1,:3]=np.array(rgb)/255
            if emit: emission[y0:y1,x0:x1,:]=np.array(rgb)/255
        rect(.12,.46,.40,.73,(29,36,34)); rect(.60,.46,.88,.73,(29,36,34))
        rect(.22,.54,.34,.63,(114,238,164),True); rect(.66,.54,.78,.63,(114,238,164),True)
        rect(.12,.74,.42,.79,(132,137,117)); rect(.58,.74,.88,.79,(132,137,117))
        rect(.34,.24,.66,.32,(60,63,52))
        for xx in (.39,.49,.59): rect(xx,.28,xx+.05,.35,(197,196,172))
        rect(.46,.38,.54,.42,(138,145,126))
    if kind=='glow': emission=tile[:,:,:3]*.75
    if kind=='spirit_dim':
        emission=tile[:,:,:3]*.24
        if h>7: tile[:h//3,:,:3]*=.76
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
mat=bpy.data.materials.new(NAME+'_Ancient_Vestments_Bone_Spectral'); mat.use_nodes=True
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
rig['status']='Static ancient spectral mage: anatomically connected arms, skull, staff, tome, vestments and residual spirit.'

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
data.type='ORTHO'; data.ortho_scale=4.1; camera.location=(3,-11,4.0); aim(camera,(0,0,1.77)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Three-meter ancient spectral lich: mortal mage transformed by necromancy, cubic skull beneath a deep hood, worn purple vestments, antique staff and research tome. No orbiting mana core.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
