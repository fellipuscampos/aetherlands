"""Record actual project import and existing catalog test results."""
import json
import re
from pathlib import Path
from run_building_architecture_revision import targets

ROOT=Path(__file__).resolve().parents[2]
review=ROOT/'art_source/building_architecture_review'
entries=json.loads((review/'completed.json').read_text(encoding='utf-8'))
assert len(entries)==66 and {e['asset'] for e in entries}==set(targets())
def read_log(filename):
    raw=(review/filename).read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
import_log=read_log('game_import.log')
test_log=read_log('game_catalog_test.log')
assert not re.search(r'ERROR|WARNING|SCRIPT ERROR',import_log)
assert 'Finalizing Asset Import' in import_log and 'Editor layout ready' in import_log
def count(label):
    return int(re.search(re.escape(label)+r'\s+(\d+)',test_log).group(1))
asserts=re.search(r'Asserts\s+(\d+)/(\d+)',test_log)
passed,total=count('Passing Tests'),count('Tests')
assert passed==6 and total==8 and count('Failing Tests')==2
missing=['assets/models/kaykit/nature/Tree_1_A_Color1.gltf','assets/models/kaykit/buildings/building_market_blue.gltf']
assert all(not (ROOT/file).exists() for file in missing)
report={'status':'PARTIAL: missing external KayKit assets','completed_buildings':66,'game_import':'PASS','import_exit_code':0,'import_warnings':0,'import_errors':0,'tests_total':total,'tests_passed':passed,'tests_failed':2,'assertions_passed':int(asserts[1]),'assertions_total':int(asserts[2]),'missing_assets':missing,'test':'test/unit/test_building_art_catalog.gd','logs':{'import':str((review/'game_import.log').relative_to(ROOT)),'catalog':str((review/'game_catalog_test.log').relative_to(ROOT))}}
(ROOT/'docs/building_architecture_game_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
