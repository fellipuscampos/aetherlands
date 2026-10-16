"""Adjust the approved creature revision's heart without repainting its packed pixel images."""
import bpy,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
st=bpy.app.driver_namespace['elemental_primordial_blocky_v3']
rig=st['rig'];scene=st['scene'];parts=st['parts']
core=next(o for o in parts if o['rig_bone']=='core')
assert not st.get('heart_refined')
factor=(core.data.vertices[1].co-core.data.vertices[0].co).length/.48
delta=Vector((0,-.07,-.05))*factor
for v in core.data.vertices:v.co+=delta
core.data.update()
bpy.context.window.scene=scene
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=rig.data.edit_bones['core'];b.head+=delta;b.tail+=delta
bpy.ops.object.mode_set(mode='OBJECT')
st['heart_refined']=True
center=rig.data.bones['core'].head_local
targets=[(o,BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])) for o in parts if o!=core]
for axis in ('X','Y','Z'):
    for step in range(48):
        R=Matrix.Rotation(math.tau*step/48,3,axis)
        tree=BVHTree.FromPolygons([center+R@(v.co-center) for v in core.data.vertices],[tuple(p.vertices) for p in core.data.polygons])
        for o,other in targets:assert not tree.overlap(other),(axis,step,o.name)
result={'core_rotation_clearance':'PASS','axes':['X','Y','Z'],'samples':144,'new_center':list(center)}
