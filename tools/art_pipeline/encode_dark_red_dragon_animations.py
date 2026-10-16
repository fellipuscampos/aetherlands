"""Encode native Godot animation captures into individual clips and a review reel."""
import json,shutil,subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

ROOT=Path(__file__).resolve().parents[2]
STEM='dark_red_dragon_v5_animated'
OUT=ROOT/'assets/generated/dragons'/STEM/'previews/animations'
SOURCE=ROOT/'art_source/dark_red_dragon_animation_review/frames'
OUT.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
specs=[('Dragon_Idle_Ground',72,True),('Dragon_Idle_Flying',48,True),
    ('Dragon_Walk_Ground',36,True),('Dragon_Walk_Flying',36,True),
    ('Dragon_Attack_Ground',73,False),('Dragon_Attack_Flying',73,False)]

def encode(spec):
    name,count,loop=spec
    files=list((SOURCE/name).glob('*.png')); assert len(files)==count,(name,count,len(files))
    command=[ffmpeg,'-hide_banner','-loglevel','error','-y']
    if loop: command+=['-stream_loop','1']
    command+=['-framerate','24','-start_number','0','-i',str(SOURCE/name/'%04d.png'),
        '-frames:v',str(count*(2 if loop else 1))]
    subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/(name+'.mp4'))],check=True)
    subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-i',str(OUT/(name+'.mp4')),
        '-filter_complex_threads','1','-filter_complex','[0:v]fps=12,split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none',
        '-loop','0' if loop else '-1',str(OUT/(name+'.gif'))],check=True)
    return name,{'source_frames':count,'fps':24,'loop':loop,'preview_cycles':2 if loop else 1,'mp4':name+'.mp4','gif':name+'.gif'}

with ThreadPoolExecutor(max_workers=2) as pool:
    manifest=dict(pool.map(encode,specs))
concat=OUT/'reel_sources.txt'
concat.write_text('\n'.join("file '"+name+".mp4'" for name,_,_ in specs)+'\n',encoding='utf-8')
subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(concat),
    '-c','copy','-movflags','+faststart',str(OUT/'Dragon_All_Animations.mp4')],check=True)
manifest['review_reel']='Dragon_All_Animations.mp4'
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
