"""Add flight, bite and elemental casting, preserving the approved mesh and idle."""
import bpy,math,json,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
CONFIG=globals().get('DRAGON_ACTION_CONFIG',{})
SOURCE=CONFIG.get('source','elemental_dragon_v5_animated'); STEM=CONFIG.get('stem','elemental_dragon_v6_animated')
SCENE_NAME=CONFIG.get('scene','Elemental_Dragon_V6_Animated')
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
assert not (OUT/(STEM+'.glb')).exists(),'Preserve the existing animation package.'
old=bpy.app.driver_namespace[SOURCE]
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
failed=bpy.data.scenes.get(SCENE_NAME)
if failed:
    bpy.context.window.scene=old['scene']
    for obj in list(failed.objects): bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.scenes.remove(failed)
protected={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'assets/generated/grand_manifestations').glob('*/*.glb')}
OUT.mkdir(parents=True,exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
old['scene'].frame_set(1)
scene=bpy.data.scenes.new(SCENE_NAME); bpy.context.window.scene=scene
scene.world=old['scene'].world.copy(); scene.unit_settings.system='METRIC'
copies={}
for original in old['scene'].objects:
    obj=original.copy(); obj.animation_data_clear()
    if original.data: obj.data=original.data.copy()
    obj.name=original.name.replace(SOURCE,STEM); scene.collection.objects.link(obj); copies[original]=obj
for original,obj in copies.items():
    obj.parent=copies.get(original.parent)
    for modifier in obj.modifiers:
        if modifier.type=='ARMATURE': modifier.object=copies[old['rig']]
rig=copies[old['rig']]; root=copies[old['root']]; parts=[copies[o] for o in old['parts']]
scene.camera=copies[old['scene'].camera]
material=parts[0].data.materials[0].copy(); material.name=STEM+'_Pixel_Material'; images=[]
for original,suffix in zip(old['images'],('albedo','emission')):
    path=OUT/(STEM+'_'+suffix+'.png'); shutil.copy2(original.filepath_raw,path)
    copied=bpy.data.images.load(str(path),check_existing=False); copied.pack(); images.append(copied)
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image==original: node.image=copied
for obj in parts: obj.data.materials.clear(); obj.data.materials.append(material)
assert not any(o['part'].startswith(('Brow_','fore_','hind_','Dorsal_crystal_','Head_mane_')) for o in parts)
assert all([tuple(v.co) for v in a.data.vertices]==[tuple(v.co) for v in b.data.vertices] for a,b in zip(old['parts'],parts))
if CONFIG.get('rig_setup_file'):
    setup=ROOT/'tools/art_pipeline'/CONFIG['rig_setup_file']
    exec(compile(setup.read_text(encoding='utf-8'),str(setup),'exec'),globals())
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
core=rest['core'].translation.copy(); spine=['spine_%02d'%i for i in range(39)]
FPS=30; scene.render.fps=FPS

def ease(t):
    t=max(0.,min(1.,t)); return t*t*t*(t*(t*6-15)+10)

def pulse(t,start,rise,hold,end):
    if t<=start or t>=end: return 0.
    return ease((t-start)/(rise-start)) if t<rise else (1. if t<=hold else 1-ease((t-hold)/(end-hold)))

def rotated_at(matrix,axis,angle):
    result=(Matrix.Rotation(angle,3,axis)@matrix.to_3x3()).to_4x4(); result.translation=matrix.translation
    return result

def wave(point,s,p,mult=1.):
    freedom=max(0.,min(1.,((point-core).length-.78)/.45))
    amp=(.008+freedom*(.045+.055*s**3.5))*mult; phase=-math.tau*1.7*s
    return Vector((amp*.65*(math.sin(p+phase)-math.sin(phase)),
                   amp*.90*(math.sin(p+phase+.4)-math.sin(phase+.4)),
                   amp*.65*(math.cos(p+phase)-math.cos(phase))))*.5

def frame_pose(clip,t,duration):
    p=math.tau*t/duration; wind=hit=charge=release=jaw=0.
    lean=bank=lift=advance=0.; strength=1.
    if clip=='walk':
        strength=1.05; lean=4.; bank=.65*math.sin(p); lift=.024*math.sin(p)
    elif clip=='attack':
        strength=.55
        wind=pulse(t,0,.48,.58,.98); hit=pulse(t,.55,.84,.91,1.60)
        jaw=24*pulse(t,.10,.45,.67,1.02)
        lean=-2*wind+6*hit; advance=.065*wind-.26*hit; lift=.05*hit
    elif clip=='spell':
        strength=.65
        charge=pulse(t,0,1.15,2.25,3.85); release=pulse(t,1.85,2.22,2.32,2.85)
        jaw=13*charge+5*release
        lean=-3.5*charge+2.0*release; lift=.16*charge+.035*release
    G=Matrix.Translation((0,advance,lift))@Matrix.Translation(core)@Matrix.Rotation(math.radians(lean),4,'X')@Matrix.Rotation(math.radians(bank),4,'Y')@Matrix.Translation(-core)
    def target_for(point,s):
        delta=wave(point,s,p,strength)
        neck=max(0.,1-s/.21)**3
        if clip=='attack': delta+=Vector((0,.018*wind-.045*hit,-.018*hit))*neck
        elif clip=='spell':
            delta+=Vector((0,.012*charge,.055*charge))*neck
            radial=point-core; radial.y=0
            if radial.length>.01: delta+=radial.normalized()*.016*charge*min(1.,max(0.,(point-core).length-.55))
        return point+delta
    pose={'root':rest['root'].copy()}
    current=target_for(rest[spine[0]].translation,0)
    for j,name in enumerate(spine):
        bone=rig.data.bones[name]; direction=(target_for(bone.tail_local,(j+1)/39)-current).normalized()
        rotation=(bone.tail_local-bone.head_local).normalized().rotation_difference(direction).to_matrix()@rest[name].to_3x3()
        matrix=rotation.to_4x4(); matrix.translation=current; pose[name]=matrix
        current+=direction*bone.length
    for bone in rig.data.bones:
        name=bone.name
        if name in pose: continue
        parent=bone.parent.name; pose[name]=pose[parent]@rest[parent].inverted()@rest[name]
        if name=='head':
            pitch=(.4*math.sin(2*p) if clip=='walk' else (-3*wind+4*hit if clip=='attack' else -5*charge+2*release))
            pose[name]=rotated_at(pose[name],'X',math.radians(pitch))
        elif name=='jaw': pose[name]=rotated_at(pose[name],'X',math.radians(jaw))
        elif name.startswith('whisker_'):
            side=int(name.split('_')[1]); segment=int(name.split('_')[2]); lag=.28*segment
            flutter=1.8*(math.sin(p-lag)-math.sin(-lag))+side*(2*hit+2*release)
            pose[name]=rotated_at(pose[name],'Z',math.radians(side*flutter))
        elif name=='core':
            angle=p if clip=='walk' else math.tau*(2 if clip=='spell' else 1)*ease(t/duration)
            pose[name]=rotated_at(rest[name],'Z',angle)
            if clip=='spell': pose[name]=rotated_at(pose[name],'Y',math.radians(7)*charge*math.sin(p))
    return {name:G@matrix for name,matrix in pose.items()}

if CONFIG.get('motion_file'):
    motion=ROOT/'tools/art_pipeline'/CONFIG['motion_file']
    exec(compile(motion.read_text(encoding='utf-8'),str(motion),'exec'),globals())

def fingerprint(action):
    curves=[]
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves: curves.append((curve.data_path,curve.array_index,[(tuple(k.co),k.interpolation) for k in curve.keyframe_points]))
    return hashlib.sha256(repr(curves).encode()).hexdigest()

original_idle=old['rig'].animation_data.nla_tracks[0].strips[0].action
idle=original_idle.copy(); idle.name=STEM+'_idle'
assert fingerprint(idle)==fingerprint(original_idle)
specs={'idle':(6.,True),'walk':(3.,True),'attack':(2.4,False),'spell':(4.,False)}
for name,duration in CONFIG.get('clip_durations',{}).items():
    specs[name]=(float(duration),specs[name][1])
clips={} if CONFIG.get('remake_idle') else {'idle':{'action':idle,'slot':idle.slots[0],'duration_s':6.,'loop':True,'end_frame':181}}
rig.animation_data_create()
for name,(duration,loop) in specs.items():
    if name=='idle' and not CONFIG.get('remake_idle'): continue
    action=bpy.data.actions.new(STEM+'_'+name); action.use_fake_user=True; rig.animation_data.action=action
    previous={}; end=round(duration*FPS)+1
    for frame in range(1,end+1):
        pose=frame_pose(name,(frame-1)/FPS,duration)
        for bone in rig.pose.bones:
            bone.rotation_mode='QUATERNION'
            args={'parent_matrix':pose[bone.parent.name],'parent_matrix_local':rest[bone.parent.name]} if bone.parent else {}
            bone.matrix_basis=bone.bone.convert_local_to_pose(pose[bone.name],rest[bone.name],invert=True,**args)
            q=bone.rotation_quaternion.copy()
            if bone.name in previous: q.make_compatible(previous[bone.name])
            bone.rotation_quaternion=q; previous[bone.name]=q.copy()
            for path in ('location','rotation_quaternion','scale'): bone.keyframe_insert(data_path=path,frame=frame)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    if name=='attack': action.pose_markers.new('IMPACT').frame=26
    if name=='spell': action.pose_markers.new('CAST').frame=68
    clips[name]={'action':action,'slot':rig.animation_data.action_slot,'duration_s':duration,'loop':loop,'end_frame':end}
rig.animation_data.action=None; cursor=1
for name,info in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,cursor,info['action']); strip.action_slot=info['slot']
    strip.action_frame_start=1; strip.action_frame_end=info['end_frame']; strip.frame_end=cursor+info['end_frame']-1
    strip.blend_type='REPLACE'; strip.extrapolation='NOTHING'; info['start_frame']=cursor
    scene.timeline_markers.new(name,frame=cursor); cursor+=info['end_frame']+30

