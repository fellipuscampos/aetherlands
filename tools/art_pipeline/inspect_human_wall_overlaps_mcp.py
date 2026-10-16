"""Measure coplanar overlaps in all three editable wall models."""
import bpy, json, sys
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from human_wall_surface_cleanup import audit_coplanar
report=[]
for level in (1,2,3):
    scene=bpy.data.scenes.get(f'Human_Walls_Level_{level}_Hex_V1')
    assert scene is not None
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part')]
    overlaps=audit_coplanar(parts)
    report.append(dict(level=level,coplanar_overlaps=len(overlaps),examples=overlaps[:20]))
out=ROOT/'art_source/human_walls_review/overlaps_before.json'
out.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
