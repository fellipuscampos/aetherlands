"""Refine only the new Archon's hand clearance and its portal inscriptions."""
import bpy,math,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
st=bpy.app.driver_namespace['veil_archon_blocky_v1']
scene=st['scene']; rig=st['rig']; parts=st['parts']; NAME=st['name']; STEM=st['stem']
OUT=Path(st['out']); SIZE=st['atlas']; islands=st['islands']; PAD=2; DENSITY=64
bpy.context.window.scene=scene
assert not scene.get('hands_refined')
factor=(rig.data.bones['crown'].head_local.z-.25)/(2.77-.31)
for side,sign in [('L',-1),('R',1)]:
    shift=Vector((sign*.14,0,-.09))*factor
    for o in parts:
        if o['rig_bone']=='hand_'+side:
            for v in o.data.vertices: v.co+=shift
            o.data.update()
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for side,sign in [('L',-1),('R',1)]:
    bone=rig.data.edit_bones['hand_'+side]; shift=Vector((sign*.14,0,-.09))*factor
    bone.head+=shift; bone.tail+=shift
bpy.ops.object.mode_set(mode='OBJECT')
exec((ROOT/'tools/art_pipeline/veil_archon_texture.py').read_text(encoding='utf-8'),globals())
for im,data in zip(st['images'],[pixels,energy]):
    im.pixels.foreach_set(data.reshape(-1)); im.save(); im.pack()
scene['hands_refined']=True
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':scene.name,'hands_suspended':True,'portal_inscriptions':True,'core_preserved':True}
