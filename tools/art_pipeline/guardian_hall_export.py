"""Export eight architectural mesh groups, verify binary GLB and save editable source."""
import bpy
import bmesh
import hashlib
import json
import struct
from pathlib import Path

exec(Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\guardian_hall_state.py').read_text(encoding='utf-8'))
st = bpy.app.driver_namespace['guardian_hall']
scene, root, parts = st['scene'], st['root'], st['parts']
OUT, NAME = Path(st['out']), st['name']
bpy.context.window.scene = scene
for obj in parts:
    assert obj.location.length < 1e-7 and all(abs(s - 1) < 1e-7 for s in obj.scale)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    assert all(edge.is_manifold for edge in bm.edges), obj.name
    bm.free()
for im in st['images']:
    assert bytes(im.packed_file.data) == Path(im.filepath_raw).read_bytes(), im.name

temporary = bpy.data.collections.new(NAME + '_EXPORT_TEMP')
scene.collection.children.link(temporary)
meshes = []
try:
    for label, collection in st['groups'].items():
        if label == '09_STUDIO':
            continue
        source = [o for o in collection.objects if o in parts]
        if not source:
            continue
        copies = []
        for obj in source:
            copy = obj.copy()
            copy.data = obj.data.copy()
            for key in list(copy.keys()):
                if key.startswith('source_paint_'):
                    del copy[key]
            temporary.objects.link(copy)
            copies.append(copy)
        orphan_data = [o.data for o in copies[1:]]
        with bpy.context.temp_override(active_object=copies[0], selected_editable_objects=copies, selected_objects=copies):
            bpy.ops.object.join()
        obj = copies[0]
        obj.name = NAME + '_' + label[3:].title()
        obj.data.name = obj.name + '_Mesh'
        obj.parent = root
        meshes.append(obj)
        for data in orphan_data:
            if data.users == 0:
                bpy.data.meshes.remove(data)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes + [root]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    glb = OUT / (OUT.name + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB',
        use_selection=True, use_active_scene=True, export_animations=False,
        export_skins=False, export_yup=True, export_cameras=False, export_lights=False,
        export_extras=True, export_materials='EXPORT')
finally:
    for obj in list(temporary.objects):
        data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if data.users == 0:
            bpy.data.meshes.remove(data)
    bpy.data.collections.remove(temporary)

raw = glb.read_bytes()
magic, version, length = struct.unpack_from('<III', raw)
assert magic == 0x46546C67 and version == 2 and length == len(raw)
json_length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20 + json_length])
binary = raw[28 + json_length:]
assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
assert 'KHR_lights_punctual' not in doc.get('extensionsUsed', [])
assert len(doc['meshes']) == len(meshes) and len(doc['materials']) == 1
assert len(doc['images']) == 2
triangles = sum(doc['accessors'][p['indices']]['count'] // 3 for m in doc['meshes'] for p in m['primitives'])
assert triangles == st['report']['triangles']
assert all(s.get('magFilter') == 9728 and s.get('minFilter') in (9728, 9984, 9986) for s in doc['samplers'])
embedded = []
for im in doc['images']:
    bv = doc['bufferViews'][im['bufferView']]
    png = binary[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    digest = hashlib.sha256(png).hexdigest()
    expected = {hashlib.sha256(Path(x.filepath_raw).read_bytes()).hexdigest() for x in st['images']}
    assert digest in expected, im
    embedded.append({'image': im['name'], 'bytes': len(png), 'sha256': digest})

st['report']['export'] = {
    'file': glb.name, 'bytes': len(raw), 'meshes': len(doc['meshes']),
    'primitives': sum(len(m['primitives']) for m in doc['meshes']),
    'triangles': triangles, 'materials': 1,
    'nearest_samplers': doc['samplers'], 'embedded_images_verified': embedded,
    'includes_studio': False, 'includes_reference_unit': False}
(OUT / (OUT.name + '_report.json')).write_text(json.dumps(st['report'], ensure_ascii=False, indent=2), encoding='utf-8')
# Save only this scene, with its separate source objects and packed textures.
# Do not rename or overwrite the user's current blend file.
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.data.libraries.write(str(OUT / (OUT.name + '.blend')), {scene},
    path_remap='RELATIVE', fake_user=True, compress=True)
result = {'glb': str(glb), 'bytes': len(raw), 'meshes': len(doc['meshes']),
          'triangles': triangles, 'embedded_images_verified': True}
