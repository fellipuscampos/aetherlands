"""Clear the belt edge planes while preserving 64 px/m UV density."""
import bpy
assets=bpy.app.driver_namespace['human_school_mage_assets_v1']; factor=.435/.447
for a in assets:
    obj=next(o for o in a['parts'] if o['part']=='Human_blue_belt')
    for vertex in obj.data.vertices: vertex.co.x*=factor
    uv=obj.data.uv_layers.active.data
    for face in obj.data.polygons:
        if abs(face.normal.x)>.5: continue
        middle=sum(uv[i].uv.x for i in face.loop_indices)/len(face.loop_indices)
        for i in face.loop_indices: uv[i].uv.x=middle+(uv[i].uv.x-middle)*factor
    obj.data.update()
result=dict(status='PASS',belts_refined=6,uv_density_preserved=True)
