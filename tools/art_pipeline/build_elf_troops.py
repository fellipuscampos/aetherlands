"""Blender: copy human .blend files, edit their atlases, add rigid cuboid ears.

Run in the open Blender through run_elf_troop_mcp.py. Human/dwarf assets are
read-only inputs. Each human source is appended as a separate elf scene.
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from elf_troop_assets import ROOT, OUT, WORK, ASSETS, TEAM_COLORS, HAIR_COLORS
from human_texture_glb import read_glb
from elf_troop_paint import head_face, surface, FULL_HELMETS, PROFILES, VERSION

BODY = ['Head', 'Chest', 'Belly', 'Pelvis'] + [part+'_'+side for side in ('l','r')
        for part in ('Thigh','Shin','Foot','Shoulder','UpperArm','Forearm','Hand')]
FACES = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def reset_pose(rig, scene):
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    scene.frame_set(1)
    bpy.context.view_layer.update()


def pixels(image):
    data = np.empty(len(image.pixels), dtype=np.float32)
    image.pixels.foreach_get(data)
    return np.rint(data.reshape(image.size[1],image.size[0],4)*255).astype(np.uint8)


def bounds(obj):
    coords = np.array([list(v.co) for v in obj.data.vertices])
    return coords.min(axis=0), coords.max(axis=0)


def face_rectangle(obj, poly, width, height):
    uv = np.array([list(obj.data.uv_layers.active.data[i].uv) for i in poly.loop_indices])
    lo,hi = np.rint(uv.min(axis=0)*[width,height]).astype(int), np.rint(uv.max(axis=0)*[width,height]).astype(int)
    return lo,hi,uv


def paint_head(canvas, obj, poly, uv, lo, hi, row):
    return head_face(canvas,obj,poly,uv,lo,hi,row,HAIR_COLORS[row['tier']])



def edit_atlas(image, parts, row):
    old = pixels(image)
    height,width = old.shape[:2]
    canvas = np.zeros((height*2,width,4),dtype=np.uint8)
    canvas[...,3] = 255
    canvas[:height] = old
    changes = {}
    head_audit=[]
    material_audit={}
    for obj in parts:
        count = 0
        for poly in obj.data.polygons:
            lo,hi,uv = face_rectangle(obj,poly,width,height)
            if obj['part']=='Head':
                # Integer texel boundaries remove unequal sampling at UV edges.
                old_lo,old_hi=uv.min(axis=0),uv.max(axis=0)
                uv=(lo+(uv-old_lo)/(old_hi-old_lo)*(hi-lo))/[width,height]
                for loop,point in zip(poly.loop_indices,uv):
                    obj.data.uv_layers.active.data[loop].uv=point
            x0,y0 = lo; x1,y1 = hi
            before = canvas[y0:y1,x0:x1,:3].copy()
            if obj.get('part') == 'Head':
                audit=paint_head(canvas,obj,poly,uv,lo,hi,row)
                if audit: head_audit.append(audit)
            else:
                kind=surface(canvas,obj,poly,uv,lo,hi,row,HAIR_COLORS[row['tier']])
                if kind: material_audit[obj['part']]=kind
            # Refresh the existing UV gutters after painting, avoiding old human
            # skin/hair colors leaking into a face at oblique or distant views.
            if x0>0: canvas[y0:y1,x0-1]=canvas[y0:y1,x0]
            if x1<width: canvas[y0:y1,x1]=canvas[y0:y1,x1-1]
            if y0>0: canvas[y0-1,max(0,x0-1):min(width,x1+1)]=canvas[y0,max(0,x0-1):min(width,x1+1)]
            if y1<height: canvas[y1,max(0,x0-1):min(width,x1+1)]=canvas[y1-1,max(0,x0-1):min(width,x1+1)]
            count += int(np.any(before!=canvas[y0:y1,x0:x1,:3],axis=-1).sum())
        changes[obj['part']] = count
        for loop in obj.data.uv_layers.active.data:
            loop.uv.y *= .5
    return canvas,changes,head_audit,material_audit


def save_image(name, data, out):
    image = bpy.data.images.new(name,width=data.shape[1],height=data.shape[0],alpha=True)
    image.colorspace_settings.name = 'sRGB'
    image.pixels.foreach_set((data.astype(np.float32)/255).ravel())
    image.file_format = 'PNG'
    image.filepath_raw = str(out/(name+'.png'))
    image.save()
    image.pack()
    return image


def add_ears(head, parts, rig, canvas, material, row):
    low,high = bounds(head)
    center = (low+high)/2
    size = high-low
    factor = size[2]/.27
    roots = {}
    collection = head.users_collection[0]
    for sign,side in ((1,'l'),(-1,'r')):
        outer = high[0] if sign==1 else low[0]
        start = outer-sign*.006*factor
        for step,(length,depth,tall,rise) in enumerate(((.060,.050,.080,0),(.047,.040,.057,.018),(.026,.030,.033,.035))):
            c = (start+sign*length*.5*factor,center[1]-.023*factor,low[2]+size[2]*.57+rise*factor)
            dims = np.array([length,depth,tall])*factor
            verts = [Vector(c)+Vector((sx*dims[0]/2,sy*dims[1]/2,sz*dims[2]/2)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
            name = 'ElfEar_'+side+'_'+str(step)
            mesh = bpy.data.meshes.new(row['stem']+'_'+name)
            mesh.from_pydata(verts,[],FACES); mesh.update()
            obj = bpy.data.objects.new(row['stem']+'_'+name,mesh)
            collection.objects.link(obj)
            obj['part'] = name; obj['region'] = 'elf_ear'; obj['rig_bone'] = 'head'
            obj['construction'] = 'Closed rectangular cuboid; stepped pointed ear'
            obj.parent = head.parent
            obj.matrix_basis = head.matrix_basis.copy()
            group = obj.vertex_groups.new(name='head'); group.add(list(range(8)),1.0,'REPLACE')
            modifier = obj.modifiers.new('ElfHeadRig','ARMATURE'); modifier.object = rig
            mesh.materials.append(material)
            uvs = mesh.uv_layers.new(name='UVMap')
            for poly in mesh.polygons:
                index = ((0 if sign==1 else 3)+step)*6+poly.index
                tx = 4+(index%18)*12; ty = canvas.shape[0]//2+4+(index//18)*12
                for yy in range(10):
                    for xx in range(10):
                        color = (236,216,204)
                        if poly.normal.y<-.5 and 3<=xx<=6 and 2<=yy<=6:
                            color = (209,171,164) if step<2 else (231,204,193)
                        if yy in (0,9): color = (244,228,216)
                        canvas[ty+yy,tx+xx,:3] = color
                points = [(tx+2,ty+2),(tx+8,ty+2),(tx+8,ty+8),(tx+2,ty+8)]
                for loop,point in zip(poly.loop_indices,points):
                    uvs.data[loop].uv = (point[0]/canvas.shape[1],point[1]/canvas.shape[0])
            parts.append(obj)
            if step==0: roots[side]=list(c)
            start += sign*length*factor
    return roots


def export_glb(row,scene,parts,rig,root,out):
    collection = bpy.data.collections.new('ELF_EXPORT_TEMP'); scene.collection.children.link(collection)
    copies = []
    for obj in parts:
        copy = obj.copy(); copy.data = obj.data.copy(); collection.objects.link(copy); copies.append(copy)
    with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies):
        bpy.ops.object.join()
    model = copies[0]; model.name = row['stem']+'_Model'; model.parent=rig
    root_scale = root.scale.copy(); root.scale = (1,1,1)
    for track in rig.animation_data.nla_tracks: track.mute=False
    rig.animation_data.action=None
    scene.frame_set(1); bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (model,rig,root): obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    path=out/(row['stem']+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
        export_force_sampling=True,export_frame_range=False,export_skins=True,export_def_bones=False,
        export_yup=True,export_cameras=False,export_lights=False)
    root.scale=root_scale
    bpy.data.objects.remove(model,do_unlink=True); bpy.data.collections.remove(collection)
    if abs(root_scale.x-1)>1e-6:
        import struct
        raw=path.read_bytes(); doc,binary=read_glb(raw)
        roots=doc['scenes'][doc.get('scene',0)]['nodes']
        assert len(roots)==1
        doc['nodes'][roots[0]]['scale']=list(root_scale)
        encoded=json.dumps(doc,separators=(',',':')).encode(); encoded+=b' '*(-len(encoded)%4)
        body=struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary
        path.write_bytes(b'glTF'+struct.pack('<II',2,len(body)+12)+body)
    return read_glb(path.read_bytes())[0]


def build(row,views):
    source=ROOT/'assets/generated/humans'/row['source_stem']/(row['source_stem']+'.blend')
    with bpy.data.libraries.load(str(source),link=False) as (library,loaded):
        assert len(library.scenes)==1
        source_name=library.scenes[0]
        loaded.scenes=[source_name]
    scene=loaded.scenes[0]
    scene.name='Elf_'+source_name
    bpy.context.window.scene=scene
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts:
        obj.data=obj.data.copy()
    original_geometry={o['part']:[[float(c) for c in v.co] for v in o.data.vertices] for o in parts}
    assert all(any(o['part']==name for o in parts) for name in BODY)
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None)
    reset_pose(rig,scene)
    head=next(o for o in parts if o['part']=='Head')
    removed=[]
    if head['region'] in FULL_HELMETS or row['source_stem'] in ('swordsman_v1','blade_hero_v1'):
        # Closed helmets and hair live entirely on the existing head cuboid.
        for obj in list(parts):
            if obj.get('rig_bone')=='head' and obj['part']!='Head':
                obj.data.calc_loop_triangles()
                removed.append(dict(part=obj['part'],triangles=[
                    [dict(position=[float(obj.data.vertices[i].co.x),float(obj.data.vertices[i].co.z),-float(obj.data.vertices[i].co.y)],
                          normal=[float(t.normal.x),float(t.normal.z),-float(t.normal.y)],bone='head') for i in t.vertices]
                    for t in obj.data.loop_triangles]))
                parts.remove(obj); bpy.data.objects.remove(obj,do_unlink=True)
    if row['family']!='cavalry':
        headwear=[o for o in parts if o.get('rig_bone')=='head']
        head_top=max((obj.matrix_world@v.co).z for obj in headwear for v in obj.data.vertices)
        root.scale*=row['character_height_m']/head_top
        bpy.context.view_layer.update()
    for obj in scene.objects:
        obj.name='Elf_'+obj.name
    material=parts[0].data.materials[0].copy(); material.name=row['stem']+'_Material'
    for obj in parts:
        obj.data.materials.clear(); obj.data.materials.append(material)
    tex_nodes=[n for n in material.node_tree.nodes if n.type=='TEX_IMAGE']
    original_albedo=next(n.image for n in tex_nodes if 'albedo' in n.image.name.lower())
    original_emission=next(n.image for n in tex_nodes if 'emission' in n.image.name.lower())
    emission=pixels(original_emission)
    atlas,changes,head_audit,material_audit=edit_atlas(original_albedo,parts,row)
    head=next(o for o in parts if o['part']=='Head')
    ear_roots=add_ears(head,parts,rig,atlas,material,row)
    out=OUT/row['stem']; out.mkdir(parents=True,exist_ok=True)
    albedo=save_image(row['stem']+'_albedo',atlas,out)
    expanded=np.zeros_like(atlas); expanded[...,3]=255; expanded[:emission.shape[0]]=emission
    glow=save_image(row['stem']+'_emission',expanded,out)
    for node in tex_nodes:
        node.image=albedo if 'albedo' in node.image.name.lower() else glow
        node.interpolation='Closest'
    bpy.context.view_layer.update()
    world_coords=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
    lo=[min(v[i] for v in world_coords) for i in range(3)]
    hi=[max(v[i] for v in world_coords) for i in range(3)]
    # Record actual coordinates, not the mounted model's lance height as character height.
    scene['character_height_m']=row['character_height_m']
    scene['derived_from']=str(source.relative_to(ROOT))
    scene['description']='Elven cloth, leather and practical armor; mirrored pixel eyes, closed helmets on the single head cuboid, legendary gold armor; inherited humanoid rig.'
    anatomical={name:original_geometry[name] for name in BODY}
    for obj in parts:
        if obj['part'] in original_geometry:
            assert original_geometry[obj['part']]==[list(v.co) for v in obj.data.vertices]
        bm=bmesh.new(); bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges),obj.name
        bm.free()
        assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in obj.data.vertices)
        assert not any(p.use_smooth for p in obj.data.polygons)
    # Existing studio renders show the direct derivative at the same scale as the source.
    camera=scene.camera
    target=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(lo[2]+hi[2])/2))
    camera.data.type='ORTHO'; camera.data.ortho_scale=max(2.55,(hi[2]-lo[2])*1.24)
    scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=512; scene.render.resolution_y=512; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    preview=out/'previews'; preview.mkdir(exist_ok=True)
    offsets={'three_quarter':(6,-12,5.6),'front':(0,-12,1.2),'back':(-6,12,5),'game_top':(5,-7,11),'side':(12,0,1.2)}
    for view in views:
        camera.location=target+Vector(offsets[view]); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(preview/(view+'.png')); bpy.ops.render.render(write_still=True)
    gltf=export_glb(row,scene,parts,rig,root,out)
    original_gltf,_=read_glb((source.with_suffix('.glb')).read_bytes())
    clips={a['name']:max(gltf['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in gltf['animations']}
    expected={a['name']:max(original_gltf['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in original_gltf['animations']}
    assert clips.keys()==expected.keys(),(clips.keys(),expected.keys())
    assert all(abs(clips[name]-expected[name])<1e-5 for name in clips)
    reset_pose(rig,scene)
    rig.animation_data.use_nla=True
    scene.timeline_markers.clear()
    for track in rig.animation_data.nla_tracks:
        track.mute=False
        track.is_solo=False
        for strip in track.strips:
            scene.timeline_markers.new(track.name,frame=round(strip.frame_start))
    scene.frame_start=1
    scene.frame_end=round(max(strip.frame_end for track in rig.animation_data.nla_tracks for strip in track.strips))
    scene.frame_set(1)
    bpy.data.libraries.write(str(out/(row['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    report=row|dict(status='PASS',revision=VERSION,pipeline='Open Blender MCP localhost:9876',source_blend_sha256=digest(source),geometry=dict(body_parts=BODY,
        inherited_parts_unchanged=True,editable_parts=len(parts),ear_cuboids=6,ear_roots=ear_roots,
        head_blocks=1,closed_helmet=head['region'] in FULL_HELMETS,removed_head_decorations=removed,root_scale=list(root.scale),
        flat_shading=True,nonmanifold_edges=0,bounds_min=lo,bounds_max=hi,dimensions=[hi[i]-lo[i] for i in range(3)],
        anatomy_sha256=hashlib.sha256(json.dumps(anatomical,sort_keys=True).encode()).hexdigest()),
        texture=dict(size=[atlas.shape[1],atlas.shape[0]],filter='NEAREST',changed_pixels_by_part=changes,
        source_uv_pixel_density_preserved_except_aligned_head=True,head_audit=head_audit,painted_materials=material_audit,
        armor_profile=PROFILES[row['family']][row['tier']],heraldic_emblems_removed=True,
        skin='pale ivory',hair=list(HAIR_COLORS[row['tier']]),team=list(TEAM_COLORS[row['family']])),
        rig=dict(bones=list(rig.data.bones.keys()),ear_bone='head',rigid_weights=True),clips=clips,
        inherited_animation_names_and_durations=True,source_geometry=original_geometry)
    (out/(row['stem']+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('ELF_COMPLETE',row['stem'],len(parts),len(clips),flush=True)


if __name__=='__main__':
    raise RuntimeError('Use python tools/art_pipeline/run_elf_troop_mcp.py to build in the open Blender.')
