"""Build the orc worker from its own approved settler in live Blender MCP."""
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
BUILDER_CONFIG={
    'race':'orc',
    'family':'orcs',
    'hammer_scale':1.25,
    'palette':{'canvas':(118,88,60),'canvas_dark':(91,67,45),
               'leather':(121,86,52),'wood':(113,80,43),
               'iron':(101,109,112),'iron_light':(159,168,171)},
    'removed':'backpack, bedroll, travelling straps, seed sack, stone mallet, tunic lacing',
}
try:
    exec((ROOT/'tools/art_pipeline/build_human_builder_mcp.py').read_text(encoding='utf-8'),globals())
finally:
    globals().pop('BUILDER_CONFIG',None)
