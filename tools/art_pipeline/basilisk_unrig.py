"""Remove ONLY the generated rig/actions of the Basilisk in the live
Blender (MCP), keeping every mesh exactly as is, so skeleton_warrior_animate.py
can be re-run after tweaking poses."""
import bpy
NAME='Basilisk_Blocky_V1'; scene=bpy.data.scenes[NAME]; root=bpy.data.objects[NAME+'_ROOT']
rig=bpy.data.objects[NAME+'_Rig']
for o in [o for o in scene.objects if o.type=='MESH' and o.parent==rig]:
    mw=o.matrix_world.copy()
    for m in [m for m in o.modifiers if m.type=='ARMATURE']: o.modifiers.remove(m)
    o.vertex_groups.clear(); o.parent=root; o.matrix_world=mw
arm=rig.data; bpy.data.objects.remove(rig); bpy.data.armatures.remove(arm)
bpy.data.collections.remove(bpy.data.collections[NAME+'_07_RIG'])
for a in [a for a in bpy.data.actions if a.name.startswith('Basilisk_')]: bpy.data.actions.remove(a)
for m in [m for m in scene.timeline_markers if m.name.startswith('Basilisk_')]: scene.timeline_markers.remove(m)
result={'meshes':len([o for o in scene.objects if o.type=='MESH']),'actions':[a.name for a in bpy.data.actions]}
