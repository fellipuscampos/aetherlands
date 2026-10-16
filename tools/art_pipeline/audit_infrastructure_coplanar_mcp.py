"""Find exposed coplanar overlap between native components (actual polygon area)."""
import bpy
import hashlib
import json
import math
import time
from collections import defaultdict
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
REVIEW=ROOT/'art_source/infrastructure_roof_review'
AUDIT_LABEL=globals().get('AUDIT_LABEL','before_face_repairs')
entries=json.loads((ROOT/'art_source/infrastructure_buildings_review/completed.json').read_text(encoding='utf-8'))

def signed_area(points):
    return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(points,points[1:]+points[:1]))*.5

def intersect(subject,clip):
    if signed_area(clip)<0: clip=list(reversed(clip))
    result=subject
    for a,b in zip(clip,clip[1:]+clip[:1]):
        previous=result
        result=[]
        if not previous: break
        def distance(p): return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
        for p,q in zip(previous,previous[1:]+previous[:1]):
            dp,dq=distance(p),distance(q)
            if dp>=-1e-10: result.append(p)
            if (dp>=0)!=(dq>=0):
                t=dp/(dp-dq)
                result.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])))
    return result

views=[Vector((2.6,-4,3.3))-Vector((0,0,.61)),Vector((1.8,-2.9,4.9))-Vector((0,0,.61)),Vector((0,0,1)),Vector((-2.6,4,3.4))-Vector((0,0,.61)),Vector((0,-1,0)),Vector((0,1,0)),Vector((1,0,0)),Vector((-1,0,0))]
rows=[]
started=time.monotonic()
for entry in entries:
    plural={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}[entry['civilization']]
    out=ROOT/'assets/generated'/plural/'buildings'/entry['asset']
    report=json.loads((out/(entry['asset']+'_report.json')).read_text(encoding='utf-8'))
    scene=bpy.data.scenes[report['name']]
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio' and not o.get('preview_only')]
    vertices=[]; triangles=[]; planes=defaultdict(list)
    for obj in parts:
        offset=len(vertices)
        vertices.extend(v.co.copy() for v in obj.data.vertices)
        obj.data.calc_loop_triangles()
        for tri in obj.data.loop_triangles:
            indices=tuple(offset+i for i in tri.vertices)
            points=[vertices[i] for i in indices]
            normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
            distance=normal.dot(points[0])
            key=tuple(round(c,5) for c in normal)+(round(distance,5),)
            drop=max(range(3),key=lambda i:abs(normal[i]))
            axes=[i for i in range(3) if i!=drop]
            projected=[(p[axes[0]],p[axes[1]]) for p in points]
            bounds=[min(p[i] for p in projected) for i in (0,1)]+[max(p[i] for p in projected) for i in (0,1)]
            planes[key].append({'part':obj['part'],'face':tri.polygon_index,'normal':normal,'distance':distance,'drop':drop,'axes':axes,'projected':projected,'bounds':bounds})
            triangles.append(indices)
    bvh=BVHTree.FromPolygons(vertices,triangles,all_triangles=True,epsilon=0)
    overlaps={}; hidden=0
    for bucket in planes.values():
        for i,a in enumerate(bucket):
            for b in bucket[i+1:]:
                if a['part']==b['part']: continue
                if abs(a['distance']-b['distance'])>2e-6 or a['normal'].dot(b['normal'])<1-1e-7: continue
                pair=tuple(sorted(((a['part'],a['face']),(b['part'],b['face']))))
                box_a,box_b=a['bounds'],b['bounds']
                if min(box_a[2],box_b[2])-max(box_a[0],box_b[0])<=1e-7 or min(box_a[3],box_b[3])-max(box_a[1],box_b[1])<=1e-7: continue
                polygon=intersect(a['projected'],b['projected'])
                if len(polygon)<3: continue
                area=abs(signed_area(polygon))/abs(a['normal'][a['drop']])
                if area<1e-8: continue
                # Sample the intersection interior, then test visibility against
                # all game geometry. Studio geometry is intentionally excluded.
                center=[sum(p[axis] for p in polygon)/len(polygon) for axis in (0,1)]
                point=Vector((0,0,0))
                for axis,value in zip(a['axes'],center): point[axis]=value
                normal=a['normal']
                point[a['drop']]=(a['distance']-sum(normal[axis]*point[axis] for axis in a['axes']))/normal[a['drop']]
                samples=[point]
                for corner in polygon:
                    sample=point.copy()
                    for axis,value,centroid in zip(a['axes'],corner,center): sample[axis]=value*.8+centroid*.2
                    sample[a['drop']]=(a['distance']-sum(normal[axis]*sample[axis] for axis in a['axes']))/normal[a['drop']]
                    samples.append(sample)
                visible=False
                for sample in samples:
                    for direction in views+[normal]:
                        direction=direction.normalized()
                        if normal.dot(direction)<.05: continue
                        hit=bvh.ray_cast(sample+direction*3e-6,direction,10)
                        if hit[0] is None:
                            visible=True; break
                    if visible: break
                if not visible:
                    hidden+=1; continue
                previous=overlaps.setdefault(pair,{'first':pair[0][0],'first_face':pair[0][1],'second':pair[1][0],'second_face':pair[1][1],'area':0,'normal':[float(n) for n in normal],'example_point':[float(c) for c in point]})
                previous['area']+=area
    position_signature=hashlib.sha256(repr(sorted({tuple(round(float(c),6) or 0.0 for c in v) for v in vertices})).encode()).hexdigest()
    rows.append({'asset':entry['asset'],'civilization':entry['civilization'],'role':entry['role'],'source_position_sha256':position_signature,'exposed_overlap_faces':len(overlaps),'hidden_triangle_overlaps':hidden,'overlaps':list(overlaps.values())})
summary={'method':'Native Blender MCP; triangle clipping on matching outward planes, visible area checked against a BVH of all game meshes','label':AUDIT_LABEL,'assets':rows,'assets_with_exposed_overlap':sum(bool(r['overlaps']) for r in rows),'exposed_overlap_faces':sum(r['exposed_overlap_faces'] for r in rows),'seconds':round(time.monotonic()-started,1)}
destination=REVIEW/(AUDIT_LABEL+'.json')
if AUDIT_LABEL=='before_face_repairs': assert not destination.exists(),'Keep the original face audit.'
destination.write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
result={'label':AUDIT_LABEL,'assets':len(rows),'assets_with_exposed_overlap':summary['assets_with_exposed_overlap'],'exposed_overlap_faces':summary['exposed_overlap_faces'],'seconds':summary['seconds'],'overlaps':[{'asset':r['asset'],'pairs':[(o['first'],o['second'],round(o['area'],6)) for o in r['overlaps']]} for r in rows if r['overlaps']]}
