"""Animate a preserved copy of Lich V2, with connected arms and articulated cloth."""
import bpy,bmesh,math,json,shutil,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler,Quaternion

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='elder_lich_blocky_v3_animated'; NAME='Elder_Lich_Blocky_V3_Animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source'/f'{STEM}_review'
old=bpy.app.driver_namespace['elder_lich_blocky_v2']
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
mat=old['material'].copy(); mat.name=NAME+'_Ancient_Vestments_Bone_Spectral'
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

# Split only the existing cloth surfaces. Cut edges inherit their metric UVs;
# the silhouette, thickness, atlas and all rigid body surfaces remain unchanged.
cloth={}
for base in ('robe_front_L','robe_front_R','robe_side_L','robe_side_R','cape_left','cape_center','cape_right'):
    group=[o for o in parts if o['rig_bone']==base]
    panel=max(group,key=lambda o:len(o.data.vertices))
    up=Euler(panel['local_rotation'],'XYZ').to_matrix()@Vector((0,0,1))
    anchor=rig.data.bones[base].head_local.copy()
    projections=[(v.co-anchor).dot(up) for v in panel.data.vertices]
    top,bottom=max(projections),min(projections)
    cuts=[top-(top-bottom)*fraction for fraction in (1/3,2/3)]
    joints=[base,base+'_middle',base+'_hem']
    cloth[base]=dict(up=up,anchor=anchor,cuts=cuts,joints=joints,parts=group)
    for o in group:
        bm=bmesh.new(); bm.from_mesh(o.data)
        for position in cuts:
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                dist=1e-7,plane_co=anchor+up*position,plane_no=up,clear_inner=False,clear_outer=False)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free(); o.data.update()
        for vg in list(o.vertex_groups): o.vertex_groups.remove(vg)
        groups=[o.vertex_groups.new(name=n) for n in joints]
        for vertex in o.data.vertices:
            height=(vertex.co-anchor).dot(up)
            level=0 if height>cuts[0]+1e-6 else 1 if height>cuts[1]+1e-6 else 2
            groups[level].add([vertex.index],1,'REPLACE')
        o['articulated_cloth']=True

focus=next(o for o in parts if 'Staff_Grave_Flame' in o.name)
focus_center=sum((v.co for v in focus.data.vertices),Vector())/len(focus.data.vertices)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for base,data in cloth.items():
    parent=base
    for name,position in zip(data['joints'][1:],data['cuts']):
        bone=rig.data.edit_bones.new(name); bone.head=data['anchor']+data['up']*position
        bone.tail=bone.head+Vector((0,0,.10)); bone.parent=rig.data.edit_bones[parent]; parent=name
bone=rig.data.edit_bones.new('staff_focus'); bone.head=focus_center; bone.tail=focus_center+Vector((0,0,.10)); bone.parent=rig.data.edit_bones['staff']
bpy.ops.object.mode_set(mode='OBJECT')
for vg in list(focus.vertex_groups): focus.vertex_groups.remove(vg)
focus.vertex_groups.new(name='staff_focus').add(list(range(len(focus.data.vertices))),1,'REPLACE')
focus['rig_bone']='staff_focus'
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
    shoulder=rig.data.bones['upper_arm_'+side].head_local.copy()
    elbow=rig.data.bones['forearm_'+side].head_local.copy()
    wrist=rig.data.bones['hand_'+side].head_local.copy()
    arms[side]=(shoulder,elbow,wrist)

def arm(side,shift,desired_hand=identity):
    # Solve two connected segments at their existing lengths. Use the resting
    # elbow plane as the bend hint, shortest rotations and a bounded wrist.
    shoulder,elbow,wrist=arms[side]; target=wrist+Vector(shift)
    upper0=elbow-shoulder; fore0=wrist-elbow; a,b=upper0.length,fore0.length
    delta=target-shoulder; distance=delta.length; direction=delta.normalized()
    assert abs(a-b)+.002<distance<a+b-.002,('Unreachable wrist',side,shift,distance)
    along=(a*a-b*b+distance*distance)/(2*distance)
    bend=upper0-direction*upper0.dot(direction); bend.normalize()
    solved_elbow=shoulder+direction*along+bend*math.sqrt(max(0,a*a-along*along))
    upper=upper0.rotation_difference(solved_elbow-shoulder)
    fore=fore0.rotation_difference(target-solved_elbow)
    wrist_delta=fore.inverted()@desired_hand
    if wrist_delta.w<0: wrist_delta.negate()
    limit=math.radians(35)
    hand=desired_hand if wrist_delta.angle<=limit else fore@identity.slerp(wrist_delta,limit/wrist_delta.angle)
    pose('upper_arm_'+side,rotation=upper)
    pose('forearm_'+side,rotation=upper.inverted()@fore)
    pose('hand_'+side,rotation=fore.inverted()@hand)

