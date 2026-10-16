"""New cubic Mana Devourer; run in the live Blender MCP, preserving every existing scene."""
import bpy
import bmesh
import math
import json
import hashlib
import struct
from pathlib import Path
from mathutils import Vector, Euler
import numpy as np

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
STEM = 'mana_devourer_blocky_v3'
NAME = 'Mana_Devourer_Blocky_V3'
OUT = ROOT / 'assets/generated/mana_devourers' / STEM
REVIEW = ROOT / 'art_source/mana_devourer_blocky_v3_review'
assert NAME not in bpy.data.scenes, 'Preserve existing source; do not rebuild over edits.'
OUT.mkdir(parents=True, exist_ok=True)
REVIEW.mkdir(parents=True, exist_ok=True)
(REVIEW / '.gdignore').write_text('')
old_scenes = set(bpy.data.scenes.keys())
old_dir = ROOT / 'assets/generated/mana_devourers/mana_devourer_v1'
old_hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in old_dir.rglob('*') if p.is_file()}
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
col = bpy.data.collections.new(NAME + '_Entity')
scene.collection.children.link(col)
studio = bpy.data.collections.new(NAME + '_Studio')
scene.collection.children.link(studio)
root = bpy.data.objects.new(NAME + '_ROOT', None)
col.objects.link(root)
root.empty_display_size = .18
parts, centers, islands, kinds = [], {}, [], {}

