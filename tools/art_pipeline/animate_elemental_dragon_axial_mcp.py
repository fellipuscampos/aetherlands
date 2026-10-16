from pathlib import Path
DRAGON_ACTION_CONFIG={
    'source':'elemental_dragon_v7_animated','stem':'elemental_dragon_v8_animated','scene':'Elemental_Dragon_V8_Animated',
    'motion_file':'elemental_dragon_axial_motion.py.inc','remake_idle':True,'core_pulse':True,
    'rig_setup_file':'elemental_dragon_ring_skin.py.inc',
    'minimum_skin_edge_ratio':.30,'maximum_skin_edge_ratio':2.30,
    'minimum_ground_clearance':.08,'axial_motion':True
}
source=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/animate_elemental_dragon_actions_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
