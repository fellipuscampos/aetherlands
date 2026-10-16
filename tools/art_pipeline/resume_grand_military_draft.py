"""Validate an adjusted live draft and finish it without rebuilding its geometry."""
from pathlib import Path
import bpy
import bmesh
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
st=bpy.app.driver_namespace['guardian_hall']
assert st['scene'].get('grand_military')
for obj in st['parts']:
    obj.parent=st['root']
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
scope={'AUDIT_RUN':False}
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'),scope)
unattached=[o['part'] for o in scope['detached'](st['parts'])]
st['scene']['physical_attachment_remaining']=unattached
assert not unattached,unattached
exec((PIPELINE/'grand_military_finish.py').read_text(encoding='utf-8'))
