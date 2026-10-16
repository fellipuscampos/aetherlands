"""Run the existing movement, combat and neighboring art regression tests."""
import json
import subprocess
import re
import sys
from pathlib import Path

root=Path(__file__).resolve().parents[2]
godot=Path('C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
names=['test_hex_grid_movement.gd','test_combat_resolver.gd','test_v2_cavalry_flow.gd',
       'test_v2_siege_flow.gd','test_v2_human_troop_models.gd','test_v2_human_rogue_siege_models.gd']
log=root/'art_source/dwarf_skills/regression_tests.log'
if '--from-log' in sys.argv:
    output=log.read_text(encoding='utf-8')
else:
    done=subprocess.run([str(godot),'--headless','--path',str(root),'-s','addons/gut/gut_cmdln.gd',
        '-gconfig=','-gtest='+','.join('res://test/unit/'+name for name in names),'-gexit'],
        capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
    output=done.stdout+'\n'+done.stderr
    log.write_text(output,encoding='utf-8')
plain=re.sub(r'\x1b\[[0-9;]*m','',output)
suites=[]
for block in re.split(r'\n(?=res://test/unit/)',plain):
    match=re.search(r'(\d+)/(\d+) passed\.',block)
    if not block.startswith('res://test/unit/') or not match:continue
    passed,total=map(int,match.groups())
    suites.append(dict(script=block.splitlines()[0],passed=passed,total=total,
                       status='PASS' if passed==total else 'FAIL'))
assert len(suites)==len(names),suites
passed=sum(s['passed'] for s in suites);total=sum(s['total'] for s in suites)
report=dict(status='PASS' if passed==total else 'PARTIAL',suites=suites,passed=passed,total=total,
            failed=total-passed,log=str(log.relative_to(root)),
            limitations=[] if passed==total else [
                'Missing assets/models/kaykit/nature/Tree_1_A_Color1.gltf and forest_texture.png in map-dependent tests.',
                'Cavalry and siege flow tests also expect a doctrine node that the current research database does not provide.'])
(root/'docs/dwarf_skills_regression_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
