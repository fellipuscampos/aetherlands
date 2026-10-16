"""Animate the approved floating Avatar V4 without changing its meshes or textures."""
import bpy,bmesh,math,json,shutil,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler,Quaternion

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='nature_avatar_blocky_v5_animated'; NAME='Nature_Avatar_Blocky_V5_Animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source'/f'{STEM}_review'
old=bpy.app.driver_namespace['nature_avatar_blocky_v4']
assert NAME not in bpy.data.scenes,'Preserve existing animation work.'
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(OUT/'previews').mkdir(exist_ok=True); (REVIEW/'.gdignore').write_text('')
protected=dict(old['old_hashes'])
for ext in ('glb','blend'):
    path=Path(old['out'])/(old['stem']+'.'+ext)
    protected[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
old_scenes=list(bpy.data.scenes.keys())
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
entity=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(entity)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=old['root'].copy(); root.name=NAME+'_ROOT'; entity.objects.link(root)
rig=old['rig'].copy(); rig.data=old['rig'].data.copy(); rig.name=NAME+'_Rig'
rig.animation_data_clear(); rig.parent=root; entity.objects.link(rig)
mat=old['material'].copy(); mat.name=NAME+'_Ancient_Roots_Green_Core'
images=[]
for im in old['images']:
    suffix='emission' if 'emission' in im.name else 'albedo'
    dest=OUT/(STEM+'_'+suffix+'.png'); shutil.copy2(im.filepath_raw,dest)
    copied=bpy.data.images.load(str(dest),check_existing=False); copied.pack(); images.append(copied)
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image==im: node.image=copied
parts=[]
for original in old['parts']:
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

# Floating locomotion and two connected articulated arms; no linear root motion or limb stretching.
rig.animation_data_create()
restq={b.name:b.matrix_local.to_quaternion() for b in rig.data.bones}
identity=Quaternion((1,0,0,0))
for bone in rig.pose.bones: bone.rotation_mode='QUATERNION'
def rot(x=0,y=0,z=0): return Euler(tuple(math.radians(v) for v in (x,y,z))).to_quaternion()
def ease(x):
    x=max(0,min(1,x)); return x*x*(3-2*x)
def pulse(t,start,rise,hold,end):
    if t<=start or t>=end: return 0.
    if t<rise: return ease((t-start)/(rise-start))
    if t<=hold: return 1.
    return 1-ease((t-hold)/(end-hold))
def pose(name,shift=(0,0,0),rotation=None,scale=1.):
    bone=rig.pose.bones[name]; q=restq[name]
    bone.location=q.inverted()@Vector(shift)
    bone.rotation_quaternion=q.inverted()@(rotation or identity)@q
    bone.scale=(scale,)*3
arms={}
for side in ('L','R'):
    arms[side]=tuple(rig.data.bones[base+side].head_local.copy() for base in ('upper_arm_','forearm_','hand_'))
def arm(side,shift,pole_amount=0.,wrist_tilt=0.):
    shoulder,elbow,wrist=arms[side]; target=wrist+Vector(shift)
    upper0=elbow-shoulder; fore0=wrist-elbow; a,b=upper0.length,fore0.length
    delta=target-shoulder; distance=delta.length; direction=delta.normalized()
    assert abs(a-b)+.002<distance<a+b-.002,('Unreachable wrist',side,shift,distance,a+b)
    along=(a*a-b*b+distance*distance)/(2*distance)
    sign=-1 if side=='L' else 1
    hint=upper0+Vector((sign*.12*pole_amount,-.11*pole_amount,.09*pole_amount))
    bend=hint-direction*hint.dot(direction)
    assert bend.length>.001
    bend.normalize()
    solved_elbow=shoulder+direction*along+bend*math.sqrt(max(0,a*a-along*along))
    upper=upper0.rotation_difference(solved_elbow-shoulder)
    fore=fore0.rotation_difference(target-solved_elbow)
    pose('upper_arm_'+side,rotation=upper)
    pose('forearm_'+side,rotation=upper.inverted()@fore)
    # The square hand follows its forearm; only a small local wrist gesture is added.
    pose('hand_'+side,rotation=rot(wrist_tilt))

root_bones=[n for n in rig.pose.bones.keys() if n.startswith(('floating_root_','hanging_root_'))]
def frame_pose(clip,t,duration):
    for bone in rig.pose.bones:
        bone.location=(0,0,0); bone.rotation_quaternion=identity; bone.scale=(1,1,1)
    p=math.tau*t/duration
    charge=cast=wind=hit=0.
    left=right=(0,0,0); pole_l=pole_r=0.; tilt_l=tilt_r=0.
    core_phase=p
    if clip=='Idle':
        wave=math.sin(4*p)
        pose('body',(0,0,.025*(1-math.cos(4*p))),rot(.65*wave,0,.45*math.sin(2*p)))
        pose('chest',rotation=rot(-.3*wave))
        left=(0,-.003*wave,.006*(1-math.cos(4*p)))
        right=(0,.003*wave,.006*(1-math.cos(4*p)))
    elif clip=='Walk':
        wave=math.sin(3*p)
        pose('body',(0,0,.040+.022*(1-math.cos(3*p))),rot(5.0+.6*wave,0,.5*math.sin(2*p)))
        pose('chest',rotation=rot(-1.2))
        left=(-.010,.025+.008*wave,.035+.010*wave)
        right=(.010,.025-.008*wave,.035-.010*wave)
    elif clip=='Attack':
        wind=pulse(t,0,.34,.40,.78); hit=pulse(t,.40,.875,.94,1.66)
        pose('body',(0,.025*wind-.035*hit,.04*wind+.055*hit),rot(-2.0*wind+3.5*hit))
        pose('chest',rotation=rot(0,0,3.0*wind-4.0*hit))
        right=(-.045*wind-.025*hit,.05*wind-.40*hit,.33*wind+.25*hit)
        left=(.010*wind,-.060*hit,.035*wind+.06*hit)
        pole_r=.45*wind+.65*hit; pole_l=.20*hit
        tilt_r=-7*hit
        core_phase=math.tau*ease(t/duration)
    elif clip=='Spell':
        charge=pulse(t,0,.90,1.95,3.15); cast=pulse(t,1.42,1.75,1.88,2.60)
        pose('body',(0,0,.14*charge+.035*cast),rot(-1.2*charge+2*cast))
        pose('chest',rotation=rot(-1.0*charge+2.0*cast))
        left=(-.04*charge,-.55*charge-.035*cast,.84*charge-.15*cast)
        right=(.04*charge,-.55*charge-.035*cast,.84*charge-.15*cast)
        pole_l=pole_r=charge
        tilt_l=tilt_r=-12*cast
        core_phase=math.tau*ease(t/duration)
    arm('L',left,pole_l,tilt_l); arm('R',right,pole_r,tilt_r)
    # A slight forward clearance keeps the original cube free of its wooden crown while turning.
    travel_clearance=.04 if clip=='Walk' else 0.
    pose('core',(0,-.27-travel_clearance-.10*charge-.055*hit,0),rot(0,0,math.degrees(core_phase)),1+.035*charge+.03*hit)
    for i,name in enumerate(root_bones):
        lag=.53*i
        if clip in ('Idle','Walk'):
            cycles=4 if clip=='Idle' else 3
            flutter=math.sin(cycles*p-lag)-math.sin(-lag)
            trail=5.0 if clip=='Walk' else 0.
            angle=(1.65 if clip=='Idle' else 2.3)*flutter+trail
        else:
            flutter=math.sin(math.pi*t/duration)**2*math.sin(2*p-lag)
            angle=2.8*flutter+3.5*charge+3*hit
        pose(name,rotation=rot(angle,.75*flutter))

specs={
 'Idle':(12.,True,'Flutuação suave, giro lento do núcleo e raízes suspensas balançando.'),
 'Walk':(6.,True,'Deslizamento pairando no lugar, corpo inclinado e raízes acompanhando o fluxo.'),
 'Attack':(2.,False,'Prepara o braço direito e libera um golpe frontal de energia, com recuperação.'),
 'Spell':(3.5,False,'Ergue os dois braços, concentra energia no núcleo e projeta o poder em direção ao terreno.')}
clips={}; previous={}
for name,(duration,loop,description) in specs.items():
    action=bpy.data.actions.new(NAME+'_'+name); action.use_fake_user=True
    action['loop']=loop; action['fps']=24; action['description']=description
    rig.animation_data.action=action; previous.clear(); end=round(duration*24)+1
    for frame in range(1,end+1):
        frame_pose(name,(frame-1)/24,duration)
        for bone in rig.pose.bones:
            if bone.name in previous and previous[bone.name].dot(bone.rotation_quaternion)<0: bone.rotation_quaternion.negate()
            previous[bone.name]=bone.rotation_quaternion.copy()
            for path in ('location','rotation_quaternion','scale'): bone.keyframe_insert(data_path=path,frame=frame,group=bone.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    if name=='Attack': action.pose_markers.new('IMPACT').frame=22
    if name=='Spell': action.pose_markers.new('CAST').frame=43
    clips[name]=dict(action=action,duration_s=duration,end_frame=end,loop=loop,description=description)
rig.animation_data.action=None
cursor=1
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,cursor,data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    data['nla_start']=cursor; scene.timeline_markers.new(name,frame=cursor); cursor+=data['end_frame']+24
scene.frame_start=1; scene.frame_end=clips['Idle']['end_frame']; scene.frame_set(1)
scene['description']='Floating Avatar V4 animated: connected arms, turning green core, rigid suspended roots, no walking legs, no root motion.'
st=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,images=images,material=mat,
    atlas=old['atlas'],camera=camera,studio=studio,out=str(OUT),review=str(REVIEW),
    clips=clips,old_scenes=old_scenes,old_hashes=protected,reference=old,arms=arms,root_bones=root_bones)
bpy.app.driver_namespace[STEM]=st
result={'scene':NAME,'parts':len(parts),'bones':len(rig.data.bones),
    'clips':{n:{k:v for k,v in data.items() if k!='action'} for n,data in clips.items()}}
