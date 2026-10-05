"""Rig the Giant Spider (no animations yet) via Blender MCP, verify it with a pose
test, then save the .blend and export the skinned GLB in the rest pose.
Rigid block skinning: every part follows the single bone stored in obj['rig_bone'];
each leg has two bones (femur, tibia). The pose test renders previews/pose_test.png
and checks that no new surface crossings appear (legs/body, legs/legs, fangs/palps).
Refuses to replace an existing rig.
"""
import math
import bpy
import json
import shutil
import tempfile
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['spider']; NAME=st['name']; scene=st['scene']; root=st['root']; OUT=Path(st['out'])
bpy.context.window.scene=scene
assert NAME+'_Rig' not in bpy.data.objects, 'Existing rig: preserve manual edits.'
parts=[o for o in scene.objects if o.type=='MESH' and not o.name.endswith('StudioGround')]
for o in parts:
    if o.matrix_basis!=Matrix.Identity(4):
        o.data.transform(o.matrix_basis); o.matrix_basis=Matrix.Identity(4)
def short(o): return o.name.removeprefix(NAME+'_')

specs={}
def bone(n,h,t,p=None): specs[n]=(Vector(h),Vector(t),p)
bone('root',(0,0,0),(0,0,.25))
bone('cephalothorax',(0,.05,.56),(0,-.60,.52),'root')
bone('abdomen',(0,.10,.62),(0,1.36,.92),'cephalothorax')
for side,k in [('l',1),('r',-1)]:
    bone('chelicera_'+side,(k*.10,-.60,.58),(k*.10,-.78,.32),'cephalothorax')
    bone('palp_'+side,(k*.24,-.60,.52),(k*.30,-.84,.36),'cephalothorax')
    for i,(yaw,y0,reach,foot_z) in enumerate([(52,-.50,1.20,.16),(22,-.38,1.30,0),(-14,-.24,1.30,0),(-44,-.10,1.22,0)]):
        a=math.radians(yaw); d=Vector((k*math.cos(a),-math.sin(a),0))
        hip=Vector((k*.30,y0,.56)); knee=hip+d*.55+Vector((0,0,.46)); foot=hip+d*reach; foot.z=foot_z+.02
        bone('leg%d_femur_%s'%(i+1,side),hip,knee,'cephalothorax')
        bone('leg%d_tibia_%s'%(i+1,side),knee,foot,'leg%d_femur_%s'%(i+1,side))
collection=bpy.data.collections.new(NAME+'_05_RIG'); scene.collection.children.link(collection)
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); collection.objects.link(rig)
rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,parent) in specs.items():
    b=arm.edit_bones.new(n); b.head=h; b.tail=t
    if parent: b.parent=arm.edit_bones[parent]
    b.use_deform=n!='root'
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True; arm.display_type='STICK'
for o in parts:
    n=o['rig_bone']; assert n in specs,(o.name,n)
    o.vertex_groups.clear(); o.vertex_groups.new(name=n).add(list(range(len(o.data.vertices))),1,'REPLACE'); o['bone']=n
    for m in [m for m in o.modifiers if m.type=='ARMATURE']: o.modifiers.remove(m)
    mod=o.modifiers.new('Block_preserving_skin','ARMATURE'); mod.object=rig
    o.parent=rig
restq={b.name:b.matrix_local.to_quaternion() for b in arm.bones}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
def rotate(n,xyz):
    rig.pose.bones[n].rotation_quaternion=restq[n].inverted()@Euler(xyz,'XYZ').to_quaternion()@restq[n]
def reset():
    for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
objects={short(o):o for o in parts}
def evaluated(objs):
    deps=bpy.context.evaluated_depsgraph_get(); data={}
    for o in objs:
        ev=o.evaluated_get(deps); me=ev.to_mesh()
        data[short(o)]=([ev.matrix_world@v.co for v in me.vertices],[list(p.vertices) for p in me.polygons]); ev.to_mesh_clear()
    return data
body=['Cephalothorax','Waist','Abdomen','AbdomenRear']
legs=[n for n in objects if n.startswith('Leg')]
pairs=[(a,b) for a in legs for b in body]
pairs+=[(a,b) for ai,a in enumerate(legs) for b in legs[ai+1:] if a.split('_')[0]!=b.split('_')[0] or a[-1]!=b[-1]]
pairs+=[(a,b) for a in objects if a.startswith(('Fang','Chelicera')) for b in objects if b.startswith('Palp')]
pairs=[(a,b) for a,b in pairs if a in objects and b in objects]
def overlaps():
    ev=evaluated([objects[n] for n in set(x for p in pairs for x in p)])
    trees={n:BVHTree.FromPolygons(*ev[n]) for n in ev}
    return {(a,b) for a,b in pairs if trees[a].overlap(trees[b])}
reset(); bpy.context.view_layer.update(); at_rest=overlaps()

