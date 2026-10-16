"""Build a square, pixel-painted iron outcrop in the live Blender MCP."""
import bpy
import bmesh
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
OUT = ROOT / 'assets/generated/resources/iron/iron_outcrop_v1'
STEM = 'iron_outcrop_v1'
assert not (OUT / (STEM + '.glb')).exists(), 'Preserve existing asset.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scenes = [s.name for s in bpy.data.scenes]
scene = bpy.data.scenes.new('Iron_Resource_V1')
bpy.context.window.scene = scene
root = bpy.data.objects.new(STEM, None); scene.collection.objects.link(root)
root['resource_id'] = 'iron'; root['tile_radius'] = 1.0

# Charcoal host rock, silver-gray iron grains and oxidized seams.
palette = [(43,47,51),(64,69,73),(88,95,100),
           (133,71,43),(179,98,50),(212,132,71),
           (118,132,143),(163,177,184),(201,213,217)]
size, cell = 256, 64
pixels = np.ones((size,size,4), dtype=np.float32)
pixels[:,:,:3] = (.15,.17,.18)
for region, color in enumerate(palette):
    rng = np.random.default_rng(131026+region)
    yy,xx = np.mgrid[:cell,:cell]
    tile = np.zeros((cell,cell,3)); tile[:] = color
    tile += rng.integers(-7,8,(32,32)).repeat(2,0).repeat(2,1)[:,:,None]
    tile[((xx//3*17+yy//4*13)%29)<4] -= 10
    tile[((xx//4*7+yy//3*11)%41)<3] += 9
    if region < 3:
        # Broken, stepped oxide veins rather than a continuous painted stripe.
        for x,y in [(6,7),(29,5),(14,30),(40,37)]:
            for step in range(4):
                sx=x+step*3; sy=y+step*2
                tile[sy:sy+3,sx:sx+5] = palette[3+(step+region)%3]
        speck=((xx//2*19+yy//2*7)%47)<2
        tile[speck] = palette[6+region]
    elif region >= 6:
        tile[((xx//2*13+yy//2*17)%31)<3] = palette[3+(region%3)]
        tile[((xx//3*5+yy//3*11)%43)<3] += 12
    pixels[(region//4)*cell:(region//4+1)*cell,
           (region%4)*cell:(region%4+1)*cell,:3] = np.clip(tile/255,0,1)
image = bpy.data.images.new(STEM+'_albedo', size,size,alpha=False)
image.pixels.foreach_set(pixels.ravel()); image.filepath_raw=str(OUT/(STEM+'_albedo.png'))
image.file_format='PNG'; image.save(); image.pack()
material=bpy.data.materials.new(STEM+'_Pixel_Material')
material.use_nodes=True; material.use_backface_culling=True
bsdf=material.node_tree.nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value=.84
bsdf.inputs['Specular IOR Level'].default_value=.24
texture=material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image=image; texture.interpolation='Closest'
material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])

vertices,faces,regions,parts=[],[],[],[]
def block(name, x0,x1,y0,y1,z0,z1, paint):
    verts=[(x,y,z) for z in (z0,z1) for x,y in [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]]
    polys=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    paints=[paint,max(paint,min(paint+2,8)),min(paint+1,8),paint,min(paint+1,8),paint]
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],polys); data.update()
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume(signed=True)>1e-10,name
    bm.to_mesh(data); bm.free()
    offset=len(vertices)
    vertices.extend(tuple(v.co) for v in data.vertices)
    faces.extend(tuple(offset+i for i in p.vertices) for p in data.polygons)
    regions.extend(paints); parts.append(dict(name=name,paint=paint))
    bpy.data.meshes.remove(data)

# Uneven cubic bedrock, with a large rear face and lower foreground steps.
block('Main_bedrock',-.24,.04,-.04,.22,0,.52,0)
block('Right_bedrock',.04,.30,-.06,.20,0,.34,0)
block('Front_bedrock',-.10,.16,-.30,-.06,0,.25,0)
block('Left_bedrock',-.34,-.20,-.19,.08,0,.20,0)
block('Rear_bedrock',-.07,.15,.20,.34,0,.18,0)
block('Loose_rock',.24,.37,-.25,-.14,0,.10,0)

# Small exposed iron grains break the flat surfaces; oxidized seams sit
# partly inside the host rock, without coplanar faces or floating pieces.
block('Main_iron_cap',-.19,-.10,.065,.155,.51,.55,6)
block('Main_iron_chip',-.105,-.047,.11,.185,.513,.536,6)
block('Main_front_grain',-.18,-.09,-.061,-.03,.25,.35,6)
block('Main_front_oxide',-.095,-.035,-.056,-.032,.17,.29,3)
block('Main_side_iron',-.261,-.232,.08,.17,.17,.29,6)
block('Right_iron_cap',.13,.235,.04,.12,.328,.366,6)
block('Right_oxide_cap',.21,.265,-.01,.07,.333,.349,3)
block('Right_front_iron',.12,.21,-.078,-.05,.145,.235,6)
block('Front_iron_cap',-.065,.01,-.22,-.12,.24,.28,6)
block('Front_oxide_grain',.025,.08,-.275,-.205,.24,.265,3)
block('Left_iron_grain',-.31,-.26,-.135,-.08,.188,.22,6)
block('Loose_iron_grain',.275,.33,-.22,-.17,.09,.125,6)

data=bpy.data.meshes.new(STEM+'_Mesh'); data.from_pydata(vertices,[],faces); data.update()
obj=bpy.data.objects.new('Iron_Outcrop',data); scene.collection.objects.link(obj)
obj.parent=root; data.materials.append(material)
uv=data.uv_layers.new(name='Pixel_Atlas')
for face,region in zip(data.polygons,regions):
    face.use_smooth=False
    axis=max(range(3),key=lambda j:abs(face.normal[j])); axes=[j for j in range(3) if j!=axis]
    coords=[Vector((data.vertices[data.loops[i].vertex_index].co[axes[0]],
                    data.vertices[data.loops[i].vertex_index].co[axes[1]])) for i in face.loop_indices]
    lower=Vector((min(c.x for c in coords),min(c.y for c in coords)))
    for index,coord in zip(face.loop_indices,coords):
        local=(coord-lower)*64; assert max(local)<56
        uv.data[index].uv=Vector(((region%4)*cell+4+local.x,(region//4)*cell+4+local.y))/size
data.calc_loop_triangles()
bm=bmesh.new(); bm.from_mesh(data)
assert all(e.is_manifold for e in bm.edges)
assert all(p.area>1e-10 for p in data.polygons)
bm.free()
radius=max(math.hypot(v.co.x,v.co.y) for v in data.vertices)
assert radius<.46
height=max(v.co.z for v in data.vertices)
assert abs(height-.55)<1e-6
report=dict(asset=STEM,resource='iron',method='live Blender MCP',
    vertices=len(data.vertices),triangles=len(data.loop_triangles),rock_blocks=6,
    exposed_ore_blocks=12,footprint_radius=radius,height=.55,
    materials=1,texture_size=[size,size],texture_filter='nearest',
    host_rock='cuboid blocks',closed_components=True,previous_scenes=previous_scenes)
(OUT/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for item in scene.objects: item.select_set(False)
root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
    use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
    export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')

world=bpy.data.worlds.new(STEM+'_Studio'); scene.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.29,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6
for name,position,power,scale in [('Key',(2,-3,4),240,3),('Fill',(-3,-1,2),110,3),('Rim',(1,3,3),170,2)]:
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=scale
    light=bpy.data.objects.new(name,ld); scene.collection.objects.link(light); light.location=position
    light.rotation_euler=(Vector((0,0,.25))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new(STEM+'_Camera'); cd.type='ORTHO'
camera=bpy.data.objects.new('Iron_Preview_Camera',cd); scene.collection.objects.link(camera); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
for view,position,scale,aim in [('three_quarter',(1.8,-2.6,1.85),1.25,(0,0,.25)),
                              ('game_top',(1.8,-2.9,4.9),2.0,(0,0,.12)),
                              ('top',(0,0,5),1.2,(0,0,0))]:
    camera.location=position; cd.ortho_scale=scale
    camera.rotation_euler=(Vector(aim)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(1.8,-2.6,1.85); cd.ortho_scale=1.25
camera.rotation_euler=(Vector((0,0,.25))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert set(previous_scenes).issubset({s.name for s in bpy.data.scenes})
result=report
