"""Fit class motions to wide orc anatomy and carry equipment with the hands.

The rig keeps the game's flat bone layout. Logical chest/head and limb chains
are solved before baking, rather than forcing big orc limbs onto elf wrists.
"""
import math
import bpy,numpy as np
from mathutils import Vector,Matrix,Quaternion
from build_orc_troops import action_curves,frame_for,solve_arm
from build_elf_troops import reset_pose
from human_texture_glb import read_glb

def accessor(doc,binary,index):
    info=doc['accessors'][index];view=doc['bufferViews'][info['bufferView']]
    dtype={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[info['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[info['type']]
    return np.ndarray((info['count'],count),dtype=dtype,buffer=binary,
        offset=view.get('byteOffset',0)+info.get('byteOffset',0),
        strides=(view.get('byteStride',np.dtype(dtype).itemsize*count),np.dtype(dtype).itemsize)).copy()


def sample_clips(scene,rig,glb_path):
    # Appended armatures can have stale evaluated pose caches in Blender.
    # Read the shipped class motion instead, including every bone channel.
    doc,binary=read_glb(glb_path.read_bytes())
    joint_ids=set(doc['skins'][0]['joints'])
    parents={child:i for i,node in enumerate(doc['nodes']) for child in node.get('children',[])}
    to_blender=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    def local_matrix(node,values):
        if 'matrix' in node and not values:return Matrix(np.array(node['matrix']).reshape(4,4).T.tolist())
        p=values.get('translation',node.get('translation',[0,0,0]))
        q=values.get('rotation',node.get('rotation',[0,0,0,1]))
        s=values.get('scale',node.get('scale',[1,1,1]))
        return Matrix.Translation(Vector(p))@Quaternion((q[3],q[0],q[1],q[2])).to_matrix().to_4x4()@Matrix.Diagonal(Vector((*s,1)))
    def global_pose(changes):
        cache={}
        def world(index):
            if index not in cache:
                m=local_matrix(doc['nodes'][index],changes.get(index,{}))
                cache[index]=world(parents[index])@m if parents.get(index) in joint_ids else m
            return cache[index]
        # glTF preserves each joint's Blender-local axes; only its world axes
        # are converted from Y-up to Z-up by the exporter.
        return {doc['nodes'][index]['name']:to_blender@world(index) for index in joint_ids}
    rest=global_pose({})
    for name,bone in rig.data.bones.items():
        assert max(abs(rest[name][i][j]-bone.matrix_local[i][j]) for i in range(4) for j in range(4))<.00008,(glb_path,name)
    animations={a['name']:a for a in doc['animations']}
    bpy.context.window.scene=scene;clips=[]
    for track in list(rig.animation_data.nla_tracks):
        strip=track.strips[0];samples=[];animation=animations[track.name]
        channels=[]
        for channel in animation['channels']:
            sampler=animation['samplers'][channel['sampler']]
            channels.append((channel['target']['node'],channel['target']['path'],accessor(doc,binary,sampler['input']).ravel(),accessor(doc,binary,sampler['output'])))
        for frame in range(round(strip.frame_start),round(strip.frame_end)+1):
            time=(frame-strip.frame_start)/scene.render.fps;changes={}
            for index,path,times,values in channels:
                pos=min(len(times)-1,max(0,int(np.searchsorted(times,time,side='right')-1)))
                if pos==len(times)-1 or abs(time-times[pos])<.000001:value=values[pos]
                else:
                    t=(time-times[pos])/(times[pos+1]-times[pos]);a=values[pos];b=values[pos+1]
                    if path=='rotation' and np.dot(a,b)<0:b=-b
                    value=a*(1-t)+b*t
                    if path=='rotation':value/=np.linalg.norm(value)
                changes.setdefault(index,{})[path]=value
            local=strip.action_frame_start+(frame-strip.frame_start)/strip.scale
            samples.append((local,global_pose(changes)))
        clips.append(dict(name=track.name,action=strip.action,frame_start=strip.frame_start,
            action_start=strip.action_frame_start,action_end=strip.action_frame_end,frames=samples))
    reset_pose(rig,scene)
    return clips


def correction(scene,rig,source_rig,clips,base_rig,base_by,row):
    old={b.name:b.matrix_local.copy() for b in source_rig.data.bones}
    baseline={b.name:b.matrix_local.copy() for b in base_rig.data.bones}
    base_chest=base_by['Chest'];base_head=base_by['Head']
    base_neck=max(v.co.z for v in base_chest.data.vertices)-baseline['chest'].translation.z
    preserve=row['key']=='squire'
    scale=1. if preserve else (old['head'].translation.z-old['chest'].translation.z)/base_neck
    head_raise=.015*scale
    shift={};pole_shift={};lengths={}
    head_local=np.array([list(baseline['head'].inverted()@v.co*scale) for v in base_head.data.vertices])
    chest_local=np.array([list(baseline['chest'].inverted()@v.co*scale) for v in base_chest.data.vertices])
    hand_radius={side:max((baseline['hand_'+side].inverted()@v.co).length for v in base_by['Hand_'+side].data.vertices)*scale for side in ('l','r')}
    for side,sign in (('l',1),('r',-1)):
        shoulder=Vector((sign*.17*scale,0,0)) if not preserve else Vector()
        dz=0.
        if row['family'] in ('warrior','rogue'):dz=-.16 if side=='l' else -.10
        elif row['family']=='guardian' and side=='r':dz=-.06
        elif row['family']=='cavalry':dz=-.02 if side=='l' else -.04
        wrist=Vector((sign*.17*scale,-.045*scale,dz*scale)) if not preserve else Vector()
        shift[side]=(shoulder,wrist)
        pole_shift[side]=Vector((sign*.13*scale,-.025*scale,0)) if not preserve else Vector()
        lengths['upper_arm_'+side]=source_rig.data.bones['upper_arm_'+side].length
        lengths['forearm_'+side]=source_rig.data.bones['forearm_'+side].length

    def head_pose(pose):
        chest_delta=pose['chest']@old['chest'].inverted()
        root_delta=pose['root']@old['root'].inverted()
        rotation=chest_delta.to_3x3()@root_delta.to_3x3().inverted()@pose['head'].to_3x3()
        head=rotation.to_4x4()
        head.translation=chest_delta@old['head'].translation+chest_delta.to_3x3()@Vector((0,0,head_raise))
        return head

    def arm_points(pose,side,left_hand=None):
        chest_delta=pose['chest']@old['chest'].inverted()
        shoulder,wrist_shift=shift[side]
        a=pose['upper_arm_'+side].translation+chest_delta.to_3x3()@shoulder
        hand=pose['hand_'+side].copy()
        wrist=hand.translation+chest_delta.to_3x3()@wrist_shift
        if row['family']=='ranger' and side=='r' and left_hand is not None:
            # A drawn arrow and the pulling fingers must share the bow's new
            # frame. Blend only while the original hand crosses toward it.
            local=old['chest']@pose['chest'].inverted()@pose['hand_r'].translation
            t=max(0.,min(1.,(local.x+.27)/.16));t=t*t*(3-2*t)
            # The pulling hand anchors beside the face. Moving it as far as
            # the outward bow would require an unnaturally elongated arm.
            draw=hand.translation+chest_delta.to_3x3()@Vector((-.055*scale,-.075*scale,0))
            wrist=wrist.lerp(draw,t)
        if not preserve:
            # Broad gloves stay in front of the chest and beside the face.
            # The constraints work in each body's moving frame, not world
            # axes, so turning and recovering cannot bury a fist in the body.
            r=hand_radius[side];head=head_pose(pose)
            for _ in range(2):
                point=pose['chest'].inverted()@wrist
                low=chest_local.min(axis=0);high=chest_local.max(axis=0)
                if all(point[i]+r>low[i] and point[i]-r<high[i] for i in range(3)):
                    overlaps=[min(high[i],point[i]+r)-max(low[i],point[i]-r) for i in (0,1)]
                    t=max(0.,min(1.,min(overlaps)/(.018*scale)));t=t*t*(3-2*t)
                    wrist+=pose['chest'].to_3x3()@Vector((0,0,max(0.,high[2]+r+.01*scale-point.z)*t))
                point=head.inverted()@wrist
                low=head_local.min(axis=0);high=head_local.max(axis=0)
                if all(point[i]+r>low[i] and point[i]-r<high[i] for i in range(3)):
                    goal=low[0]-r-.012*scale if side=='r' else high[0]+r+.012*scale
                    wrist+=head.to_3x3()@Vector((goal-point.x,0,0))
        pole=pose['forearm_'+side].translation+chest_delta.to_3x3()@(shoulder+pole_shift[side])
        return a,wrist,pole,hand

    def fitted_hand(pose,side,fore,hand):
        rotation=fore.to_3x3()@pose['forearm_'+side].to_3x3().inverted()@hand.to_3x3()
        blend=1.
        if side=='r' and row['family'] in ('guardian','warrior','rogue','cavalry'):blend=.25
        if side=='l' and row['family']=='guardian':blend=.25
        if row['family']=='ranger':
            if side=='l':blend=.1
            else:
                local=old['chest']@pose['chest'].inverted()@pose['hand_r'].translation
                t=max(0.,min(1.,(local.x+.27)/.16));blend=1.-t*t*(3-2*t)
        q=hand.to_quaternion().slerp(rotation.to_quaternion(),blend)
        result=q.to_matrix().to_4x4();result.translation=hand.translation
        return result

    factors={}
    # Left arm first, as bow/string/arrow contact determines the right target.
    poses=[old]+[pose for clip in clips for _,pose in clip['frames']]
    left_frames=[]
    for side in ('l','r'):
        reach=0.
        for index,pose in enumerate(poses):
            a,wrist,_,_=arm_points(pose,side,left_frames[index] if side=='r' else None)
            reach=max(reach,(wrist-a).length)
        nominal=lengths['upper_arm_'+side]+lengths['forearm_'+side]
        factor=max(1.,reach/nominal*1.012);factors[side]=factor
        lengths['upper_arm_'+side]*=factor;lengths['forearm_'+side]*=factor
        if side=='l':
            for pose in poses:
                a,wrist,pole,hand=arm_points(pose,side)
                elbow=solve_arm(a,wrist,lengths['upper_arm_l'],lengths['forearm_l'],pole)
                fore=frame_for(pose['forearm_l'],elbow,wrist)
                # Preserve the wrist angle relative to its forearm. An empty
                # fist no longer points up independently of the lowered arm.
                hand.translation=wrist;left_frames.append(fitted_hand(pose,'l',fore,hand))

    # Both arms share the same reach allowance; a large draw glove must not
    # turn only the right arm into a longer limb.
    common_factor=max(factors.values())
    for side in ('l','r'):
        factors[side]=common_factor
        for prefix in ('upper_arm','forearm'):
            lengths[prefix+'_'+side]=source_rig.data.bones[prefix+'_'+side].length*common_factor

    def solved(pose):
        result={n:p.copy() for n,p in pose.items()}
        chest_delta=pose['chest']@old['chest'].inverted()
        for side in ('l','r'):
            a,wrist,pole,hand=arm_points(pose,side,result['hand_l'] if side=='r' else None)
            elbow=solve_arm(a,wrist,lengths['upper_arm_'+side],lengths['forearm_'+side],pole)
            result['upper_arm_'+side]=frame_for(pose['upper_arm_'+side],a,elbow)
            result['forearm_'+side]=frame_for(pose['forearm_'+side],elbow,wrist)
            hand.translation=wrist
            result['hand_'+side]=fitted_hand(pose,side,result['forearm_'+side],hand)
            if preserve:
                # The squire's already approved relaxed arm stays exact.
                for prefix in ('upper_arm','forearm','hand'):result[prefix+'_'+side]=pose[prefix+'_'+side].copy()
            if not preserve:
                leg_offset=Vector(((1 if side=='l' else -1)*(.065 if row['family']=='cavalry' else .055)*scale,0,0))
                hips_delta=pose['hips']@old['hips'].inverted()
                for prefix in ('thigh','shin','foot'):
                    result[prefix+'_'+side].translation+=hips_delta.to_3x3()@leg_offset
        # The neck originates on the chest in every pose, even though the
        # game's bones are all direct root children.
        result['head']=head_pose(pose)
        if row['family']=='ranger':
            carry=result['hand_l']@pose['hand_l'].inverted()
            right=result['hand_r']@pose['hand_r'].inverted()
            local=old['chest']@pose['chest'].inverted()@pose['hand_r'].translation
            t=max(0.,min(1.,(local.x+.27)/.16));t=t*t*(3-2*t)
            for name in ('string_u','string_d'):
                # Bone heads stay at the bow tips; tails follow the nock.
                length=source_rig.data.bones[name].length
                head=carry@pose[name].translation
                tail=pose[name]@Vector((0,length,0))
                tail=(carry@tail).lerp(right@tail,t)
                normalized=pose[name].to_quaternion().to_matrix().to_4x4()
                normalized.translation=pose[name].translation
                result[name]=frame_for(normalized,head,tail)
                result[name]@=Matrix.Diagonal(Vector((1,(tail-head).length/length,1,1)))
            arrow=carry@pose['arrow']
            # While nocked, the shaft starts beside the drawing fingers and
            # points through the bow's grip. Flight continues in the class
            # animation's trajectory after release.
            if (pose['arrow'].translation-pose['hand_r'].translation).length<.22 and t>.001:
                origin=(carry@pose['arrow'].translation).lerp(right@pose['arrow'].translation,t)
                direction=(pose['arrow'].to_3x3()@Vector((0,1,0))).normalized()
                distance=max(.15,(pose['hand_l'].translation-pose['arrow'].translation).dot(direction))
                aim=carry@(pose['arrow'].translation+direction*distance)
                arrow=frame_for(arrow,origin,origin+(aim-origin).normalized())
            result['arrow']=arrow
        return result

    target=solved(old)
    rig.data=source_rig.data.copy();rig.animation_data_clear();rig.animation_data_create()
    bpy.context.window.scene=scene;bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
    for name,matrix in target.items():
        bone=rig.data.edit_bones[name];bone.matrix=matrix
        if name in lengths:bone.length=lengths[name]
    bpy.ops.object.mode_set(mode='OBJECT')
    target={b.name:b.matrix_local.copy() for b in rig.data.bones}
    modified={p+'_'+s for s in ('l','r') for p in ('upper_arm','forearm','hand','thigh','shin','foot')}|{'head'}
    if row['family']=='ranger':modified|={'string_u','string_d','arrow'}

    # Head/chest clearance is checked using the actual approved head vertices
    # in the moving chest frame, rather than axis-aligned world boxes.
    head_points=[]
    for obj in base_by.values():
        if obj.get('rig_bone')!='head':continue
        for vertex in obj.data.vertices:
            local=baseline['head'].inverted()@vertex.co
            head_points.append(target['head']@(local*scale))
    chest_points=[]
    for vertex in base_chest.data.vertices:
        local=baseline['chest'].inverted()@vertex.co
        chest_points.append(target['chest']@(local*scale))
    # Use the chest's anatomical upward direction, not Blender bone-local Y.
    max_head_lift=0.
    def clear_head(desired):
        nonlocal max_head_lift
        delta=desired['chest']@target['chest'].inverted()
        inverse=delta.inverted()
        change=desired['head']@target['head'].inverted()
        low=min((inverse@change@p).z for p in head_points)
        top=max(p.z for p in chest_points)
        lift=max(0.,top+.008*scale-low)
        max_head_lift=max(max_head_lift,lift)
        if lift:desired['head'].translation+=delta.to_3x3()@Vector((0,0,lift))

    for clip in clips:
        action=clip['action'].copy();action.name='Orc_Anatomy_'+clip['name']
        for bag,curve in list(action_curves(action)):
            if any('pose.bones["'+name+'"]' in curve.data_path for name in modified):bag.fcurves.remove(curve)
        rig.animation_data.action=action
        if action.slots:rig.animation_data.action_slot=action.slots[0]
        previous={}
        for frame,pose in clip['frames']:
            desired=solved(pose);clear_head(desired)
            for name in sorted(modified):
                rest_local=target['root'].inverted()@target[name]
                pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION'
                pb.matrix_basis=rest_local.inverted()@pose['root'].inverted()@desired[name]
                if name in previous and previous[name].dot(pb.rotation_quaternion)<0:pb.rotation_quaternion.negate()
                previous[name]=pb.rotation_quaternion.copy()
                pb.keyframe_insert('rotation_quaternion',frame=frame,group=name);pb.keyframe_insert('location',frame=frame,group=name)
                pb.keyframe_insert('scale',frame=frame,group=name)
        for _,curve in action_curves(action):
            for key in curve.keyframe_points:key.interpolation='LINEAR'
        rig.animation_data.action=None
        track=rig.animation_data.nla_tracks.new();track.name=clip['name']
        strip=track.strips.new(clip['name'],round(clip['frame_start']),action)
        if action.slots:strip.action_slot=action.slots[0]
        strip.action_frame_start=clip['action_start'];strip.action_frame_end=clip['action_end']
        strip.blend_type='REPLACE';strip.extrapolation='NOTHING';track.mute=True
    rig.animation_data.use_nla=True
    reset_pose(rig,scene)
    return old,target,scale,dict(revision='anatomy_v2',logical_neck_follows_chest=True,
        head_rest_raise=head_raise,maximum_additional_head_clearance_lift=max_head_lift,
        arm_reach_factors=factors,wrist_targets_adapted_to_orc_width=True,
        equipment_follows_adapted_hands=True,original_hand_contact_poses_preserved=False,
        bow_string_arrow_relative_frames_preserved=True,approved_squire_arm_preserved=preserve,
        modified_bones=sorted(modified))
