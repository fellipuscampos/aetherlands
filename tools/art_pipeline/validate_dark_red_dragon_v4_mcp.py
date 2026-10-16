"""Check wing-to-spar contact, connected sails, mirrored limbs and clean export data."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree
STEM='dark_red_dragon_v4'
st=bpy.app.driver_namespace[STEM]
parts=st['parts']; rig=st['rig']; OUT=st['out']; factor=st['native_scale']
report={'status':'PASS','parts':len(parts),'bones':len(rig.data.bones),
    'non_manifold_edges':0,'degenerate_faces':0,'invalid_vertices':0,'bad_weights':0,
    'invalid_uvs':0,'mirror_max_distance_m':0.0,'paired_parts':0,
    'ventral_slabs':0,'core':False,'wings':{}}
for obj in parts:
    bm=bmesh.new(); bm.from_mesh(obj.data)
    report['non_manifold_edges']+=sum(not e.is_manifold for e in bm.edges)
    report['degenerate_faces']+=sum(f.calc_area()<1e-10 for f in bm.faces)
    assert bm.calc_volume(signed=True)>0,obj.name
    bm.free()
    for v in obj.data.vertices:
        report['invalid_vertices']+=int(not all(math.isfinite(c) for c in v.co))
        report['bad_weights']+=int(abs(sum(g.weight for g in v.groups)-1)>1e-5)
    report['invalid_uvs']+=sum(any(c<0 or c>1 for c in loop.uv) for loop in obj.data.uv_layers.active.data)
    report['ventral_slabs']+=int(obj['part'].startswith(('Throat_scale','Belly_scale','Lower_jaw_pale')))
by_name={o['part']:o for o in parts}
for label,obj in by_name.items():
    other_label=label[:-2]+'_R' if label.endswith('_L') else label.replace('_L_','_R_')
    if label==other_label: continue
    other=by_name[other_label]
    assert len(obj.data.vertices)==len(other.data.vertices),label
    tree=KDTree(len(other.data.vertices))
    for v in other.data.vertices: tree.insert(v.co,v.index)
    tree.balance()
    for v in obj.data.vertices:
        distance=tree.find(Vector((-v.co.x,v.co.y,v.co.z)))[2]
        report['mirror_max_distance_m']=max(report['mirror_max_distance_m'],distance)
    report['paired_parts']+=1
for suffix,surface in st['wing_surfaces'].items():
    verts=[v.co.copy() for v in surface.data.vertices]
    faces=[list(f.vertices) for f in surface.data.polygons]
    bvh=BVHTree.FromPolygons(verts,faces)
    graph={i:set() for i in range(len(verts))}
    for edge in surface.data.edges:
        a,b=edge.vertices; graph[a].add(b); graph[b].add(a)
    unseen=set(graph); components=0
    while unseen:
        pending=[unseen.pop()]; components+=1
        while pending:
            for i in graph[pending.pop()]:
                if i in unseen: unseen.remove(i); pending.append(i)
    row=st['wing_structure'][suffix]
    anchors=row['anchors']; normal=row['normal']
    shift=rig.data.bones['wing_upper_'+suffix].head_local-anchors['S']*factor
    samples=[]
    for a,b in [('S','E'),('E','W'),('W','B'),('B','Tip'),('W','T2'),('W','T3')]:
        for t in [0,.2,.4,.6,.8,1.0]:
            point=anchors[a].lerp(anchors[b],t)*factor+shift
            samples.append(bvh.find_nearest(point)[3])
    maximum=max(samples)
    # The center of each spar must intersect the sail thickness or sit closer
    # than its half-depth. This catches the old detached root web and rolled bars.
    assert maximum<.018*factor,(suffix,maximum)
    origin=anchors['S']*factor+shift
    maximum_plane=max(abs((v-origin).dot(normal)) for v in verts)
    assert maximum_plane<.0101*factor,(suffix,maximum_plane)
    assert components==1,(suffix,components)
    report['wings'][suffix]={'connected_shells':components,'contact_samples':len(samples),
        'maximum_spar_to_sail_distance_m':maximum,'shell_half_thickness_m':maximum_plane}
assert report['mirror_max_distance_m']<2e-6,report
assert all(report[k]==0 for k in ('non_manifold_edges','degenerate_faces','invalid_vertices','bad_weights','invalid_uvs','ventral_slabs')),report
assert len(rig.data.bones)==52,len(rig.data.bones)
assert not any(any(word in obj['part'].lower() for word in ('core','heart','chest_ember')) for obj in parts)
(OUT/'blender_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
