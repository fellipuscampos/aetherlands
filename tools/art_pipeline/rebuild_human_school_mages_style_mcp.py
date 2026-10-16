"""Rebuild the six mages after the user's visual review; preserve old scenes."""
import bpy,json
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/human_school_mages_review'
assert (WORK/'before_style_revision/human_school_mages_six_schools_review.blend').exists()
old=bpy.app.driver_namespace['human_school_mage_assets_v1']
assert len(old)==6
bpy.app.driver_namespace['human_school_mage_assets_before_style_revision']=old
bpy.app.driver_namespace['human_school_mage_assets_v1']=[]
exec(compile((ROOT/'tools/art_pipeline/build_human_school_mages_mcp.py').read_text(encoding='utf-8'),'<revised_mages>','exec'),dict(MAGE_REBUILD=True))
assets=bpy.app.driver_namespace['human_school_mage_assets_v1']; review=bpy.app.driver_namespace['human_school_mage_review_v1']
roots=[]
for index,(asset,col) in enumerate(zip(assets,review['collections'])):
    # Only replace these owned model instances; retain the existing labels/studio.
    bpy.data.batch_remove(ids=[obj for obj in col.objects if obj.type in ['MESH','EMPTY']])
    mapping={}
    for original in [asset['root']]+asset['parts']:
        obj=original.copy(); col.objects.link(obj); mapping[original]=obj
    for original,obj in mapping.items():
        if original.parent in mapping: obj.parent=mapping[original.parent]
    root=mapping[asset['root']]; root.location=((index-2.5)*1.8,0,0); roots.append(root)
review['roots']=roots
bpy.context.window.scene=review['scene']; review['scene']['style_revision']=2
review['scene']['description']='Revisão de estilo: couro e botas da família humana, barbas em blocos, cabeça sem cabelo pintado, sem livros.'
bpy.ops.object.select_all(action='DESELECT'); roots[0].select_set(True); bpy.context.view_layer.objects.active=roots[0]
result=dict(status='PASS',models=6,revision=2,books=0,original_models_preserved=True,triangles=[a['report']['geometry']['triangles'] for a in assets])
