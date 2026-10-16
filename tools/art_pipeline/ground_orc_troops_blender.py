"""Correct sole grounding without changing rig trajectories or anatomy."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import ASSETS,OUT
from build_elf_troops import reset_pose,export_glb
fixed=[]
for row in ASSETS:
    if row['key'] not in ('sentinel','guardian_champion','rogue','saboteur','assassin','shadow_master'): continue
    out=OUT/row['stem']; path=out/(row['stem']+'.blend')
    with bpy.data.libraries.load(str(path),link=False) as (src,dst): dst.scenes=src.scenes
    scene=dst.scenes[0]; bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None)
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    reset_pose(rig,scene)
    bottom=min(v.co.z for o in parts if o['part'] in ('Foot_l','Foot_r') for v in o.data.vertices)
    root.location.z=-bottom*root.scale.z; bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
    lo=[min(p[i] for p in points) for i in range(3)]; hi=[max(p[i] for p in points) for i in range(3)]
    target=Vector([(a+b)/2 for a,b in zip(lo,hi)]); camera=scene.camera
    for view,offset in [('front',(0,-12,1.2)),('three_quarter',(6,-12,5.6)),('back',(-6,12,5)),('game_top',(5,-7,11))]:
        camera.location=target+Vector(offset); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
    export_glb(row,scene,parts,rig,root,out); reset_pose(rig,scene)
    for track in rig.animation_data.nla_tracks: track.mute=False; track.is_solo=False
    scene.frame_set(1)
    bpy.data.libraries.write(str(path),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    report_path=out/(row['stem']+'_report.json'); report=json.loads(report_path.read_text(encoding='utf-8'))
    report['geometry'].update(bounds_min=lo,bounds_max=hi,dimensions=[b-a for a,b in zip(lo,hi)],grounding_offset_m=root.location.z)
    report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    fixed.append(row['stem']); print('GROUNDED',row['stem'],root.location.z,flush=True)
result=dict(status='PASS',models=len(fixed),assets=fixed)
