"""Preserve the approved relic and its pixel atlas; simplify and separate the requested pieces."""
import bpy,bmesh,math,json,hashlib,shutil
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OLD='archdemon_blocky_v2'; STEM='archdemon_blocky_v3'; NAME='Infernal_Archdemon_Blocky_V3'
previous=bpy.app.driver_namespace[OLD]
assert NAME not in bpy.data.scenes, 'Preserve an existing revision.'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM; REVIEW=ROOT/'art_source/archdemon_blocky_v3_review'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True); (REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys()); old_hashes=dict(previous['old_hashes'])
for path in Path(previous['out']).glob('*'):
    if path.suffix in ('.glb','.blend','.png'):
        old_hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
old_parts_hash=hashlib.sha256(b''.join(np.array([tuple(v.co) for v in o.data.vertices],dtype=np.float32).tobytes() for o in previous['parts'])).hexdigest()
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
col=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(col)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=bpy.data.objects.new(NAME+'_ROOT',None); col.objects.link(root); root.empty_display_size=.2
rig=previous['rig'].copy(); rig.data=previous['rig'].data.copy(); rig.name=NAME+'_Rig'; col.objects.link(rig); rig.parent=root
images=[]
for original,suffix in zip(previous['images'],['albedo','emission']):
    path=OUT/(STEM+'_'+suffix+'.png'); shutil.copy2(Path(original.filepath_raw),path)
    im=bpy.data.images.load(str(path),check_existing=False); im.name=NAME+'_'+suffix; im.pack(); images.append(im)
mat=previous['material'].copy(); mat.name=NAME+'_Weathered_Iron_Red_Core'
for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE':
        for before,after in zip(previous['images'],images):
            if node.image==before: node.image=after; break

parts=[]; copied={}
removed=[]
for original in previous['parts']:
    short=original.name.removeprefix(previous['name']+'_')
    omit=short.startswith('Core_') or short.startswith('stole_') or '_Pauldron_Seal' in short or any(x in short for x in ['_Knuckle_','_Finger_','_Thumb','_Elbow_Link'])
    if omit: removed.append(short); continue
    o=original.copy(); o.data=original.data.copy(); o.name=NAME+'_'+short; col.objects.link(o); o.parent=rig
    o.data.materials.clear(); o.data.materials.append(mat)
    for modifier in o.modifiers:
        if modifier.type=='ARMATURE': modifier.object=rig
    parts.append(o); copied[original]=o
    bone=o['rig_bone']
    delta=Vector((0,0,0))
    if bone.startswith('shoulder_'): delta.x=.30*(-1 if bone.endswith('_L') else 1)
    if bone.startswith(('forearm_','fist_')):
        delta=Vector((.30*(-1 if bone.endswith('_L') else 1),0,-.20))
        o['rig_bone']='fist_'+bone[-1]
        for group in list(o.vertex_groups): o.vertex_groups.remove(group)
        o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    if bone.startswith('mantle_'): delta.y=.20
    for vertex in o.data.vertices: vertex.co+=delta
    o.data.update()

# Keep every pixel used by the approved armor. Only fresh islands are allocated for the new cloth and core.
size=previous['atlas']; pad=2
pixels=np.array(images[0].pixels[:],dtype=np.float32).reshape(size,size,4)
energy=np.array(images[1].pixels[:],dtype=np.float32).reshape(size,size,4)
islands=[]; occupied=np.zeros((size,size),dtype=bool)
for before in previous['islands']:
    if before['obj'] not in copied: continue
    it=dict(before); it['obj']=copied[before['obj']]; islands.append(it)
    occupied[it['y']-pad:it['y']+it['h']+pad,it['x']-pad:it['x']+it['w']+pad]=True
unchanged_pixels=pixels[occupied].copy(); unchanged_energy=energy[occupied].copy()

