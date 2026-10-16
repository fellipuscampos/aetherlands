"""Six ground/flight clips for the approved V4, in an isolated Blender MCP scene.

World-space two-bone solves keep the ground paws planted. Wing roots are pinned
to the chest; shoulder, elbow and wrist move together. No fire geometry/VFX.
"""
import bpy,bmesh,math,json,hashlib,shutil
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix,Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
BASE='dark_red_dragon_v4'; STEM='dark_red_dragon_v5_animated'; NAME='Dark_Red_Dragon_V5_Animated'
OUT=ROOT/'assets/generated/dragons'/STEM
assert NAME not in bpy.data.scenes,'Preserve existing animation work.'
assert not (OUT/(STEM+'.glb')).exists(),'Preserve existing export.'
OUT.mkdir(parents=True,exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
review=ROOT/'art_source/dark_red_dragon_animation_review'; review.mkdir(parents=True,exist_ok=True)
(review/'.gdignore').touch()
protected={str(p):hashlib.sha256(p.read_bytes()).hexdigest()
           for p in (ROOT/'assets/generated/dragons').rglob('*') if p.suffix in ('.blend','.glb','.png') and OUT not in p.parents}
if BASE not in bpy.app.driver_namespace:
    with bpy.data.libraries.load(str(ROOT/'assets/generated/dragons'/BASE/(BASE+'.blend')),link=False) as (src,dst):
        dst.scenes=['Dark_Red_Dragon_V4']
    original=dst.scenes[0]
    base_parts=[o for o in original.objects if o.type=='MESH']
else:
    source_state=bpy.app.driver_namespace[BASE]; original=source_state['scene']; base_parts=source_state['parts']
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene; scene.unit_settings.system='METRIC'
mapping={}
for old in original.objects:
    new=old.copy()
    if old.data: new.data=old.data.copy()
    new.name=old.name.replace(BASE,STEM)
    if new.data: new.data.name=new.name+'_Data'
    scene.collection.objects.link(new); mapping[old]=new
for old,new in mapping.items():
    new.parent=mapping.get(old.parent)
    for mod in new.modifiers:
        if mod.type=='ARMATURE': mod.object=mapping[mod.object]
parts=[mapping[o] for o in base_parts]
rig=next(o for o in mapping.values() if o.type=='ARMATURE')
root=mapping[next(o for o in original.objects if o.type=='EMPTY' and o.parent is None)]
rig.animation_data_clear(); root.animation_data_clear()
scene.camera=mapping[original.camera]; scene.world=original.world.copy()
scene.world.name=STEM+'_World'
scene.render.engine='BLENDER_EEVEE'; scene.render.fps=24
scene.render.resolution_x=700; scene.render.resolution_y=700; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
material=parts[0].data.materials[0].copy(); material.name=STEM+'_Pixel_Material'
for node in material.node_tree.nodes:
    if node.type=='TEX_IMAGE':
        suffix='emission' if 'emission' in node.image.name else 'albedo'
        shutil.copyfile(ROOT/'assets/generated/dragons'/BASE/(BASE+'_'+suffix+'.png'),OUT/(STEM+'_'+suffix+'.png'))
        node.image=node.image.copy(); node.image.name=STEM+'_'+suffix
        node.image.filepath=str(OUT/(STEM+'_'+suffix+'.png')); node.image.pack()
for obj in parts:
    obj.data.materials.clear(); obj.data.materials.append(material)

# Keep the underside root web attached to the chest, not half attached to a
# rotating wing. All other approved geometry, topology and texture UVs stay intact.
for suffix in ('L','R'):
    surface=next(o for o in parts if o['part']=='Continuous_wing_membrane_'+suffix)
    count=len(surface.data.vertices)//2; indices=[count-1,len(surface.data.vertices)-1]
    for group in surface.vertex_groups: group.remove(indices)
    group=surface.vertex_groups.get('chest') or surface.vertex_groups.new(name='chest')
    group.add(indices,1.0,'REPLACE')

# A non-deforming mouth socket follows the upper jaw/head and points forward.
for obj in scene.objects: obj.select_set(False)
rig.select_set(True); bpy.context.view_layer.objects.active=rig
head_origin=Vector((0,-1.18,1.94)); R=Euler((math.radians(4),0,0)).to_matrix()
old_source=ROOT/'tools/art_pipeline/build_dark_red_dragon_v4_mcp.py'
factor=-rig.data.bones['head'].head_local.y/1.18
if BASE in bpy.app.driver_namespace: factor=bpy.app.driver_namespace[BASE]['native_scale']
shift=rig.data.bones['head'].head_local-head_origin*factor
socket=head_origin+R@Vector((0,-1.075,-.28)); socket=socket*factor+shift
forward=R@Vector((0,-1,0))
bpy.ops.object.mode_set(mode='EDIT')
socket_bone=rig.data.edit_bones.new('mouth_fire'); socket_bone.head=socket; socket_bone.tail=socket+forward*.16
socket_bone.parent=rig.data.edit_bones['head']; socket_bone.use_deform=False
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=False

rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
restq={n:m.to_quaternion() for n,m in rest.items()}
restinv={n:m.inverted() for n,m in rest.items()}
resthead={b.name:b.head_local.copy() for b in rig.data.bones}
restvec={b.name:b.tail_local-b.head_local for b in rig.data.bones}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
limbs={}; pole={}; sole={}; targets={}; reach_errors=[]
ground_rotation=Euler((math.radians(-20),0,0)).to_matrix()
for kind in ('Front','Hind'):
    for side in ('L','R'):
        key=kind+'_'+side
        a=kind+'_upper_'+side; b=kind+'_lower_'+side; c=kind+'_hand_'+side
        limbs[key]=(a,b,c)
        h,k,w=(resthead[n] for n in (a,b,c)); direction=(w-h).normalized()
        pole[key]=((k-h)-direction*(k-h).dot(direction)).normalized()
        points=[ground_rotation@(v.co-w) for obj in parts if obj['rig_bone']==c for v in obj.data.vertices]
        sole[key]=-min(v.z for v in points)+.002
        targets[key]=Vector((w.x,w.y,sole[key]))

def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)

