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
STEM = 'mana_devourer_blocky_v2'
NAME = 'Mana_Devourer_Blocky_V2'
OUT = ROOT / 'assets/generated/mana_devourers' / STEM
REVIEW = ROOT / 'art_source/mana_devourer_blocky_v2_review'
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

# Interlocked, disconnected orthogonal masses. The center is genuinely empty:
# no hidden sphere, face, painted slit, complete portal ring or anatomical limbs.
cluster('crown_west', [((-.30,.03,1.49),(.48,.42,.30)),
    ((-.46,.03,1.70),(.28,.32,.12)), ((-.12,.17,1.67),(.16,.28,.18)),
    ((-.36,-.27,1.51),(.20,.16,.18)), ((-.60,.02,1.49),(.10,.24,.18))])
cluster('west_fold', [((-.47,.01,1.12),(.24,.50,.38)),
    ((-.62,.14,1.19),(.10,.26,.20)), ((-.43,-.31,1.04),(.16,.12,.18)),
    ((-.49,.32,1.02),(.18,.12,.18))])
cluster('lower_fold', [((-.20,-.03,.68),(.54,.44,.24)),
    ((-.32,.12,.47),(.28,.28,.14)), ((-.39,-.18,.51),(.12,.18,.16)),
    ((.12,-.10,.69),(.10,.30,.14)), ((-.03,.23,.72),(.18,.12,.14))])
cluster('east_fold', [((.34,.13,1.01),(.26,.46,.34)),
    ((.49,.23,1.07),(.12,.26,.18)), ((.30,-.18,.94),(.16,.12,.18)),
    ((.40,.40,.95),(.14,.12,.14))])
cluster('crown_east', [((.32,.20,1.46),(.40,.38,.22)),
    ((.46,.32,1.65),(.18,.18,.16)), ((.10,.34,1.51),(.14,.18,.16)),
    ((.46,-.05,1.48),(.16,.12,.16))])
# A receding broken corner in a perpendicular plane makes the void readable
# from the game's elevated camera as well as from the front.
cluster('rear_fold', [((-.04,.38,1.33),(.28,.16,.18)),
    ((.06,.40,1.14),(.12,.16,.14)), ((-.19,.39,1.45),(.14,.14,.12))])
cluster('satellite_west', [((-.73,-.04,.82),(.20,.22,.24)),
    ((-.75,.01,1.00),(.12,.14,.08)), ((-.85,-.03,.83),(.04,.14,.12))])
cluster('satellite_east', [((.70,.10,1.30),(.22,.22,.28)),
    ((.79,.15,1.48),(.12,.12,.08)), ((.72,-.05,1.34),(.12,.06,.14))])
cluster('satellite_below', [((.28,-.08,.36),(.16,.18,.18)),
    ((.31,-.10,.23),(.10,.10,.06))])

# Inset luminous seams are cuboids themselves, not circular runes or veins.
# Violet is incoming mana; cyan/white is processed energy leaving the entity.
for i,(c,s,b,k) in enumerate([
    ((-.336,-.192,1.50),(.18,.018,.045),'crown_west','violet'),
    ((-.23,-.192,1.435),(.035,.018,.12),'crown_west','violet'),
    ((-.345,-.02,1.12),(.018,.25,.20),'west_fold','violet'),
    ((-.47,-.242,1.13),(.045,.018,.22),'west_fold','violet'),
    ((-.22,-.258,.71),(.27,.018,.035),'lower_fold','violet'),
    ((-.20,-.015,.805),(.24,.22,.018),'lower_fold','violet'),
    ((.20,.08,1.02),(.018,.24,.16),'east_fold','cyan'),
    ((.33,-.108,1.09),(.12,.018,.035),'east_fold','cyan'),
    ((.32,.004,1.46),(.23,.018,.035),'crown_east','cyan'),
    ((.32,.15,1.577),(.22,.20,.018),'crown_east','cyan'),
    ((-.04,.293,1.33),(.14,.018,.035),'rear_fold','hot'),
    ((-.73,-.157,.85),(.07,.018,.12),'satellite_west','violet'),
    ((.7,-.017,1.34),(.08,.018,.16),'satellite_east','cyan'),
    ((.28,-.177,.36),(.055,.018,.08),'satellite_below','violet'),
]):
    box('Mana_Seam_%02d'%i, c,s,b,k)

intake = [(-.81,-.35,1.29),(-.68,-.48,.62),(-.13,-.66,.92),(.41,-.55,.56)]
exhaust = [(.12,.06,1.91),(.71,.23,1.78),(.81,.41,1.07),(-.18,.47,1.76)]
for i,p in enumerate(intake):
    box('Absorbed_Mana_%02d'%i,p,(.085,)*3,'intake_%02d'%i,'violet')
