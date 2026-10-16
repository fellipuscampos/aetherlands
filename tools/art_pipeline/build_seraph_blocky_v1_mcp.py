"""Static shared Sacred Grand Manifestation, authored in the live Blender MCP."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='seraph_blocky_v1'; NAME='Sacred_Seraph_Blocky_V1'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/seraph_blocky_v1_review'
assert NAME not in bpy.data.scenes,'Preserve an existing model instead of rebuilding over it.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb',
           ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.blend',
           ROOT/'scripts/data/UnitDatabase.gd']
old_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
col=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(col)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=bpy.data.objects.new(NAME+'_ROOT',None); col.objects.link(root); root.empty_display_size=.2
parts=[]; centers={'body':Vector((0,0,1.83)),'core':Vector((0,-.06,1.85)),
                  'halo':Vector((0,.08,2.78)),'tail':Vector((0,.04,1.00))}

def box(label,center,size,bone,kind='ivory',angle=0):
    c=Vector(center); s=Vector(size)*.5; R=Euler((0,angle,0),'XYZ').to_matrix()
    vertices=[c+R@Vector((x*s.x,y*s.y,z*s.z)) for x,y,z in
              [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(NAME+'_'+label); me.from_pydata(vertices,[],faces); me.update()
    o=bpy.data.objects.new(me.name,me); col.objects.link(o)
    o['rig_bone']=bone; o['kind']=kind; o['local_rotation']=[0,angle,0]
    o['primitive']='closed cuboid; sharp edges; flat faces'
    parts.append(o); return o

def diamond(label,c,half,thickness,depth,bone,kind='gold'):
    x,y,z=c
    for i,(sx,sz,ang) in enumerate([(1,1,-45),(-1,1,45),(1,-1,45),(-1,-1,-45)]):
        box(label+'_%02d'%i,(x+sx*half*.5,y,z+sz*half*.5),
            (thickness,depth,half*math.sqrt(2)),bone,kind,math.radians(ang))

# The center is an open golden reliquary carrying sacred light, rather than
# a humanoid torso. No head, face, arms, hands, legs, feet, skin or weapon.
diamond('Reliquary_Outer',(0,.025,1.85),.43,.13,.25,'body')
diamond('Reliquary_Inlay',(0,-.112,1.85),.325,.047,.025,'body','bright_gold')
box('Sacred_Light_Core',(0,-.055,1.85),(.255,.25,.39),'core','light',math.radians(45))
box('Core_Light_Spine',(0,.10,1.85),(.115,.09,.76),'core','light')
box('Reliquary_Lower_Keystone',(0,.035,1.36),(.22,.22,.20),'body','gold',math.radians(45))

# One angular floating aureole with four small rays: read as a sacred crown
# of light, with actual negative space, rather than a round ring or head.
diamond('Aureole',(0,.08,2.78),.335,.075,.085,'halo','bright_gold')
for i,(c,s) in enumerate([((0,.08,3.16),(.068,.09,.16)),
    ((.385,.08,2.78),(.13,.09,.065)),((-.385,.08,2.78),(.13,.09,.065)),
    ((0,.08,2.40),(.068,.09,.11))]):
    box('Aureole_Ray_%02d'%i,c,s,'halo','gold')

# A tapering light train below the reliquary gives vertical presence without
# a robe around a body, a pelvis, legs or a humanoid stance.
for i,(c,s,k) in enumerate([
    ((0,.04,1.08),(.16,.16,.32),'ivory'),((0,.05,.70),(.115,.12,.24),'light'),
    ((0,.05,.38),(.065,.09,.20),'light'),
    ((-.18,.045,.92),(.095,.12,.40),'ivory'),((.18,.045,.92),(.095,.12,.40),'ivory'),
]): box('Light_Train_%02d'%i,c,s,'tail',k)

def wing(label,sign,root_position,rib_angle,rib_length,feather_angle,lengths):
    bone='wing_'+label+('_R' if sign>0 else '_L')
    p=Vector((root_position[0]*sign,root_position[1],root_position[2])); centers[bone]=p.copy()
    a=math.radians(rib_angle); d=Vector((sign*math.cos(a),0,math.sin(a)))
    fa=math.radians(feather_angle); fd=Vector((sign*math.cos(fa),0,math.sin(fa)))
    rib_rot=sign*(math.pi*.5-a); feather_rot=sign*(math.pi*.5-fa)
    box(bone+'_Gold_Rib',p+d*rib_length*.5,(.09,.14,rib_length),bone,'gold',rib_rot)
    box(bone+'_Root_Cap',p+d*.055,(.20,.18,.21),bone,'bright_gold',rib_rot)
    for i,length in enumerate(lengths):
        distance=.10+i*(rib_length-.16)/(len(lengths)-1)
        start=p+d*distance
        start.y-=.014*i
        # Each feather is a broad sharp-ended rectangular volume. The fan's
        # changing lengths form the stepped voxel outline.
        box(bone+'_Feather_%02d'%i,start+fd*(length*.5),
            (.177,.085,length),bone,'feather',feather_rot)
    for i in range(3):
        start=p+d*(.12+i*.205); start.y-=.075
        box(bone+'_Covert_%02d'%i,start+fd*.115,(.185,.055,.24),bone,'ivory',feather_rot)

for sign in (-1,1):
    wing('upper',sign,(.32,.22,2.06),52,.91,-8,[.31,.45,.61,.72,.62])
    wing('middle',sign,(.43,.34,1.75),12,1.01,-61,[.30,.45,.59,.72,.58])
    wing('lower',sign,(.33,.075,1.48),-34,.77,-107,[.40,.56,.69,.77,.66])

# Sweep the three pairs into different depth planes. This remains a static
# rest shape, with each sharp cuboid and its future wing pivot kept rigid.
for o in parts:
    bone=o['rig_bone']
    if not bone.startswith('wing_'): continue
    band,side=bone.split('_')[1:]
    angle=math.radians({'upper':24,'middle':-18,'lower':32}[band])*(1 if side=='R' else -1)
    R=Matrix.Rotation(angle,3,'Z'); pivot=centers[bone]
    for v in o.data.vertices: v.co=pivot+R@(v.co-pivot)
    o['local_rotation']=list((R@Euler(o['local_rotation'],'XYZ').to_matrix()).to_euler('XYZ'))
    o.data.update()

# Apply exact native game dimensions to the geometry and the prepared pivots.
# 3.00 m from lowest light tip to highest halo ray; ground origin at (0,0,0).
coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+.22))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}

# A metric pixel atlas: all materials remain coherent with the game's sacred
# clerics (ivory + gold), shared across civilizations, with warm school light.
DENSITY=64; PAD=2; islands=[]
for o in parts:
    me=o.data; me.uv_layers.new(name='Metric_Pixel_UV')
    R=Euler(o['local_rotation'],'XYZ').to_matrix()
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
palette={'ivory':(230,225,200),'feather':(238,237,225),'gold':(193,141,52),
         'bright_gold':(240,205,111),'light':(250,225,155)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1
energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; kind=it['obj']['kind']; n=it['normal']
    base=np.array(palette[kind])/255
    tile=np.empty((h,w,4),dtype=np.float32); tile[:,:,3]=1; tile[:,:,:3]=base
    if kind!='light':
        # Discrete directional bands, with no smooth bevel or organic noise.
        shade=1.04 if n.z>.8 else .87 if n.z<-.8 else 1 if n.y<0 else .95
        tile[:,:,:3]=base*shade
        if min(w,h)>3:
            tile[:1,:,:3]=base*.78
            tile[-1:,:,:3]=np.minimum(base*1.07,1)
            tile[:,0,:3]=base*.90
        if kind=='feather' and w>5 and h>8 and abs(n.y)>.8:
            tile[2:h-2,w//2:w//2+1,:3]=np.array((206,208,194))/255
            for yy in range(4,h-3,7):
                xx=1 if (yy//7+index)%2 else max(1,w-4)
                tile[yy:yy+2,xx:xx+2,:3]=base*.96
        elif kind in ('gold','bright_gold') and w>5 and h>6:
            tile[2:h-2,1:2,:3]=np.minimum(base*1.19,1)
            if w>9: tile[2:h-2,w-3:w-2,:3]=base*.75
    else:
        if min(w,h)>5:
            tile[2:h-2,2:w-2,:3]=np.array((255,242,202))/255
    for yy in range(-PAD,h+PAD):
        for xx in range(-PAD,w+PAD):
            color=tile[min(h-1,max(0,yy)),min(w-1,max(0,xx))]
            pixels[it['y']+yy,it['x']+xx]=color
            if kind=='light': energy[it['y']+yy,it['x']+xx]=color
    uv=it['obj'].data.uv_layers.active.data
    for li,c in zip(it['obj'].data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(data.reshape(-1))
    im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png')); im.file_format='PNG'; im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.new(NAME+'_Sacred_Ivory_Gold'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.78
bsdf.inputs['Specular IOR Level'].default_value=.2
for im,socket in zip(images,['Base Color','Emission Color']):
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=im; node.interpolation='Closest'
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
bsdf.inputs['Emission Strength'].default_value=1.15
for o in parts: o.data.materials.append(mat)

# Prepared rigid pivots only; no actions, keyframes, NLA or animation exports.
arm=bpy.data.armatures.new(NAME+'_Prepared_Skeleton')
rig=bpy.data.objects.new(NAME+'_Rig',arm); col.objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=arm.edit_bones.new('root'); b.head=(0,0,0); b.tail=(0,0,.20); b.use_deform=False
for n,c in centers.items():
    b=arm.edit_bones.new(n); b.head=c; b.tail=c+Vector((0,0,.15))
    b.parent=arm.edit_bones['root'] if n=='body' else arm.edit_bones['body']
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    o.parent=rig; o.modifiers.new('Prepared_Rigid_Pivots','ARMATURE').object=rig
rig['status']='Static model only. Editable pivots prepared for a later animation stage.'

def aim(o,p): o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45; scene.world=world
for label,pos,power,color in [('Key',(-4,-6,8),1150,(1,.96,.88)),('Fill',(5,-2,5),700,(.8,.88,1)),('Rim',(0,5,7),1000,(1,.91,.70))]:
    data=bpy.data.lights.new(NAME+'_'+label,'AREA'); data.energy=power; data.size=5; data.color=color
    o=bpy.data.objects.new(data.name,data); studio.objects.link(o); o.location=pos; aim(o,(0,0,1.7))
me=bpy.data.meshes.new(NAME+'_StudioFloorMesh'); me.from_pydata([(-200,-200,-.01),(200,-200,-.01),(200,200,-.01),(-200,200,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_StudioFloor',me); studio.objects.link(floor)
gm=bpy.data.materials.new(NAME+'_Floor'); gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.10,.12,.15,1)
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(gm)
data=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera)
data.type='ORTHO'; data.ortho_scale=4.4; camera.location=(4,-10,5.2); aim(camera,(0,0,1.72)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Serafim: shared Sacred Grand Manifestation. Six stepped ivory wings, floating golden aureole/reliquary, warm sacred core; non-humanoid; exactly 3m tall.'
scene['stage']='MODEL ONLY; no animations or gameplay changes.'
bpy.app.driver_namespace['seraph_blocky_v1']=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,
    parts=parts,images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,
    out=str(OUT),review=str(REVIEW),old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':len(parts)*12,'height_m':3.0,'wing_pairs':3,
    'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
