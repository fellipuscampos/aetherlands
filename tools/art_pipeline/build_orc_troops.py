"""Clone the approved orc anatomy, fit class equipment and retarget flat IK.

Runs only in the user's open Blender via MCP. Elf files supply class equipment
and motion references, never the humanoid body. Hands retain reference poses
so weapons, bow strings and reins keep their original contact points.
"""
import hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh,numpy as np
from mathutils import Vector,Matrix

sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import ROOT,OUT,WORK,BASE,PROFILES
from build_elf_troops import BODY,reset_pose,pixels,export_glb
from build_orc_squire import cuboid_axes,resize,rectangle
from orc_troop_paint import body as paint_body,equipment as paint_equipment


def load_scene(path):
    with bpy.data.libraries.load(str(path),link=False) as (source,loaded): loaded.scenes=source.scenes
    return loaded.scenes[0]


def action_curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in list(bag.fcurves): yield bag,curve


def solve_arm(a,wrist,l1,l2,pole):
    d=(wrist-a).length; direction=(wrist-a).normalized()
    assert d<l1+l2+.0001,(d,l1,l2)
    d=max(abs(l1-l2)+.00001,min(d,l1+l2-.00001))
    projected=pole-a-direction*(pole-a).dot(direction)
    if projected.length<.00001: projected=Vector((0,1,-.3))-direction*direction.dot(Vector((0,1,-.3)))
    projected.normalize()
    along=(l1*l1-l2*l2+d*d)/(2*d)
    return a+direction*along+projected*math.sqrt(max(0,l1*l1-along*along))


def frame_for(old,head,tail):
    change=(old.to_3x3()@Vector((0,1,0))).normalized().rotation_difference((tail-head).normalized()).to_matrix()
    result=(change@old.to_3x3()).to_4x4(); result.translation=head
    return result


def collect_motion(scene,rig):
    bpy.context.window.scene=scene; rig.animation_data.action=None
    tracks=list(rig.animation_data.nla_tracks); result=[]
    for track in tracks:
        for other in tracks: other.mute=other!=track
        strip=track.strips[0]; frames=[]
        for frame in range(round(strip.frame_start),round(strip.frame_end)+1):
            scene.frame_set(frame); bpy.context.view_layer.update()
            local=strip.action_frame_start+(frame-strip.frame_start)/strip.scale
            frames.append((local,{pb.name:pb.matrix.copy() for pb in rig.pose.bones}))
        result.append(dict(name=track.name,action=strip.action,frame_start=strip.frame_start,
            action_start=strip.action_frame_start,action_end=strip.action_frame_end,frames=frames))
    reset_pose(rig,scene)
    return result


