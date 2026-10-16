"""Record actual project import and catalog/economy regression results."""
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
review=ROOT/'art_source/infrastructure_buildings_review'
def read_log(filename):
    raw=(review/filename).read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
import_log=read_log('game_import.log')
test_log=read_log('game_tests.log')
assert not re.search(r'ERROR|WARNING|SCRIPT ERROR',import_log)
assert 'Finalizing Asset Import' in import_log and 'Editor layout ready' in import_log
counts={label:int(re.search(r'^'+label+r'\s+(\d+)',test_log,re.MULTILINE).group(1)) for label in ('Scripts','Tests','Passing Tests')}
asserts=re.search(r'^Asserts\s+(\d+)(?:/(\d+))?',test_log,re.MULTILINE)
assert counts['Scripts']==2 and counts['Tests']==25 and counts['Passing Tests']==25
assert not re.search(r'SCRIPT ERROR|\[Failed\]|Failing Tests\s+[1-9]',test_log)
summary={'status':'PASS','game_import':'PASS','import_errors':0,'import_warnings':0,'verified_infrastructure_assets':20,'scripts':counts['Scripts'],'tests_total':counts['Tests'],'tests_passed':counts['Passing Tests'],'assertions_passed':int(asserts[1]),'tests':['test/unit/test_building_art_catalog.gd','test/unit/test_v2_economy_data.gd'],'logs':{'import':str((review/'game_import.log').relative_to(ROOT)),'tests':str((review/'game_tests.log').relative_to(ROOT))},'fixture_note':'Building catalog tests use a simple tree mesh fixture to isolate building art from the independent KayKit forest asset.'}
(ROOT/'docs/infrastructure_buildings_game_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
