"""Clean anatomical rebuild: matched wings, coherent jaw, four untwisted limbs."""
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
DRAGON_STEM='dark_red_dragon_v3'
DRAGON_NAME='Dark_Red_Dragon_V3'
source=(ROOT/'tools/art_pipeline/build_dark_red_dragon_mcp.py').read_text(encoding='utf-8')
start=source.index("bone('chest',"); end=source.index('# Native 3 m',start)
geometry=(ROOT/'tools/art_pipeline/dark_red_dragon_v3_geometry.py.inc').read_text(encoding='utf-8')
source=source[:start]+geometry+'\n'+source[end:]
start=source.index("palette={'body':"); end=source.index('# Reuse the established packed-atlas',start)
paint=(ROOT/'tools/art_pipeline/dark_red_dragon_v2_paint.py.inc').read_text(encoding='utf-8')
source=source[:start]+paint+'\n'+source[end:]
source=source.replace("start=helper_source.index('images=[]')", "helper_source=helper_source.replace('image.save(); image.pack(); images.append(image)', 'image.save(); path=image.filepath_raw; bpy.data.images.remove(image); image=bpy.data.images.load(path,check_existing=False); image.colorspace_settings.name=\"sRGB\"; image.pack(); images.append(image)')\nstart=helper_source.index('images=[]')")
source=source.replace('scene.cycles.samples=32','scene.cycles.samples=24')
source=source.replace('camera_data.ortho_scale=5.0','camera_data.ortho_scale=5.0')
source=source.replace("area.spaces.active.shading.type='MATERIAL'","area.spaces.active.shading.type='MATERIAL'\n        area.spaces.active.overlay.show_overlays=False")
source=source.replace("'standalone_asset':True,", "'standalone_asset':True,'core':False,'mirror_symmetric_anatomy':True,")
exec(compile(source,'dark_red_dragon_v3','exec'),globals())
