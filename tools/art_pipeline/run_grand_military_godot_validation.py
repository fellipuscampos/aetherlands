"""Reuse the established isolated GLB importer with military IDs and report path."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from grand_military_assets import RECIPES

PIPELINE=Path(__file__).resolve().parent
ROOT=PIPELINE.parents[1]
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',required=True)
    parser.add_argument('--civ',choices=('human','orc','dwarf','elf'))
    args=parser.parse_args()
    source=(PIPELINE/'verify_magic_school_import.gd').read_text(encoding='utf-8')
    start=source.index('\tvar stems :=')
    end=source.index('\tvar civs :=')
    source=source[:start]+'\tvar stems := ['+', '.join('"'+r[0]+'"' for r in RECIPES.values())+']\n'+source[end:]
    original='("grand_magic_godot_validation" if grand_mode else "magic_schools_godot_validation")'
    assert original in source
    source=source.replace(original,'"grand_military_godot_validation"')
    with tempfile.TemporaryDirectory(prefix='grand_military_godot_') as temp:
        project=Path(temp).resolve()
        assert project.parent==Path(tempfile.gettempdir()).resolve()
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Grand military validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        (project/'verify.gd').write_text(source,encoding='utf-8')
        done=subprocess.run([args.godot,'--headless','--path',str(project),'--script','verify.gd','--',str(ROOT),args.civ or 'all'],timeout=240)
    if done.returncode==0 and not args.civ:
        full=json.loads((ROOT/'docs/grand_military_godot_validation.json').read_text(encoding='utf-8'))
        for civ in ('human','orc','dwarf','elf'):
            subset=[entry for entry in full['assets'] if
                    next((p for p in ('orc','dwarf','elf') if entry['asset'].startswith(p+'_')),'human')==civ]
            report={'status':full['status'],'verified':len(subset),'assets':subset,'problems':[],
                    'source':'grand_military_godot_validation.json'}
            (ROOT/'docs'/('grand_military_godot_validation_'+civ+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    raise SystemExit(done.returncode)
