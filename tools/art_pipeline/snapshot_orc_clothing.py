import shutil,json,hashlib
from orc_troop_assets import ASSETS,OUT,WORK
dest=WORK/'clothing_refinement/before_assets'
dest.mkdir(parents=True,exist_ok=True)
hashes={}
for row in ASSETS:
    source=OUT/row['stem'];target=dest/row['stem']
    if not target.exists():shutil.copytree(source,target)
    for suffix in ('.blend','.glb','_albedo.png','_report.json'):
        path=target/(row['stem']+suffix)
        hashes[str(path.relative_to(WORK))]=hashlib.sha256(path.read_bytes()).hexdigest()
(dest.parent/'snapshot_sha256.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
print('CLOTHING_SNAPSHOT_READY',len(ASSETS))
