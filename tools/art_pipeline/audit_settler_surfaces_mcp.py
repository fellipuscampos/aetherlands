"""Report same-facing coplanar positive-area faces in live static settlers."""
import bpy, json, math
from pathlib import Path
from mathutils import Vector
from collections import defaultdict

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
assets=bpy.app.driver_namespace['settlers_v1_assets']

def area(poly): return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))*.5
def intersect(subject,clip):
    if area(clip)<0: clip=list(reversed(clip))
    result=subject
    for a,b in zip(clip,clip[1:]+clip[:1]):
        old=result; result=[]
        if not old: break
        def dist(p): return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
        for p,q in zip(old,old[1:]+old[:1]):
            dp,dq=dist(p),dist(q)
            if dp>=-1e-10: result.append(p)
            if (dp>=0)!=(dq>=0):
                t=dp/(dp-dq); result.append(tuple(p[i]+t*(q[i]-p[i]) for i in (0,1)))
    return result

def inside(obj,p):
    # All parts are closed convex cuboids, including diagonal straps and tools.
    return all(poly.normal.dot(p-obj.data.vertices[poly.vertices[0]].co)<-1e-7 for poly in obj.data.polygons)

def audit(parts):
    planes=defaultdict(list); issues=[]; hidden=[]
    for obj in parts:
        for face in obj.data.polygons:
            n=face.normal; pts=[obj.data.vertices[i].co for i in face.vertices]; d=n.dot(pts[0])
            key=tuple(round(v,5) for v in n)+(round(d,5),)
            axis=max(range(3),key=lambda i:abs(n[i])); axes=[i for i in range(3) if i!=axis]
            poly=[tuple(v[i] for i in axes) for v in pts]
            planes[key].append((obj,face,poly,axis,axes))
    for records in planes.values():
        for i,(obj,face,poly,axis,axes) in enumerate(records):
            for other,second,clip,_,_ in records[i+1:]:
                if obj==other: continue
                if any(min(max(p[j] for p in poly),max(p[j] for p in clip))-max(min(p[j] for p in poly),min(p[j] for p in clip))<1e-7 for j in (0,1)): continue
                hit=intersect(poly,clip)
                if len(hit)<3 or abs(area(hit))<1e-8: continue
                mid=[sum(v[j] for v in hit)/len(hit) for j in (0,1)]
                pt=Vector((0,0,0)); pt[axes[0]]=mid[0]; pt[axes[1]]=mid[1]
                n=face.normal; d=n.dot(obj.data.vertices[face.vertices[0]].co)
                pt[axis]=(d-n[axes[0]]*mid[0]-n[axes[1]]*mid[1])/n[axis]
                blocker=next((o for o in parts if o not in (obj,other) and inside(o,pt+n*.0001)),None)
                row=dict(a=obj['part'],face_a=face.index,b=other['part'],face_b=second.index,area=abs(area(hit)),normal=list(n),point=list(pt))
                if blocker: row['blocker']=blocker['part']; hidden.append(row)
                else: issues.append(row)
    return issues,hidden

rows=[]
for asset in assets:
    issues,hidden=audit(asset['parts'])
    rows.append(dict(race=asset['report']['race'],exposed_coplanar_pairs=len(issues),hidden_coplanar_pairs=len(hidden),issues=issues,hidden=hidden))
    print(asset['report']['race'],'exposed',len(issues),'hidden',len(hidden),[(i['a'],i['b']) for i in issues])
bpy.app.driver_namespace['settlers_v1_surface_audit']=audit
(ROOT/'art_source/settlers_review/surface_audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
result={'verified':4,'exposed_coplanar_pairs':sum(r['exposed_coplanar_pairs'] for r in rows)}
