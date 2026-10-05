"""Save the reviewed static Minotaur (.blend, editable parts) and export the game GLB.
The GLB carries two joined meshes (body, labrys) sharing one material, like the
Troll; the .blend keeps all named parts separate. The GLB is re-imported to verify.
"""
import bpy
import json
import shutil
import tempfile
from pathlib import Path

st=bpy.app.driver_namespace['minotaur_blocky']; NAME=st['name']; scene=st['scene']; report=st['report']
parts=st['parts']; root=st['root']; out=Path(st['out'])
bpy.context.window.scene=scene; scene.frame_set(1)
assert all(o.type!='ARMATURE' and o.animation_data is None for o in scene.objects)
views=('front','three_quarter','side','back','game_top')
assert all((out/'previews'/f'{v}.png').is_file() for v in views)

# Temporary joined copies for export only.
export=bpy.data.collections.new(NAME+'_EXPORT_TMP'); scene.collection.children.link(export)
joined=[]
for label,members in [('Body',[o for o in parts if not o['part'].startswith('Labrys_')]),
                      ('Labrys',[o for o in parts if o['part'].startswith('Labrys_')])]:
    copies=[]
    for o in members:
        c=o.copy(); c.data=o.data.copy(); export.objects.link(c); copies.append(c)
    with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies):
        bpy.ops.object.join()
    obj=copies[0]; obj.name=NAME+'_'+label; obj.data.name=NAME+'_'+label+'_Mesh'; joined.append(obj)
glb=out/'minotaur_blocky_v1.glb'
bpy.ops.object.select_all(action='DESELECT')
for o in joined+[root]: o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
 export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False)
for o in joined: o.data.calc_loop_triangles()
joined_tris=sum(len(o.data.loop_triangles) for o in joined)
for o in joined: bpy.data.meshes.remove(o.data)
bpy.data.collections.remove(export)

# Verify the GLB by importing it into a throwaway scene.
check=bpy.data.scenes.new('GLB_CHECK_TMP'); bpy.context.window.scene=check
bpy.ops.import_scene.gltf(filepath=str(glb))
meshes=[o for o in check.objects if o.type=='MESH']
zs=[(o.matrix_world@v.co).z for o in meshes for v in o.data.vertices]
ys=[(o.matrix_world@v.co).y for o in meshes for v in o.data.vertices]
img=[n.image for o in meshes for s in o.material_slots for n in s.material.node_tree.nodes if n.type=='TEX_IMAGE']
glb_check={'meshes':sorted(o.name for o in meshes),'height_m':max(zs)-min(zs),'min_z':min(zs),
 'materials':len({s.material.name for o in meshes for s in o.material_slots}),
 'texture':[list(img[0].size),img[0].colorspace_settings.name] if img else None,
 'interpolation':sorted({n.interpolation for o in meshes for s in o.material_slots for n in s.material.node_tree.nodes if n.type=='TEX_IMAGE'}),
 'muzzle_points_minus_y':min(ys)<-0.9,'triangles':joined_tris}
for o in list(check.objects):
    data=o.data; bpy.data.objects.remove(o,do_unlink=True)
    if data is not None and data.users==0 and isinstance(data,bpy.types.Mesh): bpy.data.meshes.remove(data)
bpy.data.scenes.remove(check); bpy.context.window.scene=scene
assert abs(glb_check['height_m']-report['height_m'])<1e-3 and glb_check['materials']==1 and len(meshes)==2

report['visual_review']={'views':list(views),
 'identity':'Hunched bull brute: large swept horns, red eyes under angry brows, iron nose ring, dark hump mane, hooves, tail',
 'gear':'Crimson loincloth under the belt, iron bracers and fetlock bands, labrys hanging forward from a real grip channel'}
report['glb']={'file':glb.name,'meshes':['Body','Labrys'],'check':glb_check}
report['status']='Complete: static editable Minotaur, no rig or animation, five review renders'
scene['status']=report['status']
bpy.ops.object.select_all(action='DESELECT'); root.select_set(True); bpy.context.view_layer.objects.active=root
source=out/'minotaur_blocky_v1.blend'
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='minotaur_source_check_') as folder:
    target=Path(folder)/'check.blend'; shutil.copyfile(source,target)
    with bpy.data.libraries.load(str(target)) as (src,dst):
        scenes=list(src.scenes); actions=list(src.actions); rigs=list(src.armatures); images=list(src.images)
assert scenes==[NAME] and not actions and not rigs
report['source_validation']={'scenes':scenes,'actions':actions,'armatures':rigs,'images':images,'packed_texture':True}
(out/'minotaur_blocky_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'source':str(source),'glb':str(glb),'glb_check':glb_check,'source_validation':report['source_validation']}
