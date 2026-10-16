from pathlib import Path
DRAGON_ACTION_CONFIG={
    'source':'elemental_dragon_v5_animated','stem':'elemental_dragon_v10_animated','scene':'Elemental_Dragon_V10_Animated',
    'motion_file':'elemental_dragon_states_motion.py.inc','remake_idle':True,'core_pulse':True,
    'rig_setup_file':'elemental_dragon_ring_skin.py.inc',
    'minimum_skin_edge_ratio':.10,'maximum_skin_edge_ratio':4.,
    'minimum_ground_clearance':.08,
    'animation_layout':{'idle':'upright_subtle_zigzag','walk':'open_serpent_wave','spell':'approved_v9_walk_with_entry_and_recovery','attack':'preserved_v9_attack'},
    'clip_durations':{'idle':6.,'walk':4.,'spell':8.}
}
source=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/animate_elemental_dragon_actions_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
