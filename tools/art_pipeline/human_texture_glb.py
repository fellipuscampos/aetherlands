"""Replace embedded PNG bytes without exporting meshes, rigs or animations."""
import copy
import hashlib
import json
import struct


def read_glb(raw):
    assert raw[:4] == b'glTF' and struct.unpack_from('<II', raw, 4) == (2, len(raw))
    chunks = []
    offset = 12
    while offset < len(raw):
        size, kind = struct.unpack_from('<II', raw, offset)
        chunks.append((kind, raw[offset + 8:offset + 8 + size]))
        offset += size + 8
    assert [kind for kind, data in chunks] == [0x4E4F534A, 0x004E4942]
    return json.loads(chunks[0][1]), chunks[1][1]


def image_bytes(doc, binary, image):
    view = doc['bufferViews'][image['bufferView']]
    start = view.get('byteOffset', 0)
    return binary[start:start + view['byteLength']]


def replace_images(raw, replacements):
    before, binary = read_glb(raw)
    doc = copy.deepcopy(before)
    binary = bytearray(binary[:doc['buffers'][0]['byteLength']])
    changed_views = set()
    found = set()
    for image in doc.get('images', []):
        name = image.get('name', '')
        if name not in replacements:
            continue
        payload = replacements[name]
        assert image.get('mimeType') == 'image/png' and payload[:8] == b'\x89PNG\r\n\x1a\n'
        found.add(name)
        view = doc['bufferViews'][image['bufferView']]
        assert view.get('buffer', 0) == 0
        binary.extend(b'\0' * (-len(binary) % 4))
        view['byteOffset'] = len(binary)
        view['byteLength'] = len(payload)
        binary.extend(payload)
        changed_views.add(image['bufferView'])
    assert found == set(replacements), (found, set(replacements))
    doc['buffers'][0]['byteLength'] = len(binary)
    binary.extend(b'\0' * (-len(binary) % 4))
    encoded = json.dumps(doc, separators=(',', ':')).encode('utf-8')
    encoded += b' ' * (-len(encoded) % 4)
    body = struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
    body += struct.pack('<II', len(binary), 0x004E4942) + bytes(binary)
    result = b'glTF' + struct.pack('<II', 2, len(body) + 12) + body
    verify_unchanged(raw, result, changed_views)
    return result


def verify_unchanged(before_raw, after_raw, changed_views=None):
    before, old_binary = read_glb(before_raw)
    after, new_binary = read_glb(after_raw)
    if changed_views is None:
        changed_views = {i['bufferView'] for i in before.get('images', [])
                         if 'albedo' in i.get('name', '')}
    clean = copy.deepcopy(after)
    clean['buffers'] = before['buffers']
    for index in changed_views:
        clean['bufferViews'][index] = before['bufferViews'][index]
    assert clean == before, 'Non-image GLB metadata was changed'
    for index, view in enumerate(before['bufferViews']):
        if index in changed_views:
            continue
        new_view = after['bufferViews'][index]
        lo = view.get('byteOffset', 0)
        hi = new_view.get('byteOffset', 0)
        assert old_binary[lo:lo + view['byteLength']] == new_binary[hi:hi + new_view['byteLength']], index
    return {'non_image_metadata_identical': True, 'non_image_buffer_views_identical': True,
            'animations': [a['name'] for a in after.get('animations', [])],
            'skin_count': len(after.get('skins', [])),
            'sha256': hashlib.sha256(after_raw).hexdigest()}