def rotate(name,angles):
    rig.pose.bones[name].rotation_quaternion=restq[name].inverted()@Euler(angles,'XYZ').to_quaternion()@restq[name]

def degrees(name,x=0,y=0,z=0): rotate(name,tuple(math.radians(v) for v in (x,y,z)))

def move(name,delta): rig.pose.bones[name].location=restq[name].inverted()@Vector(delta)

def plant(key,target,clip,frame):
    a,b,c=limbs[key]; upper,lower,hand=(rig.pose.bones[n] for n in (a,b,c))
    bpy.context.view_layer.update(); hip=upper.head.copy(); line=target-hip
    l1,l2=restvec[a].length,restvec[b].length; length=line.length
    if length>l1+l2-1e-5 or length<abs(l1-l2)+1e-5:
        reach_errors.append({'clip':clip,'frame':frame,'leg':key,'reach':length,'maximum':l1+l2})
    d=max(abs(l1-l2)+1e-5,min(length,l1+l2-1e-5)); direction=line.normalized()
    along=(l1*l1-l2*l2+d*d)/(2*d); height=math.sqrt(max(0,l1*l1-along*along))
    bend=pole[key]-direction*pole[key].dot(direction); bend.normalize()
    knee=hip+direction*along+bend*height
    q=restvec[a].rotation_difference(knee-hip)@restq[a]
    upper.matrix=Matrix.Translation(hip)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    q=restvec[b].rotation_difference(target-knee)@restq[b]
    lower.matrix=Matrix.Translation(knee)@q.to_matrix().to_4x4(); bpy.context.view_layer.update()
    hand.matrix=Matrix.Translation(target)@(ground_rotation@restq[c].to_matrix()).to_4x4()
    bpy.context.view_layer.update()

def smooth(t):
    t=max(0,min(1,t)); return t*t*t*(t*(t*6-15)+10)

