"""Build the elven siege roster in the running Blender; protect existing assets."""
import argparse
import hashlib
import json
from pathlib import Path
from blender_mcp_client import execute
from elf_siege_assets import ROOT, OUT, WORK, SIEGE_ASSETS
from elf_troop_assets import ASSETS

parser=argparse.ArgumentParser(); parser.add_argument('--only',nargs='+'); args=parser.parse_args()
WORK.mkdir(parents=True,exist_ok=True); (WORK/'.gdignore').touch()
baseline_path=WORK/'protected_assets.json'
if not baseline_path.exists():
    protected={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest()
        for race in ('humans','dwarves','elves') for folder in (ROOT/'assets/generated'/race).iterdir()
        if folder.is_dir() and folder.name!='buildings' and folder.name not in {row['stem'] for row in SIEGE_ASSETS}
        for path in folder.iterdir() if path.suffix in ('.blend','.glb','.png','.json')}
    baseline_path.write_text(json.dumps(protected,indent=2),encoding='utf-8')
protected=json.loads(baseline_path.read_text(encoding='utf-8'))
for row in SIEGE_ASSETS:
    if args.only and row['stem'] not in args.only: continue
    print('OPEN_BLENDER_MCP_BUILD',row['stem'],flush=True)
    code=f'''import sys, importlib.util
if {str(ROOT/'tools/art_pipeline')!r} not in sys.path: sys.path.insert(0,{str(ROOT/'tools/art_pipeline')!r})
spec=importlib.util.spec_from_file_location('elf_siege_builder',{str(ROOT/'tools/art_pipeline/build_elf_siege.py')!r})
builder=importlib.util.module_from_spec(spec); spec.loader.exec_module(builder)
result=builder.build({row!r})
'''
    execute(code,timeout=1200)
assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in protected.items())
if all((OUT/row['stem']/(row['stem']+'.glb')).exists() for row in SIEGE_ASSETS):
    (OUT/'elf_troops_manifest.json').write_text(json.dumps(ASSETS+SIEGE_ASSETS,ensure_ascii=False,indent=2),encoding='utf-8')
print('ELF_SIEGE_COMPLETE',flush=True)
