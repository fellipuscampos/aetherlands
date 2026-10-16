"""Give the outer detached chip a clear fracture gap; preserve all colors and UVs."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['veil_archon_blocky_v3']; scene=st['scene']; rig=st['rig']
bpy.context.window.scene=scene
assert not scene.get('outer_fragment_gap_finished')
factor=(rig.data.bones['head'].head_local.z-.35)/(2.62-.31)
shift=Vector((.055,0,0))*factor
part=next(o for o in st['parts'] if o['rig_bone']=='free_fragment_2')
for v in part.data.vertices: v.co+=shift
part.data.update()
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
bone=rig.data.edit_bones['free_fragment_2']; bone.head+=shift; bone.tail+=shift
bpy.ops.object.mode_set(mode='OBJECT'); scene['outer_fragment_gap_finished']=True
scene.render.filepath=str(Path(st['out'])/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':scene.name,'outer_fragment_gap_m':.055*factor,'textures_preserved':True}
