"""Build a shared arcane-resource improvement in the live Blender MCP.

Run with blender_mcp_client.py. Adds an isolated scene; preserves the source
resource, all pre-existing scenes and the current Blender file/window scene.
"""
import bpy
import bmesh
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
STEM = 'arcane_conduit_v1'
OUT = ROOT / 'assets/generated/improvements' / STEM
SOURCE = ROOT / 'assets/generated/resources/arcane_node/arcane_node_v1/arcane_node_v1.glb'
assert not (OUT / (STEM + '.glb')).exists(), 'Preserve an existing exported asset.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scene = bpy.context.window.scene
previous_scenes = {s.name for s in bpy.data.scenes}
scene = bpy.data.scenes.new('Arcane_Conduit_V1_Shared')
bpy.context.window.scene = scene

try:
    # Import a copy of the approved resource into this scene only.
    old_objects = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    imported = set(bpy.data.objects) - old_objects
    originals = [o for o in imported if o.type == 'MESH']
    assert len(originals) == 1
    original = originals[0]
    original_image = next(n.image for n in original.data.materials[0].node_tree.nodes
                          if n.type == 'TEX_IMAGE' and n.image)
    assert tuple(original_image.size) == (256, 256)

    # One atlas/material for the complete installation. The lower-left quadrant
    # preserves every original texel and UV; the rest contains apparatus paint.
    size, cell = 512, 64
    pixels = np.ones((size, size, 4), dtype=np.float32)
    pixels[:, :, :3] = (0.09, 0.12, 0.15)
    source_pixels = np.empty(256 * 256 * 4, dtype=np.float32)
    original_image.pixels.foreach_get(source_pixels)
    pixels[:256, :256] = source_pixels.reshape((256, 256, 4))
    emission = np.ones((size, size, 4), dtype=np.float32)
    emission[:, :, :3] = 0
    for index in range(6):
        x, y = (index % 4) * cell, (index // 4) * cell
        emission[y:y+cell, x:x+cell, :3] = pixels[y:y+cell, x:x+cell, :3] * 0.5

    palette = {
        'slate_dark': (43, 52, 65), 'slate_side': (69, 82, 98),
        'slate_top': (96, 110, 124), 'bronze_dark': (69, 55, 39),
        'bronze': (126, 101, 66), 'bronze_edge': (168, 142, 96),
        'energy_dark': (29, 103, 121), 'energy': (82, 207, 217),
        'energy_light': (165, 239, 234), 'panel': (23, 45, 55),
    }
    slots = {}
    yy, xx = np.mgrid[:cell, :cell]
    for index, (name, color) in enumerate(palette.items()):
        # Columns 4..7, rows 0..2 do not overlap the approved resource quadrant.
        tile_x, tile_y = 4 + index % 4, index // 4
        slots[name] = (tile_x, tile_y)
        rng = np.random.default_rng(150026 + index)
        tile = np.empty((cell, cell, 3)); tile[:] = color
        tile += rng.integers(-6, 7, (32, 32)).repeat(2, 0).repeat(2, 1)[:, :, None]
        if name.startswith('slate'):
            tile[((xx//3*7 + yy//4*11) % 31) < 3] -= 11
        elif name.startswith('bronze'):
            tile[(yy % 21 < 2) & (xx % 29 < 19)] += 13
            tile[((xx//5*7 + yy//7*13) % 37) < 2] -= 14
        elif name.startswith('energy'):
            tile[(xx + yy*3) % 37 < 2] += 10
        else:
            # Orthogonal rune, painted into the console rather than tiny geometry.
            tile[10:13, 12:43] = (71, 180, 195)
            tile[10:39, 40:43] = (71, 180, 195)
            tile[36:39, 22:43] = (130, 225, 225)
            tile[25:38, 22:25] = (130, 225, 225)
        x, y = tile_x * cell, tile_y * cell
        pixels[y:y+cell, x:x+cell, :3] = np.clip(tile / 255, 0, 1)
        if name.startswith('energy') or name == 'panel':
            emissive = pixels[y:y+cell, x:x+cell, :3].copy()
            if name == 'panel': emissive *= (tile[:, :, 1] > 110)[:, :, None]
            emission[y:y+cell, x:x+cell, :3] = emissive * 0.6

    def image_file(suffix, values):
        image = bpy.data.images.new(STEM + suffix, size, size, alpha=False)
        image.colorspace_settings.name = original_image.colorspace_settings.name
        image.pixels.foreach_set(values.ravel())
        image.filepath_raw = str(OUT / (STEM + suffix + '.png'))
        image.file_format = 'PNG'; image.save(); image.pack()
        return image

    albedo = image_file('_albedo', pixels)
    glow = image_file('_emission', emission)
    material = bpy.data.materials.new(STEM + '_Pixel_Atlas')
    material.use_nodes = True
    material.use_backface_culling = True
    bsdf = material.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = 0.78
    bsdf.inputs['Specular IOR Level'].default_value = 0.20
    for image, socket in [(albedo, 'Base Color'), (glow, 'Emission Color')]:
        tex = material.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = image; tex.interpolation = 'Closest'
        material.node_tree.links.new(tex.outputs['Color'], bsdf.inputs[socket])
    bsdf.inputs['Emission Strength'].default_value = 0.55

    vertices, faces, face_uvs, parts = [], [], [], []
    uv_original = original.data.uv_layers.active
    vertices.extend(tuple(original.matrix_world @ v.co) for v in original.data.vertices)
    for face in original.data.polygons:
        faces.append(tuple(face.vertices))
        face_uvs.append([tuple(uv_original.data[i].uv * 0.5) for i in face.loop_indices])
    parts.append({'name': 'Approved_arcane_node_preserved', 'faces': len(faces)})
    original_count = len(vertices)

    def add_part(name, verts, polys, paints):
        offset = len(vertices)
        vertices.extend(tuple(v) for v in verts)
        for poly, paint in zip(polys, paints):
            faces.append(tuple(offset + i for i in poly))
            points = [Vector(verts[i]) for i in poly]
            normal = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
            axis = max(range(3), key=lambda i: abs(normal[i]))
            axes = [(1,2),(0,2),(0,1)][axis]
            coords = [Vector((p[axes[0]],p[axes[1]])) for p in points]
            low = Vector((min(p.x for p in coords),min(p.y for p in coords)))
            slot = Vector(slots[paint]) * cell
            uvs = []
            for coord in coords:
                local = (coord-low) * 105
                assert max(local) < cell-8, (name, local)
                uvs.append(tuple((slot + Vector((4,4)) + local) / size))
            face_uvs.append(uvs)
        parts.append({'name': name, 'faces': len(polys)})

    BOX_FACES = [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    def box(name, center, extent, paint='stone', angle=0):
        cx,cy,cz = center; sx,sy,sz = extent
        verts = []
        for z in (-sz/2,sz/2):
            for x,y in [(-sx/2,-sy/2),(sx/2,-sy/2),(sx/2,sy/2),(-sx/2,sy/2)]:
                verts.append((cx+x*math.cos(angle)-y*math.sin(angle),cy+x*math.sin(angle)+y*math.cos(angle),cz+z))
        palette_faces = {'stone':['slate_dark','slate_top','slate_side','slate_dark','slate_side','slate_side'],
                         'metal':['bronze_dark','bronze_edge','bronze','bronze_dark','bronze','bronze'],
                         'energy':['energy_dark','energy_light','energy','energy_dark','energy','energy']}[paint]
        add_part(name,verts,BOX_FACES,palette_faces)

    # Four low receivers collect the core's field into stone-mounted channels.
    # Their caps remain lower than the approved central crystal.
    for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]:
        cx,cy = sx*0.46,sy*0.39
        tag = f'{sx}_{sy}'
        box('Foundation_'+tag,(cx,cy,0.045),(0.22,0.22,0.09))
        box('Receiver_stone_'+tag,(cx,cy,0.25),(0.145,0.145,0.32))
        box('Lower_bronze_band_'+tag,(cx,cy,0.135),(0.165,0.165,0.045),'metal')
        box('Collector_housing_'+tag,(cx,cy,0.425),(0.19,0.19,0.08),'metal')
        box('Inset_lens_'+tag,(cx,cy,0.476),(0.118,0.118,0.022),'energy')
        # Two squared prongs, a readable receiving fork from the game camera.
        for side in (-1,1):
            box('Collector_prong_'+tag+str(side),(cx+side*0.079,cy,0.53),(0.032,0.12,0.16),'metal')
        start = Vector((sx*0.265,sy*0.205))
        end = Vector((cx,cy))
        delta = end-start; mid = (start+end)/2
        angle = math.atan2(delta.y,delta.x)
        box('Channel_stone_'+tag,(mid.x,mid.y,0.09),(delta.length+0.045,0.105,0.06),'stone',angle)
        box('Channel_metal_'+tag,(mid.x,mid.y,0.125),(delta.length+0.02,0.065,0.016),'metal',angle)
        box('Channel_energy_'+tag,(mid.x,mid.y,0.137),(delta.length,0.022,0.009),'energy',angle)

    # Small front control lectern; open space remains around the floating node.
    box('Control_foot',(0,-0.61,0.035),(0.27,0.22,0.07))
    box('Control_body',(0,-0.61,0.13),(0.19,0.15,0.12),'metal')
    verts = [(-.115,-.70,.16),(.115,-.70,.16),(.115,-.52,.22),(-.115,-.52,.22),
             (-.115,-.70,.19),(.115,-.70,.19),(.115,-.52,.25),(-.115,-.52,.25)]
    add_part('Rune_control_tablet',verts,BOX_FACES,['bronze_dark','panel','bronze','bronze','bronze_edge','bronze'])

    data = bpy.data.meshes.new(STEM + '_Mesh')
    data.from_pydata(vertices,[],faces); data.update()
    uv = data.uv_layers.new(name='PixelAtlas')
    for face,coords in zip(data.polygons,face_uvs):
        for loop_index,coord in zip(face.loop_indices,coords): uv.data[loop_index].uv = coord
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), 'Every disconnected solid must be closed.'
    bm.to_mesh(data); bm.free(); data.update(); data.calc_loop_triangles()
    assert all(p.area > 1e-10 for p in data.polygons)
    assert all(not p.use_smooth for p in data.polygons)
    radius = max(math.hypot(v.co.x,v.co.y) for v in data.vertices)
    assert radius < 0.78
    assert abs(min(v.co.z for v in data.vertices)) < 1e-6
    assert max(v.co.z for v in data.vertices) <= 0.841
    assert len(data.loop_triangles) < 800
    root = bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
    root['improvement_id'] = 'v2_improvement_arcane_conduit'
    root['resource_id'] = 'mana_node'; root['meters_per_tile_radius'] = 1.0
    root['shared_civilizations'] = 'human,elf,orc,dwarf'
    obj = bpy.data.objects.new(STEM + '_Complete',data)
    scene.collection.objects.link(obj); obj.parent = root
    data.materials.append(material)
    for item in imported: bpy.data.objects.remove(item,do_unlink=True)
    for item in scene.objects: item.select_set(False)
    root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
        use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
        export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')

    report = dict(asset=STEM,improvement='v2_improvement_arcane_conduit',resource='mana_node',
        method='live Blender MCP localhost:9876',source_resource=str(SOURCE.relative_to(ROOT)),
        preserved_resource=True,shared_civilizations=['human','elf','orc','dwarf'],
        vertices=len(data.vertices),triangles=len(data.loop_triangles),materials=1,meshes=1,
        texture_size=[size,size],texture_filter='nearest',footprint_radius=radius,
        height=max(v.co.z for v in data.vertices),ground_origin=True,closed_components=True,
        original_imported_vertices=original_count,parts=parts,animations=0,lights=0,
        concept='Approved floating node, four low receiver forks, stone channels and rune control lectern')
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

    world = bpy.data.worlds.new(STEM+'_Studio'); scene.world=world; world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value = (.18,.21,.25,1)
    world.node_tree.nodes['Background'].inputs[1].default_value = .5
    for name,pos,power,area in [('Key',(2,-3,4),220,3),('Fill',(-3,-1,2),110,3),('Rim',(1,3,3),170,2)]:
        light_data = bpy.data.lights.new(STEM+'_'+name,'AREA')
        light_data.energy=power; light_data.shape='DISK'; light_data.size=area
        light=bpy.data.objects.new(light_data.name,light_data); scene.collection.objects.link(light)
        light.location=pos; light.rotation_euler=(Vector((0,0,.3))-light.location).to_track_quat('-Z','Y').to_euler()
    camera_data=bpy.data.cameras.new(STEM+'_Camera'); camera_data.type='ORTHO'
    camera=bpy.data.objects.new(camera_data.name,camera_data); scene.collection.objects.link(camera); scene.camera=camera
    scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
    scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
    scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
    for name,pos,scale,aim in [('three_quarter',(2,-3,2.1),1.95,(0,0,.32)),
                               ('game_top',(1.8,-2.9,4.9),2.1,(0,0,.18)),
                               ('top',(0,0,5),1.8,(0,0,0))]:
        camera.location=pos; camera_data.ortho_scale=scale
        camera.rotation_euler=(Vector(aim)-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/'previews'/(name+'.png'))
        bpy.ops.render.render(write_still=True)
    camera.location=(2,-3,2.1); camera_data.ortho_scale=1.95
    camera.rotation_euler=(Vector((0,0,.32))-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    assert previous_scenes.issubset({s.name for s in bpy.data.scenes})
    result=report
finally:
    bpy.context.window.scene = previous_scene
