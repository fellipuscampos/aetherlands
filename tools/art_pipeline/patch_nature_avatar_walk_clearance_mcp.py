"""Apply the measured four-centimeter clearance to the existing Walk keys only."""
import bpy
from mathutils import Vector
st=bpy.app.driver_namespace['nature_avatar_blocky_v5_animated']; rig=st['rig']
action=st['clips']['Walk']['action']
assert not action.get('forward_clearance_adjusted')
delta=rig.data.bones['core'].matrix_local.to_quaternion().inverted()@Vector((0,-.04,0))
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                if curve.data_path=='pose.bones["core"].location':
                    for key in curve.keyframe_points:
                        key.co.y+=delta[curve.array_index]
                        key.handle_left.y+=delta[curve.array_index]; key.handle_right.y+=delta[curve.array_index]
action['forward_clearance_adjusted']=True
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
st['scene'].frame_set(1)
result={'walk_core_additional_forward_clearance_m':.04}
