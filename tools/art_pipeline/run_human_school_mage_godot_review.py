"""Import new assets and validate them; one optional native preview session."""
import argparse,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/human_school_mages_review'
GODOT=r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
parser=argparse.ArgumentParser(); parser.add_argument('stage',choices=['import','validate','native']); args=parser.parse_args()
if (WORK/'manifest.json').exists():
    manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
else:
    stems=['human_sacred_cleric_v1','human_infernal_warlock_v1','human_necromancer_v1','human_druid_v1','human_arcanist_v1','human_elementalist_v1']
    manifest=dict(assets=[json.loads((ROOT/'assets/generated/humans'/stem/(stem+'_report.json')).read_text(encoding='utf-8')) for stem in stems])
if args.stage=='import':
    for row in manifest['assets']:
        stem=row['stem']; folder=ROOT/'assets/generated/humans'/stem; path=folder/(stem+'.glb.import')
        source='res://'+(folder/(stem+'.glb')).relative_to(ROOT).as_posix()
        imported='res://.godot/imported/'+stem+'.glb-'+hashlib.md5(source.encode()).hexdigest()+'.scn'
        if path.exists():
            text=path.read_text(encoding='utf-8')
            old='import_script/path=""'
            text=text.replace(old,'import_script/path="res://tools/art_pipeline/human_school_mage_import.gd"')
        else:
            template=(ROOT/'assets/generated/humans/human_settler_v1/human_settler_v1.glb.import').read_text(encoding='utf-8')
            lines=[]
            for line in template.splitlines():
                if line.startswith('uid='): continue
                if line.startswith('path='): line='path='+json.dumps(imported)
                if line.startswith('source_file='): line='source_file='+json.dumps(source)
                if line.startswith('dest_files='): line='dest_files=['+json.dumps(imported)+']'
                if line.startswith('import_script/path='): line='import_script/path="res://tools/art_pipeline/human_school_mage_import.gd"'
                if line.startswith('animation/import='): line='animation/import=false'
                if line.startswith('meshes/generate_lods='): line='meshes/generate_lods=false'
                lines.append(line)
            text='\n'.join(lines)+'\n'
        path.write_text(text,encoding='utf-8')
    command=[GODOT,'--headless','--path',str(ROOT),'--import']
elif args.stage=='validate':
    command=[GODOT,'--headless','--path',str(ROOT),'--script','res://tools/art_pipeline/human_mage_review_bootstrap.gd','--','--validate-only']
else:
    command=[GODOT,'--path',str(ROOT),'--windowed','--resolution','1600x900','--position','-2500,-1500','--script','res://tools/art_pipeline/human_mage_review_bootstrap.gd']
startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
result=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',startupinfo=startup,timeout=300)
log=result.stdout+'\n'+result.stderr; (WORK/('godot_'+args.stage+'.log')).write_text(log,encoding='utf-8')
assert result.returncode==0 and 'SCRIPT ERROR:' not in log and 'ERROR:' not in result.stderr,log[-8000:]
if args.stage!='import':
    name='human_school_mages_godot_import_validation.json' if args.stage=='validate' else 'human_school_mages_godot_validation.json'
    report=json.loads((ROOT/'docs'/name).read_text(encoding='utf-8')); assert report['status']=='PASS' and report['verified']==6
    print(json.dumps(report))
else: print('Six human mage assets imported successfully.')