def footpath(u,half,lift):
    u%=1.0
    if u<.64: return -half+2*half*u/.64,0.0
    f=(u-.64)/.36
    return half-2*half*smooth(f),lift*math.sin(math.pi*f)**2

def tail_motion(p,amplitude=1.0):
    for i in range(27):
        fade=1.0 if i<13 else .55
        degrees('tail_%02d'%i,x=.30*amplitude*math.sin(p-.20*i),
                z=.72*fade*amplitude*math.sin(p-.23*i-.5))

def grounded(seconds,walking,attack,clip,frame):
    duration=1.5 if walking else 3.0; t=seconds/duration; p=math.tau*t
    breath=(1-math.cos(p))*.5
    pre=smooth(seconds/.60)*(1-smooth((seconds-.55)/.25)) if attack else 0
    fire=smooth((seconds-.58)/.22)*(1-smooth((seconds-2.05)/.75)) if attack else 0
    move('root',(.010*math.sin(p) if walking else 0,.055*pre-.025*fire,
                 -.42+(.009*math.cos(2*p) if walking else .007*breath)-.016*pre))
    degrees('chest',x=(.7*math.cos(2*p) if walking else .7*breath)-4*pre+2.5*fire,
            z=-1.2*math.sin(p) if walking else .35*math.sin(p))
    degrees('hips',x=.5*math.cos(2*p) if walking else .35*breath,
            y=1.0*math.sin(p) if walking else 0,z=.9*math.sin(p) if walking else 0)
    degrees('neck_01',x=.65*breath-12*pre+4*fire,z=.55*math.sin(p))
    degrees('neck_02',x=-.45*breath+8*pre-3*fire,z=-.35*math.sin(p))
    degrees('head',x=.35*math.sin(p)+2*pre-3.5*fire,z=-.35*math.sin(p))
    degrees('jaw',x=(34+1.1*math.sin(seconds*22))*fire)
    tail_motion(p,.85 if walking else .45)
    if attack:
        degrees('tail_00',x=.30*.45*math.sin(p)+6*pre+1.5*fire,
                z=.72*.45*math.sin(p-.5))
    for side,s in [('L',1),('R',-1)]:
        degrees('wing_upper_'+side,x=-20+.6*breath,y=s*(20+.5*breath),z=s*(55+.6*math.sin(p)))
        degrees('wing_fore_'+side,x=-8+.5*breath,y=s*.5*math.sin(p-.4))
        degrees('wing_fingers_'+side,x=-5+.5*breath,y=s*.4*math.sin(p-.8))
    phases={'Hind_L':0,'Front_L':.25,'Hind_R':.5,'Front_R':.75}
    for key in limbs:
        target=targets[key].copy()
        if walking:
            dy,lift=footpath(t+phases[key],.13 if key.startswith('Front') else .12,.082 if key.startswith('Front') else .071)
            target+=Vector((0,dy,lift))
        plant(key,target,clip,frame)
        sample_targets[(clip,frame,key)]=tuple(target)

