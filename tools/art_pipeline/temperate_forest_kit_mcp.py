"""Build a modular opaque forest kit in the running Blender MCP editor."""
import bpy
import bmesh
import hashlib
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/nature/temperate_forest_v1'
REVIEW=ROOT/'art_source/temperate_forest_review'
OUT.mkdir(parents=True,exist_ok=True)
for directory in ('models','textures','godot'): (OUT/directory).mkdir(exist_ok=True)
REVIEW.mkdir(exist_ok=True)
(REVIEW/'.gdignore').write_text('',encoding='utf-8')
assert not (OUT/'manifest.json').exists(),'Preserve the existing kit.'
PREFIX='Temperate_Forest_V1'
assert not any(s.name.startswith(PREFIX) for s in bpy.data.scenes),'Preserve live forest sources.'
existing_scenes=sorted(s.name for s in bpy.data.scenes)
(REVIEW/'source_scenes_before.json').write_text(json.dumps(existing_scenes,ensure_ascii=False,indent=2),encoding='utf-8')
CELL=.04
DENSITY=128
SIZE=512
PAD=4
REGIONS=[('oak_bark',(106,76,47)),('beech_bark',(147,139,115)),('cut_wood',(174,137,84)),('oak_leaf',(69,112,53)),('beech_leaf',(92,132,61)),('pine_leaf',(48,100,69)),('shrub_leaf',(90,118,55)),('stone',(112,125,122)),('moss',(80,109,55))]
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32)
pixels[:]=(.18,.22,.18,1)
for region,(label,color) in enumerate(REGIONS):
    rng=np.random.default_rng(83119+region)
    yy,xx=np.mgrid[0:120,0:120]
    clusters=rng.integers(-10,11,(40,40)).repeat(3,0).repeat(3,1)
    colors=np.zeros((120,120,3)); colors[:]=color
    colors+=clusters[:,:,None]
    colors+=rng.integers(-2,3,(120,120))[:,:,None]
    if label.endswith('bark'):
        grain=((xx//2*19+yy//17*7)%23)<3
        colors[grain]-=18
        colors[(xx%11==2)&(yy%29<18)]+=10
        if label=='beech_bark': colors[((xx//3+yy//7*5)%31)<2]-=20
    elif label=='cut_wood':
        distance=np.maximum(abs(xx-60),abs(yy-60))
        colors[(distance//3)%5==0]-=24
        colors[(distance//3)%5==1]+=8
    elif 'leaf' in label or label=='moss':
        patch=((xx//4*13+yy//4*23)%37)<4
        colors[patch]+=13
        colors[((xx//3*11+yy//3*17)%41)<3]-=13
    elif label=='stone':
        colors[((xx//5*17+yy//5*7)%31)<4]-=12
    tile=np.pad(np.clip(colors/255,0,1),((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    x,y=(region%4)*128,(region//4)*128
    pixels[y:y+128,x:x+128,:3]=tile
image=bpy.data.images.new(PREFIX+'_Shared_Atlas',width=SIZE,height=SIZE,alpha=False)
image.colorspace_settings.name='sRGB'
image.pixels.foreach_set(pixels.ravel())
image.filepath_raw=str(OUT/'textures/forest_pixel_atlas.png')
image.file_format='PNG'; image.save(); image.pack()
material=bpy.data.materials.new(PREFIX+'_Shared_Material')
material.use_nodes=True
material.use_backface_culling=True
bsdf=material.node_tree.nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value=.92
bsdf.inputs['Metallic'].default_value=0
bsdf.inputs['Specular IOR Level'].default_value=.2
texture=material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image=image; texture.interpolation='Closest'; texture.extension='EXTEND'
material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])

def recipe(asset):
    cells={}
    def box(x0,x1,y0,y1,z0,z1,region):
        for x in range(x0,x1):
            for y in range(y0,y1):
                for z in range(z0,z1): cells[(x,y,z)]=region
    def trunk(height,region=0):
        box(-1,1,-1,1,0,height,region)
        box(-2,2,-1,1,0,2,region); box(-1,1,-2,2,0,2,region)
    if asset=='tree_oak_a':
        trunk(17)
        box(-4,1,-1,1,9,11,0); box(-4,-2,-1,1,10,15,0)
        box(-1,4,-1,1,11,13,0)
        box(-7,1,-5,3,11,15,3); box(-1,7,-3,5,12,16,3)
        box(-6,6,-5,5,14,20,3); box(-4,3,-3,3,20,23,3)
    elif asset=='tree_oak_b':
        trunk(16)
        box(-3,-1,-1,1,10,18,0); box(-3,1,-1,1,10,12,0)
        box(1,3,-1,1,12,21,0); box(-1,3,-1,1,12,14,0)
        box(-4,4,-3,3,12,18,3)
        box(-7,-1,-4,3,14,22,3); box(-5,-2,-3,2,22,24,3)
        box(0,6,-3,4,16,24,3); box(1,4,-2,2,24,26,3)
    elif asset=='tree_beech_a':
        trunk(21,1)
        box(-3,1,-1,1,10,13,1); box(-1,3,-1,1,14,16,1)
        box(-5,4,-4,4,12,19,4); box(-5,5,-5,4,17,23,4)
        box(-3,3,-3,3,23,27,4)
    elif asset=='tree_pine_a':
        trunk(27)
        box(-6,6,-2,2,8,11,5); box(-2,2,-6,6,8,11,5)
        box(-5,5,-4,4,11,15,5)
        box(-4,4,-4,4,15,19,5); box(-3,3,-3,3,19,23,5)
        box(-2,2,-2,2,23,27,5); box(-1,1,-1,1,27,29,5)
    elif asset=='tree_oak_young':
        trunk(11)
        box(-4,4,-3,3,6,12,3); box(-3,3,-3,3,12,15,3)
        box(-1,2,-1,1,15,16,3)
    elif asset=='tree_pine_young':
        trunk(17)
        box(-4,4,-3,3,5,9,5); box(-3,3,-3,3,9,13,5)
        box(-2,2,-2,2,13,16,5); box(-1,1,-1,1,16,19,5)
    elif asset=='shrub_hazel':
        box(-4,2,-3,2,0,3,6); box(-1,4,-2,3,1,5,6)
        box(-2,2,-2,2,5,7,6)
    elif asset=='shrub_bracken':
        box(-1,1,-1,1,0,4,6)
        box(-5,5,-1,1,1,3,6); box(-2,2,-3,3,1,4,6)
        box(-5,-3,-1,1,3,4,6); box(3,5,-1,1,3,4,6)
        box(-1,1,-3,-1,4,5,6); box(-1,1,1,3,4,5,6)
    elif asset=='fallen_log':
        box(-7,7,-1,1,0,1,0); box(-8,8,-2,2,1,4,0)
        box(1,3,1,4,2,3,0); box(2,3,3,5,2,4,0)
    elif asset=='rock_root_small':
        box(-4,-1,0,2,0,1,0)
        box(-3,3,-2,2,0,2,7); box(-2,2,-2,2,2,4,7)
        box(-1,2,-2,1,4,5,8)
    else: raise ValueError(asset)
    # Six-connected occupancy prevents separate floating lobes and edge-only
    # voxel contacts; the extracted boundary has no hidden interior faces.
    visited=set(); queue=[next(iter(cells))]
    while queue:
        key=queue.pop()
        if key in visited: continue
        visited.add(key)
        for dx,dy,dz in ((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)):
            other=(key[0]+dx,key[1]+dy,key[2]+dz)
            if other in cells and other not in visited: queue.append(other)
    assert len(visited)==len(cells),(asset,'disconnected component')
    return cells

NAMES={
 'tree_oak_a':('Carvalho amplo','main_tree','oak'),
 'tree_oak_b':('Carvalho bifurcado','main_tree','oak'),
 'tree_beech_a':('Faia vertical','main_tree','beech'),
 'tree_pine_a':('Pinheiro adulto','main_tree','pine'),
 'tree_oak_young':('Carvalho jovem','small_tree','oak'),
 'tree_pine_young':('Pinheiro jovem','small_tree','pine'),
 'shrub_hazel':('Arbusto de aveleira','shrub','hazel'),
 'shrub_bracken':('Arbusto de sub-bosque','shrub','underbrush'),
 'fallen_log':('Tronco caído','fallen_log','oak'),
 'rock_root_small':('Pedra com musgo e raiz','decoration','stone_root'),
}
DIRECTIONS=[((-1,0,0),[(0,0,0),(0,0,1),(0,1,1),(0,1,0)]),((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),((0,1,0),[(0,1,0),(0,1,1),(1,1,1),(1,1,0)]),((0,0,-1),[(0,0,0),(0,1,0),(1,1,0),(1,0,0)]),((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)])]
assets=[]
for asset,(display,category,species) in NAMES.items():
    name=PREFIX+'_'+asset
    scene=bpy.data.scenes.new(name)
    bpy.context.window.scene=scene
    cells=recipe(asset)
    vertices=[]; faces=[]; regions=[]; lookup={}
    for (x,y,z),region in cells.items():
        for (dx,dy,dz),corners in DIRECTIONS:
            if (x+dx,y+dy,z+dz) in cells: continue
            indices=[]
            for cx,cy,cz in corners:
                key=(x+cx,y+cy,z+cz)
                if key not in lookup:
                    lookup[key]=len(vertices); vertices.append(tuple(c*CELL for c in key))
                indices.append(lookup[key])
            faces.append(indices)
            is_log_cap=asset=='fallen_log' and abs(dx)==1 and (x+int(dx>0)) in (-8,8)
            regions.append(2 if is_log_cap else region)
    data=bpy.data.meshes.new(name+'_Mesh')
    data.from_pydata(vertices,[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data)
    layer=bm.faces.layers.int.new('forest_region')
    bm.faces.ensure_lookup_table()
    for face,region in zip(bm.faces,regions): face.material_index=region; face[layer]=region
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.normal_update()
    bmesh.ops.dissolve_limit(bm,angle_limit=.001,use_dissolve_boundaries=False,verts=list(bm.verts),edges=list(bm.edges),delimit={'MATERIAL'})
    # Collapse collinear boundary subdivisions left by the voxel extraction.
    # Shared corner vertices remain welded; this preserves a closed surface.
    for iteration in range(3):
        redundant=[]
        for vertex in bm.verts:
            if len(vertex.link_edges)!=2: continue
            first,second=[edge.other_vert(vertex).co-vertex.co for edge in vertex.link_edges]
            if first.cross(second).length<1e-7 and first.dot(second)<0: redundant.append(vertex)
        if not redundant: break
        bmesh.ops.dissolve_verts(bm,verts=redundant,use_face_split=False,use_boundary_tear=False)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),(asset,'nonmanifold boundary')
    bm.to_mesh(data); bm.free(); data.update()
    face_regions=[poly.material_index for poly in data.polygons]
    uv=data.uv_layers.new(name='Metric_Pixel_UV_128')
    max_uv_error=0
    for poly,region in zip(data.polygons,face_regions):
        normal=poly.normal
        axes=[axis for axis in range(3) if axis!=max(range(3),key=lambda i:abs(normal[i]))]
        # Bark uses vertical grain; planar projection maintains metric density.
        if 2 in axes: axes=[next(a for a in axes if a!=2),2]
        if asset=='fallen_log' and region==0 and 0 in axes:
            axes=[next(a for a in axes if a!=0),0]
        positions=[data.vertices[i].co for i in poly.vertices]
        lo=[min(p[axis] for p in positions) for axis in axes]
        spans=[max(p[axis] for p in positions)-low for axis,low in zip(axes,lo)]
        assert max(spans)*DENSITY<=120+1e-5,(asset,'atlas patch too small',spans)
        px,py=(region%4)*128+PAD,(region//4)*128+PAD
        if region==2:
            px+=(120-spans[0]*DENSITY)/2; py+=(120-spans[1]*DENSITY)/2
        for loop,position in zip(poly.loop_indices,positions):
            uv.data[loop].uv=((px+(position[axes[0]]-lo[0])*DENSITY)/SIZE,(py+(position[axes[1]]-lo[1])*DENSITY)/SIZE)
        poly.material_index=0; poly.use_smooth=False
    data.materials.append(material)
    root=bpy.data.objects.new(name+'_ROOT',None); scene.collection.objects.link(root)
    mesh=bpy.data.objects.new('Mesh',data); scene.collection.objects.link(mesh); mesh.parent=root
    mesh['forest_asset']=asset; mesh['pixel_density']=DENSITY
    root['asset_id']=asset; root['category']=category; root['species']=species
    root['native_scale']=1.; root['modular']=True
    data.calc_loop_triangles()
    count=len(data.loop_triangles)
    assert count<=700,(asset,'triangle budget',count)
    bounds={'min':[min(v.co[i] for v in data.vertices) for i in range(3)],'max':[max(v.co[i] for v in data.vertices) for i in range(3)]}
    assert abs(bounds['min'][2])<1e-6
    report={'asset':asset,'name':name,'display_name':display,'category':category,'species':species,'triangles':count,'vertices':len(data.vertices),'polygons':len(data.polygons),'bounds_blender':bounds,'dimensions':[bounds['max'][i]-bounds['min'][i] for i in range(3)],'pivot':'ground at base of trunk / center of prop','native_scale':1,'pixel_density_px_per_unit':DENSITY,'materials':1,'game_meshes':1,'atlas':'textures/forest_pixel_atlas.png','alpha_blending':False,'voxel_cells':len(cells),'surface_cells_removed':True,'nonmanifold_edges':0,'mcp_only':True}
    scene['forest_asset']=asset; scene['forest_category']=category
    scene['asset_output_relative']=OUT.relative_to(ROOT).as_posix()
    scene['forest_report']=json.dumps(report,ensure_ascii=False)
    assets.append(report)
    # Studio is preview-only, with the same lights and neutral floor as buildings.
    studio=bpy.data.collections.new(name+'_STUDIO'); scene.collection.children.link(studio)
    target=Vector((0,0,bounds['max'][2]*.47))
    world=bpy.data.worlds.new(name+'_World'); world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.21,.27,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.55; scene.world=world
    for label,location,energy,size,color in (('Key',(-3,-4,6),450,4,(1,.93,.83)),('Fill',(4,-1,3),220,3,(.81,.89,1)),('Rim',(0,4,5),400,3,(.83,.93,1))):
        light=bpy.data.lights.new(name+'_'+label,'AREA'); light.energy=energy; light.size=size; light.color=color
        obj=bpy.data.objects.new(light.name,light); studio.objects.link(obj); obj.location=location
        obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
    floor_data=bpy.data.meshes.new(name+'_StudioFloor'); floor_data.from_pydata([(-50,-50,-.006),(50,-50,-.006),(50,50,-.006),(-50,50,-.006)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new(name+'_StudioFloor',floor_data); studio.objects.link(floor)
    floor_mat=bpy.data.materials.new(name+'_StudioFloor'); floor_mat.use_nodes=True
    floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.13,.16,.20,1)
    floor_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor_data.materials.append(floor_mat)
    camera_data=bpy.data.cameras.new(name+'_Camera'); camera=bpy.data.objects.new(camera_data.name,camera_data); studio.objects.link(camera)
    camera_data.type='ORTHO'; scene.camera=camera
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.render.resolution_x=scene.render.resolution_y=700; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
    scene['preview_target']=list(target)
manifest={'kit':'temperate_forest_v1','pipeline':'Blender 5.2 editor MCP localhost:9876','asset_count':10,'atlas_size':[512,512],'pixel_density':DENSITY,'shared_material':True,'scale':'native map units: tile circumradius 1; main trees 0.92–1.16 high','no_tile_geometry':True,'assets':assets}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.app.driver_namespace['temperate_forest_v1']={'out':str(OUT),'manifest':manifest,'material':material,'image':image}
result={'assets':[{k:r[k] for k in ('asset','triangles','dimensions')} for r in assets],'total_triangles':sum(r['triangles'] for r in assets),'scenes_preserved':len(existing_scenes),'shared_atlas':512,'mcp_only':True}
