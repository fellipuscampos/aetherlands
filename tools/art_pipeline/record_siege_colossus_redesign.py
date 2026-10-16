"""Record the completed Colossus replacement without rewriting other troops."""
import hashlib, json, re
from pathlib import Path
from human_rogue_siege_assets import ROOT

STEM='siege_colossus_v1'
folder=ROOT/'assets/generated/humans'/STEM
backup=ROOT/'art_source/siege_colossus_before_redesign_v1'
manifest=json.loads((backup/'manifest.json').read_text(encoding='utf-8'))
changed=[name for name,digest in manifest['other_assets_baseline'].items()
         if not (ROOT/name).is_file() or hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest]
assert not changed, changed
assert all(hashlib.sha256((backup/'asset'/name).read_bytes()).hexdigest()==digest
           for name,digest in manifest['colossus_backup'].items())
report=json.loads((folder/(STEM+'_report.json')).read_text(encoding='utf-8'))
assert report['nonmanifold_edges']==0 and not report['animation_validation']['problems']
assert report['height_m']==2 and report['editable_parts']==121
assert all(sample['curve_sha256']==report['redesign']['old_curve_hashes'][name]
           for name,sample in report['animation_validation']['samples'].items())
geometry=report['geometry_validation']
for field in ('unattached_parts_candidates','same_normal_coplanar_candidates',
              'mast_weapon_collisions','intersecting_wheels'):
    assert not geometry[field], (field,geometry[field])
new_import=json.loads((ROOT/'docs/human_rogue_siege_godot_validation_7_8.json').read_text(encoding='utf-8'))
assert new_import['status']=='PASS' and new_import['verified']==1
aggregate_path=ROOT/'docs/human_rogue_siege_godot_validation.json'
aggregate=json.loads(aggregate_path.read_text(encoding='utf-8'))
aggregate['assets']=[new_import['assets'][0] if item['asset']==STEM else item for item in aggregate['assets']]
assert aggregate['status']=='PASS' and len(aggregate['assets'])==8
aggregate_path.write_text(json.dumps(aggregate,indent=2),encoding='utf-8')

def log_text(name):
    data=(backup/name).read_bytes()
    text=data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8',errors='replace')
    return re.sub(r'\x1b\[[0-9;]*m','',text)

gut=log_text('gut_redesign.log')
assert 'All tests passed!' in gut
assert re.search(r'^Tests\s+2\s*$',gut,re.M)
assert re.search(r'^Passing Tests\s+2\s*$',gut,re.M)
assertions=int(re.search(r'^Asserts\s+(\d+)\s*$',gut,re.M).group(1))
for filename in ('godot_import_redesign.log','review_redesign.log'):
    content=log_text(filename)
    assert 'SCRIPT ERROR:' not in content and 'ERROR:' not in content, filename
readme=folder/'README.md'
text=readme.read_text(encoding='utf-8')
text+='\nVisual revisado: grande bombarda de cano único e oco, carro de carvalho com laterais inclinadas, seis rodas com raios, ferragens, guincho manual e placas azuis da civilização humana. Dourado discreto nos detalhes lendários. Altura de 2 m até a estrutura de madeira. Apoios laterais do canhão e trilho de recuo mantêm o interior do cano livre.\n'
text+='\nOs dez ossos e as curvas dos cinco clipes anteriores foram preservados. Backup da versão substituída: `art_source/siege_colossus_before_redesign_v1/asset`. Validação: `docs/siege_colossus_redesign_validation.json`.\n'
readme.write_text(text,encoding='utf-8')
output={'status':'PASS','asset':STEM,
        'design':'Single great bombard; shaped oak carriage, six spoked wheels, side trunnions, windlass, human blue heraldry and restrained legendary gold.',
        'height_m':2.0,'triangles':report['triangles'],'editable_parts':report['editable_parts'],
        'rig_bones':10,'native_animation_clips':5,'all_existing_action_curves_preserved':True,
        'geometry_validation':geometry,'godot_import':new_import['assets'][0],
        'runtime_tests':{'scripts':1,'tests':2,'passing':2,'assertions':assertions,
                         'log':'art_source/siege_colossus_before_redesign_v1/gut_redesign.log'},
        'review_scene_smoke':'PASS, eight frames, exit 0, no errors',
        'other_troops_and_runtime_files_preserved':len(manifest['other_assets_baseline']),
        'other_files_changed':changed,'old_asset_backup':'art_source/siege_colossus_before_redesign_v1/asset',
        'final_files_sha256':{name:hashlib.sha256((folder/name).read_bytes()).hexdigest()
                              for name in (STEM+'.blend',STEM+'.glb',STEM+'_albedo.png',STEM+'_emission.png')},
        'pipeline':'Live Blender MCP'}
(ROOT/'docs/siege_colossus_redesign_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
print(json.dumps({'status':'PASS','triangles':report['triangles'],'other_files_preserved':len(manifest['other_assets_baseline']),
                  'runtime_tests':2,'assertions':assertions}))
