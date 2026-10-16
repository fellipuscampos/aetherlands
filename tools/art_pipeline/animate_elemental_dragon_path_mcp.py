from pathlib import Path
DRAGON_ACTION_CONFIG={
    'source':'elemental_dragon_v5_animated','stem':'elemental_dragon_v9_animated','scene':'Elemental_Dragon_V9_Animated',
    'motion_file':'elemental_dragon_path_motion.py.inc','remake_idle':True,'core_pulse':True,
    'rig_setup_file':'elemental_dragon_ring_skin.py.inc',
    'minimum_skin_edge_ratio':.15,'maximum_skin_edge_ratio':2.50,
    'minimum_ground_clearance':.08,'path_following':True,
    'clip_durations':{'idle':12.,'walk':6.}
}
source=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/animate_elemental_dragon_actions_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
