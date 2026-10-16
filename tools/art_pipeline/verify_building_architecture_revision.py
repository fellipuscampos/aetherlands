"""Validate actual exported geometry, embedded textures, backups and metadata."""
from pathlib import Path
import hashlib
import json
import math
import struct
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
REVIEW=ROOT/'art_source/building_architecture_review'
BACKUP=ROOT/'art_source/buildings_before_architecture_revision'
done=json.loads((REVIEW/'completed.json').read_text(encoding='utf-8'))
manifest=json.loads((BACKUP/'manifest.json').read_text(encoding='utf-8'))
results=[]
for entry in done:
    folder=entry['asset']; paths=list((ROOT/'assets/generated').glob('*/buildings/'+folder))
    assert len(paths)==1
    out=paths[0]; report=json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
    saved=next(x for x in manifest if x['folder']==folder)
    for file,digest in saved['files'].items():
        assert hashlib.sha256((ROOT/saved['backup']/file).read_bytes()).hexdigest()==digest,(folder,'backup changed',file)
    original=json.loads((ROOT/saved['backup']/(folder+'_report.json')).read_text(encoding='utf-8'))
    for key in ('gameplay_building_id','trains','excludes','civilization'):
        if key in original: assert report[key]==original[key],(folder,key)
    assert report['architecture_revision']['blender_mcp_only']
    assert report['nonmanifold_edges']==0 and not report['rig'] and not report['animations']
    raw=(out/(folder+'.glb')).read_bytes()
    assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    length=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+length]); binary=raw[28+length:]
    assert len(doc['images'])==2 and len(doc['materials'])==1
    assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    expected={hashlib.sha256((out/(folder+'_'+s+'.png')).read_bytes()).hexdigest() for s in ('albedo','emission')}
    for image in doc['images']:
        bv=doc['bufferViews'][image['bufferView']]; start=bv.get('byteOffset',0)
        assert hashlib.sha256(binary[start:start+bv['byteLength']]).hexdigest() in expected
    assert all(s['magFilter']==9728 and s['minFilter'] in (9728,9984,9986) for s in doc['samplers'])
    triangles=0; maximum=0; points=[]; geometry_points=set()
    for m in doc['meshes']:
        for p in m['primitives']:
            triangles+=doc['accessors'][p['indices']]['count']//3
            a=doc['accessors'][p['attributes']['POSITION']]
            assert a['type']=='VEC3' and a['componentType']==5126
            bv=doc['bufferViews'][a['bufferView']]
            start=bv.get('byteOffset',0)+a.get('byteOffset',0); stride=bv.get('byteStride',12)
            for i in range(a['count']):
                xyz=struct.unpack_from('<fff',binary,start+i*stride)
                assert all(math.isfinite(v) for v in xyz)
                x,y,z=xyz; points.append(xyz)
                geometry_points.add(tuple(round(value,6) for value in xyz))
                maximum=max(maximum,max(x*math.cos(math.radians(n*60))-z*math.sin(math.radians(n*60)) for n in range(6)))
    assert triangles==report['triangles']==report['export']['triangles']
    assert maximum<=math.sqrt(3)/2-.030+1e-6,(folder,maximum)
    assert abs(maximum-report['architecture_revision']['max_tile_half_plane'])<.0001
    assert abs(min(v[1] for v in points))<.00001
    oldraw=(ROOT/saved['backup']/(folder+'.glb')).read_bytes()
    oldlen=struct.unpack_from('<I',oldraw,12)[0]; olddoc=json.loads(oldraw[20:20+oldlen]); oldbin=oldraw[28+oldlen:]
    old_geometry_points=set()
    for m in olddoc['meshes']:
        for p in m['primitives']:
            a=olddoc['accessors'][p['attributes']['POSITION']]; bv=olddoc['bufferViews'][a['bufferView']]
            start=bv.get('byteOffset',0)+a.get('byteOffset',0); stride=bv.get('byteStride',12)
            for i in range(a['count']):
                xyz=struct.unpack_from('<fff',oldbin,start+i*stride)
                old_geometry_points.add(tuple(round(value,6) for value in xyz))
    geometry_changed=geometry_points!=old_geometry_points
    atlas_changed=hashlib.sha256((out/(folder+'_albedo.png')).read_bytes()).hexdigest()!=hashlib.sha256((ROOT/saved['backup']/(folder+'_albedo.png')).read_bytes()).hexdigest()
    assert geometry_changed or atlas_changed,(folder,'asset was not revised')
    if not geometry_changed:
        assert entry['civilization']=='human' and any(change.startswith('masonry:') for change in report['architecture_revision']['geometry_changes']),(folder,'expected structural redesign')
    for view in ('three_quarter','game_top','top','back'):
        with Image.open(out/'previews'/(view+'.png')) as im: im.verify()
        assert (out/'previews'/(view+'.png')).stat().st_mtime>(ROOT/saved['backup']/'previews'/(view+'.png')).stat().st_mtime
    assert (out/(folder+'.blend')).is_file()
    results.append({'asset':folder,'triangles':triangles,'hex_margin':math.sqrt(3)/2-maximum,'geometry_changed':geometry_changed,'atlas_changed':atlas_changed})
summary={'status':'PASS','verified':len(results),'assets':results,'backups_verified':True}
(ROOT/'docs/building_architecture_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'status':'PASS','verified':len(results),'backups_verified':True}))
