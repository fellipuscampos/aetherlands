"""Check the coiled dragon's geometry, skin, articulation and rotating heart clearance."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM=globals().get('DRAGON_STEM','elemental_dragon_v1')
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
state=bpy.app.driver_namespace[STEM]; parts=state['parts']; rig=state['rig']
coords=[v.co for obj in parts for v in obj.data.vertices]
assert abs(max(v.z for v in coords)-min(v.z for v in coords)-3)<1e-5
assert abs(min(v.z for v in coords)-.35)<1e-5
assert not rig.animation_data
assert len([b for b in rig.data.bones if b.name.startswith('spine_')])==39
for j in range(1,39): assert rig.data.bones['spine_%02d'%j].parent.name=='spine_%02d'%(j-1)
assert rig.data.bones['core'].parent.name=='root'
for obj in parts:
    bm=bmesh.new(); bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,obj.name
    bm.free()
    assert all(not f.use_smooth and f.area>1e-9 for f in obj.data.polygons)
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 and len(v.groups)<=2 for v in obj.data.vertices)
core_parts=[o for o in parts if o['rig_bone']=='core']; center=rig.data.bones['core'].head_local
radius=max((v.co-center).length for o in core_parts for v in o.data.vertices)
clearance=[]
for obj in parts:
    if obj in core_parts: continue
    tree=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(f.vertices) for f in obj.data.polygons])
    nearest=tree.find_nearest(center)
    if nearest: clearance.append((nearest[3]-radius,obj['part']))
minimum=min(clearance)
if state['report'].get('body_surrounds_core'):
    assert not any(o['part'].startswith(('fore_','hind_','Head_mane_','Dorsal_crystal_')) for o in parts)
    assert not any(b.name.startswith(('fore_','hind_')) for b in rig.data.bones)
    body=next(o for o in parts if o['part']=='Continuous_serpentine_body')
    assert min(v.co.x for v in body.data.vertices)<center.x-radius
    assert max(v.co.x for v in body.data.vertices)>center.x+radius
    assert min(v.co.z for v in body.data.vertices)<center.z-radius
    assert max(v.co.z for v in body.data.vertices)>center.z+radius
    assert min(v.co.y for v in body.data.vertices)<center.y<max(v.co.y for v in body.data.vertices)
    assert rig.data.bones['head'].head_local.y<center.y-.5
result={'status':'PASS','height_m':3.0,'ground_clearance_m':.35,'closed_geometry':True,
    'normalized_weights':True,'maximum_influences':2,'continuous_spine':True,'independent_core':True,
    'body_surrounds_core':state['report'].get('body_surrounds_core',False),
    'legs':state['report']['four_clawed_legs'],'side_spikes':state['report'].get('body_spikes',True),
    'full_rotation_core_clearance_m':minimum[0],'nearest_core_neighbor':minimum[1]}
if minimum[0]<.015: result['status']='CORE_CLEARANCE_ADJUSTMENT_NEEDED'
(OUT/'source_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
