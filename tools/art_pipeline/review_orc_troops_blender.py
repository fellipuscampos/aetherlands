"""Validate saved editable models and leave the full roster open in Blender MCP."""
import json,sys,math
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import ASSETS,OUT
from build_elf_troops import BODY,reset_pose
from build_orc_squire import cuboid_axes

if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
review=bpy.data.scenes.new('Orc_Troops_20_Review')
review.render.engine='BLENDER_EEVEE'; review.render.fps=24
review.render.resolution_x=1800; review.render.resolution_y=1400; review.render.resolution_percentage=100
review.view_settings.view_transform='Standard'; review.view_settings.look='None'
review.world=bpy.data.worlds.new('Orc_Roster_Studio'); review.world.use_nodes=True
review.world.node_tree.nodes['Background'].inputs[0].default_value=(.11,.14,.12,1)
review.world.node_tree.nodes['Background'].inputs[1].default_value=.65
results=[]
animated_validation=json.loads((ROOT/'docs/orc_troops_anatomy_validation.json').read_text(encoding='utf-8'))
assert animated_validation['status']=='PASS' and animated_validation['models']==20
animated_by_stem={r['stem']:r for r in animated_validation['assets']}
for row in ASSETS:
    path=OUT/row['stem']/(row['stem']+'.blend')
    with bpy.data.libraries.load(str(path),link=False) as (src,dst): dst.scenes=src.scenes
    scene=dst.scenes[0]; bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None)
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    tracks=list(rig.animation_data.nla_tracks)
    assert all(not t.mute and not t.is_solo for t in tracks)
    by={o['part']:o for o in parts}; reset_pose(rig,scene)
    assert set(BODY).issubset(by) and len(BODY)==18
    orthogonal_error=0.
    for name in BODY:
        obj=by[name]; assert len(obj.data.vertices)==8 and len(obj.data.polygons)==6
        _,axes=cuboid_axes(obj); axes/=np.linalg.norm(axes,axis=0)
        orthogonal_error=max(orthogonal_error,float(np.max(np.abs(axes.T@axes-np.eye(3)))))
    assert orthogonal_error<.00003
    assert len([o for o in parts if o['part']=='Head'])==1
    assert len([o for o in parts if o['part'].startswith('ElfEar')])==6
    for name in ('Brow_l','Brow_r'):
        obj=by[name]; assert len(obj.data.vertices)==8 and len(obj.data.polygons)==6
        assert list(obj.vertex_groups.keys())==['head']
    for obj in parts:
        assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<.000001 for v in obj.data.vertices),obj.name
    top=max(v.co.z for v in by['Head'].data.vertices)
    if row['family']=='cavalry':
        height=(top-rig.data.bones['thigh_l'].head_local.z
            +rig.data.bones['thigh_l'].length+rig.data.bones['shin_l'].length
            +rig.data.bones['foot_l'].head_local.z-min(v.co.z for v in by['Foot_l'].data.vertices))*root.scale.z
    else:
        height=(top-min(v.co.z for name in ('Foot_l','Foot_r') for v in by[name].data.vertices))*root.scale.z
    assert abs(height-row['character_height_m'])<.00002,(row['stem'],height)
    # Inspect the saved editable actions directly. An appended armature's
    # dependency-graph cache can hold stale poses; actual animated joint and
    # mesh measurements come from the independent exported-GLB audit.
    verified=animated_by_stem[row['stem']]
    max_gap=verified['maximum_joint_gap_m']; samples=verified['pose_samples']
    for track in tracks:
        strip=track.strips[0]
        assert strip.action_slot is not None
        curves=[fc for layer in strip.action.layers for bag in layer.strips[0].channelbags for fc in bag.fcurves]
        assert curves and all(np.isfinite(np.array([tuple(k.co) for k in fc.keyframe_points])).all() for fc in curves)
        assert any('hand_r' in fc.data_path and np.ptp([k.co.y for k in fc.keyframe_points])>.0001 for fc in curves),row['stem']
    assert max_gap<.008,(row['stem'],max_gap)
    for track in tracks: track.mute=False; track.is_solo=False
    scene.frame_set(1); bpy.context.view_layer.update()
    results.append(dict(stem=row['stem'],status='PASS',body_cuboids=18,head_blocks=1,
        ear_cuboids=6,eyebrow_cuboids=2,height_m=height,clips=len(tracks),pose_samples=samples,
        max_arm_joint_gap_m=max_gap,max_cuboid_orthogonality_error=orthogonal_error,
        rigid_weights=True,saved_animation_tracks_enabled=True,
        animated_geometry_validation='orc_troops_anatomy_validation.json'))
    for obj in [root,rig]+parts: review.collection.objects.link(obj)
    root.location=((row['tier']-1.5)*3.4,(ASSETS.index(row)//4-2)*4.5,root.location.z)
    label=bpy.data.curves.new(row['stem']+'_Label','FONT'); label.body=row['name']+'\n'+('Supremo 2,20 m' if row['tier']==3 else '2 m')
    label.align_x='CENTER'; label.size=.19; label.extrude=0
    text=bpy.data.objects.new(row['stem']+'_Label',label); review.collection.objects.link(text)
    text.location=(root.location.x,root.location.y-1.45,.015)
    bpy.data.scenes.remove(scene)

bpy.context.window.scene=review
floor_mat=bpy.data.materials.new('Orc_Review_Floor'); floor_mat.diffuse_color=(.085,.105,.09,1)
bpy.ops.mesh.primitive_plane_add(size=200)
floor=bpy.context.object; floor.name='Orc_Review_Floor'; floor.location.z=-.035; floor.data.materials.append(floor_mat)
for name,location,power,size in [('Key',(-7,-10,17),2400,12),('Fill',(10,-2,13),1800,10),('Rim',(0,10,16),2500,10)]:
    lamp=bpy.data.lights.new('Orc_Review_'+name,'AREA'); lamp.energy=power; lamp.shape='DISK'; lamp.size=size
    obj=bpy.data.objects.new(lamp.name,lamp); review.collection.objects.link(obj)
    obj.location=location; obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.cameras.new('Orc_Review_Camera'); camera.type='ORTHO'; camera.ortho_scale=26
obj=bpy.data.objects.new(camera.name,camera); review.collection.objects.link(obj)
obj.location=(12,-20,25); target=Vector((0,0,.6)); obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
review.camera=obj; review.frame_start=1; review.frame_end=72; review.frame_set(1)
review['description']='20 orcs, 5 classes, 4 tiers. 2 m ordinary, 2.20 m supreme. Each editable actor retains every class animation; first 72 frames show the idle clips.'
review.render.image_settings.file_format='PNG'
review.render.filepath=str(ROOT/'docs/previews/orc_troops/blender_roster.png')
Path(review.render.filepath).parent.mkdir(parents=True,exist_ok=True)
# The final review helper applies the floor/label materials and renders once.
bpy.data.libraries.write(str(OUT/'orc_troops_review.blend'),{review},path_remap='RELATIVE',fake_user=True,compress=True)
output=dict(status='PASS',models=len(results),clips=sum(r['clips'] for r in results),
    pose_samples=sum(r['pose_samples'] for r in results),assets=results)
(ROOT/'docs/orc_troops_blender_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.overlay.show_overlays=False
        area.spaces.active.shading.type='MATERIAL'
        area.spaces.active.region_3d.view_perspective='CAMERA'
result={k:v for k,v in output.items() if k!='assets'}
result['scene']=review.name
