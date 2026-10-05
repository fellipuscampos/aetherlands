"""Encode Blender-rendered PNG sequences; no image synthesis or model changes."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'art_source/troll_blocky_v3/animation_frames'
out=ROOT/'assets/generated/trolls/troll_blocky_v3/previews/animations'
out.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg')
if not ffmpeg: raise RuntimeError('ffmpeg not found; PNG sequences are available')
manifest={}
for name,count in [('Troll_Idle',48),('Troll_Walk',28),('Troll_Attack',37)]:
    assert len(list((source/name).glob('*.png')))==count
    base=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','24',
          '-start_number','1','-i',str(source/name/'%04d.png'),'-frames:v',str(count)]
    subprocess.run(base+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p',
                        '-movflags','+faststart',str(out/(name+'.mp4'))],check=True)
    subprocess.run(base+['-filter_complex_threads','1','-filter_complex',
                        '[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none',
                        '-loop','-1' if name=='Troll_Attack' else '0',str(out/(name+'.gif'))],check=True)
    manifest[name]={'frames':count,'fps':24,'mp4':name+'.mp4','gif':name+'.gif'}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
