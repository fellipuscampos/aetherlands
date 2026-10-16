import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
old=bpy.app.driver_namespace['elemental_dragon_v8_animated']
scene=old['scene']; bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
rig=old['rig']; parts=old['parts']; material=parts[0].data.materials[0]
rest={bone.name:bone.matrix_local.copy() for bone in rig.data.bones}
core=rest['core'].translation.copy(); spine=['spine_%02d'%i for i in range(39)]
def ease(t):
    t=max(0.,min(1.,t)); return t*t*t*(t*(t*6-15)+10)
def pulse(t,start,rise,hold,end):
    if t<=start or t>=end: return 0.
    return ease((t-start)/(rise-start)) if t<rise else (1. if t<=hold else 1-ease((t-hold)/(end-hold)))
def rotated_at(matrix,axis,angle):
    value=(Matrix.Rotation(angle,3,axis)@matrix.to_3x3()).to_4x4(); value.translation=matrix.translation; return value
source=ROOT/'tools/art_pipeline/elemental_dragon_path_motion.py.inc'
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
for track in rig.animation_data.nla_tracks: track.mute=True
action=bpy.data.actions.new('Path_follow_preview'); rig.animation_data.action=action
previous={}
for frame in range(1,181+1):
    pose=frame_pose('walk',(frame-1)/30,6.)
    for bone in rig.pose.bones:
        bone.rotation_mode='QUATERNION'
        args={'parent_matrix':pose[bone.parent.name],'parent_matrix_local':rest[bone.parent.name]} if bone.parent else {}
        bone.matrix_basis=bone.bone.convert_local_to_pose(pose[bone.name],rest[bone.name],invert=True,**args)
        q=bone.rotation_quaternion.copy()
        if bone.name in previous: q.make_compatible(previous[bone.name])
        bone.rotation_quaternion=q; previous[bone.name]=q.copy()
        for path in ('location','rotation_quaternion','scale'): bone.keyframe_insert(data_path=path,frame=frame)
out=ROOT/'art_source/elemental_dragon_review/path_preview'; out.mkdir(parents=True,exist_ok=True)
scene.render.engine='CYCLES'; scene.cycles.samples=8; scene.cycles.use_denoising=True
scene.render.resolution_x=scene.render.resolution_y=420; scene.render.resolution_percentage=100
scene.render.film_transparent=False; scene.view_settings.view_transform='Standard'
scene.camera.data.ortho_scale=5.
for index in range(12):
    scene.frame_set(index*15+1); scene.render.filepath=str(out/('corrected_%03d.png'%index)); bpy.ops.render.render(write_still=True)
scene.frame_start=1; scene.frame_end=180; scene.frame_set(1)
bpy.ops.screen.animation_play()
result={'path_length':_CIRCUMFERENCE,'body_length':sum(_LENGTHS),'preview':str(out),'live':True}
