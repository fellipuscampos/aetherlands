"""Bake four rigid animations on a separate copy of the approved live seraph."""
import bpy, math, json, shutil, hashlib
from pathlib import Path
from mathutils import Vector, Euler, Quaternion, Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='archdemon_blocky_v4_animated'; NAME='Infernal_Archdemon_Blocky_V4_Animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/archdemon_blocky_v4_animated_review'
old=bpy.app.driver_namespace['archdemon_blocky_v3']
assert NAME not in bpy.data.scenes, 'Preserve an existing animation scene.'
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
protected=dict(old['old_hashes'])
for ext in ('glb','blend'):
    p=Path(old['out'])/('archdemon_blocky_v3.'+ext)
    protected[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
old_scenes=list(bpy.data.scenes.keys())
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
entity=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(entity)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=old['root'].copy(); root.name=NAME+'_ROOT'; entity.objects.link(root)
rig=old['rig'].copy(); rig.data=old['rig'].data.copy(); rig.name=NAME+'_Rig'
rig.animation_data_clear(); rig.parent=root; entity.objects.link(rig)
mat=old['material'].copy(); mat.name=NAME+'_Weathered_Iron_Red_Core'
images=[]
for im in old['images']:
    suffix='emission' if 'emission' in im.name else 'albedo'
    dest=OUT/(STEM+'_'+suffix+'.png'); shutil.copy2(im.filepath_raw,dest)
    copied=bpy.data.images.load(str(dest),check_existing=False); copied.pack(); images.append(copied)
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image==im: node.image=copied
parts=[]
for o in old['parts']:
    n=o.copy(); n.data=o.data.copy(); n.name=o.name.replace('Infernal_Archdemon_Blocky_V3',NAME)
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
scene['description']='Side stoles attached to skirt surfaces; spinning red cube inside the chest. Four rigid clips, no root motion.'
# Rotate the broad faces outward, with the top edge touching the skirt's side surface.
attachments={}
for side,sign in [('L',-1),('R',1)]:
    prefix='stole_side_'+side+'_'
    pivot=rig.data.bones[prefix+'0'].head_local.copy()
    target=Vector((sign*(.3885811567+.045*.92519325/2),.1063972283,pivot.z))
    turn=Matrix.Rotation(sign*math.pi/2,3,'Z')
    for o in parts:
        if o['rig_bone'].startswith(prefix):
            for v in o.data.vertices: v.co=target+turn@(v.co-pivot)
            o.data.update()
    attachments[side]=(pivot,target,turn)
core=next(o for o in parts if o['rig_bone']=='core')
core.name=NAME+'_Core_Red_Energy_Cube'
old_center=rig.data.bones['core'].head_local.copy()
center=Vector((0,0,old_center.z)); edge=.24
tilt=Euler(tuple(math.radians(a) for a in (18,10,22))).to_matrix()
for v in core.data.vertices:
    delta=v.co-old_center
    corner=Vector(tuple(edge/2*(1 if delta[i]>0 else -1) for i in range(3)))
    v.co=center+tilt@corner
core['kind']='red_energy_cube'; core['edge_m']=edge; core.data.update()
# Uniform red atlas texels also cover the deeper faces; armor and cloth images stay byte-identical.
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for side,(pivot,target,turn) in attachments.items():
    for b in rig.data.edit_bones:
        if b.name.startswith('stole_side_'+side+'_'):
            b.head=target+turn@(b.head-pivot); b.tail=b.head+Vector((0,0,.15))
rig.data.edit_bones['core'].head=center; rig.data.edit_bones['core'].tail=center+Vector((0,0,.15))
bpy.ops.object.mode_set(mode='OBJECT')
scene['side_stoles_attachment']='Broad cloth faces lie on the two side planes of the skirt; top edges touch the armor.'
scene['core']='Single 24 cm red emissive cube, suspended and spinning inside the hollow cuirass.'

rig.animation_data_create()
restq={b.name:b.matrix_local.to_quaternion() for b in rig.data.bones}
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
identity=Quaternion((1,0,0,0)); axis=Vector((.18,.22,1)).normalized()
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
def rot(x=0,y=0,z=0): return Euler(tuple(math.radians(a) for a in (x,y,z))).to_quaternion()
def frame_pose(clip,t,duration):
    for b in rig.pose.bones:
        b.location=(0,0,0); b.rotation_quaternion=identity; b.scale=(1,1,1)
    p=math.tau*t/duration; wave=math.sin(math.tau*t/4)
    wind=hit=charge=0.
    if clip=='Idle':
        pose('body',(0,0,.022*(1-math.cos(math.tau*t/4))),rot(.55*math.sin(math.tau*t/8)))
    elif clip=='Walk':
        wave=math.sin(math.tau*t/2)
        pose('body',(0,0,.10+.012*(1-math.cos(math.tau*t/2))),rot(4.5+.6*wave))
    elif clip=='Attack':
        wind=pulse(t,0,.32,.40,.65); hit=pulse(t,.44,.625,.70,1.22)
        pose('body',(0,.028*wind-.07*hit,.04*wind+.12*hit),rot(-2*wind+4*hit))
        p=math.tau*ease(t/duration); wave=0.
    else:
        charge=pulse(t,0,.70,1.85,2.82)
        pose('body',(0,0,.15*charge),rot(-1.5*charge))
        p=2*math.tau*ease(t/duration); wave=0.
    pose('core',rotation=Quaternion(axis,p))
    for side,sign in [('L',-1),('R',1)]:
        if clip=='Idle':
            sshift=(sign*.005*(1-math.cos(math.tau*t/6)),0,.012*wave)
            fshift=(sign*.008*(1-math.cos(math.tau*t/6)),0,.010*wave)
            sr=rot(0,sign*.65*wave,0); fr=rot(.7*wave,0,sign*.8*wave)
        elif clip=='Walk':
            sshift=(sign*.018,.018,.012*wave); fshift=(sign*.025,.075,.010*wave)
            sr=rot(1,sign*1.1,0); fr=rot(-2+.7*wave,0,sign*1.0)
        elif clip=='Attack':
            sshift=(sign*(.026*wind+.022*hit),.035*wind-.035*hit,.045*hit)
            fshift=(sign*(.07*wind+.045*hit),.10*wind-.33*hit,.075*wind+.19*hit)
            sr=rot(-2*wind+3*hit,sign*2*wind,0); fr=rot(-5*wind+11*hit,0,-sign*2*wind)
        else:
            sshift=(sign*.045*charge,0,.075*charge)
            fshift=(sign*.19*charge,-.12*charge,.24*charge)
            sr=rot(0,sign*3*charge); fr=rot(0,-sign*6*charge,0)
        pose('shoulder_'+side,sshift,sr); pose('fist_'+side,fshift,fr)
        for band in ('front','side'):
            for i in range(4):
                sway=.42*wave*(i/3)
                trail=(.65+.35*wave) if clip=='Walk' else .7*hit+1.1*charge
                # The attachment segment is rigid at the body; distal folds sway without twisting.
                angle=(sway+trail)*(i/3)
                pose('stole_'+band+'_'+side+'_'+str(i),rotation=rot(angle,0,0))
    for i,n in enumerate(('mantle_upper_l','mantle_upper_r','mantle_lower_l','mantle_lower_r')):
        sign=-1 if n.endswith('_l') else 1
        flutter=wave*.008 if clip in ('Idle','Walk') else 0
        pose(n,(sign*.012*charge,.012*charge,.022*charge+flutter),rot(0,0,sign*(.55*wave+1.5*charge)))
specs={'Idle':(24.,True,'Flutuação contida; ombros e mãos suspensos; giro lento do cubo vermelho.'),
       'Walk':(8.,True,'Deslizamento no lugar, inclinação suave e faixas acompanhando o movimento.'),
       'Attack':(1.5,False,'Preparação e golpe frontal com as duas mãos flutuantes.'),
       'Spell':(3.,False,'Mãos afastadas em conjuração; elevação da entidade e giro acelerado do núcleo.')}

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
        islands=old['islands'],clips=clips,old_scenes=old_scenes,old_hashes=protected,reference=old)
bpy.app.driver_namespace[STEM]=st
result={'scene':NAME,'side_stoles_attached':True,'core_is_cube_inside_chest':True,'clips':{n:{k:v for k,v in c.items() if k!='action'} for n,c in clips.items()}}
