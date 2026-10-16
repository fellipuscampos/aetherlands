"""Check actual GLB geometry, textures and the single-version infrastructure contract."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
from PIL import Image
from run_infrastructure_buildings_mcp import targets

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--partial',action='store_true')
args=parser.parse_args()
entries=json.loads((ROOT/'art_source/infrastructure_buildings_review/completed.json').read_text(encoding='utf-8'))
if not args.partial:
    assert len(entries)==20 and {(e['civilization'],e['role']) for e in entries}==set(targets())
plurals={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}
branches={'market':'economy','farm':'logistics','workshop':'industry','university':'academy','arcane_shrine':'arcane'}
catalog=(ROOT/'scripts/data/BuildingArtCatalog.gd').read_text(encoding='utf-8')
verified=[]; geometry_by_role={}
surface_audit=ROOT/'art_source/infrastructure_roof_review/after_face_repairs.json'
audited_positions={}
if surface_audit.exists():
    audited=json.loads(surface_audit.read_text(encoding='utf-8'))
    assert audited['exposed_overlap_faces']==0
    audited_positions={row['asset']:row['source_position_sha256'] for row in audited['assets']}
for entry in entries:
    folder,civ,role=entry['asset'],entry['civilization'],entry['role']
    out=ROOT/'assets/generated'/plurals[civ]/'buildings'/folder
    report=json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
    assert report['civilization']==civ
    assert report['integrated_in_game']
    assert report['gameplay_building_id']=='v2_building_'+('academy' if role=='university' else role)
    assert report['infrastructure']['single_version'] and report['infrastructure']['evolutions']==[]
    assert report['infrastructure']['blender_mcp_only'] and report['infrastructure']['branch']==branches[role]
    assert report['trains']==(['v2_unit_builder'] if role=='workshop' else [])
    assert report['excludes']==[] and report['nonmanifold_edges']==0
    assert '"'+folder+'"' in catalog
    raw=(out/(folder+'.glb')).read_bytes()
    assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    length=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+length]); binary=raw[28+length:]
    assert len(doc['materials'])==1 and len(doc['images'])==2
    assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert sum(n.get('name','').endswith('_Faction') and 'mesh' in n for n in doc['nodes'])==1
    assert all(s['magFilter']==9728 and s['minFilter'] in (9728,9984,9986) for s in doc['samplers'])
    expected={hashlib.sha256((out/(folder+'_'+suffix+'.png')).read_bytes()).hexdigest() for suffix in ('albedo','emission')}
    for image in doc['images']:
        bv=doc['bufferViews'][image['bufferView']]; start=bv.get('byteOffset',0)
        assert hashlib.sha256(binary[start:start+bv['byteLength']]).hexdigest() in expected
    triangles=0; maximum=0; ground=math.inf; points=set(); native_points=set()
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            triangles+=doc['accessors'][primitive['indices']]['count']//3
            accessor=doc['accessors'][primitive['attributes']['POSITION']]
            assert accessor['componentType']==5126 and accessor['type']=='VEC3'
            bv=doc['bufferViews'][accessor['bufferView']]
            start=bv.get('byteOffset',0)+accessor.get('byteOffset',0)
            stride=bv.get('byteStride',12)
            for index in range(accessor['count']):
                xyz=struct.unpack_from('<fff',binary,start+index*stride)
                assert all(math.isfinite(v) for v in xyz)
                x,y,z=xyz; ground=min(ground,y)
                points.add(tuple(round(v,6) for v in xyz))
                native_points.add(tuple(round(v,6) or 0.0 for v in (x,-z,y)))
                maximum=max(maximum,max(x*math.cos(math.radians(side*60))-z*math.sin(math.radians(side*60)) for side in range(6)))
    assert triangles==report['triangles']==report['export']['triangles']
    assert abs(ground)<1e-6 and maximum<=math.sqrt(3)/2-.030+1e-6,(folder,maximum)
    assert abs(maximum-report['hex_tile']['max_half_plane_blender'])<1e-5
    signature=hashlib.sha256(repr(sorted(points)).encode()).hexdigest()
    if folder in audited_positions:
        assert hashlib.sha256(repr(sorted(native_points)).encode()).hexdigest()==audited_positions[folder],(folder,'export differs from audited native surface geometry')
    assert signature not in geometry_by_role.setdefault(role,[]),(folder,'identical layout across civilizations')
    geometry_by_role[role].append(signature)
    for view in ('three_quarter','game_top','top','back'):
        with Image.open(out/'previews'/(view+'.png')) as image:
            assert image.size==(800,800); image.verify()
    assert (out/(folder+'.blend')).is_file() and (out/'README.md').is_file()
    verified.append({'asset':folder,'civilization':civ,'role':role,'triangles':triangles,'geometry_sha256':signature,'tile_margin':math.sqrt(3)/2-maximum})
summary={'status':'PASS','verified':len(verified),'unique_layouts_per_role':{role:len(signatures) for role,signatures in geometry_by_role.items()},'assets':verified}
(ROOT/'docs/infrastructure_buildings_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'status':'PASS','verified':len(verified),'unique_layouts_per_role':summary['unique_layouts_per_role']}))
