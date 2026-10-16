"""Create an editable amethyst tile resource in the live Blender MCP session."""
import bpy
import bmesh
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
OUT = ROOT / 'assets/generated/resources/crystals/crystal_cluster_v1'
STEM = 'crystal_cluster_v1'
UPDATE_EXISTING = globals().get('UPDATE_EXISTING', False)
assert UPDATE_EXISTING or not (OUT / (STEM + '.glb')).exists(), 'Preserve existing crystal asset.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scenes = [s.name for s in bpy.data.scenes]
scene = bpy.data.scenes.new('Crystal_Resource_V1_Blocky')
bpy.context.window.scene = scene
root = bpy.data.objects.new(STEM, None)
scene.collection.objects.link(root)
root['resource_id'] = 'gems'
root['tile_radius'] = 1.0

# Painted facets and stone share one opaque, nearest-sampled atlas.
palette = [(81, 39, 117), (112, 55, 155), (145, 75, 185),
           (175, 106, 212), (206, 150, 232), (236, 198, 247),
           (67, 65, 76), (91, 85, 102), (121, 111, 129)]
size, cell = 256, 64
pixels = np.ones((size, size, 4), dtype=np.float32)
pixels[:, :, :3] = (.22, .17, .27)
for i, color in enumerate(palette):
    rng = np.random.default_rng(121026 + i)
    y, x = np.mgrid[:cell, :cell]
    tile = np.zeros((cell, cell, 3)); tile[:] = color
    tile += rng.integers(-5, 6, (32, 32)).repeat(2, 0).repeat(2, 1)[:, :, None]
    if i < 6:
        # Sparse growth lines; highlights are painted, so fog stays readable.
        tile[((x // 3 * 11 + y // 9 * 7) % 37) < 2] += 11
        tile[(y % 17 == 3) & (x % 29 < 15)] -= 9
    else:
        tile[((x // 4 * 17 + y // 3 * 13) % 29) < 4] -= 12
        tile[((x // 3 * 7 + y // 5 * 11) % 41) < 3] += 9
    pixels[(i // 4) * cell:(i // 4 + 1) * cell,
           (i % 4) * cell:(i % 4 + 1) * cell, :3] = np.clip(tile / 255, 0, 1)
image = bpy.data.images.new(STEM + '_albedo', size, size, alpha=False)
image.pixels.foreach_set(pixels.ravel())
image.filepath_raw = str(OUT / (STEM + '_albedo.png'))
image.file_format = 'PNG'; image.save(); image.pack()
material = bpy.data.materials.new(STEM + '_Pixel_Material')
material.use_nodes = True; material.use_backface_culling = True
bsdf = material.node_tree.nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value = .64
bsdf.inputs['Specular IOR Level'].default_value = .22
texture = material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = image; texture.interpolation = 'Closest'
material.node_tree.links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])

vertices, faces, regions = [], [], []
parts = []
def add_part(name, verts, polygons, paints):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], polygons); data.update()
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    assert bm.calc_volume(signed=True) > 1e-10, name
    bm.to_mesh(data); bm.free()
    offset = len(vertices)
    vertices.extend(tuple(v.co) for v in data.vertices)
    faces.extend(tuple(offset + j for j in p.vertices) for p in data.polygons)
    regions.extend(paints)
    parts.append(dict(name=name, faces=len(polygons)))
    bpy.data.meshes.remove(data)

def crystal(name, x, y, height, radius, lean_x, lean_y, phase):
    verts = []
    # Four corners: square prism and square pyramid tip, matching the game.
    sides = 4
    for z, factor in [(0.02, .78), (height * .20, 1.0), (height * .73, .92)]:
        for i in range(sides):
            angle = math.pi / 4 + i * math.tau / sides
            verts.append((x + math.cos(angle) * radius * factor + lean_x * z / height,
                          y + math.sin(angle) * radius * factor + lean_y * z / height, z))
    verts.append((x + lean_x + radius * .12, y + lean_y - radius * .08, height))
    polys = [tuple(reversed(range(sides)))]; paints = [0]
    for ring in range(2):
        for i in range(sides):
            j = (i + 1) % sides
            polys.append((ring * sides + i, ring * sides + j, (ring + 1) * sides + j, (ring + 1) * sides + i))
            paints.append([1, 0, 2, 4][i] if ring else [0, 0, 1, 3][i])
    for i in range(sides):
        polys.append((2*sides+i, 2*sides+(i+1)%sides, 3*sides)); paints.append([3, 2, 4, 5][i])
    add_part(name, verts, polys, paints)

# An uneven vein: a tall center, leaning companions, and small emerging tips.
crystal('Crown', -.045, .035, .76, .135, -.035, .02, .15)
crystal('Left_spire', -.22, .035, .47, .10, -.095, -.035, .7)
crystal('Right_spire', .185, .08, .55, .108, .085, .055, .38)
crystal('Front_spire', .035, -.21, .40, .105, .035, -.065, .9)
crystal('Rear_spire', -.075, .255, .34, .08, -.035, .05, .3)
crystal('Left_shard', -.215, -.175, .24, .068, -.045, -.03, .55)
crystal('Right_shard', .255, -.17, .21, .06, .055, -.02, .2)

# Squared host rock blocks, with flat undersides at the ground origin.
def rock(name, x, y, rx, ry, height, phase):
    verts = [(x+dx, y+dy, z) for z in (0.0, height)
             for dx, dy in [(-rx,-ry),(rx,-ry),(rx,ry),(-rx,ry)]]
    polys = [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    paints = [6,8,7,6,7,8]
    add_part(name, verts, polys, paints)
rock('Host_rock', 0, .01, .32, .29, .105, .22)
rock('Rock_left', -.28, -.12, .11, .10, .095, .5)
rock('Rock_right', .27, .14, .11, .10, .12, .2)
rock('Rock_front', .10, -.28, .13, .09, .07, .4)

data = bpy.data.meshes.new(STEM + '_Mesh')
data.from_pydata(vertices, [], faces); data.update()
obj = bpy.data.objects.new('Crystal_Vein', data)
scene.collection.objects.link(obj); obj.parent = root
data.materials.append(material)
uv = data.uv_layers.new(name='Pixel_Atlas')
for face, region in zip(data.polygons, regions):
    face.use_smooth = False
    normal = face.normal
    axis = max(range(3), key=lambda j: abs(normal[j]))
    axes = [j for j in range(3) if j != axis]
    coords = [Vector((data.vertices[data.loops[i].vertex_index].co[axes[0]],
                      data.vertices[data.loops[i].vertex_index].co[axes[1]])) for i in face.loop_indices]
    lower = Vector((min(c.x for c in coords), min(c.y for c in coords)))
    # Fixed density: 64 texels per world unit, consistent across facets.
    for index, coord in zip(face.loop_indices, coords):
        local = (coord - lower) * 64
        assert max(local) < 56
        uv.data[index].uv = Vector(((region % 4) * cell + 4 + local.x,
                                    (region // 4) * cell + 4 + local.y)) / size
data.calc_loop_triangles()
bm = bmesh.new(); bm.from_mesh(data)
assert all(e.is_manifold for e in bm.edges)
assert all(p.area > 1e-10 for p in data.polygons)
bm.free()
radius = max(math.hypot(v.co.x, v.co.y) for v in data.vertices)
assert radius < .46
report = dict(asset=STEM, resource='gems', method='live Blender MCP',
              vertices=len(data.vertices), triangles=len(data.loop_triangles),
              crystal_spires=7, footprint_radius=radius, height=.76,
              materials=1, texture_size=[size, size], texture_filter='nearest',
              crystal_cross_section='square', host_rock='cuboid blocks',
              closed_components=True, previous_scenes=previous_scenes)
(OUT / 'manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')

for item in scene.objects: item.select_set(False)
root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(filepath=str(OUT / (STEM + '.glb')), export_format='GLB',
    use_selection=True, use_active_scene=True, export_animations=False,
    export_skins=False, export_yup=True, export_cameras=False, export_lights=False,
    export_extras=True, export_materials='EXPORT')

# Preview studio is separate from the exported resource.
world = bpy.data.worlds.new(STEM + '_Studio'); scene.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.20, .23, .29, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .6
def light(name, position, power, scale):
    light_data = bpy.data.lights.new(name, 'AREA'); light_data.energy = power; light_data.shape = 'DISK'; light_data.size = scale
    item = bpy.data.objects.new(name, light_data); scene.collection.objects.link(item)
    item.location = position; item.rotation_euler = (Vector((0, 0, .25))-item.location).to_track_quat('-Z', 'Y').to_euler()
light('Key', (2, -3, 4), 240, 3)
light('Fill', (-3, -1, 2), 110, 3)
light('Rim', (1, 3, 3), 170, 2)
camera_data = bpy.data.cameras.new(STEM + '_Camera'); camera_data.type = 'ORTHO'
camera = bpy.data.objects.new('Crystal_Preview_Camera', camera_data); scene.collection.objects.link(camera); scene.camera = camera
scene.render.engine = 'CYCLES'; scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 800; scene.render.resolution_y = 800; scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.view_settings.view_transform = 'Standard'
for view, position, scale, aim in [
    ('three_quarter', (1.8, -2.6, 1.85), 1.30, (0, 0, .32)),
    ('game_top', (1.8, -2.9, 4.9), 2.0, (0, 0, .15)),
    ('top', (0, 0, 5), 1.2, (0, 0, 0))]:
    camera.location = position; camera_data.ortho_scale = scale
    camera.rotation_euler = (Vector(aim)-camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(OUT / 'previews' / (view + '.png'))
    bpy.ops.render.render(write_still=True)
camera.location = (1.8, -2.6, 1.85); camera_data.ortho_scale = 1.3
camera.rotation_euler = (Vector((0, 0, .32))-camera.location).to_track_quat('-Z', 'Y').to_euler()
bpy.data.libraries.write(str(OUT / (STEM + '.blend')), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
assert set(previous_scenes).issubset({s.name for s in bpy.data.scenes})
result = report
