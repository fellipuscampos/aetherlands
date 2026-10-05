"""Encode the Blender-rendered Basilisk sequences as MP4 and GIF review files.
Usage: python tools/art_pipeline/encode_basilisk_previews.py <frames_dir>
(frames_dir = the FRAMES_DIR given to basilisk_animation_previews.py)
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

root=Path(__file__).resolve().parents[2]
source=Path(sys.argv[1])
out=root/'assets/generated/basilisks/basilisk_blocky_v1/previews/animations'
out.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
manifest={}
# Loops omit their last frame (identical to the first) so the video seam is clean.
for name,count in [('Basilisk_Idle',48),('Basilisk_Walk',28),('Basilisk_Attack',33)]:
    assert len(list((source/name).glob('*.png')))==count,(name,count)
    command=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','24','-start_number','1',
             '-i',str(source/name/'%04d.png'),'-frames:v',str(count)]
    subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/(name+'.mp4'))],check=True)
    subprocess.run(command+['-filter_complex_threads','1','-filter_complex',
        '[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none',
        '-loop','-1' if name=='Basilisk_Attack' else '0',str(out/(name+'.gif'))],check=True)
    manifest[name]={'frames':count,'fps':24,'loop':name!='Basilisk_Attack','mp4':name+'.mp4','gif':name+'.gif'}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
