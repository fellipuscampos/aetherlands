"""Build the blocky floating arcane resource through the live Blender MCP."""
import bpy
import bmesh
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
OUT = ROOT / 'assets/generated/resources/arcane_node/arcane_node_v1'
STEM = 'arcane_node_v1'
assert not (OUT / (STEM + '.glb')).exists(), 'Preserve existing asset.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scenes = [s.name for s in bpy.data.scenes]
scene = bpy.data.scenes.new('Arcane_Node_Resource_V1')
bpy.context.window.scene = scene
root = bpy.data.objects.new(STEM, None); scene.collection.objects.link(root)
root['resource_id'] = 'mana_node'; root['tile_radius'] = 1.0

# Cyan energy and blue slate, matching the existing resource's identity.
palette = [(24, 92, 119), (32, 137, 161), (49, 176, 188),
           (96, 210, 216), (159, 234, 235), (219, 252, 248),
           (37, 47, 61), (52, 66, 81), (74, 89, 106)]
size, cell = 256, 64
pixels = np.ones((size, size, 4), dtype=np.float32)
pixels[:, :, :3] = (.12, .18, .23)
for region, color in enumerate(palette):
    rng = np.random.default_rng(122026 + region)
    yy, xx = np.mgrid[:cell, :cell]
    tile = np.zeros((cell, cell, 3)); tile[:] = color
    tile += rng.integers(-5, 6, (32, 32)).repeat(2, 0).repeat(2, 1)[:, :, None]
    if region < 6:
        tile[((xx//3*11 + yy//11*7) % 37) < 2] += 10
        tile[(yy % 19 == 4) & (xx % 31 < 15)] -= 8
    else:
        tile[((xx//4*17 + yy//3*13) % 29) < 4] -= 13
        tile[((xx//3*7 + yy//5*11) % 41) < 3] += 9
        if region == 8:
            # Square, pixel-width energy veins painted into the top faces.
            for x, y in [(7,8),(21,15),(37,7),(13,37),(40,40)]:
                tile[y:y+2, x:x+11] = (75, 188, 199)
                tile[y:y+8, x+9:x+11] = (75, 188, 199)
                tile[y+6:y+8, x+9:x+16] = (102, 217, 222)
    pixels[(region//4)*cell:(region//4+1)*cell,
           (region%4)*cell:(region%4+1)*cell, :3] = np.clip(tile/255, 0, 1)
image = bpy.data.images.new(STEM+'_albedo', size, size, alpha=False)
image.pixels.foreach_set(pixels.ravel())
image.filepath_raw = str(OUT/(STEM+'_albedo.png'))
image.file_format = 'PNG'; image.save(); image.pack()
material = bpy.data.materials.new(STEM+'_Pixel_Material')
material.use_nodes = True; material.use_backface_culling = True
bsdf = material.node_tree.nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value = .68
bsdf.inputs['Specular IOR Level'].default_value = .22
texture = material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = image; texture.interpolation = 'Closest'
material.node_tree.links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])

vertices, faces, regions, parts = [], [], [], []
def add_part(name, verts, polys, paints):
    data = bpy.data.meshes.new(name); data.from_pydata(verts, [], polys); data.update()
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    assert bm.calc_volume(signed=True) > 1e-10, name
    bm.to_mesh(data); bm.free()
    offset = len(vertices)
    vertices.extend(tuple(v.co) for v in data.vertices)
    faces.extend(tuple(offset+i for i in p.vertices) for p in data.polygons)
    regions.extend(paints); parts.append(dict(name=name, faces=len(polys)))
    bpy.data.meshes.remove(data)

def block(name, x0, x1, y0, y1, z0, z1):
    verts = [(x,y,z) for z in (z0,z1) for x,y in [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]]
    polys = [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    add_part(name, verts, polys, [6,8,7,6,7,8])

# Broken cubic bedrock rather than a constructed altar. The core floats
# above the open center; its lower point is visibly separated from stone.
block('West_bedrock', -.32,-.16,-.24,.24,0,.14)
block('East_bedrock', .16,.32,-.24,.24,0,.12)
block('North_bedrock', -.16,.16,.16,.30,0,.10)
block('South_bedrock', -.16,.16,-.30,-.16,0,.085)
block('Broken_corner', -.31,-.21,-.30,-.19,0,.07)

def floating_shard(name, x, y, z0, z1, width, lean_x=0, lean_y=0):
    height = z1-z0
    verts = [(x-lean_x*.2,y-lean_y*.2,z0)]
    for height_fraction in (.32,.72):
        z = z0 + height*height_fraction
        for dx,dy in [(-width,-width),(width,-width),(width,width),(-width,width)]:
            verts.append((x+dx+lean_x*height_fraction,y+dy+lean_y*height_fraction,z))
    verts.append((x+lean_x,y+lean_y,z1))
    polys = []; paints = []
    for i in range(4):
        j = (i+1)%4
        polys.append((0,1+j,1+i)); paints.append([1,0,2,3][i])
        polys.append((1+i,1+j,5+j,5+i)); paints.append([2,1,3,4][i])
        polys.append((5+i,5+j,9)); paints.append([4,3,5,5][i])
    add_part(name, verts, polys, paints)

floating_shard('Floating_core', 0, 0, .25, .84, .135)
floating_shard('Orbit_left', -.27, -.055, .26, .51, .060, -.035, .012)
floating_shard('Orbit_right', .245, .085, .32, .60, .060, .028, .012)
floating_shard('Orbit_front', .075, -.265, .19, .36, .048, .015, -.025)

data = bpy.data.meshes.new(STEM+'_Mesh'); data.from_pydata(vertices, [], faces); data.update()
obj = bpy.data.objects.new('Arcane_Energy_Node', data)
scene.collection.objects.link(obj); obj.parent = root; data.materials.append(material)
uv = data.uv_layers.new(name='Pixel_Atlas')
for face, region in zip(data.polygons, regions):
    face.use_smooth = False
    axis = max(range(3), key=lambda j: abs(face.normal[j]))
    axes = [j for j in range(3) if j != axis]
    coords = [Vector((data.vertices[data.loops[i].vertex_index].co[axes[0]],
                      data.vertices[data.loops[i].vertex_index].co[axes[1]])) for i in face.loop_indices]
    lower = Vector((min(c.x for c in coords), min(c.y for c in coords)))
    for index, coord in zip(face.loop_indices, coords):
        local = (coord-lower)*64
        assert max(local)<56
        uv.data[index].uv = Vector(((region%4)*cell+4+local.x,(region//4)*cell+4+local.y))/size
data.calc_loop_triangles()
bm = bmesh.new(); bm.from_mesh(data)
assert all(e.is_manifold for e in bm.edges)
assert all(p.area>1e-10 for p in data.polygons)
bm.free()
radius = max(math.hypot(v.co.x,v.co.y) for v in data.vertices)
assert radius < .46
report = dict(asset=STEM, resource='mana_node', method='live Blender MCP',
    vertices=len(data.vertices), triangles=len(data.loop_triangles), floating_shards=4,
    footprint_radius=radius, height=.84, core_ground_clearance=.25,
    crystal_cross_section='square', host_rock='cuboid blocks',
    materials=1, texture_size=[size,size], texture_filter='nearest',
    closed_components=True, previous_scenes=previous_scenes)
(OUT/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for item in scene.objects: item.select_set(False)
root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
    use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
    export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')

world = bpy.data.worlds.new(STEM+'_Studio'); scene.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.29,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6
for name, position, power, scale in [('Key',(2,-3,4),240,3),('Fill',(-3,-1,2),110,3),('Rim',(1,3,3),170,2)]:
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=scale
    light=bpy.data.objects.new(name,ld); scene.collection.objects.link(light); light.location=position
    light.rotation_euler=(Vector((0,0,.3))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new(STEM+'_Camera'); cd.type='ORTHO'
camera=bpy.data.objects.new('Arcane_Preview_Camera',cd); scene.collection.objects.link(camera); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
for view, position, scale, aim in [('three_quarter',(1.8,-2.6,1.85),1.40,(0,0,.37)),
                                  ('game_top',(1.8,-2.9,4.9),2.0,(0,0,.15)),
                                  ('top',(0,0,5),1.2,(0,0,0))]:
    camera.location=position; cd.ortho_scale=scale
    camera.rotation_euler=(Vector(aim)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(1.8,-2.6,1.85); cd.ortho_scale=1.4
camera.rotation_euler=(Vector((0,0,.37))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert set(previous_scenes).issubset({s.name for s in bpy.data.scenes})
result=report
