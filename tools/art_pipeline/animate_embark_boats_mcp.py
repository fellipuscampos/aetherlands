"""Plain, outward-billowed sails and flat-water idle/walk, in live Blender MCP."""
import bpy, bmesh, ast, json, math, hashlib, shutil, struct
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/embark_boats_review'
BACKUP=WORK/'before_sails_animation'
BOATS=bpy.app.driver_namespace['embark_boats_v1']
FPS=30
CLIPS={'idle':(1,121,4.0),'walk':(151,61,2.0)}
STYLE={'human':(1.0,1.10,1.0),'orc':(1.1,1.35,1.1),'elf':(.85,1.15,1.05),'dwarf':(.5,.60,.55)}
SYMBOLS=('Sun_','Bone_Sigil_','Hammer_','Leaf_Vein')
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)

if not BACKUP.exists():
    BACKUP.mkdir()
    for boat in BOATS:
        dest=BACKUP/boat['out'].name; dest.mkdir()
        for suffix in ('.blend','.glb','_report.json'):
            src=boat['out']/(boat['out'].name+suffix)
            if src.exists(): shutil.copy2(src,dest/src.name)
    for name in ('manifest.json','embark_boats_v1_review.blend','four_boats.png'):
        if (WORK/name).exists(): shutil.copy2(WORK/name,BACKUP/name)

# Reuse the established closed-mesh/UV builder without running its batch.
syntax=ast.parse((ROOT/'tools/art_pipeline/build_embark_boats_mcp.py').read_text(encoding='utf-8'))
for node in syntax.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('CUBE','REGIONS') for t in node.targets):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<boat_constants>','exec'))
    if isinstance(node,ast.FunctionDef) and node.name=='mesh':
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<boat_mesh>','exec'))

def stage(race,label):
    (WORK/'current_stage.json').write_text(json.dumps(dict(race=race,stage=label)),encoding='utf-8')

def geometry_hash(obj):
    return hashlib.sha256(repr(([tuple(v.co) for v in obj.data.vertices],
        [tuple(p.vertices) for p in obj.data.polygons],
        [tuple(l.uv) for l in obj.data.uv_layers.active.data])).encode()).hexdigest()

def recalc(data):
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),data.name
    assert bm.calc_volume(signed=True)>0,data.name
    bm.to_mesh(data); bm.free(); data.update()

def square_weight(x,z,race):
    half={'human':.77,'orc':.82,'dwarf':.75}[race]
    bottom={'human':1.17,'orc':1.05,'dwarf':1.03}[race]
    top={'human':2.47,'orc':2.29,'dwarf':2.08}[race]
    v=max(0,min(1,(z-bottom)/(top-bottom)))
    u=max(0,min(1,x/(2*half*(1-.13*(1-v)))+.5))
    return max(0,math.sin(math.pi*u)*math.sin(math.pi*v))

def values(race,clip,index,count):
    t=index/(count-1); phase=math.tau*t
    idle=clip=='idle'; factor,roll,flutter=STYLE[race]
    heave=(.028 if idle else .070)*factor
    pitch=math.radians(.40 if idle else .9)*factor
    roll=math.radians(roll*(.5 if idle else 1.0))
    envelope=(1-math.cos(phase))/2
    # All heave goes DOWN into the fixed water plane. Horizontal motion is zero.
    z=-heave*(1-math.cos(2*phase))/2
    rotations=(pitch*math.sin(2*phase)*envelope,roll*math.sin(phase)*envelope,0)
    weight=(.22 if idle else .65)*flutter*(1-math.cos((1 if idle else 2)*phase))/2
    if index in (0,count-1): return (0.,0.,0.),(0.,0.,0.),0.
    return (0.,0.,z),rotations,weight

