"""Validate actual settler GLBs, rigid skins, loop samples and pixel density."""
import json, math, hashlib, struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/settlers_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
assert {r['race'] for r in manifest['assets']}=={'human','elf','dwarf','orc'}
animated=manifest['animations']==2
assert manifest['animations'] in (0,2)
reports=[]; signatures=set()
for row in manifest['assets']:
    folder=(ROOT/row['glb']).parent
    raw=(ROOT/row['glb']).read_bytes(); size=struct.unpack_from('<I',raw,12)[0]
    assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert len(doc['meshes'])==len(doc['materials'])==len(doc['images'])==1
    assert len(doc['meshes'][0]['primitives'])==1
    assert not doc.get('cameras')
    if animated:
        assert len(doc.get('skins',[]))==1 and len(doc['skins'][0]['joints'])==16
        assert sorted(a['name'] for a in doc['animations'])==['idle','walk']
    else:
        assert not doc.get('skins') and not doc.get('animations')
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert all(s.get('magFilter')==9728 for s in doc['samplers'])
    assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
    assert not doc['materials'][0].get('doubleSided',False)
    if not animated:
        assert all(n.get('scale',[1,1,1])==[1,1,1] and n.get('translation',[0,0,0])==[0,0,0] and n.get('rotation',[0,0,0,1])==[0,0,0,1] for n in doc['nodes'])
    image_view=doc['bufferViews'][doc['images'][0]['bufferView']]
    embedded=binary[image_view.get('byteOffset',0):image_view.get('byteOffset',0)+image_view['byteLength']]
    texture=ROOT/row['texture']; texture_bytes=texture.read_bytes()
    assert hashlib.sha256(embedded).hexdigest()==hashlib.sha256(texture_bytes).hexdigest()
    with Image.open(texture) as image:
        assert image.size==(512,512)
        # A restrained pixel palette is intentional; verify actual texture variation.
        assert len(image.convert('RGB').getcolors(512*512))>50
    def accessor(index):
        a=doc['accessors'][index]; view=doc['bufferViews'][a['bufferView']]
        fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        stride=view.get('byteStride',struct.calcsize('<'+fmt*count))
        offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*count,binary,offset+i*stride) for i in range(a['count'])]
    p=doc['meshes'][0]['primitives'][0]
    points=accessor(p['attributes']['POSITION']); uvs=accessor(p['attributes']['TEXCOORD_0']); normals=accessor(p['attributes']['NORMAL'])
    if animated:
        joints=accessor(p['attributes']['JOINTS_0']); weights=accessor(p['attributes']['WEIGHTS_0'])
        assert all(abs(sum(w)-1)<1e-6 and max(w)>.999999 for w in weights)
        assert all(0<=j<16 for ids,w in zip(joints,weights) for j,weight in zip(ids,w) if weight>.00001)
        for animation in doc['animations']:
            expected=3.0 if animation['name']=='idle' else 1.5
            for sampler in animation['samplers']:
                times=[t[0] for t in accessor(sampler['input'])]; values=accessor(sampler['output'])
                assert abs(min(times))<1e-6 and abs(max(times)-expected)<1e-5
                assert all(a<b for a,b in zip(times,times[1:]))
                assert all(math.isfinite(v) for value in values for v in value)
                direct=max(abs(a-b) for a,b in zip(values[0],values[-1]))
                opposite=max(abs(a+b) for a,b in zip(values[0],values[-1])) if len(values[0])==4 else direct
                assert min(direct,opposite)<.00002,(row['stem'],animation['name'],'loop')
    indices=[r[0] for r in accessor(p['indices'])]
    assert len(indices)//3==row['triangles']<1600
    assert all(math.isfinite(c) for point in points for c in point)
    assert abs(min(point[1] for point in points))<1e-6
    assert all(-1e-6<=c<=1.000001 for uv in uvs for c in uv)
    geometry_report=json.loads((folder/(row['stem']+'_report.json')).read_text(encoding='utf-8'))['geometry']
    for axis,native,sign in ((0,0,1),(1,2,1),(2,1,-1)):
        expected=[geometry_report['bounds_min'][native]*sign,geometry_report['bounds_max'][native]*sign]
        assert abs(min(v[axis] for v in points)-min(expected))<1e-5
        assert abs(max(v[axis] for v in points)-max(expected))<1e-5
    error=0
    for base in range(0,len(indices),3):
        ids=indices[base:base+3]
        a,b,c=[points[i] for i in ids]
        ab=[b[i]-a[i] for i in range(3)]; ac=[c[i]-a[i] for i in range(3)]
        cross=(ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0])
        magnitude=math.sqrt(sum(v*v for v in cross)); assert magnitude>1e-9
        normal=[v/magnitude for v in cross]
        assert all(sum(n*v for n,v in zip(normal,normals[i]))>.99999 for i in ids),'Smoothed or reversed face'
        for first,second in zip(ids,ids[1:]+ids[:1]):
            length=math.dist(points[first],points[second]); density=math.dist(uvs[first],uvs[second])*512/length
            error=max(error,abs(density-64)); assert abs(density-64)<.005,(row['stem'],density)
    signature=hashlib.sha256(repr(sorted(set(points))).encode()).hexdigest()
    assert signature not in signatures; signatures.add(signature)
    assert hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()==row['source_sha256']
    assert (ROOT/row['blend']).stat().st_size>50000
    for view in ('front','three_quarter','back'):
        with Image.open(folder/'previews'/(view+'.png')) as image:
            assert image.size==(700,700); image.verify()
    reports.append(dict(stem=row['stem'],status='PASS',triangles=row['triangles'],meshes=1,surfaces=1,materials=1,animations=2 if animated else 0,rigs=1 if animated else 0,ground_pivot=True,metric_uv_max_error=error,geometry_sha256=signature,source_preserved=True))
for view in ('front','three_quarter','back'):
    with Image.open(WORK/('settlers_'+view+'.png')) as image:
        assert image.size==(1800,900); image.verify()
assert (WORK/'settlers_four_civilizations_review.blend').stat().st_size>200000
summary=dict(status='PASS',verified=4,animations=8 if animated else 0,triangles_total=sum(r['triangles'] for r in reports),pixel_density=64,meshes_per_glb=1,surfaces_per_glb=1,assets=reports)
(ROOT/'docs/settlers_export_validation.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='assets'}))
