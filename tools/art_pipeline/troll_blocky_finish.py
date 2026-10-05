"""Stage 2: retain reviewed cuboids, paint atlas, rig, validate and export via MCP."""
import bpy
import bmesh
import math
import json
import random
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); NAME='Troll_Blocky_V3'; S=2.5/3.9
SOURCE=ROOT/'art_source/troll_blocky_v3'; OUT=ROOT/'assets/generated/trolls/troll_blocky_v3'
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
parts=bpy.data.collections[NAME+'_01_CHARACTER']; studio=bpy.data.collections[NAME+'_02_STUDIO']
if bpy.data.objects.get(NAME+'_Rig'): raise RuntimeError('Finished rig exists; preserve edits.')
# Set only after inspection of the three blockout previews.
scene['blockout_reviewed']=True
scene['blockout_review']='Front/side/three-quarter checked: discrete rectangular limbs, separate thighs below pelvis, flat normals, cuboid weapon, no bevel/subdivision.'

BASE=(57,79,83); MID=(69,94,95); HI=(84,108,105); SHA=(43,62,68); DARK=(28,42,48)
tiles=[]
def blank(c): return [[c for _ in range(64)] for _ in range(64)]
def rect(t,x,y,w,h,c):
    for yy in range(max(0,y),min(64,y+h)):
        for xx in range(max(0,x),min(64,x+w)): t[yy][xx]=c
def poly(t,points,c):
    for y in range(max(0,min(v[1] for v in points)),min(64,max(v[1] for v in points)+1)):
        for x in range(max(0,min(v[0] for v in points)),min(64,max(v[0] for v in points)+1)):
            inside=False; j=len(points)-1
            for i in range(len(points)):
                ax,ay=points[i]; bx,by=points[j]
                if (ay>y+.5)!=(by>y+.5) and x+.5<(bx-ax)*(y+.5-ay)/(by-ay)+ax: inside=not inside
                j=i
            if inside: t[y][x]=c
def skin(seed):
    t=blank(BASE); r=random.Random(seed)
    for _ in range(45):
        x,y=r.randrange(61),r.randrange(61)
        rect(t,x,y,r.choice((2,3,5)),r.choice((2,3)),r.choice([(61,84,87),(53,75,80),(65,88,89)]))
    return t
def sym(t,points,c):
    poly(t,points,c); poly(t,[(64-x,y) for x,y in points],c)

# 0: chest. Rectangular stepped light planes; shallow anatomical indication.
t=skin(1)
sym(t,[(2,9),(11,6),(24,10),(29,15),(29,46),(25,51),(7,47),(2,40)],MID)
sym(t,[(4,11),(12,9),(23,13),(27,18),(27,23),(18,18),(7,18),(4,23)],HI)
sym(t,[(3,44),(11,49),(26,51),(30,46),(30,51),(25,55),(10,53),(3,49)],SHA)
rect(t,30,17,4,38,SHA); rect(t,31,23,2,21,DARK)
rect(t,0,0,64,3,MID)
poly(t,[(45,19),(47,19),(47,26),(49,26),(49,34),(51,34),(51,40),(49,40),(47,34),(47,28),(45,28)],(122,132,117))
tiles.append(t)
# 1: abdomen with three shallow rectangular plates, not inflated muscles.
t=skin(2)
for y in (5,24,44):
    sym(t,[(18,y),(28,y-1),(30,y+2),(30,y+12),(26,y+15),(18,y+12)],MID)
    sym(t,[(18,y+12),(27,y+14),(30,y+11),(30,y+15),(24,y+17),(18,y+15)],SHA)
