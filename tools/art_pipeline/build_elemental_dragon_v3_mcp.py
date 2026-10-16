"""An open, asymmetric airborne S pose around the elemental heart."""
from pathlib import Path

DRAGON_CONFIG={
    'stem':'elemental_dragon_v3','name':'Elemental_Dragon_V3',
    'legs':False,'body_spikes':False,'head_spikes':False,
    'parallel_transport_frames':True,
    'head_shift':(.28,-.57,0),'core':(-.38,-.04,1.54),
    'body_surrounds_core':True,
    'concept':'Legless eastern elemental dragon in an asymmetric airborne S, with a loose tail, open depth-separated bends around the cubic heart and a forward-projecting head',
    # Tail to neck: counter-curves and changing depths avoid a circular ring.
    'controls':[
        (-1.36,-.22,.25),(-1.46,-.18,.60),(-1.08,-.03,.83),(-.58,.24,.70),
        (.18,.47,.39),(.86,.48,.50),(1.19,.42,.99),(.97,.45,1.43),
        (.42,.60,1.69),(-.25,.68,1.86),(-.90,.48,1.80),(-1.14,.10,1.37),
        (-.82,-.25,1.02),(-.35,-.52,1.00),(.20,-.62,1.20),(.59,-.60,1.62),
        (.60,-.62,2.04),(.55,-.79,2.37),(.70,-1.05,2.48)
    ]
}
source=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\build_elemental_dragon_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
