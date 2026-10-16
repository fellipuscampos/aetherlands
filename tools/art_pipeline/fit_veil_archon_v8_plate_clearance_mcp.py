"""Separate the oblique layer by a tested radial amount without touching the pixel maps."""
import bpy,math
from mathutils import Vector
from pathlib import Path
st=bpy.app.driver_namespace['veil_archon_blocky_v8'];scene=st['scene'];rig=st['rig'];parts=st['parts']
assert not scene.get('plate_clearance_finished'),'This one-time clearance fit has already run.'
bpy.context.window.scene=scene
core=next(o for o in parts if o['kind']=='core');C=rig.data.bones['core'].head_local.copy()
factor=(core.data.vertices[0].co-C).length/(.96*math.sqrt(3)/2)
shifts={}
for o in parts:
    if o['kind']!='plate' or o['layer']!='edge':continue
    delta=(rig.data.bones[o['rig_bone']].head_local-C).normalized()*(.12*factor)
    for v in o.data.vertices:v.co+=delta
    o.data.update();shifts[o['rig_bone']]=delta
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,delta in shifts.items():
    b=rig.data.edit_bones[n];b.head+=delta;b.tail+=delta
bpy.ops.object.mode_set(mode='OBJECT');scene.frame_set(1)
scene['plate_clearance_finished']=True
scene.render.filepath=str(Path(st['out'])/'previews/three_quarter.png');bpy.ops.render.render(write_still=True)
result={'oblique_plates_adjusted':len(shifts),'pixel_maps_preserved':True}
