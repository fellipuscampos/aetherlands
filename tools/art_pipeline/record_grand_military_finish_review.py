"""Record verified final geometry in every source, report and asset README."""
import bpy
import json
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
rows=json.loads((ROOT/'docs/grand_military_geometry_after.json').read_text(encoding='utf-8'))
assert len(rows)==24
for row in rows:
    assert not row['coplanar_faces'] and not row['mast_roof_intersections'],row['scene']
    assert not any(d['blockers'] for d in row['entrances']),row['scene']
    assert not any(d['blockers'] for d in row['open_passages']),row['scene']
    scene=bpy.data.scenes[row['scene']]
    assert scene.get('military_finish_revision')
    root=next(o for o in scene.objects if o.name==scene.name+'_ROOT')
    for obj in scene.objects:
        if obj.type=='MESH' and obj.get('part') and obj.get('region')!='studio' and not obj.get('preview_only'):
            obj.parent=root
    out=ROOT/scene['asset_output_relative']
    path=out/(out.name+'_report.json')
    r=json.loads(path.read_text(encoding='utf-8'))
    audit={k:v for k,v in row.items() if k!='scene'}
    scene['military_finish_audit_json']=json.dumps(audit)
    r['finish_review']={'revision':int(scene['military_finish_revision']),
        'method':'live Blender MCP; localized closed-mesh repairs',
        'changes':json.loads(scene['military_finish_changes_json']),
        'geometry_checks':audit,'backup':'art_source/grand_military_before_finish_pass'}
    path.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
    readme=out/'README.md'
    text=readme.read_text(encoding='utf-8').replace('../../../../../../docs/','../../../../../docs/')
    if 'Revisão de acabamento:' not in text:
        text+='\nRevisão de acabamento: entradas e passagens desobstruídas, mastros fora dos telhados e faces coincidentes corrigidas. Arquitetura e paleta preservadas. [Revisão](../../../../../docs/GRAND_MILITARY_FINISH_REVIEW.md).\n'
    readme.write_text(text,encoding='utf-8')
    bpy.data.libraries.write(str(out/(out.name+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'verified_sources_saved':24}
