import bpy,math
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion,Euler
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
st=bpy.app.driver_namespace['archdemon_blocky_v5_animated']
rig,parts,scene=st['rig'],st['parts'],st['scene']
bpy.context.window.scene=scene
for track in rig.animation_data.nla_tracks: track.mute=True
exec((ROOT/'tools/art_pipeline/archdemon_animation_motion_v5.py.inc').read_text(encoding='utf-8'),globals())
data=st['clips']['Spell']; action=data['action']; rig.animation_data.action=action
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in list(bag.fcurves): bag.fcurves.remove(curve)
previous={}
for f in range(1,data['end_frame']+1):
    frame_pose('Spell',(f-1)/24,data['duration_s'])
    for b in rig.pose.bones:
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion)<0: b.rotation_quaternion.negate()
        previous[b.name]=b.rotation_quaternion.copy()
        for path in ('location','rotation_quaternion','scale'): b.keyframe_insert(data_path=path,frame=f,group=b.name)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points: key.interpolation='LINEAR'
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
result={'spell_rebaked':True,'wrist_path':'Move clear of shoulders before lifting and turning palms up; lower before retracting.'}
