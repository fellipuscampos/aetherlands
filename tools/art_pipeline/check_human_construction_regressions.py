"""Exercise the real construction marker, production bar and fog regressions."""
import subprocess,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
names=['test_human_construction_site.gd','test_hex_grid_movement.gd','test_hexgrid_fog.gd']
run=subprocess.run([str(GODOT),'--headless','--path',str(ROOT),'-s','addons/gut/gut_cmdln.gd',
    '-gconfig=','-gtest='+','.join('res://test/unit/'+n for n in names),'-gexit'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=300)
output=run.stdout+'\n'+run.stderr
(ROOT/'art_source/human_construction_review/regression_tests.log').write_text(output,encoding='utf-8')
plain=re.sub(r'\x1b\[[0-9;]*m','',output); suites=[]
for block in re.split(r'\n(?=res://test/unit/)',plain):
    match=re.search(r'(\d+)/(\d+) passed\.',block)
    if block.startswith('res://test/unit/') and match:
        passed,total=map(int,match.groups()); suites.append(dict(script=block.splitlines()[0],passed=passed,total=total))
report=dict(status='PASS' if run.returncode==0 and len(suites)==len(names) and all(s['passed']==s['total'] for s in suites) else 'FAIL',suites=suites,exit_code=run.returncode)
(ROOT/'docs/human_construction_regression_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
if report['status']!='PASS':
    print(plain[-9000:]); raise SystemExit(1)
