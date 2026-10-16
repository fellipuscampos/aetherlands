"""Save the four racial review scenes and a 24-mage animated overview."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/school_mages_animation_review'
rows=[]; race_reviews=[]
for race in ('human','elf','dwarf','orc'):
    assets=bpy.app.driver_namespace[race+'_school_mage_assets_v1']; review=bpy.app.driver_namespace[race+'_school_mage_review_v1']; scene=review['scene']
    assert len(assets)==6 and all(a['report'].get('animation',{}).get('status')=='PASS' for a in assets)
    assert all(a['report']['animations']==3 and a.get('review_rig') for a in assets)
    bpy.context.window.scene=scene; scene.render.fps=48; scene.frame_start=1; scene.frame_end=385
    scene.timeline_markers.clear()
    for clip,start in [('IDLE',1),('WALK',161),('SPELL',241)]: scene.timeline_markers.new(clip,frame=start)
    scene.use_preview_range=True; scene.frame_preview_start=241; scene.frame_preview_end=385; scene.frame_set(241)
    scene['animation_clips']=['idle','walk','spell']; scene['description']='Seis magos animados. IDLE 1–145; WALK 161–233; SPELL 241–385. Casting comum às escolas desta civilização.'
    original=ROOT/'art_source'/(race+'_school_mages_review'); path=original/(race+'_school_mages_six_schools_review.blend')
    bpy.data.libraries.write(str(path),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    output=dict(status='PASS',models=6,pipeline='Live Blender MCP localhost:9876',animations=3,rigging_deferred=False,review_blend=path.relative_to(ROOT).as_posix(),assets=[a['report'] for a in assets])
    (original/'manifest.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    rows.extend(a['report'] for a in assets); race_reviews.append(dict(race=race,blend=path.relative_to(ROOT).as_posix()))

name='School_Mages_24_Animation_Review'; scene=bpy.data.scenes.get(name)
if scene is None:
    scene=bpy.data.scenes.new(name); scene.unit_settings.system='METRIC'; scene.render.fps=48
    scene.frame_start=1; scene.frame_end=385; scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
    scene.render.resolution_x=2400; scene.render.resolution_y=1400; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    source_review=bpy.app.driver_namespace['human_school_mage_review_v1']; scene.world=source_review['scene'].world
    roots=[]
    for ri,race in enumerate(('human','elf','dwarf','orc')):
        assets=bpy.app.driver_namespace[race+'_school_mage_assets_v1']
        for index,a in enumerate(assets):
            col=bpy.data.collections.new(a['report']['name']+'_Animated'); scene.collection.children.link(col); mapping={}
            for original in [a['root'],a['rig']]+a['parts']:
                obj=original.copy(); col.objects.link(obj); mapping[original]=obj
                if obj.type=='ARMATURE': obj.data=original.data.copy()
            for original,obj in mapping.items():
                if original.parent in mapping: obj.parent=mapping[original.parent]
                for modifier in obj.modifiers:
                    if modifier.type=='ARMATURE': modifier.object=mapping[a['rig']]
            root=mapping[a['root']]; root.location=((index-2.5)*2.0,(ri-1.5)*3.0,0); roots.append(root)
    studio=bpy.data.collections.new(name+'_Studio'); scene.collection.children.link(studio)
    for original in source_review['studio'].objects:
        if original.type not in ('LIGHT','MESH'): continue
        obj=original.copy(); studio.objects.link(obj)
    data=bpy.data.cameras.new(name+'_Camera'); data.type='ORTHO'; data.ortho_scale=17.5
    camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera); scene.camera=camera
    camera.location=(4,-23,19); target=Vector((0,0,.95)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.app.driver_namespace['school_mages_animation_review_v1']=dict(scene=scene,roots=roots)
else:
    # Review rigs are copies: explicitly replace their old animation tracks
    # after a revision rather than saving the previous choreography again.
    for race in ('human','elf','dwarf','orc'):
        for asset in bpy.app.driver_namespace[race+'_school_mage_assets_v1']:
            source=asset['rig']; stem=asset['report']['stem']
            copies=[o for o in scene.objects if o.type=='ARMATURE' and o.get('mage_animation_asset')==stem]
            assert len(copies)==1,(stem,'overview rig ownership')
            target=copies[0]; target.animation_data_clear(); target.animation_data_create()
            for track in source.animation_data.nla_tracks:
                new=target.animation_data.nla_tracks.new(); new.name=track.name
                for strip in track.strips:
                    copy=new.strips.new(strip.name,int(strip.frame_start),strip.action)
                    copy.action_slot=strip.action_slot; copy.extrapolation='NOTHING'; copy.blend_type='REPLACE'
            target['choreography_revision']=source['choreography_revision']
bpy.context.window.scene=scene
scene.timeline_markers.clear()
for label,frame in [('IDLE',1),('WALK',161),('SPELL',241)]: scene.timeline_markers.new(label,frame=frame)
scene.use_preview_range=True; scene.frame_preview_start=241; scene.frame_preview_end=385; scene.frame_set(241)
scene['animation_clips']=['idle','walk','spell']; scene['description']='24 magos, seis escolas por raça. Humanos e elfos usam gestos próximos e distintos; anões e orcs usam casting próprio. IDLE 1–145; WALK 161–233; SPELL 241–385.'
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D': area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.overlay.show_overlays=False
path=WORK/'school_mages_24_animated_review.blend'
bpy.data.libraries.write(str(path),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
output=dict(status='PASS',models=24,clips=72,fps=48,pipeline='Live Blender MCP localhost:9876',review_blend=path.relative_to(ROOT).as_posix(),race_reviews=race_reviews,assets=rows)
(WORK/'manifest.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'docs/school_mages_animation_blender_validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
result=dict(status='PASS',models=24,clips=72,race_reviews=4,active_scene=scene.name)
