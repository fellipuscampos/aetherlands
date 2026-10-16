"""Validate native kit sources, shared material, positive volume and packed atlas."""
import bpy
import bmesh
import hashlib
import json
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/nature/temperate_forest_v1'
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
previous=manifest.get('previous_scenes')
if previous is None: previous=json.loads((ROOT/'art_source/temperate_forest_review/source_scenes_before.json').read_text(encoding='utf-8'))
assert set(previous).issubset({s.name for s in bpy.data.scenes})
assert len(bpy.data.scenes)==len(previous)+10
materials=set(); images=set(); verified=[]
for report in manifest['assets']:
    scene=bpy.data.scenes[report['name']]
    objects=[o for o in scene.objects if o.get('forest_asset')]
    assert len(objects)==1
    obj=objects[0]; data=obj.data
    assert obj.location.length<1e-8 and obj.scale[:]==(1,1,1) and obj.rotation_euler[:]==(0,0,0)
    assert obj.parent.location.length<1e-8 and obj.parent.scale[:]==(1,1,1)
    assert not obj.modifiers and len(data.materials)==1
    bm=bmesh.new(); bm.from_mesh(data)
    assert all(e.is_manifold for e in bm.edges)
    volume=bm.calc_volume(signed=True)
    assert volume>0
    bm.free()
    data.calc_loop_triangles()
    assert len(data.loop_triangles)==report['triangles']
    assert all(face.area>1e-9 and not face.use_smooth for face in data.polygons)
    assert data.uv_layers.active
    material=data.materials[0]; materials.add(material)
    assert material.use_backface_culling
    textures=[n for n in material.node_tree.nodes if n.type=='TEX_IMAGE']
    assert len(textures)==1 and textures[0].interpolation=='Closest'
    image=textures[0].image; images.add(image)
    assert image.packed_file
    assert hashlib.sha256(bytes(image.packed_file.data)).hexdigest()==hashlib.sha256((OUT/'textures/forest_pixel_atlas.png').read_bytes()).hexdigest()
    source=OUT/'models'/report['asset']/(report['asset']+'.blend')
    with bpy.data.libraries.load(str(source),link=False) as (available,loaded):
        assert available.scenes==[scene.name]
    radius=max((v.co.x*v.co.x+v.co.y*v.co.y)**.5 for v in data.vertices)
    report['footprint_radius']=radius
    verified.append({'asset':report['asset'],'closed_mesh':True,'positive_volume':volume,'packed_texture':True,'isolated_source':True,'footprint_radius':radius})
assert len(materials)==len(images)==1
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
summary={'status':'PASS','verified':10,'method':'live Blender MCP','shared_materials':1,'shared_textures':1,'existing_scenes_preserved':len(previous),'assets':verified}
(ROOT/'docs/temperate_forest_source_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
result={k:v for k,v in summary.items() if k!='assets'}
