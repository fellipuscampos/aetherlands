"""Export individual kit assets, native previews and isolated editable sources."""
import bpy
import hashlib
import json
import struct
import time
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/nature/temperate_forest_v1'
REVIEW=ROOT/'art_source/temperate_forest_review'
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
report=next(r for r in manifest['assets'] if r['asset']==FOREST_ASSET)
name=report['name']; scene=bpy.data.scenes[name]
bpy.context.window.scene=scene
mesh=next(o for o in scene.objects if o.type=='MESH' and o.get('forest_asset'))
root=mesh.parent; camera=scene.camera
folder=OUT/'models'/FOREST_ASSET
folder.mkdir(exist_ok=True); (folder/'previews').mkdir(exist_ok=True)
start=time.monotonic()
def checkpoint(stage):
    (REVIEW/'current_stage.json').write_text(json.dumps({'asset':FOREST_ASSET,'stage':stage,'seconds':round(time.monotonic()-start,1)}),encoding='utf-8')
checkpoint('export_glb')
for obj in scene.objects: obj.select_set(False)
root.select_set(True); mesh.select_set(True)
bpy.context.view_layer.objects.active=mesh
path=folder/(FOREST_ASSET+'.glb')
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
raw=path.read_bytes(); assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]); binary=raw[28+length:]
assert len(doc['meshes'])==len(doc['materials'])==len(doc['images'])==1
assert len(doc['meshes'][0]['primitives'])==1
assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
assert not doc['materials'][0].get('doubleSided',False)
assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
assert triangles==report['triangles']
bv=doc['bufferViews'][doc['images'][0]['bufferView']]
png=binary[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
digest=hashlib.sha256(png).hexdigest()
assert digest==hashlib.sha256((OUT/'textures/forest_pixel_atlas.png').read_bytes()).hexdigest()
assert all(s.get('magFilter')==9728 for s in doc['samplers'])
report['export']={'bytes':len(raw),'meshes':1,'surfaces':1,'materials':1,'triangles':triangles,'embedded_atlas_sha256':digest,'no_studio':True}
checkpoint('render_previews')
prefs=bpy.context.preferences.addons['cycles'].preferences
previous_compute=prefs.compute_device_type
target=Vector(scene['preview_target'])
try:
    try:
        prefs.compute_device_type='OPTIX'; prefs.get_devices()
        if any(d.type=='OPTIX' and d.use for d in prefs.devices): scene.cycles.device='GPU'
    except (TypeError,RuntimeError): pass
    close_scale=max(report['dimensions'])*1.6+.16
    for view,(position,scale) in {'three_quarter':((2.6,-4,3.3),close_scale),'game_top':((1.8,-2.9,4.9),1.75),'top':((0,0,6),max(report['dimensions'][:2])*1.7+.16),'back':((-2.6,4,3.4),close_scale)}.items():
        checkpoint('render_'+view)
        camera.location=position; camera.data.ortho_scale=scale
        aim=Vector((0,0,0)) if view=='top' else target
        camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(folder/'previews'/(view+'.png'))
        bpy.ops.render.render(write_still=True)
finally: prefs.compute_device_type=previous_compute
camera.location=(2.6,-4,3.3); camera.data.ortho_scale=close_scale
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
scene['forest_report']=json.dumps(report,ensure_ascii=False)
bpy.data.libraries.write(str(folder/(FOREST_ASSET+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
(folder/(FOREST_ASSET+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
for index,r in enumerate(manifest['assets']):
    if r['asset']==FOREST_ASSET: manifest['assets'][index]=report
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
journal=REVIEW/'completed.json'
completed=json.loads(journal.read_text(encoding='utf-8')) if journal.exists() else []
completed.append({'asset':FOREST_ASSET,'triangles':triangles,'seconds':round(time.monotonic()-start,1)})
journal.write_text(json.dumps(completed,ensure_ascii=False,indent=2),encoding='utf-8')
checkpoint('complete')
result={'asset':FOREST_ASSET,'triangles':triangles,'seconds':round(time.monotonic()-start,1),'shared_atlas_verified':True,'mcp_only':True}
