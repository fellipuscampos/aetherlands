"""Inspect approved human anatomy without changing its source files."""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/human_school_mages_review'
WORK.mkdir(parents=True,exist_ok=True); (WORK/'.gdignore').touch()
previous=bpy.context.scene
checkpoint=WORK/'previous_blender_review.blend'
if not checkpoint.exists():
    bpy.data.libraries.write(str(checkpoint),{previous},path_remap='RELATIVE',fake_user=True,compress=True)
path=ROOT/'assets/generated/humans/human_settler_v1/human_settler_v1.blend'
with bpy.data.libraries.load(str(path),link=False) as (src,dst): dst.scenes=[src.scenes[0]]
scene=dst.scenes[0]; bpy.context.window.scene=scene
for obj in scene.objects:
    if obj.type=='ARMATURE':
        obj.animation_data_clear()
        for bone in obj.pose.bones: bone.matrix_basis=Matrix.Identity(4)
scene.frame_set(1); bpy.context.view_layer.update()
rows=[]
for obj in scene.objects:
    if obj.type!='MESH': continue
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    if not points: continue
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    rows.append(dict(name=obj.name,part=obj.get('part'),bone=obj.get('future_bone',obj.get('rig_bone')),bounds_min=low,bounds_max=high,vertices=len(points),modifiers=[m.type for m in obj.modifiers]))
report=dict(path=path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),scene=scene.name,parts=rows)
(WORK/'base_probe.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.app.driver_namespace['human_school_mage_base']=scene
bpy.context.window.scene=previous
result=dict(source=report['path'],meshes=len(rows),body=[row for row in rows if row['part'] in ['Head','Chest','Belly','Pelvis'] or str(row['part']).startswith(('Thigh_','Shin_','Foot_','Shoulder_','UpperArm_','Forearm_','Hand_'))])
