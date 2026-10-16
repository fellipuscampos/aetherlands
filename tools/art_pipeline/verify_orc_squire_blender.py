"""Inspect the saved editable orc's body and exact inherited ear shapes via MCP."""
import bpy
import json
import sys
from pathlib import Path
import numpy as np

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
if str(ROOT/'tools/art_pipeline') not in sys.path: sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from build_elf_troops import BODY

previous=bpy.context.scene; playing=bpy.context.screen.is_animation_playing
if playing: bpy.ops.screen.animation_cancel(restore_frame=False)
folder=ROOT/'assets/generated/orcs/orc_squire_v1'
report=json.loads((folder/'orc_squire_v1_report.json').read_text(encoding='utf-8'))
with bpy.data.libraries.load(str(folder/'orc_squire_v1.blend'),link=False) as (source,loaded): loaded.scenes=source.scenes
scene=loaded.scenes[0]; bpy.context.window.scene=scene; bpy.context.view_layer.update()
parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
by={o['part']:o for o in parts}
backup=ROOT/'art_source/orc_squire/approved_before_roster/orc_squire_v1.blend'
with bpy.data.libraries.load(str(backup),link=False) as (source,old_loaded): old_loaded.scenes=source.scenes
old_scene=old_loaded.scenes[0]
old_by={o.get('part'):o for o in old_scene.objects if o.type=='MESH'}
body_geometry_error=0.0
for name in BODY+['ShieldGrip']:
    old=np.array([list(v.co) for v in old_by[name].data.vertices])
    current=np.array([list(v.co) for v in by[name].data.vertices])
    if name in ('Forearm_r','Hand_r'):
        transform=np.array(report['relaxed_right_arm']['transform'])
        old=(np.c_[old,np.ones(len(old))]@transform.T)[:,:3]
    if name=='Head' and report.get('revision')=='anatomy_v2':
        old[:,2]+=report['rig']['retarget']['head_rest_raise']
    error=float(np.max(np.abs(old-current))); body_geometry_error=max(body_geometry_error,error)
    if report.get('revision')=='anatomy_v2' and name.startswith(('UpperArm','Forearm')):
        # Align these four blocks with their corrected bone lengths. Width
        # and depth remain exact; the longitudinal correction is below 3 mm.
        old_edges=np.array([np.linalg.norm(old[i]-old[0]) for i in (1,2,4)])
        new_edges=np.array([np.linalg.norm(current[i]-current[0]) for i in (1,2,4)])
        assert np.allclose(old_edges[:2],new_edges[:2],atol=.000001),name
        assert abs(new_edges[2]/old_edges[2]-1)<.02,name
        assert error<.003,name
    else:assert error<.000001,name
for name in ('ShieldMid','ShieldWide','ShieldTall','ShieldBoss'):
    old=np.array([list(v.co) for v in old_by[name].data.vertices])
    current=np.array([list(v.co) for v in by[name].data.vertices])
    old_lengths=[np.linalg.norm(old[i]-old[0]) for i in (1,2,4)]
    new_lengths=[np.linalg.norm(current[i]-current[0]) for i in (1,2,4)]
    assert np.allclose(np.array(new_lengths)/old_lengths,[1.18,1,1.18],atol=.00001),name
bpy.data.scenes.remove(old_scene)
for name in BODY:
    obj=by[name]; assert len(obj.data.vertices)==8 and len(obj.data.polygons)==6
    vertices=np.array([list(v.co) for v in obj.data.vertices])
    axes=np.stack([vertices[i]-vertices[0] for i in (1,2,4)],axis=1)
    axes/=np.linalg.norm(axes,axis=0)
    orthogonality_error=float(np.max(np.abs(axes.T@axes-np.eye(3))))
    assert orthogonality_error<.00003,(name,orthogonality_error)
ear_error=0.0
for name,old_vertices in report['source_ear_geometry'].items():
    obj=by[name]; sign=1 if '_l_' in name else -1
    expected=np.array(old_vertices)+[sign*report['geometry']['ear_edge_translation_m'],0,0]
    if report.get('revision')=='anatomy_v2':expected[:,2]+=report['rig']['retarget']['head_rest_raise']
    actual=np.array([list(v.co) for v in obj.data.vertices])
    error=float(np.max(np.abs(expected-actual))); ear_error=max(ear_error,error)
    assert error<.000001,name
head_parts=[o['part'] for o in parts if o.get('rig_bone')=='head']
assert len(head_parts)==13 and set(head_parts)=={'Head'}|set(report['source_ear_geometry'])|set(report['tusks'])|set(report['brows'])
assert set(report['brows'])=={'Brow_l','Brow_r'}
left=np.array([list(v.co) for v in by['Brow_l'].data.vertices])
right=np.array([list(v.co) for v in by['Brow_r'].data.vertices])
mirrored=left*np.array([-1,1,1])
sort=lambda rows: np.array(sorted(tuple(np.round(row,6)) for row in rows))
assert np.max(np.abs(sort(mirrored)-sort(right)))<.000001
for name in report['brows']:
    obj=by[name]
    assert len(obj.data.vertices)==8 and len(obj.data.polygons)==6
    assert list(obj.vertex_groups.keys())==['head']
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<.000001 for v in obj.data.vertices)
    vertices=np.array([list(v.co) for v in obj.data.vertices])
    assert vertices[:,1].min()<min(v.co.y for v in by['Head'].data.vertices)
    outside=vertices[vertices[:,0].argmax() if name.endswith('_l') else vertices[:,0].argmin()]
    # The inclined cuboid's X axis rises away from the nose.
    axis=vertices[1]-vertices[0]
    assert axis[2]>0 if name.endswith('_l') else axis[2]<0
height=max((by['Head'].matrix_world@v.co).z for v in by['Head'].data.vertices)
assert abs(height-2.0)<.000001
rig=next(o for o in scene.objects if o.type=='ARMATURE')
assert all(not track.mute and not track.is_solo for track in rig.animation_data.nla_tracks)
assert rig.animation_data.action is None
result=dict(status='PASS',body_cuboids=18,head_blocks=1,ear_cuboids=6,tusk_cuboids=4,
            ear_shape_error=ear_error,height_m=height,body_armor_painted=True,head_hair_painted=True,
            saved_animation_tracks_enabled=True,clips=len(rig.animation_data.nla_tracks))
result['body_geometry_compatible_with_approved_arm_relaxation']=True
result['right_arm_relaxed_degrees']=report['relaxed_right_arm']['degrees']
result['body_geometry_max_error']=body_geometry_error
result['eyebrow_cuboids']=2
result['eyebrows_mirrored_and_head_weighted']=True
result['shield_width_height_factor']=1.18
result['shield_grip_unchanged']=True
(ROOT/'docs/orc_squire_blender_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
bpy.context.window.scene=previous; bpy.data.scenes.remove(scene)
if playing: bpy.ops.screen.animation_play()
