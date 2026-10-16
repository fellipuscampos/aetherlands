"""Retarget the approved flat rig while keeping rigid parts and NLA clips."""
import math
import bpy
from mathutils import Matrix,Vector


def rotate_points(obj,transform):
    for vertex in obj.data.vertices: vertex.co=transform@vertex.co
    obj.data.update()


def relax_right_arm(scene,rig,parts,degrees=24):
    names=('forearm_r','hand_r')
    rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
    pivot=rig.data.bones['forearm_r'].head_local.copy()
    rotation=Matrix.Rotation(math.radians(degrees),4,'X')
    transform=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)
    tracks=list(rig.animation_data.nla_tracks); samples=[]
    for track in tracks:
        for other in tracks: other.mute=other!=track
        strip=track.strips[0]; frames=[]
        for frame in range(round(strip.frame_start),round(strip.frame_end)+1):
            scene.frame_set(frame); bpy.context.view_layer.update()
            upper_delta=rig.pose.bones['upper_arm_r'].matrix@rest['upper_arm_r'].inverted()
            posed_transform=upper_delta@transform@upper_delta.inverted()
            root_pose=rig.pose.bones['root'].matrix.copy()
            local_frame=strip.action_frame_start+(frame-strip.frame_start)/strip.scale
            frames.append((local_frame,root_pose,{n:posed_transform@rig.pose.bones[n].matrix for n in names}))
        samples.append((track,frames))
    for track in tracks: track.mute=True
    rig.animation_data.action=None
    for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name in names:
        bone=rig.data.edit_bones[name]
        bone.head=transform@bone.head; bone.tail=transform@bone.tail
        # Preserve the roll as a rotated frame, rather than recalculating it.
        bone.matrix=transform@rest[name]
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in parts:
        if obj.get('rig_bone') in names: rotate_points(obj,transform)
    new_rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
    for track,frames in samples:
        strip=track.strips[0]; action=strip.action.copy(); action.name='Orc_Relaxed_'+track.name
        for layer in action.layers:
            for key_strip in layer.strips:
                for bag in key_strip.channelbags:
                    for curve in list(bag.fcurves):
                        if any('pose.bones["'+name+'"]' in curve.data_path for name in names): bag.fcurves.remove(curve)
        strip.action=action; rig.animation_data.action=action
        if action.slots: rig.animation_data.action_slot=action.slots[0]
        previous={}
        for frame,root_pose,poses in frames:
            for name in names:
                local_rest=rest['root'].inverted()@new_rest[name]
                pb=rig.pose.bones[name]
                pb.rotation_mode='QUATERNION'
                pb.matrix_basis=local_rest.inverted()@root_pose.inverted()@poses[name]
                if name in previous and previous[name].dot(pb.rotation_quaternion)<0: pb.rotation_quaternion.negate()
                previous[name]=pb.rotation_quaternion.copy()
                pb.keyframe_insert('rotation_quaternion',frame=frame,group=name)
                pb.keyframe_insert('location',frame=frame,group=name)
        for layer in action.layers:
            for key_strip in layer.strips:
                for bag in key_strip.channelbags:
                    for curve in bag.fcurves:
                        if any('pose.bones["'+name+'"]' in curve.data_path for name in names):
                            for key in curve.keyframe_points: key.interpolation='LINEAR'
        rig.animation_data.action=None
    for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    scene.frame_set(1); bpy.context.view_layer.update()
    return dict(degrees=degrees,pivot=list(pivot),transform=[list(row) for row in transform],bones=list(names),clips_baked=len(samples))


def enlarge_shield(parts,width=1.18,height=1.18):
    import numpy as np
    shield=[obj for obj in parts if obj['part'].startswith('Shield') and obj['part']!='ShieldGrip']
    center=sum((sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices) for obj in shield),Vector())/len(shield)
    for obj in shield:
        coordinates=np.array([list(v.co) for v in obj.data.vertices]); local_center=coordinates.mean(axis=0)
        axes=np.stack([coordinates[i]-coordinates[0] for i in (1,2,4)],axis=1)
        axes/=np.linalg.norm(axes,axis=0)
        delta=Vector(local_center)-center
        destination=center+Vector((delta.x*width,delta.y,delta.z*height))
        updated=((coordinates-local_center)@axes*np.array([width,1,height]))@axes.T+np.array(destination)
        for vertex,position in zip(obj.data.vertices,updated): vertex.co=position
        obj.data.update()
    return dict(width_factor=width,height_factor=height,pivot=list(center),grip_unchanged=True)
