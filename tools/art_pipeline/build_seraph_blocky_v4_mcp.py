"""Change only the wings to the user-provided blocky feather reference."""
import bpy, bmesh, math, json, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Euler, Matrix, Quaternion

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='seraph_blocky_v4'; NAME='Sacred_Seraph_Blocky_V4'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/seraph_blocky_v4_review'
assert NAME not in bpy.data.scenes, 'Do not replace an existing source scene.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb',
           ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.blend',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v1/seraph_blocky_v1.glb',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v1/seraph_blocky_v1.blend',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v2/seraph_blocky_v2.glb',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v2/seraph_blocky_v2.blend',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v3/seraph_blocky_v3.glb',
           ROOT/'assets/generated/grand_manifestations/seraph_blocky_v3/seraph_blocky_v3.blend',
           ROOT/'scripts/data/UnitDatabase.gd']
old_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
col=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(col)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=bpy.data.objects.new(NAME+'_ROOT',None); col.objects.link(root); root.empty_display_size=.2
parts=[]
centers={'body':Vector((0,0,1.75)), 'core':Vector((0,-.92,1.82)),
         'orbit_a':Vector((0,-.92,1.82)), 'orbit_b':Vector((0,-.92,1.82))}

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

# A free energy cube, with fine gold edges that keep all six faces readable.
core_center=Vector((0,-.92,1.82))
core_R=Euler(tuple(math.radians(a) for a in (25,32,14))).to_matrix()
box('Sacred_Energy_Cube',core_center,(.46,)*3,'core','light',core_R)
for axis in range(3):
    others=[i for i in range(3) if i!=axis]
    for sa in (-1,1):
        for sb in (-1,1):
            c=Vector((0,0,0)); c[others[0]]=sa*.233; c[others[1]]=sb*.233
            size=[.014]*3; size[axis]=.48
            box('Core_Gold_Edge_%d_%d_%d'%(axis,sa,sb),core_center+core_R@c,size,'core','bright_gold',core_R)

# Nine cubes behind the core support the existing six wings. The three
# central blocks complete the cluster; the other six are their wing roots.
box('Rear_Cube_Central',(0,.24,1.82),(.44,)*3,'body','ivory',Euler((0,.18,0)).to_matrix())
box('Rear_Cube_Crown',(0,.43,2.12),(.28,)*3,'body','gold',Euler((0,-.22,.13)).to_matrix())
box('Rear_Cube_Lower',(0,.20,1.40),(.30,)*3,'body','ivory',Euler((0,.24,-.12)).to_matrix())

# Concentric radial shells give the two angular aureoles clearance under
# arbitrary rotation, with a common pivot at the energy cube's center.
octagon_ring('Inner_Aureole',.62,.042,.055,core_center,'orbit_a',Euler((math.radians(8),math.radians(16),math.radians(12))).to_matrix())
octagon_ring('Outer_Aureole',.80,.042,.055,core_center,'orbit_b',Euler((math.radians(72),math.radians(15),math.radians(-12))).to_matrix())
# The user's wing reference: a broad continuous feather mass with long,
# nearly parallel primaries only separated at the stepped, jagged outer edge.
# Each wing is a single closed prism, rather than a radial stack of paddles.
def reference_outline():
    # Trace the broad upper-right wing in the supplied reference. The wing
    # body occupies most of its span; only the terminal primaries separate.
    # Irregular stepped cuts follow the image, rather than an evenly spaced comb.
    pixels=[(338,221),(343,204),(355,196),(373,169),(387,145),(419,127),
        (450,117),(490,107),(529,102),(570,103),(575,110),(610,106),
        (616,110),(646,108),(650,114),(675,113),(682,119),(702,123),
        (726,132),(726,140),(679,148),(646,145),(626,141),(622,137),
        (606,139),(620,154),(648,160),(676,168),(697,175),(694,185),
        (662,189),(638,179),(609,182),(603,177),(580,183),(605,197),
        (628,207),(654,212),(653,220),(627,224),(607,218),(591,224),
        (579,215),(557,223),(575,232),(592,241),(588,250),(555,254),
        (536,246),(526,252),(511,245),(503,257),(510,264),(504,272),
        (485,272),(478,265),(464,275),(448,287),(442,302),(427,295),
        (416,305),(404,294),(390,299),(383,284),(368,283),(368,262),
        (351,248),(343,230)]
    return [((x-338)/194,(221-y)/194) for x,y in pixels]

# Retain the exact approved core, supporting cubes, bone pivots and scale.
old=bpy.app.driver_namespace['seraph_blocky_v3']
factor=old['rig'].data.bones['core'].head_local.y/-.92
zoffset=old['rig'].data.bones['body'].head_local.z-1.75*factor
def normalized(v): return Vector((v.x*factor,v.y*factor,v.z*factor+zoffset))
wing_panels=[]
for band,root_position,scale,angle,yaw in [
    ('main',(.46,.15,1.97),1.00,13,18),
    ('lower',(.45,.03,1.54),.80,-45,-22),
    ('crown',(.25,.43,2.02),.54,68,52),
]:
    for sign in (-1,1):
        bone='wing_'+band+('_R' if sign>0 else '_L')
        pivot=Vector((sign*root_position[0],root_position[1],root_position[2])); centers[bone]=pivot.copy()
        pitch=Matrix.Rotation(-sign*math.radians(angle),3,'Y')
        sweep=Matrix.Rotation(sign*math.radians(yaw),3,'Z')
        R=sweep@pitch
        profile=[(sign*x*scale,z*scale) for x,z in reference_outline()]
        o=prism(bone+'_Reference_Feather_Mass',profile,.11 if band!='crown' else .085,
                pivot,bone,'wing_feather',R)
        o['wing_band']=band; wing_panels.append(o)
        box(bone+'_Rear_Cube_Root',pivot,(.30,.30,.30),bone,'gold',Euler((0,math.radians(sign*25),0)).to_matrix())
        box(bone+'_Root_Inlay',pivot+Vector((0,-.168,0)),(.105,.028,.105),bone,'bright_gold')