def box(label, center, size, bone, kind='stone'):
    c, s = Vector(center), Vector(size) * .5
    vertices = [c + Vector((x*s.x, y*s.y, z*s.z))
                for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                              (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me = bpy.data.meshes.new(NAME + '_' + label)
    me.from_pydata(vertices, [], faces)
    me.update()
    o = bpy.data.objects.new(me.name, me)
    col.objects.link(o)
    o['rig_bone'], o['kind'] = bone, kind
    o['primitive'] = 'closed cuboid; no bevel; flat faces'
    centers.setdefault(bone, c.copy())
    kinds[bone] = kind if bone.startswith(('intake','exhaust')) else 'body'
    parts.append(o)
    return o

def cluster(bone, specs):
    for i,(c,s) in enumerate(specs):
        box(bone + '_%02d' % i, c, s, bone)

# One luminous core and four raw rectilinear stones. The mana gives stone life;
# this is the natural phenomenon that inspired later constructed golems.
origin=Vector((0,0,1.04))
axis=Vector((0,-.6,.8))
u=Vector((1,0,0)); v=Vector((0,.8,.6))
RADIUS=.83
box('Mana_Energy_Core',origin,(.48,)*3,'core','core')
centers['orbit']=origin.copy()
def rock(index, angle, width, depth, height, notch):
    c=origin+RADIUS*(u*math.cos(angle)+v*math.sin(angle))
    # A squared missing corner in a single closed mesh, without extra pegs.
    x=width*.5; z=height*.5
    outline=[(-x,-z),(x,-z),(x,z-notch),(x-notch,z-notch),(x-notch,z),(-x,z)]
    verts=[c+Vector((xx,yy,zz)) for yy in (-depth*.5,depth*.5) for xx,zz in outline]
    n=len(outline)
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(NAME+'_Stone_%02d'%index); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(me.name,me); col.objects.link(o)
    bone='stone_%02d'%index
    o['rig_bone']=bone; o['kind']='stone'; o['primitive']='closed rectilinear stone; squared missing corner'
    centers[bone]=c; kinds[bone]='stone'; parts.append(o)
for i,(w,d,h,n) in enumerate([(.34,.30,.38,.085),(.28,.26,.30,.07),(.32,.28,.34,.08),(.26,.28,.29,.065)]):
    rock(i,math.radians(15+90*i),w,d,h,n)

# Per-face metric atlas, with two pixels of padding and deliberately restrained
# large pixel clusters; the silhouette carries the style instead of rock noise.
DENSITY, PAD = 64, 2
for o in parts:
    me=o.data
    me.uv_layers.new(name='Metric_Pixel_UV')
    for p in me.polygons:
        n=p.normal.normalized()
        up=Vector((0,0,1)) if abs(n.z)<.9 else Vector((0,1,0))
        right=up.cross(n).normalized()
        coords=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        lo=Vector((min(v.x for v in coords),min(v.y for v in coords)))
        coords=[v-lo for v in coords]
        islands.append(dict(obj=o,polygon=p.index,normal=n,coords=coords,
            w=max(1,math.ceil(max(v.x for v in coords)*DENSITY)),
            h=max(1,math.ceil(max(v.y for v in coords)*DENSITY))))
def pack(size):
    x=y=PAD; row=0
    for it in sorted(islands,key=lambda d:(-d['h'],-d['w'])):
        w,h=it['w']+2*PAD,it['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        it['x']=x+PAD; it['y']=y+PAD; x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (256,512,1024) if pack(s))
palette={'stone':(116,123,130),'core':(154,112,240)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1
energy=pixels.copy()
for j,it in enumerate(islands):
    w,h=it['w'],it['h']; kind=it['obj']['kind']; n=it['normal']
    tile=np.empty((h,w,4),dtype=np.float32); tile[:,:,3]=1
    base=np.array(palette[kind])/255
    tile[:,:,:3]=base
    if kind=='stone':
        base=base*(1.20 if n.z>.8 else .78 if n.z<-.8 else 1 if n.y<0 else .91)
        tile[:,:,:3]=base
        if min(w,h)>4:
            tile[-1,:,:3]=np.minimum(base*1.30,1)
            tile[:1,:,:3]=base*.72
            # Broad square patches, without realistic scratches or mottling.
            if j%4==0: tile[h//3:h//3+max(2,h//4),w//3:w//3+max(2,w//4),:3]=base*1.10
    if kind=='core':
        for yy in range(h):
            for xx in range(w):
                edge=min(xx,w-1-xx,yy,h-1-yy)
                color=(106,73,186) if edge<2 else (164,127,235) if edge<5 else (204,177,255)
                tile[yy,xx,:3]=np.array(color)/255
    elif kind=='stone' and (n.y<-.8 or n.z>.8):
        # Sparse blocky mineral texture, related to the game's stone golem.
        for yy in range(2,h-2,4):
            for xx in range(2,w-2,4):
                if (xx//4+yy//4+j)%4==0:
                    tile[yy:yy+2,xx:xx+2,:3]=base*.90
        if w>6 and h>6:
            x=w//2
            for yy in range(h//3,2*h//3):
                tile[yy,x,:3]=np.array((128,94,177))/255
    for yy in range(-PAD,h+PAD):
        for xx in range(-PAD,w+PAD):
            v=tile[min(h-1,max(0,yy)),min(w-1,max(0,xx))]
            pixels[it['y']+yy,it['x']+xx]=v
            if kind!='stone': energy[it['y']+yy,it['x']+xx]=v
            elif abs(v[0]-128/255)<.001 and abs(v[1]-94/255)<.001:
                energy[it['y']+yy,it['x']+xx]=np.array((128/255,94/255,177/255,1))*.45
                energy[it['y']+yy,it['x']+xx,3]=1
    uv=it['obj'].data.uv_layers.active.data
    for li,co in zip(it['obj'].data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+co.x*DENSITY)/SIZE,(it['y']+co.y*DENSITY)/SIZE)
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(data.reshape(-1))
    im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png')); im.file_format='PNG'; im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.new(NAME+'_Pixel_Obsidian_Mana'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.88
bsdf.inputs['Specular IOR Level'].default_value=.16
for im,socket in zip(images,['Base Color','Emission Color']):
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=im; node.interpolation='Closest'
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
bsdf.inputs['Emission Strength'].default_value=1.5
for o in parts: o.data.materials.append(mat)

arm=bpy.data.armatures.new(NAME+'_Skeleton')
rig=bpy.data.objects.new(NAME+'_Rig',arm); col.objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=arm.edit_bones.new('root'); b.head=(0,0,0); b.tail=(0,0,.15); b.use_deform=False
for name,c in centers.items():
    b=arm.edit_bones.new(name); b.head=c; b.tail=c+Vector((0,0,.10)); b.parent=arm.edit_bones['orbit'] if name.startswith('stone_') else arm.edit_bones['root']
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    o.parent=rig; o.modifiers.new('Rigid_Cuboids','ARMATURE').object=rig
rig.animation_data_create()
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
restq={b.name:b.matrix_local.to_quaternion() for b in arm.bones}
clips={}
previous={}
def pose(bone, delta=(0,0,0), rotation=None, scale=1):
    b=rig.pose.bones[bone]
    b.location=restq[bone].inverted()@Vector(delta)
    b.rotation_quaternion=(restq[bone].inverted()@rotation@restq[bone]) if rotation else (1,0,0,0)
    b.scale=(scale,)*3
def bake(frame):
    for b in rig.pose.bones:
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion)<0:
            b.rotation_quaternion.negate()
        previous[b.name]=b.rotation_quaternion.copy()
        for prop in ('location','rotation_quaternion','scale'):
            b.keyframe_insert(data_path=prop,frame=frame,group=b.name)
def smooth(t): return t*t*(3-2*t)
from mathutils import Quaternion
# Rotation of the common parent preserves orbital radius during Godot blends;
# the stones never interpolate on straight paths through the energy core.
for clip,end,start in [('Idle',385,1),('Walk',193,411),('Attack',37,631)]:
    action=bpy.data.actions.new(NAME+'_'+clip); action.use_fake_user=True
    rig.animation_data.action=action; previous.clear()
    for f in range(1,end+1):
        scene.frame_set(f); t=(f-1)/(end-1); p=math.tau*t
        for b in rig.pose.bones: pose(b.name)
        charge=burst=0
        if clip=='Attack':
            if t<.30: charge=smooth(t/.30)
            elif t<.48:
                q=smooth((t-.30)/.18); charge=1-q; burst=q
            else: burst=1-smooth((t-.48)/.52)
            angle=.40*math.sin(math.pi*t)**2
        else: angle=p
        hover=.012*math.sin(p)
        pose('core',(0,0,hover),Euler((.28+.04*math.sin(p),.18,angle),'XYZ').to_quaternion(),1-.025*charge+.07*burst)
        pose('orbit',(0,0,hover),Quaternion(axis,angle))
        for i in range(4):
            n='stone_%02d'%i
            radial=(centers[n]-origin).normalized()
            # Opposing motion stays slight; four stones remain four clear forms.
            delta=radial*(-.025*charge+.065*burst)
            q=Euler((.10*math.sin(p+i),.09*math.cos(p+i),.06*math.sin(p+i)), 'XYZ').to_quaternion()
            pose(n,delta,q)
        bake(f)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    action['loop']=clip!='Attack'
    clips['ManaDevourer_'+clip]=dict(action=action,end=end,start=start,loop=clip!='Attack')
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['start'],data['action'])
    strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(name,frame=data['start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=667; scene.frame_set(1)

def aim(o,t): o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.55; scene.world=world
for label,pos,power,color in [('Key',(-4,-5,7),1000,(.9,.94,1)),('Fill',(5,-2,4),650,(.85,.8,1)),('Rim',(0,4,6),1000,(.65,.92,1))]:
    data=bpy.data.lights.new(NAME+'_'+label,'AREA'); data.energy=power; data.size=5
    data.color=color; o=bpy.data.objects.new(data.name,data); studio.objects.link(o); o.location=pos; aim(o,(0,0,1))
me=bpy.data.meshes.new(NAME+'_GroundMesh'); me.from_pydata([(-200,-200,-.01),(200,-200,-.01),(200,200,-.01),(-200,200,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_StudioFloor',me); studio.objects.link(floor)
gm=bpy.data.materials.new(NAME+'_Floor'); gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.14,1)
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(gm)
data=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera)
data.type='ORTHO'; data.ortho_scale=2.45; camera.location=(3,-7,3.7); aim(camera,(0,0,1.03)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.cycles.device='GPU'
scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'
scene['description']='Slowly rotating energy cube animating four orbiting raw blocky stones; natural precursor of golem stone animation.'
scene['references']='Actual previews: ancient_golem_v2, troll_blocky_v3, previous mana_devourer_v1.'
state=dict(scene=scene,root=root,rig=rig,parts=parts,clips=clips,images=images,material=mat,
    studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),name=NAME,stem=STEM,
    old_scenes=list(old_scenes),old_hashes=old_hashes,atlas=SIZE)
bpy.app.driver_namespace['mana_devourer_blocky_v3']=state
(OUT/'previews').mkdir(exist_ok=True)
scene.render.filepath=str(OUT/'previews/three_quarter.png')
bpy.ops.render.render(write_still=True)
for o in parts: o.data.calc_loop_triangles()
result={'scene':NAME,'parts':len(parts),'bones':len(arm.bones),'triangles':sum(len(o.data.loop_triangles) for o in parts),'atlas':SIZE,
        'clips':list(clips),'scenes_before':len(old_scenes),'scenes_after':len(bpy.data.scenes)}
