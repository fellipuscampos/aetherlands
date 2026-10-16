"""Build using the already-open Blender's MCP socket. Never launches Blender."""
import argparse
import json
from pathlib import Path

from blender_mcp_client import execute
from dwarf_troop_assets import ASSETS, ROOT, WORK

parser=argparse.ArgumentParser()
parser.add_argument('--units',nargs='*')
parser.add_argument('--no-render',action='store_true')
parser.add_argument('--base',action='store_true')
parser.add_argument('--humanoids-only',action='store_true',help='Rebuild the twenty characters, retaining the four siege machines.')
args=parser.parse_args()
WORK.mkdir(parents=True,exist_ok=True); (WORK/'.gdignore').touch()
rows=[r for r in ASSETS if not args.units or r['stem'] in args.units]
if args.humanoids_only: rows=[r for r in rows if r['family']!='siege']
source=str(ROOT/'tools/art_pipeline/build_dwarf_troops.py')
for row in rows:
    code=f'''import bpy, importlib, sys
from pathlib import Path
source=Path({source!r})
if str(source.parent) not in sys.path: sys.path.insert(0,str(source.parent))
import dwarf_troop_paint
importlib.reload(dwarf_troop_paint)
import dwarf_troop_assets
importlib.reload(dwarf_troop_assets)
ns={{'__file__':str(source),'__name__':'dwarf_live_factory'}}
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),ns)
ns['build']({row!r},render={not args.no_render!r})
result={{'asset':{row['stem']!r},'scene':bpy.context.scene.name,'mcp':'live','anatomical_parts':len(ns['BODY'])}}
'''
    response=execute(code)
    print('MCP_DWARF_DONE '+row['stem'],flush=True)
if args.base or not args.units:
    execute(f'''from pathlib import Path
source=Path({source!r})
ns={{'__file__':str(source),'__name__':'dwarf_live_factory'}}
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),ns)
ns['build_base'](render={not args.no_render!r})
result={{'base':'dwarf_base_v1','anatomical_parts':len(ns['BODY']),'neck':False,'mcp':'live'}}
''')
