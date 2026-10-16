"""Derive a dwarven builder from the race's approved settler via live MCP."""
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
BUILDER_CONFIG={
    'race':'dwarf','family':'dwarves',
    'hammer_scale':0.95,
    'hammer_handle_size':(.043,.043,.40),
    'hammer_head_size':(.10,.25,.095),
    'palette':{'canvas':(157,101,57),'canvas_dark':(117,74,41),
               'leather':(111,75,46),'wood':(120,85,46),
               'iron':(101,110,117),'iron_light':(169,178,183)},
    'removed':'backpack, toolbox, bedroll, travelling straps, pickaxe, lantern, old apron panels',
}
try:
    exec((ROOT/'tools/art_pipeline/build_human_builder_mcp.py').read_text(encoding='utf-8'),globals())
finally:
    globals().pop('BUILDER_CONFIG',None)
