"""Check reproducible tool bind corrections without changing saved models."""
import bpy,json
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
namespace={}
source=(ROOT/'tools/art_pipeline/animate_settlers_mcp.py').read_text(encoding='utf-8').split('\nfor asset in ASSETS:')[0]
exec(compile(source,'animate_settlers_mcp.py','exec'),namespace)
rows=[]
for asset in namespace['ASSETS']:
    race=asset['report']['race']
    if race not in ('elf','orc'): continue
    before={o:[v.co.copy() for v in o.data.vertices] for o in asset['parts']}
    try:
        namespace['correct_tool_grips'](asset,asset['chains'])
        difference=max((v.co-original).length for obj,points in before.items() for v,original in zip(obj.data.vertices,points))
        assert difference<.000001,(race,'Generator differs from saved correction',difference)
    finally:
        for obj,points in before.items():
            for v,original in zip(obj.data.vertices,points): v.co=original
            obj.data.update()
    exposed,hidden=bpy.app.driver_namespace['settlers_v1_surface_audit'](asset['parts'])
    assert not exposed,(race,'Exposed coplanar faces',exposed)
    rows.append(dict(race=race,max_generator_difference_m=difference,exposed_coplanar_pairs=0))
report=dict(status='PASS',pipeline='Live Blender MCP localhost:9876',assets=rows)
(ROOT/'docs/settlers_grip_source_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.context.window.scene=namespace['REVIEW']['scene']; namespace['REVIEW']['scene'].frame_set(161)
result=report
