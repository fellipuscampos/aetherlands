"""Animate the approved floating Avatar V4 without changing its meshes or textures."""
import bpy,bmesh,math,json,shutil,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler,Quaternion

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='veil_archon_blocky_v9_animated'; NAME='Veil_Archon_Blocky_V9_Animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source'/f'{STEM}_review'
old=bpy.app.driver_namespace['veil_archon_blocky_v8']
assert NAME not in bpy.data.scenes,'Preserve existing animation work.'
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(OUT/'previews').mkdir(exist_ok=True); (REVIEW/'.gdignore').write_text('')
protected=dict(old['old_hashes'])
for ext in ('glb','blend'):
    path=Path(old['out'])/(old['stem']+'.'+ext)
    protected[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
for image in old['images']:
    path=Path(image.filepath_raw);protected[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
old_scenes=list(bpy.data.scenes.keys())
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
entity=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(entity)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=old['root'].copy(); root.name=NAME+'_ROOT'; entity.objects.link(root)
rig=old['rig'].copy(); rig.data=old['rig'].data.copy(); rig.name=NAME+'_Rig'
rig.animation_data_clear(); rig.parent=root; entity.objects.link(rig)
mat=old['material'].copy(); mat.name=NAME+'_Runic_Plates_White_Violet_Core'
images=[]
for im in old['images']:
    suffix='emission' if 'emission' in im.name else 'albedo'
    dest=OUT/(STEM+'_'+suffix+'.png'); shutil.copy2(im.filepath_raw,dest)
    copied=bpy.data.images.load(str(dest),check_existing=False); copied.pack(); images.append(copied)
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image==im: node.image=copied
parts=[]
for original in old['parts']:
    if original['kind']=='orbit':continue
    o=original.copy(); o.data=original.data.copy(); o.name=original.name.replace(old['name'],NAME)
    o.parent=rig; entity.objects.link(o)
    for modifier in o.modifiers:
        if modifier.type=='ARMATURE': modifier.object=rig
    o.data.materials.clear(); o.data.materials.append(mat); parts.append(o)
camera=None
for original in old['studio'].objects:
    o=original.copy(); o.data=original.data.copy() if original.data else None
    o.name=NAME+'_Studio_'+original.name; studio.objects.link(o)
    if original==old['camera']: camera=o
scene.camera=camera; scene.world=old['scene'].world.copy()
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.render.fps=24

# Remove only the six external purple orbital trails in this independent animated copy.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
arm=rig.data
arm.edit_bones.remove(arm.edit_bones['orbit'])
C=arm.edit_bones['core'].head.copy()
entity_bone=arm.edit_bones.new('entity');entity_bone.head=C;entity_bone.tail=C+Vector((0,0,.15))
entity_bone.parent=arm.edit_bones['root'];entity_bone.use_deform=False
for name in ('shell','core'):arm.edit_bones[name].parent=entity_bone
arm.edit_bones['lattice'].parent=arm.edit_bones['shell']
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data_create()
restq={b.name:b.matrix_local.to_quaternion() for b in rig.data.bones};identity=Quaternion((1,0,0,0))
for bone in rig.pose.bones:bone.rotation_mode='QUATERNION'

def rot(x=0,y=0,z=0):return Euler(tuple(math.radians(v) for v in (x,y,z))).to_quaternion()
def ease(x):x=max(0,min(1,x));return x*x*(3-2*x)
def pulse(t,start,rise,hold,end):
    if t<=start or t>=end:return 0.
    if t<rise:return ease((t-start)/(rise-start))
    if t<=hold:return 1.
    return 1-ease((t-hold)/(end-hold))
def pose(name,shift=(0,0,0),rotation=None,scale=1.):
    bone=rig.pose.bones[name];q=restq[name]
    bone.location=q.inverted()@Vector(shift)
    bone.rotation_quaternion=q.inverted()@(rotation or identity)@q
    bone.scale=(scale,)*3

panels=[]
for o in parts:
    if o['kind']!='plate':continue
    name=o['rig_bone'];center=rig.data.bones[name].head_local
    normal=Euler(o['local_rotation'],'XYZ').to_matrix()@Vector((0,-1,0))
    panels.append(dict(name=name,seed=int(o['rune_seed']),direction=(center-C).normalized(),normal=normal))

def frame_pose(clip,t,duration):
    for b in rig.pose.bones:b.location=(0,0,0);b.rotation_quaternion=identity;b.scale=(1,1,1)
    p=math.tau*t/duration;wind=release=charge=cast=0.;radial=0.
    core_phase=-2*p;core_scale=1.
    if clip=='Idle':
        pose('entity',(0,0,.018*(1-math.cos(2*p))),rot(.5*math.sin(2*p),.4*math.sin(p),math.degrees(p)))
        radial=.018*(1-math.cos(2*p))
    elif clip=='Walk':
        pose('entity',(0,0,.045+.018*(1-math.cos(3*p))),rot(8+.6*math.sin(3*p),.5*math.sin(2*p),math.degrees(p)))
        radial=.022+.012*(1-math.cos(3*p))
    elif clip=='Attack':
        wind=pulse(t,0,.34,.43,.82)
        release=pulse(t,.43,.875,.96,1.85)
        pose('entity',(0,.035*wind-.13*release,.035*wind+.07*release),rot(-2*wind+5*release,0,-3*wind+4*release))
        pose('shell',rotation=rot(0,0,3*wind-6*release))
        radial=.075*wind+.24*release
        core_phase=math.tau*ease(t/duration);core_scale=1+.05*wind+.10*release
    elif clip=='Spell':
        charge=pulse(t,0,1.15,2.10,3.62)
        cast=pulse(t,1.60,2.0,2.15,3.10)
        pose('entity',(0,0,.44*charge+.12*cast),rot(-1.5*charge+2*cast))
        pose('shell',rotation=rot(0,0,15*charge+20*cast))
        radial=.32*charge+.12*cast
        core_phase=2*math.tau*ease(t/duration);core_scale=1+.08*charge+.10*cast
    pose('core',rotation=rot(0,0,math.degrees(core_phase)),scale=core_scale)
    for panel in panels:
        seed=panel['seed'];extra=0.;turn=identity
        if seed<4 and clip=='Attack':
            extra=0.
            sx=-1 if seed in (0,2) else 1;sz=1 if seed<2 else -1
            turn=rot(sz*8*release,0,sx*8*release)
        elif seed<4 and clip=='Spell':extra=0.
        elif seed>=14 and clip=='Spell':
            turn=Quaternion(panel['normal'],math.radians((10 if seed%2 else -10)*cast))
        pose(panel['name'],panel['direction']*(radial+extra),turn)

specs={
 'Idle':(24.,True,'Giro lento da casca, núcleo girando em sentido contrário e pulsação suave das placas.'),
 'Walk':(12.,True,'Desliza pairando, com leve inclinação frontal e giro contínuo das placas.'),
 'Attack':(2.25,False,'Concentra o núcleo e abre as quatro placas frontais para liberar um pulso de mana.'),
 'Spell':(4.,False,'Levanta e expande a casca rúnica, gira as camadas e revela o núcleo durante a conjuração.')}
clips={};previous={}
for name,(duration,loop,description) in specs.items():
    action=bpy.data.actions.new(NAME+'_'+name);action.use_fake_user=True
    action['loop']=loop;action['fps']=24;action['description']=description
    rig.animation_data.action=action;previous.clear();end=round(duration*24)+1
    for frame in range(1,end+1):
        frame_pose(name,(frame-1)/24,duration)
        for bone in rig.pose.bones:
            if bone.name in previous and previous[bone.name].dot(bone.rotation_quaternion)<0:bone.rotation_quaternion.negate()
            previous[bone.name]=bone.rotation_quaternion.copy()
            for path in ('location','rotation_quaternion','scale'):bone.keyframe_insert(data_path=path,frame=frame,group=bone.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
    if name=='Attack':action.pose_markers.new('IMPACT').frame=22
    if name=='Spell':action.pose_markers.new('CAST').frame=49
    clips[name]=dict(action=action,duration_s=duration,end_frame=end,loop=loop,description=description)
rig.animation_data.action=None;cursor=1
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,cursor,data['action']);strip.extrapolation='NOTHING';strip.blend_type='REPLACE'
    data['nla_start']=cursor;scene.timeline_markers.new(name,frame=cursor);cursor+=data['end_frame']+24
scene.frame_start=1;scene.frame_end=clips['Idle']['end_frame'];scene.frame_set(1)
scene['description']='Approved runic polyhedron animated, with the six external purple trails removed. Rigid floating plates, central turning cube, open white lattice, no root motion.'
st=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,images=images,material=mat,
 atlas=old['atlas'],camera=camera,studio=studio,out=str(OUT),review=str(REVIEW),clips=clips,
 old_scenes=old_scenes,old_hashes=protected,reference=old,panels=panels,removed_external_trails=6)
bpy.app.driver_namespace[STEM]=st
result={'scene':NAME,'parts':len(parts),'bones':len(rig.data.bones),'external_trails_removed':6,
 'clips':{n:{k:v for k,v in data.items() if k!='action'} for n,data in clips.items()}}
