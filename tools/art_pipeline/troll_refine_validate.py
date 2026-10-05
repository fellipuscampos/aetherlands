"""Audit all frames, UV scale, loops, support feet, grip and cloth/thigh overlap."""
import bpy
import bmesh
import math
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['troll_refinement']; scene=st['scene']; rig=st['rig']; meshes=st['meshes']; report=st['report']
bpy.context.window.scene=scene
report['meshes']={}; total=0; densities=[]
for obj in meshes:
    me=obj.data; me.calc_loop_triangles(); bm=bmesh.new(); bm.from_mesh(me)
    bad_edges=sum(not e.is_manifold for e in bm.edges); bm.free()
    bad_weights=sum(abs(sum(g.weight for g in v.groups)-1)>1e-6 for v in me.vertices)
    assert bad_edges==0 and bad_weights==0
    assert all(v.groups for v in me.vertices)
    assert all(p.area>1e-10 and not p.use_smooth for p in me.polygons)
    assert obj.location.length<1e-7 and (obj.scale-Vector((1,1,1))).length<1e-7
    total+=len(me.loop_triangles)
    report['meshes'][obj.name]={'triangles':len(me.loop_triangles),'vertices':len(me.vertices),
                              'nonmanifold_edges':bad_edges,'bad_weights':bad_weights}
    uv=me.uv_layers.active.data
    for p in me.polygons:
        lis=list(p.loop_indices)
        for i,li in enumerate(lis):
            lj=lis[(i+1)%len(lis)]
            length=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
            if length>1e-7: densities.append((uv[li].uv-uv[lj].uv).length*512/length)
report['triangles']=total
report['texture']['measured_min']=min(densities); report['texture']['measured_max']=max(densities)
assert max(abs(d-64) for d in densities)<.03

body=meshes[0]
group={g.index:g.name for g in body.vertex_groups}
bone_of={v.index:group[max(v.groups,key=lambda g:g.weight).group] for v in body.data.vertices}
face_sets={}
for name in ['loincloth_front','loincloth_back','thigh_l','thigh_r']:
    face_sets[name]=[list(p.vertices) for p in body.data.polygons if all(bone_of[v]==name for v in p.vertices)]
foot_indices={side:[v.index for v in body.data.vertices if bone_of[v.index]=='foot_'+side] for side in ('l','r')}
report['animation_validation']={}
for track in rig.animation_data.nla_tracks: track.mute=True
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']
    initial=None; maximum_edge_error=0; min_ground=1e9; max_target_error=0; collisions=[]; max_displacement=0
    foot_track={side:[] for side in ('l','r')}
    for frame in range(data['start'],data['end']+1):
        scene.frame_set(frame); bpy.context.view_layer.update()
        deps=bpy.context.evaluated_depsgraph_get()
        positions=[]
        for obj in meshes:
            ev=obj.evaluated_get(deps); me=ev.to_mesh(); co=[v.co.copy() for v in me.vertices]
            assert all(math.isfinite(c) for v in co for c in v)
            maximum_edge_error=max(maximum_edge_error,max(abs((co[e.vertices[0]]-co[e.vertices[1]]).length-
                   (obj.data.vertices[e.vertices[0]].co-obj.data.vertices[e.vertices[1]].co).length) for e in me.edges))
            if obj==body:
                for side in ('l','r'):
                    ground=min(co[i].z for i in foot_indices[side]); min_ground=min(min_ground,ground)
                    target=Vector(st['foot_targets'][(name,frame,side)])
                    err=(rig.pose.bones['foot_'+side].head-target).length; max_target_error=max(max_target_error,err)
                    foot_track[side].append({'frame':frame,'min_z':ground,'target_error':err})
                bvhs={key:BVHTree.FromPolygons(co,polys,all_triangles=False,epsilon=.000001) for key,polys in face_sets.items()}
                for cloth in ('loincloth_front','loincloth_back'):
                    for thigh in ('thigh_l','thigh_r'):
                        overlap=bvhs[cloth].overlap(bvhs[thigh])
                        if overlap: collisions.append({'frame':frame,'cloth':cloth,'thigh':thigh,'intersections':len(overlap)})
            positions+=co; ev.to_mesh_clear()
        if initial is None: initial=positions
        max_displacement=max(max_displacement,max((a-b).length for a,b in zip(positions,initial)))
    seam=max((a-b).length for a,b in zip(positions,initial))
    if data['loop']: assert seam<1e-5,(name,seam)
    assert maximum_edge_error<1e-5,(name,maximum_edge_error)
    assert min_ground>-.0001,(name,min_ground)
    assert max_target_error<.0001,(name,max_target_error)
    report['animation_validation'][name]={'frames_tested':data['end']-data['start']+1,
      'loop_seam_max_m':seam,'max_edge_length_error_m':maximum_edge_error,'minimum_foot_height_m':min_ground,
      'max_foot_target_error_m':max_target_error,'max_vertex_displacement_m':max_displacement,
      'cloth_thigh_intersections':collisions}
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1); bpy.context.view_layer.update()
report['status']='All frames numerically verified; visual animation review/export pending'
(Path(st['out'])/'troll_blocky_v3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'triangles':total,'uv_density_range':[min(densities),max(densities)],
        'animation_validation':report['animation_validation']}
