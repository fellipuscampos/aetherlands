"""Encode the requested slow core/orbit study captured from the native GLB."""
import json, shutil, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art_source/seraph_blocky_v4_review/native_frames'
OUT=ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4/previews/animations'
OUT.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
assert len(list(SOURCE.glob('*.png')))==144
cmd=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','6','-start_number','1',
     '-i',str(SOURCE/'%04d.png'),'-frames:v','144']
subprocess.run(cmd+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'Seraph_CoreOrbit.mp4')],check=True)
subprocess.run(cmd+['-filter_complex_threads','1','-filter_complex',
    '[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none',
    '-loop','0',str(OUT/'Seraph_CoreOrbit.gif')],check=True)
report={'clip':'Seraph_CoreOrbit','duration_s':24,'frames':144,'preview_fps':6,
        'renderer':'Native Godot GLB','loop':True,'mp4':'Seraph_CoreOrbit.mp4','gif':'Seraph_CoreOrbit.gif'}
(OUT/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
