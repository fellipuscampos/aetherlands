"""Render key motion poses in the open Blender and restore its walk preview."""
import bpy
from pathlib import Path

scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
playing=bpy.context.screen.is_animation_playing
if playing: bpy.ops.screen.animation_cancel(restore_frame=False)
tracks=list(rig.animation_data.nla_tracks)
original={track.name:(track.mute,track.is_solo) for track in tracks}
frame=scene.frame_current
folder=Path(r'C:\Users\felipe campos\Documents\jogo\assets\generated\orcs\orc_squire_v1\previews')
try:
    for role,fraction in (('Walk',.25),('Attack',.50),('ShieldWallHold',.50)):
        for track in tracks: track.mute=track.name!='Squire_'+role; track.is_solo=False
        track=next(t for t in tracks if t.name=='Squire_'+role)
        strip=track.strips[0]
        scene.frame_set(round(strip.frame_start+(strip.frame_end-strip.frame_start)*fraction))
        scene.render.filepath=str(folder/(role.lower()+'.png'))
        bpy.ops.render.render(write_still=True)
finally:
    for track in tracks: track.mute,track.is_solo=original[track.name]
    scene.frame_set(frame)
    if playing: bpy.ops.screen.animation_play()
result=dict(status='PASS',poses=['Walk','Attack','ShieldWallHold'],scene=scene.name)
