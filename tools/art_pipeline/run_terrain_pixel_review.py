"""Capture the terrain once with the actual Godot renderer, hidden window."""
from pathlib import Path
import subprocess,json
ROOT=Path(__file__).resolve().parents[2]
GODOT=r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
result=subprocess.run([GODOT,'--path',str(ROOT),'--windowed','--resolution','1600x1000','--position','-2500,-1500','--script','res://tools/art_pipeline/terrain_review_bootstrap.gd'],capture_output=True,text=True,encoding='utf-8',errors='replace',startupinfo=startup,timeout=180)
log=result.stdout+'\n'+result.stderr
(ROOT/'art_source/terrain_pixel_review/godot_native_review.log').write_text(log,encoding='utf-8')
assert result.returncode==0 and 'SCRIPT ERROR:' not in log and 'ERROR:' not in result.stderr,log[-7000:]
report=json.loads((ROOT/'docs/terrain_pixel_godot_validation.json').read_text(encoding='utf-8'))
assert report['status']=='PASS'
print(json.dumps(report))
