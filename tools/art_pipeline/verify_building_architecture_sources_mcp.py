"""Inspect completed editable sources in the live Blender session."""
import bpy
import hashlib
import json
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
entries=json.loads((ROOT/'art_source/building_architecture_review/completed.json').read_text(encoding='utf-8'))
plurals={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}
roof_colors={'human':[49,79,127],'elf':[48,122,88],'dwarf':[67,82,89],'orc':[130,58,39]}
verified=[]
for entry in entries:
    folder=entry['asset']; out=ROOT/'assets/generated'/plurals[entry['civilization']]/'buildings'/folder
    report=json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
    name=report['name']; scene=bpy.data.scenes[name]
    assert scene.get('architecture_revision')==1
    assert list(scene['palette_overrides']['roof'])==roof_colors[entry['civilization']]
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio' and not o.get('preview_only')]
    assert len(parts)==report['editable_parts'],folder
    triangles=0
    for obj in parts:
        assert obj.location.length<1e-7 and all(abs(s-1)<1e-7 for s in obj.scale),obj.name
        assert len(obj.data.uv_layers.active.data)==len(obj.data.loops)
        assert not obj.modifiers
        obj.data.calc_loop_triangles()
        triangles+=len(obj.data.loop_triangles)
    assert triangles==report['triangles'],(folder,triangles)
    material=parts[0].data.materials[0]
    textures=[node.image for node in material.node_tree.nodes if node.type=='TEX_IMAGE']
    assert len(textures)==2
    for image in textures:
        assert image.packed_file
        file=out/Path(image.filepath_raw).name
        assert hashlib.sha256(bytes(image.packed_file.data)).hexdigest()==hashlib.sha256(file.read_bytes()).hexdigest(),folder
    with bpy.data.libraries.load(str(out/(folder+'.blend')),link=False) as (available,loaded):
        assert available.scenes==[name],(folder,available.scenes)
    verified.append({'asset':folder,'editable_parts':len(parts),'triangles':triangles,'packed_textures':True,'isolated_scene':True})
summary={'status':'PASS','verified':len(verified),'assets':verified,'method':'live Blender MCP'}
(ROOT/'docs/building_architecture_source_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
result={'status':'PASS','verified_sources':len(verified),'method':'live Blender MCP'}
