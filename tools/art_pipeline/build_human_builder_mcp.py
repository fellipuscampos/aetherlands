"""Derive the human builder from the approved animated human settler via MCP."""
import bpy, bmesh, hashlib, json, math, numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
CONFIG=globals().get('BUILDER_CONFIG',{})
RACE=CONFIG.get('race','human'); FAMILY=CONFIG.get('family','humans')
STEM=RACE+'_builder_v1'
SOURCE=ROOT/f'assets/generated/{FAMILY}/{RACE}_settler_v1/{RACE}_settler_v1.blend'
OUT=ROOT/f'assets/generated/{FAMILY}/{STEM}'
assert not (OUT/(STEM+'.glb')).exists(), 'Preserve existing builder.'
OUT.mkdir(parents=True,exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
previous_scenes=[s.name for s in bpy.data.scenes]
source=bpy.app.driver_namespace.get(RACE+'_builder_reference')
if source is None:
    with bpy.data.libraries.load(str(SOURCE),link=False) as (available,loaded): loaded.scenes=[available.scenes[0]]
    source=loaded.scenes[0]; bpy.app.driver_namespace[RACE+'_builder_reference']=source
originals={o['part']:o for o in source.objects if o.type=='MESH' and o.get('part')}
source_rig=next(o for o in source.objects if o.type=='ARMATURE')
source_root=next(o for o in source.objects if o.type=='EMPTY')
scene=bpy.data.scenes.new(RACE.title()+'_Builder_V1'); bpy.context.window.scene=scene
scene.render.fps=source.render.fps; scene.frame_start=1; scene.frame_end=233
root=source_root.copy(); root.name=STEM; scene.collection.objects.link(root)
root['gameplay_id']='v2_unit_builder'; root['race']=RACE
rig=source_rig.copy(); rig.data=source_rig.data.copy(); rig.name=STEM+'_Rig'
scene.collection.objects.link(rig); rig.parent=root
rig.animation_data_clear(); rig.animation_data_create()
for old_track in source_rig.animation_data.nla_tracks:
    track=rig.animation_data.nla_tracks.new(); track.name=old_track.name
    for old_strip in old_track.strips:
        action=old_strip.action.copy(); action.name=STEM+'_'+track.name
        strip=track.strips.new(track.name,int(old_strip.frame_start),action)
        if old_strip.action_slot:
            slot=next(s for s in action.slots if s.identifier==old_strip.action_slot.identifier)
            strip.action_slot=slot
        strip.frame_end=old_strip.frame_end; strip.action_frame_start=old_strip.action_frame_start
        strip.action_frame_end=old_strip.action_frame_end; strip.blend_type='REPLACE'

BODY=['Head','Chest','Belly','Pelvis']+[p+'_'+s for s in ('l','r') for p in ('Shoulder','UpperArm','Forearm','Hand','Thigh','Shin','Foot')]
keep=BODY+[n for n in originals if n.startswith(('Travel_belt_','Travel_cap_','Belt_'))]
if RACE=='elf':
    keep += [n for n in originals if n.startswith(('ElfEar','Hair_','Leaf_','Tunic_tail_'))]
elif RACE=='orc':
    keep += [n for n in originals if n.startswith(('ElfEar','Tusk','Brow','Hide_coat_lobe_'))]
elif RACE=='dwarf':
    keep += [n for n in originals if n not in keep and originals[n].get('animation_bone')=='head']
else:
    keep += ['Linen_shirt_front','Linen_collar']
parts=[]; copied=[]
for name in keep:
    original=originals[name]; obj=original.copy(); obj.data=original.data.copy()
    obj.name=STEM+'_'+name; scene.collection.objects.link(obj); obj.parent=rig
    for modifier in obj.modifiers:
        if modifier.type=='ARMATURE': modifier.object=rig
    assert all((a.co-b.co).length<1e-8 for a,b in zip(original.data.vertices,obj.data.vertices))
    obj['builder_asset']=True; obj['source_part']=name; parts.append(obj); copied.append(name)

def bounds(obj):
    return Vector(tuple(min(v.co[j] for v in obj.data.vertices) for j in range(3))),Vector(tuple(max(v.co[j] for v in obj.data.vertices) for j in range(3)))
def midpoint(obj): return sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
def cube(name,center,size,region,bone):
    center=Vector(center)
    verts=[center+Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],region,bone)
