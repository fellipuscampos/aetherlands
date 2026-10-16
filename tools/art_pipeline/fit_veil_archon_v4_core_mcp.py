"""Fit the V4 core deeper into its open chest while preserving pixel maps and meshes."""
import bpy
from mathutils import Vector
from pathlib import Path
st=bpy.app.driver_namespace['veil_archon_blocky_v4'];scene=st['scene'];rig=st['rig']
assert not scene.get('core_depth_finished'), 'This one-time fit has already been applied.'
bpy.context.window.scene=scene
for label,dy in [('Dark_Central_Cuirass',.09),('Azure_Mana_Core',.15)]:
    o=next(o for o in st['parts'] if o.name.endswith('_'+label))
    for v in o.data.vertices:v.co.y+=dy
    o.data.update()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=rig.data.edit_bones['core'];b.head.y+=.15;b.tail.y+=.15
bpy.ops.object.mode_set(mode='OBJECT');scene.frame_set(1)
scene['core_depth_finished']=True
scene.render.filepath=str(Path(st['out'])/'previews/three_quarter.png')
bpy.ops.render.render(write_still=True)
result={'core_depth_fit':True,'geometry_and_texture_style_preserved':True}
