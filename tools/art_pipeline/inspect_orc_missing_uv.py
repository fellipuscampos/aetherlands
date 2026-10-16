import json,numpy as np
from orc_troop_assets import OUT,WORK
from glb_pose_math import PoseModel,accessor
from audit_orc_tribal_equipment import mask_for_rectangles
stem='orc_sentinel_v1';name='ShieldBoneClamp_-1_-1'
r=json.loads((OUT/stem/(stem+'_report.json')).read_text(encoding='utf-8'))
data=r['clothing_refinement'];boxes=data['source_part_uv_boxes'][name]
for label,folder in [('old',WORK/'clothing_refinement/before_assets'/stem),('new',OUT/stem)]:
 m=PoseModel(folder/(stem+'.glb'));p,ids,uv=m.geometry()
 for layer in (0,1):
  attrs=m.doc['meshes'][0]['primitives'][0]['attributes']
  if 'TEXCOORD_'+str(layer) not in attrs:continue
  uv=accessor(m.doc,m.binary,attrs['TEXCOORD_'+str(layer)]);mask=mask_for_rectangles(uv,boxes)
  print(label,layer,np.unique(p[mask],axis=0))
expected=np.array(data['source_part_vertices'][name])@np.array([[1,0,0],[0,0,1],[0,-1,0]]).T
print('Native vertices',expected)
