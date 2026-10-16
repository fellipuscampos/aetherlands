"""Import and exercise the orc asset and comparison in the actual Godot project."""
import argparse
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/orc_squire'
parser=argparse.ArgumentParser(); parser.add_argument('--godot',required=True); args=parser.parse_args()
for label,command in (
    ('import',[args.godot,'--headless','--editor','--path',str(ROOT),'--import']),
    ('validate',[args.godot,'--headless','--path',str(ROOT),'--script','res://tools/art_pipeline/verify_orc_squire_import.gd'])):
    result=subprocess.run(command,capture_output=True,text=True,timeout=180)
    (WORK/('godot_'+label+'.log')).write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
    print(label,result.returncode,result.stdout[-1000:],result.stderr[-1800:],flush=True)
    assert result.returncode==0 and 'SCRIPT ERROR' not in result.stderr and 'ERROR:' not in result.stderr
