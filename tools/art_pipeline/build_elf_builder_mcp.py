"""Derive an elven worker from the approved elf settler through live Blender MCP."""
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
BUILDER_CONFIG={
    'race':'elf',
    'family':'elves',
    'palette':{'canvas':(177,181,131),'canvas_dark':(132,143,92)},
    'removed':'backpack, bedroll, travelling straps, seed case, walking staff',
}
try:
    exec((ROOT/'tools/art_pipeline/build_human_builder_mcp.py').read_text(encoding='utf-8'),globals())
finally:
    globals().pop('BUILDER_CONFIG',None)
