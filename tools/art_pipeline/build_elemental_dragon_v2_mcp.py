"""Revision: an airborne serpent coiled around its heart, without legs or side spikes."""
from pathlib import Path

DRAGON_CONFIG={
    'stem':'elemental_dragon_v2','name':'Elemental_Dragon_V2',
    'legs':False,'body_spikes':False,'head_spikes':False,
    'head_shift':(.08,-.32,0),'core':(0,-.12,1.43),
    'body_surrounds_core':True,
    'concept':'Wingless, legless eastern elemental dragon floating in two open coils around a central cubic heart; head projects forward',
    # Tail to neck. Separate depths keep the returning coil clear of the back turn.
    'controls':[
        (-.10,-.20,.30),(-.55,-.05,.40),(-.97,.20,.66),(-1.05,.34,1.23),
        (-.88,.34,1.90),(-.38,.28,2.28),(.30,.20,2.31),(.88,.08,1.95),
        (1.08,-.08,1.43),(.92,-.24,.85),(.43,-.35,.57),(-.22,-.40,.60),
        (-.73,-.42,.95),(-.86,-.40,1.51),(-.66,-.38,2.02),(-.21,-.36,2.27),
        (.25,-.39,2.28),(.56,-.50,2.30),(.50,-.80,2.48)
    ]
}
source=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\build_elemental_dragon_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
