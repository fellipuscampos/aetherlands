"""Check the reused spell against the approved animation and frame the new poses."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
old=bpy.app.driver_namespace['elemental_dragon_v9_animated']
new=bpy.app.driver_namespace['elemental_dragon_v10_animated']
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
maximum=0.
for sample in range(13):
    seconds=sample*.5
    bpy.context.window.scene=old['scene']; old['scene'].frame_set(old['clips']['walk']['start_frame']+round(seconds*30)); bpy.context.view_layer.update()
    approved={bone.name:bone.matrix.copy() for bone in old['rig'].pose.bones}
    bpy.context.window.scene=new['scene']; new['scene'].frame_set(new['clips']['spell']['start_frame']+round((seconds+1.)*30)); bpy.context.view_layer.update()
    for bone in new['rig'].pose.bones:
        maximum=max(maximum,max(abs(bone.matrix[i][j]-approved[bone.name][i][j]) for i in range(4) for j in range(4)))
assert maximum<1e-5,('approved orbit changed',maximum)
out=ROOT/'assets/generated/grand_manifestations/elemental_dragon_v10_animated'
report=new['report']; report['approved_spell_motion']={'source':'elemental_dragon_v9_animated/walk','checkpoints':13,'maximum_bone_matrix_difference':maximum,'orbit_duration_s':6.,'entry_s':1.,'recovery_s':1.}
report['animation_layout']={'idle':'upright_subtle_zigzag','walk':'open_serpent_wave','spell':'approved_v9_walk_with_entry_and_recovery','attack':'preserved_v9_attack'}
(out/'elemental_dragon_v10_animated_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene=new['scene']; scene.cycles.samples=16
for label,clip,seconds,eye,target,size in [('idle_upright','idle',.8,(5,-9,4.4),(0,0,1.8),4.5),('walk_glide','walk',1.,(6,-9,5),(1,2.4,2.6),7.5)]:
    scene.frame_set(new['clips'][clip]['start_frame']+round(seconds*30)); scene.camera.location=eye
    scene.camera.rotation_euler=(Vector(target)-scene.camera.location).to_track_quat('-Z','Y').to_euler(); scene.camera.data.ortho_scale=size
    scene.render.filepath=str(out/'previews'/(label+'.png')); bpy.ops.render.render(write_still=True)
scene.camera.location=(5,-9,4.4); scene.camera.rotation_euler=(Vector((0,0,1.8))-scene.camera.location).to_track_quat('-Z','Y').to_euler(); scene.camera.data.ortho_scale=4.5
scene.frame_start=1; scene.frame_end=180; scene.frame_set(1)
bpy.data.libraries.write(str(out/'elemental_dragon_v10_animated.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.screen.animation_play()
result={'approved_spell_preserved':True,'matrix_error':maximum,'live_idle':True}