def mesh(name,verts,faces,region,bone):
    data=bpy.data.meshes.new(STEM+'_'+name); data.from_pydata(verts,[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges); assert bm.calc_volume(signed=True)>1e-10
    bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(STEM+'_'+name,data); scene.collection.objects.link(obj); obj.parent=rig
    obj['part']=name; obj['surface']=region; obj['animation_bone']=bone; obj['builder_asset']=True
    group=obj.vertex_groups.new(name=bone); group.add(list(range(len(data.vertices))),1,'REPLACE')
    modifier=obj.modifiers.new('Builder_Rigid_Skin','ARMATURE'); modifier.object=rig
    parts.append(obj); return obj
def beam(name,start,end,width,depth,region,bone):
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    side=Vector((0,1,0)); side=(side-axis*side.dot(axis)).normalized(); other=axis.cross(side)
    verts=[c+side*sx*width/2+other*sy*depth/2 for c in (a,b) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],region,bone)

cl,ch=bounds(originals['Chest']); bl,bh=bounds(originals['Belly']); pl,ph=bounds(originals['Pelvis'])
front=min([cl.y,bl.y]+([bounds(originals['Linen_shirt_front'])[0].y] if 'Linen_shirt_front' in originals else []))-.018
waist=midpoint(originals['Pelvis']).z+.035
cube('Apron_bib',(0,front,(waist+.10+ch.z-.04)/2),((ch.x-cl.x)*.62,.018,ch.z-.04-waist-.10),'canvas','chest')
cube('Apron_skirt',(0,pl.y-.035,waist-.105),((ph.x-pl.x)*.77,.018,.21),'canvas','hips')
cube('Apron_pocket',(0,pl.y-.05,waist-.077),(.16,.009,.075),'canvas_dark','hips')
for side in (-1,1):
    beam('Apron_strap_'+str(side),(side*.09,front-.003,ch.z-.055),(side*.145,front+.01,ch.z+.035),.026,.012,'leather','chest')
    lo,hi=bounds(originals['Thigh_'+('l' if side==1 else 'r')])
    cube('Knee_patch_'+str(side),((lo.x+hi.x)/2,lo.y-.008,lo.z+.06),((hi.x-lo.x)*.75,.014,.085),'leather','thigh_'+('l' if side==1 else 'r'))
grip=midpoint(originals['Hand_r']); direction=Vector((-.18,-.58,.80)).normalized()
beam('Hammer_handle',grip-direction*.09,grip+direction*.35,.038,.037,'wood','hand_r')
head=grip+direction*.35
beam('Hammer_head',head+Vector((-.11,0,0)),head+Vector((.11,0,0)),.076,.075,'iron','hand_r')
cube('Hammer_striking_face',head+Vector((-.119,0,0)),(.018,.079,.078),'iron_light','hand_r')
cube('Hammer_claw',head+Vector((.132,0,-.018)),(.06,.058,.039),'iron','hand_r')
cube('Nail_pouch',(.15,pl.y-.045,waist-.06),(.09,.06,.12),'leather','hips')

