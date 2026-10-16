"""Seat the cube slightly higher in the cowl and verify the complete future spin envelope."""
import bpy,math
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
st=bpy.app.driver_namespace['veil_archon_blocky_v2']; scene=st['scene']; rig=st['rig']; parts=st['parts']
bpy.context.window.scene=scene
assert not scene.get('core_seated')
factor=(rig.data.bones['crown'].head_local.z-.35)/(2.73-.21)
shift=Vector((0,-.05,.075))*factor
core=next(o for o in parts if o['rig_bone']=='core'); c=rig.data.bones['core'].head_local.copy()
targets=[(o,BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])) for o in parts if o!=core]
for step in range(96):
    R=Matrix.Rotation(math.tau*step/96,3,'Z')
    tree=BVHTree.FromPolygons([c+shift+R@(v.co-c) for v in core.data.vertices],[tuple(p.vertices) for p in core.data.polygons])
    for o,other in targets: assert not tree.overlap(other),('Core clearance',step,o.name)
for v in core.data.vertices: v.co+=shift
core.data.update()
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
bone=rig.data.edit_bones['core']; bone.head+=shift; bone.tail+=shift
bpy.ops.object.mode_set(mode='OBJECT'); scene['core_seated']=True
scene.render.filepath=str(Path(st['out'])/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':scene.name,'core_full_turn_clearance_samples':96,'core_position_adjusted':True}
