"""Put square-sail masts behind the cloth and refresh final deliverables via MCP."""
import bpy, bmesh, ast, json, math, hashlib, struct
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
REVIEW=ROOT/'art_source/embark_boats_review'
boats=bpy.app.driver_namespace['embark_boats_v1']
prefs=bpy.context.preferences.addons['cycles'].preferences
previous_compute=prefs.compute_device_type
prefs.get_devices()
previous_device_use={d.name:bool(d.use) for d in prefs.devices}
gpu=False
try:
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    gpu=any(d.type=='OPTIX' for d in prefs.devices)
    for d in prefs.devices:
        if d.type=='OPTIX': d.use=True
except (TypeError,RuntimeError):
    prefs.compute_device_type=previous_compute
script=ast.parse((ROOT/'tools/art_pipeline/build_embark_boats_mcp.py').read_text(encoding='utf-8'))
for node in script.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('CUBE','REGIONS') for t in node.targets):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<boat_constants>','exec'))
    if isinstance(node,ast.FunctionDef) and node.name in ('mesh','box','beam','checkpoint','export_game'):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<boat_helpers>','exec'))
review=bpy.data.scenes['Embark_Boats_V1_Review']
for boat in boats:
    race=boat['report']['race']
    if race=='elf': continue
    scene=boat['scene']; root=boat['root']; mat=boat['material']; parts=boat['parts']; out=boat['out']
    bpy.context.window.scene=scene
    groups={label:next(c for c in scene.collection.children if c.name==out.name+'_'+label) for label in ('Hull','Deck','Rig','Sail','Details')}
    assert not any(p['part']=='Yard_Mast_Support' for p in parts), 'Polish already applied'
    checkpoint(race,'polish_mast')
    mast_parts=('Mast','Mast_Step','Pennant_Pole','Blue_Pennant')
    for obj in parts:
        label=obj['part']
        if label in mast_parts or label.startswith('Mast_Binding_'):
            for v in obj.data.vertices: v.co.y-=.17
        elif label.startswith('Standing_Rigging_'):
            mid=(min(v.co.z for v in obj.data.vertices)+max(v.co.z for v in obj.data.vertices))/2
            for v in obj.data.vertices:
                if v.co.z>mid: v.co.y-=.17
        else: continue
        bm=bmesh.new(); bm.from_mesh(obj.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(obj.data); bm.free(); obj.data.update()
    top={'human':2.67,'orc':2.49,'dwarf':2.28}[race]
    added=beam('Yard_Mast_Support',(0,-.13,top-.155),(0,.075,top-.155),.07,'wood_dark','Rig')
    # Reference copies already share the edited mesh IDs; add the new support explicitly.
    rroot=next(o for o in review.objects if o.type=='EMPTY' and o.get('race')==race)
    collection=next(c for c in review.collection.children if c.name=='Embark_Boats_V1_'+race+'_Review')
    copy=added.copy(); collection.objects.link(copy); copy.parent=rroot
    checkpoint(race,'polish_export'); export_game(out,race)
    raw=(out/(out.name+'.glb')).read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size])
    report=boat['report']; report['triangles']=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
    report['editable_parts']=len(parts); report['game_meshes']=len(doc['meshes']); report['glb_sha256']=hashlib.sha256(raw).hexdigest()
    report['mast_behind_sail']=True
    camera=scene.camera; scene.cycles.samples=16
    if gpu: scene.cycles.device='GPU'
    views={'three_quarter':((4.4,6.4,4.2),4.15,Vector((0,0,1.14))),
           'game_top':((3.2,5.0,6.8),3.95,Vector((0,0,.91))),
           'side':((6,.4,2.8),3.95,Vector((0,0,1.16))),
           'top':((0,0,8),3.70,Vector((0,0,0)))}
    for label,(position,scale,aim) in views.items():
        checkpoint(race,'polish_render_'+label); camera.location=position; camera.data.ortho_scale=scale
        camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(label+'.png')); bpy.ops.render.render(write_still=True)
    floor=next(o for o in scene.objects if o.get('preview_only'))
    floor.hide_render=True; camera.location=(4.4,6.4,4.2); camera.data.ortho_scale=4.15
    camera.rotation_euler=(Vector((0,0,1.13))-camera.location).to_track_quat('-Z','Y').to_euler()
    checkpoint(race,'polish_render_dry_hull'); scene.render.filepath=str(out/'previews'/'dry_hull.png'); bpy.ops.render.render(write_still=True)
    floor.hide_render=False
    bpy.data.libraries.write(str(out/(out.name+'.blend')),{scene},fake_user=True,compress=True)
    (out/(out.name+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')

bpy.context.window.scene=review
checkpoint('all','polish_review')
label_mat=bpy.data.materials.new('Embark_Boats_V1_Label_Material'); label_mat.use_nodes=True
bsdf=label_mat.node_tree.nodes['Principled BSDF']; bsdf.inputs['Base Color'].default_value=(.88,.79,.57,1); bsdf.inputs['Roughness'].default_value=1
for obj in review.objects:
    if obj.type=='FONT':
        obj.data.materials.clear(); obj.data.materials.append(label_mat)
        obj.rotation_euler=review.camera.rotation_euler; obj.location.y=2.15; obj.location.z=.22
data=bpy.data.meshes.new('Embark_Boats_V1_Review_Water'); data.from_pydata([(-50,-50,-.004),(50,-50,-.004),(50,50,-.004),(-50,50,-.004)],[],[(0,1,2,3)])
obj=bpy.data.objects.new(data.name,data); review.collection.objects.link(obj)
data.materials.append(next(o for o in boats[0]['scene'].objects if o.get('preview_only')).data.materials[0])
review.cycles.samples=16
if gpu: review.cycles.device='GPU'
review.render.filepath=str(REVIEW/'four_boats.png'); bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(REVIEW/'embark_boats_v1_review.blend'),{review,*[b['scene'] for b in boats]},fake_user=True,compress=True)
manifest=json.loads((REVIEW/'manifest.json').read_text(encoding='utf-8')); manifest['assets']=[b['report'] for b in boats]
(REVIEW/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for d in prefs.devices:
    if d.name in previous_device_use: d.use=previous_device_use[d.name]
prefs.compute_device_type=previous_compute
result={'status':'PASS','masts_recessed':3,'review_scene':review.name,'boats':len(boats)}
