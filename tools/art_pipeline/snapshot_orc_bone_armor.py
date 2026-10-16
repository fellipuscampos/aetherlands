"""Freeze the approved leather revision before the narrowly scoped bone pass."""
import argparse,json,hashlib,shutil
from orc_troop_assets import ROOT,OUT,WORK,ASSETS

parser=argparse.ArgumentParser();parser.add_argument('--revision',default='bone_armor_refinement');args=parser.parse_args()
assert args.revision in ('bone_armor_refinement','horns_and_hoods','open_skull','war_boars','war_bulls','war_bull_finish'),args.revision
destination=WORK/args.revision;destination.mkdir(exist_ok=True)
manifest=destination/'before_hashes.json'
if not manifest.exists():
    hashes={}
    for row in ASSETS:
        src=OUT/row['stem'];target=destination/'before_assets'/row['stem']
        assert not target.exists(),str(target)
        shutil.copytree(src,target)
        for p in src.rglob('*'):
            if p.is_file():hashes[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
    manifest.write_text(json.dumps(hashes,indent=2),encoding='utf-8')
print(json.dumps({'snapshot':str(destination),'files':len(json.loads(manifest.read_text()))}))