for i,p in enumerate(exhaust):
    box('Emitted_Mana_%02d'%i,p,(.06,)*3,'exhaust_%02d'%i,'hot' if i%2==0 else 'cyan')

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
palette={'stone':(37,35,59),'violet':(163,77,240),'cyan':(46,201,225),'hot':(145,241,240)}
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
    for yy in range(-PAD,h+PAD):
        for xx in range(-PAD,w+PAD):
            v=tile[min(h-1,max(0,yy)),min(w-1,max(0,xx))]
            pixels[it['y']+yy,it['x']+xx]=v
            if kind!='stone': energy[it['y']+yy,it['x']+xx]=v
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
    b=arm.edit_bones.new(name); b.head=c; b.tail=c+Vector((0,0,.10)); b.parent=arm.edit_bones['root']
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    o.parent=rig; o.modifiers.new('Rigid_Cuboids','ARMATURE').object=rig
rig.animation_data_create()
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
restq={b.name:b.matrix_local.to_quaternion() for b in arm.bones}
origin=Vector((-.02,.02,1.10))
clips={}
def pose(bone, delta, scale=1):
    b=rig.pose.bones[bone]
    b.location=restq[bone].inverted()@Vector(delta)
    b.rotation_quaternion=(1,0,0,0)
    b.scale=(scale,)*3
def bake(frame):
    for b in rig.pose.bones:
        for prop in ('location','rotation_quaternion','scale'):
            b.keyframe_insert(data_path=prop,frame=frame,group=b.name)
def smooth(t): return t*t*(3-2*t)

for clip,end,start in [('Idle',97,1),('Walk',49,121),('Attack',37,191)]:
    action=bpy.data.actions.new(NAME+'_'+clip); action.use_fake_user=True
    rig.animation_data.action=action
    for f in range(1,end+1):
        scene.frame_set(f); t=(f-1)/(end-1); p=math.tau*t
        for b in rig.pose.bones: pose(b.name,(0,0,0))
        charge=burst=push=0
        if clip=='Attack':
            if t<.30: charge=smooth(t/.30)
            elif t<.48:
                q=smooth((t-.30)/.18); charge=1-q; burst=q
            else: burst=1-smooth((t-.48)/.52)
            push=-.15*burst
        for i,(n,c) in enumerate(centers.items()):
            if n.startswith(('intake','exhaust')):
                incoming=n.startswith('intake'); idx=int(n[-2:])
                # Continuous trajectories with a tiny, invisible return phase.
                phase=(t*(2 if clip=='Walk' else 1)+idx*.25)%1
                if clip=='Attack':
                    phase=(t+idx*.19)%1
                if phase<.76:
                    u=smooth(phase/.76)
                    target=c.lerp(origin,u) if incoming else origin.lerp(c,u)
                    size=(1-u)**.65*smooth(min(1,phase/.10)) if incoming else math.sin(math.pi*u)**.65
                    size=max(.012,size)
                else:
                    u=smooth((phase-.76)/.24)
                    target=origin.lerp(c,u) if incoming else c.lerp(origin,u)
                    size=.012
                if clip=='Attack': size*=1+.8*(charge if incoming else burst)
                pose(n,target-c+Vector((0,push,.012*math.sin(p))),size)
            else:
                drift=math.sin(p+i*.73)-math.sin(i*.73)
                radial=c-origin; radial.y*=.25
                if radial.length: radial.normalize()
                delta=radial*(.009*drift-.035*charge+.075*burst)
                delta.z+=.012*math.sin(p)
                delta.y+=push
                if n.startswith('satellite'):
                    delta+=radial*(.025*drift-.025*charge+.055*burst)
                    if clip=='Walk': delta.y+=.025
                if n=='satellite_below' and clip=='Attack': delta.z*=.35
                pose(n,delta)
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
scene.render.fps=24; scene.frame_start=1; scene.frame_end=227; scene.frame_set(1)

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
scene['description']='Cubic non-biological mana entity: disconnected folded masses, real central void, violet intake and cyan exhaust.'
scene['references']='Actual previews: ancient_golem_v2, troll_blocky_v3, previous mana_devourer_v1.'
state=dict(scene=scene,root=root,rig=rig,parts=parts,clips=clips,images=images,material=mat,
    studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),name=NAME,stem=STEM,
    old_scenes=list(old_scenes),old_hashes=old_hashes,atlas=SIZE)
bpy.app.driver_namespace['mana_devourer_blocky_v2']=state
(OUT/'previews').mkdir(exist_ok=True)
scene.render.filepath=str(OUT/'previews/three_quarter.png')
bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'bones':len(arm.bones),'triangles':len(parts)*12,'atlas':SIZE,
        'clips':list(clips),'scenes_before':len(old_scenes),'scenes_after':len(bpy.data.scenes)}
