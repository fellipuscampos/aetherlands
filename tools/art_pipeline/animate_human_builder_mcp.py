"""Bake idle, walk and a bend/raise/strike/recover work gesture in live MCP."""
import bpy,json,math,hashlib,sys,shutil
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
CONFIG=globals().get('BUILDER_CONFIG',{})
RACE=CONFIG.get('race','human'); STEM=RACE+'_builder_v1'
HINGE_ARM=RACE in ('orc','dwarf')
OUT=ROOT/f"assets/generated/{CONFIG.get('family','humans')}/{STEM}"
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from dwarf_animation_motion import solve_chain
BACKUP=ROOT/f'art_source/{RACE}_builder_review/before_work_animation'; BACKUP.mkdir(parents=True,exist_ok=True)
(BACKUP.parent/'.gdignore').touch()
for name in (STEM+'.blend',STEM+'.glb',STEM+'_report.json'):
    if not (BACKUP/name).exists(): shutil.copy2(OUT/name,BACKUP/name)
scene=bpy.data.scenes.get(RACE.title()+'_Builder_V1')
if scene is None:
    with bpy.data.libraries.load(str(OUT/(STEM+'.blend')),link=False) as (available,loaded): loaded.scenes=[available.scenes[0]]
    scene=loaded.scenes[0]
bpy.context.window.scene=scene
rig=next(o for o in scene.objects if o.type=='ARMATURE'); root=rig.parent
parts=[o for o in scene.objects if o.type=='MESH' and o.get('builder_asset')]
shape_hash=hashlib.sha256(str([(o['part'],[tuple(v.co) for v in o.data.vertices]) for o in parts]).encode()).hexdigest()
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}; snapshots={}
for track in rig.animation_data.nla_tracks:
    if track.name not in ('idle','walk'): continue
    for other in rig.animation_data.nla_tracks: other.mute=other!=track
    strip=track.strips[0]; poses=[]
    for f in range(int(strip.frame_start),int(strip.frame_end)+1):
        scene.frame_set(f); bpy.context.view_layer.update(); poses.append({b.name:b.matrix.copy() for b in rig.pose.bones})
    snapshots[track.name]=poses
