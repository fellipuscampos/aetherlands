"""Airborne S pose with the neck swept aside to keep its heart visible from the map."""
from pathlib import Path

DRAGON_CONFIG={
    'stem':'elemental_dragon_v4','name':'Elemental_Dragon_V4',
    'legs':False,'body_spikes':False,'head_spikes':False,
    'parallel_transport_frames':True,
    'head_shift':(.63,-.32,0),'core':(-.38,-.04,1.54),
    'body_surrounds_core':True,
    'concept':'Legless eastern elemental dragon floating in an asymmetric S, with a loose tail and a swept neck that projects its head forward beside the central cubic heart',
    'controls':[
        (-1.36,-.22,.25),(-1.46,-.18,.60),(-1.08,-.03,.83),(-.58,.24,.70),
        (.18,.47,.39),(.86,.48,.50),(1.19,.42,.99),(.97,.45,1.43),
        (.42,.60,1.69),(-.25,.68,1.86),(-.90,.48,1.80),(-1.14,.10,1.37),
        (-.82,-.25,1.02),(-.35,-.52,1.00),(.20,-.62,1.20),(.59,-.60,1.62),
        (.69,-.62,2.00),(.88,-.72,2.32),(1.05,-.80,2.48)
    ]
}
source=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\build_elemental_dragon_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
