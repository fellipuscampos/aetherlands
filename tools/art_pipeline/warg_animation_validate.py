"""Evaluate the baked Warg actions: weights, loop seams, ground, paw targets on all
four legs, and surface crossings that do not already exist at rest.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['warg_animation']; scene=st['scene']; rig=st['rig']; meshes=st['meshes']; NAME=st['name']
LEGS=st['legs']
objects={o.name.removeprefix(NAME+'_'):o for o in meshes}
for track in rig.animation_data.nla_tracks: track.mute=True
def evaluated(objs):
    deps=bpy.context.evaluated_depsgraph_get(); data={}
    for o in objs:
        ev=o.evaluated_get(deps); me=ev.to_mesh()
        data[o]=([ev.matrix_world@v.co for v in me.vertices],[list(p.vertices) for p in me.polygons]); ev.to_mesh_clear()
    return data
for obj in meshes:
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-6 for v in obj.data.vertices),obj.name
    assert len([m for m in obj.modifiers if m.type=='ARMATURE' and m.object==rig])==1
head_parts=[n for n in ('Head','Snout','Nose','Jaw','Fang_l','Fang_r','Cheek_l','Cheek_r','Ear_l','Ear_r') if n in objects]
front=[n for n in objects if n.startswith(('FrontUpper','FrontLower','FrontPaw','FrontClaws','ShoulderFur'))]
hind=[n for n in objects if n.startswith(('HindThigh','HindLower','HindPaw','HindClaws','HipFur'))]
pairs=[(a,b) for a in head_parts for b in front+['ChestRuff']]
pairs+=[(a,b) for a in front if a.endswith('_l') for b in front if b.endswith('_r')]
pairs+=[(a,b) for a in hind if a.endswith('_l') for b in hind if b.endswith('_r')]
pairs+=[(a,b) for a in front for b in hind]
pairs+=[(a,'ChestRuff') for a in front]
pairs+=[(a,b) for a in ('Tail_Base','Tail_Tip') for b in hind]
pairs=[(a,b) for a,b in pairs if a in objects and b in objects and a!=b]
def overlaps(points):
    trees={n:BVHTree.FromPolygons(*points[objects[n]]) for n in set(x for p in pairs for x in p)}
    return {(a,b) for a,b in pairs if trees[a].overlap(trees[b])}
rig.animation_data.action=None; scene.frame_set(1)
for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0)
bpy.context.view_layer.update()
at_rest=overlaps(evaluated([objects[n] for n in set(x for p in pairs for x in p)]))
results={}; hits=[]
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; first=last=None; clip_min=1e9; paw_error=0
    for f in range(1,data['end']+1):
        scene.frame_set(f); bpy.context.view_layer.update(); ev=evaluated(meshes)
        points=[p for pts,_ in ev.values() for p in pts]
        assert all(math.isfinite(c) for p in points for c in p)
        clip_min=min(clip_min,min(p.z for p in points))
        if f==1: first=points
        last=points
        for leg,(a,b,c) in LEGS.items():
            paw_error=max(paw_error,(rig.pose.bones[c].head-Vector(st['targets'][(name,f,leg)])).length)
        for a,b in overlaps(ev)-at_rest: hits.append((name,f,a,b))
    seam=max((a-b).length for a,b in zip(first,last))
    results[name]={'frames':data['end'],'loop':data['loop'],'endpoints_max_vertex_delta_m':seam,
                   'minimum_vertex_z_m':clip_min,'paw_target_error_m':paw_error}
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
problems=[]
for name,r in results.items():
    if r['loop'] and r['endpoints_max_vertex_delta_m']>1e-5: problems.append((name,'seam',r['endpoints_max_vertex_delta_m']))
    if not r['loop'] and r['endpoints_max_vertex_delta_m']>1e-5: problems.append((name,'attack does not return to the crouch',r['endpoints_max_vertex_delta_m']))
    if r['minimum_vertex_z_m']<-1e-5: problems.append((name,'ground',r['minimum_vertex_z_m']))
    if r['paw_target_error_m']>1e-5: problems.append((name,'paw',r['paw_target_error_m']))
st['validation']={'clips':results,'all_vertices_normalized_weights':True,
                  'rest_pose_contacts_excluded':sorted(map(list,at_rest)),'new_surface_crossings':len(hits),'problems':problems}
st['surface_contacts']=hits
(Path(st['out'])/'warg_v1_animation_validation.json').write_text(json.dumps(st['validation'],indent=2),encoding='utf-8')
summary={}
for clip,f,a,b in hits: summary.setdefault((clip,a,b),[]).append(f)
result={'problems':problems,'clips':results,'crossings':{f'{c}:{a}x{b}':[min(v),max(v),len(v)] for (c,a,b),v in summary.items()},
        'rest_contacts':sorted(map(list,at_rest))}
