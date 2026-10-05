"""Check every frame and half-frame for rigid shape, floor clearance and crossings."""
import bpy
import json
from pathlib import Path
from mathutils.bvhtree import BVHTree
st=bpy.app.driver_namespace['mana_devourer']; scene=st['scene']; rig=st['rig']; parts=st['parts']
for tr in rig.animation_data.nla_tracks: tr.mute=True
restedges={o.name:[(e.vertices[:],(o.data.vertices[e.vertices[0]].co-o.data.vertices[e.vertices[1]].co).length) for e in o.data.edges] for o in parts}
results={}; hits=[]; channels=[]; idle_start=None
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; lowest=1e9; rigid_error=0; first=None
    ch=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                ch.update((fc.data_path,fc.array_index) for fc in bag.fcurves)
    channels.append(ch)
    for step in range((data['end']-1)*2+1):
        f=1+step/2; scene.frame_set(int(f),subframe=f-int(f)); dep=bpy.context.evaluated_depsgraph_get()
        points=[]; trees={}
        for o in parts:
            ev=o.evaluated_get(dep); me=ev.to_mesh(); vv=[ev.matrix_world@v.co for v in me.vertices]
            points.extend(vv); trees[o.name]=BVHTree.FromPolygons(vv,[list(p.vertices) for p in me.polygons])
            for (a,b),length in restedges[o.name]: rigid_error=max(rigid_error,abs((vv[a]-vv[b]).length-length))
            ev.to_mesh_clear()
        if first is None: first=[p.copy() for p in points]
        lowest=min(lowest,min(p.z for p in points))
        assert rig.pose.bones['root'].location.length<1e-8
        for i,a in enumerate(parts):
            for b in parts[i+1:]:
                if trees[a.name].overlap(trees[b.name]): hits.append((name,f,a['part'],b['part']))
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5,(name,seam)
    assert lowest>.05,(name,lowest)
    assert rigid_error<1e-5,(name,rigid_error)
    if name=='ManaDevourer_Idle': idle_start=first
    if name=='ManaDevourer_Attack': assert max((a-b).length for a,b in zip(idle_start,first))<1e-5
    results[name]={'seam_vertex_delta_m':seam,'minimum_ground_clearance_m':lowest,'rigid_edge_error_m':rigid_error,'samples':(data['end']-1)*2+1}
assert all(c==channels[0] for c in channels),'Clips must animate identical channels for blending.'
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks: tr.mute=False
scene.frame_set(1)
st['animation_validation']={'clips':results,'surface_crossings':hits,'same_channels_all_clips':True,'root_motion':False}
(Path(st['out'])/'animation_validation.json').write_text(json.dumps(st['animation_validation'],indent=2),encoding='utf-8')
result={'clips':results,'crossing_count':len(hits),'first_crossings':hits[:8]}
