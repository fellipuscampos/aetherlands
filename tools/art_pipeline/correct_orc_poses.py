"""Rebuild anatomy and poses in existing assets without touching their atlases."""
import bpy,json,sys,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo');sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import OUT,WORK
from build_elf_troops import BODY,reset_pose,export_glb
from build_orc_troops import load_scene,fit_part
from orc_anatomy_retarget import sample_clips,correction


def fix(row,views=('front','three_quarter','back','game_top'),pose_views=True):
    if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    frozen=WORK/'pose_correction/before_assets'
    base_path=frozen/'orc_squire_v1/orc_squire_v1.blend'
    base_scene=load_scene(base_path);base_rig=next(o for o in base_scene.objects if o.type=='ARMATURE')
    base_by={o['part']:o for o in base_scene.objects if o.type=='MESH' and o.get('part')}
    base_rest={b.name:b.matrix_local.copy() for b in base_rig.data.bones}
    scene=load_scene(frozen/row['stem']/(row['stem']+'.blend'));bpy.context.window.scene=scene
    scene.name=row['stem']+'_Anatomy_V2'
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None)
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts:obj.data=obj.data.copy()
    reset_pose(rig,scene);current_rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
    root.scale=(1,1,1);root.location=(0,0,0);rig.location=(0,0,0)
    if row['key']=='squire':source_scene=base_scene;source_rig=base_rig
    else:
        source_scene=load_scene(ROOT/'assets/generated/elves'/row['source_stem']/(row['source_stem']+'.blend'))
        source_rig=next(o for o in source_scene.objects if o.type=='ARMATURE')
    motion_path=base_path.with_suffix('.glb') if row['key']=='squire' else ROOT/'assets/generated/elves'/row['source_stem']/(row['source_stem']+'.glb')
    clips=sample_clips(source_scene,source_rig,motion_path)
    _,target,scale,retarget=correction(scene,rig,source_rig,clips,base_rig,base_by,row)
    for obj in parts:
        name=obj['part'];bone=obj['rig_bone']
        template=name in BODY or name.startswith(('ElfEar','Brow','Tusk')) or name=='Buckle'
        if template:
            original=base_by[name]
            assert len(obj.data.vertices)==len(original.data.vertices)
            for vertex,old_vertex in zip(obj.data.vertices,original.data.vertices):vertex.co=old_vertex.co
            obj['template_bone_length']=base_rig.data.bones[bone].length
            fit_part(obj,base_rest,target,rig,scale)
        else:
            transform=target[bone]@current_rest[bone].inverted()
            before=[v.co.copy() for v in obj.data.vertices]
            for vertex in obj.data.vertices:vertex.co=transform@vertex.co
            if row['family']=='cavalry' and name in ('Rein_l3','Rein_r3'):
                distances=[(p-current_rest['hand_l'].translation).length for p in before]
                far=sorted(range(len(before)),key=lambda i:distances[i],reverse=True)[:4]
                # Four horse-end vertices follow the neck; four holder-end
                # vertices follow the hand. Both endpoints stay attached.
                neck=obj.vertex_groups.get('horse_neck') or obj.vertex_groups.new(name='horse_neck')
                for index in far:
                    obj.data.vertices[index].co=target['horse_neck']@current_rest['horse_neck'].inverted()@before[index]
                    for group in list(obj.vertex_groups):group.remove([index])
                    neck.add([index],1.,'REPLACE')
        obj.data.update()
    by={o['part']:o for o in parts}
    if row['family']=='cavalry':
        height=(max(v.co.z for v in by['Head'].data.vertices)-target['thigh_l'].translation.z
            +rig.data.bones['thigh_l'].length+rig.data.bones['shin_l'].length
            +target['foot_l'].translation.z-min(v.co.z for v in by['Foot_l'].data.vertices))
    else:
        bottom=min(v.co.z for name in ('Foot_l','Foot_r') for v in by[name].data.vertices)
        height=max(v.co.z for v in by['Head'].data.vertices)-bottom
        rig.location.z=-bottom
    root.scale=(row['character_height_m']/height,)*3
    root['height_m']=row['character_height_m'];root['pose_revision']='anatomy_v2'
    bpy.context.view_layer.update()
    coords=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
    lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
    out=OUT/row['stem'];report_path=out/(row['stem']+'_report.json')
    report=json.loads((frozen/row['stem']/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
    atlas=out/(row['stem']+'_albedo.png');atlas_hash=hashlib.sha256(atlas.read_bytes()).hexdigest()
    assert atlas_hash==hashlib.sha256((frozen/row['stem']/(row['stem']+'_albedo.png')).read_bytes()).hexdigest()
    camera=scene.camera;scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
    camera.data.type='ORTHO';camera.data.ortho_scale=max(2.85,(hi[2]-lo[2])*1.2,hi[0]-lo[0]+.5)
    point=Vector([(a+b)/2 for a,b in zip(lo,hi)])
    tracks=list(rig.animation_data.nla_tracks)
    reset_pose(rig,scene);tracks[0].mute=False;scene.frame_set(round(tracks[0].strips[0].frame_start))
    for view in views:
        offset={'front':(0,-12,1.2),'three_quarter':(6,-12,5.6),'back':(-6,12,5),'game_top':(5,-7,11)}[view]
        camera.location=point+Vector(offset);camera.rotation_euler=(point-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(view+'.png'));bpy.ops.render.render(write_still=True)
    if pose_views:
        pose_dir=WORK/'pose_correction/after_poses';pose_dir.mkdir(exist_ok=True)
        for track in tracks[:3]:
            reset_pose(rig,scene);track.mute=False;strip=track.strips[0]
            scene.frame_set(round(strip.frame_start+(strip.frame_end-strip.frame_start)*.35))
            camera.location=point+Vector((3,-9,2.5));camera.rotation_euler=(point-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(pose_dir/(row['stem']+'_'+track.name+'.png'));bpy.ops.render.render(write_still=True)
    reset_pose(rig,scene)
    gltf=export_glb(row,scene,parts,rig,root,out)
    actual={a['name']:max(gltf['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in gltf['animations']}
    assert actual.keys()==report['clips'].keys()
    assert all(abs(actual[k]-report['clips'][k])<.00001 for k in actual)
    reset_pose(rig,scene)
    for track in tracks:track.mute=False;track.is_solo=False
    scene.frame_set(1)
    scene['description']='Orc anatomy V2: coherent chest/neck proportions, broad-arm targets, lowered relaxed fists, attached weapons and bow assembly. Original painted material atlas preserved.'
    bpy.data.libraries.write(str(out/(row['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    report['revision']='anatomy_v2';report['rig']['retarget']=retarget
    report['geometry'].update(bounds_min=lo,bounds_max=hi,dimensions=[b-a for a,b in zip(lo,hi)],
        root_scale=list(root.scale),standing_character_height_m=height*root.scale.z,grounding_offset_m=rig.location.z*root.scale.z)
    report['geometry']['body_part_uv_boxes']={name:[
        [min(by[name].data.uv_layers.active.data[i].uv.x for i in p.loop_indices),
         min(by[name].data.uv_layers.active.data[i].uv.y for i in p.loop_indices),
         max(by[name].data.uv_layers.active.data[i].uv.x for i in p.loop_indices),
         max(by[name].data.uv_layers.active.data[i].uv.y for i in p.loop_indices)]
        for p in by[name].data.polygons] for name in BODY}
    report['pose_source']=str((frozen/row['stem']/(row['stem']+'.blend')).relative_to(ROOT))
    report['anatomy_source']=str(base_path.relative_to(ROOT));report['anatomy_source_sha256']=hashlib.sha256(base_path.read_bytes()).hexdigest()
    report['texture']['unchanged_atlas_sha256']=atlas_hash
    report['clips']=actual
    report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    if source_scene!=base_scene:bpy.data.scenes.remove(source_scene)
    bpy.data.scenes.remove(base_scene)
    return dict(status='PASS',stem=row['stem'],scale=scale,arm_factors=retarget['arm_reach_factors'],head_clearance_lift=retarget['maximum_additional_head_clearance_lift'],clips=len(clips))
