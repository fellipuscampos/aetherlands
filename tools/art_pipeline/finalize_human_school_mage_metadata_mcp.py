"""Remove inherited settler labels and record explicit asset paths."""
import bpy,json
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/human_school_mages_review'
assets=bpy.app.driver_namespace['human_school_mage_assets_v1']; review=bpy.app.driver_namespace['human_school_mage_review_v1']
for asset in assets:
    stem=asset['report']['stem']; folder=asset['folder']; report=asset['report']
    for part in asset['parts']:
        if 'settler_asset' in part: del part['settler_asset']
        part['human_school_mage_asset']=True
    report.update(blend=(folder/(stem+'.blend')).relative_to(ROOT).as_posix(),glb=(folder/(stem+'.glb')).relative_to(ROOT).as_posix(),texture=(folder/(stem+'_albedo.png')).relative_to(ROOT).as_posix())
    asset['scene']['mage_report']=json.dumps(report,ensure_ascii=False)
    bpy.data.libraries.write(str(folder/(stem+'.blend')),{asset['scene']},path_remap='RELATIVE',fake_user=True,compress=True)
    (folder/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
for obj in review['scene'].objects:
    if obj.type=='MESH' and 'settler_asset' in obj:
        del obj['settler_asset']; obj['human_school_mage_asset']=True
bpy.data.libraries.write(str(WORK/'human_school_mages_six_schools_review.blend'),{review['scene']},path_remap='RELATIVE',fake_user=True,compress=True)
for path in [WORK/'manifest.json',WORK/'modeling_validation.json',ROOT/'docs/human_school_mages_blender_validation.json']:
    data=json.loads(path.read_text(encoding='utf-8')); data['assets']=[a['report'] for a in assets]
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
result=dict(status='PASS',models=6,metadata_labels='human_school_mage_asset',sources_saved=True)