sym(t,[(3,3),(9,3),(13,28),(14,53),(19,62),(12,62),(7,43)],SHA)
rect(t,31,2,2,58,SHA); tiles.append(t)
# 2: face aligned to front of the rectangular head.
t=skin(3)
sym(t,[(4,7),(14,5),(27,11),(29,17),(20,14),(7,14)],MID)
sym(t,[(3,23),(11,23),(27,27),(27,38),(5,38),(3,34)],DARK)
sym(t,[(7,29),(24,30),(25,35),(7,34)],(169,157,48))
sym(t,[(8,29),(17,30),(17,33),(8,32)],(224,205,79))
rect(t,17,30,3,6,DARK); rect(t,44,30,3,6,DARK)
sym(t,[(4,41),(20,42),(25,46),(22,54),(7,52),(4,49)],MID)
sym(t,[(5,52),(18,54),(22,53),(21,57),(8,56)],SHA)
rect(t,22,58,20,3,SHA); tiles.append(t)
# 3: unadorned skin for sides/top; sparse deliberate clusters.
tiles.append(skin(4))
# 4: upper arm; 5: forearm. Edges are geometric, paint stays restrained.
for i in range(2):
    t=skin(5+i)
    rect(t,0,3,5,58,SHA); rect(t,57,6,7,58,SHA)
    if i==0:
        poly(t,[(12,5),(42,5),(50,14),(50,44),(41,56),(19,56),(12,43)],MID)
        rect(t,15,9,23,4,HI); rect(t,14,14,5,22,HI)
        poly(t,[(13,46),(21,54),(40,54),(49,46),(49,52),(39,59),(20,59)],SHA)
    else:
        poly(t,[(10,9),(25,5),(46,8),(52,18),(47,43),(39,59),(22,59),(14,40)],MID)
        poly(t,[(17,12),(23,9),(26,14),(25,34),(21,49),(18,42)],HI)
        poly(t,[(40,17),(45,17),(43,35),(37,51),(34,51),(37,32)],HI)
        rect(t,20,5,25,3,SHA)
    tiles.append(t)
# 6: fist. Four squared knuckles and two rows of finger creases.
t=skin(8)
for x in (3,18,33,48):
    rect(t,x,7,12,20,MID); rect(t,x+2,8,8,4,HI)
    rect(t,x+11,29,3,28,SHA); rect(t,x+2,44,8,3,SHA)
rect(t,3,31,58,4,SHA); tiles.append(t)
# 7: legs; large simple longitudinal planes.
t=skin(9); rect(t,3,4,7,56,SHA)
poly(t,[(14,5),(42,4),(49,16),(46,52),(38,60),(19,56),(14,37)],MID)
rect(t,17,8,6,36,HI); rect(t,42,14,4,35,SHA); tiles.append(t)
# 8: rustic hide patch, stitches positioned only on cloth.
t=blank((75,52,36))
poly(t,[(0,0),(12,0),(17,31),(11,64),(0,64)],(52,38,29))
poly(t,[(17,0),(38,0),(44,19),(37,47),(23,62),(19,62)],(94,67,43))
poly(t,[(49,0),(64,0),(64,64),(46,64),(48,43),(54,24)],(58,42,31))
poly(t,[(35,34),(52,37),(48,55),(33,51)],(111,81,52))
for y in range(37,53,5): rect(t,33,y,5,2,(157,134,87))
for x,y in [(12,14),(27,8),(22,35),(43,23),(18,54)]: rect(t,x,y,5,4,(83,59,39))
tiles.append(t)
# 9: cut log bark. Long pixel bands follow the block weapon's length.
t=blank((84,57,34))
for x,w,c in [(1,6,(47,36,27)),(9,8,(111,77,41)),(20,4,(55,40,28)),(27,11,(99,68,38)),(40,6,(54,39,27)),(49,8,(122,87,47)),(59,5,(61,44,29))]:
    poly(t,[(x,0),(x+w,0),(x+w,21),(x+w-2,29),(x+w,51),(x+w,64),(x,64),(x+2,34),(x,24)],c)
rect(t,11,9,3,20,(138,103,58)); rect(t,29,40,3,17,(125,89,45)); rect(t,50,30,3,20,(142,104,55))
tiles.append(t)
# 10: ivory, 11: ear, 12: leather belt, 13: squared growth rings.
t=blank((196,185,148)); rect(t,0,0,10,64,(151,147,124)); rect(t,10,0,9,64,(176,168,137)); rect(t,47,0,17,64,(223,214,178))
rect(t,28,11,3,8,(186,177,142)); rect(t,33,39,3,11,(186,177,142)); tiles.append(t)
t=skin(11); poly(t,[(6,14),(58,7),(24,51),(13,44)],(114,92,71)); poly(t,[(17,20),(45,14),(24,38)],(139,109,77)); tiles.append(t)
t=blank((47,36,28)); rect(t,0,3,64,8,(83,60,39)); rect(t,0,54,64,7,(30,27,25))
for x in range(4,64,10): rect(t,x,13,4,3,(147,125,84))
tiles.append(t)
t=blank((148,112,65))
for n in (4,14,24):
    rect(t,n,n,64-2*n,3,(101,78,45)); rect(t,n,61-n,64-2*n,3,(101,78,45))
    rect(t,n,n,3,64-2*n,(101,78,45)); rect(t,61-n,n,3,64-2*n,(101,78,45))
