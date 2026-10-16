"""Record completed validation evidence and correct family-specific README notes."""
import json, re
from human_rogue_siege_assets import ROOT, ASSETS, roles

source=ROOT/'art_source/human_rogue_siege_runtime_before'
data=(source/'gut_models.log').read_bytes()
raw=data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8',errors='replace')
plain=re.sub(r'\x1b\[[0-9;]*m','',raw)
assert re.search(r'^Tests\s+10\s*$',plain,re.M) and re.search(r'^Passing Tests\s+10\s*$',plain,re.M) and re.search(r'^Asserts\s+260\s*$',plain,re.M) and 'All tests passed!' in plain
geometry=json.loads((ROOT/'docs/human_rogue_siege_geometry_validation.json').read_text(encoding='utf-8'))
godot=json.loads((ROOT/'docs/human_rogue_siege_godot_validation.json').read_text(encoding='utf-8'))
assert geometry['status']=='PASS' and godot['status']=='PASS' and godot['verified']==8
for a in ASSETS:
    path=ROOT/'assets/generated/humans'/a['stem']/'README.md'
    text=path.read_text(encoding='utf-8')
    note='Desmantelar é entregue como animação; permanece passiva conforme as regras existentes.'
    if a['family']=='siege': text=text.replace(note,'Munição Demolidora é entregue como animação; permanece passiva conforme as regras existentes.')
    elif a['level']==0: text=text.replace(note,'Ataque Furtivo está incluído. O clipe Desmantelar entra a partir do Sabotador.')
    path.write_text(text,encoding='utf-8')
report={'status':'PASS','units':8,'clips':sum(len(roles(a)) for a in ASSETS),'godot_import':'8 PackedScenes, native heights, rigs, embedded nearest textures, all clip samples finite',
        'geometry':'8 assets, no disconnected AABB candidates, same-normal coplanar candidates, intersecting wheels or sampled mast/weapon collisions',
        'runtime_tests':{'scripts':2,'tests':10,'passing':10,'assertions':260,'log':'art_source/human_rogue_siege_runtime_before/gut_models.log','notes':'GUT logs PhysicalBoneSimulator3D orphan warnings in both the new and existing troop fixtures; all assertions pass.'},
        'review_scene_smoke':'PASS: headless _human_rogue_siege_review.tscn, 8 frames, exit 0, no script errors',
        'previous_sources_preserved':1867,'expected_existing_file_change':'scripts/data/UnitDatabase.gd: native visual paths/clip mappings and provisional visual descriptions only',
        'backup':'art_source/human_rogue_siege_runtime_before/UnitDatabase.gd','pipeline':'Live Blender MCP, one asset completed and saved before the next'}
(ROOT/'docs/human_rogue_siege_runtime_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'status':report['status'],'units':report['units'],'clips':report['clips'],'runtime_tests':10,'assertions':260}))
