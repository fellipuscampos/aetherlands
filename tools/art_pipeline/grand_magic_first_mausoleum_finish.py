"""Close the two small crown gaps caught before saving the first new mausoleum."""
import bpy
from pathlib import Path
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
st=bpy.app.driver_namespace['guardian_hall']
scene=st['scene']
assert scene.name=='Necromancy_Ritual_Hex_V1' and scene.get('grand_magic')
if not scene.get('obelisk_crown_seated'):
    for obj in st['parts']:
        if obj['part'].startswith('Mausoleum_Obelisk_Crown_'):
            i=int(obj['part'].rsplit('_',1)[-1])
            for vertex in obj.data.vertices:
                vertex.co.z-=.008*i
            obj.data.update()
    scene['obelisk_crown_seated']=True
scope={'AUDIT_RUN':False}
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'),scope)
scene['physical_attachment_remaining']=[o['part'] for o in scope['detached'](st['parts'])]
assert not scene['physical_attachment_remaining']
exec((PIPELINE/'grand_magic_finish.py').read_text(encoding='utf-8'))
