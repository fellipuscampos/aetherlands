"""Record real exported rest bounds, including the parent scale of new gear."""
import json,numpy as np
from orc_troop_assets import ASSETS,OUT
from glb_pose_math import PoseModel

for row in ASSETS:
    if row['key']=='squire':continue
    folder=OUT/row['stem'];path=folder/(row['stem']+'_report.json')
    report=json.loads(path.read_text(encoding='utf-8'))
    model=PoseModel(folder/(row['stem']+'.glb'));positions,ids,_=model.geometry()
    world=model.skinned(model.rest,positions,ids)
    # Convert engine Y-up bounds to the native Blender Z-up report.
    native=world@np.array([[1,0,0],[0,0,1],[0,-1,0]])
    lo=native.min(axis=0);hi=native.max(axis=0)
    report['geometry'].update(bounds_min=lo.tolist(),bounds_max=hi.tolist(),dimensions=(hi-lo).tolist(),bounds_source='exported_rest_skin')
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Recorded actual exported rest bounds for 19 revised models.')
