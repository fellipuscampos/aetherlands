"""Rebuild the rejected dragon's silhouette and pixel paint against the reference."""
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
DRAGON_STEM='dark_red_dragon_v2'
DRAGON_NAME='Dark_Red_Dragon_V2'
DRAGON_REBUILD=globals().get('DRAGON_REBUILD',False)
source=(ROOT/'tools/art_pipeline/build_dark_red_dragon_mcp.py').read_text(encoding='utf-8')
start=source.index("bone('chest',")
end=source.index('# Native 3 m',start)
geometry=(ROOT/'tools/art_pipeline/dark_red_dragon_v2_geometry.py.inc').read_text(encoding='utf-8')
source=source[:start]+geometry+'\n'+source[end:]
start=source.index("palette={'body':")
end=source.index('# Reuse the established packed-atlas',start)
paint=(ROOT/'tools/art_pipeline/dark_red_dragon_v2_paint.py.inc').read_text(encoding='utf-8')
source=source[:start]+paint+'\n'+source[end:]
source=source.replace("start=helper_source.index('images=[]')", "helper_source=helper_source.replace('image.save(); image.pack(); images.append(image)', 'image.save(); path=image.filepath_raw; bpy.data.images.remove(image); image=bpy.data.images.load(path,check_existing=False); image.pack(); images.append(image)')\nstart=helper_source.index('images=[]')")
source=source.replace("scene.cycles.samples=32","scene.cycles.samples=24")
source=source.replace("(6,-10,5.2)","(6,-10,5.8)")
source=source.replace("camera_data.ortho_scale=5.0","camera_data.ortho_scale=4.0")
exec(compile(source,'dark_red_dragon_v2','exec'),globals())
