"""Correct only the derived builder's hammer grip and re-export its skin."""
import bpy, bmesh, hashlib, json, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/humans/human_builder_v1'; STEM='human_builder_v1'
BACKUP=ROOT/'art_source/human_builder_review/initial_hammer'
BACKUP.mkdir(parents=True,exist_ok=True); (BACKUP.parent/'.gdignore').touch()
for filename in (STEM+'.blend',STEM+'.glb',STEM+'_report.json'):
    if not (BACKUP/filename).exists(): shutil.copy2(OUT/filename,BACKUP/filename)
scene=bpy.data.scenes['Human_Builder_V1']; bpy.context.window.scene=scene; scene.frame_set(1)
parts=[o for o in scene.objects if o.type=='MESH' and o.get('builder_asset')]
by={o['part']:o for o in parts}; rig=next(o for o in scene.objects if o.type=='ARMATURE')
root=rig.parent; material=by['Head'].data.materials[0]
def signature(obj): return hashlib.sha256(str([tuple(v.co) for v in obj.data.vertices]).encode()).hexdigest()
unchanged={o['part']:signature(o) for o in parts if not o['part'].startswith('Hammer_')}
grip=sum((v.co for v in by['Hand_r'].data.vertices),Vector())/8
direction=Vector((-.18,-.58,.80)).normalized(); head=grip+direction*.35
def set_vertices(name,verts,region):
    obj=by[name]
    for vertex,point in zip(obj.data.vertices,verts): vertex.co=point
    bm=bmesh.new(); bm.from_mesh(obj.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-10
    bm.to_mesh(obj.data); bm.free(); obj.data.update()
    index={'wood':3,'iron':4,'iron_light':5}[region]
    for face in obj.data.polygons:
        axis=max(range(3),key=lambda j:abs(face.normal[j])); axes=[j for j in range(3) if j!=axis]
        coords=[Vector((obj.data.vertices[obj.data.loops[i].vertex_index].co[axes[0]],obj.data.vertices[obj.data.loops[i].vertex_index].co[axes[1]])) for i in face.loop_indices]
        lower=Vector((min(c.x for c in coords),min(c.y for c in coords)))
        for li,p in zip(face.loop_indices,coords):
            q=(p-lower)*64
            obj.data.uv_layers.active.data[li].uv=Vector((512+(index%4)*128+4+q.x,(index//4)*128+4+q.y))/1024
def beam(name,a,b,width,depth,region):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); side=Vector((0,1,0))
    side=(side-axis*side.dot(axis)).normalized(); other=axis.cross(side)
    set_vertices(name,[c+side*sx*width/2+other*sy*depth/2 for c in (a,b) for sy in (-1,1) for sx in (-1,1)],region)
def box(name,center,size,region):
    center=Vector(center)
    set_vertices(name,[center+Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)],region)
beam('Hammer_handle',grip-direction*.09,head,.038,.037,'wood')
beam('Hammer_head',head+Vector((-.11,0,0)),head+Vector((.11,0,0)),.076,.075,'iron')
box('Hammer_striking_face',head+Vector((-.119,0,0)),(.018,.079,.078),'iron_light')
box('Hammer_claw',head+Vector((.132,0,-.018)),(.06,.058,.039),'iron')
assert all(signature(by[name])==value for name,value in unchanged.items())
assert all(by[name]['animation_bone']=='hand_r' for name in by if name.startswith('Hammer_'))
vertices=[]; faces=[]; uvs=[]; spans=[]
for obj in parts:
    offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(i+offset for i in f.vertices) for f in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    spans.append((obj['animation_bone'],offset,len(obj.data.vertices)))
data=bpy.data.meshes.new(STEM+'_HammerCorrectedRuntime'); data.from_pydata(vertices,[],faces); data.update(); data.materials.append(material)
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
report['hammer_alignment']={'grip_center':list(grip),'head_center':list(head),'bone':'hand_r','shaft_passes_through_fist':True,'head_above_and_forward':True,'other_parts_unchanged':True}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
camera=scene.camera
for view,pos in [('three_quarter',(3,-5,2.8)),('front',(0,-5,1.5)),('back',(-3,5,2.8))]:
    camera.location=pos; camera.data.ortho_scale=2.55
    camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(3,-5,2.8); camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report['hammer_alignment']