def tracks(owner,race,kind,stem):
    owner.animation_data_clear(); owner.animation_data_create()
    for clip,(start,count,duration) in CLIPS.items():
        action=bpy.data.actions.new(stem+'_'+clip+'_'+kind); action.use_fake_user=True
        owner.animation_data.action=action
        for index in range(count):
            location,rotation,weight=values(race,clip,index,count)
            if kind=='Motion':
                owner.location=location; owner.rotation_euler=rotation
                owner.keyframe_insert('location',frame=index+1)
                owner.keyframe_insert('rotation_euler',frame=index+1)
            else:
                key=owner.key_blocks['Sail_Billow']; key.value=weight
                key.keyframe_insert('value',frame=index+1)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation='LINEAR'
        slot=owner.animation_data.action_slot
        owner.animation_data.action=None
        track=owner.animation_data.nla_tracks.new(); track.name=clip
        strip=track.strips.new(clip,start,action); strip.action_slot=slot
        strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
        action.pose_markers.new('LOOP_START').frame=1
        action.pose_markers.new('LOOP_END').frame=count
    if kind=='Motion': owner.location=(0,0,0); owner.rotation_euler=(0,0,0)
    else: owner.key_blocks['Sail_Billow'].value=0

def animate_source(boat):
    global scene,root,mat,parts,groups
    race=boat['report']['race']; scene=boat['scene']; root=boat['root']; mat=boat['material']; parts=boat['parts']
    bpy.context.window.scene=scene; scene.frame_set(1)
    groups={label:next(c for c in scene.collection.children if c.name==boat['out'].name+'_'+label) for label in ('Hull','Deck','Rig','Sail','Details')}
    hull_hashes={o['part']:geometry_hash(o) for o in parts if o not in groups['Sail'].objects[:]}
    review=bpy.data.scenes['Embark_Boats_V1_Review']
    removed=sorted({o['part'] for o in parts if o['part'].startswith(SYMBOLS)} |
        {o['part'] for o in review.objects if o.name.startswith(root.name) and o.get('part','').startswith(SYMBOLS)})
    for obj in parts[:]:
        if not obj['part'].startswith(SYMBOLS): continue
        data=obj.data; label=obj['part']; parts.remove(obj)
        for linked in list(bpy.data.objects):
            if linked.type=='MESH' and linked.data==data and linked.get('part')==label:
                bpy.data.objects.remove(linked,do_unlink=True)
        if data.users==0: bpy.data.meshes.remove(data)
    for obj in list(review.objects):
        if obj.name.startswith(root.name) and obj.get('part','').startswith(SYMBOLS):
            data=obj.data; bpy.data.objects.remove(obj,do_unlink=True)
            if data.users==0: bpy.data.meshes.remove(data)
    if race=='elf':
        old=next(o for o in parts if o['part']=='Leaf_Lateen_Sail')
        outline=[(-.025,2.70),(.45,2.46),(.79,1.99),(.80,1.41),(.55,1.04),(-.025,.94)]
        center=Vector((sum(p[0] for p in outline)/6,sum(p[1] for p in outline)/6))
        xy=[Vector(p) for p in outline]+[center+(Vector(p)-center)*.50 for p in outline]+[center]
        weights=[0.]*6+[.72]*6+[1.]
        vertices=[(p.x,.085+.12*w+side*.012,p.y) for side in (-1,1) for p,w in zip(xy,weights)]
        N=len(xy); front=[]
        for i in range(6):
            j=(i+1)%6; front.extend([(i,j,6+j),(i,6+j,6+i),(6+i,6+j,12)])
        faces=front+[tuple(N+i for i in reversed(face)) for face in front]+[(i,(i+1)%6,N+(i+1)%6,N+i) for i in range(6)]
        new=mesh('Leaf_Lateen_Sail_Outward',vertices,faces,'cloth','Sail')
        # Keep the source object, links, and its stable part name.
        new_data=new.data; old_data=old.data
        for linked in bpy.data.objects:
            if linked.type=='MESH' and linked.data==old_data: linked.data=new_data
        parts.remove(new); bpy.data.objects.remove(new,do_unlink=True)
        if old_data.users==0: bpy.data.meshes.remove(old_data)
        old['sail_flutter_weights']=weights*2
    else:
        for obj in parts:
            label=obj['part']; flutter=None
            if label=='Square_Sail':
                flutter=[]
                for v in obj.data.vertices:
                    v.co.y=.22-v.co.y
                    flutter.append(square_weight(v.co.x,v.co.z,race))
            elif label.startswith(('Cream_Border_','Copper_Hem_')):
                flutter=[]; old_base=.12 if race=='human' else .128
                for v in obj.data.vertices:
                    offset=v.co.y-old_base
                    w=square_weight(v.co.x,v.co.z,race)
                    v.co.y=.11+.12*w+.014+offset
                    flutter.append(w)
            elif label.startswith('Sail_Patch_'):
                # Move sewn repairs with the surface, preserving their thickness.
                center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
                old_center=.11-.12*square_weight(center.x,center.z,race)+.040
                flutter=[]
                for v in obj.data.vertices:
                    offset=v.co.y-old_center; w=square_weight(v.co.x,v.co.z,race)
                    v.co.y=.11+.12*w+.018+offset; flutter.append(w)
            if flutter is not None:
                obj['sail_flutter_weights']=flutter; recalc(obj.data)
    for obj in parts:
        if 'sail_flutter_weights' not in obj: continue
        weights=obj['sail_flutter_weights']; assert len(weights)==len(obj.data.vertices)
        assert obj.data.shape_keys is None, 'Preserve existing deformation'
        obj.shape_key_add(name='Basis'); key=obj.shape_key_add(name='Sail_Billow')
        for v,w in zip(key.data,weights): v.co.y+=.04*w
        tracks(obj.data.shape_keys,race,'Billow',boat['out'].name+'_'+obj['part'])
    motion=bpy.data.objects.new(boat['out'].name+'_Motion',None); scene.collection.objects.link(motion)
    motion.parent=root; motion.rotation_mode='XYZ'; motion['flat_water_motion']=True
    for obj in parts: obj.parent=motion
    tracks(motion,race,'Motion',boat['out'].name)
    boat['motion']=motion
    review=bpy.data.scenes['Embark_Boats_V1_Review']
    rroot=next(o for o in review.objects if o.type=='EMPTY' and o.get('race')==race)
    collection=next(c for c in review.collection.children if c.name=='Embark_Boats_V1_'+race+'_Review')
    rmotion=motion.copy(); collection.objects.link(rmotion); rmotion.parent=rroot
    for obj in collection.objects:
        if obj.type=='MESH' and obj.get('part'): obj.parent=rmotion
    boat['review_motion']=rmotion
    for obj in parts:
        if obj['part'] in hull_hashes: assert geometry_hash(obj)==hull_hashes[obj['part']],obj.name
        recalc(obj.data)
    scene.render.fps=FPS; scene.frame_start=1; scene.frame_end=211
    scene.use_preview_range=True; scene.frame_preview_start=1; scene.frame_preview_end=121
    scene.timeline_markers.clear()
    for name,(start,count,duration) in CLIPS.items(): scene.timeline_markers.new(name.upper(),frame=start)
    scene.frame_set(1); scene['animation_clips']=['idle','walk']; scene['flat_water']=True
    validation={}
    keel=next(o for o in parts if o['part']=='Keel')
    for clip,(start,count,duration) in CLIPS.items():
        submerged=[]; heave=[]; endpoints=[]
        for i in range(count):
            scene.frame_set(start+i); scene.view_layers[0].update()
            assert abs(motion.location.x)+abs(motion.location.y)<1e-8
            assert motion.location.z<=1e-8, 'Boat rises above its waterline'
            submerged.append(max((motion.matrix_local@v.co).z for v in keel.data.vertices))
            heave.append(motion.location.z)
            if i in (0,count-1): endpoints.append(motion.matrix_local.copy())
        loop_error=max(abs(a-b) for ar,br in zip(endpoints[0],endpoints[1]) for a,b in zip(ar,br))
        assert loop_error<1e-7 and max(submerged)<-.20
        validation[clip]=dict(duration=duration,frames=count,fps=FPS,loop_error=loop_error,
            vertical_range_native=[min(heave),max(heave)],vertical_range_map=[min(heave)*.52,max(heave)*.52],
            highest_keel_vertex=max(submerged),in_place=True,water_plane_static=True)
    scene.frame_set(1)
    points=[v.co for o in parts for v in o.data.vertices]
    report=boat['report']; report.update(sail_revision=2,sail_symbols=False,sail_billow_direction='Blender +Y / Godot -Z',
        removed_symbols=removed,editable_parts=len(parts),animations=validation,
        bounds_blender=dict(min=[min(v[i] for v in points) for i in range(3)],max=[max(v[i] for v in points) for i in range(3)]))
    stage(race,'source_animated')

