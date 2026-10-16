"""Separate layered cape planes, preserving metric UVs and the entire atlas."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['elder_lich_blocky_v1']; rig=st['rig']; scene=st['scene']
bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
factor=3/(3.181-.10)
changes={'cape_left':Vector((0,0,0)),'cape_center':Vector((0,.018,-.003))*factor,'cape_right':Vector((0,.036,-.006))*factor}
assert not scene.get('cape_planes_separated',False),'Already applied.'
for o in st['parts']:
    if o['rig_bone'] in changes:
        for v in o.data.vertices: v.co+=changes[o['rig_bone']]
        o.data.update()
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name,delta in changes.items():
    b=rig.data.edit_bones[name]; b.head+=delta; b.tail+=delta
bpy.ops.object.mode_set(mode='OBJECT')
scene['cape_planes_separated']=True
scene.render.filepath=str(Path(st['out'])/'previews/three_quarter.png')
bpy.ops.render.render(write_still=True)
result={'cape_layers_separated':True,'uvs_and_textures_unchanged':True}
