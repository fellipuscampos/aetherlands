"""Sub-pixel wrist clearance avoids floating-point edge face overlap."""
import bpy

assets=bpy.app.driver_namespace['human_school_mage_assets_v1']
for asset in assets:
    if asset['report'].get('wrist_edge_clearance_m'): continue
    for side in ['l','r']:
        hand=asset['body']['Hand_'+side]
        shift=-(hand.data.vertices[4].co-hand.data.vertices[0].co).normalized()*.0005
        for v in hand.data.vertices: v.co+=shift
        hand.data.update()
    asset['report']['wrist_edge_clearance_m']=.0005
result=dict(models=len(assets),clearance_m=.0005,uvs_unchanged=True)
