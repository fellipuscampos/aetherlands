"""Import/test the actual construction asset in a small isolated Godot project."""
import json,re,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STEM='dwarf_construction_site_hex_v1'
ASSET=Path('assets/generated/dwarves/buildings')/STEM
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
with tempfile.TemporaryDirectory(prefix='dwarf_construction_validation_') as temporary:
    project=Path(temporary)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Dwarf Construction Review"\n[animation]\ncompatibility/default_parent_skeleton_in_mesh_instance_3d=true\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n',encoding='utf-8')
    paths=[ASSET/(STEM+'.glb'),ASSET/(STEM+'.tscn'),Path('scripts/art_review/DwarfConstructionSite.gd'),Path('tools/art_pipeline/dwarf_construction_import.gd'),Path('scenes/art_review/DwarfConstructionReview.tscn'),Path('scripts/world/HexMetrics.gd')]
    for path in paths:
        target=project/path; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/path,target)
    # Preserve the real project's UIDs when validating a revised export.
    for item in (ROOT/ASSET).glob('*.png*'):
        shutil.copy2(item,project/ASSET/item.name)
    previous=ROOT/ASSET/(STEM+'.glb.import')
    if previous.exists(): shutil.copy2(previous,project/ASSET/previous.name)
    shutil.copy2(ROOT/'tools/art_pipeline/verify_dwarf_construction_import.gd',project/'verify.gd')
    def run(args):
        result=subprocess.run([str(GODOT),'--headless','--path',str(project),*args],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
        if result.returncode or 'SCRIPT ERROR' in result.stdout+result.stderr or 'ERROR:' in result.stderr:
            print(result.stdout); print(result.stderr); raise RuntimeError('Godot validation failed')
        print(result.stdout[-1600:])
    run(['--editor','--import'])
    settings=project/ASSET/(STEM+'.glb.import')
    value=settings.read_text(encoding='utf-8')
    value=re.sub(r'^import_script/path=.*$', 'import_script/path="res://tools/art_pipeline/dwarf_construction_import.gd"',value,flags=re.M)
    value=re.sub(r'^animation/fps=.*$','animation/fps=30',value,flags=re.M)
    settings.write_text(value,encoding='utf-8')
    run(['--editor','--import'])
    run(['--script','res://verify.gd'])
    run(['res://scenes/art_review/DwarfConstructionReview.tscn','--quit-after','3'])
    report=json.loads((project/'godot_validation.json').read_text(encoding='utf-8'))
    (ROOT/'docs/dwarf_construction_godot_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    destination=ROOT/ASSET/(STEM+'.glb.import')
    value=settings.read_text(encoding='utf-8')
    if destination.exists():
        uid=re.search(r'^uid=.*$',destination.read_text(encoding='utf-8'),flags=re.M)
        if uid: value=re.sub(r'^uid=.*$',uid.group(0),value,flags=re.M)
    destination.write_text(value,encoding='utf-8')
    for item in (project/ASSET).glob('*.png*'):
        shutil.copy2(item,ROOT/ASSET/item.name)
    # Same res:// path gives the same cache name in the real project.
    cache=ROOT/'.godot/imported'; cache.mkdir(parents=True,exist_ok=True)
    for item in (project/'.godot/imported').glob(STEM+'*'):
        shutil.copy2(item,cache/item.name)
    for path in paths:
        uid=(project/path).with_suffix(path.suffix+'.uid')
        if uid.exists() and not (ROOT/path).with_suffix(path.suffix+'.uid').exists():
            shutil.copy2(uid,(ROOT/path).with_suffix(path.suffix+'.uid'))
print('DWARF_CONSTRUCTION_GODOT_PASS')