def export_animated(boat):
    race=boat['report']['race']; source=boat['scene']; out=boat['out']; parts=boat['parts']
    source.frame_set(1); bpy.context.window.scene=source; source.view_layers[0].update()
    temporary=bpy.data.scenes.new(out.name+'_Animated_Export_Temporary'); temporary.render.fps=FPS
    temporary.frame_start=1; temporary.frame_end=211
    ids={temporary}; eroot=bpy.data.objects.new(out.name,None); temporary.collection.objects.link(eroot); ids.add(eroot)
    eroot['race']=race; eroot['waterline']=0.; eroot['forward']='Godot -Z'
    motion=boat['motion'].copy(); motion.name='BoatMotion'; temporary.collection.objects.link(motion); motion.parent=eroot; ids.add(motion)
    try:
        for label in ('Hull','Deck','Rig','Sail','Details'):
            collection=next(c for c in source.collection.children if c.name==out.name+'_'+label)
            sources=[o for o in parts if o in collection.objects[:]]
            if not sources: continue
            vertices=[]; faces=[]; uvs=[]; weights=[]
            for obj in sources:
                offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
                faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
                uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
                weights.extend(list(obj.get('sail_flutter_weights',[0.]*len(obj.data.vertices))))
            data=bpy.data.meshes.new(out.name+'_'+label+'_Animated'); data.from_pydata(vertices,[],faces); data.update(); ids.add(data)
            uv=data.uv_layers.new(name='Pixel_UV')
            for loop,value in zip(uv.data,uvs): loop.uv=value
            data.materials.append(boat['material'])
            obj=bpy.data.objects.new(label,data); temporary.collection.objects.link(obj); obj.parent=motion; ids.add(obj)
            if any(weights):
                obj.shape_key_add(name='Basis'); key=obj.shape_key_add(name='Sail_Billow')
                for v,w in zip(key.data,weights): v.co.y+=.04*w
                tracks(data.shape_keys,race,'Billow',out.name+'_Runtime_'+label)
        bpy.context.window.scene=temporary; temporary.frame_set(1)
        for obj in temporary.objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=motion
        stage(race,'export_animated')
        bpy.ops.export_scene.gltf(filepath=str(out/(out.name+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
            export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,
            export_anim_slide_to_zero=True,export_skins=False,export_morph=True,export_yup=True,
            export_cameras=False,export_lights=False,export_extras=True)
    finally:
        bpy.context.window.scene=source; bpy.data.batch_remove(ids=ids)
    raw=(out/(out.name+'.glb')).read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size])
    assert sorted(a['name'] for a in doc.get('animations',[]))==['idle','walk'],[a['name'] for a in doc.get('animations',[])]
    assert len(doc['materials'])==1 and len(doc['images'])==2
    assert any(p.get('targets') for m in doc['meshes'] for p in m['primitives'])
    report=boat['report']; report.update(triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives']),
        game_meshes=len(doc['meshes']),glb_sha256=hashlib.sha256(raw).hexdigest(),exported_clips=['idle','walk'],morph_targets=1)
    source.frame_set(1)
    bpy.data.libraries.write(str(out/(out.name+'.blend')),{source},fake_user=True,compress=True)
    (out/(out.name+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')

# Save callable stages so a failed export can be retried without editing geometry twice.
bpy.app.driver_namespace['embark_boats_export_animated']=export_animated
for boat in BOATS:
    if boat['report'].get('sail_revision')!=2:
        stage(boat['report']['race'],'revise_sails'); animate_source(boat)
    export_animated(boat)
review=bpy.data.scenes['Embark_Boats_V1_Review']; bpy.context.window.scene=review
review.render.fps=FPS; review.frame_start=1; review.frame_end=211
review.use_preview_range=True; review.frame_preview_start=1; review.frame_preview_end=121; review.frame_set(1)
review.timeline_markers.clear()
for clip,(start,count,duration) in CLIPS.items(): review.timeline_markers.new(clip.upper(),frame=start)
bpy.data.libraries.write(str(WORK/'embark_boats_v1_review.blend'),{review,*[b['scene'] for b in BOATS]},fake_user=True,compress=True)
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8')); manifest['assets']=[b['report'] for b in BOATS]
manifest.update(animations=['idle','walk'],flat_water_motion=True,sail_revision=2)
(WORK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
stage('all','animated_exports_complete')
result=dict(status='PASS',boats=4,clips=['idle','walk'],flat_water=True,removed_symbols={b['report']['race']:len(b['report']['removed_symbols']) for b in BOATS})
