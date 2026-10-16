"""Keep canonical export texture names after a reversible model rebuild."""
import bpy
from pathlib import Path
assets=bpy.app.driver_namespace['human_school_mage_assets_v1']
review=bpy.app.driver_namespace['human_school_mage_review_v1']
for index,a in enumerate(assets):
    stem=a['report']['stem']
    for node in a['material'].node_tree.nodes:
        if node.type!='TEX_IMAGE': continue
        im=node.image; desired=Path(im.filepath_raw).stem
        prior=bpy.data.images.get(desired)
        if prior and prior!=im: prior.name=desired+'_previous_style'
        im.name=desired
    desired=stem+'_Pixel_Material'; prior=bpy.data.materials.get(desired)
    if prior and prior!=a['material']: prior.name=desired+'_previous_style'
    a['material'].name=desired
    prior=bpy.data.objects.get(stem)
    if prior and prior!=a['root']: prior.name=stem+'_previous_style'
    a['root'].name=stem; review['roots'][index].name='Review_'+stem
result=dict(status='PASS',models=6,canonical_names_restored=True)
