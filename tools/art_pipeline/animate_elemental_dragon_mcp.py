"""Bake a seamless floating idle on a copy of the approved V4 through live MCP."""
import bpy,math,json,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE='elemental_dragon_v4'; STEM='elemental_dragon_v5_animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
revision=globals().get('DRAGON_REVISE_IDLE',False)
assert not (OUT/(STEM+'.glb')).exists() or (revision and STEM in bpy.app.driver_namespace),'Preserve an existing animated dragon.'
old=bpy.app.driver_namespace[SOURCE]
failed=bpy.data.scenes.get('Elemental_Dragon_V5_Animated')
if failed:
    bpy.context.window.scene=old['scene']
    for obj in list(failed.objects): bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.scenes.remove(failed)
protected={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'assets/generated/grand_manifestations').glob('*/*.glb') if p.parent.name!=STEM}
OUT.mkdir(parents=True,exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
scene=bpy.data.scenes.new('Elemental_Dragon_V5_Animated'); bpy.context.window.scene=scene
scene.world=old['scene'].world.copy(); scene.unit_settings.system='METRIC'
copies={}
for original in old['scene'].objects:
    obj=original.copy(); obj.animation_data_clear()
    if original.data: obj.data=original.data.copy()
    obj.name=original.name.replace(SOURCE,STEM); scene.collection.objects.link(obj); copies[original]=obj
for original,obj in copies.items():
    obj.parent=copies.get(original.parent)
    for mod in obj.modifiers:
        if mod.type=='ARMATURE': mod.object=copies[old['rig']]
rig=copies[old['rig']]; root=copies[old['root']]; parts=[copies[o] for o in old['parts']]
scene.camera=copies[old['scene'].camera]
material=parts[0].data.materials[0].copy(); material.name=STEM+'_Pixel_Material'
images=[]
for original,suffix in zip(old['images'],('albedo','emission')):
    path=OUT/(STEM+'_'+suffix+'.png'); shutil.copy2(original.filepath_raw,path)
    copied=bpy.data.images.load(str(path),check_existing=False); copied.pack(); images.append(copied)
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image==original: node.image=copied
for obj in parts: obj.data.materials.clear(); obj.data.materials.append(material)
assert all([tuple(v.co) for v in a.data.vertices]==[tuple(v.co) for v in b.data.vertices] for a,b in zip(old['parts'],parts))
# Current approved expression: both eyebrows are omitted from the animated copy.
eyebrows=[o for o in parts if o['part'].startswith('Brow_')]
parts=[o for o in parts if o not in eyebrows]
for obj in eyebrows: bpy.data.objects.remove(obj,do_unlink=True)
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
core=rest['core'].translation.copy(); spine=['spine_%02d'%i for i in range(39)]
FPS=30; SECONDS=6; END=1+FPS*SECONDS
scene.render.fps=FPS; scene.frame_start=1; scene.frame_end=END
rig.animation_data_create(); action=bpy.data.actions.new(STEM+'_idle'); rig.animation_data.action=action
previous_quaternions={}

def wave(point,s,p):
    # Keep the tight central opening calm; the free tail carries the larger wave.
    freedom=max(0.,min(1.,((point-core).length-.78)/.45))
    amp=.008+freedom*(.045+.055*s**3.5)
    phase=-math.tau*1.7*s
    return Vector((amp*.65*(math.sin(p+phase)-math.sin(phase)),
                   amp*.90*(math.sin(p+phase+.4)-math.sin(phase+.4)),
                   amp*.65*(math.cos(p+phase)-math.cos(phase))))*.5

def rotated_at(matrix,axis,angle):
    rotation=Matrix.Rotation(angle,3,axis)@matrix.to_3x3()
    result=rotation.to_4x4(); result.translation=matrix.translation
    return result

def pose_at(t):
    p=math.tau*t/SECONDS
    G=Matrix.Translation((.003*math.sin(p),0,.018*math.sin(p)))@Matrix.Rotation(math.radians(.25)*math.sin(p),4,'Z')
    pose={'root':rest['root'].copy()}
    current=rest[spine[0]].translation+wave(rest[spine[0]].translation,0,p)
    for j,name in enumerate(spine):
        bone=rig.data.bones[name]; target=bone.tail_local+wave(bone.tail_local,(j+1)/39,p)
        direction=(target-current).normalized()
        rotation=(bone.tail_local-bone.head_local).normalized().rotation_difference(direction).to_matrix()@rest[name].to_3x3()
        matrix=rotation.to_4x4(); matrix.translation=current; pose[name]=matrix
        current=current+direction*bone.length
    for bone in rig.data.bones:
        name=bone.name
        if name in pose: continue
        parent=bone.parent.name
        pose[name]=pose[parent]@rest[parent].inverted()@rest[name]
        if name=='head':
            pose[name]=rotated_at(pose[name],'Z',math.radians(.6)*math.sin(p))
            pose[name]=rotated_at(pose[name],'X',math.radians(.4)*math.sin(2*p))
        elif name.startswith('whisker_'):
            side=int(name.split('_')[1]); segment=int(name.split('_')[2]); lag=.28*segment
            pose[name]=rotated_at(pose[name],'Z',math.radians(side*1.8)*(math.sin(p-lag)-math.sin(-lag)))
        elif name=='core':
            pose[name]=rotated_at(rest[name],'Z',p)
    return {name:G@matrix for name,matrix in pose.items()}

for frame in range(1,END+1):
    pose=pose_at((frame-1)/FPS)
    for bone in rig.pose.bones:
        bone.rotation_mode='QUATERNION'
        args={'parent_matrix':pose[bone.parent.name],'parent_matrix_local':rest[bone.parent.name]} if bone.parent else {}
        bone.matrix_basis=bone.bone.convert_local_to_pose(pose[bone.name],rest[bone.name],invert=True,**args)
        q=bone.rotation_quaternion.copy()
        if bone.name in previous_quaternions: q.make_compatible(previous_quaternions[bone.name])
        bone.rotation_quaternion=q; previous_quaternions[bone.name]=q.copy()
        bone.keyframe_insert(data_path='location',frame=frame)
        bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
slot=rig.animation_data.action_slot
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points: key.interpolation='LINEAR'

# Check the actual interpolated rig twice per exported frame, not only generated targets.
rows=[]; faces=[]; core_rows=[]; body_edges=[]; body_range=None
for obj in parts:
    start=len(rows)
    for v in obj.data.vertices:
        row=(v.co.copy(),[(obj.vertex_groups[g.group].name,g.weight) for g in v.groups])
        (core_rows if obj['rig_bone']=='core' else rows).append(row)
    if obj['rig_bone']!='core':
        faces.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
    if obj['part']=='Continuous_serpentine_body':
        body_range=(start,len(rows))
        body_edges=[(start+e.vertices[0],start+e.vertices[1],(obj.data.vertices[e.vertices[0]].co-obj.data.vertices[e.vertices[1]].co).length) for e in obj.data.edges]
radius=max((v-core).length for v,_ in core_rows)
minimum_clearance=1e9; minimum_ground=1e9; edge_low=1e9; edge_high=0.; joint_error=0.; scale_error=0.; first=None; seam=0.
for sample in range(FPS*SECONDS*2+1):
    scene.frame_set(1+sample//2,subframe=(sample%2)*.5); bpy.context.view_layer.update()
    transforms={b.name:b.matrix@rest[b.name].inverted() for b in rig.pose.bones}
    coords=[sum(((transforms[name]@v)*weight for name,weight in influences),Vector()) for v,influences in rows]
    c=rig.pose.bones['core'].matrix.translation
    nearest=BVHTree.FromPolygons(coords,faces).find_nearest(c)
    minimum_clearance=min(minimum_clearance,nearest[3]-radius)
    minimum_ground=min(minimum_ground,min(v.z for v in coords))
    for a,b,length in body_edges:
        ratio=(coords[a]-coords[b]).length/length; edge_low=min(edge_low,ratio); edge_high=max(edge_high,ratio)
    for j in range(1,39): joint_error=max(joint_error,(rig.pose.bones[spine[j]].head-rig.pose.bones[spine[j-1]].tail).length)
    for transform in transforms.values(): scale_error=max(scale_error,max(abs(s-1) for s in transform.to_scale()))
    all_coords=coords+[sum(((transforms[name]@v)*weight for name,weight in influences),Vector()) for v,influences in core_rows]
    if sample==0: first=all_coords
    if sample==FPS*SECONDS*2: seam=max((a-b).length for a,b in zip(first,all_coords))
assert minimum_clearance>.008,('core collision margin',minimum_clearance)
assert minimum_ground>.20 and joint_error<1e-5 and scale_error<1e-5
assert seam<1e-5 and .90<edge_low<=edge_high<1.10,(seam,edge_low,edge_high)

rig.animation_data.action=None
track=rig.animation_data.nla_tracks.new(); track.name='idle'
strip=track.strips.new('idle',1,action); strip.action_slot=slot; strip.action_frame_start=1; strip.action_frame_end=END; strip.frame_end=END
strip.blend_type='REPLACE'; scene.frame_set(1); bpy.context.view_layer.update()
vertices=[]; polygons=[]; uvs=[]; groups={}
for obj in parts:
    start=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    polygons.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    for v in obj.data.vertices:
        for g in v.groups: groups.setdefault(obj.vertex_groups[g.group].name,[]).append((start+v.index,g.weight))
data=bpy.data.meshes.new(STEM+'_Runtime'); data.from_pydata(vertices,[],polygons); data.update(); data.materials.append(material)
uv=data.uv_layers.new(name='PixelUV')
for loop,value in zip(uv.data,uvs): loop.uv=value
runtime=bpy.data.objects.new(STEM+'_Body',data); scene.collection.objects.link(runtime); runtime.parent=rig
for name,influences in groups.items():
    group=runtime.vertex_groups.new(name=name)
    for index,weight in influences: group.add([index],weight,'REPLACE')
runtime.modifiers.new('Dragon_Skin','ARMATURE').object=rig
for obj in scene.objects: obj.select_set(False)
for obj in (root,rig,runtime): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_step=1,
    export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False,export_anim_slide_to_zero=True)
bpy.data.objects.remove(runtime,do_unlink=True)
data.calc_loop_triangles()
report=dict(old['report']); report.update(stem=STEM,animations=1,clips=['idle'],source=SOURCE,
    parts=len(parts),triangles=len(data.loop_triangles),eyebrows=False,
    animation={'fps':FPS,'duration_s':SECONDS,'loop':True,'source_samples':FPS*SECONDS*2+1,'geometry_unchanged_except_removed_eyebrows':True,
               'minimum_rotating_core_clearance_m':minimum_clearance,'minimum_ground_clearance_m':minimum_ground,
               'maximum_loop_seam_m':seam,'maximum_spine_joint_error_m':joint_error,
               'maximum_scale_error':scale_error,'body_edge_ratio_range':[edge_low,edge_high],
               'motion':'root float, traveling length-preserving spine wave, free tail sway, balanced head, delayed whiskers, independent rotating core'})
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
for label,frame in [('idle_start',1),('idle_high',46),('idle_mid',91),('idle_low',136)]:
    scene.frame_set(frame); scene.render.filepath=str(OUT/'previews'/(label+'.png')); bpy.ops.render.render(write_still=True)
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for path,digest in protected.items(): assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest
bpy.app.driver_namespace[STEM]={'scene':scene,'rig':rig,'root':root,'parts':parts,'images':images,'report':report}
result=report['animation']
