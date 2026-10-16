"""Read back native Blender sources via MCP and verify geometry, horns and animation tracks."""
import json
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / 'tools/art_pipeline') not in sys.path: sys.path.insert(0, str(ROOT / 'tools/art_pipeline'))
from orc_siege_assets import OUT, SIEGE_ASSETS

actions_before = set(bpy.data.actions)
checks = []
for row in SIEGE_ASSETS:
    path = OUT / row['stem'] / (row['stem'] + '.blend')
    with bpy.data.libraries.load(str(path), link=False) as (source, loaded):
        assert len(source.actions) == (4 if row['tier'] == 0 else 5), (row['stem'], source.actions)
        loaded.scenes = source.scenes
    assert len(loaded.scenes) == 1
    scene = loaded.scenes[0]
    parts = [obj for obj in scene.objects if obj.get('part')]
    rigs = [obj for obj in scene.objects if obj.type == 'ARMATURE']
    roots = [obj for obj in scene.objects if obj.type == 'EMPTY' and obj.parent is None]
    assert len(rigs) == len(roots) == 1
    rig = rigs[0]; root = roots[0]
    assert root['race'] == 'orc' and root['family'] == 'siege'
    assert np.allclose(root.scale, (1, 1, 1)) and np.allclose(root.location, (0, 0, 0))
    assert rig.animation_data and rig.data.animation_data is None
    assert rig.animation_data.action is None
    tracks = rig.animation_data.nla_tracks
    assert len(tracks) == (4 if row['tier'] == 0 else 5)
    assert scene.frame_end > 200
    assert all(len(tr.strips) == 1 and tr.strips[0].extrapolation == 'NOTHING' for tr in tracks)
    materials = set(); triangles = 0
    for obj in parts:
        assert obj.animation_data is None and obj.data.animation_data is None
        assert obj.parent == rig
        assert obj['rig_bone'] in rig.data.bones
        assert obj.modifiers[0].type == 'ARMATURE' and obj.modifiers[0].object == rig
        assert np.allclose(np.array(obj.matrix_basis), np.eye(4))
        bm = bmesh.new(); bm.from_mesh(obj.data)
        assert all(edge.is_manifold for edge in bm.edges), obj.name
        assert all(face.calc_area() > 1e-10 for face in bm.faces), obj.name
        bm.free()
        assert obj.data.uv_layers.active is not None
        if obj['part'] in ('LoadedBoulder', 'SlingBoulder') or obj['part'].startswith('StoredSquareShot_'):
            coords = np.array([tuple(v.co) for v in obj.data.vertices])
            assert len(obj.data.vertices) == 8 and len(obj.data.polygons) == 6
            extents = coords.max(axis=0) - coords.min(axis=0)
            assert np.allclose(extents, extents[0], atol=.000001), 'Shot must be cubic'
        if obj['surface'] == 'ivory': assert 'horn' in obj['part'].lower() or 'tusk' in obj['part'].lower()
        assert 'bone' not in obj['part'].lower()
        assert obj['part'] not in ('BoneBrow', 'BoneCheek_-1', 'BoneCheek_1', 'BoneNose',
                                    'BoneTooth_-0.14', 'BoneTooth_0', 'BoneTooth_0.14',
                                    'EyeSlit_-1', 'EyeSlit_1')
        for vertex in obj.data.vertices:
            assert len(vertex.groups) == 1 and abs(vertex.groups[0].weight - 1) < .00001
        triangles += sum(len(face.vertices) - 2 for face in obj.data.polygons)
        materials.update(obj.data.materials)
    images = set()
    for mat in materials:
        assert mat.use_nodes
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                assert node.image.packed_file and node.interpolation == 'Closest'
                images.add(node.image)
    assert len(images) == 1
    report = json.loads((OUT / row['stem'] / (row['stem'] + '_report.json')).read_text(encoding='utf-8'))
    assert len(parts) == report['geometry']['parts'] and triangles == report['geometry']['triangles']
    assert len(rig.data.bones) == len(report['rig']['bones'])
    assert {tr.name for tr in tracks} == set(report['clips'])
    for tr in tracks:
        action = tr.strips[0].action
        assert abs((action.frame_range[1] - action.frame_range[0]) / 24 - report['clips'][tr.name]) < .0001
        assert bool(action['loop']) == tr.name.endswith(('_Idle', '_Walk'))
    checks.append(dict(stem=row['stem'], status='PASS', editable_parts=len(parts), triangles=triangles,
                       bones=len(rig.data.bones), native_actions=len(tracks), packed_atlas=True,
                       transforms_applied=True, closed_meshes=True, rigid_weights=True))
    bpy.data.scenes.remove(scene)
# Actions were read from the saved native sources; leave original scene data intact.
report = dict(status='PASS', models=4, clips=sum(a['native_actions'] for a in checks), assets=checks)
(ROOT / 'docs/orc_siege_native_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
result = report
