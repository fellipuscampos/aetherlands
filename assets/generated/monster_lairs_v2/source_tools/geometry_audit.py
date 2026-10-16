"""Independent checks for the physical issues found during the V1 art review. Execute via MCP."""
import bpy
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/monster_lairs_v2'
result_rows=[]

def bvh(ob):
    return BVHTree.FromPolygons([v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons],all_triangles=False)

def box_overlap(a,b):
    return all(min(v.co[i] for v in a.data.vertices)<=max(v.co[i] for v in b.data.vertices)+1e-6 and
        min(v.co[i] for v in b.data.vertices)<=max(v.co[i] for v in a.data.vertices)+1e-6 for i in range(3))

for kind in ('worg','troll','arboreal_ancient','corrupted_hero','giant_spider'):
    stem=kind+'_lair_v2'
    with bpy.data.libraries.load(str(OUT/stem/(stem+'.blend')),link=False) as (src,dst): dst.scenes=list(src.scenes)
    scene=dst.scenes[0]; objects=list(scene.objects)
    meshes=[o for o in objects if o.type=='MESH' and 'piece' in o]
    by_piece={}
    for ob in meshes: by_piece.setdefault(ob['piece'],[]).append(ob)
    checks={}
    if kind in ('worg','troll'):
        highest=max(v.co.z for ob in meshes for v in ob.data.vertices)
        origin=Vector((0,3,highest*(.33 if kind=='worg' else .45)))
        hits=[]
        for ob in meshes:
            # Saved libraries need not be evaluated in the active window's dependency graph.
            co,normal,face,distance=bvh(ob).ray_cast(origin,Vector((0,-1,0)))
            if co is not None: hits.append((distance,ob['piece']))
        assert hits
        first=min(hits)[1]
        expected='Closed_earthen_den_back' if kind=='worg' else 'Closed_cave_back_mass'
        assert first==expected,(kind,first,hits)
        checks['rear_ray_hits_solid_back']=True
    if kind=='arboreal_ancient':
        stones=[bvh(ob) for ob in by_piece['Birth_stone']]
        motifs=by_piece['Surface_bound_spiral']
        attached=[any(bvh(ob).overlap(stone) for stone in stones) for ob in motifs]
        assert all(attached),attached
        checks['all_spiral_segments_touch_birth_stones']=True
        checks['spiral_segments']=len(motifs)
    if kind=='corrupted_hero':
        shield=by_piece['Discarded_tower_shield'][0]; panel=by_piece['Attached_blue_shield_panel'][0]
        crest=by_piece['Attached_shield_crest'][0]
        assert bvh(shield).overlap(bvh(panel)),'Shield panel floats'
        assert bvh(panel).overlap(bvh(crest)),'Shield crest floats'
        cloth=by_piece['Ragged_watch_standard'][0]; emblem=by_piece['Faded_standard_crest'][0]
        assert bvh(cloth).overlap(bvh(emblem)),'Standard emblem floats'
        checks['shield_layers_and_standard_emblem_attached']=True
    if kind=='giant_spider':
        hanging=max(by_piece['Silk_cocoon'],key=lambda ob:min(v.co.z for v in ob.data.vertices))
        thread=by_piece['Cocoon_suspension'][0]
        assert bvh(hanging).overlap(bvh(thread)),'Hanging cocoon detached'
        anchors=by_piece['Draped_anchor_strand']
        trunks=by_piece['Dead_broken_trunk']
        front=max(trunks,key=lambda ob:-sum(v.co.y for v in ob.data.vertices)/len(ob.data.vertices))
        assert any(bvh(front).overlap(bvh(ob)) for ob in anchors),'Third snag is disconnected'
        checks['hanging_cocoon_attached']=True
        checks['front_snag_anchors_web']=True
    result_rows.append(dict(kind=kind,status='PASS',checks=checks))
    bpy.data.scenes.remove(scene)
    for ob in objects:
        if ob.users==0: bpy.data.objects.remove(ob)

result=dict(status='PASS',method='Saved-source BVH intersections and rear-facing rays',assets=result_rows)
(OUT/'geometry_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
