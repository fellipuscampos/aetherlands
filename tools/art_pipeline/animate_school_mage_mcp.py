"""Rig, bake and verify one approved mage in the live Blender MCP.

Injected MAGE_RACE and MAGE_SCHOOL select exactly one asset.
"""
import bpy,bmesh,ast,json,math,hashlib,sys,importlib,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/school_mages_animation_review'
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
import school_mage_motion as motion
importlib.reload(motion)
FPS=motion.FPS; LENGTHS=motion.LENGTHS; STARTS=motion.STARTS
asset=next(a for a in bpy.app.driver_namespace[MAGE_RACE+'_school_mage_assets_v1'] if a['report']['school']==MAGE_SCHOOL)
scene=asset['scene']; root=asset['root']; stem=root.name
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.window.scene=scene
def stage(label,frame=None): (WORK/'current_stage.json').write_text(json.dumps(dict(asset=stem,stage=label,frame=frame)),encoding='utf-8')

source=(ROOT/'tools/art_pipeline/animate_settlers_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in {'T','Q','around','midpoint','face_end','shape_hash','rig_specs','part_bone','create_rig'}:
        code=ast.get_source_segment(source,node).replace('settler_animation_owned','school_mage_animation_owned').replace('Settler_Rigid_Skin','Mage_Rigid_Skin')
        exec(compile(code,'<approved_rigid_humanoid_rig>','exec'),globals())

stage('preserve_approved_geometry')
approved={o['part']:shape_hash(o) for o in asset['parts']}
baseline=WORK/(stem+'_bind_geometry.json')
if baseline.exists(): assert json.loads(baseline.read_text())==approved,'Approved geometry or UVs changed'
else: baseline.write_text(json.dumps(approved,indent=2),encoding='utf-8')
for old in [o for o in scene.objects if o.get('school_mage_animation_owned')]:
    for o in asset['parts']:
        for mod in list(o.modifiers):
            if mod.type=='ARMATURE' and mod.object==old: o.modifiers.remove(mod)
        o.vertex_groups.clear()
    data=old.data; bpy.data.objects.remove(old,do_unlink=True)
    if data.users==0: bpy.data.armatures.remove(data)
for action in [a for a in bpy.data.actions if a.get('mage_animation_asset')==stem]:
    if action.users<=1: bpy.data.actions.remove(action)
scene.frame_set(1); stage('create_rig')
bones,chains=rig_specs(asset); rig=create_rig(asset,bones)
rig['mage_animation_asset']=stem; rig['choreography_revision']=motion.REVISION
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}; inverse={n:m.inverted() for n,m in rest.items()}; actions={}
rig.animation_data_create()
for clip,count in LENGTHS.items():
    stage('bake_'+clip)
    action=bpy.data.actions.new(stem+'_'+clip); action.use_fake_user=True
    action['mage_animation_asset']=stem; action['fps']=FPS; action['loop']=clip!='spell'
    action['description']=motion.STYLE[MAGE_RACE]['description'] if clip=='spell' else 'Respiração e atenção discretas.' if clip=='idle' else 'Caminhada no lugar, pés apoiados e cetro firme na mão.'
    rig.animation_data.action=action; previous={}
    for frame in range(count):
        desired=motion.pose(MAGE_RACE,clip,frame/(count-1),bones,chains)
        for name,delta in desired.items():
            bone=rig.pose.bones[name]; bone.matrix_basis=inverse[name]@delta@rest[name]
            if name in previous and previous[name].dot(bone.rotation_quaternion)<0: bone.rotation_quaternion.negate()
            previous[name]=bone.rotation_quaternion.copy()
            bone.keyframe_insert('rotation_quaternion',frame=frame+1,group=name); bone.keyframe_insert('location',frame=frame+1,group=name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    action.pose_markers.new('START').frame=1; action.pose_markers.new('END').frame=count
    if clip=='spell': action.pose_markers.new('SPELL_RELEASE').frame=1+round(motion.STYLE[MAGE_RACE]['release']*(count-1))
    actions[clip]=action
rig.animation_data.action=None
for bone in rig.pose.bones: bone.matrix_basis.identity()
for clip,action in actions.items():
    track=rig.animation_data.nla_tracks.new(); track.name=clip
    strip=track.strips.new(clip,STARTS[clip],action); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
scene.render.fps=FPS; scene.frame_start=1; scene.frame_end=385; scene.frame_set(1)
scene.timeline_markers.clear()
for clip,start in STARTS.items(): scene.timeline_markers.new(clip.upper(),frame=start)
scene.timeline_markers.new('SPELL_RELEASE',frame=241+round(motion.STYLE[MAGE_RACE]['release']*144))
scene['animation_clips']=['idle','walk','spell']; scene['walk_in_place']=True
asset.update(rig=rig,bones=bones,chains=chains,actions=actions)

def box_intersects(first,second):
    axes=[]
    for pts in (first,second):
        for index in (1,2,4):
            v=pts[index]-pts[0]; axes.append(v/np.linalg.norm(v))
    axes.extend(np.cross(a,b) for a in axes[:3] for b in axes[3:6])
    for v in axes:
        if np.linalg.norm(v)<1e-7: continue
        v=v/np.linalg.norm(v); x=first@v; y=second@v
        if min(x.max(),y.max())-max(x.min(),y.min())<=1e-6: return False
    return True

def coordinates(obj,delta):
    return np.array([list(delta@v.co) for v in obj.data.vertices])

stage('validate_baked_motion')
by={o['part']:o for o in asset['parts']}; shaft=asset['staff']; fore=by['Forearm_r']; hand=by['Hand_r']
assert shaft['animation_bone']=='hand_r' and len(rig.data.bones)==16
assert {o['part']:shape_hash(o) for o in asset['parts']}==approved
for obj in asset['parts']:
    assert len(obj.vertex_groups)==1 and all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in obj.data.vertices)
