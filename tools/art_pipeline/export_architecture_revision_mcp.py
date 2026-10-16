"""Consolidate source meshes directly, then export an isolated scene via MCP.

Avoid object-join operators in the user's large multi-asset Blender session.
Preserve metric UVs, one material, architectural groups and root metadata.
"""
import bpy
import json
import struct
import hashlib
from pathlib import Path

st=bpy.app.driver_namespace['guardian_hall']
source_scene, source_root = st['scene'], st['root']
OUT, NAME=Path(st['out']),st['name']
temporary_scene=bpy.data.scenes.new(NAME+'_Architecture_Export_Temporary')
objects=[]
meshes=[]
temporary_root=source_root.copy()
temporary_root.name=NAME+'_AssetRoot'
temporary_scene.collection.objects.link(temporary_root)
objects.append(temporary_root)
try:
    part_set=set(st['parts'])
    for label,collection in st['groups'].items():
        if label=='09_STUDIO': continue
        sources=[o for o in collection.objects if o in part_set]
        if not sources: continue
        vertices=[]; faces=[]; uvs=[]
        for src in sources:
            offset=len(vertices)
            vertices.extend(tuple(v.co) for v in src.data.vertices)
            faces.extend(tuple(offset+i for i in p.vertices) for p in src.data.polygons)
            uvs.extend(tuple(loop.uv) for loop in src.data.uv_layers.active.data)
        data=bpy.data.meshes.new(NAME+'_'+label[3:].title()+'_Mesh')
        data.from_pydata(vertices,[],faces)
        data.update()
        uv=data.uv_layers.new(name='Metric_Pixel_UV')
        for loop,coord in zip(uv.data,uvs): loop.uv=coord
        data.materials.append(st['material'])
        obj=bpy.data.objects.new(NAME+'_'+label[3:].title(),data)
        obj.parent=temporary_root
        temporary_scene.collection.objects.link(obj)
        objects.append(obj); meshes.append(data)
    bpy.context.window.scene=temporary_scene
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=temporary_root
    glb=OUT/(OUT.name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
        use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,
        export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
finally:
    bpy.context.window.scene=source_scene
    # These IDs belong exclusively to our temporary export scene. One batch
    # avoids walking the entire multi-asset session separately for every ID.
    bpy.data.batch_remove(ids={temporary_scene,*objects,*meshes})
raw=glb.read_bytes()
magic,version,length=struct.unpack_from('<III',raw)
assert magic==0x46546C67 and version==2 and length==len(raw)
json_length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+json_length]); binary=raw[28+json_length:]
assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
assert len(doc['materials'])==1 and len(doc['images'])==2
triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
assert triangles==st['report']['triangles'],(triangles,st['report']['triangles'])
assert all(s.get('magFilter')==9728 and s.get('minFilter') in (9728,9984,9986) for s in doc['samplers'])
expected={hashlib.sha256(Path(x.filepath_raw).read_bytes()).hexdigest() for x in st['images']}
embedded=[]
for im in doc['images']:
    bv=doc['bufferViews'][im['bufferView']]
    png=binary[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
    digest=hashlib.sha256(png).hexdigest()
    assert digest in expected
    embedded.append({'image':im['name'],'bytes':len(png),'sha256':digest})
st['report']['export']={'file':glb.name,'bytes':len(raw),'meshes':len(doc['meshes']),
    'primitives':sum(len(m['primitives']) for m in doc['meshes']),'triangles':triangles,
    'materials':1,'nearest_samplers':doc['samplers'],'embedded_images_verified':embedded,
    'includes_studio':False,'includes_reference_unit':False}
(OUT/(OUT.name+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
result={'glb':str(glb),'triangles':triangles,'embedded_images_verified':True}