def target_rig(scene,rig,source_rig,motion,head_scale):
    old={b.name:b.matrix_local.copy() for b in source_rig.data.bones}
    rig.data=source_rig.data.copy(); rig.animation_data_clear(); rig.animation_data_create()
    offsets={}; lengths={}; target={n:m.copy() for n,m in old.items()}
    factors={}
    for side,sign in (('l',1),('r',-1)):
        shoulder_offset=Vector((sign*.15*head_scale,0,0))
        l1=source_rig.data.bones['upper_arm_'+side].length
        l2=source_rig.data.bones['forearm_'+side].length
        reach=(old['hand_'+side].translation-(old['upper_arm_'+side].translation+shoulder_offset)).length
        for clip in motion:
            for _,pose in clip['frames']:
                delta=pose['chest']@old['chest'].inverted()
                a=pose['upper_arm_'+side].translation+delta.to_3x3()@shoulder_offset
                reach=max(reach,(pose['hand_'+side].translation-a).length)
        factor=max(1.,reach/(l1+l2)*1.008)
        l1*=factor; l2*=factor; factors[side]=factor
        lengths['upper_arm_'+side]=l1; lengths['forearm_'+side]=l2
        a=old['upper_arm_'+side].translation+shoulder_offset; wrist=old['hand_'+side].translation
        elbow=solve_arm(a,wrist,l1,l2,old['forearm_'+side].translation)
        target['upper_arm_'+side]=frame_for(old['upper_arm_'+side],a,elbow)
        target['forearm_'+side]=frame_for(old['forearm_'+side],elbow,wrist)
        offsets['shoulder_'+side]=list(shoulder_offset)
        leg_offset=Vector((sign*.055*head_scale,0,0)); offsets['leg_'+side]=list(leg_offset)
        for prefix in ('thigh','shin','foot'):
            target[prefix+'_'+side].translation+=leg_offset
    bpy.context.window.scene=scene
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name,matrix in target.items():
        bone=rig.data.edit_bones[name]; bone.matrix=matrix
        if name in lengths: bone.length=lengths[name]
    bpy.ops.object.mode_set(mode='OBJECT')
    target={b.name:b.matrix_local.copy() for b in rig.data.bones}
    modified={p+'_'+s for s in ('l','r') for p in ('upper_arm','forearm','thigh','shin','foot')}
    for clip in motion:
        action=clip['action'].copy(); action.name='Orc_'+clip['name']
        for bag,curve in list(action_curves(action)):
            if any('pose.bones["'+name+'"]' in curve.data_path for name in modified): bag.fcurves.remove(curve)
        rig.animation_data.action=action
        if action.slots: rig.animation_data.action_slot=action.slots[0]
        previous={}
        for frame,pose in clip['frames']:
            desired={}
            for side in ('l','r'):
                delta=pose['chest']@old['chest'].inverted()
                a=pose['upper_arm_'+side].translation+delta.to_3x3()@Vector(offsets['shoulder_'+side])
                wrist=pose['hand_'+side].translation
                elbow=solve_arm(a,wrist,lengths['upper_arm_'+side],lengths['forearm_'+side],pose['forearm_'+side].translation)
                desired['upper_arm_'+side]=frame_for(pose['upper_arm_'+side],a,elbow)
                desired['forearm_'+side]=frame_for(pose['forearm_'+side],elbow,wrist)
                hip_delta=pose['hips']@old['hips'].inverted()
                shift=hip_delta.to_3x3()@Vector(offsets['leg_'+side])
                for prefix in ('thigh','shin','foot'):
                    matrix=pose[prefix+'_'+side].copy(); matrix.translation+=shift
                    desired[prefix+'_'+side]=matrix
            for name,matrix in desired.items():
                local_rest=target['root'].inverted()@target[name]
                pb=rig.pose.bones[name]; pb.rotation_mode='QUATERNION'
                pb.matrix_basis=local_rest.inverted()@pose['root'].inverted()@matrix
                if name in previous and previous[name].dot(pb.rotation_quaternion)<0: pb.rotation_quaternion.negate()
                previous[name]=pb.rotation_quaternion.copy()
                pb.keyframe_insert('rotation_quaternion',frame=frame,group=name)
                pb.keyframe_insert('location',frame=frame,group=name)
        for _,curve in action_curves(action):
            for key in curve.keyframe_points: key.interpolation='LINEAR'
        rig.animation_data.action=None
        track=rig.animation_data.nla_tracks.new(); track.name=clip['name']
        strip=track.strips.new(clip['name'],round(clip['frame_start']),action)
        strip.action_frame_start=clip['action_start']; strip.action_frame_end=clip['action_end']
        strip.blend_type='REPLACE'; strip.extrapolation='NOTHING'; track.mute=True
    reset_pose(rig,scene)
    return old,target,dict(shoulder_and_leg_offsets=offsets,arm_reach_factors=factors,
        original_hand_contact_poses_preserved=True,modified_bones=sorted(modified))


def fit_part(obj,base_rest,target_rest,rig,scale):
    name=obj['part']; bone=obj['rig_bone']; vertices,axes=cuboid_axes(obj)
    center=vertices.mean(axis=0); old=base_rest[bone]; new=target_rest[bone]
    change=new.to_3x3()@old.to_3x3().inverted()
    height=scale
    if name.startswith(('UpperArm','Forearm','Thigh','Shin')):
        height=rig.data.bones[bone].length/obj['template_bone_length']
    frame=axes/np.linalg.norm(axes,axis=0)
    delta=old.to_3x3().inverted()@(Vector(center)-old.translation)
    delta=Vector((delta.x*scale,delta.y*height,delta.z*scale))
    destination=new.translation+new.to_3x3()@delta
    # The mesh frame keeps all three cuboid axes orthogonal after adaptation.
    rotated=np.array(change)@frame
    updated=((vertices-center)@frame*np.array([scale,scale,height]))@rotated.T+np.array(destination)
    if name.startswith('Shoulder'):
        side=name[-1]; source_arm=base_rest['upper_arm_'+side].translation
        destination=target_rest['upper_arm_'+side].translation+(Vector(center)-source_arm)*scale
        updated=((vertices-center)*scale)@np.array(change).T+np.array(destination)
    for vertex,position in zip(obj.data.vertices,updated): vertex.co=position
    obj.data.update()


