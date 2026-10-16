"""Save both Blender playback ranges and the canonical four-settler review."""
import bpy,json,hashlib
from pathlib import Path

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/settlers_review'
assets=bpy.app.driver_namespace['settlers_v1_assets']; review=bpy.app.driver_namespace['settlers_v1_review']; scene=review['scene']
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
source_checks=[]
for asset in assets:
    assert hashlib.sha256((ROOT/asset['report']['source']).read_bytes()).hexdigest()==asset['report']['source_sha256']
    with bpy.data.libraries.load(str(asset['folder']/(asset['root'].name+'.blend')),link=False) as (src,dst):
        assert len(src.scenes)==1 and len(src.armatures)==1 and len(src.actions)==2
        source_checks.append(dict(file=asset['root'].name+'.blend',scenes=1,armatures=1,actions=2,images=len(src.images)))
    asset['report']['stage']='animated_review'
    (asset['folder']/(asset['root'].name+'_report.json')).write_text(json.dumps(asset['report'],ensure_ascii=False,indent=2),encoding='utf-8')
scene.use_preview_range=True; scene.frame_preview_start=1; scene.frame_preview_end=145; scene.frame_set(1)
bpy.data.libraries.write(str(WORK/'settlers_idle_review.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
scene.frame_preview_start=161; scene.frame_preview_end=233; scene.frame_set(161)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D': area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.overlay.show_overlays=False
bpy.ops.object.select_all(action='DESELECT'); rig=assets[0]['review_rig']; rig.select_set(True); bpy.context.view_layer.objects.active=rig
for filename in ('settlers_walk_review.blend','settlers_four_civilizations_review.blend'):
    bpy.data.libraries.write(str(WORK/filename),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    with bpy.data.libraries.load(str(WORK/filename),link=False) as (src,dst): assert len(src.scenes)==1 and len(src.armatures)==4 and len(src.actions)==8
report=dict(status='PASS',verified=4,pipeline='Live Blender MCP localhost:9876',animations=8,clips_per_model=2,rigging_deferred=False,exposed_coplanar_pairs=0,review_scene=scene.name,review_blend='art_source/settlers_review/settlers_four_civilizations_review.blend',assets=[a['report'] for a in assets])
(ROOT/'docs/settlers_blender_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(WORK/'modeling_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'docs/settlers_source_file_validation.json').write_text(json.dumps(dict(status='PASS',files=source_checks,review_rigs=4,review_actions=8,active_scene=scene.name,left_to_right=['human','elf','dwarf','orc'],preview='walk',range=[161,233]),indent=2),encoding='utf-8')
result={'status':'PASS','models':4,'clips':8,'review_files':3,'default_preview':'walk'}
