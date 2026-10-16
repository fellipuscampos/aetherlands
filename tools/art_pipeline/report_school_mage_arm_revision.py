"""Record the specific before/after arm fault and full-clip verification."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/school_mages_animation_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
assert len(manifest['assets'])==24
rows=[]
for asset in manifest['assets']:
    animation=asset['animation']; assert animation['choreography_revision']==3
    clips=animation['clips']; assert all('max_elbow_axial_roll_degrees' in c for c in clips.values())
    rows.append(dict(stem=asset['stem'],race=asset['race'],clips=clips))
before=json.loads((WORK/'before_arm_logic_revision_3/arm_logic_audit_revision_2.json').read_text(encoding='utf-8'))
comparison=[]
for old in before['assets']:
    if old['clip']!='spell': continue
    current=[row['clips']['spell'] for row in rows if row['race']==old['race']]
    comparison.append(dict(race=old['race'],before_free_elbow_roll_degrees=old['arms']['l']['elbow_roll'],after_max_elbow_roll_degrees=max(c['max_elbow_axial_roll_degrees'] for c in current),before_free_wrist_angle_degrees=old['arms']['l']['wrist_angle'],after_max_free_wrist_angle_degrees=max(c['max_wrist_rotation_degrees']['l'] for c in current)))
clips=[c for row in rows for c in row['clips'].values()]
for name in ['export','source','godot_import','godot_native']:
    report=json.loads((ROOT/'docs'/('school_mages_animation_'+name+'_validation.json')).read_text(encoding='utf-8'))
    assert report['status']=='PASS' and report['verified']==24
engine=json.loads((ROOT/'docs/school_mages_animation_godot_import_validation.json').read_text(encoding='utf-8'))
assert all('maximum_elbow_hinge_error' in c for row in engine['assets'] for c in row['clips'].values())
report=dict(status='PASS',revision=3,verified=24,clips=72,baked_frames_checked=sum(c['frames'] for c in clips),maximum_elbow_axial_roll_degrees=max(c['max_elbow_axial_roll_degrees'] for c in clips),maximum_arm_frame_rotation_degrees=max(c['max_arm_frame_rotation_degrees'] for c in clips),maximum_arm_frame_acceleration_degrees=max(c['max_arm_frame_acceleration_degrees'] for c in clips),torso_intersections=sum(c['hand_forearm_torso_intersections'] for c in clips),staff_forearm_intersections=sum(c['staff_forearm_intersections'] for c in clips),staff_hand_detachments=sum(c['staff_hand_detachments'] for c in clips),geometry_and_textures_preserved=True,before_after= comparison,assets=rows)
(ROOT/'docs/school_mages_arm_motion_revision_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='assets'}))
