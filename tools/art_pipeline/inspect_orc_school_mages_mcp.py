"""Check the actual original orc head, face, tusks and native body scale."""
import bpy,ast,json,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/orc_school_mages_review'
assets=bpy.app.driver_namespace['orc_school_mage_assets_v1']; base=bpy.app.driver_namespace['orc_school_mage_base']
original=next(o for o in base.objects if o.get('part')=='Head')
source_img=next(n.image for n in original.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
src_pixels=np.rint(np.array(source_img.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
source_uvs=[[list(original.data.uv_layers.active.data[i].uv) for i in f.loop_indices] for f in original.data.polygons]
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
ns=dict(np=np,hashlib=hashlib,RACE='orc',P={'skin':(99,125,65)})
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='paint_tile': exec(compile(ast.get_source_segment(source,node),'<original_orc_face_sampling>','exec'),ns)
source=(ROOT/'tools/art_pipeline/build_orc_school_mages_mcp.py').read_text(encoding='utf-8')
paint_ns=dict(np=np,HOODS={'infernal':(102,48,40),'necromancy':(86,59,105)})
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='paint_head': exec(compile(ast.get_source_segment(source,node),'<orc_head_paint>','exec'),paint_ns)
checks=[]
for a in assets:
    head=a['body']['Head']; uv=head.data.uv_layers.active.data; face=head.data.polygons[2]
    image=next(n.image for n in a['material'].node_tree.nodes if n.type=='TEX_IMAGE' and 'albedo' in n.image.name)
    pixels=np.rint(np.array(image.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
    coords=np.array([list(uv[i].uv) for i in face.loop_indices])*512; lo=np.floor(coords.min(axis=0)).astype(int)
    w,h=np.ceil(coords.max(axis=0)-lo-.5-.00002).astype(int)+1
    n=face.normal; up=Vector((0,0,1)); up-=n*up.dot(n); up.normalize(); right=up.cross(n).normalized()
    points=[Vector((head.data.vertices[head.data.loops[i].vertex_index].co.dot(right),head.data.vertices[head.data.loops[i].vertex_index].co.dot(up))) for i in face.loop_indices]
    minimum=Vector((min(p.x for p in points),min(p.y for p in points))); points=[p-minimum for p in points]
    ns['PRESERVED']={head.name:dict(pixels=src_pixels,uvs=source_uvs)}
    sampled=ns['paint_tile'](head,face,w,h,points)
    rgba=np.concatenate((sampled,np.full((h,w,1),255,np.uint8)),axis=-1)
    expected=paint_ns['paint_head'](rgba,2,a['report']['school'])[0]
    assert np.array_equal(expected,pixels[lo[1]:lo[1]+h,lo[0]:lo[0]+w]),(a['report']['school'],'Original facial pixel layout')
    error=0
    for obj in a['parts']:
        if obj['part']=='Head' or obj['part'].startswith(('ElfEar','Tusk','Brow')):
            src=next(o for o in base.objects if o.get('part')==obj['part'])
            error=max(error,max((a['head_pose'].inverted()@v.co-src.matrix_world@s.co).length for v,s in zip(obj.data.vertices,src.data.vertices)))
    assert error<1e-6,('Original orc facial geometry',error)
    assert sum(o['part'].startswith('ElfEar') for o in a['parts'])==6
    assert sum(o['part'].startswith('Tusk') for o in a['parts'])==4
    assert sum(o['part'].startswith('Brow') for o in a['parts'])==2
    beards=[o for o in a['parts'] if o['part'].startswith(('Orc_chin_beard','Orc_cheek_beard'))]
    assert len(beards)==3
    sat=bpy.app.driver_namespace['orc_school_mage_sat_v1']
    assert all(sat(b,head) for b in beards)
    assert all(not sat(b,t) for b in beards for t in a['parts'] if t['part'].startswith('Tusk'))
    assert not any(o['part'].startswith(('Leaf_hem','Leaf_chest','Arcane_rune','Hood_side','Hood_crown','Block_beard')) for o in a['parts'])
    edge_error=0
    for name,obj in a['body'].items():
        src=next(o for o in base.objects if o.get('part')==name)
        for e,se in zip(obj.data.edges,src.data.edges):
            actual=(obj.data.vertices[e.vertices[0]].co-obj.data.vertices[e.vertices[1]].co).length
            old=(src.matrix_world@src.data.vertices[se.vertices[0]].co-src.matrix_world@src.data.vertices[se.vertices[1]].co).length
            edge_error=max(edge_error,abs(actual-old))
    assert edge_error<1e-6,('Native orc proportions',edge_error)
    if a['report']['school']=='elementalism':
        stem=next(o for o in a['parts'] if o['part']=='Element_focus_stem')
        assert bpy.app.driver_namespace['orc_school_mage_sat_v1'](stem,a['staff'])
    a['report']['style_validation'].update(actual_face_pixels_verified=True,actual_head_size_verified=True,actual_ears_verified=True,actual_tusks_verified=True,native_body_proportions_verified=True,facial_geometry_max_error_m=error,body_edge_length_max_error_m=edge_error)
    checks.append(dict(school=a['report']['school'],status='PASS',original_face_pixels=True,original_head_size=True,ears=6,tusks=4,native_proportions=True,beard_parts=3,beard_tusks_clear=True,beard_attached_to_jaw=True))
(WORK/'head_validation.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
result=dict(status='PASS',models=6,original_heads=True,original_faces=True,ears=36,tusks=24,native_body_proportions=True)