rows=[]; faces=[]; core_rows=[]; edges=[]; body_span=None
for obj in parts:
    start=len(rows)
    for v in obj.data.vertices:
        row=(v.co.copy(),[(obj.vertex_groups[g.group].name,g.weight) for g in v.groups])
        (core_rows if obj['rig_bone']=='core' else rows).append(row)
    if obj['rig_bone']!='core': faces.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
    if obj['part']=='Continuous_serpentine_body':
        body_span=(start,len(rows))
        edges=[(start+e.vertices[0],start+e.vertices[1],(obj.data.vertices[e.vertices[0]].co-obj.data.vertices[e.vertices[1]].co).length,e.vertices[0]//4==e.vertices[1]//4) for e in obj.data.edges]
radius=max((v-core).length for v,_ in core_rows); checks={}
for name,info in clips.items():
    minimum=ground=low=1e9; high=joint_error=scale_error=seam=0.; first=None
    width_low=pulse_low=1e9; width_high=pulse_high=body_motion=0.; first_body=None
    count=round(info['duration_s']*FPS*2)+1
    for sample in range(count):
        scene.frame_set(info['start_frame']+sample//2,subframe=(sample%2)*.5); bpy.context.view_layer.update()
        transforms={b.name:b.matrix@rest[b.name].inverted() for b in rig.pose.bones}
        points=[sum(((transforms[n]@v)*w for n,w in influences),Vector()) for v,influences in rows]
        center=rig.pose.bones['core'].matrix.translation
        nearest=BVHTree.FromPolygons(points,faces).find_nearest(center)
        core_scale=rig.pose.bones['core'].matrix.to_scale().x
        pulse_low=min(pulse_low,core_scale); pulse_high=max(pulse_high,core_scale)
        minimum=min(minimum,nearest[3]-radius*core_scale); ground=min(ground,min(v.z for v in points))
        for a,b,length,cross_section in edges:
            ratio=(points[a]-points[b]).length/length; low=min(low,ratio); high=max(high,ratio)
            if cross_section: width_low=min(width_low,ratio); width_high=max(width_high,ratio)
        root_inverse=transforms['root'].inverted()
        body_local=[root_inverse@point for point in points[body_span[0]:body_span[1]]]
        if sample==0: first_body=body_local
        body_motion=max(body_motion,max((a-b).length for a,b in zip(first_body,body_local)))
        for j in range(1,39): joint_error=max(joint_error,(rig.pose.bones[spine[j]].head-rig.pose.bones[spine[j-1]].tail).length)
        for bone,transform in transforms.items():
            scales=transform.to_scale()
            if bone=='core' and CONFIG.get('core_pulse'):
                assert max(scales)-min(scales)<1e-5 and .75<scales.x<1.30
            else: scale_error=max(scale_error,max(abs(s-1) for s in scales))
        all_points=points+[sum(((transforms[n]@v)*w for n,w in influences),Vector()) for v,influences in core_rows]
        if sample==0: first=all_points
        if sample==count-1: seam=max((a-b).length for a,b in zip(first,all_points))
    checks[name]={'samples':count,'minimum_rotating_core_clearance_m':minimum,'minimum_ground_clearance_m':ground,
                  'maximum_joint_error_m':joint_error,'maximum_scale_error':scale_error,'end_pose_difference_m':seam,'body_edge_ratio_range':[low,high],
                  'body_cross_section_ratio_range':[width_low,width_high],'body_motion_beyond_root_m':body_motion,'core_scale_range':[pulse_low,pulse_high]}
    assert minimum>.008,(name,'core margin',minimum)
    assert ground>CONFIG.get('minimum_ground_clearance',.20) and joint_error<1e-5 and scale_error<1e-5,(name,checks[name])
    assert CONFIG.get('minimum_skin_edge_ratio',.88)<low<=high<CONFIG.get('maximum_skin_edge_ratio',1.12),(name,'skin deformation',low,high)
    assert width_low>.90 and width_high<1.001,(name,'cross section distortion',width_low,width_high)
    assert seam<1e-5,(name,'loop or recovery',seam)
if not CONFIG.get('remake_idle'): assert fingerprint(clips['idle']['action'])==fingerprint(original_idle)

scene.frame_start=1; scene.frame_end=clips['idle']['end_frame']; scene.frame_set(1); bpy.context.view_layer.update()
vertices=[]; polygons=[]; uvs=[]; groups={}
for obj in parts:
    start=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    polygons.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons); uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
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
report=dict(old['report']); report.update(stem=STEM,source=SOURCE,animations=4,clips=list(clips),geometry_unchanged=True,idle_keyframes_unchanged=not CONFIG.get('remake_idle',False),
    prepared_bones=list(rig.data.bones.keys()),skinning=CONFIG.get('rig_setup_file','original'),
    core_pulse=CONFIG.get('core_pulse',False),serpentine_body_motion=CONFIG.get('remake_idle',False),
    axial_motion=CONFIG.get('axial_motion',False),
    path_following=CONFIG.get('path_following',False),
    animation_layout=CONFIG.get('animation_layout',{}),
    animation_clips={name:{'duration_s':i['duration_s'],'loop':i['loop'],'start_frame':i['start_frame'],**checks[name]} for name,i in clips.items()})
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
for label,clip,seconds in [('walk_glide','walk',.75),('attack_anticipation','attack',.48),('attack_impact','attack',.84),('spell_cast','spell',2.22)]:
    scene.frame_set(clips[clip]['start_frame']+round(seconds*FPS)); scene.render.filepath=str(OUT/'previews'/(label+'.png')); bpy.ops.render.render(write_still=True)
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for path,digest in protected.items(): assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest
bpy.app.driver_namespace[STEM]={'scene':scene,'rig':rig,'root':root,'parts':parts,'images':images,'report':report,'clips':clips}
result=report['animation_clips']
