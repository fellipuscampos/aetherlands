"""Create the orc base in the open Blender, with hashes guarding previous art."""
import hashlib
import json
import shutil
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/orc_squire'; WORK.mkdir(parents=True,exist_ok=True); (WORK/'.gdignore').touch()
baseline=WORK/'protected_assets.json'
if not baseline.exists():
    protected={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest()
        for race in ('humans','dwarves','elves') for folder in (ROOT/'assets/generated'/race).iterdir()
        if folder.is_dir() and folder.name!='buildings'
        for path in folder.iterdir() if path.suffix in ('.blend','.glb','.png','.json')}
    baseline.write_text(json.dumps(protected,indent=2),encoding='utf-8')
protected=json.loads(baseline.read_text(encoding='utf-8'))
previous=ROOT/'assets/generated/orcs/orc_squire_v1'
backup=WORK/'before_bulk_refinement'
if previous.exists() and not backup.exists(): shutil.copytree(previous,backup)
visual_backup=WORK/'before_equipment_refinement'
if previous.exists() and not visual_backup.exists(): shutil.copytree(previous,visual_backup)
finish_backup=WORK/'before_brows_clothing_refinement'
if previous.exists() and not finish_backup.exists(): shutil.copytree(previous,finish_backup)
roster_backup=WORK/'approved_before_roster'
if previous.exists() and not roster_backup.exists(): shutil.copytree(previous,roster_backup)
code=f'''import sys, importlib.util
if {str(ROOT/'tools/art_pipeline')!r} not in sys.path: sys.path.insert(0,{str(ROOT/'tools/art_pipeline')!r})
import orc_rig_helpers,orc_clothing_paint
importlib.reload(orc_rig_helpers); importlib.reload(orc_clothing_paint)
spec=importlib.util.spec_from_file_location('orc_squire_builder',{str(ROOT/'tools/art_pipeline/build_orc_squire.py')!r})
builder=importlib.util.module_from_spec(spec); spec.loader.exec_module(builder)
result=builder.build()
'''
execute(code,timeout=1200)
assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in protected.items())
print('ORC_SQUIRE_MCP_COMPLETE',flush=True)
