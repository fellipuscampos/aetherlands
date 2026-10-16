"""Render Death in the connected Blender, without particles or VFX."""
import bpy
from pathlib import Path

st = bpy.app.driver_namespace['primordial_death']
scene = st['scene']
bpy.context.window.scene = scene
frames = Path(st['out'])/'frames'
frames.mkdir(exist_ok=True)
scene.render.filepath = str(frames)+'/'
scene.frame_start, scene.frame_end = 1, 151
st['rig'].animation_data.action = st['action']
bpy.ops.render.render(animation=True)
scene.frame_set(1)
result = {'frames': len(list(frames.glob('*.png'))), 'directory': str(frames)}
