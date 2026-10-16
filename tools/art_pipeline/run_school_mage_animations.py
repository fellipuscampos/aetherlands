"""Process mages strictly one at a time, using only the live Blender MCP."""
import argparse,ast,contextlib,io,json,re
from pathlib import Path
from blender_mcp_client import execute
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/school_mages_animation_review'; TOOLS=Path(__file__).parent
parser=argparse.ArgumentParser(); parser.add_argument('--race',choices=['human','elf','dwarf','orc']); parser.add_argument('--school'); parser.add_argument('--preview',action='store_true'); parser.add_argument('--force',action='store_true'); args=parser.parse_args()
revision=next(ast.literal_eval(n.value) for n in ast.parse((TOOLS/'school_mage_motion.py').read_text(encoding='utf-8')).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='REVISION' for t in n.targets))
logs=WORK/'mcp_logs'; logs.mkdir(exist_ok=True)
def call(prefix,name,stem):
    buffer=io.StringIO()
    try:
        with contextlib.redirect_stdout(buffer): result=execute(prefix+(TOOLS/name).read_text(encoding='utf-8'),timeout=900)
    except Exception:
        (logs/(stem+'_'+name+'.log')).write_text(buffer.getvalue(),encoding='utf-8')
        print(buffer.getvalue()[-10000:],flush=True); raise
    (logs/(stem+'_'+name+'.log')).write_text(buffer.getvalue(),encoding='utf-8')
    print(json.dumps(result.get('result',{})),flush=True)
for race in [args.race] if args.race else ['human','elf','dwarf','orc']:
    manifest=json.loads((ROOT/'art_source'/(race+'_school_mages_review')/'manifest.json').read_text(encoding='utf-8'))
    for index,row in enumerate(manifest['assets']):
        if args.school and row['school']!=args.school: continue
        folder=(ROOT/row['blend']).parent; stem=row['stem']; current=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'))
        if not args.force and current.get('animation',{}).get('choreography_revision')==revision and current.get('export',{}).get('animations')==3:
            print('ALREADY_COMPLETE',stem,flush=True); continue
        prefix='MAGE_RACE='+repr(race)+'\nMAGE_SCHOOL='+repr(row['school'])+'\n'
        call(prefix,'animate_school_mage_mcp.py',stem)
        call(prefix,'finish_school_mage_animation_mcp.py',stem)
        if args.preview and index==0: call(prefix,'preview_school_mage_cast_mcp.py',stem)
print('Requested sequential mage animation batch complete.',flush=True)