# Pose test: front pair raised to strike, others stepping, abdomen tilted up and
# swung, cephalothorax pitched down, chelicerae spread, palps reaching.
rotate('leg1_femur_l',(-.35,0,.10)); rotate('leg1_femur_r',(-.35,0,-.10))
rotate('leg2_femur_l',(0,0,.20)); rotate('leg2_tibia_l',(-.15,0,0)); rotate('leg3_femur_r',(0,0,-.20))
rotate('leg4_femur_l',(0,0,-.15)); rotate('leg4_femur_r',(0,0,.15))
rotate('abdomen',(-.18,0,.12)); rotate('cephalothorax',(.06,0,0))
rotate('chelicera_l',(-.20,0,-.15)); rotate('chelicera_r',(-.20,0,.15))
rotate('palp_l',(-.25,0,.10)); rotate('palp_r',(-.25,0,-.10))
bpy.context.view_layer.update()
pose_hits=sorted(overlaps()-at_rest)
camera=scene.camera; saved=camera.matrix_world.copy(); target=Vector((0,.15,.50))
camera.location=target+Vector((6,-12,5.6)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
(OUT/'previews').mkdir(exist_ok=True)
scene.render.filepath=str(OUT/'previews'/'pose_test.png'); bpy.ops.render.render(write_still=True)
camera.matrix_world=saved
reset(); bpy.context.view_layer.update()
assert not pose_hits, pose_hits

# Save the rigged source, then export the skinned GLB in the rest pose (no clips).
def digest(image): return hashlib.md5(bytes(round(v*255) for v in image.pixels[:])).hexdigest()
disk=bpy.data.images.load(str(OUT/'giant_spider_v1_atlas.png'),check_existing=False)
assert digest(bpy.data.images[NAME+'_PixelAtlas'])==digest(disk), 'Packed atlas differs from the PNG on disk'
bpy.data.images.remove(disk)
rig.show_in_front=False
export=bpy.data.collections.new(NAME+'_EXPORT_TMP'); scene.collection.children.link(export)
copies=[]
for o in parts:
    c=o.copy(); c.data=o.data.copy(); export.objects.link(c); copies.append(c)
copy_data=[c.data for c in copies[1:]]
with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies):
    bpy.ops.object.join()
for d in copy_data:
    if d.users==0: bpy.data.meshes.remove(d)
model=copies[0]; model.name=NAME+'_Model'; model.data.name=NAME+'_Model_Mesh'; model.parent=rig
glb=OUT/'giant_spider_v1.glb'
bpy.ops.object.select_all(action='DESELECT')
for o in (model,rig,root): o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
 export_animations=False,export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
model.data.calc_loop_triangles(); triangles=len(model.data.loop_triangles)
bpy.data.meshes.remove(model.data); bpy.data.collections.remove(export)

stores={'objects':bpy.data.objects,'meshes':bpy.data.meshes,'materials':bpy.data.materials,'images':bpy.data.images,
        'armatures':bpy.data.armatures,'collections':bpy.data.collections}
before={k:set(v.keys()) for k,v in stores.items()}
check=bpy.data.scenes.new('GLB_CHECK_TMP'); bpy.context.window.scene=check
try:
    bpy.ops.import_scene.gltf(filepath=str(glb))
    arms=[o for o in check.objects if o.type=='ARMATURE']; skinned=[o for o in check.objects if o.type=='MESH' and o.parent in arms]
    zs=[(o.matrix_world@v.co).z for o in skinned for v in o.data.vertices]
    img=[n.image for o in skinned for s in o.material_slots for n in s.material.node_tree.nodes if n.type=='TEX_IMAGE']
    glb_check={'armatures':len(arms),'bones':len(arms[0].data.bones) if arms else 0,'skinned_meshes':sorted(o.name for o in skinned),
     'height_m':max(zs)-min(zs),'min_z':min(zs),'texture_matches_atlas':bool(img) and digest(img[0])==digest(bpy.data.images[NAME+'_PixelAtlas'])}
finally:
    bpy.context.window.scene=scene
    for o in list(check.objects): bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(check)
    for k in ('meshes','armatures','materials','images','collections'):
        for key in sorted(set(stores[k].keys())-before[k]):
            if key in stores[k]: stores[k].remove(stores[k][key])
assert glb_check['armatures']==1 and glb_check['bones']==len(arm.bones) and len(glb_check['skinned_meshes'])==1 and glb_check['texture_matches_atlas'], glb_check

source=OUT/'giant_spider_v1.blend'
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='giant_spider_check_') as folder:
    tmp=Path(folder)/'check.blend'; shutil.copyfile(source,tmp)
    with bpy.data.libraries.load(str(tmp)) as (src,dst):
        scenes=list(src.scenes); rigs=list(src.armatures); actions=list(src.actions)
assert scenes==[NAME] and len(rigs)==1 and not actions
report=st['report']
report.update({'rig':True,'bone_count':len(arm.bones),'bones':list(arm.bones.keys()),
 'skinning':'Rigid block skinning: every part follows one bone; two bones per leg (femur, tibia); chelicerae (with fangs) and palps have their own bones',
 'pose_test':{'image':'previews/pose_test.png','new_surface_crossings':len(pose_hits),'rest_contacts_excluded':sorted(map(list,at_rest)),
              'pose':'front legs raised to strike, other legs stepping, abdomen tilted and swung, chelicerae spread, palps reaching'},
 'glb':{'file':glb.name,'meshes':['Model'],'triangles':triangles,'check':glb_check},
 'source_validation':{'scenes':scenes,'armatures':rigs,'actions':actions,'packed_texture':True},
 'animations':[],'status':'Complete: rigged Giant Spider (rest pose, no clips yet), pose-tested, GLB exported'})
(OUT/'giant_spider_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.app.driver_namespace['spider']['rig']=rig
result={'bones':len(arm.bones),'pose_test_new_crossings':len(pose_hits),'rest_contacts':sorted(map(list,at_rest)),'glb_check':glb_check,'triangles':triangles,'source':str(source)}
