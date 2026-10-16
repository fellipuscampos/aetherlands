"""Merge rigid clothing in memory; preserve the original export/animation settings."""
import bpy,json,struct,importlib,numpy as np
from mathutils import Matrix,Vector
from human_texture_glb import read_glb
import glb_pose_math
importlib.reload(glb_pose_math)
from glb_pose_math import PoseModel
from orc_troop_assets import WORK

def mask_for_rectangles(uv,rectangles):
    mask=np.zeros(len(uv),dtype=bool)
    for x0,y0,x1,y1 in rectangles:
        mask|=(uv[:,0]>=x0-1e-6)&(uv[:,0]<=x1+1e-6)&(uv[:,1]>=1-y1-1e-6)&(uv[:,1]<=1-y0+1e-6)
    return mask

def export(row,scene,parts,rig,root,out,source_boxes=None,rotations=None,approved_path=None):
    vertices=[];faces=[];weights={};main_uv=parts[0].data.uv_layers[0].name
    layer_names=[main_uv]+sorted({l.name for o in parts for l in o.data.uv_layers if l.name!=main_uv})
    uvs={name:[] for name in layer_names}
    inverse=rig.matrix_world.inverted()
    approved=PoseModel(approved_path or WORK/'clothing_refinement/before_assets'/row['stem']/(row['stem']+'.glb'))
    conversion=np.array([[1,0,0],[0,0,1],[0,-1,0]])
    canonical={}
    if source_boxes:
        for name,boxes in source_boxes.items():
            for index in range(4):
                if 'TEXCOORD_'+str(index) not in approved.doc['meshes'][0]['primitives'][0]['attributes']:break
                p,ids,uv=approved.geometry(index);mask=mask_for_rectangles(uv,boxes)
                if mask.any():canonical[name]=np.unique(p[mask],axis=0)@conversion;break
    rotated={}
    # A subsequent edit reads native mesh coordinates from the saved .blend,
    # while the approved GLB includes the armature's grounding translation.
    # Account for that translation before matching shared-UV strap connectors.
    matching_offset=np.zeros(3)
    if approved_path is not None and 'Head' in canonical:
        head=next(o for o in parts if o['part']=='Head')
        matching_offset=canonical['Head'].mean(axis=0)-np.array([tuple(v.co) for v in head.data.vertices]).mean(axis=0)
    for grip,data in (rotations or {}).items():
        data.setdefault('blender_pivot',data['pivot'])
        data['pivot']=canonical[grip].mean(axis=0).tolist()
        for name in data['parts']:rotated[name]=data
    for obj in parts:
        offset=len(vertices);transform=inverse@obj.matrix_world
        current=np.array([tuple(v.co) for v in obj.data.vertices]);name=obj['part']
        if name in canonical:
            match=current+matching_offset
            if name in rotated:
                data=rotated[name];rotation=np.array(data['rotation']);pivot=np.array(data['blender_pivot'])
                match=(current-pivot)@rotation+pivot
            old=canonical[name];distance=np.linalg.norm(match[:,None]-old[None],axis=2)
            assert distance.min(axis=1).max()<.015,(row['stem'],name,'source vertex matching failed',distance.min(axis=1).max())
            current=old[distance.argmin(axis=1)]
            if name in rotated:
                data=rotated[name];rotation=np.array(data['rotation']);pivot=np.array(data['pivot'])
                current=(current-pivot)@rotation.T+pivot
            # The glTF skin exporter bakes the armature object's local matrix
            # into mesh positions. Frozen GLB positions already include it.
            unbake=rig.matrix_local.inverted()
            vertices.extend(tuple(unbake@Vector(v)) for v in current)
        else:vertices.extend(tuple(transform@v.co) for v in obj.data.vertices)
        faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
        for name in layer_names:
            layer=obj.data.uv_layers.get(name)
            # Inherited ears/brows use UVMap while repainted body/clothing uses
            # Metric_Pixel_UV. Each part's rendered UVs must reach TEXCOORD_0;
            # zero-filling missing names makes the face sample a pale atlas pixel.
            if layer is None and name == main_uv:
                layer=next((l for l in obj.data.uv_layers if l.active_render),obj.data.uv_layers.active)
            uvs[name].extend(tuple(layer.data[i].uv) if layer else (0.,0.)
                            for p in obj.data.polygons for i in p.loop_indices)
        for v in obj.data.vertices:
            for group in v.groups:weights.setdefault(obj.vertex_groups[group.group].name,[]).append((offset+v.index,group.weight))
    mesh=bpy.data.meshes.new(row['stem']+'_Export_Mesh');mesh.from_pydata(vertices,[],faces);mesh.update()
    for name in layer_names:
        layer=mesh.uv_layers.new(name=name);assert len(layer.data)==len(uvs[name])
        for loop,uv in zip(layer.data,uvs[name]):loop.uv=uv
    mesh.uv_layers.active_index=0
    for layer in mesh.uv_layers:layer.active_render=layer.name==main_uv
    mesh.materials.append(parts[0].data.materials[0])
    model=bpy.data.objects.new(row['stem']+'_Model',mesh);scene.collection.objects.link(model);model.parent=rig
    for name,values in weights.items():
        group=model.vertex_groups.new(name=name)
        for index,weight in values:group.add([index],weight,'REPLACE')
    modifier=model.modifiers.new('Rigid_Skin','ARMATURE');modifier.object=rig
    scale=root.scale.copy();root.scale=(1,1,1)
    for track in rig.animation_data.nla_tracks:track.mute=False
    rig.animation_data.action=None;scene.frame_set(1);bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (model,rig,root):obj.select_set(True)
    bpy.context.view_layer.objects.active=rig;path=out/(row['stem']+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
        export_force_sampling=True,export_frame_range=False,export_skins=True,export_def_bones=False,
        export_yup=True,export_cameras=False,export_lights=False)
    root.scale=scale;bpy.data.objects.remove(model,do_unlink=True);bpy.data.meshes.remove(mesh)
    doc,binary=read_glb(path.read_bytes());roots=doc['scenes'][doc.get('scene',0)]['nodes'];assert len(roots)==1
    doc['nodes'][roots[0]]['scale']=list(scale)
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
    body=struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary
    path.write_bytes(b'glTF'+struct.pack('<II',2,len(body)+12)+body)
    return doc
