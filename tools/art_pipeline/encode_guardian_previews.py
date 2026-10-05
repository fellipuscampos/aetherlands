"""Encode the Guardian V1 animation PNG sequences to MP4/GIF previews (local Python)."""
import json
import shutil
import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
source=root/'art_source/guardian_v1/animation_frames'
out=root/'assets/generated/humans/guardian_v1/previews/animations'; out.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
manifest={}
for name,count,loop in [('Guardian_Idle',72,True),('Guardian_Walk',28,True),('Guardian_Attack',31,False),('Guardian_ShieldWall',25,False),('Guardian_ShieldWallHold',48,True)]:
    assert len(list((source/name).glob('*.png')))==count
    cmd=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','24','-start_number','1','-i',str(source/name/'%04d.png'),'-frames:v',str(count)]
    subprocess.run(cmd+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/(name+'.mp4'))],check=True)
    subprocess.run(cmd+['-filter_complex_threads','1','-filter_complex','[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none',
                       '-loop','0' if loop else '-1',str(out/(name+'.gif'))],check=True)
    manifest[name]={'frames':count,'fps':24,'mp4':name+'.mp4','gif':name+'.gif'}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8'); print(json.dumps(manifest,indent=2))