# Preserve the entire existing painted body atlas without resampling it.
source_image=next(n.image for n in originals['Head'].data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
assert tuple(source_image.size)==(512,512)
pixels=np.ones((1024,1024,4),dtype=np.float32); pixels[:,:,:3]=(.23,.17,.11)
old=np.empty(len(source_image.pixels),dtype=np.float32); source_image.pixels.foreach_get(old)
pixels[:512,:512]=old.reshape(512,512,4)
PALETTE={'canvas':(174,138,87),'canvas_dark':(138,103,61),'leather':(112,74,44),'wood':(133,98,57),
         'iron':(124,134,139),'iron_light':(174,183,186),'plan':(58,93,142),'paper':(221,209,170)}
PALETTE.update(CONFIG.get('palette',{}))
for index,(label,color) in enumerate(PALETTE.items()):
    rng=np.random.default_rng(182026+index); y,x=np.mgrid[:128,:128]
    tile=np.zeros((128,128,3)); tile[:]=color
    tile+=rng.integers(-5,6,(64,64)).repeat(2,0).repeat(2,1)[:,:,None]
    if label.startswith('canvas'): tile[(x%4==0)&(y%4==0)]-=7
    if label=='wood': tile[((x//2*7+y//19*3)%23)<3]-=14
    if label=='plan':
        tile[(x%12==4)|(y%12==4)]=(182,205,224)
        tile[(y%24==7)&(x%24>7)&(x%24<19)]=(231,231,211)
    ox=512+(index%4)*128; oy=(index//4)*128
    pixels[oy:oy+128,ox:ox+128,:3]=np.clip(tile/255,0,1)
for obj in parts:
    if obj['part'] in copied:
        for loop in obj.data.uv_layers.active.data: loop.uv*=.5
    else:
        index=list(PALETTE).index(obj['surface']); uv=obj.data.uv_layers.new(name='UVMap')
        for face in obj.data.polygons:
            axis=max(range(3),key=lambda j:abs(face.normal[j])); axes=[j for j in range(3) if j!=axis]
            coords=[Vector((obj.data.vertices[obj.data.loops[i].vertex_index].co[axes[0]],obj.data.vertices[obj.data.loops[i].vertex_index].co[axes[1]])) for i in face.loop_indices]
            lower=Vector((min(c.x for c in coords),min(c.y for c in coords)))
            for li,p in zip(face.loop_indices,coords):
                q=(p-lower)*64; assert max(q)<120
                uv.data[li].uv=Vector((512+(index%4)*128+4+q.x,(index//4)*128+4+q.y))/1024
image=bpy.data.images.new(STEM+'_albedo',1024,1024,alpha=False)
image.pixels.foreach_set(pixels.ravel()); image.filepath_raw=str(OUT/(STEM+'_albedo.png'))
image.file_format='PNG'; image.save(); image.pack()
material=bpy.data.materials.new(STEM+'_Pixel_Material'); material.use_nodes=True; material.use_backface_culling=True
bsdf=material.node_tree.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value=.90; bsdf.inputs['Specular IOR Level'].default_value=.18
tex=material.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image; tex.interpolation='Closest'
material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
vertices=[]; faces=[]; uvs=[]; spans=[]; triangles=0
for obj in parts:
    obj.data.materials.clear(); obj.data.materials.append(material)
    for face in obj.data.polygons: face.use_smooth=False
    obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
    offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(i+offset for i in f.vertices) for f in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    spans.append((obj['animation_bone'],offset,len(obj.data.vertices)))
data=bpy.data.meshes.new(STEM+'_Runtime'); data.from_pydata(vertices,[],faces); data.update(); data.materials.append(material)
uv=data.uv_layers.new(name='UVMap')
for loop,value in zip(uv.data,uvs): loop.uv=value
runtime=bpy.data.objects.new(STEM+'_Body',data); scene.collection.objects.link(runtime); runtime.parent=rig
groups={b.name:runtime.vertex_groups.new(name=b.name) for b in rig.data.bones}
for bone,start,count in spans: groups[bone].add(list(range(start,start+count)),1,'REPLACE')
modifier=runtime.modifiers.new('Builder_Skin','ARMATURE'); modifier.object=rig
scene.frame_set(1); bpy.context.view_layer.update()
for obj in scene.objects: obj.select_set(False)
for obj in (root,rig,runtime): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,
    use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,
    export_skins=True,export_yup=True,export_cameras=False,export_lights=False,export_extras=False,export_anim_slide_to_zero=True)
bpy.data.objects.remove(runtime,do_unlink=True)
report=dict(stem=STEM,race=RACE,gameplay_id='v2_unit_builder',pipeline='live Blender MCP',
    source=str(SOURCE.relative_to(ROOT)),source_sha256=source_hash,source_body_preserved=True,
    source_face_pixels_preserved=True,copied_parts=copied,editable_parts=len(parts),triangles=triangles,
    bones=16,clips=['idle','walk'],texture_size=[1024,1024],removed=CONFIG.get('removed','backpack, bedroll, spade, survey scroll, travelling coat tails'),
    added='work apron, hammer, nail pouch, reinforced knees')
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')

world=bpy.data.worlds.new(STEM+'_Studio'); scene.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.29,1); world.node_tree.nodes['Background'].inputs[1].default_value=.6
for name,pos,power in [('Key',(3,-4,5),380),('Fill',(-4,-2,3),170),('Rim',(1,4,4),250)]:
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.size=3
    light=bpy.data.objects.new(name,ld); scene.collection.objects.link(light); light.location=pos
    light.rotation_euler=(Vector((0,0,.95))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new(STEM+'_Camera'); cd.type='ORTHO'
camera=bpy.data.objects.new('Builder_Preview',cd); scene.collection.objects.link(camera); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
for view,pos,scale in [('three_quarter',(3,-5,2.8),2.55),('front',(0,-5,1.5),2.55),('back',(-3,5,2.8),2.55)]:
    camera.location=pos; cd.ortho_scale=scale; camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(3,-5,2.8); cd.ortho_scale=2.55
camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
assert set(previous_scenes).issubset({s.name for s in bpy.data.scenes})
result=report
# Complete the upright grip and forward-facing hammer in the carrying pose.
exec((ROOT/'tools/art_pipeline/refine_human_builder_tools_mcp.py').read_text(encoding='utf-8'),globals())
exec((ROOT/'tools/art_pipeline/animate_human_builder_mcp.py').read_text(encoding='utf-8'),globals())