def mesh_part(label,vertices,faces,bone,kind):
    me=bpy.data.meshes.new(NAME+'_'+label); me.from_pydata(vertices,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    o=bpy.data.objects.new(me.name,me); col.objects.link(o); o.parent=rig
    o['rig_bone']=bone; o['kind']=kind; o['local_rotation']=[0.,0.,0.]
    o['primitive']='Closed planar prism; flat shading; one rigid pivot'
    o.data.materials.append(mat); o.vertex_groups.new(name=bone).add(list(range(len(me.vertices))),1,'REPLACE')
    o.modifiers.new('Prepared_Rigid_Pivots','ARMATURE').object=rig; parts.append(o); return o

core_center=Vector((0,-.445,rig.data.bones['core'].head_local.z)); half=Vector((.165,.050,.165))
vertices=[core_center+Vector((x*half.x,y*half.y,z*half.z)) for x,y,z in
    [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
mesh_part('Core_Single_Red_Square',vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'core','plain_red')

# Four identical strips, mirrored across the center. Constant width and the same full length/curvature.
# The side pair has the same profile, placed slightly farther back at the skirt edge.
scale=(previous['rig'].data.bones['core'].head_local.z-.20)/(2.29-.13)
def normalized(raw): return Vector((raw[0]*scale,raw[1]*scale,(raw[2]-.13)*scale+.20))
profile=[(.205,-.018,1.58),(.20,-.025,1.18),(.13,-.18,.81),(.19,-.25,.43),(.30,-.16,.13)]
centers={}; parents={}
for band,x_offset,y_offset in [('front',0,0),('side',.275,.248)]:
    for sign in (-1,1):
        label='stole_'+band+('_L' if sign<0 else '_R')
        rows=[(sign*(x+x_offset),y+y_offset,z) for x,y,z in profile]
        for i in range(4):
            bone=label+'_'+str(i); centers[bone]=normalized(rows[i]); parents[bone]='body' if i==0 else label+'_'+str(i-1)
            vs=[]
            for x,y,z in (rows[i],rows[i+1]):
                width=.30; depth=.045
                vs.extend(normalized((x+dx*width/2,y+dy*depth/2,z)) for dx,dy in [(-1,-1),(1,-1),(1,1),(-1,1)])
            mesh_part(label+'_Fold_'+str(i),vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,'cloth')

bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for bone in list(rig.data.edit_bones):
    if bone.name.startswith('stole_'): rig.data.edit_bones.remove(bone)
for side,sign in [('L',-1),('R',1)]:
    shoulder=rig.data.edit_bones['shoulder_'+side]; delta=Vector((sign*.30,0,0)); shoulder.head+=delta; shoulder.tail+=delta
    fist=rig.data.edit_bones['fist_'+side]; fist.parent=rig.data.edit_bones['body']
    points=[v.co for o in parts if o['rig_bone']==fist.name for v in o.data.vertices]
    low=Vector(tuple(min(v[i] for v in points) for i in range(3))); high=Vector(tuple(max(v[i] for v in points) for i in range(3)))
    fist.head=(low+high)/2; fist.tail=fist.head+Vector((0,0,.15))
    rig.data.edit_bones.remove(rig.data.edit_bones['forearm_'+side])
for bone in rig.data.edit_bones:
    if bone.name.startswith('mantle_'): delta=Vector((0,.20,0)); bone.head+=delta; bone.tail+=delta
rig.data.edit_bones['core'].head=core_center; rig.data.edit_bones['core'].tail=core_center+Vector((0,0,.15))
for name,center in centers.items():
    bone=rig.data.edit_bones.new(name); bone.head=center; bone.tail=center+Vector((0,0,.15))
for name in centers: rig.data.edit_bones[name].parent=rig.data.edit_bones[parents[name]]
bpy.ops.object.mode_set(mode='OBJECT')

# All changed faces receive metric UVs, placed entirely outside the retained armor islands.
new_objects=[o for o in parts if o not in copied.values()]; new_islands=[]
for o in new_objects:
    me=o.data; me.uv_layers.new(name='Metric_Pixel_UV')
    for polygon in me.polygons:
        n=polygon.normal.normalized(); up=Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.001: up=Vector((0,1,0)); up-=n*up.dot(n)
        up.normalize(); right=up.cross(n).normalized()
        coords=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in polygon.vertices]
        lo=Vector((min(v.x for v in coords),min(v.y for v in coords))); coords=[v-lo for v in coords]
        new_islands.append(dict(obj=o,polygon=polygon.index,normal=n,coords=coords,
            w=max(1,math.ceil(max(v.x for v in coords)*64)),h=max(1,math.ceil(max(v.y for v in coords)*64))))
kept_mask=occupied.copy()
for it in sorted(new_islands,key=lambda item:(-item['h'],-item['w'])):
    w,h=it['w'],it['h']; bw,bh=w+2*pad,h+2*pad; found=False
    for y in range(0,size-bh,2):
        for x in range(0,size-bw,2):
            if not occupied[y:y+bh,x:x+bw].any():
                it['x']=x+pad; it['y']=y+pad; occupied[y:y+bh,x:x+bw]=True; found=True; break
        if found: break
    assert found,'Atlas allocation failed'
    tile=np.ones((h,w,4),dtype=np.float32); emission=np.zeros((h,w,3),dtype=np.float32)
    if it['obj']['kind']=='plain_red':
        tile[:,:,:3]=np.array((219,24,31))/255; emission[:,:,:3]=tile[:,:,:3]
    else:
        # Every strip uses the same weave/motif; no left/right change in width or pattern.
        tile[:,:,:3]=np.array((109,21,35))/255
        if w>6 and h>5:
            tile[:,:,:3]*=.84
            tile[:,1:3,:3]=np.array((164,38,44))/255; tile[:,w-3:w-1,:3]=np.array((69,20,30))/255
            tile[2:h-2,3:w-3,:3]=np.array((143,29,35))/255
            for yy in range(3,h-2,12):
                tile[yy:yy+2,3:w-3,:3]=np.array((85,22,31))/255
                tile[yy+4:min(yy+8,h-2),5:max(6,w-5),:3]=np.array((178,44,43))/255
    pixels[it['y']-pad:it['y']+h+pad,it['x']-pad:it['x']+w+pad]=np.pad(tile,((pad,pad),(pad,pad),(0,0)),mode='edge')
    energy[it['y']-pad:it['y']+h+pad,it['x']-pad:it['x']+w+pad,:3]=np.pad(emission,((pad,pad),(pad,pad),(0,0)),mode='edge')
    uv=it['obj'].data.uv_layers.active.data
    for li,coordinate in zip(it['obj'].data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+coordinate.x*64)/size,(it['y']+coordinate.y*64)/size)
assert np.array_equal(pixels[kept_mask],unchanged_pixels) and np.array_equal(energy[kept_mask],unchanged_energy)
for im,data in zip(images,[pixels,energy]):
    if im.packed_file: im.unpack(method='REMOVE')
    im.pixels.foreach_set(data.reshape(-1)); im.update(); im.save(); im.pack()
islands.extend(new_islands)

# Presentation preserves the approved lighting and framing.
camera=None
for original in previous['studio'].objects:
    o=original.copy()
    if original.data: o.data=original.data.copy()
    o.name=original.name.replace(previous['name'],NAME); studio.objects.link(o)
    if original==previous['camera']: camera=o
scene.camera=camera; scene.world=previous['scene'].world.copy()
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Approved hollow infernal armor: four matching stoles, clearly detached pauldrons and square floating hands; one red square core.'
scene['stage']='Static model only; shared across civilizations.'
st=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,images=images,material=mat,atlas=size,
    islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),old_scenes=list(old_scenes),old_hashes=old_hashes)
