"""Bake four rigid animations on a separate copy of the approved live seraph."""
import bpy, math, json, shutil, hashlib
from pathlib import Path
from mathutils import Vector, Euler, Quaternion, Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='seraph_blocky_v4_animated'; NAME='Sacred_Seraph_Blocky_V4_Animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/seraph_blocky_v4_animated_review'
old=bpy.app.driver_namespace['seraph_blocky_v4']
assert NAME not in bpy.data.scenes, 'Preserve an existing animation scene.'
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
protected=dict(old['old_hashes'])
for ext in ('glb','blend'):
    p=Path(old['out'])/('seraph_blocky_v4.'+ext)
    protected[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
old_scenes=list(bpy.data.scenes.keys())
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
entity=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(entity)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=old['root'].copy(); root.name=NAME+'_ROOT'; entity.objects.link(root)
rig=old['rig'].copy(); rig.data=old['rig'].data.copy(); rig.name=NAME+'_Rig'
rig.animation_data_clear(); rig.parent=root; entity.objects.link(rig)
mat=old['material'].copy(); mat.name=NAME+'_Sacred_Ivory_Gold'
images=[]
for im in old['images']:
    suffix='emission' if 'emission' in im.name else 'albedo'
    dest=OUT/(STEM+'_'+suffix+'.png'); shutil.copy2(im.filepath_raw,dest)
    copied=bpy.data.images.load(str(dest),check_existing=False); copied.pack(); images.append(copied)
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image==im: node.image=copied
parts=[]
for o in old['parts']:
    n=o.copy(); n.data=o.data.copy(); n.name=o.name.replace('Sacred_Seraph_Blocky_V4',NAME)
    n.parent=rig; entity.objects.link(n)
    for modifier in n.modifiers:
        if modifier.type=='ARMATURE': modifier.object=rig
    n.data.materials.clear(); n.data.materials.append(mat); parts.append(n)
camera=None
for o in old['studio'].objects:
    n=o.copy(); n.data=o.data.copy() if o.data else None; n.name=NAME+'_Studio_'+o.name
    studio.objects.link(n)
    if o==old['camera']: camera=n
scene.camera=camera; scene.world=old['scene'].world.copy()
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.render.fps=24
scene['description']='Approved V4 geometry and textures; rigid Idle, Walk, Attack and Spell. No root motion.'
rig.animation_data_create()
restq={b.name:b.matrix_local.to_quaternion() for b in rig.data.bones}
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
axes={'core':Vector((.18,.22,1)).normalized(),'orbit_a':Vector((.9,.22,.28)).normalized(),'orbit_b':Vector((.16,.06,1)).normalized()}
alignment=(Euler((0,0,math.radians(12))).to_matrix() @ Euler(tuple(math.radians(a) for a in (72,15,-12))).to_matrix().inverted()).to_quaternion()
identity=Quaternion((1,0,0,0))

def ease(x):
    x=max(0,min(1,x)); return x*x*(3-2*x)

def pulse(t,start,rise,hold,end):
    if t<start or t>=end: return 0.
    if t<rise: return ease((t-start)/(rise-start))
    if t<=hold: return 1.
    return 1-ease((t-hold)/(end-hold))

def pose(name,shift=(0,0,0),rotation=None,scale=1.):
    b=rig.pose.bones[name]; q=restq[name]
    b.location=q.inverted()@Vector(shift)
    b.rotation_quaternion=q.inverted()@(rotation or identity)@q
    b.scale=(scale,)*3

def wings(elevations,sweeps):
    for band in ('main','lower','crown'):
        for sign in (-1,1):
            n='wing_'+band+('_R' if sign>0 else '_L')
            q=Quaternion((0,0,1),math.radians(sign*sweeps[band]))@Quaternion((0,1,0),math.radians(-sign*elevations[band]))
            pose(n,rotation=q)

def frame_pose(clip,t,duration):
    for b in rig.pose.bones:
        b.location=(0,0,0); b.rotation_quaternion=identity; b.scale=(1,1,1)
    p=math.tau*t/duration
    shell=(0,0,0); core_scale=1.; charge=0.
    if clip=='Idle':
        body=(0,0,.045*(1-math.cos(math.tau*t/4)))
        rotation=Euler((math.radians(1.1)*math.sin(math.tau*t/8),0,math.radians(.8)*math.sin(math.tau*t/12))).to_quaternion()
        wave=math.sin(math.tau*t/6)
        elev={'main':1.4*wave,'lower':1.*wave,'crown':.55*wave}
        sweep={'main':.5*math.sin(math.tau*t/4),'lower':.4*math.sin(math.tau*t/4),'crown':.2*wave}
    elif clip=='Walk':
        wave=math.sin(math.tau*t/2)
        body=(0,0,.10+.025*(1-math.cos(math.tau*t/2)))
        rotation=Euler((math.radians(7+1.4*wave),math.radians(.7)*math.sin(math.tau*t/4),0)).to_quaternion()
        elev={'main':3+4*wave,'lower':1+2.2*math.sin(math.tau*t/2-.5),'crown':.8+wave}
        sweep={'main':2+2*wave,'lower':1+1.3*wave,'crown':.5*wave}
    elif clip=='Attack':
        wind=pulse(t,0,.34,.42,.68); hit=pulse(t,.45,.625,.67,1.12)
        body=(0,.03*wind-.11*hit,.06*wind+.10*hit)
        rotation=Euler((math.radians(-4*wind+8*hit),0,0)).to_quaternion()
        shell=(0,.025*wind-.14*hit,.025*hit)
        core_scale=1-.07*wind+.10*hit
        elev={'main':6*wind-4*hit,'lower':4*wind-2*hit,'crown':1.5*wind+2*hit}
        sweep={'main':9*wind-10*hit,'lower':6*wind-7*hit,'crown':2*wind-3*hit}
        p=math.tau*ease(t/duration)
    else:
        charge=pulse(t,0,.78,1.85,2.78)
        beat=(math.sin(math.tau*(t-.78)/.70)**2)*charge
        body=(0,0,.20*charge+.025*beat)
        rotation=Euler((math.radians(-3)*charge,0,0)).to_quaternion()
        core_scale=1+.12*charge+.04*beat
        elev={'main':6*charge+beat,'lower':6*charge+beat,'crown':2*charge+.5*beat}
        sweep={'main':4*charge,'lower':3*charge,'crown':charge}
        p=math.tau*ease(t/duration)
    pose('body',body,rotation)
    wings(elev,sweep)
    pose('core',shell,Quaternion(axes['core'],p*(2 if clip=='Spell' else 1)),core_scale)
    for n,direction in (('orbit_a',1),('orbit_b',-1)):
        axis=Vector((0,0,1)) if clip=='Spell' else axes[n]
        q=Quaternion(axis,p*direction)
        if clip=='Spell' and n=='orbit_b': q=q@identity.slerp(alignment,charge)
        pose(n,shell,q)

specs={'Idle':(24.,True,'Flutuação suave, asas suspensas e giro lento do núcleo e das auréolas.'),
       'Walk':(8.,True,'Voo no lugar, com inclinação para a frente e batidas suaves das asas.'),
       'Attack':(1.5,False,'Recuo de preparação, impulso frontal do núcleo e recuperação.'),
       'Spell':(3.,False,'Abertura das asas, auréola frontal e pulsos de energia sagrada.')}
clips={}; previous={}
for name,(duration,loop,description) in specs.items():
    action=bpy.data.actions.new(NAME+'_'+name); action.use_fake_user=True
    action['loop']=loop; action['fps']=24; action['description']=description
    rig.animation_data.action=action; previous.clear()
    end=round(duration*24)+1
    for f in range(1,end+1):
        frame_pose(name,(f-1)/24,duration)
        for b in rig.pose.bones:
            if b.name in previous and previous[b.name].dot(b.rotation_quaternion)<0: b.rotation_quaternion.negate()
            previous[b.name]=b.rotation_quaternion.copy()
            for path in ('location','rotation_quaternion','scale'): b.keyframe_insert(data_path=path,frame=f,group=b.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    if name=='Attack': action.pose_markers.new('IMPACT').frame=16
    if name=='Spell': action.pose_markers.new('CAST').frame=34
    clips[name]={'action':action,'duration_s':duration,'end_frame':end,'loop':loop,'description':description}
rig.animation_data.action=None
cursor=1
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,cursor,data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    data['nla_start']=cursor
    scene.timeline_markers.new(name,frame=cursor)
    cursor+=data['end_frame']+24
scene.frame_start=1; scene.frame_end=clips['Idle']['end_frame']; scene.frame_set(1)
st=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,images=images,material=mat,
        atlas=old['atlas'],camera=camera,studio=studio,out=str(OUT),review=str(REVIEW),
        clips=clips,old_scenes=old_scenes,old_hashes=protected,reference=old)
bpy.app.driver_namespace[STEM]=st
result={'scene':NAME,'geometry_and_textures_preserved':True,'clips':{n:{k:v for k,v in c.items() if k!='action'} for n,c in clips.items()}}
