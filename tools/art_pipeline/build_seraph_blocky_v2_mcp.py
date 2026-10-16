"""Rebuild the Sacred Seraph as a volumetric, layered, voxel winged eye."""
import bpy, bmesh, math, json, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Euler, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='seraph_blocky_v2'; NAME='Sacred_Seraph_Blocky_V2'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/seraph_blocky_v2_review'
assert NAME not in bpy.data.scenes, 'Do not replace an existing source scene.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb',
           ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.blend',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v1/seraph_blocky_v1.glb',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v1/seraph_blocky_v1.blend',
           ROOT/'scripts/data/UnitDatabase.gd']
old_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
col=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(col)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=bpy.data.objects.new(NAME+'_ROOT',None); col.objects.link(root); root.empty_display_size=.2
parts=[]
centers={'body':Vector((0,0,1.75)), 'core':Vector((0,-.36,1.82)),
         'orbit_a':Vector((0,.20,1.82)), 'orbit_b':Vector((0,.06,1.48))}

def mesh_part(label,vertices,faces,bone,kind,R=None):
    R=R if R is not None else Matrix.Identity(3)
    me=bpy.data.meshes.new(NAME+'_'+label)
    me.from_pydata(vertices,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    o=bpy.data.objects.new(me.name,me); col.objects.link(o)
    o['rig_bone']=bone; o['kind']=kind; o['local_rotation']=list(R.to_euler('XYZ'))
    o['primitive']='closed sharp-edged stepped prism; flat shading'
    parts.append(o); return o

def box(label,center,size,bone,kind='ivory',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); s=Vector(size)*.5
    vertices=[c+R@Vector((x*s.x,y*s.y,z*s.z)) for x,y,z in
        [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh_part(label,vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,kind,R)

def prism(label,profile,depth,center,bone,kind='ivory',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); n=len(profile)
    vertices=[c+R@Vector((x,y,z)) for y in (-depth/2,depth/2) for x,z in profile]
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    faces.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vertices,faces,bone,kind,R)

def octagon_ring(label,radius,thickness,depth,center,bone,R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center)
    # A single watertight annulus avoids the overlapping bars of the old model.
    vertices=[]
    for y in (-depth/2,depth/2):
        for r in (radius,radius-thickness):
            for i in range(8):
                a=math.radians(22.5+i*45)
                vertices.append(c+R@Vector((r*math.cos(a),y,r*math.sin(a))))
    faces=[]
    for i in range(8):
        j=(i+1)%8
        faces.extend([(i,j,8+j,8+i),(16+i,24+i,24+j,16+j),
                      (i,16+i,16+j,j),(8+i,8+j,24+j,24+i)])
    return mesh_part(label,vertices,faces,bone,'gold',R)

# The single luminous eye is the focal point, housed in a thick, stepped
# reliquary. The dark recess provides contrast instead of overexposing it.
eye=[(-.62,-.10),(-.45,-.10),(-.45,-.22),(-.22,-.22),(-.22,-.31),
     (.22,-.31),(.22,-.22),(.45,-.22),(.45,-.10),(.62,-.10),
     (.62,.10),(.45,.10),(.45,.22),(.22,.22),(.22,.31),
     (-.22,.31),(-.22,.22),(-.45,.22),(-.45,.10),(-.62,.10)]
prism('Eye_Reliquary_Gold',eye,.40,(0,.015,1.82),'body','gold')
prism('Eye_Ivory_Rim',[(x*.85,z*.85) for x,z in eye],.11,(0,-.24,1.82),'body','ivory')
prism('Eye_Shadow_Recess',[(x*.72,z*.65) for x,z in eye],.045,(0,-.318,1.82),'body','void')
prism('Eye_Luminous_Iris',[(-.12,-.10),(-.075,-.10),(-.075,-.21),(.075,-.21),
    (.075,-.10),(.12,-.10),(.12,.10),(.075,.10),(.075,.21),(-.075,.21),(-.075,.10),(-.12,.10)],
    .08,(0,-.37,1.82),'core','light')
box('Eye_Gold_Pupil',(0,-.421,1.82),(.047,.025,.23),'core','bright_gold')
box('Eye_Light_Catch',(-.055,-.42,1.94),(.045,.035,.055),'core','light')

# A solid rear seed and a compact downward taper give volume in profile,
# with no anatomical body or dangling rectangular sticks.
rear=[(-.33,-.23),(-.44,-.10),(-.44,.10),(-.33,.23),(.33,.23),(.44,.10),(.44,-.10),(.33,-.23)]
prism('Reliquary_Rear_Seed',rear,.35,(0,.28,1.82),'body','ivory')
pendant=[(-.27,.24),(.27,.24),(.27,.07),(.18,.07),(.18,-.18),(.09,-.18),(.09,-.39),(0,-.50),(-.09,-.39),(-.09,-.18),(-.18,-.18),(-.18,.07),(-.27,.07)]
prism('Reliquary_Pendant',pendant,.27,(0,.02,1.23),'body','gold')
prism('Pendant_Light_Inlay',[(x*.53,z*.79) for x,z in pendant],.045,(0,-.14,1.25),'core','light')

# Two clean, angular orbital structures frame the eye in different planes.
octagon_ring('Vertical_Aureole',.71,.065,.08,(0,.25,1.84),'orbit_a',Euler((0,math.radians(10),0)).to_matrix())
octagon_ring('Equatorial_Orbit',.65,.052,.075,(0,.06,1.48),'orbit_b',Euler((math.radians(76),0,math.radians(12))).to_matrix())
prism('Crown_Sigil',[(-.10,0),(.10,0),(.10,.14),(.05,.14),(.05,.30),(0,.38),(-.05,.30),(-.05,.14),(-.10,.14)],
      .12,(0,.25,2.45),'orbit_a','bright_gold')

def feather(label,start,length,width,angle,bone,kind='feather',depth=.085,yaw=0):
    # A fused stepped outline with a narrow tip, rather than a long cuboid.
    profile=[(-.32*width,0),(.32*width,0),(.32*width,.18*length),(.50*width,.18*length),
        (.50*width,.68*length),(.30*width,.68*length),(.30*width,.88*length),(.12*width,.88*length),
        (.12*width,length),(-.12*width,length),(-.12*width,.88*length),(-.30*width,.88*length),
        (-.30*width,.68*length),(-.50*width,.68*length),(-.50*width,.18*length),(-.32*width,.18*length)]
    R=Euler((0,math.radians(90-angle),math.radians(yaw)),'XYZ').to_matrix()
    return prism(label,profile,depth,start,bone,kind,R)

def make_wing(band,sign,root_position,spine,pinions,coverts,yaw):
    bone='wing_'+band+('_R' if sign>0 else '_L')
    pivot=Vector((sign*root_position[0],root_position[1],root_position[2])); centers[bone]=pivot.copy()
    begin=len(parts)
    # Broad feather bed behind the two overlapping rows; no exposed shelf beam.
    profile=[(sign*x,z) for x,z in spine]
    prism(bone+'_Feather_Bed',profile,.16,(0,root_position[1]+.10,0),bone,'ivory')
    for i,(x,z,length,width,angle) in enumerate(pinions):
        # Roots alternate slightly in depth; the clean tapered ends remain legible.
        feather(bone+'_Flight_%02d'%i,(sign*x,root_position[1]-.014*i,z),length,width,
                angle if sign>0 else 180-angle,bone,depth=.10)
    for i,(x,z,length,width,angle) in enumerate(coverts):
        feather(bone+'_Covert_%02d'%i,(sign*x,root_position[1]-.15-.018*i,z),length,width,
                angle if sign>0 else 180-angle,bone,'ivory',depth=.08)
    R=Euler((0,0,math.radians(sign*yaw))).to_matrix()
    for o in parts[begin:]:
        for v in o.data.vertices: v.co=pivot+R@(v.co-pivot)
        o['local_rotation']=list((R@Euler(o['local_rotation'],'XYZ').to_matrix()).to_euler('XYZ'))
        o.data.update()
    box(bone+'_Gold_Root',pivot,(.22,.24,.24),bone,'gold',Euler((0,math.radians(sign*25),0)).to_matrix())
    box(bone+'_Root_Inlay',pivot+Vector((0,-.135,0)),(.105,.035,.105),bone,'bright_gold')

for sign in (-1,1):
    # Dominant upper pair: rising, long primary pinions, broad stepped mass.
    make_wing('main',sign,(.46,.15,1.97),
        [(.34,1.86),(.42,2.16),(.73,2.36),(1.13,2.45),(1.33,2.33),(1.00,2.06),(.62,1.85)],
        [(.58,2.05,.59,.24,86),(.75,2.12,.76,.25,75),(.92,2.19,.92,.27,64),
         (1.08,2.26,1.04,.27,52),(1.21,2.32,1.05,.25,39),(1.28,2.33,.94,.23,25),(1.30,2.30,.72,.22,10)],
        [(.49,2.03,.38,.25,78),(.68,2.09,.48,.27,62),(.87,2.16,.53,.28,48),
         (1.05,2.20,.50,.26,34),(1.17,2.23,.42,.24,18)],22)
    # Supporting lower pair: curled down and outward, smaller than the main pair.
    make_wing('lower',sign,(.45,.03,1.54),
        [(.33,1.54),(.50,1.63),(.82,1.42),(1.13,1.09),(1.11,.88),(.77,1.01),(.49,1.23)],
        [(.50,1.40,.66,.23,-78),(.66,1.33,.79,.24,-63),(.82,1.24,.84,.25,-49),
         (.96,1.14,.84,.24,-33),(1.04,1.08,.70,.23,-15),(1.03,1.13,.54,.21,2)],
        [(.46,1.42,.40,.24,-71),(.63,1.33,.48,.26,-51),(.78,1.25,.49,.27,-32),(.91,1.17,.42,.24,-13)],-28)
    # Rear crown pair: compact and folded, surrounding the aureole in depth.
    make_wing('crown',sign,(.25,.43,2.02),
        [(.15,2.00),(.22,2.24),(.40,2.47),(.70,2.57),(.77,2.43),(.53,2.15)],
        [(.26,2.18,.54,.21,98),(.38,2.26,.66,.22,86),(.49,2.33,.68,.22,73),
         (.59,2.39,.60,.21,58),(.67,2.44,.43,.19,42)],
        [(.23,2.20,.31,.21,92),(.37,2.27,.37,.23,72),(.50,2.34,.33,.22,51)],48)

# Exact game height, with a floating origin on the terrain plane.
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
         'bright_gold':(240,205,111),'light':(249,225,160),'void':(42,39,36)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1
energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; kind=it['obj']['kind']; n=it['normal']
    base=np.array(palette[kind])/255
    tile=np.empty((h,w,4),dtype=np.float32); tile[:,:,3]=1; tile[:,:,:3]=base
    if kind not in ('light','void'):
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
    elif kind=='light':
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
bsdf.inputs['Emission Strength'].default_value=.75
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
for label,pos,power,color in [('Key',(-4,-6,8),850,(1,.96,.88)),('Fill',(5,-2,5),500,(.8,.88,1)),('Rim',(0,5,7),750,(1,.91,.70))]:
    data=bpy.data.lights.new(NAME+'_'+label,'AREA'); data.energy=power; data.size=5; data.color=color
    o=bpy.data.objects.new(data.name,data); studio.objects.link(o); o.location=pos; aim(o,(0,0,1.7))
me=bpy.data.meshes.new(NAME+'_StudioFloorMesh'); me.from_pydata([(-200,-200,-.01),(200,-200,-.01),(200,200,-.01),(-200,200,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_StudioFloor',me); studio.objects.link(floor)
gm=bpy.data.materials.new(NAME+'_Floor'); gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.10,.12,.15,1)
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(gm)
data=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera)
data.type='ORTHO'; data.ortho_scale=5.6; camera.location=(3,-10,4.2); aim(camera,(0,0,1.72)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Serafim V2: sacred winged eye; six tapered stepped wings with overlapping rows, two volumetric gold orbits, a single luminous eye in a thick reliquary; exactly 3m.'
scene['stage']='MODEL ONLY; no animations or gameplay changes.'
bpy.app.driver_namespace['seraph_blocky_v2']=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,
    parts=parts,images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,
    out=str(OUT),review=str(REVIEW),old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),'height_m':3.0,'wing_pairs':3,
    'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
