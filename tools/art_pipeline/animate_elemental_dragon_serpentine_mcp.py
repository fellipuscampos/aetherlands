from pathlib import Path
DRAGON_ACTION_CONFIG={
    'source':'elemental_dragon_v6_animated','stem':'elemental_dragon_v7_animated','scene':'Elemental_Dragon_V7_Animated',
    'motion_file':'elemental_dragon_serpentine_motion.py.inc','remake_idle':True,'core_pulse':True,
    'minimum_skin_edge_ratio':.68,'maximum_skin_edge_ratio':1.50
}
source=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/animate_elemental_dragon_actions_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
