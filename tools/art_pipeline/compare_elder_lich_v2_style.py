"""Render the actual current GLBs together under identical native Godot lighting."""
import hashlib,json,shutil,tempfile,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT=Path('C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
def run(project,args):
 startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
 process=subprocess.run([str(GODOT),'--path',str(project),*args],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180,startupinfo=startup)
 log=process.stdout+process.stderr
 if process.returncode: raise RuntimeError(log)
 return log
DEST=ROOT/'art_source/elder_lich_blocky_v2_review'; DEST.mkdir(parents=True,exist_ok=True)
(DEST/'.gdignore').write_text('')
assets={
 'skeleton':('Esqueleto atual','assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1.glb'),
 'necromancer':('Necromante humano','assets/generated/humans/human_necromancer_v1/human_necromancer_v1.glb'),
 'lich':('Lich Ancião V2','assets/generated/grand_manifestations/elder_lich_blocky_v2/elder_lich_blocky_v2.glb'),
 'archdemon':('Arcdemônio V5','assets/generated/grand_manifestations/archdemon_blocky_v5_animated/archdemon_blocky_v5_animated.glb'),
 'seraph':('Serafim V4','assets/generated/grand_manifestations/seraph_blocky_v4_animated/seraph_blocky_v4_animated.glb')}
with tempfile.TemporaryDirectory(prefix='lich_style_compare_') as tmp:
 project=Path(tmp)
 (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Lich style comparison"\n[display]\nwindow/size/viewport_width=1200\nwindow/size/viewport_height=1200\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n',encoding='utf-8')
 for _,relative in assets.values():
  target=project/relative; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/relative,target)
 (project/'assets.json').write_text(json.dumps(assets),encoding='utf-8')
 shutil.copy2(ROOT/'tools/art_pipeline/compare_elder_lich_v2_style.gd',project/'compare.gd')
 run(project,['--headless','--editor','--import'])
 log=run(project,['--script','res://compare.gd','--',str(DEST)])
 assert 'LICH_STYLE_COMPARISON PASS' in log,log
 manifest={k:{'name':n,'source':p,'sha256':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()} for k,(n,p) in assets.items()}
 (DEST/'references.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
print('Rendered current references and Lich V1 with identical lighting.')
