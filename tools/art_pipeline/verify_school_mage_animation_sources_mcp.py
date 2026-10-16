"""Verify every saved source, and both individual and review rig ownership."""
import bpy,ast,json
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/school_mages_animation_review'
source=(ROOT/'tools/art_pipeline/animate_settlers_mcp.py').read_text(encoding='utf-8')
import hashlib
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='shape_hash': exec(compile(ast.get_source_segment(source,node),'<approved_mesh_hash>','exec'),globals())
rows=[]; original_sources={}
for race in ('human','elf','dwarf','orc'):
    assets=bpy.app.driver_namespace[race+'_school_mage_assets_v1']; review=bpy.app.driver_namespace[race+'_school_mage_review_v1']
    assert len(assets)==6 and sum(o.type=='ARMATURE' for o in review['scene'].objects)==6
    for asset in assets:
        stem=asset['report']['stem']; path=asset['folder']/(stem+'.blend')
        original=asset['report']['source']; expected=asset['report']['source_sha256']
        if original not in original_sources:
            actual=hashlib.sha256((ROOT/original).read_bytes()).hexdigest()
            assert actual==expected,(original,'original body source changed')
            original_sources[original]=actual
        original_shapes=json.loads((WORK/(stem+'_bind_geometry.json')).read_text())
        removed=set(asset['report'].get('clothing_cleanup',{}).get('removed_parts',[])) if race=='human' else set()
        assert removed <= original_shapes.keys()
        assert {o['part']:shape_hash(o) for o in asset['parts']}=={name:value for name,value in original_shapes.items() if name not in removed}
        if removed:
            issues,hidden=bpy.app.driver_namespace['human_school_mage_surface_audit_v1'](asset['parts'])
            assert not issues,(stem,'exposed coplanar faces after clothing cleanup',issues)
        assert asset['report']['animation']['status']=='PASS' and len(asset['rig'].data.bones)==16
        assert len(asset['rig'].animation_data.nla_tracks)==3 and len(asset['review_rig'].animation_data.nla_tracks)==3
        assert len(asset['parts'])==asset['report']['export']['editable_source_parts']
        with bpy.data.libraries.load(str(path),link=False) as (available,unused):
            names={key:list(getattr(available,key)) for key in ('scenes','objects','meshes','armatures','actions','images','materials')}
        assert len(names['scenes'])==len(names['armatures'])==len(names['materials'])==1,(stem,names)
        assert len(names['meshes'])==len(asset['parts']) and len(names['actions'])==3 and len(names['images'])==2,(stem,names)
        assert all(any('_'+clip in name for name in names['actions']) for clip in ('idle','walk','spell'))
        rows.append(dict(stem=stem,scenes=1,rigs=1,bones=16,actions=3,images=2,materials=1,editable_parts=len(asset['parts']),retained_geometry_and_uv_hashes_unchanged=True,removed_clothing_parts=sorted(removed)))
for race in ('human','elf','dwarf','orc'):
    path=ROOT/'art_source'/(race+'_school_mages_review')/(race+'_school_mages_six_schools_review.blend')
    with bpy.data.libraries.load(str(path),link=False) as (available,unused):
        assert len(available.scenes)==1 and len(available.armatures)==6 and len(available.actions)==18,(race,'review dependencies')
path=WORK/'school_mages_24_animated_review.blend'
for rig in bpy.app.driver_namespace['school_mages_animation_review_v1']['scene'].objects:
    if rig.type=='ARMATURE':
        source=next(a for race in ('human','elf','dwarf','orc') for a in bpy.app.driver_namespace[race+'_school_mage_assets_v1'] if a['report']['stem']==rig['mage_animation_asset'])
        assert rig['choreography_revision']==source['report']['animation']['choreography_revision']
        assert {strip.action for track in rig.animation_data.nla_tracks for strip in track.strips}==set(source['actions'].values()),'Stale overview animation'
with bpy.data.libraries.load(str(path),link=False) as (available,unused):
    assert len(available.scenes)==1 and len(available.armatures)==24 and len(available.actions)==72,'Overview dependencies'
report=dict(status='PASS',verified=24,clips=72,racial_reviews=4,overview_rigs=24,retained_source_geometry_unchanged=True,original_body_sources_unchanged=original_sources,assets=rows)
(ROOT/'docs/school_mages_animation_source_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
cleanup_path=ROOT/'docs/human_school_mages_clothing_validation.json'
if cleanup_path.exists():
    cleanup=json.loads(cleanup_path.read_text(encoding='utf-8'))
    cleanup['exposed_coplanar_pairs']=0
    cleanup['source_validation_status']='PASS'
    cleanup_path.write_text(json.dumps(cleanup,indent=2),encoding='utf-8')
result={k:v for k,v in report.items() if k!='assets'}
