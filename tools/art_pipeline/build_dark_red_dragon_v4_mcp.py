"""Silhouette revision based on limb, head, tail and wing construction of the reference."""
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
DRAGON_STEM='dark_red_dragon_v4'
DRAGON_NAME='Dark_Red_Dragon_V4'
source=(ROOT/'tools/art_pipeline/build_dark_red_dragon_mcp.py').read_text(encoding='utf-8')
start=source.index("bone('chest',"); end=source.index('# Native 3 m',start)
geometry=(ROOT/'tools/art_pipeline/dark_red_dragon_v4_geometry.py.inc').read_text(encoding='utf-8')
source=source[:start]+geometry+'\n'+source[end:]
start=source.index("palette={'body':"); end=source.index('# Reuse the established packed-atlas',start)
paint=(ROOT/'tools/art_pipeline/dark_red_dragon_v2_paint.py.inc').read_text(encoding='utf-8')
paint=paint.replace("rng=np.random.default_rng(784117+index); yy,xx=np.indices((h,w))", """rng=np.random.default_rng(784117+index); yy,xx=np.indices((h,w))
    label=it['obj']['part']; face=it['obj'].data.polygons[it['face']]
    # Ventral scutes and the chin are painted on existing faces, never slabs.
    if label in ('Compact_torso','Short_arched_neck') and face.normal.z<-.40:
        kind='belly'; base=np.array(palette[kind],dtype=float)
    if label=='Lower_jaw' and face.normal.z<-.55:
        kind='belly'; base=np.array(palette[kind],dtype=float)
    if label=='Lower_jaw' and face.normal.z>.55:
        kind='mouth'; base=np.array(palette[kind],dtype=float)
    if label=='Upper_muzzle' and face.normal.z<-.55:
        kind='mouth'; base=np.array(palette[kind],dtype=float)""")
paint=paint.replace("    # Save palette bytes unchanged", """    if label=='Lower_jaw' and abs(face.normal.z)<.55:
        chin=yy<max(1,h*.22)
        rgb[chin]=np.array(palette['belly'],dtype=float)
        rgb[chin & (yy%8==0)]=np.array(palette['belly'],dtype=float)*.80
    # Save palette bytes unchanged""")
source=source[:start]+paint+'\n'+source[end:]
source=source.replace("start=helper_source.index('images=[]')", "helper_source=helper_source.replace('image.save(); image.pack(); images.append(image)', 'image.save(); path=image.filepath_raw; bpy.data.images.remove(image); image=bpy.data.images.load(path,check_existing=False); image.colorspace_settings.name=\"sRGB\"; image.pack(); images.append(image)')\nstart=helper_source.index('images=[]')")
source=source.replace('scene.cycles.samples=32','scene.cycles.samples=24')
source=source.replace('camera_data.ortho_scale=5.0','camera_data.ortho_scale=5.5')
source=source.replace("area.spaces.active.shading.type='MATERIAL'","area.spaces.active.shading.type='MATERIAL'\n        area.spaces.active.overlay.show_overlays=False")
source=source.replace("'standalone_asset':True,", "'standalone_asset':True,'core':False,'ventral_slabs':False,'continuous_wing_shells':2,'wing_structure_in_surface_plane':True,")
source=source.replace("'out':OUT}","'out':OUT,'wing_surfaces':wing_surfaces,'wing_structure':wing_structure,'native_scale':factor}")
exec(compile(source,'dark_red_dragon_v4','exec'),globals())
