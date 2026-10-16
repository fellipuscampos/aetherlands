"""Build the orc roster in the running Blender and preserve previous races."""
import argparse,hashlib,json
from blender_mcp_client import execute
from orc_troop_assets import ROOT,OUT,WORK,ASSETS,BASE

parser=argparse.ArgumentParser(); parser.add_argument('--only',nargs='+'); args=parser.parse_args()
WORK.mkdir(parents=True,exist_ok=True); (WORK/'.gdignore').touch()
baseline=WORK/'protected_sources.json'
if not baseline.exists():
    baseline.write_text((ROOT/'art_source/orc_squire/protected_assets.json').read_text(),encoding='utf-8')
protected=json.loads(baseline.read_text())
base_hash=hashlib.sha256(BASE.read_bytes()).hexdigest()
selected=[r for r in ASSETS if r['key']!='squire' and (not args.only or r['stem'] in args.only)]
for row in selected:
    print('ORC_BUILD_START',row['stem'],flush=True)
    code=f'''import sys,importlib,importlib.util
pipe={str(ROOT/'tools/art_pipeline')!r}
if pipe not in sys.path: sys.path.insert(0,pipe)
import orc_troop_paint
importlib.reload(orc_troop_paint)
import build_orc_squire
importlib.reload(build_orc_squire)
spec=importlib.util.spec_from_file_location('orc_roster_builder',{str(ROOT/'tools/art_pipeline/build_orc_troops.py')!r})
builder=importlib.util.module_from_spec(spec); spec.loader.exec_module(builder)
result=builder.build({row!r})
'''
    execute(code,timeout=1200)
    print('ORC_BUILD_COMPLETE',row['stem'],flush=True)
assert hashlib.sha256(BASE.read_bytes()).hexdigest()==base_hash
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
if all((OUT/r['stem']/(r['stem']+'.glb')).exists() for r in ASSETS):
    (OUT/'orc_troops_manifest.json').write_text(json.dumps(ASSETS,ensure_ascii=False,indent=2),encoding='utf-8')
print('ORC_BATCH_COMPLETE',len(selected),flush=True)