clips={}; speed=motion.STYLE[MAGE_RACE]['stride']/.62/1.5
for clip,count in LENGTHS.items():
    first=None; last=None; previous=None; max_step=0; motion_size=0; min_floor=1e9; max_gap=0; max_foot_error=0; max_slide=0; contacts={}; intersections=0; detached=0
    max_elbow_roll=0; max_wrist={'l':0,'r':0}; max_arm_step=0; max_arm_acceleration=0; previous_quats={}; previous_steps={}; torso_hits=0
    for frame in range(count):
        scene.frame_set(STARTS[clip]+frame); scene.view_layers[0].update()
        delta={b.name:b.matrix@inverse[b.name] for b in rig.pose.bones}
        data=np.array([list(row) for m in delta.values() for row in m])
        if first is None: first=data.copy()
        if previous is not None: max_step=max(max_step,float(np.abs(data-previous).max()))
        motion_size=max(motion_size,float(np.abs(data-first).max())); previous=data.copy(); last=data
        assert np.abs(np.array(delta['root'])-np.eye(4)).max()<1e-6,'Root motion'
        assert all(abs(m.to_3x3().determinant()-1)<1e-5 for m in delta.values()),'Limb scaling'
        for obj in asset['parts']:
            transform=delta[obj['animation_bone']]
            min_floor=min(min_floor,min((transform@v.co).z for v in obj.data.vertices))
        for side in ('l','r'):
            a,b,c=chains['leg_'+side]; aa,bb,cc,_=chains['arm_'+side]
            max_gap=max(max_gap,(delta['thigh_'+side]@a-delta['hips']@a).length,(delta['thigh_'+side]@b-delta['shin_'+side]@b).length,(delta['shin_'+side]@c-delta['foot_'+side]@c).length,(delta['upper_arm_'+side]@aa-delta['chest']@aa).length,(delta['upper_arm_'+side]@bb-delta['forearm_'+side]@bb).length,(delta['forearm_'+side]@cc-delta['hand_'+side]@cc).length)
            phase=(frame/(count-1)+(0 if side=='l' else .5))%1
            if clip!='walk' or phase<.62:
                foot=delta['foot_'+side]@c; max_foot_error=max(max_foot_error,abs(foot.z-c.z))
                world_point=foot+Vector((0,-speed*frame/FPS,0)) if clip=='walk' else foot
                if side in contacts and (clip!='walk' or phase>contacts[side][0]): max_slide=max(max_slide,(world_point-contacts[side][1]).length)
                contacts[side]=(phase,world_point)
            else: contacts.pop(side,None)
            up=delta['upper_arm_'+side].to_quaternion(); low=delta['forearm_'+side].to_quaternion(); palm=delta['hand_'+side].to_quaternion()
            rest_axis=(cc-bb).normalized(); relative=up.inverted()@low
            swing=rest_axis.rotation_difference(relative@rest_axis)
            angle=math.degrees((swing.inverted()@relative).angle)
            max_elbow_roll=max(max_elbow_roll,min(angle,360-angle))
            angle=math.degrees((low.inverted()@palm).angle)
            max_wrist[side]=max(max_wrist[side],min(angle,360-angle))
            for name in ('upper_arm_'+side,'forearm_'+side,'hand_'+side):
                q=delta[name].to_quaternion()
                if name in previous_quats:
                    step=previous_quats[name].rotation_difference(q)
                    if step.w<0: step.negate()
                    max_arm_step=max(max_arm_step,math.degrees(step.angle))
                    if name in previous_steps:
                        turn=previous_steps[name].rotation_difference(step)
                        angle=math.degrees(turn.angle); max_arm_acceleration=max(max_arm_acceleration,min(angle,360-angle))
                    previous_steps[name]=step
                previous_quats[name]=q
        staff_coords=coordinates(shaft,delta['hand_r'])
        if box_intersects(staff_coords,coordinates(fore,delta['forearm_r'])): intersections+=1
        if not box_intersects(staff_coords,coordinates(hand,delta['hand_r'])): detached+=1
        for tag in ('Forearm_l','Hand_l','Forearm_r','Hand_r'):
            obj=by[tag]
            for body in ('Chest','Belly'):
                if box_intersects(coordinates(obj,delta[obj['animation_bone']]),coordinates(by[body],delta[by[body]['animation_bone']])): torso_hits+=1
    closure=float(np.abs(last-first).max())
    row=dict(frames=count,seconds=(count-1)/FPS,loop=clip!='spell',end_to_start_error=closure,min_ground_z=min_floor,max_joint_gap_m=max_gap,max_frame_step=max_step,movement=motion_size,max_planted_foot_z_error_m=max_foot_error,max_planted_foot_slide_m=max_slide,staff_forearm_intersections=intersections,staff_hand_detachments=detached,max_elbow_axial_roll_degrees=max_elbow_roll,max_wrist_rotation_degrees=max_wrist,max_arm_frame_rotation_degrees=max_arm_step,max_arm_frame_acceleration_degrees=max_arm_acceleration,hand_forearm_torso_intersections=torso_hits)
    print('MAGE_MOTION_CHECK',stem,clip,json.dumps(row))
    assert closure<1e-5 and min_floor>-.00003 and max_gap<.00003 and max_step<.15 and motion_size>.005,(stem,clip,'motion',row)
    assert max_foot_error<.00003 and max_slide<.00003,(stem,clip,'planted foot',row)
    assert intersections==0 and detached==0,(stem,clip,'staff grip',row)
    assert max_elbow_roll<.25 and max_wrist['l']<6 and max_wrist['r']<(1 if clip=='spell' else 25),(stem,clip,'anatomical arm orientation',row)
    assert max_arm_step<4.5 and max_arm_acceleration<1.0 and torso_hits==0,(stem,clip,'arm continuity and clearance',row)
    clips[clip]=row
scene.frame_set(1); scene.view_layers[0].update()
report=asset['report']; report.update(animations=3,rigging_deferred=False,static_review=False,stage='animated_review')
report['geometry'].update(animations=3,rigs=1)
animation=dict(status='PASS',fps=FPS,bones=16,rigid_skinning=True,root_motion=False,arm_motion='fixed_anatomical_elbow_hinge_with_forearm_following_hand',walk_speed_m_per_s=speed,approved_geometry_and_uvs_preserved=True,choreography_revision=motion.REVISION,casting_name=motion.STYLE[MAGE_RACE]['name'],casting_description=motion.STYLE[MAGE_RACE]['description'],same_casting_for_all_schools=True,spell_release_seconds=motion.STYLE[MAGE_RACE]['release']*3,clips=clips)
asset['animation']=animation; report['animation']=animation
(WORK/(stem+'_animation_validation.json')).write_text(json.dumps(dict(status='PASS',stem=stem,race=MAGE_RACE,school=MAGE_SCHOOL,animation=animation),ensure_ascii=False,indent=2),encoding='utf-8')
stage('animation_verified')
result=dict(status='PASS',asset=stem,clips=['idle','walk','spell'],bones=16,approved_geometry_preserved=True)
