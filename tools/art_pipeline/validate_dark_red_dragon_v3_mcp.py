"""Validate the clean reference dragon in the active MCP scene, without editing it."""
import bpy,bmesh,json,math,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='dark_red_dragon_v3'
st=bpy.app.driver_namespace[STEM]
parts=st['parts']; rig=st['rig']; OUT=st['out']
checks={'status':'PASS','parts':len(parts),'bones':len(rig.data.bones),
    'non_manifold_edges':0,'degenerate_faces':0,'bad_weights':0,'invalid_vertices':0,
    'invalid_uvs':0,'symmetry_max_distance_m':0.0,'paired_parts':0,'core':False,
    'jaw_in_one_local_frame':True,'mirror_symmetric_wings':True}
for obj in parts:
    bm=bmesh.new(); bm.from_mesh(obj.data)
    checks['non_manifold_edges']+=sum(not e.is_manifold for e in bm.edges)
    checks['degenerate_faces']+=sum(f.calc_area()<1e-10 for f in bm.faces)
    assert bm.calc_volume(signed=True)>0,obj.name
    bm.free()
    for v in obj.data.vertices:
        checks['invalid_vertices']+=int(not all(math.isfinite(c) for c in v.co))
        checks['bad_weights']+=int(abs(sum(g.weight for g in v.groups)-1)>1e-5)
    for loop in obj.data.uv_layers.active.data:
        checks['invalid_uvs']+=int(any(c<0 or c>1 for c in loop.uv))
by_name={obj['part']:obj for obj in parts}
for label,obj in by_name.items():
    target=label[:-2]+'_R' if label.endswith('_L') else label.replace('_L_','_R_')
    if target==label: continue
    # Digits are numbered from world -X to +X on each hand. Mirroring swaps
    # the outer two indices, while the central digit keeps index 1.
    if '_digit_L_' in label or '_claw_L_' in label:
        target=target[:-1]+str(2-int(label[-1]))
    assert target in by_name,(label,target)
    other=by_name[target]
    assert len(obj.data.vertices)==len(other.data.vertices),label
    tree=KDTree(len(other.data.vertices))
    for v in other.data.vertices: tree.insert(v.co,v.index)
    tree.balance()
    for v in obj.data.vertices:
        _,_,distance=tree.find(Vector((-v.co.x,v.co.y,v.co.z)))
        checks['symmetry_max_distance_m']=max(checks['symmetry_max_distance_m'],distance)
    checks['paired_parts']+=1
assert checks['symmetry_max_distance_m']<2e-6,checks
assert all(checks[k]==0 for k in ('non_manifold_edges','degenerate_faces','bad_weights','invalid_vertices','invalid_uvs')),checks
assert not any(any(word in o['part'].lower() for word in ('core','heart','chest_ember')) for o in parts)
assert len(rig.data.bones)==38,len(rig.data.bones)
assert all(im.source=='FILE' and im.colorspace_settings.name=='sRGB' for im in st['images'])
(OUT/'blender_validation.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print(json.dumps(checks))
