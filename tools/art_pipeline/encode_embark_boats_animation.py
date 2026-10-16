"""Encode the actual Blender animation frames to MP4 and looping GIFs."""
import json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/embark_boats_review'
out=WORK/'animations'; out.mkdir(exist_ok=True)
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
manifest={}
for clip,count in [('idle',96),('walk',48)]:
    folder=WORK/'animation_frames'/clip
    assert len(list(folder.glob('*.png')))==count
    command=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','24','-start_number','1','-i',str(folder/'%04d.png'),'-frames:v',str(count)]
    subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/(clip+'.mp4'))],check=True)
    subprocess.run(command+['-filter_complex_threads','1','-filter_complex','[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none','-loop','0',str(out/(clip+'.gif'))],check=True)
    manifest[clip]=dict(frames=count,fps=24,duration=count/24,mp4=clip+'.mp4',gif=clip+'.gif',water_plane_static=True)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest))
