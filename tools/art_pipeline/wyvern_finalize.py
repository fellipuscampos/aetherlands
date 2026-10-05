"""Save the reviewed static Wyvern (.blend, editable parts) and export the game GLB.
The GLB carries one joined mesh (Body) with one material; the .blend keeps all named parts separate. The GLB is re-imported to verify,
and the packed atlas must match the PNG on disk (stale packed image guard).
"""
import bpy
import json
import shutil
import tempfile
from pathlib import Path

st=bpy.app.driver_namespace['wyvern']; NAME=st['name']; scene=st['scene']; report=st['report']
parts=st['parts']; root=st['root']; out=Path(st['out'])
bpy.context.window.scene=scene; scene.frame_set(1)
assert all(o.type!='ARMATURE' and o.animation_data is None for o in scene.objects)
views=('front','three_quarter','side','back','game_top')
assert all((out/'previews'/f'{v}.png').is_file() for v in views)
import hashlib
def digest(image): return hashlib.md5(bytes(round(v*255) for v in image.pixels[:])).hexdigest()
disk=bpy.data.images.load(str(out/'wyvern_blocky_v1_atlas.png'),check_existing=False)
assert digest(bpy.data.images[NAME+'_PixelAtlas'])==digest(disk), 'Packed atlas differs from the PNG on disk'
bpy.data.images.remove(disk)

# Temporary joined copies for export only.
export=bpy.data.collections.new(NAME+'_EXPORT_TMP'); scene.collection.children.link(export)
joined=[]
for label,members in [('Model',list(parts))]:   # 'Body' is already the torso part's name
    copies=[]
    for o in members:
        c=o.copy(); c.data=o.data.copy(); export.objects.link(c); copies.append(c)
    with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies):
        bpy.ops.object.join()
    obj=copies[0]; obj.name=NAME+'_'+label; obj.data.name=NAME+'_'+label+'_Mesh'; joined.append(obj)
glb=out/'wyvern_blocky_v1.glb'
bpy.ops.object.select_all(action='DESELECT')
for o in joined+[root]: o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
 export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False)
for o in joined: o.data.calc_loop_triangles()
joined_tris=sum(len(o.data.loop_triangles) for o in joined)
for o in joined: bpy.data.meshes.remove(o.data)
bpy.data.collections.remove(export)

# Verify the GLB by importing it into a throwaway scene; every datablock the
# import creates is removed afterwards so the session stays clean.
stores={'objects':bpy.data.objects,'meshes':bpy.data.meshes,'materials':bpy.data.materials,
        'images':bpy.data.images,'collections':bpy.data.collections}
before={k:set(v.keys()) for k,v in stores.items()}
check=bpy.data.scenes.new('GLB_CHECK_TMP'); bpy.context.window.scene=check
try:
    bpy.ops.import_scene.gltf(filepath=str(glb))
    meshes=[o for o in check.objects if o.type=='MESH']
    zs=[(o.matrix_world@v.co).z for o in meshes for v in o.data.vertices]
    ys=[(o.matrix_world@v.co).y for o in meshes for v in o.data.vertices]
    img=[n.image for o in meshes for s in o.material_slots for n in s.material.node_tree.nodes if n.type=='TEX_IMAGE']
    glb_check={'meshes':sorted(o.name for o in meshes),'height_m':max(zs)-min(zs),'min_z':min(zs),
     'materials':len({s.material.name for o in meshes for s in o.material_slots}),
     'texture':[list(img[0].size),img[0].colorspace_settings.name] if img else None,
     'texture_matches_atlas':bool(img) and digest(img[0])==digest(bpy.data.images[NAME+'_PixelAtlas']),
     'interpolation':sorted({n.interpolation for o in meshes for s in o.material_slots for n in s.material.node_tree.nodes if n.type=='TEX_IMAGE'}),
     'front_is_minus_y':min(ys)<-0.3,'triangles':joined_tris}
finally:
    bpy.context.window.scene=scene
    for o in list(check.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(check)
    for k in ('meshes','materials','images','collections'):
        for key in sorted(set(stores[k].keys())-before[k]):
            if key in stores[k]: stores[k].remove(stores[k][key])
assert abs(glb_check['height_m']-report['height_m'])<1e-3 and glb_check['materials']==1 and len(glb_check['meshes'])==1 and glb_check['texture_matches_atlas']

report['visual_review']={'views':list(views),
 'anatomy':'V3: low body; two hind legs only; each forelimb IS the wing (thin wing-bone arm, wrist knuckle on the ground with two thumb claws, five fan fingers growing from that knuckle, membrane joining arm and body) - no separate front leg',
 'identity':'Long low body, long three-segment neck, very long tail, row of pale dorsal spines from neck to tail tip, boxy head with wide-open mouth and white block teeth on both jaws, double swept horns, yellow slit eyes under one brow each',
 'materials':'Vivid red 3-tone pixel-noise scales with darker dorsal, cream leathery belly/throat plates, mottled membrane with dark trailing edge, dark-red finger bones, pale bone horns/spines/claws, blood-red mouth',
 'consistency':'Cuboid construction, flat shading, 64 px/m metric pixel UV like the rest of the bestiary; no hidden parts; 1024 atlas only because of membrane area'}
report['glb']={'file':glb.name,'meshes':['Model'],'check':glb_check}
report['status']='Complete: static editable Wyvern, no rig or animation, five review renders'
scene['status']=report['status']
bpy.ops.object.select_all(action='DESELECT'); root.select_set(True); bpy.context.view_layer.objects.active=root
source=out/'wyvern_blocky_v1.blend'
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='wyvern_source_check_') as folder:
    target=Path(folder)/'check.blend'; shutil.copyfile(source,target)
    with bpy.data.libraries.load(str(target)) as (src,dst):
        scenes=list(src.scenes); actions=list(src.actions); rigs=list(src.armatures); images=list(src.images)
assert scenes==[NAME] and not actions and not rigs
report['source_validation']={'scenes':scenes,'actions':actions,'armatures':rigs,'images':images,'packed_texture':True}
(out/'wyvern_blocky_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'source':str(source),'glb':str(glb),'glb_check':glb_check,'source_validation':report['source_validation']}