bpy.app.driver_namespace[STEM]=st

def bounds(items):
    vs=[v.co for o in items for v in o.data.vertices]
    return Vector(tuple(min(v[i] for v in vs) for i in range(3))),Vector(tuple(max(v[i] for v in vs) for i in range(3)))
body_low,body_high=bounds([o for o in parts if o['rig_bone'] in ['body','chest','crown','core']])
gaps={}
for side,sign in [('L',-1),('R',1)]:
    shoulder_low,shoulder_high=bounds([o for o in parts if o['rig_bone']=='shoulder_'+side])
    hand_low,hand_high=bounds([o for o in parts if o['rig_bone']=='fist_'+side])
    gap=shoulder_low.x-body_high.x if sign>0 else body_low.x-shoulder_high.x
    assert gap>.10
    assert shoulder_low.z-hand_high.z>.08
    gaps[side]={'shoulder_to_body_x_m':gap,'hand_below_shoulder_z_m':shoulder_low.z-hand_high.z,
        'hand_to_body_x_m':hand_low.x-body_high.x if sign>0 else body_low.x-hand_high.x}
low,high=bounds(parts); assert abs((high-low).z-3)<1e-5 and abs(low.z-.20)<1e-5
assert len([o for o in parts if o['rig_bone']=='core'])==1
assert not any(any(s in o.name for s in ['_Seal','_Finger_','_Knuckle_','_Thumb','_Elbow_Link']) for o in parts)
assert hashlib.sha256(b''.join(np.array([tuple(v.co) for v in o.data.vertices],dtype=np.float32).tobytes() for o in previous['parts'])).hexdigest()==old_parts_hash
st['design_checks']={'four_matching_stoles':True,'cloth_width_m':.30*scale,'single_red_core':True,
    'square_hands_without_fingers':True,'shoulder_crystals_removed':True,'original_armor_pixels_preserved':True,'gaps':gaps}
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),'bones':len(rig.data.bones),
    'height_m':(high-low).z,'design_checks':st['design_checks']}
