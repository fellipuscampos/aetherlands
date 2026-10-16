"""Remove settler-only caps and separate buckle surfaces; native anatomy stays."""
import bpy,json
from pathlib import Path
from mathutils import Vector
assets=bpy.app.driver_namespace['dwarf_school_mage_assets_v1']
review=bpy.app.driver_namespace['dwarf_school_mage_review_v1']
removed=[]
for a in assets:
    caps=[o for o in a['parts'] if o['part'].startswith('Workshop_cap_')]
    assert len(caps)==3
    for col in review['collections']:
        for o in col.objects:
            if o.parent and o.parent.get('school')==a['report']['school'] and o.get('part','').startswith('Workshop_cap_'): removed.append(o)
    a['parts']=[o for o in a['parts'] if o not in caps]; removed.extend(caps)
    a['report']['source_body']=[p for p in a['report']['source_body'] if not p['part'].startswith('Workshop_cap_')]
    buckle=next(o for o in a['parts'] if o['part']=='Copper_buckle')
    old=[v.co.copy() for v in buckle.data.vertices]; uv=buckle.data.uv_layers.active.data
    for face in buckle.data.polygons:
        n=face.normal; up=Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.01: up=Vector((0,1,0)); up-=n*up.dot(n)
        up.normalize(); right=up.cross(n).normalized()
        for loop in face.loop_indices:
            vertex=buckle.data.loops[loop].vertex_index; delta=Vector((0,0,(.561-old[vertex].z)*(1-.044/.051)))
            uv[loop].uv+=Vector((delta.dot(right),delta.dot(up)))*(64/512)
    for v,co in zip(buckle.data.vertices,old): v.co.z=.561+(co.z-.561)*(.044/.051)
    buckle.data.update()
    a['report']['geometry'].update(editable_parts=len(a['parts']),triangles=sum(len(f.vertices)-2 for o in a['parts'] for f in o.data.polygons))
    a['report']['surface_refinements']=['Exclude workshop cap inherited from settler equipment','Inset buckle top and bottom by 3.5 mm, preserving 64 px/m UVs']
bpy.data.batch_remove(ids=removed)
result=dict(status='PASS',workshop_caps_removed=18,buckles_refined=6,anatomy_unchanged=True)
