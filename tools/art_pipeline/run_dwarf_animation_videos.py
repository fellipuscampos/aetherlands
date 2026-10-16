"""MP4 previews of each actual dwarf variant, rendered by the live Blender MCP."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

from blender_mcp_client import execute
from dwarf_troop_assets import ASSETS, ROOT, OUT, WORK

parser = argparse.ArgumentParser()
parser.add_argument('--units', nargs='*')
parser.add_argument('--families', nargs='*')
parser.add_argument('--assemble-only', action='store_true')
args = parser.parse_args()
rows = [r for r in ASSETS if (not args.units or r['stem'] in args.units)
        and (not args.families or r['family'] in args.families)]
ffmpeg = shutil.which('ffmpeg')
ffprobe = shutil.which('ffprobe')
assert ffmpeg and ffprobe, 'ffmpeg and ffprobe must be installed.'
source = ROOT/'tools/art_pipeline/render_dwarf_animation_previews.py'
fps = None
results = []
state = None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode_video(row, clip, info):
    label = row['family'] if row['tier'] == 2 else row['family']+'_tier'+str(row['tier'])
    frames = WORK/'animation_frames'/label/clip
    frame_count = info['frames']-1
    assert all((frames/f'{f:04d}.png').exists() for f in range(1, frame_count+1)), (row['stem'], clip, 'Missing native frames')
    # Replay the cycle in the preview only. Authored attack resources remain
    # one-shot; these videos are long enough to review with a normal player.
    repetitions = 2 if clip == 'idle' else 4 if clip == 'walk' else 3
    concat = frames/'video_sequence.txt'
    lines = []
    for _ in range(repetitions):
        for frame in range(1, frame_count+1):
            lines.append(f"file '{frame:04d}.png'\noption framerate {fps}\nduration {1/fps:.9f}")
    concat.write_text('\n'.join(lines)+'\n', encoding='utf-8')
    folder = OUT/row['stem']/'previews'
    folder.mkdir(exist_ok=True)
    path = folder/(clip+'.mp4')
    temporary = folder/(clip+'.encoding.mp4')
    command = [ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat',
        '-safe', '0', '-i', str(concat), '-an', '-r', str(fps), '-c:v', 'libx264',
        '-preset', 'fast', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
        str(temporary)]
    done = subprocess.run(command, capture_output=True, text=True, timeout=120)
    assert done.returncode == 0, done.stderr
    temporary.replace(path)
    probe = subprocess.run([ffprobe, '-v', 'error', '-show_streams', '-show_format',
        '-of', 'json', str(path)], capture_output=True, text=True, timeout=30)
    assert probe.returncode == 0, probe.stderr
    doc = json.loads(probe.stdout)
    video = next(s for s in doc['streams'] if s['codec_type'] == 'video')
    expected = frame_count*repetitions
    assert video['codec_name'] == 'h264' and video['pix_fmt'] == 'yuv420p'
    assert video['width'] == video['height'] == 560
    assert video['avg_frame_rate'] == f'{fps}/1' and int(video['nb_frames']) == expected
    duration = float(doc['format']['duration'])
    assert abs(duration-expected/fps) < .05
    # Decode the entire stream to detect truncated/corrupt packets as well as
    # checking its metadata. Windows video players can open H.264/yuv420p MP4.
    decode = subprocess.run([ffmpeg, '-v', 'error', '-xerror', '-i', str(path),
        '-f', 'null', '-'], capture_output=True, text=True, timeout=60)
    assert decode.returncode == 0, decode.stderr
    return dict(file=path.name, fps=fps, codec='h264', pixel_format='yuv420p',
        width=560, height=560, frames=expected, duration_s=duration,
        preview_repetitions=repetitions, source_clip_frames=info['frames'],
        bytes=path.stat().st_size, sha256=sha(path), fully_decoded=True)


try:
    if not args.assemble_only:
        response = execute('''import bpy
scene=bpy.context.window.scene
playing=bpy.context.screen.is_animation_playing
result={'scene':scene.name,'frame':scene.frame_current,'playing':playing}
if playing: bpy.ops.screen.animation_play()
''')
        state = response['result']
    for row in rows:
        stem = row['stem']; folder = OUT/stem
        protected = {name: sha(folder/name) for name in
            (stem+'.glb', stem+'.blend', stem+'_albedo.png')}
        manifest = json.loads((OUT/'animations'/(row['family']+'_manifest.json')).read_text(encoding='utf-8'))
        fps = manifest['fps']
        if not args.assemble_only:
            execute(f'''import sys
from pathlib import Path
source=Path({str(source)!r}); sys.path.insert(0,str(source.parent))
ns={{'__file__':str(source)}}
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),ns)
ns['render_family']({row['family']!r},tier={row['tier']!r},frame_step=1)
result={{'stem':{stem!r},'fps':{fps},'rendered':'all three clips'}}
''')
        clips = {clip: encode_video(row, clip, info) for clip, info in manifest['clips'].items()}
        assert all(sha(folder/name) == digest for name, digest in protected.items())
        result = dict(stem=stem, family=row['family'], tier=row['tier'], status='PASS',
            actual_model_variant=True, models_and_textures_unchanged=True, clips=clips)
        (folder/'previews/animations_manifest.json').write_text(json.dumps(result,
            ensure_ascii=False, indent=2), encoding='utf-8')
        results.append(result)
        print('DWARF_MP4_DONE '+stem+' (idle, walk, attack)', flush=True)
finally:
    if state is not None:
        execute(f'''import bpy
scene=bpy.data.scenes.get({state['scene']!r})
if scene:
    bpy.context.window.scene=scene
    scene.frame_set({state['frame']!r})
if {state['playing']!r} and not bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
result={{'review_restored':bool(scene)}}
''')
updated = {row['stem']: row for row in results}
complete = []
for row in ASSETS:
    manifest_path = OUT/row['stem']/'previews/animations_manifest.json'
    if row['stem'] in updated:
        complete.append(updated[row['stem']])
    elif manifest_path.exists():
        previous = json.loads(manifest_path.read_text(encoding='utf-8'))
        assert previous['status'] == 'PASS'
        for clip, info in previous['clips'].items():
            assert info['fully_decoded'] and sha(manifest_path.parent/info['file']) == info['sha256']
        complete.append(previous)
report = dict(status='PASS', variants=len(complete), videos=len(complete)*3,
    updated_variants=len(results), updated_videos=len(results)*3,
    fps=fps, codec='h264', format='mp4', previews='individual model previews directories',
    actual_variants_rendered=True, assets=complete)
(ROOT/'docs/dwarf_troops_animation_video_validation.json').write_text(json.dumps(report,
    ensure_ascii=False, indent=2), encoding='utf-8')
print(f'DWARF_MP4_PASS: {len(results)*3} videos in {len(results)} model preview folders', flush=True)
