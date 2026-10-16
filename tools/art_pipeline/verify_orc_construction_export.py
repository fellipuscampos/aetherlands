"""Check the delivered orc GLB, embedded atlas and construction audit."""
from pathlib import Path
import hashlib,json,struct

ROOT=Path(__file__).resolve().parents[2]
STEM='orc_construction_site_hex_v1'
ASSET=ROOT/'assets/generated/orcs/buildings'/STEM
raw=(ASSET/(STEM+'.glb')).read_bytes()
assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
size=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+size])
assert len(doc['meshes'])==2 and len(doc['materials'])==1 and len(doc['skins'])==1
assert len(doc['skins'][0]['joints'])==25
assert len(doc['images'])==1 and not doc.get('cameras')
assert [clip['name'] for clip in doc['animations']]==['construction']
assert all(sampler['magFilter']==9728 for sampler in doc['samplers'])
assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
triangles=sum(doc['accessors'][primitive['indices']]['count']//3 for mesh in doc['meshes'] for primitive in mesh['primitives'])
clip=doc['animations'][0]
for sampler in clip['samplers']:
    times=doc['accessors'][sampler['input']]
    assert abs(times['min'][0])<1e-6 and abs(times['max'][0]-6)<1e-6
view=doc['bufferViews'][doc['images'][0]['bufferView']]
start=20+size+8+view.get('byteOffset',0)
atlas=raw[start:start+view['byteLength']]
atlas_hash=hashlib.sha256(atlas).hexdigest()
assert atlas_hash==hashlib.sha256((ASSET/(STEM+'_albedo.png')).read_bytes()).hexdigest()
report=json.loads((ASSET/(STEM+'_report.json')).read_text(encoding='utf-8'))
assert report['status']=='PASS' and report['race']=='orc'
assert triangles==report['geometry']['triangles']==report['geometry']['editable_parts']*12
assert report['contacts']['loose_building_blocks']==6 and report['contacts']['original_ear_parts']==18
assert report['contacts']['original_tusk_parts']==12 and report['contacts']['original_brow_parts']==6
assert report['contacts']['rivet_contact_samples']>=6 and report['contacts']['rivet_contact_error']<1e-5
assert report['building_materials']['structure']=='basalt_heavy_timber_and_iron'
assert report['building_materials']['loose_rust_hide_roof_shingles']==10
assert report['building_materials']['raw_timber_logs']==3
assert report['geometry']['ground_plate'] is False
assert report['orc_style']['static_shoulder_blocks']==0
assert all(.080<length<.091 for arm in report['orc_style']['forearm_lengths'].values() for length in arm.values())
result=dict(status='PASS',race='orc',revision=report['revision'],bytes=len(raw),triangles=triangles,meshes=2,materials=1,skins=1,bones=25,clip='construction',seconds=6,embedded_atlas_sha256=atlas_hash,nearest=True,studio_excluded=True,ground_plate=False,generic_construction=True,jobs=report['jobs'],loose_building_blocks=6,raw_timber_logs=3,original_ear_parts=18,original_tusk_parts=12,original_brow_parts=6,building_materials=report['building_materials'],footprint_margin=report['geometry']['footprint_margin'])
(ROOT/'docs/orc_construction_export_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
