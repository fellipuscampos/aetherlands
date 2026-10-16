"""Remove buried faces and partition coincident surfaces of convex wall parts.

Works on the existing pieces and interpolates their approved atlas UVs. No
texture repaint, silhouette changes, normal offsets, or depth-bias workaround.
The last constructed piece owns shared exterior patches (trim over masonry).
"""
import numpy as np

EPS = 8e-7
AREA_EPS = 2e-10


def area(polygon):
    if len(polygon) < 3:
        return 0.0
    p = np.asarray(polygon)[:, :3]
    return np.linalg.norm(sum((np.cross(p[i]-p[0], p[i+1]-p[0]) for i in range(1,len(p)-1)),np.zeros(3)))*.5


def split(polygon, normal, distance):
    """Split a planar convex polygon with (xyz, uv) vertices, preserving UVs."""
    inside, outside = [], []
    if not polygon:
        return inside, outside
    distances = [float(np.dot(v[:3],normal)-distance) for v in polygon]
    projected=[]
    for v,d in zip(polygon,distances):
        if abs(d)<EPS:
            v=v.copy()
            v[:3]-=normal*d
        projected.append(v)
    polygon=projected
    distances = [0.0 if abs(d)<EPS else d for d in distances]
    if not any(distances):
        return polygon, []
    for i, b in enumerate(polygon):
        a, da, db = polygon[i-1], distances[i-1], distances[i]
        if (da<0 and db>0) or (da>0 and db<0):
            intersection = a+(b-a)*(-da/(db-da))
            inside.append(intersection); outside.append(intersection)
        if db<=0: inside.append(b)
        if db>=0: outside.append(b)
    return inside, outside


def planes(vertices, faces):
    result = []
    for face in faces:
        points = np.asarray([vertices[i] for i in face])
        normal = sum((np.cross(points[i]-points[0],points[i+1]-points[0]) for i in range(1,len(points)-1)),np.zeros(3))
        normal /= np.linalg.norm(normal)
        # All modeled prism planes follow the hex grid's 30-degree axes or
        # horizontal layers. Canonical axes avoid float32 errors on thin trims.
        if abs(normal[2])>.99:
            normal=np.array((0.0,0.0,np.sign(normal[2])))
        else:
            angle=np.round(np.arctan2(normal[1],normal[0])/(np.pi/6))*(np.pi/6)
            normal=np.array((np.cos(angle),np.sin(angle),0.0))
        distance = float(np.mean(points@normal))
        if not any(np.dot(normal,n)>.99999999 and abs(distance-d)<EPS for n,d in result):
            result.append((normal,distance))
    return result


def snapshots(parts):
    result = []
    for obj in parts:
        vertices = np.asarray([list(v.co) for v in obj.data.vertices],dtype=float)
        faces = [list(face.vertices) for face in obj.data.polygons]
        uv = obj.data.uv_layers.active
        polygons = [[np.asarray([*vertices[vertex],*uv.data[loop].uv],dtype=float)
                     for vertex,loop in zip(face.vertices,face.loop_indices)] for face in obj.data.polygons]
        result.append(dict(obj=obj,vertices=vertices,faces=faces,polygons=polygons,
                           planes=planes(vertices,faces),lo=vertices.min(axis=0),hi=vertices.max(axis=0)))
    return result


def intersection(polygon, solid):
    for normal,distance in solid['planes']:
        polygon,_ = split(polygon,normal,distance)
        if area(polygon)<=AREA_EPS:
            return []
    return polygon


def subtract(polygon, solid):
    outside = []
    for normal,distance in solid['planes']:
        polygon,fragment = split(polygon,normal,distance)
        if area(fragment)>AREA_EPS:
            outside.append(fragment)
        if area(polygon)<=AREA_EPS:
            return outside
    return outside


def overlapping(a,b):
    return np.all(a['hi']+EPS>=b['lo']) and np.all(b['hi']+EPS>=a['lo'])


