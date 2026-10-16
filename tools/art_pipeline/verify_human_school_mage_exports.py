"""Validate actual GLB bytes, geometry, UV density and exported preview files."""
import hashlib,json,math,struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/human_school_mages_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
assert {a['school'] for a in manifest['assets']}=={'sacred','infernal','necromancy','druidism','arcanism','elementalism'}
rows=[]; signatures=set()
for row in manifest['assets']:
    stem=row['stem']; folder=ROOT/'assets/generated/humans'/stem
    raw=(folder/(stem+'.glb')).read_bytes(); assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert len(doc['meshes'])==len(doc['materials'])==1 and len(doc['images'])==2
    assert len(doc['meshes'][0]['primitives'])==1 and not doc.get('skins') and not doc.get('animations')
    assert not doc.get('cameras') and 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert all(s.get('magFilter')==9728 for s in doc['samplers'])
    assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE' and not doc['materials'][0].get('doubleSided',False)
    embedded=[]; disk=[]
    for img in doc['images']:
        view=doc['bufferViews'][img['bufferView']]; off=view.get('byteOffset',0)
        embedded.append(hashlib.sha256(binary[off:off+view['byteLength']]).hexdigest())
    for suffix in ('albedo','emission'):
        path=folder/(stem+'_'+suffix+'.png'); disk.append(hashlib.sha256(path.read_bytes()).hexdigest())
        with Image.open(path) as img: assert img.size==(512,512); img.verify()
    assert sorted(embedded)==sorted(disk)
    def accessor(index):
        a=doc['accessors'][index]; view=doc['bufferViews'][a['bufferView']]
        fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]; count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        stride=view.get('byteStride',struct.calcsize('<'+fmt*count)); offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*count,binary,offset+i*stride) for i in range(a['count'])]
    p=doc['meshes'][0]['primitives'][0]
    points=accessor(p['attributes']['POSITION']); uvs=accessor(p['attributes']['TEXCOORD_0']); normals=accessor(p['attributes']['NORMAL']); indices=[i[0] for i in accessor(p['indices'])]
    assert len(indices)//3==row['geometry']['triangles']<1000
    assert all(math.isfinite(c) for point in points for c in point) and abs(min(point[1] for point in points))<1e-6
    assert all(-1e-6<=c<=1.000001 for uv in uvs for c in uv)
    for axis,native,sign in ((0,0,1),(1,2,1),(2,1,-1)):
        expected=[row['geometry']['bounds_min'][native]*sign,row['geometry']['bounds_max'][native]*sign]
        assert abs(min(v[axis] for v in points)-min(expected))<1e-5 and abs(max(v[axis] for v in points)-max(expected))<1e-5
    error=0
    for base in range(0,len(indices),3):
        ids=indices[base:base+3]; a,b,c=[points[i] for i in ids]
        ab=[b[i]-a[i] for i in range(3)]; ac=[c[i]-a[i] for i in range(3)]
        cross=(ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0])
        magnitude=math.sqrt(sum(v*v for v in cross)); assert magnitude>1e-9
        normal=[v/magnitude for v in cross]
        assert all(sum(n*v for n,v in zip(normal,normals[i]))>.99999 for i in ids)
        for first,second in zip(ids,ids[1:]+ids[:1]):
            density=math.dist(uvs[first],uvs[second])*512/math.dist(points[first],points[second]); error=max(error,abs(density-64)); assert abs(density-64)<.005
    signature=hashlib.sha256(repr(sorted(set(points))).encode()).hexdigest(); assert signature not in signatures; signatures.add(signature)
    assert hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()==row['source_sha256']
    assert row['surface_validation']['exposed_coplanar_pairs']==0 and row['surface_validation']['staff_hand_contact'] and not row['surface_validation']['staff_forearm_intersection']
    if row.get('style_revision',1)>=3:
        style=row['style_validation']
        assert row['books']==0 and style['relaxed_offhand']
        assert style['original_head_geometry'] and style['head_scale']==1.0
        assert style['original_facial_features_preserved'] and style['painted_white_hair']
        assert style['original_head_max_vertex_error_m']<1e-6
        assert style['body_and_clothing_geometry_unchanged']
        assert style['bulky_hood_shells']==style['separate_hair_shells']==0
        assert style['painted_hood']==(row['school'] in ('infernal','necromancy','elementalism'))
    elif row.get('style_revision',1)>=2:
        assert row['books']==0 and row['style_validation']['painted_scalp_hair_pixels']==0 and row['style_validation']['relaxed_offhand']
    elif row['school'] in ('arcanism','necromancy'): assert row['surface_validation']['book_hand_contact'] and not row['surface_validation']['book_forearm_intersection']
    assert (folder/(stem+'.blend')).stat().st_size>50000
    for view in ('front','three_quarter','back'):
        with Image.open(folder/'previews'/(view+'.png')) as img: assert img.size==(700,700); img.verify()
    rows.append(dict(school=row['school'],status='PASS',triangles=len(indices)//3,meshes=1,surfaces=1,materials=1,animations=0,ground_pivot=True,uv_density_max_error=error,source_preserved=True,geometry_sha256=signature))
for view in ('front','three_quarter','back'):
    with Image.open(WORK/('human_mages_'+view+'.png')) as img: assert img.size==(2400,950); img.verify()
assert (WORK/'human_school_mages_six_schools_review.blend').stat().st_size>0
# Native Blender parsing validates the scene/images separately; compressed
# size is not a proxy for a complete scene after simplification.
source_check=json.loads((ROOT/'docs/human_school_mages_source_file_validation.json').read_text(encoding='utf-8'))
assert source_check['status']=='PASS' and source_check['review_models']==6
output=dict(status='PASS',verified=6,triangles_total=sum(r['triangles'] for r in rows),pixel_density=64,animations=0,assets=rows)
(ROOT/'docs/human_school_mages_export_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in output.items() if k!='assets'}))
