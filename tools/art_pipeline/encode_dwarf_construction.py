"""Make a six-second review clip and GIF from the live Blender render frames."""
import subprocess,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/dwarf_construction_review'
frames=WORK/'animation_frames_final'; assert len(list(frames.glob('*.png')))==108
def run(args):
    subprocess.run(['ffmpeg','-y','-loglevel','error',*args],check=True,timeout=180)
run(['-framerate','18','-i',str(frames/'%04d.png'),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(WORK/'construction.mp4')])
run(['-framerate','18','-i',str(frames/'%04d.png'),'-filter_complex','[0:v]scale=640:640:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(WORK/'construction.gif')])
close_frames=WORK/'hammer_animation_frames'
if close_frames.exists():
    assert len(list(close_frames.glob('*.png')))==36
    run(['-framerate','18','-i',str(close_frames/'%04d.png'),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(WORK/'hammer_detail.mp4')])
    run(['-framerate','18','-i',str(close_frames/'%04d.png'),'-filter_complex','[0:v]scale=640:640:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(WORK/'hammer_detail.gif')])
    close_gif=Image.open(WORK/'hammer_detail.gif'); close_duration=0
    for i in range(close_gif.n_frames):
        close_gif.seek(i); close_duration+=close_gif.info.get('duration',0)
    assert close_gif.n_frames==36 and abs(close_duration/1000-2)<.03
gif=Image.open(WORK/'construction.gif'); duration=0
for i in range(gif.n_frames):
    gif.seek(i); duration+=gif.info.get('duration',0)
assert gif.n_frames==108 and abs(duration/1000-6)<.03
asset=ROOT/'assets/generated/dwarves/buildings/dwarf_construction_site_hex_v1'
report=json.loads((asset/(asset.name+'_report.json')).read_text(encoding='utf-8'))
manifest=dict(race='dwarf',revision=report['revision'],style=report['style'],workers=3,loop='construction',seconds=6,review_fps=18,gif_frames=gif.n_frames,gif_duration=duration/1000,
    original_dwarf_faces=report['dwarf_style']['original_face_pixels'],original_beard_parts=54,original_head_attachments=90,all_content_cuboids=report['geometry']['all_content_cuboids'],footprint_margin=report['geometry']['footprint_margin'],ground_plate=False,jobs=report['jobs'],building_materials=report['building_materials'],stable_elbow_planes=report['animation']['stable_elbow_planes'],
    forearm_lengths=report['dwarf_style'].get('forearm_lengths'),hammer_detail='hammer_detail.gif' if close_frames.exists() else None,
    scene='assets/generated/dwarves/buildings/dwarf_construction_site_hex_v1/dwarf_construction_site_hex_v1.tscn',
    review_scene='scenes/art_review/DwarfConstructionReview.tscn',automatic_gameplay_integration=True)
(WORK/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
