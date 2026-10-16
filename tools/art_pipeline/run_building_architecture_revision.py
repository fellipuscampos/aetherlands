"""Back up selected buildings, then rebuild them sequentially via Blender MCP."""
import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
import shutil
import time
from blender_mcp_client import execute

ROOT = Path(__file__).resolve().parents[2]
PIPELINE = ROOT/'tools/art_pipeline'
REVIEW = ROOT/'art_source/building_architecture_review'
BACKUP = ROOT/'art_source/buildings_before_architecture_revision'
STEMS = ('guardian_hall','warrior_hall','ranger_camp','war_stable','rogue_guild','siege_arsenal')
MAGIC = ('sacred_temple','sacred_ritual','infernal_sanctum','infernal_ritual','necromancy_ossuary','necromancy_ritual','druidic_circle','druidic_ritual','arcane_conclave','arcane_ritual','elemental_observatory','elemental_ritual')

def targets():
    folders=['war_stable_hex_v1','elf_war_stable_hex_v1','dwarf_war_stable_hex_v1','orc_arcane_conclave_hex_v1']
    folders += [s+'_hex_v1' for s in STEMS if s!='guardian_hall']
    folders += [s+'_hex_v1' for s in ('cavalry_mastery','rogue_mastery','grand_arsenal','ranger_mastery','warrior_mastery')]
    folders += [s+'_hex_v1' for s in MAGIC if not s.startswith('druidic')]
    folders += ['elf_'+s+'_hex_v1' for s in STEMS]
    folders += ['dwarf_'+s+'_hex_v1' for s in STEMS if s not in ('guardian_hall','warrior_hall')]
    for civ in ('elf','dwarf','orc'):
        folders += [civ+'_'+s+'_hex_v1' for s in MAGIC]
    return list(dict.fromkeys(folders))

def backup(folder):
    sources=list((ROOT/'assets/generated').glob('*/buildings/'+folder))
    assert len(sources)==1
    src=sources[0]; dst=BACKUP/src.relative_to(ROOT/'assets/generated')
    if not dst.exists(): shutil.copytree(src,dst)
    return {'folder':folder,'backup':dst.relative_to(ROOT).as_posix(),
            'files':{p.relative_to(dst).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in dst.rglob('*') if p.is_file()}}

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--only',nargs='+')
    parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--limit',type=int)
    args=parser.parse_args()
    queue=args.only or targets()[args.start:]
    if args.limit: queue=queue[:args.limit]
    REVIEW.mkdir(parents=True,exist_ok=True)
    BACKUP.mkdir(parents=True,exist_ok=True)
    (BACKUP/'.gdignore').touch(exist_ok=True)
    (REVIEW/'.gdignore').touch(exist_ok=True)
    manifest_path=BACKUP/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else []
    for folder in queue:
        if not any(x['folder']==folder for x in manifest):
            manifest.append(backup(folder))
            manifest_path.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    progress_path=REVIEW/'completed.json'
    completed=json.loads(progress_path.read_text(encoding='utf-8')) if progress_path.exists() else []
    for i,folder in enumerate(queue):
        if any(x['asset']==folder for x in completed):
            print('SKIP '+folder,flush=True); continue
        print(f'REBUILD {i+1}/{len(queue)} {folder}',flush=True)
        started=time.monotonic()
        code=(PIPELINE/'rebuild_building_architecture_mcp.py').read_text(encoding='utf-8')
        captured=io.StringIO()
        try:
            with contextlib.redirect_stdout(captured):
                response=execute('ARCH_FOLDER='+repr(folder)+'\n'+code,timeout=1200)
        except Exception:
            (REVIEW/(folder+'_error.txt')).write_text(captured.getvalue(),encoding='utf-8')
            print(captured.getvalue(),flush=True)
            raise
        entry=response['result']; entry['seconds']=round(time.monotonic()-started,1)
        completed.append(entry)
        progress_path.write_text(json.dumps(completed,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(entry,ensure_ascii=True),flush=True)
    print('ARCHITECTURE_REVISION_COMPLETE',flush=True)
