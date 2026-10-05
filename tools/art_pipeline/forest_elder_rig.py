"""Rig the approved Forest Elder (no animations yet) via Blender MCP, verify it with a
pose test, then save the .blend and export the skinned GLB in the rest pose.
Rigid block skinning: every part follows the single bone stored in obj['rig_bone'],
so crown, mask, beard, branches, talisman, vine, sash tail and leaf skirt plates all
travel with the body. The pose test renders previews/pose_test.png and checks that
no new surface crossings appear (arm/torso, hand/leg, skirt/thigh, sash/thigh...).
Refuses to replace an existing rig.
"""
import bpy
import json
import shutil
import tempfile
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['forest_elder']; NAME=st['name']; scene=st['scene']; root=st['root']; OUT=Path(st['out'])
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
bone('pelvis',(0,.02,1.10),(0,.02,1.30),'root')
bone('spine',(0,.02,1.28),(0,.0,1.64),'pelvis')
bone('chest',(0,.0,1.64),(0,-.03,2.20),'spine')
bone('head',(0,-.06,2.20),(0,-.06,2.62),'chest')
bone('skirt_front',(0,-.26,1.20),(0,-.26,.80),'pelvis')
bone('skirt_back',(0,.27,1.20),(0,.27,.84),'pelvis')
bone('sash_tail',(.37,-.20,1.25),(.42,-.24,.90),'pelvis')
for side,k in [('l',1),('r',-1)]:
    bone('shoulder_'+side,(k*.22,0,2.10),(k*.58,0,2.06),'chest')
    bone('upper_arm_'+side,(k*.60,0,2.00),(k*.72,-.08,1.54),'shoulder_'+side)
    bone('forearm_'+side,(k*.72,-.08,1.54),(k*.805,-.19,.97),'upper_arm_'+side)
    bone('hand_'+side,(k*.805,-.19,.97),(k*.82,-.26,.60),'forearm_'+side)
    bone('thigh_'+side,(k*.22,.02,1.10),(k*.26,-.04,.64),'pelvis')
    bone('shin_'+side,(k*.26,-.04,.64),(k*.27,.04,.14),'thigh_'+side)
    bone('foot_'+side,(k*.27,.04,.14),(k*.27,.42,.06),'shin_'+side)      # the foot points BACKWARDS
collection=bpy.data.collections.new(NAME+'_06_RIG'); scene.collection.children.link(collection)
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
torso=['Chest','Abdomen','Pelvis','Head','Mask','Beard','Sash','Talisman']
pairs=[]
for side in ('l','r'):
    armp=[n for n in objects if n.endswith('_'+side) and n.split('_')[0] in ('UpperArm','Forearm','Hand','Finger0','Finger1','Finger2','Thumb')]
    legp=[n for n in objects if n.endswith('_'+side) and n.split('_')[0] in ('Thigh','Shin','Foot','Toe0','Toe1','Toe2')]
    pairs+=[(a,b) for a in armp for b in torso+legp+['LeafSkirt_Front','LeafSkirt_Back','SashTail']]
    pairs+=[(a,b) for a in ('LeafSkirt_Front','LeafSkirt_Back','SashTail') for b in legp]
    pairs+=[(a,b) for a in ('Branch_'+side,'Twig_l') for b in ['Head','Crown_Center','Crown_Front','Crown_Mid_l','Crown_Mid_r','Crown_Side_l','Crown_Side_r']]
pairs=[(a,b) for a,b in pairs if a in objects and b in objects]
def overlaps():
    ev=evaluated([objects[n] for n in set(x for p in pairs for x in p)])
    trees={n:BVHTree.FromPolygons(*ev[n]) for n in ev}
    return {(a,b) for a,b in pairs if trees[a].overlap(trees[b])}
reset(); bpy.context.view_layer.update(); at_rest=overlaps()

# Pose test: left arm raised forward, right arm swung out, left leg stepping forward,
# right leg back, torso and head turned, skirt plates following the legs.
rotate('upper_arm_l',(-1.2,-.15,0)); rotate('forearm_l',(-.6,0,0)); rotate('hand_l',(-.3,0,0))
rotate('upper_arm_r',(.35,.55,0)); rotate('forearm_r',(-.4,0,0))
rotate('thigh_l',(-.55,0,0)); rotate('shin_l',(.65,0,0)); rotate('foot_l',(-.10,0,0))
rotate('thigh_r',(.30,0,0)); rotate('shin_r',(.25,0,0))
rotate('skirt_front',(-.45,0,0)); rotate('skirt_back',(.20,0,0)); rotate('sash_tail',(-.35,0,0))
rotate('spine',(.06,0,.12)); rotate('chest',(.04,0,.10)); rotate('head',(-.06,0,-.25))
bpy.context.view_layer.update()
pose_hits=sorted(overlaps()-at_rest)
camera=scene.camera; saved=camera.matrix_world.copy(); target=Vector((0,-.05,1.45))
camera.location=target+Vector((6,-12,5.6)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
(OUT/'previews').mkdir(exist_ok=True)
scene.render.filepath=str(OUT/'previews'/'pose_test.png'); bpy.ops.render.render(write_still=True)
camera.matrix_world=saved
reset(); bpy.context.view_layer.update()
assert not pose_hits, pose_hits

# Save the rigged source, then export the skinned GLB in the rest pose (no clips).
def digest(image): return hashlib.md5(bytes(round(v*255) for v in image.pixels[:])).hexdigest()
disk=bpy.data.images.load(str(OUT/'forest_elder_v1_atlas.png'),check_existing=False)
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
glb=OUT/'forest_elder_v1.glb'
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

source=OUT/'forest_elder_v1.blend'
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='forest_elder_check_') as folder:
    tmp=Path(folder)/'check.blend'; shutil.copyfile(source,tmp)
    with bpy.data.libraries.load(str(tmp)) as (src,dst):
        scenes=list(src.scenes); rigs=list(src.armatures); actions=list(src.actions)
assert scenes==[NAME] and len(rigs)==1 and not actions
report=st['report']
report.update({'rig':True,'bone_count':len(arm.bones),'bones':list(arm.bones.keys()),
 'skinning':'Rigid block skinning: every part follows one bone; adornments (crown, mask, beard, branches, talisman, vine, sash tail, leaf skirt) have their own or their carrier bone',
 'pose_test':{'image':'previews/pose_test.png','new_surface_crossings':len(pose_hits),'rest_contacts_excluded':sorted(map(list,at_rest)),
              'pose':'left arm raised forward, right arm swung out, left leg stepping forward, right leg back, torso/head turned, skirt plates following'},
 'glb':{'file':glb.name,'meshes':['Model'],'triangles':triangles,'check':glb_check},
 'source_validation':{'scenes':scenes,'armatures':rigs,'actions':actions,'packed_texture':True},
 'animations':[],'status':'Complete: rigged Forest Elder (rest pose, no clips yet), pose-tested, GLB exported'})
(OUT/'forest_elder_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.app.driver_namespace['forest_elder']['rig']=rig
result={'bones':len(arm.bones),'pose_test_new_crossings':len(pose_hits),'rest_contacts':sorted(map(list,at_rest)),'glb_check':glb_check,'triangles':triangles,'source':str(source)}
