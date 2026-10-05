"""Save the reviewed animated Minotaur (.blend), export the skinned GLB with three
NLA clips, re-import the GLB to verify it, and re-render the rest-pose stills.
GLB: two skinned meshes (Body, Labrys) sharing one material, like the Troll;
the .blend keeps every named part separate and editable.
"""
import bpy
import json
import shutil
import tempfile
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['minotaur_animation']; scene=st['scene']; rig=st['rig']; root=st['root']; NAME=st['name']
assert st.get('validation') and not st['validation']['problems'] and st.get('surface_contacts')==[], 'Run validation first.'
out=Path(st['out']); meshes=st['meshes']
anim_dir=out/'previews/animations'
for name in st['clips']:
    assert (anim_dir/f'{name}.mp4').is_file() and (anim_dir/f'{name}.gif').is_file(), name
bpy.context.window.scene=scene

# Rest-pose stills of the final (user-edited) model, NLA muted.
for t in rig.animation_data.nla_tracks: t.mute=True
rig.animation_data.action=None
for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0)
scene.frame_set(1); bpy.context.view_layer.update()
camera=scene.camera; target=Vector((0,-.15,1.30)); still_dir=out/'previews'
views={'three_quarter':(6,-12,5.6),'front':(0,-12,1.2),'side':(12,0,2.0),'back':(-6,12,5.0),'game_top':(5,-7,11)}
for view,off in views.items():
    camera.location=target+Vector(off); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(still_dir/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=target+Vector(views['three_quarter']); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
for t in rig.animation_data.nla_tracks: t.mute=False
scene.frame_start=1; scene.frame_end=137; scene.frame_set(1)

# Temporary joined, skinned copies for export only.
export=bpy.data.collections.new(NAME+'_EXPORT_TMP'); scene.collection.children.link(export)
joined=[]
for label,members in [('Body',[o for o in meshes if o['bone']!='weapon']),('Labrys',[o for o in meshes if o['bone']=='weapon'])]:
    copies=[]
    for o in members:
        c=o.copy(); c.data=o.data.copy(); export.objects.link(c); copies.append(c)
    copy_data=[c.data for c in copies[1:]]
    with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies):
        bpy.ops.object.join()
    for data in copy_data:
        if data.users==0: bpy.data.meshes.remove(data)
    obj=copies[0]; obj.name=NAME+'_'+label; obj.data.name=NAME+'_'+label+'_Mesh'; obj.parent=rig
    assert len([m for m in obj.modifiers if m.type=='ARMATURE'])==1
    joined.append(obj)
glb=out/'minotaur_blocky_v1.glb'
bpy.ops.object.select_all(action='DESELECT')
for o in joined+[rig,root]: o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
 export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,
 export_frame_range=False,export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
for o in joined: bpy.data.meshes.remove(o.data)
bpy.data.collections.remove(export)

# Re-import into a throwaway scene, then delete every datablock the import created.
stores={'objects':bpy.data.objects,'meshes':bpy.data.meshes,'materials':bpy.data.materials,'images':bpy.data.images,
        'armatures':bpy.data.armatures,'actions':bpy.data.actions,'collections':bpy.data.collections}
before={k:set(s.keys()) for k,s in stores.items()}
check=bpy.data.scenes.new('GLB_CHECK_TMP'); bpy.context.window.scene=check
try:
    bpy.ops.import_scene.gltf(filepath=str(glb))
    arms=[o for o in check.objects if o.type=='ARMATURE']; skinned=[o for o in check.objects if o.type=='MESH' and o.parent in arms]
    new_actions=sorted(set(bpy.data.actions.keys())-before['actions'])
    zs=[(o.matrix_world@v.co).z for o in skinned for v in o.data.vertices]
    glb_check={'armatures':len(arms),'bones':len(arms[0].data.bones) if arms else 0,'skinned_meshes':sorted(o.name for o in skinned),
     'mesh_has_armature_modifier':all(any(m.type=='ARMATURE' for m in o.modifiers) for o in skinned),
     'actions':[a.split('.')[0] for a in new_actions],
     'action_frame_ranges':{a.split('.')[0]:list(bpy.data.actions[a].frame_range) for a in new_actions},
     'rest_height_m':max(zs)-min(zs) if zs else 0,'rest_min_z':min(zs) if zs else 0}
finally:
    bpy.context.window.scene=scene
    for o in list(check.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(check)
    for k in ('actions','meshes','armatures','materials','images','collections'):
        for key in sorted(set(stores[k].keys())-before[k]):
            if key in stores[k]: stores[k].remove(stores[k][key])
assert glb_check['armatures']==1 and glb_check['bones']==len(rig.data.bones) and len(glb_check['skinned_meshes'])==2, glb_check
assert sorted(glb_check['actions'])==sorted(st['clips']), glb_check['actions']

report_path=out/'minotaur_blocky_v1_report.json'
report=json.loads(report_path.read_text(encoding='utf-8'))
coords=[v.co for o in meshes for v in o.data.vertices]; triangles=0
for o in meshes: o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
report.update({'height_m':max(c.z for c in coords)-min(c.z for c in coords),'triangles':triangles,'editable_parts':len(meshes),
 'user_edits':'Final model edited by the user in Blender: Hump and both Elbow blocks removed, ankle bands adjusted. '
              'Static copy: minotaur_blocky_v1_static.blend.',
 'rig':True,'bone_count':len(rig.data.bones),'bones':list(rig.data.bones.keys()),
 'skinning':'Rigid block skinning (one bone per part); hooves planted with a baked analytic two-bone solve; FK only at runtime',
 'animations':{n:{k:v for k,v in d.items() if k!='action'} for n,d in st['clips'].items()},
 'animation_validation':st['validation'],
 'glb':{'file':glb.name,'meshes':['Body','Labrys'],'check':glb_check},
 'status':'Complete: rigged editable Minotaur with Idle, Walk and Attack; MP4/GIF reviews.'})
for d in report['animations'].values(): d['duration_seconds']=(d['end']-d['start'])/24
scene['status']=report['status']
scene['description']='Animated minotaur brute: Idle / Walk / Attack. User-approved blocky geometry and pixel atlas.'
rig.show_in_front=False
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
assert all(i.packed_file for i in bpy.data.images if i.name.startswith(NAME))
source=out/'minotaur_blocky_v1.blend'
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='minotaur_animated_check_') as folder:
    tmp=Path(folder)/'check.blend'; shutil.copyfile(source,tmp)
    with bpy.data.libraries.load(str(tmp)) as (src,dst):
        scenes=list(src.scenes); actions=list(src.actions); rigs=list(src.armatures)
assert scenes==[NAME] and sorted(actions)==sorted(st['clips']) and len(rigs)==1,(scenes,actions,rigs)
report['source_validation']={'scenes':scenes,'actions':actions,'armatures':rigs,'packed_texture':True}
report_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'source':str(source),'glb_check':glb_check,'source_validation':report['source_validation'],'triangles':triangles}
