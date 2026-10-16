"""Render the review on the connected Blender, never a headless substitute."""
import bpy
from pathlib import Path

st = bpy.app.driver_namespace['seraph_summon']
scene = st['scene']
bpy.context.window.scene = scene
frames = Path(st['out'])/'frames_core_first'
frames.mkdir(exist_ok=True)
scene.render.filepath = str(frames/'')+'/'
scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.cycles.samples = 16
scene.frame_start = 1
scene.frame_end = 121
bpy.ops.render.render(animation=True)
scene.frame_set(1)
result = {'frames': len(list(frames.glob('*.png'))), 'directory': str(frames)}
