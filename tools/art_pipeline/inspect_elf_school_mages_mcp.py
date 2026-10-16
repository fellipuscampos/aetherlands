"""Check actual head sizes, original facial pixels, ears, and staff continuity."""
import bpy,ast,json,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/elf_school_mages_review'
assets=bpy.app.driver_namespace['elf_school_mage_assets_v1']; base=bpy.app.driver_namespace['elf_school_mage_base']
original=next(o for o in base.objects if o.get('part')=='Head')
source_img=next(n.image for n in original.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
src_pixels=np.rint(np.array(source_img.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
source_uvs=[[list(original.data.uv_layers.active.data[i].uv) for i in f.loop_indices] for f in original.data.polygons]
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
ns=dict(np=np,hashlib=hashlib,RACE='elf',P={'skin':(237,221,209)})
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='paint_tile': exec(compile(ast.get_source_segment(source,node),'<original_face_sampling>','exec'),ns)
source=(ROOT/'tools/art_pipeline/build_elf_school_mages_mcp.py').read_text(encoding='utf-8')
paint_ns=dict(np=np,HOODS={'infernal':(102,48,40),'necromancy':(86,59,105)})
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='paint_head': exec(compile(ast.get_source_segment(source,node),'<elf_head_paint>','exec'),paint_ns)
checks=[]
for a in assets:
    head=a['body']['Head']; uv=head.data.uv_layers.active.data; face=head.data.polygons[2]
    image=next(n.image for n in a['material'].node_tree.nodes if n.type=='TEX_IMAGE' and 'albedo' in n.image.name)
    pixels=np.rint(np.array(image.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
    coords=np.array([list(uv[i].uv) for i in face.loop_indices])*512; lo=np.floor(coords.min(axis=0)).astype(int)
    w,h=np.ceil(coords.max(axis=0)-lo-.5-.00002).astype(int)+1
    # Recreate projected coordinates as used by the UV packer, avoiding rounded UVs.
    n=face.normal; up=Vector((0,0,1)); up-=n*up.dot(n); up.normalize(); right=up.cross(n).normalized()
    points=[Vector((head.data.vertices[head.data.loops[i].vertex_index].co.dot(right),head.data.vertices[head.data.loops[i].vertex_index].co.dot(up))) for i in face.loop_indices]
    minimum=Vector((min(p.x for p in points),min(p.y for p in points))); points=[p-minimum for p in points]
    ns['PRESERVED']={head.name:dict(pixels=src_pixels,uvs=source_uvs)}
    sampled=ns['paint_tile'](head,face,w,h,points)
    rgba=np.concatenate((sampled,np.full((h,w,1),255,np.uint8)),axis=-1)
    expected=paint_ns['paint_head'](rgba,2,a['report']['school'])[0]
    actual=pixels[lo[1]:lo[1]+h,lo[0]:lo[0]+w]
    assert np.array_equal(expected,actual),(a['report']['school'],'Original facial pixel layout')
    assert max(abs((head.data.vertices[e.vertices[0]].co-head.data.vertices[e.vertices[1]].co).length-.262702703) for e in head.data.edges)<1e-6
    assert len([o for o in a['parts'] if o['part'].startswith('ElfEar')])==6
    assert not any('beard' in o['part'].lower() or o['part'].startswith(('Hood_side','Hood_back','Hood_crown','Grey_temple')) for o in a['parts'])
    if a['report']['school']=='elementalism':
        stem=next(o for o in a['parts'] if o['part']=='Element_focus_stem')
        assert bpy.app.driver_namespace['elf_school_mage_sat_v1'](stem,a['staff']),'Floating elemental focus'
    a['report']['style_validation'].update(actual_face_pixels_verified=True,actual_head_size_verified=True,actual_ears_verified=True)
    checks.append(dict(school=a['report']['school'],status='PASS',original_head_size=True,original_face_pixels=True,ears=6))
(WORK/'head_validation.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
result=dict(status='PASS',models=6,heads_original=True,faces_original=True,ears=36,elemental_focus_connected=True)
