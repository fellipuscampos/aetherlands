"""Render selected beats for visual review before the complete animation."""
import bpy
from pathlib import Path
s = bpy.app.driver_namespace['seraph_summon']
scene = s['scene']
bpy.context.window.scene = scene
folder = Path(s['out'])/'contact'
folder.mkdir(exist_ok=True)
for frame in (19, 37, 55, 73, 91, 109, 121):
    scene.frame_set(frame)
    scene.render.filepath = str(folder/f'{frame:04d}.png')
    bpy.ops.render.render(write_still=True)
result = {'directory': str(folder)}
