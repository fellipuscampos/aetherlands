"""Activate the equivalent human clips in the open Blender via its MCP.

GLBs already carry the original human animation samples. This repairs muted
editable files and builds a synchronized playback review without altering art.
"""
import hashlib
import json
import math
import shutil
import sys
from pathlib import Path

import bpy

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPE = ROOT / 'tools/art_pipeline'
if str(PIPE) not in sys.path:
    sys.path.insert(0, str(PIPE))
from elf_troop_assets import ASSETS, OUT, WORK


def append_scene(path):
    with bpy.data.libraries.load(str(path), link=False) as (source, loaded):
        assert len(source.scenes) == 1, str(path)
        loaded.scenes = source.scenes
    return loaded.scenes[0]


def activate(rig, scene, set_frame=True):
    rig.animation_data.action = None
    rig.animation_data.use_nla = True
    for track in rig.animation_data.nla_tracks:
        track.mute = False
        track.is_solo = False
    scene.frame_start = 1
    scene.frame_end = math.ceil(max(strip.frame_end for track in rig.animation_data.nla_tracks for strip in track.strips))
    scene.use_preview_range = False
    if set_frame:
        scene.frame_set(1)


def sample_pose(scene, rig, track, fraction):
    if bpy.context.scene != scene:
        bpy.context.window.scene = scene
    rig.animation_data.action = None
    rig.animation_data.use_nla = True
    for item in rig.animation_data.nla_tracks:
        item.mute = False
        item.is_solo = item == track
    strip = track.strips[0]
    frame = strip.frame_start + (strip.frame_end - strip.frame_start) * fraction
    scene.frame_set(math.floor(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    return {bone.name: tuple(value for matrix_row in bone.matrix for value in matrix_row) for bone in rig.pose.bones}


if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_cancel(restore_frame=False)
previous_scene = bpy.context.scene
backup = WORK / 'before_animation_activation'
backup.mkdir(parents=True, exist_ok=True)
verified = []

for row in ASSETS:
    path = OUT / row['stem'] / (row['stem'] + '.blend')
    backup_path = backup / path.name
    if not backup_path.exists():
        shutil.copy2(path, backup_path)
    source_path = ROOT / 'assets/generated/humans' / row['source_stem'] / (row['source_stem'] + '.blend')
    source_hash = hashlib.sha256(source_path.read_bytes()).hexdigest()
    human_scene = append_scene(source_path)
    elf_scene = append_scene(path)
    human_rig = next(o for o in human_scene.objects if o.type == 'ARMATURE')
    elf_rig = next(o for o in elf_scene.objects if o.type == 'ARMATURE')
    human_tracks = {track.name: track for track in human_rig.animation_data.nla_tracks}
    elf_tracks = {track.name: track for track in elf_rig.animation_data.nla_tracks}
    assert human_tracks.keys() == elf_tracks.keys(), row['stem']
    assert list(human_rig.data.bones.keys()) == list(elf_rig.data.bones.keys()), row['stem']
    max_error = 0.0
    movement = {}
    elf_scene.timeline_markers.clear()
    # Evaluate each scene in one batch. Switching the active Blender scene for
    # each individual sample unnecessarily rebuilds its dependency graph.
    fractions = (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)
    human_poses = {name: [sample_pose(human_scene, human_rig, track, fraction)
                          for fraction in fractions]
                   for name, track in human_tracks.items()}
    for name, human_track in human_tracks.items():
        elf_track = elf_tracks[name]
        assert len(human_track.strips) == len(elf_track.strips) == 1
        hs, es = human_track.strips[0], elf_track.strips[0]
        for property_name in ('frame_start', 'frame_end', 'action_frame_start', 'action_frame_end', 'scale', 'repeat', 'blend_type', 'extrapolation'):
            assert getattr(hs, property_name) == getattr(es, property_name), (row['stem'], name, property_name)
        poses = []
        for fraction, hp in zip(fractions, human_poses[name]):
            ep = sample_pose(elf_scene, elf_rig, elf_track, fraction)
            error = max(abs(a-b) for bone in hp for a,b in zip(hp[bone], ep[bone]))
            max_error = max(max_error, error)
            assert error < 0.00001, (row['stem'], name, fraction, error)
            poses.append(ep)
        movement[name] = max(abs(a-b) for pose in poses[1:] for bone in pose for a,b in zip(poses[0][bone], pose[bone]))
        if name.endswith(('_Walk', '_Attack')):
            assert movement[name] > 0.01, (name, 'animation not moving')
        elf_scene.timeline_markers.new(name, frame=round(es.frame_start))
    activate(elf_rig, elf_scene)
    elf_scene['human_animation_source'] = str(source_path.relative_to(ROOT))
    elf_scene['animation_clips_active'] = len(elf_tracks)
    bpy.data.libraries.write(str(path), {elf_scene}, path_remap='RELATIVE', fake_user=True, compress=True)
    # Validate the actual saved file, rather than only its in-memory predecessor.
    saved = append_scene(path)
    saved_rig = next(o for o in saved.objects if o.type == 'ARMATURE')
    assert saved_rig.animation_data.use_nla
    assert saved_rig.animation_data.action is None
    assert all(not track.mute and not track.is_solo for track in saved_rig.animation_data.nla_tracks)
    assert {track.name for track in saved_rig.animation_data.nla_tracks} == human_tracks.keys()
    bpy.context.window.scene = previous_scene
    bpy.data.scenes.remove(saved)
    bpy.data.scenes.remove(human_scene)
    bpy.data.scenes.remove(elf_scene)
    assert hashlib.sha256(source_path.read_bytes()).hexdigest() == source_hash
    verified.append(dict(stem=row['stem'], clips=list(elf_tracks), clip_count=len(elf_tracks),
                         samples_per_clip=6, maximum_bone_matrix_error=max_error,
                         movement=movement, saved_nla_enabled=True, all_saved_tracks_enabled=True))
    print('ELF_ANIMATIONS_ACTIVE', row['stem'], len(elf_tracks), max_error, flush=True)

# The review has its own NLA strip timing; individual editable files above retain
# the human timelines exactly. Only review playback is synchronized across rows.
review_path = OUT / 'elf_troops_review.blend'
if not (backup / review_path.name).exists():
    shutil.copy2(review_path, backup / review_path.name)
review = append_scene(review_path)
review.name = 'Elf_Troops_Animated_20_Model_Review'
bpy.context.window.scene = review
review.timeline_markers.clear()
segments = [('Idle', 1, 1), ('Walk', 91, 3), ('Attack', 201, 3)]
for role, start, repeat in segments:
    review.timeline_markers.new(role, frame=start)
max_end = 1
rig_count = 0
for rig in (o for o in review.objects if o.type == 'ARMATURE'):
    activate(rig, review, set_frame=False)
    specials = 0
    for track in rig.animation_data.nla_tracks:
        strip = track.strips[0]
        role = track.name.rsplit('_', 1)[-1]
        if role in ('Idle', 'Walk', 'Attack'):
            _, start, repeat = next(segment for segment in segments if segment[0] == role)
        else:
            start, repeat = 331 + specials * 180, 1
            specials += 1
            if not review.timeline_markers.get('Technique ' + str(specials)):
                review.timeline_markers.new('Technique ' + str(specials), frame=start)
        strip.frame_start = start
        strip.repeat = repeat
        strip.extrapolation = 'NOTHING'
        max_end = max(max_end, math.ceil(strip.frame_end))
    rig_count += 1
assert rig_count == len(ASSETS)
review.frame_start = 1
review.frame_end = max_end
review.use_preview_range = True
review.frame_preview_start = 91
review.frame_preview_end = 118
review.frame_set(91)
review['description'] = '20 elves with the exact animation clips of their equivalent humans. Preview: Walk. Timeline markers: Idle, Walk, Attack, class techniques.'
review['animation_preview_instructions'] = 'Space: play/pause. Disable Preview Range to play all clips. Markers: Idle 1, Walk 91, Attack 201, techniques 331 and later.'
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        area.spaces.active.region_3d.view_perspective = 'CAMERA'
        area.spaces.active.shading.type = 'MATERIAL'
bpy.data.libraries.write(str(review_path), {review}, path_remap='RELATIVE', fake_user=True, compress=True)
output = dict(status='PASS', pipeline='Open Blender MCP localhost:9876', verified=len(verified),
              clips_verified=sum(item['clip_count'] for item in verified), samples_per_clip=6,
              assets=verified, review=dict(path=str(review_path.relative_to(ROOT)), models=rig_count,
              segments=segments, preview_range=[91,118], timeline_end=max_end))
(ROOT / 'docs/elf_troops_animation_blender_validation.json').write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
result = dict(status=output['status'], models=len(verified), clips=output['clips_verified'], scene=review.name,
              maximum_bone_matrix_error=max(item['maximum_bone_matrix_error'] for item in verified))
bpy.ops.screen.animation_play()
