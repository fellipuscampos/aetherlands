"""Replace the five revised actors in the open review and verify all 20."""
import sys,json,re,hashlib,numpy as np,bpy
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
from orc_troop_assets import ROOT,OUT,ASSETS
from build_elf_troops import BODY
from build_orc_squire import cuboid_axes
from build_orc_closed_bone_armor import KEYS as BONE_KEYS
from build_orc_horns_hoods import KEYS as FINISH_KEYS
from build_orc_open_skull import KEYS as OPEN_SKULL_KEYS
from build_orc_war_boars import KEYS as BOAR_KEYS

KEYS=FINISH_KEYS if any(json.loads((OUT/r['stem']/(r['stem']+'_report.json')).read_text(encoding='utf-8')).get('finishing_revision') for r in ASSETS) else BONE_KEYS
if any(json.loads((OUT/r['stem']/(r['stem']+'_report.json')).read_text(encoding='utf-8')).get('open_skull_revision') for r in ASSETS):KEYS=OPEN_SKULL_KEYS
if any(json.loads((OUT/r['stem']/(r['stem']+'_report.json')).read_text(encoding='utf-8')).get('mount_revision') for r in ASSETS):KEYS=BOAR_KEYS

def cached_source(row,report):
    """Reuse only this pass's saved actors with matching atlas and geometry."""
    if report.get('mount_revision') in ('war_boar_v1','war_bull_v1','war_bull_v2','war_bull_v3'):
        c=report['mount_refinement'];expected={n:i['vertices'] for n,i in c['new_parts'].items()}
        expected.update(c['reshaped_target_vertices'])
        for s in reversed(list(bpy.data.scenes)):
            if s.get('asset_revision')!=report['mount_revision'] or s.get('asset_stem')!=row['stem']:continue
            if report['mount_revision']=='war_bull_v3' and s.get('mount_motion_signature')!=c.get('motion_signature'):continue
            by={o['part']:o for o in s.objects if o.type=='MESH' and o.get('part')}
            if any(n.startswith('Horse') for n in by):continue
            if report['mount_revision'].startswith('war_bull_') and any(n.startswith('Boar') for n in by):continue
            if any(n not in by or not np.allclose(np.array([tuple(v.co) for v in by[n].data.vertices]),v,atol=1e-6,rtol=0) for n,v in expected.items()):continue
            image=next(n.image for n in by['Head'].data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
            if image.packed_file and hashlib.sha256(bytes(image.packed_file.data)).hexdigest()==report['texture']['albedo_sha256']:return s
        return None
    if report.get('open_skull_revision')!='jawless_skull_v1':return None
    c=report['open_skull_refinement'];head=np.array(c['source_part_vertices']['Head'])
    axes=np.stack((head[1]-head[0],head[2]-head[0],head[4]-head[0]),axis=1)
    size=np.linalg.norm(axes,axis=0);axes/=size;u,_,vt=np.linalg.svd(axes);axes=u@vt
    png_hash=report['texture']['albedo_sha256']
    for s in reversed(list(bpy.data.scenes)):
        if s.get('asset_revision')!='jawless_skull_v1' or s.get('asset_stem')!=row['stem']:continue
        by={o['part']:o for o in s.objects if o.type=='MESH' and o.get('part')}
        if any(n in by for n in ('Brow_l','Brow_r')):continue
        valid=True
        for name in c['reshaped_parts']:
            if name not in by:valid=False;break
            delta=axes@np.array(c['horn_translation_head_local']) if 'Horn' in name else axes[:,2]*size[2]*.14
            expected=np.array(c['source_part_vertices'][name])+delta
            if not np.allclose(np.array([tuple(v.co) for v in by[name].data.vertices]),expected,atol=1e-6,rtol=0):valid=False;break
        if not valid:continue
        material=by['Head'].data.materials[0]
        image=next(n.image for n in material.node_tree.nodes if n.type=='TEX_IMAGE')
        if image.packed_file and hashlib.sha256(bytes(image.packed_file.data)).hexdigest()==png_hash:return s
    return None

reviews=[s for s in bpy.data.scenes if s.name.startswith('Orc_Troops_20_Review') and sum(o.type=='ARMATURE' for o in s.objects)==20]
assert reviews,'The existing approved 20-actor review must be open.'
review=max(reviews,key=lambda s:int(s.name.rsplit('.',1)[-1]) if '.' in s.name else 0)
bpy.context.window.scene=review
for row in ASSETS:
    if row['key'] not in KEYS:continue
    old_root=next(o for o in review.objects if o.type=='EMPTY' and o.parent is None and o.get('family')==row['family'] and o.get('tier')==row['tier'])
    location=old_root.location.copy()
    def belongs(obj):
        while obj is not None:
            if obj==old_root:return True
            obj=obj.parent
        return False
    old_objects=[o for o in review.objects if belongs(o)]
    asset_report=json.loads((OUT/row['stem']/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
    source=cached_source(row,asset_report)
    if source is None:
        with bpy.data.libraries.load(str(OUT/row['stem']/(row['stem']+'.blend')),link=False) as (src,dst):dst.scenes=src.scenes
        source=dst.scenes[0]
    root=next(o for o in source.objects if o.type=='EMPTY' and o.parent is None)
    rig=next(o for o in source.objects if o.type=='ARMATURE')
    parts=[o for o in source.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in old_objects:
        for collection in tuple(obj.users_collection):
            if collection==review.collection:collection.objects.unlink(obj)
    for obj in [root,rig]+parts:review.collection.objects.link(obj)
    root.location=location
    rig.update_tag(refresh={'OBJECT','DATA','TIME'})
    bpy.data.scenes.remove(source)
bpy.context.window.scene=review;review.frame_set(1);bpy.context.view_layer.update()
animated=json.loads((ROOT/'docs/orc_troops_anatomy_validation.json').read_text(encoding='utf-8'))
assert animated['status']=='PASS' and animated['models']==20
poses={a['stem']:a for a in animated['assets']};results=[]
for row in ASSETS:
    root=next(o for o in review.objects if o.type=='EMPTY' and o.parent is None and o.get('family')==row['family'] and o.get('tier')==row['tier'])
    rig=next(o for o in review.objects if o.type=='ARMATURE' and o.parent==root)
    parts=[o for o in review.objects if o.type=='MESH' and o.parent==rig]
    by={o['part']:o for o in parts};assert set(BODY).issubset(by)
    orthogonal=0.
    for name in BODY:
        obj=by[name];assert len(obj.data.vertices)==8 and len(obj.data.polygons)==6
        _,axes=cuboid_axes(obj);axes/=np.linalg.norm(axes,axis=0)
        orthogonal=max(orthogonal,float(np.abs(axes.T@axes-np.eye(3)).max()))
    assert orthogonal<.00003
    assert sum(o['part']=='Head' for o in parts)==1
    assert sum(o['part'].startswith('ElfEar') for o in parts)==6
    asset_report=json.loads((OUT/row['stem']/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
    eyebrows=0 if asset_report.get('open_skull_revision')=='jawless_skull_v1' else 2
    assert sum(o['part'].startswith('Brow_') for o in parts)==eyebrows
    if eyebrows:
        for name in ('Brow_l','Brow_r'):
            assert len(by[name].data.vertices)==8 and list(by[name].vertex_groups)==[by[name].vertex_groups['head']]
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for o in parts for v in o.data.vertices)
    tracks=list(rig.animation_data.nla_tracks);assert all(not t.mute and not t.is_solo for t in tracks)
    for track in tracks:
        strip=track.strips[0];assert strip.action_slot is not None
        curves=[fc for layer in strip.action.layers for bag in layer.strips[0].channelbags for fc in bag.fcurves]
        assert curves and all(np.isfinite(np.array([tuple(k.co) for k in fc.keyframe_points])).all() for fc in curves)
        assert any('hand_r' in fc.data_path and np.ptp([k.co.y for k in fc.keyframe_points])>.0001 for fc in curves)
    top=max(v.co.z for v in by['Head'].data.vertices)
    if row['family']=='cavalry':
        height=(top-rig.data.bones['thigh_l'].head_local.z+rig.data.bones['thigh_l'].length+rig.data.bones['shin_l'].length
            +rig.data.bones['foot_l'].head_local.z-min(v.co.z for v in by['Foot_l'].data.vertices))*root.scale.z
    else:height=(top-min(v.co.z for name in ('Foot_l','Foot_r') for v in by[name].data.vertices))*root.scale.z
    assert abs(height-row['character_height_m'])<.00002,(row['stem'],height)
    p=poses[row['stem']]
    results.append(dict(stem=row['stem'],status='PASS',body_cuboids=18,head_blocks=1,ear_cuboids=6,eyebrow_cuboids=eyebrows,
        height_m=height,clips=len(tracks),pose_samples=p['pose_samples'],max_arm_joint_gap_m=p['maximum_joint_gap_m'],
        max_cuboid_orthogonality_error=orthogonal,rigid_weights=True,saved_animation_tracks_enabled=True,
        animated_geometry_validation='orc_troops_anatomy_validation.json'))
review['description']='20 approved orcs; four closed bone carapaces with forward skull horns, four painted archer hoods, cavalry without arm shields. All original bodies and animation curves preserved.'
if KEYS==OPEN_SKULL_KEYS:review['description']='20 approved orcs; four jawless skull helmets, seated horns clear of ears, solid bone gauntlets; four painted archer hoods. Approved bodies and animations preserved.'
if KEYS==BOAR_KEYS:review['description']='20 approved orcs; four cavalry war boars replace horses, with broad bristled bodies and curved tusks. Approved riders, saddle, stirrups, weapons and all animation curves preserved.'
if KEYS==BOAR_KEYS and any(json.loads((OUT/r['stem']/(r['stem']+'_report.json')).read_text(encoding='utf-8')).get('mount_species')=='war_bull' for r in ASSETS):review['description']='20 approved orcs; cavalry rides rectangular bulls without decorative mount plates. Existing gaits corrected at mounted leg translations for grounded hooves. Riders, weapons, saddles and all 93 clips preserved.'
review.render.filepath=str(ROOT/'docs/previews/orc_troops/blender_roster.png')
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(OUT/'orc_troops_review.blend'),{review},path_remap='RELATIVE',fake_user=True,compress=True)
output=dict(status='PASS',models=20,clips=sum(r['clips'] for r in results),pose_samples=sum(r['pose_samples'] for r in results),assets=results)
(ROOT/'docs/orc_troops_blender_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
        area.spaces.active.region_3d.view_perspective='CAMERA'
result={'status':'PASS','scene':review.name,'models':20,'clips':output['clips'],'updated_actors':len(KEYS)}