for o in parts:
    for v in o.data.vertices: v.co=normalized(v.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}
# Fit only the wing panels to the existing 3m silhouette. All approved center
# geometry and pivots retain their exact positions; roots stay on their cubes.
for o in wing_panels:
    pivot=centers[o['rig_bone']]
    if o['wing_band']=='lower':
        extent=min(v.co.z for v in o.data.vertices)-pivot.z
        stretch=(.22-pivot.z)/extent
    elif o['wing_band']=='crown':
        extent=max(v.co.z for v in o.data.vertices)-pivot.z
        stretch=(3.22-pivot.z)/extent
    else:
        stretch=1.0
    for v in o.data.vertices: v.co.z=pivot.z+(v.co.z-pivot.z)*stretch
    o.data.update()

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
         'bright_gold':(240,205,111),'light':(249,225,160),'void':(42,39,36),'wing_feather':(223,220,204)}
reference_image=bpy.data.images.load(str(OUT/'wing_reference_texture.png'),check_existing=False)
reference_image.colorspace_settings.name='Non-Color'
rw,rh=reference_image.size
reference_full=np.empty(rw*rh*4,dtype=np.float32)
reference_image.pixels.foreach_get(reference_full)
reference_full=reference_full.reshape(rh,rw,4)
rx=np.minimum(rw-1,((np.arange(64)+.5)*rw/64).astype(int))
ry=np.minimum(rh-1,((np.arange(64)+.5)*rh/64).astype(int))
reference_pixels=reference_full[ry[:,None],rx[None,:]]
bpy.data.images.remove(reference_image)
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
        if kind=='wing_feather':
            yy,xx=np.indices((h,w))
            if abs(n.y)>.60:
                # Sample the image-generated material made directly from the
                # user's reference: irregular ivory / grey / taupe pixel patches.
                poly=it['obj'].data.polygons[it['polygon']]
                R=Euler(it['obj']['local_rotation'],'XYZ').to_matrix()
                world_normal=poly.normal.normalized()
                up=R@Vector((0,0,1)); up-=world_normal*up.dot(world_normal); up.normalize()
                right=up.cross(world_normal).normalized()
                sign=1 if it['obj']['rig_bone'].endswith('_R') else -1
                u=xx if right.dot(R@Vector((sign,0,0)))>0 else w-1-xx
                band={'main':0,'lower':13,'crown':29}[it['obj']['wing_band']]
                sx=(u//3+band)%64; sy=(yy//3+band//2)%64
                tile[:,:,:3]=reference_pixels[sy,sx,:3]*shade
            else:
                tile[:,:,:3]=base*(.88 if n.z<0 else .98)
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
# Only the slow core/aureole study requested for this design revision.
# Wings and supporting cubes remain fixed; no locomotion, healing or combat.
rig.animation_data_create()
action=bpy.data.actions.new('Seraph_CoreOrbit'); action.use_fake_user=True
rig.animation_data.action=action
axes={'core':Vector((.18,.22,1)).normalized(), 'orbit_a':Vector((.9,.22,.28)).normalized(),
      'orbit_b':Vector((.16,.06,1)).normalized()}
restq={n:arm.bones[n].matrix_local.to_quaternion() for n in axes}
previous={}
END=577
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
for f in range(1,END+1):
    phase=math.tau*(f-1)/(END-1)
    for name,axis in axes.items():
        q=Quaternion(axis,phase*(-1 if name=='orbit_b' else 1))
        q=restq[name].inverted()@q@restq[name]
        if name in previous and previous[name].dot(q)<0: q.negate()
        previous[name]=q.copy()
        b=rig.pose.bones[name]; b.rotation_quaternion=q
        b.keyframe_insert(data_path='rotation_quaternion',frame=f,group=name)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                for key in fc.keyframe_points: key.interpolation='LINEAR'
action['loop']=True; action['description']='24 second slow cube and aureole rotation study.'
rig.animation_data.action=None
track=rig.animation_data.nla_tracks.new(); track.name='Seraph_CoreOrbit'
strip=track.strips.new('Seraph_CoreOrbit',1,action); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
rig['status']='Model revision plus the requested core/orbit rotation study. Wings are static.'


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
data.type='ORTHO'; data.ortho_scale=6.4; camera.location=(3,-10,4.2); aim(camera,(0,0,1.72)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.render.fps=24; scene.frame_start=1; scene.frame_end=END; scene.frame_set(1)
scene['description']='Serafim V4: wings rebuilt from the supplied Minecraft angel reference; six continuous stepped feather masses with jagged parallel tips and pixel ivory/taupe feather texture. Approved core, rear cubes and orbit motion preserved.'
scene['stage']='MODEL REVISION + CORE/ORBIT ROTATION STUDY; no gameplay changes.'
bpy.app.driver_namespace['seraph_blocky_v4']=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,
    parts=parts,images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,
    out=str(OUT),review=str(REVIEW),old_scenes=list(old_scenes),old_hashes=old_hashes,rotation_action=action,rotation_frames=END,rotation_seconds=24)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),'height_m':3.0,'wing_pairs':3,
    'prepared_bones':len(arm.bones),'animations':1,'atlas':SIZE,'previous_scenes':len(old_scenes)}
