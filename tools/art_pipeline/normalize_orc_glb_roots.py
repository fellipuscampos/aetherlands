"""Preserve grounding in Godot by placing root translation on its rig child.

The two hierarchies produce exactly the same world matrices. Geometry, skins,
all animation channels and embedded textures remain byte-for-byte unchanged.
"""
import json,struct
from orc_troop_assets import ASSETS,OUT
from human_texture_glb import read_glb
for row in ASSETS:
    path=OUT/row['stem']/(row['stem']+'.glb'); doc,binary=read_glb(path.read_bytes())
    root=doc['nodes'][doc['scenes'][doc.get('scene',0)]['nodes'][0]]
    move=root.get('translation',[0,0,0])
    if max(abs(x) for x in move)<.000001: continue
    assert 'rotation' not in root and len(root['children'])==1
    scale=root.get('scale',[1,1,1]); child=doc['nodes'][root['children'][0]]
    assert 'matrix' not in child
    offset=child.get('translation',[0,0,0])
    child['translation']=[offset[i]+move[i]/scale[i] for i in range(3)]
    root.pop('translation')
    encoded=json.dumps(doc,separators=(',',':')).encode(); encoded+=b' '*(-len(encoded)%4)
    body=struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary
    path.write_bytes(b'glTF'+struct.pack('<II',2,len(body)+12)+body)
    print('GODOT_ROOT_NORMALIZED',row['stem'],move)
