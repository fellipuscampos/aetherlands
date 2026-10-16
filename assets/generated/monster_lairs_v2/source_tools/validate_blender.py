"""Round-trip new GLBs and inspect saved source libraries; execute through MCP."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/monster_lairs_v2'
original=bpy.context.window.scene
previous_scenes=set(bpy.data.scenes)
checks=[]

try:
    for manifest in sorted(OUT.glob('*_lair_v2/manifest.json')):
        report=json.loads(manifest.read_text(encoding='utf-8')); stem=report['stem']; folder=manifest.parent
        with bpy.data.libraries.load(str(folder/(stem+'.blend')),link=False) as (src,dst):
            names=list(src.scenes)
            assert len(names)==1 and names[0].startswith(stem),names
            # Load the actual saved scene, inspect its editable content, and remove it afterwards.
            # Blender replaces the destination list entries with loaded Scene IDs.
            # Keep the source-name list independent for the JSON report.
            dst.scenes=list(names)
        source=dst.scenes[0]
        source_objects=list(source.objects)
        source_meshes=[o for o in source_objects if o.type=='MESH' and not o.name.startswith('STUDIO')]
        assert len(source_meshes)==report['editable_parts'],(stem,len(source_meshes))
        assert all(o.data.materials[0].node_tree for o in source_meshes)
        image_nodes=[node for node in source_meshes[0].data.materials[0].node_tree.nodes if node.type=='TEX_IMAGE']
        assert len(image_nodes)==2 and all(n.image.packed_file for n in image_nodes)
        source_scene_name=source.name
        bpy.data.scenes.remove(source)
        for obj in source_objects:
            if obj.users==0: bpy.data.objects.remove(obj)
        test=bpy.data.scenes.new('LAIR_ROUNDTRIP_'+stem)
        bpy.context.window.scene=test
        bpy.ops.import_scene.gltf(filepath=str(folder/(stem+'.glb')),import_pack_images=True)
        meshes=[o for o in test.objects if o.type=='MESH']
        assert len(meshes)==1 and not any(o.type in ('CAMERA','LIGHT') for o in test.objects)
        obj=meshes[0]; obj.data.calc_loop_triangles()
        assert len(obj.data.loop_triangles)==report['triangles']
        coords=[obj.matrix_world@v.co for v in obj.data.vertices]
        low=[min(v[i] for v in coords) for i in range(3)]
        high=[max(v[i] for v in coords) for i in range(3)]
        expected=report['source_bounds_xyz']
        assert max(abs(low[i]-expected[0][i]) for i in range(3))<1e-5
        assert max(abs(high[i]-expected[1][i]) for i in range(3))<1e-5
        assert len(obj.data.materials)==1
        checks.append(dict(kind=report['kind'],result='PASS',source_scenes=names,
            editable_parts=len(source_meshes),packed_source_images=2,imported_meshes=1,
            imported_triangles=len(obj.data.loop_triangles),bounds_match=True,studio_exported=False))
        objects=list(test.objects)
        bpy.context.window.scene=original
        bpy.data.scenes.remove(test)
        for obj in objects:
            if obj.users==0: bpy.data.objects.remove(obj)
    assert len(checks)==12
    result=dict(status='PASS',method='Live Blender MCP source load + GLB round-trip',assets=checks,
        original_scene_restored=True,existing_scenes_preserved=True)
    (OUT/'blender_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
finally:
    bpy.context.window.scene=original
    assert previous_scenes.issubset(set(bpy.data.scenes))
