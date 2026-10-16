"""Rebake the two action clips after fitting the plate opening envelopes."""
import bpy,math
from pathlib import Path
from mathutils import Vector,Matrix,Euler,Quaternion
st=bpy.app.driver_namespace['veil_archon_blocky_v9_animated'];rig=st['rig'];scene=st['scene'];parts=st['parts']
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_play()
for track in rig.animation_data.nla_tracks:track.mute=True
C=rig.data.bones['core'].head_local.copy()
source=(Path(r'C:/Users/felipe campos/Documents/jogo')/'tools/art_pipeline/veil_archon_animation_motion.py').read_text(encoding='utf-8')
exec(source[source.index('rig.animation_data_create()'):source.index('specs={')],globals())
for name in ('Attack','Spell'):
    data=st['clips'][name];action=data['action'];rig.animation_data.action=action;previous={}
    for frame in range(1,data['end_frame']+1):
        frame_pose(name,(frame-1)/24,data['duration_s'])
        for bone in rig.pose.bones:
            if bone.name in previous and previous[bone.name].dot(bone.rotation_quaternion)<0:bone.rotation_quaternion.negate()
            previous[bone.name]=bone.rotation_quaternion.copy()
            for path in ('location','rotation_quaternion','scale'):bone.keyframe_insert(data_path=path,frame=frame,group=bone.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=False
scene.frame_set(1)
result={'rebaked':['Attack','Spell'],'approved_geometry_and_textures_preserved':True}
