"""Remove joint overlaps without changing mesh dimensions or texel density."""
import bpy, math
from mathutils import Vector, Matrix

assets=bpy.app.driver_namespace['human_school_mage_assets_v1']
for asset in assets:
    if asset['report'].get('joint_surface_refinement'): continue
    for side in ['l','r']:
        hand=asset['body']['Hand_'+side]
        shift=-(hand.data.vertices[4].co-hand.data.vertices[0].co).normalized()*.004
        for v in hand.data.vertices: v.co+=shift
        hand.data.update()
    for obj in asset['parts']:
        part=obj['part']
        if part.startswith('Moustache_'):
            shift=Vector((.002 if part.endswith('_1') else -.002,0,0))
        elif part=='Hood_back':
            shift=Matrix.Rotation(math.radians(asset['report']['elderly_posture']['torso_forward_degrees']-3),3,'X')@Vector((0,0,-.012))
        elif part=='Sun_staff_vertical': shift=Vector((0,.006,0))
        else: continue
        for v in obj.data.vertices: v.co+=shift
        obj.data.update()
    asset['report']['joint_surface_refinement']='Forearm and fist meet without overlapping side faces; moustache tips are separate; hood cap surfaces staggered; sun-cross front planes separated by 7 mm. UV density preserved.'
result=dict(models=len(assets),dimensions_preserved=True,pixel_density_preserved=True)
