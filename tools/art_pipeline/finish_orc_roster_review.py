"""Make review labels readable and save the final scene in the open Blender."""
import bpy
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
scene=bpy.context.scene
assert scene.name.startswith('Orc_Troops_20_Review')
floor=next(o for o in scene.objects if o.name.startswith('Orc_Review_Floor'))
material=floor.data.materials[0];material.use_nodes=True
shader=material.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=(.06,.08,.065,1)
shader.inputs['Roughness'].default_value=1
ink=bpy.data.materials.new('Orc_Review_Label_Ink');ink.use_nodes=True
shader=ink.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=(.74,.66,.43,1)
shader.inputs['Emission Color'].default_value=(.74,.66,.43,1)
shader.inputs['Emission Strength'].default_value=.2
for obj in scene.objects:
    if obj.type=='FONT': obj.data.materials.clear();obj.data.materials.append(ink)
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(ROOT/'assets/generated/orcs/orc_troops_review.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'status':'PASS','scene':scene.name,'actors':len([o for o in scene.objects if o.type=='ARMATURE'])}
