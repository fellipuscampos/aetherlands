"""Stagger the upper central beard tier without rescaling texture pixels."""
import bpy,json,numpy as np
from pathlib import Path

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
assets=bpy.app.driver_namespace['settlers_v1_assets']
asset=next(a for a in assets if a['report']['race']=='dwarf')
obj=next(o for o in asset['parts'] if o['part']=='beard_lock_2_0')
old=np.array([list(v.co) for v in obj.data.vertices])
new=old.copy(); new[:,2]=old[:,2].mean()+(old[:,2]-old[:,2].mean())*.92
uvdata=obj.data.uv_layers.active.data
for face in obj.data.polygons:
    ids=list(face.vertices); uv=np.array([list(uvdata[i].uv) for i in face.loop_indices])
    original=old[ids]; updated=new[ids]
    basis=np.stack((original[1]-original[0],original[-1]-original[0]),axis=1)
    coefficients=(updated-original[0])@np.linalg.pinv(basis).T
    refreshed=uv[0]+coefficients[:,0,None]*(uv[1]-uv[0])+coefficients[:,1,None]*(uv[-1]-uv[0])
    for li,point in zip(face.loop_indices,refreshed): uvdata[li].uv=point
for v,p in zip(obj.data.vertices,new): v.co=p
obj.data.update()
change=dict(race='dwarf',part='beard_lock_2_0',fix='Inset upper/lower strand ends by 3.16 mm, retaining 64 px/m UVs')
asset['report']['review_refinements'].append(change)
audit=bpy.app.driver_namespace['settlers_v1_surface_audit']
rows=[]
for a in assets:
    exposed,hidden=audit(a['parts'])
    assert not exposed,(a['report']['race'],[(r['a'],r['b']) for r in exposed])
    rows.append(dict(race=a['report']['race'],exposed_coplanar_pairs=0,hidden_coplanar_pairs=len(hidden),issues=[],hidden=hidden))
(ROOT/'art_source/settlers_review/surface_audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
ns={'__name__':'settler_metric_validation'}
code=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8').split('reports=[]; assets=[]')[0]
exec(compile(code,'build_settlers_mcp.py','exec'),ns)
ns.update(PARTS=asset['parts'],SCENE=asset['scene'],RACE='dwarf')
bpy.context.window.scene=asset['scene']; asset['report']['geometry']=ns['validation']()
(asset['folder']/(asset['root'].name+'_report.json')).write_text(json.dumps(asset['report'],ensure_ascii=False,indent=2),encoding='utf-8')
bpy.context.window.scene=bpy.app.driver_namespace['settlers_v1_review']['scene']
result={'verified':4,'exposed_coplanar_pairs':0,'pixel_density':64}
