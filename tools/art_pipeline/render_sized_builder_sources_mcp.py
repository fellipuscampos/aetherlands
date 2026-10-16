"""Refresh the affected builders' Blender stills at their corrected body height."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
for race,family in [('human','humans'),('elf','elves')]:
    scene=bpy.data.scenes[race.title()+'_Builder_V1']; bpy.context.window.scene=scene
    out=ROOT/f'assets/generated/{family}/{race}_builder_v1'
    camera=scene.camera
    for name,position in [('three_quarter',(3,-5,2.8)),('front',(0,-5,1.5)),('back',(-3,5,2.8))]:
        scene.frame_set(1); camera.location=position
        camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(name+'.png')); bpy.ops.render.render(write_still=True)
    camera.location=(3,-5,2.8)
    camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
    for name,frame in [('work_bend',277),('work_raise',307),('work_strike',330),('work_recover',375)]:
        scene.frame_set(frame); scene.render.filepath=str(out/'previews'/(name+'.png'))
        bpy.ops.render.render(write_still=True)
    scene.frame_set(1)
result={'status':'PASS','updated':['human','elf']}