assert set(snapshots)=={'idle','walk'}
base=snapshots['idle'][0]; base_delta={n:base[n]@rest[n].inverted() for n in rest}
T=Matrix.Translation
def around(point,rotation): return T(point)@rotation@T(-point)
def smooth(t): t=max(0,min(1,t)); return t*t*(3-2*t)
def envelope(t,a,b): return smooth((t-a)/(b-a))
def delta_hand(wrist,rotation): return T(wrist)@rotation@T(-rest['hand_r'].translation)
base_hand_rotation=base_delta['hand_r'].to_3x3().to_4x4()
work=[]; hammer_positions=[]; arm_reach_errors=[]
by={o['part']:o for o in parts}
hammer_head=sum((v.co for v in by['Hammer_head'].data.vertices),Vector())/8
for i in range(145):
    t=i/144; bend=envelope(t,0,.20)*(1-envelope(t,.80,1))
    lift=envelope(t,.20,.40); strike=envelope(t,.45,.56); recover=envelope(t,.64,.85)
    hips=T((0,0,-.028*bend))@base_delta['hips']
    chest=hips@base_delta['hips'].inverted()@base_delta['chest']@around(rest['chest'].translation,Matrix.Rotation(math.radians(16*bend),4,'X'))
    head=chest@base_delta['chest'].inverted()@base_delta['head']@around(rest['head'].translation,Matrix.Rotation(math.radians(5*bend),4,'X'))
    deltas={'root':base_delta['root'],'hips':hips,'chest':chest,'head':head}
    for side in ('l','r'):
        names=['thigh_'+side,'shin_'+side,'foot_'+side]; a,b,c=[rest[n].translation for n in names]
        target=base_delta['foot_'+side]@c
        upper,lower,actual=solve_chain(a,b,c,hips@a,target,Vector((0,-1,0)))
        deltas.update({names[0]:upper,names[1]:lower,names[2]:T(actual-target)@base_delta[names[2]]})
    # Free left arm follows the modest torso lean, without another tool.
    for name in ['upper_arm_l','forearm_l','hand_l']:
        deltas[name]=chest@base_delta['chest'].inverted()@base_delta[name]
    if HINGE_ARM:
        # A shoulder and elbow hinge keep the thick square limbs in one
        # sagittal plane. Carry the wrist and hammer rigidly with the forearm.
        shoulder_angle=(-20*lift+38*strike)*(1-recover)
        elbow_angle=(-20*lift+50*strike)*(1-recover)
        follow=chest@base_delta['chest'].inverted()
        upper_turn=follow@around(base['upper_arm_r'].translation,Matrix.Rotation(math.radians(shoulder_angle),4,'X'))
        fore_turn=upper_turn@around(base['forearm_r'].translation,Matrix.Rotation(math.radians(elbow_angle),4,'X'))
        deltas.update(upper_arm_r=upper_turn@base_delta['upper_arm_r'],
                      forearm_r=fore_turn@base_delta['forearm_r'],
                      hand_r=fore_turn@base_delta['hand_r'])
        arm_reach_errors.append(0.0)
    else:
        a,b,c=[rest[n].translation for n in ['upper_arm_r','forearm_r','hand_r']]
        shoulder=chest@a
        start_wrist=(chest@base_delta['chest'].inverted()@base_delta['hand_r'])@c
        raised=shoulder+Vector((-.015,-.36,.04)); hit=shoulder+Vector((-.015,-.41,-.23))
        radius=((b-a).length+(c-b).length)*.96
        for p in (raised,hit):
            if (p-shoulder).length>radius: p[:]=shoulder+(p-shoulder).normalized()*radius
        target=start_wrist.lerp(raised,lift).lerp(hit,strike).lerp(start_wrist,recover)
        pitch=(-18*lift+103*strike)*(1-recover)
        rotation=Matrix.Rotation(math.radians(pitch),4,'X')@base_hand_rotation
        hand=delta_hand(target,rotation)
        upper,fore,actual=solve_chain(a,b,c,shoulder,target,Vector((-1,.12,0)))
        arm_reach_errors.append((actual-target).length)
        deltas.update(upper_arm_r=upper,forearm_r=fore,hand_r=hand)
    pose={n:deltas[n]@rest[n] for n in rest}
    if i in (0,144): pose={n:m.copy() for n,m in base.items()}
    work.append(pose); hammer_positions.append(list((pose['hand_r']@rest['hand_r'].inverted())@hammer_head))
assert max(arm_reach_errors)<1e-5
snapshots['work']=work
# A steadier wrist supports the hammer's weight in the breathing and walking loops.
for clip in ('idle','walk'):
    if CONFIG.get('preserve_carry_clips',False): continue
    for i,pose in enumerate(snapshots[clip]):
        t=i/(len(snapshots[clip])-1)
        angle=(.45 if clip=='idle' else 2.0)*math.sin(t*math.tau)
        rotation=Matrix.Rotation(math.radians(angle),4,'X')@base_hand_rotation
        pose['hand_r']=delta_hand(pose['hand_r'].translation,rotation)@rest['hand_r']
if HINGE_ARM:
    # The source rig uses independent bones. Parent the working arm so
    # interpolation preserves the elbow and wrist attachments exactly.
    for obj in scene.objects: obj.select_set(False)
    rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for child,parent in [('upper_arm_r','chest'),('forearm_r','upper_arm_r'),('hand_r','forearm_r')]:
        rig.data.edit_bones[child].parent=rig.data.edit_bones[parent]
        rig.data.edit_bones[child].use_connect=False
    bpy.ops.object.mode_set(mode='OBJECT')
    assert all(max(abs(b.matrix_local[i][j]-rest[b.name][i][j]) for i in range(4) for j in range(4))<1e-6 for b in rig.data.bones)
