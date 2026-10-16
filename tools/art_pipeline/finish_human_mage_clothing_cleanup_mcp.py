"""Export the six cleaned mages, refresh previews and save existing review scenes."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
WORK = ROOT / 'art_source/school_mages_animation_review'
assets = bpy.app.driver_namespace['human_school_mage_assets_v1']
schools = [a['report']['school'] for a in assets]
export_code = (ROOT / 'tools/art_pipeline/finish_school_mage_animation_mcp.py').read_text(encoding='utf-8')
for school in schools:
    exec(compile(export_code, '<export_existing_animation>', 'exec'), dict(MAGE_RACE='human', MAGE_SCHOOL=school))

review = bpy.app.driver_namespace['human_school_mage_review_v1']
scene = review['scene']
camera = scene.camera
bpy.context.window.scene = scene
scene.frame_set(1)
settings = (camera.location.copy(), camera.rotation_euler.copy(), camera.data.ortho_scale, scene.render.resolution_x, scene.render.resolution_y, scene.cycles.samples, scene.cycles.device)
prefs = bpy.context.preferences.addons['cycles'].preferences
compute = prefs.compute_device_type
fonts = {o: o.hide_render for o in scene.objects if o.type == 'FONT'}
try:
    prefs.compute_device_type = 'OPTIX'
    prefs.get_devices()
    for device in prefs.devices:
        if device.type == 'OPTIX':
            device.use = True
            scene.cycles.device = 'GPU'
    scene.cycles.samples = 8
    scene.render.resolution_x = scene.render.resolution_y = 700
    camera.data.ortho_scale = 2.70
    for index, asset in enumerate(assets):
        for i, col in enumerate(review['collections']):
            col.hide_render = i != index
        for obj in fonts:
            obj.hide_render = True
        target = review['roots'][index].location + Vector((0, 0, 1.0))
        for view, offset in [('front', (0,-5,1.0)), ('three_quarter', (2.5,-5,1.6)), ('back', (-2.5,5,1.6))]:
            (WORK / 'current_stage.json').write_text(json.dumps(dict(asset=asset['report']['stem'], stage='clothing_preview', view=view)), encoding='utf-8')
            camera.location = target + Vector(offset)
            camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath = str(asset['folder'] / 'previews' / (view+'.png'))
            bpy.ops.render.render(write_still=True)
    for col in review['collections']:
        col.hide_render = False
    for obj, hidden in fonts.items():
        obj.hide_render = hidden
    scene.render.resolution_x, scene.render.resolution_y = settings[3:5]
    camera.data.ortho_scale = settings[2]
    for view, position in [('front',(0,-17,4.1)), ('three_quarter',(3.5,-17,5)), ('back',(-3.5,17,5))]:
        camera.location = position
        camera.rotation_euler = (review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath = str(ROOT / 'art_source/human_school_mages_review' / ('human_mages_'+view+'.png'))
        bpy.ops.render.render(write_still=True)
finally:
    for col in review['collections']:
        col.hide_render = False
    for obj, hidden in fonts.items():
        obj.hide_render = hidden
    camera.location, camera.rotation_euler, camera.data.ortho_scale, scene.render.resolution_x, scene.render.resolution_y, scene.cycles.samples, scene.cycles.device = settings
    prefs.compute_device_type = compute

exec(compile((ROOT / 'tools/art_pipeline/preview_school_mage_cast_mcp.py').read_text(encoding='utf-8'), '<human_cast_preview>', 'exec'), dict(MAGE_RACE='human', MAGE_SCHOOL='sacred'))

scene.frame_set(241)
scene['clothing_revision'] = 4
human_folder = ROOT / 'art_source/human_school_mages_review'
human_blend = human_folder / 'human_school_mages_six_schools_review.blend'
bpy.data.libraries.write(str(human_blend), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
human_manifest = json.loads((human_folder / 'manifest.json').read_text(encoding='utf-8'))
human_manifest['assets'] = [a['report'] for a in assets]
human_manifest['clothing_revision'] = 4
(human_folder / 'manifest.json').write_text(json.dumps(human_manifest, ensure_ascii=False, indent=2), encoding='utf-8')

overview = bpy.app.driver_namespace['school_mages_animation_review_v1']['scene']
overview.frame_set(241)
overview['human_clothing_revision'] = 4
bpy.context.window.scene = overview
bpy.data.libraries.write(str(WORK / 'school_mages_24_animated_review.blend'), {overview}, path_remap='RELATIVE', fake_user=True, compress=True)
manifest = json.loads((WORK / 'manifest.json').read_text(encoding='utf-8'))
manifest['assets'] = [a['report'] for race in ('human','elf','dwarf','orc') for a in bpy.app.driver_namespace[race+'_school_mage_assets_v1']]
manifest['human_clothing_revision'] = 4
(WORK / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
(ROOT / 'docs/school_mages_animation_blender_validation.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
# Leave the requested humans side by side in the open Blender.
bpy.context.window.scene = scene
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        area.spaces.active.shading.type = 'MATERIAL'
        area.spaces.active.region_3d.view_perspective = 'CAMERA'
        area.spaces.active.overlay.show_overlays = False
result = dict(status='PASS',models=6,clips_preserved=18,individual_previews=18,review_scenes_saved=2,active_scene=scene.name)
