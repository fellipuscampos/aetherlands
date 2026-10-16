"""Give the builder an upright, forward-facing hammer as its only held tool."""
import bpy,bmesh,json,math,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
CONFIG=globals().get('BUILDER_CONFIG',{})
RACE=CONFIG.get('race','human'); STEM=RACE+'_builder_v1'
OUT=ROOT/f"assets/generated/{CONFIG.get('family','humans')}/{STEM}"
scene=bpy.data.scenes[RACE.title()+'_Builder_V1']; bpy.context.window.scene=scene
rig=next(o for o in scene.objects if o.type=='ARMATURE'); root=rig.parent
parts=[o for o in scene.objects if o.type=='MESH' and o.get('builder_asset')]
by={o['part']:o for o in parts}; material=by['Head'].data.materials[0]

# Copy both original timelines before changing the builder-only actions.
reference=bpy.app.driver_namespace[RACE+'_builder_reference']
reference_rig=next(o for o in reference.objects if o.type=='ARMATURE')
original_mutes=[(t,t.mute) for t in reference_rig.animation_data.nla_tracks]
clips=[]
for track in reference_rig.animation_data.nla_tracks:
    for other in reference_rig.animation_data.nla_tracks: other.mute=other!=track
    strip=track.strips[0]; poses=[]
    for frame in range(int(strip.frame_start),int(strip.frame_end)+1):
        reference.frame_set(frame); reference.view_layers[0].update()
        poses.append({b.name:b.matrix.copy() for b in reference_rig.pose.bones})
    clips.append((track.name,int(strip.frame_start),poses))
for track,muted in original_mutes: track.mute=muted
rig.animation_data_clear(); rig.animation_data_create()
new_actions=[]
for name,start,poses in clips:
    action=bpy.data.actions.new(STEM+'_'+name+'_CarryHammer')
    rig.animation_data.action=action
    for frame,snapshot in enumerate(poses,1):
        for bone in rig.pose.bones: bone.matrix=snapshot[bone.name]
        elbow=snapshot['forearm_r'].translation
        turn=Matrix.Translation(elbow)@Matrix.Rotation(math.radians(-55),4,'X')@Matrix.Translation(-elbow)
        rig.pose.bones['forearm_r'].matrix=turn@snapshot['forearm_r']
        rig.pose.bones['hand_r'].matrix=turn@snapshot['hand_r']
        for bone in rig.pose.bones:
            bone.rotation_mode='QUATERNION'
            bone.keyframe_insert(data_path='location',frame=frame)
            bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
    new_actions.append((name,start,len(poses),action,rig.animation_data.action_slot))
rig.animation_data.action=None
for name,start,count,action,slot in new_actions:
    track=rig.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,start,action); strip.action_slot=slot
    strip.frame_end=start+count-1; strip.action_frame_start=1; strip.action_frame_end=count; strip.blend_type='REPLACE'
scene.frame_set(1); bpy.context.view_layer.update()
hand_delta=rig.pose.bones['hand_r'].matrix@rig.data.bones['hand_r'].matrix_local.inverted()
grip=sum((hand_delta@v.co for v in by['Hand_r'].data.vertices),Vector())/8
tool_scale=CONFIG.get('hammer_scale',1.0)
head=grip+Vector((0,0,.30*tool_scale))
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def box_vertices(center,size):
    center=Vector(center)
    return [center+Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
def update_mesh(obj,verts,region):
    for vertex,point in zip(obj.data.vertices,verts): vertex.co=point
    bm=bmesh.new(); bm.from_mesh(obj.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-10
    bm.to_mesh(obj.data); bm.free(); obj.data.update()
    index={'wood':3,'iron':4,'iron_light':5,'plan':6}[region]
    for face in obj.data.polygons:
        axis=max(range(3),key=lambda j:abs(face.normal[j])); axes=[j for j in range(3) if j!=axis]
        coords=[Vector((obj.data.vertices[obj.data.loops[i].vertex_index].co[axes[0]],obj.data.vertices[obj.data.loops[i].vertex_index].co[axes[1]])) for i in face.loop_indices]
        lower=Vector((min(c.x for c in coords),min(c.y for c in coords)))
        for li,p in zip(face.loop_indices,coords):
            q=(p-lower)*64
            obj.data.uv_layers.active.data[li].uv=Vector((512+(index%4)*128+4+q.x,(index//4)*128+4+q.y))/1024
def hammer_box(name,center,size,region):
    obj=by[name]; inverse=hand_delta.inverted()
    update_mesh(obj,[inverse@p for p in box_vertices(center,Vector(size)*tool_scale)],region)
hammer_box('Hammer_handle',grip+Vector((0,0,.10*tool_scale)),CONFIG.get('hammer_handle_size',(.037,.037,.40)),'wood')
head_size=CONFIG.get('hammer_head_size',(.075,.22,.073))
hammer_box('Hammer_head',head,head_size,'iron')
face_size=(head_size[0]+.005,.020,head_size[2]+.007)
hammer_box('Hammer_striking_face',head+Vector((0,-(head_size[1]/2+.01)*tool_scale,0)),face_size,'iron_light')
for name in ['Hammer_claw','Building_plan','Plan_fold_-1','Plan_fold_1','Clipboard_backing','Clipboard_plan','Clipboard_clip']:
    if name in by:
        parts.remove(by[name]); bpy.data.objects.remove(by[name],do_unlink=True)

vertices=[]; faces=[]; uvs=[]; spans=[]; triangles=0
for obj in parts:
    offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(i+offset for i in f.vertices) for f in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    spans.append((obj['animation_bone'],offset,len(obj.data.vertices))); obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
data=bpy.data.meshes.new(STEM+'_FinalRuntime'); data.from_pydata(vertices,[],faces); data.update(); data.materials.append(material)
uv=data.uv_layers.new(name='UVMap')
for loop,value in zip(uv.data,uvs): loop.uv=value
runtime=bpy.data.objects.new(STEM+'_Body',data); scene.collection.objects.link(runtime); runtime.parent=rig
groups={b.name:runtime.vertex_groups.new(name=b.name) for b in rig.data.bones}
for bone,start,count in spans: groups[bone].add(list(range(start,start+count)),1,'REPLACE')
modifier=runtime.modifiers.new('Builder_Skin','ARMATURE'); modifier.object=rig
for obj in scene.objects: obj.select_set(False)
for obj in (root,rig,runtime): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,
    export_yup=True,export_cameras=False,export_lights=False,export_extras=False,export_anim_slide_to_zero=True)
bpy.data.objects.remove(runtime,do_unlink=True)
report=json.loads((OUT/(STEM+'_report.json')).read_text(encoding='utf-8'))
report.update(triangles=triangles,editable_parts=len(parts),added='work apron, forward-facing upright hammer, nail pouch, reinforced knees')
report['hammer_alignment']={'grip_center':list(grip),'head_center':list(head),'bone':'hand_r','upright_shaft':True,'perpendicular_head':True,'carrying_pose':True,'striking_face_forward':True}
report.pop('clipboard',None)
report['held_tools']=['hammer']
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
camera=scene.camera
for view,pos in [('three_quarter',(3,-5,2.8)),('front',(0,-5,1.5)),('back',(-3,5,2.8))]:
    camera.location=pos; camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(3,-5,2.8); camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'hammer':report['hammer_alignment'],'held_tools':report['held_tools'],'triangles':triangles}
