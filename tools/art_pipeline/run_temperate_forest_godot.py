"""Prepare and verify the standalone Godot bundle in an isolated import project."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
RELATIVE=Path('assets/generated/nature/temperate_forest_v1')
SOURCE=ROOT/RELATIVE
GODOT=Path(r'C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
with tempfile.TemporaryDirectory(prefix='temperate_forest_validation_') as temporary:
    project=Path(temporary).resolve()
    assert project.parent==Path(tempfile.gettempdir()).resolve()
    (project/'project.godot').write_text('[application]\nconfig/name="Temperate Forest Kit Validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n',encoding='utf-8')
    kit=project/RELATIVE
    kit.mkdir(parents=True)
    shutil.copy2(SOURCE/'manifest.json',kit/'manifest.json')
    shutil.copytree(SOURCE/'textures',kit/'textures',ignore=shutil.ignore_patterns('*.import'))
    (kit/'models').mkdir(); (kit/'godot').mkdir()
    manifest=json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))
    for entry in manifest['assets']:
        name=entry['asset']; folder=kit/'models'/name; folder.mkdir()
        shutil.copy2(SOURCE/'models'/name/(name+'.glb'),folder/(name+'.glb'))
    shutil.copy2(ROOT/'tools/art_pipeline/prepare_temperate_forest_godot.gd',project/'prepare.gd')
    def run(arguments):
        result=subprocess.run([str(GODOT),'--headless','--path',str(project),*arguments],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
        if result.returncode or 'SCRIPT ERROR' in result.stdout+result.stderr or 'ERROR:' in result.stderr:
            print(result.stdout); print(result.stderr); raise RuntimeError('Godot kit preparation failed')
        return result
    run(['--editor','--import'])
    # Keep crisp nearest sampling close up, with mipmaps to reduce shimmering
    # at distance. Preserve the import setting in the actual asset folder.
    settings=kit/'textures/forest_pixel_atlas.png.import'
    content=settings.read_text(encoding='utf-8')
    assert 'mipmaps/generate=false' in content
    settings.write_text(content.replace('mipmaps/generate=false','mipmaps/generate=true'),encoding='utf-8')
    run(['--editor','--import'])
    result=run(['--script','res://prepare.gd'])
    print(result.stdout)
    report=json.loads((kit/'godot_validation.json').read_text(encoding='utf-8'))
    assert report['status']=='PASS' and report['verified']==10
    for path in (kit/'godot').iterdir():
        if path.is_file(): shutil.copy2(path,SOURCE/'godot'/path.name)
    shutil.copy2(settings,SOURCE/'textures'/settings.name)
    (ROOT/'docs/temperate_forest_godot_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    for entry in manifest['assets']:
        name=entry['asset']; entry.update({'godot_scene':'godot/'+name+'.tscn','godot_mesh':'godot/'+name+'.res'})
    manifest['godot_material']='godot/forest_pixel_material.tres'
    manifest['recommended_scale_variation']=[.85,1.12]
    manifest['texture_filter']='nearest with mipmaps; shared opaque material'
    (SOURCE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
