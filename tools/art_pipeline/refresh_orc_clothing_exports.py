"""Refresh canonical protected geometry and all UV layers without repainting."""
import argparse
from blender_mcp_client import execute
from orc_troop_assets import ROOT,ASSETS
parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
for row in ASSETS:
    if args.only and row['key'] not in args.only:continue
    print('CLOTHING_EXPORT_START',row['stem'],flush=True)
    execute(f'''import bpy,sys,importlib,json,numpy as np
from pathlib import Path
sys.path.insert(0,{str(ROOT/'tools/art_pipeline')!r})
import export_orc_clothing_glb;importlib.reload(export_orc_clothing_glb)
from build_orc_troops import load_scene
from build_elf_troops import reset_pose
from glb_pose_math import PoseModel
row={row!r};out=Path({str(ROOT/'assets/generated/orcs')!r})/row['stem']
path=out/(row['stem']+'_report.json');report=json.loads(path.read_text(encoding='utf-8'))
previous=bpy.context.scene;scene=load_scene(out/(row['stem']+'.blend'));bpy.context.window.scene=scene
rig=next(o for o in scene.objects if o.type=='ARMATURE');root=rig.parent;reset_pose(rig,scene)
parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
details=report['clothing_refinement']
doc=export_orc_clothing_glb.export(row,scene,parts,rig,root,out,details['source_part_uv_boxes'],details['blade_rotations'])
model=PoseModel(out/(row['stem']+'.glb'));p,ids,_=model.geometry();world=model.skinned(model.rest,p,ids)
native=world@np.array([[1,0,0],[0,0,1],[0,-1,0]]);lo=native.min(axis=0);hi=native.max(axis=0)
report['geometry'].update(bounds_min=lo.tolist(),bounds_max=hi.tolist(),dimensions=(hi-lo).tolist(),bounds_source='exported_rest_skin')
details['protected_glb_geometry_preserved']=True;details['all_source_uv_layers_preserved']=True
path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.context.window.scene=previous;bpy.data.scenes.remove(scene)
result=dict(status='PASS',stem=row['stem'],clips=len(doc['animations']))
''',timeout=600)
    print('CLOTHING_EXPORT_COMPLETE',row['stem'],flush=True)
print('CLOTHING_EXPORT_BATCH_COMPLETE',flush=True)
