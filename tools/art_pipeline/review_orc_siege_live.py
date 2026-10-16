"""Compose the four animated machines in the user's open Blender through MCP."""
import json
import hashlib
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / 'tools/art_pipeline') not in sys.path: sys.path.insert(0, str(ROOT / 'tools/art_pipeline'))
from orc_siege_assets import OUT, SIEGE_ASSETS

if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_cancel(restore_frame=False)
actions_before = set(bpy.data.actions)
scene = bpy.data.scenes.new('Orc_Siege_Four_Evolutions_Animated_Review')
bpy.context.window.scene = scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1700; scene.render.resolution_y = 680
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'
scene.world = bpy.data.worlds.new('OrcSiegeReviewWorld'); scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.18, .20, .17, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .65
roots = []; rigs = []
labelmat = bpy.data.materials.new('OrcSiegeReviewLabelMaterial'); labelmat.use_nodes = True
labelmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.80, .76, .60, 1)
for row in SIEGE_ASSETS:
    report = json.loads((OUT / row['stem'] / (row['stem'] + '_report.json')).read_text(encoding='utf-8'))
    original_scene = None
    # Reuse a matching source already in the open Blender. Check the actual
    # atlas bytes and geometry bounds, so an earlier revision cannot be shown.
    for candidate in bpy.data.scenes:
        if not candidate.name.startswith(row['stem'] + '_Scene'): continue
        parts = [obj for obj in candidate.objects if obj.get('part')]
        if {obj['part']: obj['rig_bone'] for obj in parts} != report['rig']['part_bones']: continue
        candidate_rigs = [obj for obj in candidate.objects if obj.type == 'ARMATURE']
        if len(candidate_rigs) != 1 or not candidate_rigs[0].animation_data: continue
        if {track.name for track in candidate_rigs[0].animation_data.nla_tracks} != set(report['clips']): continue
        images = {node.image for obj in parts for mat in obj.data.materials
                  for node in mat.node_tree.nodes if node.type == 'TEX_IMAGE'}
        if len(images) != 1: continue
        atlas = next(iter(images))
        if not atlas.packed_file or hashlib.sha256(atlas.packed_file.data).hexdigest() != report['texture']['sha256']: continue
        points = [obj.matrix_world @ v.co for obj in parts for v in obj.data.vertices]
        low = [min(p[i] for p in points) for i in range(3)]
        high = [max(p[i] for p in points) for i in range(3)]
        if max(abs(a - b) for a, b in zip(low + high, report['geometry']['bounds_min'] + report['geometry']['bounds_max'])) > .00001: continue
        original_scene = candidate
        break
    loaded_for_review = original_scene is None
    if loaded_for_review:
        with bpy.data.libraries.load(str(OUT / row['stem'] / (row['stem'] + '.blend')), link=False) as (source, loaded):
            loaded.scenes = source.scenes
        original_scene = loaded.scenes[0]
    collection = bpy.data.collections.new(row['stem'] + '_Review'); scene.collection.children.link(collection)
    objects = [o for o in original_scene.objects if o.type in ('EMPTY', 'ARMATURE') or o.get('part')]
    mapping = {}
    for original in objects:
        copy = original.copy()
        if original.type == 'ARMATURE': copy.data = original.data.copy()
        collection.objects.link(copy); mapping[original] = copy
    for original, copy in mapping.items():
        if original.parent in mapping: copy.parent = mapping[original.parent]
        for modifier in copy.modifiers:
            if modifier.type == 'ARMATURE' and modifier.object in mapping:
                modifier.object = mapping[modifier.object]
        assert copy.animation_data is None if copy.type != 'ARMATURE' else len(copy.animation_data.nla_tracks) == len(report['clips'])
        if copy.type == 'ARMATURE': rigs.append(copy)
    root = next(o for o in mapping.values() if o.type == 'EMPTY' and o.parent is None)
    root.location = ((row['tier'] - 1.5) * 3.2, 0, 0); roots.append(root)
    curve = bpy.data.curves.new(row['stem'] + '_Label', 'FONT')
    curve.body = row['name']; curve.align_x = 'CENTER'; curve.size = .17
    curve.materials.append(labelmat)
    label = bpy.data.objects.new(row['stem'] + '_Label', curve); collection.objects.link(label)
    label.location = (root.location.x, -1.65, .06); label.rotation_euler = (math.pi / 2, 0, 0)
    if loaded_for_review: bpy.data.scenes.remove(original_scene)
ground_data = bpy.data.meshes.new('OrcSiegeReviewGround')
ground_data.from_pydata([(-20, -20, -.01), (20, -20, -.01), (20, 20, -.01), (-20, 20, -.01)], [], [(0, 1, 2, 3)])
ground = bpy.data.objects.new(ground_data.name, ground_data); scene.collection.objects.link(ground)
material = bpy.data.materials.new('OrcSiegeReviewGroundMaterial'); material.use_nodes = True
material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.12, .14, .12, 1)
material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 1
ground.data.materials.append(material)
for name, at, power, size in [('Key', (-5, -6, 10), 2700, 10), ('Fill', (7, -2, 8), 1700, 8), ('Rim', (0, 6, 9), 2300, 8)]:
    data = bpy.data.lights.new('OrcSiegeReview_' + name, 'AREA')
    data.energy = power; data.shape = 'DISK'; data.size = size
    obj = bpy.data.objects.new(data.name, data); scene.collection.objects.link(obj); obj.location = at
    obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat('-Z', 'Y').to_euler()
data = bpy.data.cameras.new('OrcSiegeReviewCamera'); data.type = 'ORTHO'; data.ortho_scale = 14.2
camera = bpy.data.objects.new(data.name, data); scene.collection.objects.link(camera); scene.camera = camera
camera.location = (5, -18, 11)
camera.rotation_euler = (Vector((0, 0, .85)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.fps = 24
scene.frame_start = 1; scene.frame_end = int(max(strip.frame_end for rig in rigs for track in rig.animation_data.nla_tracks for strip in track.strips)); scene.frame_set(1)
for row in SIEGE_ASSETS:
    report = json.loads((OUT / row['stem'] / (row['stem'] + '_report.json')).read_text(encoding='utf-8'))
    for name, clip in report['clip_metadata'].items():
        scene.timeline_markers.new(name, frame=clip['start'])
scene['description'] = 'Four animated orc siege machines: square-shot mangonel and trebuchet, iron bombard and a six-wheel twin heavy bombard. Orc horns, no skull emblem or bone plates. 19 authored clips.'
scene['preview_instructions'] = 'Play the timeline: Idle 1, Walk 58, Attack 115, DemolitionAmmo 172, PreparedBombardment 253. Each machine has rigid NLA clips and fire markers.'
preview = ROOT / 'docs/previews/orc_siege'; preview.mkdir(parents=True, exist_ok=True)
scene.render.filepath = str(preview / 'blender_review.png'); bpy.ops.render.render(write_still=True)
path = OUT / 'orc_siege_review.blend'
bpy.data.libraries.write(str(path), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
bpy.ops.object.select_all(action='DESELECT')
roots[-1].select_set(True); bpy.context.view_layer.objects.active = roots[-1]
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        area.spaces.active.region_3d.view_perspective = 'CAMERA'
        area.spaces.active.shading.type = 'MATERIAL'
        area.spaces.active.overlay.show_overlays = False
assert actions_before.issubset(set(bpy.data.actions))
assert len(rigs) == 4
report = dict(status='PASS', models=4, clips=19, animated=True,
              saved=path.relative_to(ROOT).as_posix(), scene=scene.name)
(ROOT / 'docs/orc_siege_blender_review_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
result = report
