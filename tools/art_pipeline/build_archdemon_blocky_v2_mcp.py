"""A suspended hollow infernal relic, following the user's armored revenant reference."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='archdemon_blocky_v2'; NAME='Infernal_Archdemon_Blocky_V2'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/archdemon_blocky_v2_review'
assert NAME not in bpy.data.scenes, 'Preserve previous work.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'scripts/data/UnitDatabase.gd',ROOT/'assets/generated/magic/archdemon/archdemon.glb',
    ROOT/'assets/generated/grand_manifestations/archdemon_blocky_v1/archdemon_blocky_v1.glb',
    ROOT/'assets/generated/grand_manifestations/archdemon_blocky_v1/archdemon_blocky_v1.blend',
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
centers={'body':Vector((0,.04,1.78)),'chest':Vector((0,.02,2.19)),
    'crown':Vector((0,.075,2.82)),'core':Vector((0,-.32,2.29))}
parents={'body':'root','chest':'body','crown':'chest','core':'chest'}

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

# Hollow cuirass: a suspended shell around the red core, with visible gaps inside.
box('Cuirass_Left_Wall',(-.38,.025,2.29),(.14,.47,.75),'chest')
box('Cuirass_Right_Wall',(.38,.025,2.29),(.14,.47,.75),'chest')
box('Cuirass_Top',(0,.035,2.67),(.82,.44,.13),'chest','edge')
box('Cuirass_Base',(0,.035,1.91),(.66,.46,.13),'chest','iron')
box('Cuirass_Back_Upper',(0,.28,2.50),(.72,.10,.35),'chest','iron')
box('Cuirass_Back_Lower',(0,.28,2.12),(.65,.10,.31),'chest','iron')
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    prism(side+'_Breast_Plate',[(sign*x,z) for x,z in [( .12,2.62),(.46,2.62),(.46,2.46),(.38,2.46),(.38,2.22),(.26,2.22),(.26,2.41),(.12,2.41)]],.10,(0,-.249,0),'chest','plate')
    prism(side+'_Lower_Rib',[(sign*x,z) for x,z in [(.22,2.20),(.42,2.20),(.42,2.02),(.32,2.02),(.32,1.95),(.12,1.95),(.12,2.04),(.22,2.04)]],.085,(0,-.255,0),'chest','plate')
    box(side+'_Chest_Rim',(sign*.398,-.318,2.32),(.042,.035,.40),'chest','edge')
    box(side+'_Lower_Rim',(sign*.26,-.323,1.982),(.23,.033,.046),'chest','edge')
box('Collar_Bridge',(0,-.219,2.70),(.55,.24,.094),'chest','iron')
box('Collar_Red_Seam',(0,-.348,2.697),(.19,.027,.038),'chest','ember')

# The single red relic is the face/focus of the entity. No anatomical face or eyes.
frame('Core_Housing',(0,-.318,2.29),.42,.57,.070,.14,'chest','shadow')
frame('Core_Bezel',(0,-.417,2.29),.36,.48,.038,.060,'core','crimson')
prism('Core_Ruby',[(-.145,-.18),(.145,-.18),(.145,.13),(.10,.13),(.10,.19),(-.10,.19),(-.10,.13),(-.145,.13)],.095,(0,-.457,2.29),'core','ruby')
box('Core_Inner_Red',(0,-.511,2.295),(.185,.013,.257),'core','red_light')
box('Core_Hot_Center',(-.028,-.522,2.325),(.084,.016,.105),'core','hot')
box('Core_Spark',(.040,-.522,2.213),(.025,.017,.035),'core','hot')

# Empty, crown-like collar above the cuirass. Its cavity opens toward the camera.
box('Crown_Back',(0,.175,2.925),(.33,.11,.29),'crown','iron')
box('Crown_Left',(-.153,.025,2.95),(.09,.28,.31),'crown','plate')
box('Crown_Right',(.153,.025,2.95),(.09,.28,.31),'crown','plate')
box('Crown_Top',(0,.050,3.09),(.38,.32,.065),'crown','edge')
box('Crown_Lower',(0,-.075,2.805),(.26,.12,.055),'crown','iron')
box('Crown_Interior',(0,.111,2.92),(.20,.018,.17),'crown','void')

# A broken armor skirt floats below the torso; nothing resembling legs or feet.
box('Waist_Back',(0,.08,1.72),(.57,.39,.15),'body','shadow')
prism('Waist_Front',[(-.31,.11),(.31,.11),(.31,-.07),(.22,-.07),(.22,-.16),(-.22,-.16),(-.22,-.07),(-.31,-.07)],.27,(0,-.025,1.72),'body','plate')
frame('Waist_Relic_Frame',(0,-.183,1.716),.32,.19,.045,.040,'body','edge')
box('Waist_Relic_Recess',(0,-.171,1.716),(.225,.025,.09),'body','shadow')
box('Waist_Relic_Top',(0,-.221,1.791),(.12,.018,.03),'body','iron')
for sign in (-1,1):
    box(('L' if sign<0 else 'R')+'_Waist_Red_Tab',(sign*.123,-.200,1.565),(.049,.045,.125),'body','crimson')
    prism(('L' if sign<0 else 'R')+'_Skirt_Plate',[(sign*x,z) for x,z in [(.23,.13),(.42,.13),(.42,-.10),(.34,-.10),(.34,-.20),(.23,-.20)]],.30,(0,.115,1.62),'body','iron')

# Large tilted pauldrons and detached armored fists. Each shoulder is a single articulated group.
for sign in (-1,1):
    side='L' if sign<0 else 'R'; shoulder='shoulder_'+side; fore='forearm_'+side; fist='fist_'+side
    pivot=Vector((sign*.59,.035,2.53)); elbow=Vector((sign*.79,-.055,2.02)); hand=Vector((sign*.89,-.11,1.54))
    centers.update({shoulder:pivot,fore:elbow,fist:hand}); parents.update({shoulder:'chest',fore:shoulder,fist:fore})
    c=Vector((sign*.74,.035,2.48)); R=Euler((math.radians(8),math.radians(-sign*22),math.radians(sign*9))).to_matrix()
    box(side+'_Pauldron_Shell',c,(.62,.52,.73),shoulder,'iron',R)
    box(side+'_Pauldron_Front',c+R@Vector((0,-.301,.01)),(.56,.11,.65),shoulder,'plate',R)
    box(side+'_Pauldron_Inset',c+R@Vector((0,-.364,.035)),(.405,.025,.49),shoulder,'shadow',R)
    frame(side+'_Pauldron_Border',c+R@Vector((0,-.392,.015)),.53,.66,.048,.029,shoulder,'edge',R)
    box(side+'_Pauldron_Upper_Ridge',c+R@Vector((0,-.025,.397)),(.53,.50,.066),shoulder,'edge',R)
    box(side+'_Pauldron_Lower_Lip',c+R@Vector((0,-.298,-.349)),(.65,.17,.07),shoulder,'iron',R)
    D=R@Euler((0,math.radians(45),0)).to_matrix(); jewel=c+R@Vector((sign*.10,-.432,-.22))
    box(side+'_Pauldron_Seal_Frame',jewel,(.17,.036,.17),shoulder,'edge',D)
    box(side+'_Pauldron_Seal',jewel+R@Vector((0,-.026,0)),(.108,.025,.108),shoulder,'crimson',D)
    box(side+'_Pauldron_Seal_Glow',jewel+R@Vector((0,-.041,0)),(.04,.012,.07),shoulder,'ember',D)
    # Visible red energy occupies the gap, rather than flesh connecting the floating armor.
    beam(side+'_Elbow_Link',(sign*.77,-.07,2.10),(sign*.80,-.07,1.97),.072,.090,fore,'ember')
    a=Vector((sign*.81,-.09,1.93)); b=Vector((sign*.91,-.14,1.56)); F=(b-a).to_track_quat('Z','Y').to_matrix()
    gauntlet=(a+b)*.5
    box(side+'_Gauntlet_Shell',gauntlet,(.44,.43,.47),fore,'iron',F)
    box(side+'_Gauntlet_Cuff',a,(.48,.44,.12),fore,'plate',F)
    box(side+'_Gauntlet_Front',gauntlet+Vector((0,-.23,0)),(.35,.060,.37),fore,'plate',F)
    frame(side+'_Gauntlet_Border',gauntlet+Vector((0,-.265,0)),.34,.35,.043,.025,fore,'edge',F)
    box(side+'_Gauntlet_Palm',hand,(.41,.34,.26),fist,'plate',F)
    # Three broad armored knuckles read as a clenched fist at map scale.
    for i,offset in enumerate([-.125,0,.125]):
        box(side+'_Knuckle_'+str(i),hand+Vector((offset,-.215,-.005)),(.103,.15,.135),fist,'edge',F)
        box(side+'_Finger_'+str(i),hand+Vector((offset,-.07,-.148)),(.103,.24,.10),fist,'iron',F)
    box(side+'_Thumb',hand+Vector((-sign*.232,-.063,.02)),(.12,.21,.23),fist,'plate',F)

# Three solid, segmented red stoles: long front pair and a shorter, swept side strip.
# Their planar faces and coincident section boundaries keep the blocky silhouette clean.
ribbons={
    'stole_L':[(-.205,-.018,1.58,.33),(-.20,-.025,1.18,.34),(-.13,-.18,.81,.33),(-.19,-.25,.43,.31),(-.30,-.16,.13,.28)],
    'stole_R':[(.195,.035,1.58,.29),(.215,.08,1.20,.30),(.31,-.065,.83,.31),(.34,-.11,.44,.28),(.405,-.17,.27,.245)],
    'stole_side':[(.395,.23,1.60,.205),(.50,.31,1.21,.21),(.72,.37,.93,.195),(.99,.43,.68,.175),(1.085,.48,.615,.15)]
}
for label,rows in ribbons.items():
    for i in range(len(rows)-1):
        bone=label+'_'+str(i); a=rows[i]; b=rows[i+1]; centers[bone]=Vector(a[:3]); parents[bone]='body' if i==0 else label+'_'+str(i-1)
        vs=[]; depth=.045
        for row in (a,b):
            x,y,z,w=row
            vs.extend([(x-w/2,y-depth/2,z),(x+w/2,y-depth/2,z),(x+w/2,y+depth/2,z),(x-w/2,y+depth/2,z)])
        mesh_part(label+'_Fold_'+str(i),vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,'cloth')

# Four heavy relic fragments behind the shoulders form an incomplete floating mantle.
# Few large pieces keep the central core and hollow armor legible.
fragments=[('Mantle_Upper_L',(-.98,.67,2.97),(.58,.46,.48),(8,-10,-12)),
    ('Mantle_Upper_R',(1.005,.67,3.03),(.55,.44,.52),(-8,13,15)),
    ('Mantle_Lower_L',(-1.075,.61,2.49),(.31,.35,.32),(12,-8,8)),
    ('Mantle_Lower_R',(1.12,.62,2.54),(.32,.36,.30),(-11,7,-9))]
for label,c,size,angles in fragments:
    bone=label.lower(); centers[bone]=Vector(c); parents[bone]='body'; R=Euler(tuple(math.radians(v) for v in angles)).to_matrix()
    box(label,c,size,bone,'fragment',R)

# The hanging cloth determines the bottom; detached mantle fragments count toward the 3m height.
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
palette={'iron':(73,98,102),'plate':(88,119,119),'edge':(117,146,140),'shadow':(37,59,67),
    'fragment':(74,103,105),'void':(11,19,28),'cloth':(109,21,35),'crimson':(125,20,30),
    'ruby':(181,19,24),'red_light':(229,38,22),'ember':(221,30,24),'hot':(255,135,77)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind])/255
    tile=np.zeros((h,w,4),dtype=np.float32); tile[:,:,3]=1; tile[:,:,:3]=base
    emission=np.zeros((h,w,3),dtype=np.float32)
    if kind in ('iron','plate','edge','fragment','shadow'):
        shade=1.07 if n.z>.8 else .78 if n.z<-.8 else 1 if n.y<0 else .88
        tile[:,:,:3]=base*shade
        # Irregular rectangular wear, not smooth noise or a checkerboard.
        rng=np.random.default_rng(7200+index)
        count=max(1,round(w*h/85))
        for patch in range(count):
            xx=int(rng.integers(0,w)); yy=int(rng.integers(0,h)); pw=int(rng.integers(2,7)); ph=int(rng.integers(2,5))
            value=float(rng.choice([.78,.88,1.10,1.18]))
            tile[yy:yy+ph,xx:xx+pw,:3]=np.minimum(base*shade*value,1)
        if min(w,h)>4:
            tile[-1:,:,:3]=np.minimum(base*shade*1.27,1); tile[:,0,:3]=base*shade*.78
            tile[:1,:,:3]=base*shade*.67
        if kind=='shadow' and min(w,h)>11:
            # Inset panel edges echo the nested rectangular engraving in the reference.
            tile[2:4,2:w-2,:3]=base*.60; tile[h-4:h-2,2:w-2,:3]=base*1.19
            tile[2:h-2,2:4,:3]=base*1.12; tile[2:h-2,w-4:w-2,:3]=base*.60
        if kind=='plate' and min(w,h)>12:
            for yy in range(4,h-4,11):
                tile[yy:yy+2,2:4,:3]=np.array((133,161,150))/255
    elif kind=='cloth':
        # Broad red rectangular motifs, with darker hems and squared folds.
        tile[:,:,:3]=base
        if w>6 and h>5:
            tile[:,:,:3]*=.84
            tile[:,1:3,:3]=np.array((164,38,44))/255
            tile[:,w-3:w-1,:3]=np.array((69,20,30))/255
            tile[2:h-2,3:w-3,:3]=np.array((143,29,35))/255
            for yy in range(3,h-2,12):
                tile[yy:yy+2,3:w-3,:3]=np.array((85,22,31))/255
                tile[yy+4:min(yy+8,h-2),5:max(6,w-5),:3]=np.array((178,44,43))/255
    elif kind in ('ruby','red_light','ember','hot'):
        emission=tile[:,:,:3].copy()
        if kind=='ruby' and min(w,h)>7:
            tile[2:h-2,2:w-2,:3]=np.array((205,27,23))/255
            emission=tile[:,:,:3].copy()
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
mat=bpy.data.materials.new(NAME+'_Weathered_Iron_Ruby_Stoles'); mat.use_nodes=True
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
rig['status']='Static hollow armor entity: rigid shoulder, forearm, fist, crown, core, mantle and segmented cloth pivots.'

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
scene['description']='Three-meter suspended infernal relic, inspired by the user revenant: hollow ancient armor, oversized angled pauldrons, red core, heavy fists, three hanging crimson stoles and four floating mantle fragments.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
