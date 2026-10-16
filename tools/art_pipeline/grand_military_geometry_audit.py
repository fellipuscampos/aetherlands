"""Actual coplanar face overlap, roof penetration and entrance checks in Blender.

Uses clipped triangle intersections and short outward rays to ignore buried
contacts. Opposite-facing contact surfaces are deliberately not z-fighting.
"""
import math
from collections import defaultdict
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def bb(obj):
    return [Vector(tuple(f(v.co[k] for v in obj.data.vertices) for k in range(3)))
            for f in (min, max)]


def obj_bvh(obj):
    return BVHTree.FromPolygons([v.co for v in obj.data.vertices],
                               [p.vertices[:] for p in obj.data.polygons])


def scene_bvh(parts):
    vertices, polygons = [], []
    for obj in parts:
        offset = len(vertices)
        vertices.extend(v.co.copy() for v in obj.data.vertices)
        polygons.extend([i+offset for i in p.vertices] for p in obj.data.polygons)
    return BVHTree.FromPolygons(vertices, polygons)


def cross(a,b,c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def clip_triangle(poly, tri):
    if cross(*tri) < 0:
        tri = tri[::-1]
    for a,b in zip(tri, tri[1:]+tri[:1]):
        out = []
        for s,e in zip(poly, poly[1:]+poly[:1]):
            ds,de = cross(a,b,s),cross(a,b,e)
            if (ds>=-1e-10) != (de>=-1e-10):
                t = ds/(ds-de)
                out.append((s[0]+t*(e[0]-s[0]),s[1]+t*(e[1]-s[1])))
            if de>=-1e-10:
                out.append(e)
        poly = out
        if len(poly)<3:
            return []
    return poly


def coplanar_conflicts(parts):
    tree = scene_bvh(parts)
    boxes=[bb(o) for o in parts]
    individual={}
    inside_ray=Vector((.811,.331,.481)).normalized()
    buckets = defaultdict(list)
    for oi,obj in enumerate(parts):
        obj.data.calc_loop_triangles()
        for tri in obj.data.loop_triangles:
            face = obj.data.polygons[tri.polygon_index]
            n = face.normal.copy()
            verts = [obj.data.vertices[i].co.copy() for i in tri.vertices]
            d = n.dot(verts[0])
            key = tuple(round(x,4) for x in n)+(round(d,4),)
            axis = max(range(3),key=lambda i:abs(n[i]))
            uv = [i for i in range(3) if i!=axis]
            points = [tuple(v[i] for i in uv) for v in verts]
            bounds = (min(p[0] for p in points),min(p[1] for p in points),
                      max(p[0] for p in points),max(p[1] for p in points))
            buckets[key].append((oi,face.index,n,d,axis,uv,points,bounds))
    rows,seen = [],set()
    for group in buckets.values():
        for i,a in enumerate(group):
            for b in group[i+1:]:
                if (a[0]==b[0] and a[1]==b[1]) or abs(a[3]-b[3])>2e-6 or a[2].dot(b[2])<.999999:
                    continue
                pair = tuple(sorted(((a[0],a[1]),(b[0],b[1]))))
                if pair in seen:
                    continue
                aa,ba=a[7],b[7]
                if aa[2]<=ba[0]+1e-7 or ba[2]<=aa[0]+1e-7 or aa[3]<=ba[1]+1e-7 or ba[3]<=aa[1]+1e-7:
                    continue
                poly = clip_triangle(a[6],b[6])
                if len(poly)<3:
                    continue
                area = abs(sum(p[0]*q[1]-q[0]*p[1] for p,q in zip(poly,poly[1:]+poly[:1])))/2
                if area<1e-7:
                    continue
                pt = Vector((0,0,0))
                for k,axis in enumerate(a[5]):
                    pt[axis]=sum(p[k] for p in poly)/len(poly)
                pt[a[4]]=(a[3]-sum(a[2][k]*pt[k] for k in a[5]))/a[2][a[4]]
                outside=pt+a[2]*.00003
                buried=False
                for oi,(lo,hi) in enumerate(boxes):
                    if not all(lo[k]+1e-7<outside[k]<hi[k]-1e-7 for k in range(3)):
                        continue
                    if oi not in individual:
                        individual[oi]=obj_bvh(parts[oi])
                    exit_hit=individual[oi].ray_cast(outside,inside_ray)
                    if exit_hit[0] is not None and exit_hit[1].dot(inside_ray)>1e-6:
                        buried=True
                        break
                if buried:
                    continue
                # A surface deep inside another solid is not visible flicker.
                hit = tree.ray_cast(outside,a[2])
                if hit[0] is not None and (hit[3]<.008 or hit[1].dot(a[2])>.01):
                    continue
                seen.add(pair)
                rows.append({'a':parts[a[0]]['part'],'b':parts[b[0]]['part'],
                             'face_a':a[1],'face_b':b[1], 'normal':list(a[2]),
                             'plane':a[3], 'area':area})
    return rows


def roof_hits(parts, targets=None):
    roofs=[o for o in parts if o.get('region') in ('roof','roof_dark','canvas')]
    targets = targets if targets is not None else [o for o in parts if o['part'].startswith('Standard_') or
        ('_Post_Shaft' in o['part'] and any(s in o['part'] for s in ('Perch','Dock','Nest')))]
    rows=[]
    for roof in roofs:
        rlo,rhi=bb(roof)
        tree=None
        for obj in targets:
            lo,hi=bb(obj)
            if any(lo[k]>=rhi[k]-.0001 or hi[k]<=rlo[k]+.0001 for k in range(3)):
                continue
            if tree is None:
                tree=obj_bvh(roof)
            # Test centre and a grid across the overlapping footprint.
            x0,x1=max(lo.x,rlo.x),min(hi.x,rhi.x)
            y0,y1=max(lo.y,rlo.y),min(hi.y,rhi.y)
            collision=False
            for fx in (.1,.5,.9):
                for fy in (.1,.5,.9):
                    hit=tree.ray_cast(Vector((x0+fx*(x1-x0),y0+fy*(y1-y0),rhi.z+.01)),Vector((0,0,-1)))
                    if hit[0] is not None and lo.z < hit[0].z-.0001 and hi.z > rlo.z+.0001:
                        collision=True
            if collision:
                rows.append({'part':obj['part'],'roof':roof['part']})
    return rows


def doors(parts):
    prefixes=sorted(set(o['part'].rsplit('_Door_',1)[0] for o in parts if '_Door_' in o['part'] and o['part'].endswith(('_-1','_1'))))
    result=[]
    for prefix in prefixes:
        leaves=[o for o in parts if o['part'] in (prefix+'_Door_-1',prefix+'_Door_1')]
        if len(leaves)!=2:
            continue
        bounds=[bb(o) for o in leaves]
        lo=Vector(tuple(min(b[0][k] for b in bounds) for k in range(3)))
        hi=Vector(tuple(max(b[1][k] for b in bounds) for k in range(3)))
        result.append({'prefix':prefix,'x':(lo.x+hi.x)/2,'front':lo.y,
                       'bottom':lo.z,'top':hi.z,'width':hi.x-lo.x})
    return result


def door_blockers(parts):
    rows=[]
    for door in doors(parts):
        # Walking envelope, excluding the frame and floor-height stair treads.
        x,y,z=door['x'],door['front'],door['bottom']+.035
        w=door['width']*.85
        lo=Vector((x-w/2,y-.18,z))
        hi=Vector((x+w/2,y-.002,door['top']-.015))
        blocked=[]
        for obj in parts:
            name=obj['part']
            if name.startswith(door['prefix']+'_') and any(s in name for s in ('Door','Jamb','Backing','Lintel','Handle','Stair','Point','Fang')):
                continue
            if any(s in name for s in ('Stair','Hex_','Target','Dummy')):
                continue
            a,b=bb(obj)
            if not all(a[k]<hi[k]-.001 and b[k]>lo[k]+.001 for k in range(3)):
                continue
            tree=obj_bvh(obj)
            hits=False
            for fx in (.12,.5,.88):
                for fz in (.1,.45,.8):
                    start=Vector((lo.x+fx*(hi.x-lo.x),lo.y,lo.z+fz*(hi.z-lo.z)))
                    hit=tree.ray_cast(start,Vector((0,1,0)),hi.y-lo.y)
                    if hit[0] is not None:
                        hits=True
            if hits:
                blocked.append(name)
        rows.append({**door,'blockers':blocked})
    return rows


def passage_blockers(parts, scene=None):
    """Clear routes through open pavilions and courtyard gates, not just doors."""
    routes=[]
    for floor in parts:
        if not floor['part'].endswith('_Floor'):
            continue
        prefix=floor['part'][:-6]
        lintel=next((o for o in parts if o['part']==prefix+'_Front_Lintel'),None)
        if lintel is None:
            continue
        a,b=bb(floor)
        top=bb(lintel)[0].z-.025
        width=max(.060,b.x-a.x-.165)
        centre=(a.x+b.x)/2
        # A divided stable has separate bays; an assembly hall has a narrow
        # pedestrian approach beside its demonstration machine.
        if prefix=='War_Mount_Longhouse':
            centre,width=-.08,.10
        if prefix=='Colossus_Assembly_Vault':
            centre,width=-.41,.12
        if prefix=='Ram_Assembly_Hangar':
            centre,width=-.42,.10
        if prefix=='Engineering_Bay_-0.3':
            centre,width=-.42,.12
        if prefix=='Sneak_Prep_Awning':
            continue  # Workbench shelter, not a pedestrian entrance.
        routes.append({'name':prefix,'lo':[centre-width/2,a.y-.125,b.z+.035],
                       'hi':[centre+width/2,a.y+.080,top]})
    if scene is not None:
        civ,role=scene['civilization'],scene['military_role']
        if role=='warrior':
            routes.append({'name':'Courtyard_Gate','lo':[-.10,-.61,.14],'hi':[.10,-.25,.48]})
        if role=='cavalry' and civ=='human':
            routes.append({'name':'Officers_Court_Approach','lo':[-.070,-.60,.135],'hi':[.070,.20,.40]})
        if role=='cavalry' and civ=='elf':
            routes.append({'name':'Living_Order_Gate','lo':[-.10,-.58,.135],'hi':[.040,-.05,.40]})
        if role=='cavalry' and civ=='dwarf':
            routes.append({'name':'Left_Stable_Gate','lo':[-.29,-.52,.135],'hi':[-.15,.07,.45]})
        if role=='ranger' and civ=='dwarf':
            routes.append({'name':'Survey_Tower_Approach','lo':[-.135,-.54,.16],'hi':[.015,-.12,.45]})
    rows=[]
    for route in routes:
        lo,hi=Vector(route['lo']),Vector(route['hi'])
        blockers=[]
        for obj in parts:
            if obj['part'].startswith('Hex_') or obj.get('region')=='horse_source' or any(s in obj['part'] for s in ('Stair','Threshold')):
                continue
            a,b=bb(obj)
            if not all(a[k]<hi[k]-.001 and b[k]>lo[k]+.001 for k in range(3)):
                continue
            tree=obj_bvh(obj)
            for fx in (.1,.3,.5,.7,.9):
                for fz in (.1,.4,.7,.9):
                    hit=tree.ray_cast(Vector((lo.x+fx*(hi.x-lo.x),lo.y,lo.z+fz*(hi.z-lo.z))),Vector((0,1,0)),hi.y-lo.y)
                    if hit[0] is not None:
                        blockers.append(obj['part'])
                        break
                if obj['part'] in blockers:
                    break
        rows.append({**route,'blockers':blockers})
    return rows


def geometry_audit(parts, scene=None):
    return {'coplanar_faces':coplanar_conflicts(parts),'mast_roof_intersections':roof_hits(parts),
            'entrances':door_blockers(parts),'open_passages':passage_blockers(parts,scene)}