def airborne(seconds,moving,attack):
    duration=1.5 if moving else 1.0; t=seconds/duration; p=math.tau*t
    u=t%1.0
    stroke=(smooth(u/.36) if u<.36 else 1.0 if u<.57 else 1-smooth((u-.57)/.43)) if moving else (1-math.cos(p))*.5
    flap=-12+87*stroke if moving else 4+70*stroke
    pre=smooth(seconds/.60)*(1-smooth((seconds-.55)/.25)) if attack else 0
    fire=smooth((seconds-.58)/.22)*(1-smooth((seconds-2.05)/.75)) if attack else 0
    pitch=(10 if moving else 1.4*math.sin(p-.3))
    move('root',(.012*math.sin(p) if moving else .008*math.sin(p/2),.028*pre-.018*fire,
                 (.55 if moving else .46)+(.085 if moving else .065)*math.sin(p-.65)))
    degrees('root',x=pitch,y=.7*math.sin(p),z=.45*math.sin(p))
    degrees('chest',x=.8*math.sin(p-.5)-3*pre+2*fire)
    degrees('hips',x=.8*math.sin(p-1.1),z=.6*math.sin(p-.8))
    degrees('neck_01',x=(-4 if moving else -.7*math.sin(p-.3))-11*pre+4*fire)
    degrees('neck_02',x=(-3 if moving else -.4*math.sin(p-.5))+7*pre-3*fire)
    degrees('head',x=(-3 if moving else -.3*math.sin(p-.8))+2*pre-3*fire,z=.45*math.sin(p-.5))
    degrees('jaw',x=(34+.9*math.sin(seconds*22))*fire)
    tail_motion(p,1.15 if moving else .85)
    for side,s in [('L',1),('R',-1)]:
        degrees('wing_upper_'+side,x=-3,y=s*flap,z=s*(-4+2*math.sin(p)))
        degrees('wing_fore_'+side,x=-1.5*math.cos(p),y=-s*4*math.sin(p-.45))
        degrees('wing_fingers_'+side,x=1.5*math.sin(p-.5),y=-s*5*math.sin(p-.9))
        degrees('Front_upper_'+side,x=-18+1.2*math.sin(p-.7))
        degrees('Front_lower_'+side,x=38+1.8*math.sin(p-1.1))
        degrees('Front_hand_'+side,x=8+1.0*math.sin(p-1.4))
        degrees('Hind_upper_'+side,x=15+1.2*math.sin(p-.9))
        degrees('Hind_lower_'+side,x=-32+1.4*math.sin(p-1.3))
        degrees('Hind_hand_'+side,x=12+.9*math.sin(p-1.5))

# Fast CPU skinning checks, including floor clearance of the actual claws.
bone_names=list(rest); bone_index={n:i for i,n in enumerate(bone_names)}
vertices=[]; grouped={}; hand_indices={key:[] for key in limbs}
for obj in parts:
    start=len(vertices)
    for v in obj.data.vertices:
        index=len(vertices); vertices.append(tuple(v.co)+(1.0,))
        for g in v.groups:
            name=obj.vertex_groups[g.group].name
            grouped.setdefault(name,[]).append((index,g.weight))
        for key,(_,_,c) in limbs.items():
            if obj['rig_bone']==c: hand_indices[key].append(index)
vertices=np.array(vertices,dtype=np.float64)
grouped={name:(np.array([r[0] for r in rows]),np.array([r[1] for r in rows])[:,None]) for name,rows in grouped.items()}
def skin_points():
    result=np.zeros((len(vertices),3))
    for name,(indices,weights) in grouped.items():
        matrix=np.array(rig.pose.bones[name].matrix@restinv[name])
        result[indices]+=(vertices[indices]@matrix.T)[:,:3]*weights
    return result

clip_specs=[('Dragon_Idle_Ground',3.0,True,False,False,False),
    ('Dragon_Idle_Flying',2.0,True,True,False,False),
    ('Dragon_Walk_Ground',1.5,True,False,True,False),
    ('Dragon_Walk_Flying',1.5,True,True,True,False),
    ('Dragon_Attack_Ground',3.0,False,False,False,True),
    ('Dragon_Attack_Flying',3.0,False,True,False,True)]
