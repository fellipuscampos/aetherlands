"""Audit the actual GLBs, embedded pixels and native waterline coordinates."""
import hashlib, json, math, struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/embark_boats_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
assert manifest['original_scenes_retained']
assert {e['race'] for e in manifest['assets']}=={'human','orc','elf','dwarf'}
verified=[]
for row in manifest['assets']:
    path=ROOT/row['glb']; raw=path.read_bytes()
    assert struct.unpack_from('<III',raw)==(0x46546C67,2,len(raw))
    assert hashlib.sha256(raw).hexdigest()==row['glb_sha256']
    size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert len(doc['meshes'])==row['game_meshes'] and len(doc['materials'])==1 and len(doc['images'])==2
    assert not doc.get('cameras') and not doc.get('skins')
    animated=row.get('sail_revision')==2
    if animated:
        assert sorted(a['name'] for a in doc.get('animations',[]))==['idle','walk']
        assert row['sail_symbols'] is False
    else:
        assert not doc.get('animations')
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    material=doc['materials'][0]
    assert material.get('alphaMode','OPAQUE')=='OPAQUE' and not material.get('doubleSided',False)
    assert all(s.get('magFilter')==9728 for s in doc['samplers'])
    assert material['pbrMetallicRoughness'].get('metallicRoughnessTexture') is not None
    local_images={hashlib.sha256(p.read_bytes()).hexdigest() for p in path.parent.glob('*_albedo.png')}
    local_images.update(hashlib.sha256(p.read_bytes()).hexdigest() for p in path.parent.glob('*_orm.png'))
    for im in doc['images']:
        view=doc['bufferViews'][im['bufferView']]; start=view.get('byteOffset',0)
        embedded=binary[start:start+view['byteLength']]
        assert embedded.startswith(b'\x89PNG\r\n\x1a\n')
        assert hashlib.sha256(embedded).hexdigest() in local_images, 'Embedded image changed'
    def accessor(index):
        a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
        fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        stride=v.get('byteStride',struct.calcsize('<'+fmt*count)); start=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*count,binary,start+i*stride) for i in range(a['count'])]
    all_points=[]; triangles=0
    clip_reports=[]
    if animated:
        for animation in doc['animations']:
            duration=4.0 if animation['name']=='idle' else 2.0
            last_time=0; paths=[]
            for channel in animation['channels']:
                sampler=animation['samplers'][channel['sampler']]
                times=[p[0] for p in accessor(sampler['input'])]; output=accessor(sampler['output'])
                assert min(times)>=-1e-6 and max(times)<=duration+1e-5
                assert all(a<b for a,b in zip(times,times[1:]))
                assert all(math.isfinite(c) for p in output for c in p)
                last_time=max(last_time,max(times)); path_kind=channel['target']['path']; paths.append(path_kind)
                assert max(abs(a-b) for a,b in zip(output[0],output[-1]))<1e-5, 'Open loop'
                if path_kind=='translation':
                    assert all(abs(p[0])+abs(p[2])<1e-6 and p[1]<=1e-6 for p in output), 'Boat leaves flat water'
                    assert min(p[1] for p in output)<-.01
                if path_kind=='weights':
                    assert min(p[0] for p in output)>=0 and max(p[0] for p in output)>.05
            assert abs(last_time-duration)<1e-5
            assert {'translation','rotation','weights'}.issubset(paths)
            clip_reports.append(dict(clip=animation['name'],duration=duration,loop=True,flat_water=True))
    for mesh in doc['meshes']:
        assert len(mesh['primitives'])==1
        primitive=mesh['primitives'][0]; points=accessor(primitive['attributes']['POSITION'])
        normals=accessor(primitive['attributes']['NORMAL']); uv=accessor(primitive['attributes']['TEXCOORD_0'])
        indices=[r[0] for r in accessor(primitive['indices'])]
        triangles+=len(indices)//3; all_points.extend(points)
        assert all(math.isfinite(c) for p in points for c in p)
        assert all(0<=c<=1 for pair in uv for c in pair)
        assert all(abs(sum(c*c for c in n)-1)<1e-4 for n in normals)
        for i in range(0,len(indices),3):
            a,b,c=[points[j] for j in indices[i:i+3]]
            ab=[b[k]-a[k] for k in range(3)]; ac=[c[k]-a[k] for k in range(3)]
            cross=(ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0])
            assert sum(x*x for x in cross)>1e-15, 'Degenerate triangle'
            assert all(sum(v*n for v,n in zip(cross,normals[j]))>0 for j in indices[i:i+3]), 'Reversed face'
    assert triangles==row['triangles']<5000
    # Conversion is Blender XYZ -> Godot X,Z,-Y. Origin stays at water level.
    for axis,native,sign in ((0,0,1),(1,2,1),(2,1,-1)):
        expected=sorted([row['bounds_blender']['min'][native]*sign,row['bounds_blender']['max'][native]*sign])
        assert abs(min(p[axis] for p in all_points)-expected[0])<1e-5
        assert abs(max(p[axis] for p in all_points)-expected[1])<1e-5
    assert min(p[1] for p in all_points)<0<max(p[1] for p in all_points)
    assert max(math.hypot(p[0],p[2])*.52 for p in all_points)<.87, 'Map footprint exceeds tile apothem'
    assert path.with_suffix('.blend').stat().st_size>50000
    for view in ('three_quarter','game_top','side','top','dry_hull'):
        with Image.open(path.parent/'previews'/(view+'.png')) as im:
            assert im.size==(800,800) and im.getbbox()
    verified.append(dict(race=row['race'],triangles=triangles,meshes=row['game_meshes'],embedded_textures_verified=True,
        waterline=True,map_footprint_fits_hex=True,clips=clip_reports,sail_symbols=not animated))
report=dict(status='PASS',verified=verified,original_scenes_retained=True)
(ROOT/'docs/embark_boats_export_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
