"""Render the particle-free Death review on the connected Blender."""
import bpy
from pathlib import Path

st = bpy.app.driver_namespace['seraph_death']
scene = st['scene']
bpy.context.window.scene = scene
frames = Path(st['out'])/'frames'
frames.mkdir(exist_ok=True)
scene.render.filepath = str(frames)+'/'
scene.frame_start = 1
scene.frame_end = 85
bpy.ops.render.render(animation=True)
scene.frame_set(1)
result = {'frames': len(list(frames.glob('*.png'))), 'directory': str(frames)}