def pack_equipment(canvas,objects,row):
    face_index=0; audit={}
    width,height=canvas.shape[1],canvas.shape[0]; size=28; origin=width//2
    for obj in objects:
        uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
        for poly in obj.data.polygons:
            col=face_index%18; line=face_index//18; x=origin+4+col*size; y=4+line*size
            assert x+24<width and y+24<height
            coords=[obj.data.vertices[i].co for i in poly.vertices]
            axis=(coords[1]-coords[0]).normalized(); other=poly.normal.cross(axis).normalized()
            projected=np.array([[p.dot(axis),p.dot(other)] for p in coords])
            lo=projected.min(axis=0); extent=projected.max(axis=0)-lo
            assert min(extent)>.000001,(obj.name,poly.index)
            for loop,point in zip(poly.loop_indices,projected):
                p=np.array([x+2,y+2])+(point-lo)/extent*20
                uv.data[loop].uv=(p[0]/width,p[1]/height)
            tile,kind=paint_equipment(obj['part'],obj['region'],poly.normal,(24,24),row)
            canvas[y:y+24,x:x+24,:3]=tile; audit[obj['part']]=kind
            face_index+=1
    return audit


def save_atlas(canvas,path,name):
    image=bpy.data.images.new(name,width=canvas.shape[1],height=canvas.shape[0],alpha=True)
    image.colorspace_settings.name='Non-Color'; image.pixels.foreach_set((canvas.astype(np.float32)/255).ravel())
    image.file_format='PNG'; image.filepath_raw=str(path); image.save()
    image.colorspace_settings.name='sRGB'; image.reload(); image.pack()
    return image


