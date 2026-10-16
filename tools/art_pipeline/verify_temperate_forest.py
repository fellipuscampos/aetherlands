"""Check actual GLB geometry, metric UV density and coplanar surface overlap."""
import hashlib
import json
import math
from pathlib import Path
import struct
from collections import defaultdict,Counter
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/generated/nature/temperate_forest_v1'
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
assert Counter(r['category'] for r in manifest['assets'])=={'main_tree':4,'small_tree':2,'shrub':2,'fallen_log':1,'decoration':1}
atlas=(OUT/'textures/forest_pixel_atlas.png').read_bytes()
atlas_hash=hashlib.sha256(atlas).hexdigest()
with Image.open(OUT/'textures/forest_pixel_atlas.png') as image:
    assert image.size==(512,512)
    rgb=image.convert('RGB').transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    for region in range(9):
        x,y=region%4*128,region//4*128
        assert len(rgb.crop((x+4,y+4,x+124,y+124)).getcolors(120*120))>12,'Texture region is flat.'

def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(sum(v*v for v in a))
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

verified=[]; signatures=set()
for report in manifest['assets']:
    asset=report['asset']; folder=OUT/'models'/asset
    raw=(folder/(asset+'.glb')).read_bytes()
    assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert len(doc['meshes'])==len(doc['materials'])==len(doc['images'])==1
    assert not doc.get('cameras') and not doc.get('skins') and not doc.get('animations')
    assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
    assert not doc['materials'][0].get('doubleSided',False)
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert all(s.get('magFilter')==9728 for s in doc['samplers'])
    image_view=doc['bufferViews'][doc['images'][0]['bufferView']]
    start=image_view.get('byteOffset',0)
    assert hashlib.sha256(binary[start:start+image_view['byteLength']]).hexdigest()==atlas_hash
    def accessor(index):
        a=doc['accessors'][index]; view=doc['bufferViews'][a['bufferView']]
        fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        stride=view.get('byteStride',struct.calcsize('<'+fmt*count))
        offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*count,binary,offset+i*stride) for i in range(a['count'])]
    assert len(doc['meshes'][0]['primitives'])==1
    primitive=doc['meshes'][0]['primitives'][0]
    points=accessor(primitive['attributes']['POSITION']); uvs=accessor(primitive['attributes']['TEXCOORD_0'])
    indices=[v[0] for v in accessor(primitive['indices'])]
    assert len(indices)//3==report['triangles']<=700
    assert all(math.isfinite(c) for p in points for c in p)
    assert min(p[1] for p in points)==0
    expected=report['bounds_blender']
    for axis,source_axis,sign in ((0,0,1),(1,2,1),(2,1,-1)):
        values=[expected['min'][source_axis]*sign,expected['max'][source_axis]*sign]
        assert abs(min(p[axis] for p in points)-min(values))<1e-6
        assert abs(max(p[axis] for p in points)-max(values))<1e-6
    planes=defaultdict(list); max_density_error=0
    for base in range(0,len(indices),3):
        ids=indices[base:base+3]; tri=[points[i] for i in ids]
        normal=cross(sub(tri[1],tri[0]),sub(tri[2],tri[0])); magnitude=length(normal)
        assert magnitude>1e-9,(asset,'degenerate triangle')
        normal=tuple(v/magnitude for v in normal)
        distance=sum(a*b for a,b in zip(normal,tri[0])); drop=max(range(3),key=lambda i:abs(normal[i]))
        axes=[a for a in range(3) if a!=drop]
        polygon=[(p[axes[0]],p[axes[1]]) for p in tri]
        planes[tuple(round(v,5) for v in normal)+(round(distance,5),)].append(polygon)
        for first,second in zip(ids,ids[1:]+ids[:1]):
            world_distance=length(sub(points[first],points[second]))
            pixel_distance=length(sub(uvs[first],uvs[second]))*512
            error=abs(pixel_distance/world_distance-128)
            max_density_error=max(max_density_error,error)
            assert error<.002,(asset,'stretched texture',error)
    overlap=0
    for polygons in planes.values():
        for i,a in enumerate(polygons):
            for b in polygons[i+1:]:
                if any(min(max(p[j] for p in a),max(p[j] for p in b))-max(min(p[j] for p in a),min(p[j] for p in b))<=1e-7 for j in (0,1)): continue
                polygon=intersect(a,b)
                if len(polygon)>=3 and abs(area(polygon))>1e-8: overlap+=1
    assert overlap==0,(asset,'coplanar overlap',overlap)
    signature=hashlib.sha256(repr(sorted(set(points))).encode()).hexdigest()
    assert signature not in signatures,'Variants are identical geometry.'
    signatures.add(signature)
    assert (folder/(asset+'.blend')).is_file()
    for view in ('three_quarter','game_top','top','back'):
        with Image.open(folder/'previews'/(view+'.png')) as image:
            assert image.size==(700,700); image.verify()
    verified.append({'asset':asset,'triangles':report['triangles'],'surface_count':1,'atlas_sha256':atlas_hash,'metric_uv_max_error':max_density_error,'coplanar_overlap_pairs':0,'geometry_sha256':signature})
summary={'status':'PASS','verified':len(verified),'triangles_total':sum(r['triangles'] for r in verified),'pixel_density':128,'atlas_size':[512,512],'shared_atlas':True,'coplanar_overlap_pairs':0,'no_tile_geometry':True,'assets':verified}
(ROOT/'docs/temperate_forest_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='assets'}))
