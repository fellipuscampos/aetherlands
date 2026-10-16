"""Preserve the isolated source and leave its loop playing in the open Blender."""
import bpy, json

asset = bpy.app.driver_namespace['dwarf_construction_v1']
scene = asset['scene']
report = asset['report']
assert report['status'] == 'PASS' and report['contacts']['status'] == 'PASS'
assert len(asset['parts']) == report['geometry']['editable_parts']
prior = json.loads((asset['work'] / 'session_before.json').read_text(encoding='utf-8'))
missing = [name for name in prior if name not in bpy.data.scenes]
assert not missing, missing
assert bpy.app.driver_namespace['human_construction_v1']['report']['revision'] == 6
assert bpy.app.driver_namespace['elf_construction_v1']['report']['revision'] == 3
assert bpy.app.driver_namespace['orc_construction_v1']['report']['revision'] == 1
for name in ['construction.gif', 'construction.mp4', 'hammer_detail.gif', 'hammer_detail.mp4', 'manifest.json']:
    assert (asset['work'] / name).is_file(), name
assert (asset['out'] / 'previews/hex_alignment.png').is_file()
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_cancel(restore_frame=False)
scene.frame_set(1)
scene.use_preview_range = True
scene.frame_preview_start = 1
scene.frame_preview_end = 180
for obj in scene.objects:
    obj.select_set(False)
outline = scene.objects.get('Dwarf_Construction_Map_Tile_Outline_Preview')
assert outline is not None and outline.get('preview_only')
outline.hide_render = True
outline.hide_set(True)
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.shading.type = 'MATERIAL'
        space.shading.use_scene_lights = True
        space.shading.use_scene_world = True
        space.region_3d.view_perspective = 'CAMERA'
        space.overlay.show_overlays = False
bpy.data.libraries.write(str(asset['out'] / (asset['out'].name + '.blend')), {scene}, fake_user=True, compress=True)
bpy.ops.screen.animation_play()
result = dict(status='PASS', original_scenes_preserved=len(prior), scene_count=len(bpy.data.scenes),
              human_revision=6, elf_revision=3, orc_revision=1, dwarf_revision=1,
              animation_playing=bpy.context.screen.is_animation_playing, isolated_source_saved=True)
(asset['work'] / 'session_validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
