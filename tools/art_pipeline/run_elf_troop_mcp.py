"""Build and render elf troops using only the running Blender's MCP connection."""
import argparse
import json
from pathlib import Path

from blender_mcp_client import execute
from elf_troop_assets import ROOT, OUT, WORK, ASSETS
from elf_siege_assets import SIEGE_ASSETS
import hashlib

parser=argparse.ArgumentParser()
parser.add_argument('--only',nargs='+')
args=parser.parse_args()
WORK.mkdir(parents=True,exist_ok=True); (WORK/'.gdignore').touch()
selected=[a for a in ASSETS if not args.only or a['stem'] in args.only]
protected={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
           for race in ('humans','dwarves') for folder in (ROOT/'assets/generated'/race).iterdir()
           if folder.is_dir() and folder.name!='buildings' for p in folder.iterdir()
           if p.suffix in ('.blend','.glb','.png','.json')}
baseline=WORK/'protected_source_baseline.json'
if not baseline.exists(): baseline.write_text(json.dumps(protected,indent=2),encoding='utf-8')
pipe=str(ROOT/'tools/art_pipeline')
for row in selected:
    print('BUILD_THROUGH_OPEN_BLENDER_MCP',row['stem'],flush=True)
    code=f'''import bpy, sys, importlib.util, importlib
if {pipe!r} not in sys.path: sys.path.insert(0,{pipe!r})
import elf_troop_paint
importlib.reload(elf_troop_paint)
spec=importlib.util.spec_from_file_location('elf_builder', {str(Path(pipe)/'build_elf_troops.py')!r})
elf_builder=importlib.util.module_from_spec(spec)
spec.loader.exec_module(elf_builder)
elf_builder.build({row!r}, ['front','three_quarter','game_top','back'])
result=dict(stem={row['stem']!r},scene=bpy.context.scene.name,pipeline='Open Blender MCP',saved=True)
'''
    execute(code,timeout=600)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
if all((OUT/a['stem']/(a['stem']+'.glb')).exists() for a in ASSETS):
    completed_siege=[row for row in SIEGE_ASSETS if (OUT/row['stem']/(row['stem']+'.glb')).exists()]
    (OUT/'elf_troops_manifest.json').write_text(json.dumps(ASSETS+completed_siege,ensure_ascii=False,indent=2),encoding='utf-8')
print('OPEN_BLENDER_ELF_BATCH_COMPLETE',len(selected),flush=True)
