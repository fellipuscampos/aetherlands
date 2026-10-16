"""Encode the complete slow orbit and the in-place movement/attack reviews."""
import json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STEM='mana_devourer_blocky_v3'
SOURCE=ROOT/'art_source/mana_devourer_blocky_v3_review/native_frames'
OUT=ROOT/'assets/generated/mana_devourers'/STEM/'previews/animations'
OUT.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
manifest={}
for clip,count in [('Idle',96),('Walk',48),('Attack',19)]:
    assert len(list((SOURCE/clip).glob('*.png')))==count
    fps=12 if clip=='Attack' else 6
    name='ManaDevourer_'+clip
    cmd=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate',str(fps),'-start_number','1',
        '-i',str(SOURCE/clip/'%04d.png'),'-frames:v',str(count)]
    subprocess.run(cmd+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/(name+'.mp4'))],check=True)
    subprocess.run(cmd+['-filter_complex_threads','1','-filter_complex',
        '[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none',
        '-loop','0',str(OUT/(name+'.gif'))],check=True)
    manifest[name]={'frames':count,'preview_fps':fps,'mp4':name+'.mp4','gif':name+'.gif'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