def audit_coplanar(parts, include_opposing=False):
    """Count overlapping face interiors, excluding shared-edge float32 noise."""
    faces=[]
    groups={}
    for obj in parts:
        uv=obj.data.uv_layers.active
        for face in obj.data.polygons:
            polygon=[np.asarray([*obj.data.vertices[v].co,*uv.data[loop].uv],dtype=float)
                     for v,loop in zip(face.vertices,face.loop_indices)]
            if area(polygon)<=AREA_EPS: continue
            points=np.asarray(polygon)[:,:3]
            normal,distance=planes(points,[list(range(len(points)))])[0]
            index=len(faces)
            faces.append(dict(obj=obj,polygon=polygon,normal=normal,distance=distance,
                              lo=points.min(axis=0),hi=points.max(axis=0)))
            key=(*np.round(normal,3),int(np.floor(distance/.0001)))
            groups.setdefault(key,[]).append(index)
    overlaps=[]
    for i,a in enumerate(faces):
        normal,distance=a['normal'],a['distance']
        bucket=int(np.floor(distance/.0001))
        candidates=[j for offset in (-1,0,1) for j in groups.get((*np.round(normal,3),bucket+offset),[]) if j>i]
        if include_opposing:
            opposite_bucket=int(np.floor(-distance/.0001))
            candidates += [j for offset in (-1,0,1) for j in groups.get((*np.round(-normal,3),opposite_bucket+offset),[]) if j>i]
        for j in candidates:
            b=faces[j]
            alignment=np.dot(normal,b['normal'])
            coplanar=(alignment>.999999 and abs(distance-b['distance'])<EPS)
            if include_opposing: coplanar=coplanar or (alignment<-.999999 and abs(distance+b['distance'])<EPS)
            if not overlapping(a,b) or not coplanar: continue
            patch=a['polygon']
            for k,p in enumerate(b['polygon']):
                q=b['polygon'][(k+1)%len(b['polygon'])]
                edge_normal=np.cross(q[:3]-p[:3],b['normal'])
                length=np.linalg.norm(edge_normal)
                if length<EPS: continue
                edge_normal/=length
                # Contract the test polygon by the positional tolerance. Adjacent
                # fragments otherwise produce false slivers when a shared edge
                # is rounded back to float32; actual surface overlaps remain.
                patch,_=split(patch,edge_normal,float(p[:3].dot(edge_normal))-2*EPS)
                if area(patch)<=AREA_EPS: break
            if area(patch)>AREA_EPS:
                overlaps.append(dict(first=a['obj'].get('part',a['obj'].name),second=b['obj'].get('part',b['obj'].name),area=area(patch)))
    return overlaps


def clean_human_wall_surfaces(parts):
    import bpy
    solids=snapshots(parts)
    cleaned=[]
    total_removed_area=0.0
    for index,solid in enumerate(solids):
        neighbours=[(j,other) for j,other in enumerate(solids) if j!=index and overlapping(solid,other)]
        output=[]
        for polygon in solid['polygons']:
            normal,distance=planes(np.asarray(polygon)[:,:3],[list(range(len(polygon)))])[0]
            fragments=[polygon]
            for other_index,other in neighbours:
                # Coplanar outward patches belong to the later architectural
                # detail. Opposing interfaces and buried faces are discarded.
                shared=any(np.dot(normal,n)>.999999 and abs(distance-d)<EPS for n,d in other['planes'])
                if shared and index>other_index: continue
                remaining=[]
                for fragment in fragments:
                    patch=intersection(fragment,other)
                    if area(patch)<=AREA_EPS:
                        remaining.append(fragment)
                    else:
                        remaining.extend(subtract(fragment,other))
                fragments=remaining
                if not fragments: break
            total_removed_area+=area(polygon)-sum(area(f) for f in fragments)
            output.extend(fragments)
        cleaned.append(output)

    # Mutate only after the calculations finish; keep the existing objects,
    # labels, material, hierarchy and editable part identities.
    for solid,polygons in zip(solids,cleaned):
        obj=solid['obj']
        old=obj.data
        vertices=[]; faces=[]; uvs=[]
        for polygon in polygons:
            if area(polygon)<=AREA_EPS: continue
            faces.append(tuple(range(len(vertices),len(vertices)+len(polygon))))
            vertices.extend([tuple(v[:3]) for v in polygon])
            uvs.append([tuple(v[3:]) for v in polygon])
        data=bpy.data.meshes.new(old.name+'_VisibleBoundary')
        data.from_pydata(vertices,[],faces); data.update()
        for material in old.materials: data.materials.append(material)
        uv=data.uv_layers.new(name='Approved_City_Atlas_UV')
        for face,values in zip(data.polygons,uvs):
            for loop,value in zip(face.loop_indices,values): uv.data[loop].uv=value
            face.use_smooth=False
        obj.data=data
        obj['surface_cleanup']='Visible boundary, UV-preserving convex solid subtraction v1'
        if old.users==0: bpy.data.meshes.remove(old)
    return dict(removed_buried_and_shared_face_area=float(total_removed_area),source_parts=len(parts),
                visible_parts=sum(bool(o.data.polygons) for o in parts),
                visible_faces=sum(len(o.data.polygons) for o in parts))