clips={}; sample_targets={}; previous_quat={}; validation={}; timeline=1
rig.animation_data_create()
for name,duration,loop,flying,walking,attack in clip_specs:
    action=bpy.data.actions.new(STEM+'_'+name); action.use_fake_user=True
    rig.animation_data.action=action; end=1+round(duration*24)
    data={'action':action,'start':1,'end':end,'duration_seconds':duration,'loop':loop,
          'flying':flying,'walking':walking,'attack':attack,'nla_start':timeline}
    if attack: data.update(fire_start_seconds=.75,fire_end_seconds=2.0,fire_start_frame=19,fire_end_frame=49,mouth_socket='mouth_fire')
    if name=='Dragon_Walk_Ground': data['suggested_translation_mps']=.26/(.64*duration)
    clips[name]=data; stats={'samples':end,'minimum_geometry_z':100.0,'maximum_foot_target_error':0.0,'loop_matrix_error':0.0}
    first=None
    for frame in range(1,end+1):
        scene.frame_set(frame); reset(); seconds=(frame-1)/24
        if flying: airborne(seconds,walking,attack)
        else: grounded(seconds,walking,attack,name,frame)
        bpy.context.view_layer.update()
        pose=[np.array(pb.matrix) for pb in rig.pose.bones]
        if first is None: first=pose
        if frame==end: stats['loop_matrix_error']=max(float(np.max(np.abs(a-b))) for a,b in zip(first,pose))
        points=skin_points(); stats['minimum_geometry_z']=min(stats['minimum_geometry_z'],float(points[:,2].min()))
        assert np.isfinite(points).all(),(name,frame)
        if not flying:
            for key,(_,_,c) in limbs.items():
                error=(rig.pose.bones[c].head-Vector(sample_targets[(name,frame,key)])).length
                stats['maximum_foot_target_error']=max(stats['maximum_foot_target_error'],error)
        for pb in rig.pose.bones:
            q=pb.rotation_quaternion.copy()
            if pb.name in previous_quat and q.dot(previous_quat[pb.name])<0:
                q.negate(); pb.rotation_quaternion=q
            previous_quat[pb.name]=q.copy()
            for path in ('location','rotation_quaternion','scale'): pb.keyframe_insert(data_path=path,frame=frame,group=pb.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    action['loop']=loop; action['fps']=24
    if attack:
        action.pose_markers.new('FIRE_START').frame=19; action.pose_markers.new('FIRE_END').frame=49
    else:
        action.pose_markers.new('LOOP_START').frame=1; action.pose_markers.new('LOOP_END').frame=end
    validation[name]=stats; timeline+=end+18
assert not reach_errors,reach_errors[:12]
assert all(v['maximum_foot_target_error']<1e-4 for v in validation.values()),validation
assert all(v['minimum_geometry_z']>-.003 for v in validation.values()),validation
assert all(validation[n]['loop_matrix_error']<2e-5 for n in clips if clips[n]['loop']),validation
rig.animation_data.action=None
for name,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,data['nla_start'],data['action']); strip.extrapolation='NOTHING'
    strip.action_frame_start=1; strip.action_frame_end=data['end']; strip.blend_type='REPLACE'
    scene.timeline_markers.new(name,frame=data['nla_start'])
scene.frame_start=1; scene.frame_end=timeline; scene.frame_set(1)

# Studio ground is source/preview only, never selected for game export.
ground_data=bpy.data.meshes.new(STEM+'_StudioGround'); ground_data.from_pydata([(-30,-30,-.004),(30,-30,-.004),(30,30,-.004),(-30,30,-.004)],[],[(0,1,2,3)])
ground=bpy.data.objects.new(ground_data.name,ground_data); scene.collection.objects.link(ground)
ground_mat=bpy.data.materials.new(STEM+'_StudioGround'); ground_mat.use_nodes=True
ground_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.12,.13,.14,1)
ground_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1
ground.data.materials.append(ground_mat)
for obj in scene.objects: obj.select_set(False)
rig.select_set(True); bpy.context.view_layer.objects.active=rig
rig['mouth_socket']='mouth_fire'; rig['animation_notes']='Baked planted-paw IK; no runtime constraints or VFX; complete matching tracks in all six clips.'
state={'scene':scene,'rig':rig,'root':root,'parts':parts,'out':OUT,'clips':clips,
       'validation':validation,'ground':ground,'material':material,'protected':protected,'targets':sample_targets}
bpy.app.driver_namespace[STEM]=state
(OUT/'animation_validation.json').write_text(json.dumps({'status':'PASS','bones':len(rest),'unreachable_targets':reach_errors,'clips':validation},indent=2),encoding='utf-8')
print(json.dumps({'scene':NAME,'bones':len(rest),'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()},'validation':validation}))
