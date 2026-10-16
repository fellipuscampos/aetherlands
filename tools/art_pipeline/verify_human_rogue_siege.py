"""Validate isolated sources/exports, inheritance, baseline and real Godot imports."""
import argparse, json, hashlib, struct, shutil, subprocess, tempfile
from pathlib import Path
from human_rogue_siege_assets import ROOT, ASSETS, roles

PIPE=Path(__file__).resolve().parent

def import_settings(a):
    return '[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\n\nsource_file="res://assets/generated/humans/'+a['stem']+'/'+a['stem']+'.glb"\n\n[params]\n\nnodes/root_scale=1.0\nnodes/apply_root_scale=true\nskins/use_named_skins=true\nanimation/import=true\nanimation/fps=24\nanimation/remove_immutable_tracks=false\nimport_script/path="res://assets/generated/humans/'+a['stem']+'/'+a['stem']+'_import.gd"\nmeshes/generate_lods=false\ngltf/embedded_image_handling=1\n'

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--start',type=int,default=0); p.add_argument('--end',type=int,default=8); p.add_argument('--godot',required=True); args=p.parse_args()
    manifest=[]; reports={}; faults=[]
    for a in ASSETS[args.start:args.end]:
        folder=ROOT/'assets/generated/humans'/a['stem']; report=json.loads((folder/(a['stem']+'_report.json')).read_text(encoding='utf-8')); reports[a['stem']]=report
        data=(folder/(a['stem']+'.glb')).read_bytes(); length=struct.unpack_from('<I',data,12)[0]; gltf=json.loads(data[20:20+length])
        assert sorted(x['name'] for x in gltf['animations'])==sorted(a['prefix']+'_'+r for r in roles(a))
        assert report['nonmanifold_edges']==0 and report['animation_validation']['problems']==[]
        for role in roles(a):
            clip=a['prefix']+'_'+role
            for extension in ('.mp4','.gif','_contact.png'): assert (folder/'previews/animations'/(clip+extension)).is_file()
        if a['family']=='rogue' and a['level']:
            previous=json.loads((ROOT/'assets/generated/humans'/a['parent']/(a['parent']+'_report.json')).read_text(encoding='utf-8'))
            parent=next(p for p in ASSETS if p['stem']==a['parent'])
            for role in roles(parent):
                child=report['animation_validation']['samples'][a['prefix']+'_'+role]['curve_sha256']; old=previous['animation_validation']['samples'][parent['prefix']+'_'+role]['curve_sha256']
                assert child==old,(a['stem'],role,'changed inherited curves')
        (folder/(a['stem']+'.glb.import')).write_text(import_settings(a),encoding='utf-8')
        manifest.append({'stem':a['stem'],'prefix':a['prefix'],'height':a['height'],'bones':report['glb']['joints'],'clips':report['glb']['clips']})
    baseline=json.loads((ROOT/'docs/human_rogue_siege_source_baseline.json').read_text(encoding='utf-8'))
    changed=[p for p,h in baseline.items() if not (ROOT/p).exists() or hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
    expected_changes=[]
    if changed==['scripts/data/UnitDatabase.gd']:
        backup=ROOT/'art_source/human_rogue_siege_runtime_before/UnitDatabase.gd'
        assert backup.is_file() and hashlib.sha256(backup.read_bytes()).hexdigest()==baseline['scripts/data/UnitDatabase.gd']
        expected_changes=changed
    else:
        assert not changed,changed
    with tempfile.TemporaryDirectory(prefix='human_rogue_siege_import_') as directory:
        project=Path(directory)
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Human troop validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        (project/'manifest.json').write_text(json.dumps(manifest),encoding='utf-8')
        shutil.copyfile(PIPE/'verify_human_rogue_siege_import.gd',project/'verify.gd')
        for a in ASSETS[args.start:args.end]:
            src=ROOT/'assets/generated/humans'/a['stem']; dest=project/'assets/generated/humans'/a['stem']; dest.mkdir(parents=True)
            for filename in (a['stem']+'.glb',a['stem']+'.glb.import',a['stem']+'_import.gd'): shutil.copyfile(src/filename,dest/filename)
        imported=subprocess.run([args.godot,'--headless','--editor','--path',str(project),'--import'],capture_output=True,text=True,timeout=240)
        if imported.returncode: print(imported.stdout[-5000:],imported.stderr[-5000:]); raise SystemExit(imported.returncode)
        suffix='' if args.start==0 and args.end==8 else '_'+str(args.start)+'_'+str(args.end)
        done=subprocess.run([args.godot,'--headless','--path',str(project),'--script','verify.gd','--',str(ROOT/'docs'/('human_rogue_siege_godot_validation'+suffix+'.json'))],capture_output=True,text=True,timeout=180)
        print(done.stdout[-5000:]); print(done.stderr[-3000:])
        if done.returncode: raise SystemExit(done.returncode)
    print(json.dumps({'baseline_files_preserved':len(baseline)-len(expected_changes),'expected_visual_integration_changes':expected_changes,'assets':len(manifest),'inheritance':'exact curve hashes, all earlier rogue clips retained'}))
