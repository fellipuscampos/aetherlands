"""Center the heart in the asymmetric pose's upper opening without changing its scale."""
import bpy
from pathlib import Path
DRAGON_STEM='elemental_dragon_v3'
state=bpy.app.driver_namespace[DRAGON_STEM]
assert abs(state['report']['core_center_m'][0])<.001, 'Heart already recentered.'
skull=next(o for o in state['parts'] if o['part']=='Dragon_skull')
factor=(max(v.co.x for v in skull.data.vertices)-min(v.co.x for v in skull.data.vertices))/.55
DRAGON_CORE_DELTA=(-.38*factor,-.06*factor,.08*factor)
source=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\refine_elemental_dragon_core_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