def frame_pose(clip,t,duration):
    for bone in rig.pose.bones:
        bone.location=(0,0,0); bone.rotation_quaternion=identity; bone.scale=(1,1,1)
    p=math.tau*t/duration; wave=math.sin(p)
    wind=hit=charge=cast=0.
    left=right=(0,0,0); left_hand=right_hand=identity
    if clip=='Idle':
        pose('body',(0,0,.025*(1-math.cos(p))),rot(.45*wave))
        pose('chest',rotation=rot(0,0,.7*math.sin(p)))
        pose('head',rotation=rot(.6*wave,0,-.4*wave))
        left=(0,-.006*wave,.008*wave); right=(0,-.005*wave,.009*wave)
    elif clip=='Walk':
        pose('body',(0,0,.065+.015*(1-math.cos(p))),rot(4.2+.45*wave))
        pose('chest',rotation=rot(-1+.3*wave,0,.5*wave))
        pose('head',rotation=rot(-2.8-.3*wave))
        left=(-.012,.008,.012+.010*wave); right=(.008,-.015,.020-.008*wave)
        left_hand=rot(4)
    elif clip=='Attack':
        wind=pulse(t,0,.28,.34,.64); hit=pulse(t,.35,.625,.68,1.25)
        pose('body',(0,.025*wind-.05*hit,.035*wind+.045*hit),rot(-.8*wind+2*hit))
        pose('chest',rotation=rot(0,0,-5*wind+5*hit))
        pose('head',rotation=rot(-1.2*wind+2*hit,0,2*wind-2*hit))
        left=(-.025*wind-.015*hit,.06*wind-.15*hit,.14*wind+.08*hit)
        right=(.010*hit,-.04*hit,.025*wind+.035*hit)
        left_hand=rot(-14*wind+27*hit)
        pose('staff_focus',scale=1+.12*hit)
    else:
        charge=pulse(t,0,.75,1.65,2.70); cast=pulse(t,1.20,1.45,1.60,2.30)
        pose('body',(0,0,.11*charge),rot(-.7*charge))
        pose('chest',rotation=rot(-.7*charge))
        pose('head',rotation=rot(9*charge-3*cast,0,-2*charge))
        left=(-.025*charge,-.10*charge-.08*cast,.13*charge)
        right=(-.03*charge,-.10*charge,.23*charge+.015*cast)
        left_hand=rot(-5*charge+16*cast)
        right_hand=rot(-14*charge)
        pose('tome',(0,0,.025*charge),rot(-6*charge))
        pose('staff_focus',scale=1+.15*charge+.08*cast)
    arm('L',left,left_hand); arm('R',right,right_hand)
    for index,(base,data) in enumerate(cloth.items()):
        cape=base.startswith('cape_'); side=base.startswith('robe_side_')
        for j,name in enumerate(data['joints']):
            lag=.52*j+.38*index
            if clip in ('Idle','Walk'):
                flutter=math.sin(p-lag)-math.sin(-lag)
                trail=(1.6 if cape else .6) if clip=='Walk' else 0.
                gain=1.45 if clip=='Walk' else 1.
            else:
                flutter=math.sin(math.pi*t/duration)**2*math.sin(2*p-lag)
                trail=1.5*hit+.7*charge; gain=1.2
            amplitude=((.7,1.2,1.7) if cape else (.35,.65,.95))[j]
            angle=(gain*amplitude*flutter+trail*(.35+.25*j))
            if j==0: angle=0.  # Upper cloth remains attached to the chest/waist.
            if side:
                sign=-1 if base.endswith('_L') else 1
                pose(name,rotation=rot(0,-sign*angle,0))
            else: pose(name,rotation=rot(angle))
    for index,label in enumerate(('left','center','right')):
        lag=.75*index
        oscillation=math.sin(p-lag)-math.sin(-lag) if clip in ('Idle','Walk') else math.sin(math.pi*t/duration)**2*math.sin(2*p-lag)
        pose('spectral_tail_'+label,rotation=rot(3*oscillation+3*charge,1.0*oscillation))

specs={'Idle':(6.,True,'Flutuação suave, manto ondulando e vestígios espectrais em movimento.'),
       'Walk':(2.,True,'Deslizamento no lugar, corpo levemente inclinado e manto acompanhando o fluxo.'),
       'Attack':(1.5,False,'Preparação e golpe mágico frontal com o cajado, seguido de recuperação.'),
       'Spell':(3.,False,'Ergue o grimório, lê e canaliza a magia pelo cajado; retorna ao repouso.')}
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
    if name=='Attack': action.pose_markers.new('IMPACT').frame=16
    if name=='Spell': action.pose_markers.new('CAST').frame=36
    clips[name]=dict(action=action,duration_s=duration,end_frame=end,loop=loop,description=description)
rig.animation_data.action=None
cursor=1
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,cursor,data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    data['nla_start']=cursor; scene.timeline_markers.new(name,frame=cursor); cursor+=data['end_frame']+24
scene.frame_start=1; scene.frame_end=clips['Idle']['end_frame']; scene.frame_set(1)
scene['description']='Animated Lich V2: connected anatomical arm pivots, floating travel, articulated cloth, staff attack and grimoire spell. No root motion.'
st=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,images=images,material=mat,
    atlas=old['atlas'],camera=camera,studio=studio,out=str(OUT),review=str(REVIEW),
    clips=clips,old_scenes=old_scenes,old_hashes=protected,reference=old,cloth=cloth,arms=arms)
bpy.app.driver_namespace[STEM]=st
result={'scene':NAME,'parts':len(parts),'bones':len(rig.data.bones),'clips':{n:{k:v for k,v in data.items() if k!='action'} for n,data in clips.items()}}