def build(row,views=('front','three_quarter','back','game_top')):
    if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
    scene=load_scene(BASE); scene.name=row['stem']+'_Scene'; bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None); root.scale=(1,1,1)
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts: obj.data=obj.data.copy()
    reset_pose(rig,scene)
    base_rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
    for obj in parts: obj['template_bone_length']=rig.data.bones[obj['rig_bone']].length
    base_by={o['part']:o for o in parts}
    approved_image=next(n.image for n in parts[0].data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
    original=pixels(approved_image)
    source_path=ROOT/'assets/generated/elves'/row['source_stem']/(row['source_stem']+'.blend')
    source_scene=load_scene(source_path); source_rig=next(o for o in source_scene.objects if o.type=='ARMATURE')
    source_parts=[o for o in source_scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    source_head=next(o for o in source_parts if o.get('part')=='Head')
    head_scale=(max(v.co.z for v in source_head.data.vertices)-min(v.co.z for v in source_head.data.vertices))/(max(v.co.z for v in base_by['Head'].data.vertices)-min(v.co.z for v in base_by['Head'].data.vertices))
    motion=collect_motion(source_scene,source_rig)
    scene.render.fps=source_scene.render.fps
    old,target,retarget=target_rig(scene,rig,source_rig,motion,head_scale)
    for obj in list(parts):
        if obj['part'].startswith('Shield') and row['family']!='guardian':
            parts.remove(obj); bpy.data.objects.remove(obj,do_unlink=True); continue
        fit_part(obj,base_rest,target,rig,head_scale)
        if obj['part'].startswith('Shield') and obj['part']!='ShieldGrip' and row['tier']>0:
            resize(obj,(1+row['tier']*.035,1,1+row['tier']*.035))
    gear=[]; exclusions=set(BODY)|{'Buckle'}
    for obj in source_parts:
        name=obj['part']
        if name in exclusions or name.startswith('ElfEar') or obj.get('rig_bone')=='head': continue
        if row['family']=='guardian' and name.startswith('Shield'): continue
        copy=obj.copy(); copy.data=obj.data.copy(); scene.collection.objects.link(copy)
        copy.parent=rig
        for modifier in copy.modifiers:
            if modifier.type=='ARMATURE': modifier.object=rig
        bone=copy.get('rig_bone')
        if bone in target:
            change=target[bone]@old[bone].inverted()
            for vertex in copy.data.vertices: vertex.co=change@vertex.co
        if row['family'] in ('warrior','rogue') and bone in ('hand_l','hand_r'):
            pivot=target[bone].translation
            factor=1.25 if row['family']=='warrior' else 1.55
            for vertex in copy.data.vertices: vertex.co=pivot+(vertex.co-pivot)*factor
        # Back equipment and side pouches must clear the thicker orc body.
        if name in ('Quiver','Arrows','PeltCape','Cape','CapeUpper','CapeLower','ShortMantle','SplitMantle_l','SplitMantle_r','RoyalMantle_l','RoyalMantle_r'):
            for v in copy.data.vertices: v.co.y+=.05*head_scale
        if name in ('BeltPouch','ToolSatchel','ThrowingKnifeCase','Tool_0','Tool_1','Tool_2','ToolClasp'):
            center=sum((v.co for v in copy.data.vertices),Vector())/len(copy.data.vertices)
            shift=.075*head_scale*(1 if center.x>0 else -1)
            for v in copy.data.vertices: v.co.x+=shift
        if copy.get('region') in ('tabard','cape','cloak','royal_cloak','pelt'):
            center=sum((v.co for v in copy.data.vertices),Vector())/len(copy.data.vertices)
            for v in copy.data.vertices: v.co.x=center.x+(v.co.x-center.x)*1.45
        gear.append(copy); parts.append(copy)
    canvas=np.zeros((original.shape[0],original.shape[1]*2,4),dtype=np.uint8); canvas[...,3]=255
    canvas[:,:original.shape[1]]=original
    for obj in parts:
        if obj in gear: continue
        for loop in obj.data.uv_layers.active.data: loop.uv.x*=.5
        for poly in obj.data.polygons:
            lo,hi,frac=rectangle(obj,poly,canvas.shape[1],canvas.shape[0]); paint_body(canvas,obj,poly,lo,hi,frac,row)
            x0,y0=lo; x1,y1=hi
            if x0>0: canvas[y0:y1,x0-1]=canvas[y0:y1,x0]
            if x1<canvas.shape[1]//2: canvas[y0:y1,x1]=canvas[y0:y1,x1-1]
            if y0>0: canvas[y0-1,x0:x1]=canvas[y0,x0:x1]
            if y1<canvas.shape[0]: canvas[y1,x0:x1]=canvas[y1-1,x0:x1]
    gear_materials=pack_equipment(canvas,gear,row)
    out=OUT/row['stem']; out.mkdir(parents=True,exist_ok=True)
    atlas=save_atlas(canvas,out/(row['stem']+'_albedo.png'),row['stem']+'_albedo')
    material=bpy.data.materials.new(row['stem']+'_Painted_Materials'); material.use_nodes=True
    shader=material.node_tree.nodes.get('Principled BSDF'); shader.inputs['Roughness'].default_value=.86
    texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=atlas; texture.interpolation='Closest'
    material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
    for obj in parts:
        obj.data.materials.clear(); obj.data.materials.append(material)
        bm=bmesh.new(); bm.from_mesh(obj.data); assert all(e.is_manifold for e in bm.edges),obj.name; bm.free()
    by={o['part']:o for o in parts}
    # An upright character's segment heights also provide an honest size for
    # mounted riders: horse/lance height never masquerades as rider height.
    standing=(max(v.co.z for v in by['Head'].data.vertices)-target['thigh_l'].translation.z
        +rig.data.bones['thigh_l'].length+rig.data.bones['shin_l'].length
        +target['foot_l'].translation.z-min(v.co.z for v in by['Foot_l'].data.vertices))
    if row['family']!='cavalry':
        standing=max(v.co.z for v in by['Head'].data.vertices)-min(v.co.z for o in (by['Foot_l'],by['Foot_r']) for v in o.data.vertices)
    root.scale=(row['character_height_m']/standing,)*3
    if row['family']!='cavalry':
        # Godot discards a scene root's translation on import; keep grounding
        # on the child rig so the authored world position survives import.
        rig.location.z=-min(v.co.z for name in ('Foot_l','Foot_r') for v in by[name].data.vertices)
    root['race']='orc'; root['family']=row['family']; root['tier']=row['tier']; root['height_m']=row['character_height_m']
    for obj in scene.objects: obj.name=row['stem']+'_'+obj.name
    bpy.context.view_layer.update()
    coords=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
    lo=[min(v[i] for v in coords) for i in range(3)]; hi=[max(v[i] for v in coords) for i in range(3)]
    assert all(len(by[n].data.vertices)==8 and len(by[n].data.polygons)==6 for n in BODY)
    target_point=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(lo[2]+hi[2])/2)); camera=scene.camera
    camera.data.type='ORTHO'; camera.data.ortho_scale=max(2.85,(hi[2]-lo[2])*1.20,hi[0]-lo[0]+.5)
    scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=512; scene.render.resolution_y=512
    scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    preview=out/'previews'; preview.mkdir(exist_ok=True)
    for view in views:
        offset={'front':(0,-12,1.2),'three_quarter':(6,-12,5.6),'back':(-6,12,5),'game_top':(5,-7,11)}[view]
        camera.location=target_point+Vector(offset); camera.rotation_euler=(target_point-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(preview/(view+'.png')); bpy.ops.render.render(write_still=True)
    camera.location=target_point+Vector((6,-12,5.6)); camera.rotation_euler=(target_point-camera.location).to_track_quat('-Z','Y').to_euler()
    gltf=export_glb(row,scene,parts,rig,root,out)
    clips={a['name']:max(gltf['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in gltf['animations']}
    expected={c['name']:(c['action_end']-c['action_start'])/scene.render.fps for c in motion}
    assert clips.keys()==expected.keys() and all(abs(clips[n]-expected[n])<.00001 for n in clips)
    reset_pose(rig,scene)
    for track in rig.animation_data.nla_tracks: track.mute=False; track.is_solo=False
    scene.timeline_markers.clear()
    for track in rig.animation_data.nla_tracks: scene.timeline_markers.new(track.name,frame=round(track.strips[0].frame_start))
    scene.frame_start=1; scene.frame_end=round(max(t.strips[0].frame_end for t in rig.animation_data.nla_tracks)); scene.frame_set(1)
    scene['description']='Approved orc-squire anatomy, 18 rigid cuboids, angry 3D brows. Native class clips retargeted with exact hand contacts; heavy hide, bone and forged armor progression.'
    bpy.data.libraries.write(str(out/(row['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    triangles=0
    for o in parts: o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
    report=row|dict(status='PASS',pipeline='Open Blender MCP localhost:9876',source=str(BASE.relative_to(ROOT)),
        base_blend_sha256=hashlib.sha256(BASE.read_bytes()).hexdigest(),motion_equipment_reference=str(source_path.relative_to(ROOT)),
        source_reference_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
        geometry=dict(body_parts=BODY,head_blocks=1,ear_cuboids=6,eyebrow_cuboids=2,tusk_cuboids=4,
            editable_parts=len(parts),triangles=triangles,flat_shading=True,nonmanifold_edges=0,
            bounds_min=lo,bounds_max=hi,dimensions=[hi[i]-lo[i] for i in range(3)],root_scale=list(root.scale),grounding_offset_m=rig.location.z*root.scale.z,
            mounted=row['family']=='cavalry',standing_character_height_m=standing*root.scale.x),
        texture=dict(size=[canvas.shape[1],canvas.shape[0]],filter='NEAREST',base_appearance_preserved=True,
            armor_profile=PROFILES[row['family']][row['tier']],equipment_materials=gear_materials),
        rig=dict(bones=list(rig.data.bones.keys()),rigid_weights=True,ear_bone='head',eyebrow_bone='head',retarget=retarget),
        clips=clips,inherited_animation_names_and_durations=True)
    (out/(row['stem']+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    # The reference scene is no longer needed; keep the resulting orc editable.
    bpy.data.scenes.remove(source_scene)
    return dict(status='PASS',stem=row['stem'],height_m=row['character_height_m'],parts=len(parts),clips=len(clips),scene=scene.name)
