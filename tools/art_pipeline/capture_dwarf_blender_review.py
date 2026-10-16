"""Capture the actual textured review viewport in live Blender MCP."""
import bpy
from pathlib import Path

scene=bpy.context.window.scene
assert scene.name.startswith('Dwarf_Troops_24_Model_Review')
area=next(a for a in bpy.context.window.screen.areas if a.type=='VIEW_3D')
region=next(r for r in area.regions if r.type=='WINDOW')
scene.render.resolution_x=1600; scene.render.resolution_y=1200
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
path=Path(r'C:/Users/felipe campos/Documents/jogo/docs/previews/dwarf_troops/blender_live_overview.png')
scene.render.filepath=str(path)
with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0],area=area,region=region):
    bpy.ops.render.opengl(write_still=True,view_context=True)
result={'scene':scene.name,'viewport':str(path),'mcp':'live'}
