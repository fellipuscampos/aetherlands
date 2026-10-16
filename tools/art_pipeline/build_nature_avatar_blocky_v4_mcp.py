"""Three-meter living grove avatar of the druidic school."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='nature_avatar_blocky_v4'; NAME='Nature_Avatar_Blocky_V4'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/nature_avatar_blocky_v4_review'
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
protected.extend(ROOT/'assets/generated/grand_manifestations'/'nature_avatar_blocky_v3'/('nature_avatar_blocky_v3.'+ext) for ext in ('glb','blend'))
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

# An ancient root sovereign: contiguous sculpted bark masses, a broad asymmetrical silhouette.
centers={'body':Vector((0,.10,1.19)),'chest':Vector((0,.025,2.04)),
 'crown':Vector((0,-.015,2.45)),'core':Vector((.015,-.19,2.60)),
 'hanging_root_L':Vector((-.11,-.12,1.24)),'hanging_root_R':Vector((.13,.04,1.23))}
parents={'body':'root','chest':'body','crown':'chest','core':'chest','hanging_root_L':'body','hanging_root_R':'body'}
def splinter(label,a,b,width,bone,kind='wood'):
    a,b=Vector(a),Vector(b); length=(b-a).length; R=(b-a).to_track_quat('Z','Y').to_matrix()
    profile=[(-width/2,0),(width/2,0),(width/2,length*.38),(width*.28,length*.38),
      (width*.28,length*.74),(width*.10,length*.74),(width*.10,length),
      (-width*.10,length),(-width*.10,length*.74),(-width*.28,length*.74),(-width*.28,length*.38),(-width/2,length*.38)]
    return prism(label,profile,width*.75,a,bone,kind,R)
def root_path(label,points,width,depth,bone,kind='wood'):
    for i in range(len(points)-1): beam(label+'_'+str(i),points[i],points[i+1],width*(1-.075*i),depth,bone,kind)

# Solid stepped roots outline a narrow, deep abdominal opening. No scaffolding-sized strips.
for side,s in [('L',-1),('R',1)]:
    profile=[(s*x,z) for x,z in [(.10,1.14),(.44,1.14),(.44,1.42),(.58,1.42),(.58,1.82),(.74,1.82),
      (.74,2.18),(.57,2.35),(.32,2.26),(.22,2.04),(.30,1.78),(.25,1.47),(.09,1.36)]]
    prism(side+'_Ancient_Trunk_Wall',profile,.58,(0,.04,0),'chest','bark')
    root_path(side+'_Trunk_Heartwood',[(s*.31,-.30,1.26),(s*.40,-.30,1.59),(s*.40,-.30,1.96),(s*.49,-.29,2.17)],.16,.10,'chest','wood')
    beam(side+'_Back_Trunk', (s*.26,.39,1.22),(s*.37,.35,2.14),.22,.24,'chest','bark_dark')
prism('Root_Breastplate',[(-.66,2.28),(-.29,2.30),(0,2.13),(.33,2.30),(.66,2.30),(.52,2.09),(.18,1.95),(-.18,1.95),(-.53,2.08)],.24,(0,-.245,0),'chest','wood')
prism('Pelvic_Trunk',[(-.48,1.14),(-.50,1.37),(-.27,1.48),(.23,1.47),(.47,1.36),(.45,1.13),(.23,1.03),(-.23,1.04)],.57,(0,.025,0),'body','bark')
beam('Pelvic_Root_Wrap',(-.42,-.31,1.12),(.42,-.31,1.40),.19,.16,'body','wood')

# A continuous, irregular root crown grows out of the torso, not a segmented geometric ring.
left=[(-.18,2.01),(-.47,2.13),(-.72,2.43),(-.72,2.77),(-.58,2.77),(-.58,2.96),(-.32,3.17),(-.10,3.17),
 (-.10,3.29),(.08,3.29),(.08,3.11),(.30,3.11),(.30,2.96),(-.08,2.96),(-.35,2.80),(-.44,2.59),(-.40,2.39),(-.11,2.23)]
right=[(.12,2.02),(.43,2.17),(.65,2.41),(.65,2.71),(.51,2.91),(.34,3.06),(.16,3.06),(.16,2.88),(.33,2.73),(.38,2.57),(.31,2.37),(.04,2.23)]
prism('Sovereign_Crown_Left',left,.37,(0,-.01,0),'crown','bark')
prism('Sovereign_Crown_Right',right,.32,(0,.005,0),'crown','wood')
# Raised grain ridges follow the major root surfaces, with clear separation in value.
root_path('Crown_Left_Heartwood',[(-.23,-.206,2.18),(-.57,-.206,2.47),(-.55,-.206,2.78),(-.29,-.206,3.02),(.12,-.206,3.025)],.075,.035,'crown','wood_light')
root_path('Crown_Right_Dark_Cleft',[(.24,-.167,2.20),(.49,-.167,2.45),(.47,-.167,2.72),(.26,-.167,2.93)],.061,.027,'crown','bark_dark')
root_path('Rear_Crown_Root',[(-.43,.28,2.25),(-.48,.31,2.65),(-.27,.34,2.93),(.13,.33,2.96),(.43,.28,2.58)],.15,.18,'crown','bark_dark')
splinter('Crown_Left_Fork',(-.59,.045,2.85),(-.77,.08,3.18),.18,'crown','wood')
splinter('Crown_Right_Fork',(.49,.045,2.83),(.74,.08,3.13),.17,'crown','bark')
box('Exposed_Druidic_Core',centers['core'],(.445,.445,.445),'core','core',Euler((math.radians(14),math.radians(22),math.radians(17))).to_matrix())
# Root tendrils inside the chest emphasize depth while leaving the core fully visible.
for i,(x,y,bottom) in enumerate([(-.14,.07,1.44),(.13,.13,1.46),(.015,.26,1.37)]):
    root_path('Inner_Living_Root_'+str(i),[(x,y,2.23),(x*.7,y,1.93),(x*.8+.03,y,bottom)],.036,.038,'chest','vine')

# Enormous fused shoulder knots carry the silhouette. Left is higher and heavier.
for side,s in [('L',-1),('R',1)]:
    shoulder=Vector((s*.70,.015,2.22 if s<0 else 2.16)); elbow=Vector((s*.94,-.075,1.69)); wrist=Vector((s*1.07,-.28,1.045))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist}); parents.update({upper:'chest',fore:upper,hand:fore})
    # One irregular volumetric prism per mantle, not a plain square shoulder pad.
    profile=[(-.34,-.20),(.30,-.20),(.30,-.08),(.45,-.08),(.45,.20),(.32,.20),(.32,.39),(.12,.39),(.12,.51),(-.12,.51),(-.12,.36),(-.32,.36),(-.32,.16),(-.40,.16),(-.40,-.07),(-.34,-.07)]
    profile=[(s*x,z*(1.05 if s<0 else .86)) for x,z in profile]
    R=Euler((math.radians(-8),math.radians(-s*13),0)).to_matrix()
    prism(side+'_Great_Root_Shoulder',profile,.64,shoulder,upper,'bark',R)
    beam(side+'_Connected_Upper_Trunk',shoulder,elbow,.40,.44,upper,'bark_dark')
    beam(side+'_Upper_Arm_Outer_Root',shoulder+Vector((s*.12,-.15,-.02)),elbow+Vector((s*.12,-.15,.01)),.23,.19,upper,'wood')
    # Broad angular forearm tapers at the wrist, rather than many thin stick segments.
    a=elbow; b=wrist; length=(b-a).length; R=(b-a).to_track_quat('Z','Y').to_matrix()
    profile=[(-.26,-.06),(.26,-.06),(.26,.18),(.31,.18),(.31,length*.69),(.24,length*.69),(.24,length+.10),(-.23,length+.10),(-.23,length*.74),(-.30,length*.74),(-.30,.20),(-.26,.20)]
    prism(side+'_Massive_Root_Forearm',profile,.53,a,fore,'bark',R)
    beam(side+'_Forearm_Heartwood',elbow+Vector((-s*.12,-.305,-.10)),wrist+Vector((s*.10,-.28,.03)),.18,.075,fore,'wood')
    beam(side+'_Forearm_Cleft',elbow+Vector((s*.19,-.305,-.08)),wrist+Vector((s*.17,-.28,.07)),.038,.025,fore,'bark_dark')
    R=Euler((math.radians(-8),math.radians(s*8),math.radians(-s*4))).to_matrix()
    box(side+'_Single_Square_Hand',wrist+Vector((s*.025,-.07,-.21)),(.59,.57,.60),hand,'bark',R)
    box(side+'_Hand_Heartwood_Facet',wrist+Vector((s*.03,-.358,-.22)),(.37,.035,.43),hand,'wood',R)
    # Few strong branches produce a regal, threatening crown around the upper body.
    for i,(offset,end,width) in enumerate([
        ((s*.04,.085,.37),(s*.15,.10,.72),.21),
        ((s*.26,.11,.28),(s*.56,.12,.60),.19),
        ((s*.35,.12,.10),(s*.69,.14,.29),.17)]):
        if side=='R' and i==0: end=(s*.17,.10,.59)
        splinter(side+'_Shoulder_Ancient_Bough_'+str(i),shoulder+Vector(offset),shoulder+Vector(end),width,upper,'wood')
    splinter(side+'_Forearm_Broken_Root',elbow+Vector((s*.25,.07,-.16)),elbow+Vector((s*.51,.13,.06)),.18,fore,'wood')
    # Moss is rooted into the shoulder silhouette and painted with large dark-green clusters.
    for i,(offset,size) in enumerate([
        ((-s*.15,-.24,.32),(.30,.14,.22)),((s*.13,-.23,.26),(.27,.17,.22)),
        ((s*.29,.14,.05),(.19,.24,.19))]):
        box(side+'_Shoulder_Moss_'+str(i),shoulder+Vector(offset),size,upper,'moss' if i<2 else 'moss_dark',Euler((0,math.radians(s*10),0)).to_matrix())
    box(side+'_Forearm_Moss',(s*1.01,-.11,1.34),(.26,.16,.24),fore,'moss_dark')
    root_path(side+'_Shoulder_Grain_Crest',[shoulder+Vector((-s*.25,-.34,.22)),shoulder+Vector((s*.01,-.34,.33)),shoulder+Vector((s*.32,-.34,.06))],.065,.033,upper,'wood_light')

# A single suspended trunk tapers into a cluster of unequal roots, with no hips, knees or feet.
prism('Suspended_Trunk_Taper',[(-.38,1.20),(.36,1.20),(.36,1.04),(.27,1.04),(.27,.89),
 (.16,.89),(.16,.74),(-.13,.74),(-.13,.86),(-.25,.86),(-.25,1.01),(-.38,1.01)],.44,(0,.06,0),'body','bark')
root_specs=[
 ('center',[(.025,-.055,1.03),(-.015,-.055,.77),(.045,-.02,.48)],.155,.165,'wood'),
 ('left',[(-.27,.025,1.16),(-.39,.02,.90),(-.27,-.035,.67)],.14,.145,'bark'),
 ('right',[(.28,.10,1.17),(.39,.115,.97),(.30,.055,.77)],.15,.15,'wood'),
 ('rear',[(-.10,.285,1.14),(-.16,.30,.88),(-.07,.26,.61)],.115,.13,'bark_dark'),
 ('inner',[(.13,.225,1.01),(.16,.22,.78),(.115,.19,.54)],.082,.095,'vine')]
for label,points,width,depth,kind in root_specs:
    bone='floating_root_'+label
    centers[bone]=Vector(points[0]); parents[bone]='body'
    # Broad at the trunk, stepped and narrower at each hanging end. No boot-like blocks.
    for i in range(len(points)-1):
        a,b=Vector(points[i]),Vector(points[i+1]); length=(b-a).length
        R=(b-a).to_track_quat('Z','Y').to_matrix(); w=width*(1-.27*i)
        profile=[(-w/2,0),(w/2,0),(w/2,length*.43),(w*.31,length*.43),
          (w*.31,length*.78),(w*.14,length*.78),(w*.14,length),
          (-w*.14,length),(-w*.14,length*.78),(-w*.31,length*.78),(-w*.31,length*.43),(-w/2,length*.43)]
        prism('Suspended_'+label+'_Root_'+str(i),profile,depth*(1-.20*i),a,bone,kind,R)
root_path('Lower_Living_Root_L',[(-.11,-.12,1.24),(-.16,-.16,1.03),(-.12,-.16,.75)],.075,.09,'hanging_root_L','vine')
root_path('Lower_Living_Root_R',[(.13,.04,1.23),(.11,-.02,.97),(.16,-.02,.66)],.065,.08,'hanging_root_R','vine')

coords=[v.co for o in parts for v in o.data.vertices]
zmin=0.0; zmax=max(v.z for v in coords); factor=3.0/zmax
GROUND=0.0
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+GROUND))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}


previous=bpy.app.driver_namespace['nature_avatar_blocky_v3']
old_parts={o.name.removeprefix('Nature_Avatar_Blocky_V3_'):o for o in previous['parts']}
upper_names=[]
for o in parts:
    label=o.name.removeprefix(NAME+'_')
    if label in old_parts and not label.startswith('Lower_Living_Root'):
        old=old_parts[label]
        assert len(o.data.vertices)==len(old.data.vertices)
        assert max((a.co-b.co).length for a,b in zip(o.data.vertices,old.data.vertices))<1e-6,label
        upper_names.append(label)
assert len(upper_names)>60

# Metric pixel atlas: forest bark, cut wood and layered foliage, 64 pixels per meter.
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
# Strong dark bark / warm heartwood separation makes the emissive core the focal point.
palette={'bark':(81,61,38),'bark_dark':(43,35,25),'wood':(125,95,56),'wood_light':(165,132,79),
         'moss':(65,97,42),'moss_dark':(43,68,36),'vine':(72,95,41),'core':(113,224,85)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(120700+index); yy,xx=np.indices((h,w))
    noise=rng.integers(-7,8,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+noise[:,:,None],0,255)
    if kind in ('wood','wood_light','bark','bark_dark','vine'):
        # Low-frequency stepped strips suggest bark clefts; no regular plank checkerboard.
        for cx in range(3,w,10):
            for cy in range(0,h,17):
                drift=int(rng.integers(-1,2)); length=int(rng.integers(7,16))
                x=max(0,cx+drift); rgb[cy:cy+length,x:x+2]=np.maximum(0,base-22)
                if x+2<w: rgb[cy:cy+length,x+2:x+3]=np.minimum(255,base+13)
        if min(w,h)>8:
            for _ in range(max(1,w*h//240)):
                cx=int(rng.integers(1,w-2)); cy=int(rng.integers(1,h-2))
                rgb[cy:cy+4,cx:cx+3]=np.maximum(0,base-12)
        if 'Crown' in o.name or 'Trunk_Wall' in o.name or 'Great_Root_Shoulder' in o.name:
            rgb[:2]=np.maximum(0,rgb[:2]-14)
    elif kind.startswith('moss'):
        clusters=rng.integers(-12,13,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
        rgb=np.clip(base+clusters[:,:,None],0,255)
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[65,154,48]
        # A single, softly varied luminous cube; avoid a target of concentric square frames.
        rgb[(xx>w*.30)&(xx<w*.72)&(yy>h*.30)&(yy<h*.75)]=[169,248,122]
        for _ in range(4):
            cx=int(rng.integers(2,max(3,w-3))); cy=int(rng.integers(2,max(3,h-3)))
            rgb[cy:cy+2,cx:cx+2]=[199,255,157]
    light=1.06 if n.z>.8 else .76 if n.z<-.8 else 1 if n.y<0 else .85
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    emission=tile[:,:,:3]*.90 if kind=='core' else np.zeros((h,w,3),dtype=np.float32)
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
mat=bpy.data.materials.new(NAME+'_Sovereign_Bark_Green_Core'); mat.use_nodes=True
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
rig['status']='Static floating root sovereign: approved upper body preserved, no legs or feet, tapered unequal suspended roots and exposed green cube core.'

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
data.type='ORTHO'; data.ortho_scale=4.3; camera.location=(3,-11,4.0); aim(camera,(0,0,1.5)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Floating ancient root sovereign: approved crown, shoulders, torso, arms and green core preserved at the original scale. Suspended tapered roots replace the legs; crown reaches three meters above ground.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes,upper_preserved=upper_names)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_above_ground_m':3.0,'floating':True,'upper_preserved_parts':len(upper_names),'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
