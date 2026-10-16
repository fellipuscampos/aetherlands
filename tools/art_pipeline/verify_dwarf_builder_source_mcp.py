"""Check preserved dwarf beard/anatomy/pixels and the worker's hammer grip."""
from pathlib import Path
import numpy as np
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
BUILDER_CONFIG={'race':'dwarf','family':'dwarves'}
try:
    exec((ROOT/'tools/art_pipeline/verify_human_builder_source_mcp.py').read_text(encoding='utf-8'),globals())
finally:
    globals().pop('BUILDER_CONFIG',None)
reference=bpy.app.driver_namespace['dwarf_builder_reference']
originals={o['part']:o for o in reference.objects if o.type=='MESH' and o.get('part')}
for name in report['copied_parts']:
    assert len(parts[name].data.vertices)==len(originals[name].data.vertices)
    assert all((a.co-b.co).length<1e-8 for a,b in zip(parts[name].data.vertices,originals[name].data.vertices))
    assert all((a.uv*2-b.uv).length<1e-8 for a,b in zip(parts[name].data.uv_layers.active.data,originals[name].data.uv_layers.active.data))
def pixels(obj):
    image=next(n.image for n in obj.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
    values=np.empty(len(image.pixels),dtype=np.float32); image.pixels.foreach_get(values)
    return values.reshape(image.size[1],image.size[0],4)
assert np.array_equal(pixels(parts['Head'])[:512,:512],pixels(originals['Head']))
head_parts=[n for n,o in originals.items() if o.get('animation_bone')=='head']
assert all(n in parts for n in head_parts)
assert not any(n.startswith(('Pick_','Lantern_','Pack_','Backpack','Toolbox','Bedroll')) for n in parts)
assert rig.data.bones['hand_r'].parent.name=='forearm_r'
assert rig.data.bones['forearm_r'].parent.name=='upper_arm_r'
result.update(copied_geometry_preserved=True,original_pixels_preserved=True,dwarf_face_beard_cap_preserved=True,hinged_arm_hierarchy=True)
(OUT/'source_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
