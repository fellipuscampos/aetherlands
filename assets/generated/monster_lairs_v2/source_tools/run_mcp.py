"""Call the project's existing Blender MCP client sequentially, with reviewable logs."""
from pathlib import Path
import sys
import argparse
import json
import contextlib
import hashlib

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from blender_mcp_client import execute

KINDS=['goblin','skeleton','worg','giant_spider','troll','wyvern','minotaur','basilisk',
       'colossal_worm','arboreal_ancient','mana_devourer','corrupted_hero']

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--only',nargs='+',choices=KINDS)
    parser.add_argument('--rebuild',action='store_true'); args=parser.parse_args()
    for kind in args.only or KINDS:
        print('START',kind,flush=True)
        code=f'''import importlib.util
spec=importlib.util.spec_from_file_location('lair_art_v2',{str(WORK/'build_lairs.py')!r})
lair_art_v2=importlib.util.module_from_spec(spec)
spec.loader.exec_module(lair_art_v2)
result=lair_art_v2.build({kind!r},rebuild={args.rebuild!r})
'''
        with (WORK/(kind+'_mcp.log')).open('w',encoding='utf-8') as log:
            with contextlib.redirect_stdout(log): response=execute(code,timeout=600)
        print('DONE',kind,flush=True)
    baseline=json.loads((WORK/'protected_monster_models.json').read_text())
    changed=[p for p,sha in baseline.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=sha]
    assert not changed,changed
    print('Original monster sources preserved:',len(baseline),flush=True)