rig.animation_data_clear(); rig.animation_data_create(); clips=[]
for clip,start in [('idle',1),('walk',161),('work',249)]:
    poses=snapshots[clip]; action=bpy.data.actions.new(STEM+'_'+clip+'_Animated')
    rig.animation_data.action=action
    for frame,pose in enumerate(poses,1):
        for bone in rig.pose.bones:
            if HINGE_ARM:
                parent_args={'parent_matrix':pose[bone.parent.name],'parent_matrix_local':rest[bone.parent.name]} if bone.parent else {}
                bone.matrix_basis=bone.bone.convert_local_to_pose(pose[bone.name],rest[bone.name],invert=True,**parent_args)
            else:
                bone.matrix=pose[bone.name]
        for bone in rig.pose.bones:
            bone.rotation_mode='QUATERNION'; bone.keyframe_insert(data_path='location',frame=frame); bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
    clips.append((clip,start,len(poses),action,rig.animation_data.action_slot))
rig.animation_data.action=None
for clip,start,count,action,slot in clips:
    track=rig.animation_data.nla_tracks.new(); track.name=clip
    strip=track.strips.new(clip,start,action); strip.action_slot=slot; strip.frame_end=start+count-1
    strip.action_frame_start=1; strip.action_frame_end=count; strip.blend_type='REPLACE'
scene.render.fps=48; scene.frame_end=393; scene.frame_set(1); bpy.context.view_layer.update()
vertices=[];faces=[];uvs=[];spans=[]
for obj in parts:
    offset=len(vertices);vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons);uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    spans.append((obj['animation_bone'],offset,len(obj.data.vertices)))
data=bpy.data.meshes.new(STEM+'_ThreeClips');data.from_pydata(vertices,[],faces);data.update();data.materials.append(parts[0].data.materials[0])
uv=data.uv_layers.new(name='UVMap')
for loop,value in zip(uv.data,uvs):loop.uv=value
runtime=bpy.data.objects.new(STEM+'_Body',data);scene.collection.objects.link(runtime);runtime.parent=rig
groups={b.name:runtime.vertex_groups.new(name=b.name) for b in rig.data.bones}
for bone,start,count in spans:groups[bone].add(list(range(start,start+count)),1,'REPLACE')
modifier=runtime.modifiers.new('Builder_Skin','ARMATURE');modifier.object=rig
for obj in scene.objects:obj.select_set(False)
for obj in (root,rig,runtime):obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,
    export_yup=True,export_cameras=False,export_lights=False,export_extras=False,export_anim_slide_to_zero=True)
bpy.data.objects.remove(runtime,do_unlink=True)
assert shape_hash==hashlib.sha256(str([(o['part'],[tuple(v.co) for v in o.data.vertices]) for o in parts]).encode()).hexdigest()
report=json.loads((OUT/(STEM+'_report.json')).read_text(encoding='utf-8'))
report['clips']=['idle','walk','work']; report['animation']={'fps':48,'seconds':{'idle':3,'walk':1.5,'work':3},'work':'bend, raise, single air strike, recover','torso_bend_degrees':16,'geometry_unchanged':True,'maximum_arm_reach_error':max(arm_reach_errors),'hammer_head_samples':hammer_positions}
if HINGE_ARM:
    report['animation'].update(arm_motion='shoulder and elbow hinges in sagittal plane',wrist_locked_to_forearm=True,arm_hierarchy=['chest','upper_arm_r','forearm_r','hand_r'])
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
camera=scene.camera
for name,f in [('work_bend',277),('work_raise',307),('work_strike',330),('work_recover',375)]:
    scene.frame_set(f);bpy.context.view_layer.update();scene.render.filepath=str(OUT/'previews'/(name+'.png'));bpy.ops.render.render(write_still=True)
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'clips':['idle','walk','work'],'work_seconds':3,'bend_degrees':16,'arm_reach_error':max(arm_reach_errors),'geometry_unchanged':True}
