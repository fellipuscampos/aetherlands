import argparse,subprocess
from orc_troop_assets import ROOT,WORK
parser=argparse.ArgumentParser(); parser.add_argument('--godot',required=True)
parser.add_argument('--skip-import',action='store_true',help='Use assets already imported by the editor.')
args=parser.parse_args()
for label,command in (
 ('import',[args.godot,'--headless','--editor','--path',str(ROOT),'--import']),
 ('validate',[args.godot,'--headless','--path',str(ROOT),'--script','res://tools/art_pipeline/verify_orc_troops_import.gd']),
 ('base_validate',[args.godot,'--headless','--path',str(ROOT),'--script','res://tools/art_pipeline/verify_orc_squire_import.gd'])):
    if label=='import' and args.skip_import:continue
    result=subprocess.run(command,capture_output=True,text=True,timeout=240)
    (WORK/('godot_'+label+'.log')).write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
    print(label,result.returncode,result.stdout[-1000:],result.stderr[-2200:],flush=True)
    assert result.returncode==0 and 'SCRIPT ERROR' not in result.stderr and 'ERROR:' not in result.stderr
