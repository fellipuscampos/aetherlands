"""Verify runtime geometry against the user's approved static assets."""
import hashlib,json,struct
from collections import Counter
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/school_mages_animation_review'

def glb(path):
    raw=path.read_bytes(); count=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+count]),raw[28+count:]

def accessor(doc,data,index):
    item=doc['accessors'][index]; view=doc['bufferViews'][item['bufferView']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[item['componentType']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[item['type']]
    offset=view.get('byteOffset',0)+item.get('byteOffset',0)
    stride=view.get('byteStride',np.dtype(dtype).itemsize*width)
    return np.ndarray((item['count'],width),dtype=dtype,buffer=data,offset=offset,strides=(stride,np.dtype(dtype).itemsize)).copy()

def geometry(doc,data,include_normals=False):
    primitive=doc['meshes'][0]['primitives'][0]; attrs=primitive['attributes']
    keys=['POSITION','TEXCOORD_0']+(['NORMAL'] if include_normals else [])
    rows=np.concatenate([accessor(doc,data,attrs[key]) for key in keys],axis=1)
    rows=np.round(rows.astype(np.float64),6)
    indices=accessor(doc,data,primitive['indices']).reshape(-1,3)
    triangles=[]
    for face in indices:
        corners=[tuple(rows[i]) for i in face]
        # Cyclic shifts keep the face winding part of the comparison.
        triangles.append(min(tuple(corners[i:]+corners[:i]) for i in range(3)))
    return sorted(triangles)

def animation_fingerprint(doc,data):
    clips={}
    for animation in doc['animations']:
        channels=[]
        for channel in animation['channels']:
            sampler=animation['samplers'][channel['sampler']]
            target=channel['target']
            channels.append((doc['nodes'][target['node']]['name'],target['path'],sampler.get('interpolation','LINEAR'),accessor(doc,data,sampler['input']).tobytes().hex(),accessor(doc,data,sampler['output']).tobytes().hex()))
        clips[animation['name']]=sorted(channels)
    return clips

def verify():
    manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
    hashes=json.loads((WORK/'approved_static_hashes.json').read_text(encoding='utf-8'))
    textures=0
    for relative,digest in hashes.items():
        if relative.endswith('.png'):
            assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()==digest,relative
            textures+=1
    assert len(manifest['assets'])==24
    results=[]
    for row in manifest['assets']:
        path=ROOT/row['glb']; doc,data=glb(path)
        before,binary=glb(WORK/'before_animations'/row['glb'])
        cleanup=row.get('clothing_cleanup') if row['race']=='human' else None
        if cleanup:
            backup=ROOT/cleanup['backup']/row['glb']
            previous,previous_binary=glb(backup)
            current_triangles=Counter(geometry(doc,data,True)); previous_triangles=Counter(geometry(previous,previous_binary,True))
            assert not current_triangles-previous_triangles,row['stem']+' changed retained geometry/UVs'
            assert sum((previous_triangles-current_triangles).values())==len(cleanup['removed_parts'])*12
            assert animation_fingerprint(doc,data)==animation_fingerprint(previous,previous_binary),row['stem']+' animation changed'
            assert np.array_equal(accessor(doc,data,doc['skins'][0]['inverseBindMatrices']),accessor(previous,previous_binary,previous['skins'][0]['inverseBindMatrices']))
        else:
            assert geometry(doc,data)==geometry(before,binary),row['stem']+' geometry/UV/normal change'
        attrs=doc['meshes'][0]['primitives'][0]['attributes']
        old_attrs=before['meshes'][0]['primitives'][0]['attributes']
        for key in ([] if cleanup else ['POSITION','TEXCOORD_0','NORMAL']):
            current=accessor(doc,data,attrs[key]); original=accessor(before,binary,old_attrs[key])
            assert current.shape==original.shape and np.allclose(current,original,atol=2e-6,rtol=0),row['stem']+' '+key
        assert len(doc['meshes'])==len(doc['skins'])==len(doc['materials'])==1
        assert len(doc['images'])==2 and len(doc['skins'][0]['joints'])==16
        primitive=doc['meshes'][0]['primitives'][0]
        weights=accessor(doc,data,primitive['attributes']['WEIGHTS_0'])
        assert np.allclose(weights.sum(axis=1),1) and np.all((weights==0)|(weights==1))
        assert all(s.get('magFilter')==9728 for s in doc['samplers'])
        clips={}
        for animation in doc['animations']:
            spans=[]
            for sampler in animation['samplers']:
                times=accessor(doc,data,sampler['input']); values=accessor(doc,data,sampler['output'])
                assert np.isfinite(values).all() and np.isfinite(times).all()
                assert np.all(np.diff(times[:,0])>0)
                spans.append((float(times.min()),float(times.max())))
            duration=max(t[1] for t in spans)-min(t[0] for t in spans)
            assert abs(duration-(1.5 if animation['name']=='walk' else 3))<1e-5
            clips[animation['name']]=duration
        assert sorted(clips)==['idle','spell','walk']
        images=[]
        for image in doc['images']:
            view=doc['bufferViews'][image['bufferView']]; offset=view.get('byteOffset',0)
            images.append(hashlib.sha256(data[offset:offset+view['byteLength']]).hexdigest())
        assert sorted(images)==sorted(row['export']['atlas_hashes'].values())
        results.append(dict(stem=row['stem'],retained_geometry_uvs_unchanged=True,removed_clothing_parts=cleanup['removed_parts'] if cleanup else [],approved_animations_unchanged=True if cleanup else None,triangles=row['geometry']['triangles'],meshes=1,surfaces=1,bones=16,clips=clips,bytes=path.stat().st_size))
    report=dict(status='PASS',verified=24,clips=72,unchanged_texture_files=textures,triangles=sum(r['triangles'] for r in results),assets=results)
    backup=WORK/'before_human_clothing_cleanup'
    if backup.exists():
        protected=json.loads((backup/'protected_files.json').read_text(encoding='utf-8'))
        for relative,digest in protected.items():
            assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()==digest,relative+' unrelated asset changed'
        report['unchanged_other_race_files']=len(protected)
    (ROOT/'docs/school_mages_animation_export_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='assets'}))

if __name__=='__main__': verify()
