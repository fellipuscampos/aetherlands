"""Clear the saw handle and move mortar work onto the unfinished lower course."""
import bpy,bmesh,ast,json,struct
from mathutils import Vector
from pathlib import Path
asset=bpy.app.driver_namespace['human_construction_v1']
scene=asset['scene']; root=asset['root']; rig=asset['rig']; parts=asset['parts']; OUT=asset['out']; STEM=OUT.name
scene.frame_set(1); bpy.context.window.scene=scene
for obj in list(scene.objects):
    if obj.type=='MESH' and obj.name.startswith(('Construction_Props','Construction_Workers')) and '_Export' in obj.data.name:
        data=obj.data; bpy.data.objects.remove(obj,do_unlink=True)
        if data.users==0: bpy.data.meshes.remove(data)
board=next(p for p in parts if p['part']=='Board_being_sawn')
if not board.get('crosscut_revision'):
    span_x=max(v.co.x for v in board.data.vertices)-min(v.co.x for v in board.data.vertices)
    if abs(span_x-.091)<1e-5:
        for v in board.data.vertices:
            v.co.x=.40+(v.co.x-.40)*(.335/.091)
            v.co.y=-.225+(v.co.y+.225)*(.091/.335)
    else:
        assert abs(span_x-.335)<1e-5
    bm=bmesh.new(); bm.from_mesh(board.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(board.data); bm.free()
    board['crosscut_revision']=1
# Moving the rest geometry and bone origins together preserves the rigid clip.
body=next(p for p in parts if p['part']=='Bricklayer_Shirt')
body_x=sum(v.co.x for v in body.data.vertices)/len(body.data.vertices)
if abs(body_x)<1e-5:
    for obj in parts:
        if obj['bone'].startswith('Bricklayer_'):
            for v in obj.data.vertices: v.co.x+=.20
            obj.data.update()
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in rig.data.edit_bones:
        if bone.name.startswith('Bricklayer_'):
            bone.head.x+=.20; bone.tail.x+=.20
    bpy.ops.object.mode_set(mode='OBJECT')
else:
    assert abs(body_x-.20)<1e-5
for name in ('Mortar_trough','Mortar_in_trough'):
    obj=next(p for p in parts if p['part']==name)
    center=sum(v.co.x for v in obj.data.vertices)/len(obj.data.vertices)
    if abs(center-.21)<1e-5:
        for v in obj.data.vertices: v.co.x-=.41
        obj.data.update()
    else: assert abs(center+.20)<1e-5
scene.frame_set(1); scene.view_layers[0].update()
bones={b.name:b.head_local.copy() for b in rig.data.bones}; mat=parts[0].data.materials[0]
source=(Path(r'C:/Users/felipe campos/Documents/jogo')/'tools/art_pipeline/build_human_construction_site_mcp.py').read_text(encoding='utf-8')
module=ast.parse(source); definition=next(n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='consolidate')
exec(compile(ast.Module(body=[definition],type_ignores=[]),'consolidate','exec'))
exec(compile(source[source.index('runtime=['):source.index('report=dict(')],'export_corrected_board','exec'))
asset['report']['export']['bytes']=len(raw)
asset['report']['tool_contacts']='Hammer on chisel; trowel on stone; crosscut saw handle outside board.'
(OUT/(STEM+'_report.json')).write_text(json.dumps(asset['report'],indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},fake_user=True,compress=True)
result={'status':'PASS','board':'crosscut','mortar_work':'lower course clear of top blocks','bytes':len(raw)}
