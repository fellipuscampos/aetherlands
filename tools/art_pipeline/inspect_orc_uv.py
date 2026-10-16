import numpy as np,json
from orc_troop_assets import OUT,WORK
from glb_pose_math import PoseModel
for stem in ('orc_squire_v1','orc_blade_hero_v1'):
 for label,folder in [('before',WORK/'clothing_refinement/before_assets'/stem),('after',OUT/stem)]:
    m=PoseModel(folder/(stem+'.glb'));p,ids,uv=m.geometry();h=ids==m.names.index('head')
    print(stem,label,'head uv ranges',uv[h].min(axis=0),uv[h].max(axis=0))
    ear=h&(abs(p[:,0])>.165)&(p[:,1]>1.5)
    print('ear UV',np.unique(np.round(uv[ear],6),axis=0)[:45])
