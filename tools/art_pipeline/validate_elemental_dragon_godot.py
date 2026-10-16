"""Check the GLB and import the static dragon in an isolated Godot project."""
import argparse,json,shutil,struct,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--stem',default='elemental_dragon_v1',choices=['elemental_dragon_v1','elemental_dragon_v2','elemental_dragon_v3','elemental_dragon_v4','elemental_dragon_v5_animated','elemental_dragon_v6_animated','elemental_dragon_v7_animated','elemental_dragon_v8_animated','elemental_dragon_v9_animated','elemental_dragon_v10_animated'])
STEM=parser.parse_args().stem
REL=Path('assets/generated/grand_manifestations')/STEM; OUT=ROOT/REL
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
IMPORT='tools/art_pipeline/elemental_dragon_model_import.gd'
ANIMATED=STEM.endswith('_animated')
if ANIMATED: IMPORT='tools/art_pipeline/elemental_dragon_animation_import.gd'
report=json.loads((OUT/(STEM+'_report.json')).read_text(encoding='utf-8'))
raw=(OUT/(STEM+'.glb')).read_bytes(); length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length])
assert not doc.get('cameras')
if ANIMATED:
    assert sorted(a['name'] for a in doc.get('animations',[]))==sorted(report['clips'])
else: assert not doc.get('animations')
assert len(doc['meshes'])==len(doc['materials'])==len(doc['skins'])==1
assert len(doc['images'])==2 and len(doc['skins'][0]['joints'])==len(report['prepared_bones'])
assert len(doc['meshes'][0]['primitives'])==1
assert doc['accessors'][doc['meshes'][0]['primitives'][0]['indices']]['count']//3==report['triangles']
def run(folder,args):
    startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
    result=subprocess.run([str(GODOT),'--headless','--path',str(folder),*args],capture_output=True,text=True,
        encoding='utf-8',errors='replace',startupinfo=startup,timeout=90)
    output=result.stdout+result.stderr
    if result.returncode or 'SCRIPT ERROR' in output or 'ERROR:' in output: raise RuntimeError(output)
    return output
with tempfile.TemporaryDirectory(prefix='elemental_dragon_validation_') as temporary:
    folder=Path(temporary); target=folder/REL; target.mkdir(parents=True)
    shutil.copy2(OUT/(STEM+'.glb'),target/(STEM+'.glb'))
    (folder/IMPORT).parent.mkdir(parents=True); shutil.copy2(ROOT/IMPORT,folder/IMPORT)
    shutil.copy2(ROOT/'tools/art_pipeline/verify_elemental_dragon_import.gd',folder/'verify.gd')
    (folder/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Elemental Dragon Validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    run(folder,['--editor','--import'])
    settings=target/(STEM+'.glb.import')
    contents=settings.read_text(encoding='utf-8').replace('import_script/path=""','import_script/path="res://'+IMPORT+'"')
    if STEM in ('elemental_dragon_v9_animated','elemental_dragon_v10_animated'):
        contents=contents.replace('_subresources={}','_subresources={"nodes":{"PATH:AnimationPlayer":{"optimizer/enabled":false,"compression/enabled":false}}}')
    settings.write_text(contents,encoding='utf-8'); (target/(STEM+'.glb')).touch()
    run(folder,['--editor','--import'])
    run(folder,['--script','res://verify.gd','--quit-after','5','--',str(OUT/'godot_validation.json'),'res://'+REL.as_posix()+'/'+STEM+'.glb'])
    validation=json.loads((OUT/'godot_validation.json').read_text(encoding='utf-8')); assert validation['status']=='PASS'
    shutil.copy2(settings,OUT/settings.name); (OUT/(STEM+'.glb')).touch()
    for texture in target.glob('*.png'): shutil.copy2(texture,OUT/texture.name)
    print(json.dumps(validation,indent=2))
