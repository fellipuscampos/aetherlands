"""Encode the Blender-rendered sequences as MP4 and GIF review files."""
import json
import shutil
import subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[2]
source=root/'art_source/goblin_raider_v3/animation_frames'
out=root/'assets/generated/goblins/goblin_raider_v3/previews/animations'
out.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
manifest={}
for name,count in [('Goblin_Idle',60),('Goblin_Walk',20),('Goblin_Attack',29)]:
    assert len(list((source/name).glob('*.png')))==count
    command=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','24','-start_number','1',
             '-i',str(source/name/'%04d.png'),'-frames:v',str(count)]
    subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/(name+'.mp4'))],check=True)
    subprocess.run(command+['-filter_complex_threads','1','-filter_complex',
        '[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none',
        '-loop','-1' if name=='Goblin_Attack' else '0',str(out/(name+'.gif'))],check=True)
    manifest[name]={'frames':count,'fps':24,'loop':name!='Goblin_Attack','mp4':name+'.mp4','gif':name+'.gif'}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