rect(t,30,0,3,28,(62,48,31)); rect(t,33,25,11,3,(62,48,31)); tiles.append(t)
# 14: brow/iron, 15: broad back planes.
t=blank((37,53,59)); rect(t,0,0,64,9,(58,77,79)); rect(t,0,9,6,50,(47,66,71))
rect(t,0,54,64,10,(25,38,44)); tiles.append(t)
t=skin(13)
sym(t,[(3,6),(13,3),(28,15),(28,39),(20,47),(8,38),(3,23)],MID)
sym(t,[(6,8),(13,6),(25,15),(25,20),(13,12),(6,16)],HI)
sym(t,[(7,37),(20,44),(28,37),(28,44),(20,50),(10,45)],SHA)
rect(t,30,5,4,54,SHA); tiles.append(t)

pixels=[0.0]*(256*256*4)
for i,t in enumerate(tiles):
    for y in range(64):
        for x in range(64):
            k=(((i//4)*64+63-y)*256+(i%4)*64+x)*4
            pixels[k:k+4]=[c/255 for c in t[y][x]]+[1.0]
atlas=bpy.data.images.new(NAME+'_Atlas256',width=256,height=256,alpha=True)
atlas.colorspace_settings.name='sRGB'; atlas.pixels.foreach_set(pixels)
atlas.filepath_raw=str(OUT/'troll_blocky_v3_atlas.png'); atlas.file_format='PNG'; atlas.save(); atlas.pack()
material=bpy.data.materials.new(NAME+'_PixelArt_MAT'); material.use_nodes=True
bsdf=material.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.95
bsdf.inputs['Specular IOR Level'].default_value=.1
node=material.node_tree.nodes.new('ShaderNodeTexImage'); node.image=atlas; node.interpolation='Closest'; node.extension='EXTEND'
material.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])

# Controlled detail changes: square stepped cloth hem and three flat toenails.
def detail_box(name,center,size,bone,region):
    c=Vector(center); a,b,d=[n/2 for n in size]
    verts=[(c+Vector((sx*a,sy*b,sz*d)))*S for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata(verts,[],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); parts.objects.link(obj); obj['bone']=bone; obj['region']=region; obj['construction']='cuboid'
    return obj
for side,suffix in [(1,'l'),(-1,'r')]:
    for j in range(3): detail_box('Nail_'+suffix+str(j),(side*.49+(j-1)*.19,-.70,.14),(.155,.025,.13),'foot_'+suffix,'bone')
detail_box('HideHem',(-.15,-.407,1.00),(.32,.055,.09),'pelvis','hide')
detail_box('Buckle',(-.12,-.386,1.575),(.20,.04,.125),'pelvis','iron')
detail_box('Mouth',(0,-.94,3.315),(.70,.055,.075),'head','mouth')

# Per-part planar UVs keep pixel scale stable within each cuboid, orienting limbs
# and timber along their own length rather than using world-space projections.
tile_map={'chest':0,'abdomen':1,'face':2,'skin':3,'shoulder':4,'upper_arm':4,'forearm':5,
 'hand':6,'thigh':7,'shin':7,'foot':3,'hide':8,'wood':9,'bone':10,'ear':11,'belt':12,
 'endgrain':13,'brow':14,'iron':14,'back':15,'nose':3,'jaw':3,'mouth':14}
specs=json.loads(scene['bone_specs'])
for obj in list(parts.objects):
    me=obj.data; region=obj['region']; bone=obj['bone']; tile=tile_map[region]
    me.materials.clear(); me.materials.append(material)
    uv=me.uv_layers.new(name='PixelArtUV')
    # Inverse orientation for long limb/weapon beams.
    direction=(Vector(specs[bone][1])-Vector(specs[bone][0])).normalized() if region in ('upper_arm','forearm','thigh','shin','wood','endgrain') else Vector((0,0,1))
    if direction.z<0 and region not in ('wood','endgrain'): direction=-direction
    u=Vector((0,1,0)).cross(direction).normalized(); v=direction.cross(u).normalized()
    coords=[Vector((vert.co.dot(u),vert.co.dot(v),vert.co.dot(direction))) for vert in me.vertices]
    lo=[min(p[i] for p in coords) for i in range(3)]; hi=[max(p[i] for p in coords) for i in range(3)]
    for p in me.polygons:
        p.use_smooth=False
        norm=Vector((p.normal.dot(u),p.normal.dot(v),p.normal.dot(direction)))
        axis=max(range(3),key=lambda i:abs(norm[i]))
        face_tile=tile
        if axis==1:
            axes=(0,2)
            if norm.y>0 and region in ('chest','back'): face_tile=15
            elif norm.y>0 and region in ('face','abdomen','shoulder','hand','upper_arm','forearm','thigh','shin'): face_tile=3
        elif axis==0:
            axes=(1,2)
            if region in ('chest','abdomen','face','shoulder','hand','upper_arm','forearm','thigh','shin','back'): face_tile=3
        else:
            axes=(0,1)
            if region in ('chest','abdomen','face','shoulder','hand','upper_arm','forearm','thigh','shin','back'): face_tile=3
        for li in p.loop_indices:
            co=coords[me.loops[li].vertex_index]
            pu=(co[axes[0]]-lo[axes[0]])/max(hi[axes[0]]-lo[axes[0]],1e-6)
            pv=(co[axes[1]]-lo[axes[1]])/max(hi[axes[1]]-lo[axes[1]],1e-6)
            if axis==1 and norm.y>0: pu=1-pu
            if region=='mouth': pu,pv=.5,.07
            uv.data[li].uv=((face_tile%4*64+1+pu*61)/256,(face_tile//4*64+1+pv*61)/256)
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    obj.vertex_groups.new(name=bone).add(list(range(len(me.vertices))),1,'REPLACE')

# Rigid cuboid skinning is intentional: joints articulate without rounding blocks.
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); parts.objects.link(rig)
bpy.context.view_layer.objects.active=rig; rig.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
for n,(head,tail,parent) in specs.items():
    b=arm.edit_bones.new(n); b.head=Vector(head)*S; b.tail=Vector(tail)*S
    if parent: b.parent=arm.edit_bones[parent]
    b.use_deform=n!='root'
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True

def join_group(objs,name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs: obj.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name; obj.data.name=name+'_Mesh'
    # Every part was authored in world coordinates, so object origin is ground center.
    obj.parent=rig; mod=obj.modifiers.new('Skin_Armature','ARMATURE'); mod.object=rig
    return obj
body_objects=[o for o in parts.objects if o.type=='MESH' and o['bone']!='weapon']
weapon_objects=[o for o in parts.objects if o.type=='MESH' and o['bone']=='weapon']
body=join_group(body_objects,NAME+'_Body'); weapon=join_group(weapon_objects,NAME+'_Club')
meshes=[body,weapon]
rig['rig_type']='FK; rigid cuboid weights preserve blocky construction; root at ground center'
rig['height_m']=2.5; rig['forward']='-Y Blender, +Z glTF'

poses={1:{},12:{'upper_arm_l':(0,0,-.48),'upper_arm_r':(0,0,.35)},
 24:{'forearm_l':(-.8,0,0),'forearm_r':(-.9,0,0)},
 36:{'thigh_l':(-.3,0,0),'shin_l':(.75,0,0),'thigh_r':(-.15,0,0),'shin_r':(.55,0,0)},
 48:{'spine_01':(0,0,.12),'chest':(.08,0,.22),'head':(.10,0,-.36),'jaw':(.1,0,0)},
 60:{'upper_arm_r':(-1.0,0,.3),'forearm_r':(-.85,0,0),'upper_arm_l':(-.2,0,-.22),
     'chest':(.12,0,-.16),'head':(-.08,0,.13)},72:{}}
scene.frame_start=1; scene.frame_end=72; scene.render.fps=24
for frame,pose in poses.items():
    for pb in rig.pose.bones:
        pb.rotation_mode='XYZ'; pb.rotation_euler=pose.get(pb.name,(0,0,0))
        pb.keyframe_insert(data_path='rotation_euler',frame=frame,group=pb.name)
rig.animation_data.action.name='Blocky_Rig_Validation'
for frame,label in [(1,'NEUTRAL'),(12,'SHOULDERS'),(24,'ELBOWS'),(36,'KNEES'),(48,'TORSO_HEAD'),(60,'ATTACK_TEST'),(72,'NEUTRAL_END')]:
    scene.timeline_markers.new(label,frame=frame)
scene.frame_set(1)
report={'name':NAME,'pipeline':'Blender MCP localhost:9876','style':'cuboids, rectangular prisms, flat normals, no bevel or subdivision',
 'blockout_review':scene['blockout_review'],'triangles':0,'bones':list(specs),'bone_count':len(specs),
 'texture':{'size':[256,256],'filter':'NEAREST','materials':1},'height_m':2.5,
 'base_pose':'Neutral relaxed A pose, frame 1','skinning':'Rigid per-block skinning, one normalized influence per vertex',
 'meshes':{},'pose_checks':{},'limitations':['FK controls only','Validation clip only, no production animation set','No runtime monster replacement performed']}
for obj in meshes:
    me=obj.data; me.calc_loop_triangles(); bm=bmesh.new(); bm.from_mesh(me)
    nonmanifold=sum(not e.is_manifold for e in bm.edges); bm.free()
    invalid_weights=sum(abs(sum(g.weight for g in v.groups)-1)>1e-6 for v in me.vertices)
    assert nonmanifold==0 and invalid_weights==0 and all(v.groups for v in me.vertices)
    assert all(p.area>1e-10 and not p.use_smooth for p in me.polygons)
    report['triangles']+=len(me.loop_triangles)
    report['meshes'][obj.name]={'triangles':len(me.loop_triangles),'vertices':len(me.vertices),'nonmanifold_edges':nonmanifold,'invalid_weights':invalid_weights}
for frame in poses:
    scene.frame_set(frame); deps=bpy.context.evaluated_depsgraph_get(); checks={}
    for obj in meshes:
        ev=obj.evaluated_get(deps); me=ev.to_mesh()
        error=max(abs((me.vertices[e.vertices[0]].co-me.vertices[e.vertices[1]].co).length-
                      (obj.data.vertices[e.vertices[0]].co-obj.data.vertices[e.vertices[1]].co).length) for e in me.edges)
        assert error<1e-5 and all(math.isfinite(c) for v in me.vertices for c in v.co)
        checks[obj.name]={'max_edge_length_error_m':error,'max_displacement_m':max((v.co-obj.data.vertices[v.index].co).length for v in me.vertices)}
        ev.to_mesh_clear()
    report['pose_checks'][str(frame)]=checks
scene.frame_set(1)

# Final studio: softer light on entirely flat-shaded geometry.
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000
world=scene.world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,pos,energy,size,color in [('Key',(-3,-4,6),430,4,(1,.92,.81)),('Fill',(4,-2,4),220,4,(.78,.86,1)),('Rim',(0,3,5),500,3,(.80,.92,1))]:
    data=bpy.data.lights.new(NAME+'_'+name,'AREA'); data.energy=energy; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(data.name,data); studio.objects.link(obj); obj.location=pos; aim(obj,(0,0,1.2))
me=bpy.data.meshes.new(NAME+'_FloorMesh'); me.from_pydata([(-200,-200,-.015),(200,-200,-.015),(200,200,-.015),(-200,200,-.015)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_Floor',me); studio.objects.link(floor)
floor_mat=bpy.data.materials.new(NAME+'_FloorMat'); floor_mat.use_nodes=True
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(floor_mat)
scene.camera.data.ortho_scale=3.48
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes+[rig]: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
scene['production_state']='Rigged and exported; final visual and engine verification pending'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'troll_blocky_v3.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'troll_blocky_v3.glb'),export_format='GLB',use_selection=True,use_active_scene=True,
 export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Blocky_Rig_Validation',
 export_force_sampling=True,export_frame_range=True,export_skins=True,
 export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
bpy.ops.export_scene.fbx(filepath=str(SOURCE/'troll_blocky_v3.fbx'),use_selection=True,object_types={'ARMATURE','MESH'},
 add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,
 path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y')
(OUT/'troll_blocky_v3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'triangles':report['triangles'],'bone_count':len(specs),'texture':[256,256],'source':str(SOURCE),'exports':str(OUT),'validation':'geometry, weights and 7 FK poses passed'}
