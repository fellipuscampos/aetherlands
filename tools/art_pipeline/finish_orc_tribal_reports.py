"""Keep material inventories in earlier batch reports consistent with the mesh."""
import json
from orc_troop_assets import ASSETS,OUT
for row in ASSETS:
    path=OUT/row['stem']/(row['stem']+'_report.json')
    report=json.loads(path.read_text(encoding='utf-8'))
    assert report.get('equipment_revision')=='tribal_v1'
    if row['key']=='squire':continue
    removed=set(report['tribal_equipment']['removed_parts'])
    materials={name:kind for name,kind in report['texture']['equipment_materials'].items() if name not in removed}
    materials.update(report['texture']['tribal_materials'])
    report['texture']['equipment_materials']=materials
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Updated material inventories for 19 revised models; approved squire unchanged.')
