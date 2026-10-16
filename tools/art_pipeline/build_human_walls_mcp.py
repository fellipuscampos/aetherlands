"""Three low human fortification rings, modeled/exported in the live Blender MCP.

Reuse the approved City IV material and atlas pixels without repainting them.
Coordinates follow City._add_walls and HexMetrics, converted to Blender XY.
Existing scenes and assets are preserved; only new owned scenes are exported.
"""
import bpy, bmesh, math, json, hashlib, struct, zlib, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
sys.path.insert(0, str(ROOT/'tools/art_pipeline'))
from human_wall_surface_cleanup import clean_human_wall_surfaces, audit_coplanar
OUT_ROOT = ROOT/'assets/generated/humans/buildings'
WORK = ROOT/'art_source/human_walls_review'
WORK.mkdir(parents=True, exist_ok=True)
(WORK/'.gdignore').touch()
SOURCE = OUT_ROOT/'city_level_4_hex_v1/city_level_4_hex_v1.blend'
source = bpy.app.driver_namespace.get('human_wall_reference')
if source is None:
    with bpy.data.libraries.load(str(SOURCE), link=False) as (available, loaded):
        loaded.scenes = ['City_Level_4_Hex_V1']
    source = loaded.scenes[0]
    bpy.app.driver_namespace['human_wall_reference'] = source

protected = [p for level in range(1, 5) for p in (OUT_ROOT/f'city_level_{level}_hex_v1').glob('*') if p.is_file()]
before = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
(WORK/'source_baseline.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
source_material = next(o.data.materials[0] for o in source.objects if o.type == 'MESH' and o.get('region') == 'stone')
source_images = {n.image for n in source_material.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image}
assert all(im.packed_file for im in source_images)
image_hashes = {im.name: hashlib.sha256(bytes(im.packed_file.data)).hexdigest() for im in source_images}

# Rectangular approved atlas islands, identified by architectural surface.
# Sampling subrectangles preserves the existing paint, palette and texel density.
tiles = {}
for obj in source.objects:
    region = obj.get('region')
    if obj.type != 'MESH' or not region or region == 'studio':
        continue
    uv = obj.data.uv_layers.active
    for face in obj.data.polygons:
        if len(face.vertices) != 4:
            continue
        points = [uv.data[i].uv.copy() for i in face.loop_indices]
        lo = Vector((min(v.x for v in points), min(v.y for v in points)))
        hi = Vector((max(v.x for v in points), max(v.y for v in points)))
        area = abs(sum(points[i].x*points[(i+1)%4].y-points[(i+1)%4].x*points[i].y for i in range(4)))*.5
        if (hi.x-lo.x)*(hi.y-lo.y) < 1e-9 or area/((hi.x-lo.x)*(hi.y-lo.y)) < .995:
            continue
        # City IV was painted at 128 pixels per native map meter.
        tiles.setdefault(region, []).append((lo, hi, (hi-lo)*2048/128))
assert all(tiles.get(region) for region in ('stone', 'cutstone', 'foundation', 'roof', 'roof_dark', 'door', 'iron', 'shadow', 'gold', 'faction'))

NORMALS = [Vector((math.cos(math.radians(i*60)), math.sin(math.radians(i*60)))) for i in range(6)]
OUTER_LIMIT = .985 * math.sqrt(3)/2
CITY_LIMIT = .84 * math.sqrt(3)/2
WALL_RADIUS = .94
APOTHEM = WALL_RADIUS * math.sqrt(3)/2
results = []
states = []

def clip_to_tile(outline):
    for normal in NORMALS:
        output = []
        for i, b in enumerate(outline):
            a = outline[i-1]
            da, db = a.dot(normal)-OUTER_LIMIT, b.dot(normal)-OUTER_LIMIT
            if (da <= 1e-9) != (db <= 1e-9):
                output.append(a+(b-a)*(-da/(db-da)))
            if db <= 1e-9:
                output.append(b)
        outline = output
    return outline

for level in (1, 2, 3):
    stem = f'human_walls_level_{level}_hex_v1'
    name = f'Human_Walls_Level_{level}_Hex_V1'
    out = OUT_ROOT/stem
    if (out/(stem+'.glb')).exists():
        # Resume a partially completed batch without replacing a successful level.
        report = json.loads((out/(stem+'_report.json')).read_text(encoding='utf-8'))
        assert report['status']=='PASS' and report['material_source']==str(SOURCE.relative_to(ROOT))
        results.append(report)
        existing = bpy.data.scenes.get(name)
        if existing:
            states.append(dict(scene=existing,root=next(o for o in existing.objects if o.type=='EMPTY'),
                parts=[o for o in existing.objects if o.type=='MESH'],out=out))
        continue
    existing = bpy.data.scenes.get(name)
    if existing:
        # These are our unexported objects from an interrupted build.
        assert all(o.name.startswith(name) for o in existing.objects)
        bpy.data.batch_remove(ids={existing,*existing.objects})
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    root['race'] = 'human'
    root['fortification_level'] = level
    root['tile_radius'] = 1.0
    root['wall_radius'] = WALL_RADIUS
    root['low_decorative_wall'] = True
    material = source_material.copy()
    material.name = name+'_Approved_City_Material'
    parts = []
    footprints = []

    def prism(part, outline, z0, z1, region, group):
        outline = clip_to_tile(outline)
        assert len(outline) >= 3 and z1 > z0
        # A separating hex plane proves the whole convex part stays outside
        # the largest city foundation, rather than testing only its vertices.
        clearance = max(min(n.dot(v) for v in outline)-CITY_LIMIT for n in NORMALS)
        assert clearance > .006, (part, clearance)
        footprints.append(clearance)
        count = len(outline)
        vertices = [(v.x, v.y, z) for z in (z0, z1) for v in outline]
        faces = [tuple(reversed(range(count))), tuple(range(count, 2*count))]
        faces += [(i, (i+1)%count, (i+1)%count+count, i+count) for i in range(count)]
        data = bpy.data.meshes.new(name+'_'+part+'_Mesh')
        data.from_pydata(vertices, [], faces)
        data.update()
        bm = bmesh.new(); bm.from_mesh(data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True) > 1e-12, part
        bm.to_mesh(data); bm.free()
        obj = bpy.data.objects.new(name+'_'+part, data)
        scene.collection.objects.link(obj)
        obj.parent = root
        obj['part'] = part; obj['region'] = region; obj['group'] = group
        data.materials.append(material)
        uv = data.uv_layers.new(name='Approved_City_Atlas_UV')
        seed = zlib.crc32(part.encode('utf-8'))
        for poly in data.polygons:
            normal = poly.normal
            if abs(normal.z) > .9:
                right, up = Vector((1,0,0)), Vector((0,1,0))
            else:
                right, up = Vector((normal.y,-normal.x,0)).normalized(), Vector((0,0,1))
            values = [Vector((data.vertices[i].co.dot(right), data.vertices[i].co.dot(up))) for i in poly.vertices]
            lower = Vector((min(v.x for v in values), min(v.y for v in values)))
            span = Vector((max(v.x for v in values)-lower.x, max(v.y for v in values)-lower.y))
            tile = max(tiles[region], key=lambda t: min(t[2].x/max(span.x,.0001), t[2].y/max(span.y,.0001)))
            lo, hi, physical = tile
            # Half a pixel inset avoids sampling the neighboring atlas island.
            lo, hi = lo+Vector((.5/2048,.5/2048)), hi-Vector((.5/2048,.5/2048))
            fraction = Vector((min(1., span.x/max(physical.x,.0001)), min(1., span.y/max(physical.y,.0001))))
            size = Vector(((hi.x-lo.x)*fraction.x, (hi.y-lo.y)*fraction.y))
            offset = Vector(((hi.x-lo.x-size.x)*(seed%7)/6, (hi.y-lo.y-size.y)*((seed//7)%7)/6))
            for loop, value in zip(poly.loop_indices, values):
                local = value-lower
                uv.data[loop].uv = lo+offset+Vector((local.x/max(span.x,.0001)*size.x, local.y/max(span.y,.0001)*size.y))
            poly.use_smooth = False
        parts.append(obj)
        return obj

    def rectangle(part, center, width, depth, z0, z1, region, group, angle):
        center = Vector(center)
        along = Vector((math.cos(angle), math.sin(angle)))
        across = Vector((-math.sin(angle), math.cos(angle)))
        outline = [center+along*(x*width/2)+across*(y*depth/2) for x,y in ((-1,-1),(1,-1),(1,1),(-1,1))]
        return prism(part, outline, z0, z1, region, group)

    def edge_box(part, edge, x, radial_offset, width, depth, z0, z1, region, group='Architecture'):
        # Reflection of Godot XZ into Blender XY: +Godot Z becomes -Blender Y.
        phi = math.radians(-60*edge)
        normal = Vector((math.cos(phi), math.sin(phi)))
        tangent = Vector((-math.sin(phi), math.cos(phi)))
        center = normal*(APOTHEM+radial_offset)+tangent*x
        return rectangle(part, center, width, depth, z0, z1, region, group, phi+math.pi/2)

    body_top = {1:.194, 2:.211, 3:.223}[level]
    coping_top = body_top+.026
    columns = 4 if level < 3 else 5
    for edge in range(6):
        # The wooden closed gate occupies part of one front edge; the other
        # five sides remain continuous. No ground plate fills the empty center.
        sections = [(-.449, .449)] if edge != 1 else [(-.449,-.120),(.120,.449)]
        for section, (left, right) in enumerate(sections):
            edge_box(f'Edge_{edge}_Foot_{section}',edge,(left+right)/2,0,right-left,.092,0,.031,'foundation')
            for course in range(3):
                for column in range(columns):
                    a = left+(right-left)*column/columns
                    b = left+(right-left)*(column+1)/columns
                    edge_box(f'Edge_{edge}_Course_{course}_Stone_{section}_{column}',edge,(a+b)/2,0,b-a,.073,
                             .026+(body_top-.026)*course/3,.026+(body_top-.026)*(course+1)/3,
                             'stone' if level<3 or course!=1 else 'cutstone')
            edge_box(f'Edge_{edge}_Coping_{section}',edge,(left+right)/2,0,right-left,.088,body_top,coping_top,'cutstone')
            if level >= 2:
                number = 6 if level == 2 else 7
                if edge == 1: number = 2
                for merlon in range(number):
                    x = left+(right-left)*(merlon+.5)/number
                    edge_box(f'Edge_{edge}_Merlon_{section}_{merlon}',edge,x,0,.055 if level==2 else .052,.085,
                             coping_top,coping_top+.043,'cutstone')
            if level == 3:
                edge_box(f'Edge_{edge}_Dressed_Band_{section}',edge,(left+right)/2,.006,right-left,.081,.080,.095,'cutstone')
                for buttress in (-.32,.32):
                    if left<buttress<right:
                        edge_box(f'Edge_{edge}_Buttress_{section}_{buttress}',edge,buttress,.030,.037,.020,.016,body_top,'cutstone')

    for corner in range(6):
        angle = math.radians(30-60*corner)
        center = Vector((math.cos(angle), math.sin(angle)))*.946
        width, depth = ((.104,.096) if level==1 else (.120,.110))
        tower_top = {1:.235, 2:.282, 3:.279}[level]
        rectangle(f'Corner_{corner}_Foot',center,width,depth,0,.036,'foundation','Architecture',angle)
        rectangle(f'Corner_{corner}_Tower',center,width-.008,depth-.008,.033,tower_top,'stone','Architecture',angle)
        rectangle(f'Corner_{corner}_Cap',center,width,depth,tower_top,tower_top+.024,'cutstone','Architecture',angle)
        if level == 2:
            for a,b in ((-1,-1),(-1,1),(1,-1),(1,1)):
                radial = Vector((math.cos(angle),math.sin(angle)))
                tangent = Vector((-math.sin(angle),math.cos(angle)))
                merlon_center = center+radial*(a*.036)+tangent*(b*.031)
                rectangle(f'Corner_{corner}_Battlement_{a}_{b}',merlon_center,.035,.035,tower_top+.022,tower_top+.064,'cutstone','Architecture',angle)
        if level >= 2:
            radial = Vector((math.cos(angle),math.sin(angle)))
            rectangle(f'Corner_{corner}_ArrowSlit',center-radial*((width-.008)/2+.001),.002,.013,.13,.206,'shadow','Architecture',angle)
        if level == 3:
            rectangle(f'Corner_{corner}_Lower_Band',center,width,depth,.075,.092,'cutstone','Architecture',angle)
            for layer in range(3):
                rectangle(f'Corner_{corner}_Blue_Roof_{layer}',center,.126-layer*.033,.116-layer*.030,
                          tower_top+.020+layer*.023,tower_top+.043+layer*.023,'roof','Architecture',angle)
            rectangle(f'Corner_{corner}_Blue_Ridge',center,.051,.047,tower_top+.089,tower_top+.102,'roof_dark','Architecture',angle)
            rectangle(f'Corner_{corner}_Gold_Finial',center,.017,.017,tower_top+.102,tower_top+.115,'gold','Architecture',angle)

    # A short square stone portal, closed timber double leaves and metal bands.
    door_top = {1:.169, 2:.197, 3:.210}[level]
    gate_top = {1:.239, 2:.300, 3:.315}[level]
    for side in (-1,1):
        edge_box(f'Gate_Jamb_{side}',1,side*.112,0,.040,.070,0,gate_top-.033,'cutstone')
        edge_box(f'Gate_Door_{side}',1,side*.046,-.004,.089,.022,.008,door_top,'door')
        for band in (.049,.134):
            edge_box(f'Gate_Iron_Band_{side}_{band}',1,side*.046,.010,.087,.008,band,band+.011,'iron')
        edge_box(f'Gate_Handle_{side}',1,side*.015,.016,.012,.008,.087,.108,'iron' if level==1 else 'gold')
    edge_box('Gate_Shadow',1,0,-.012,.19,.018,.004,door_top+.013,'shadow')
    edge_box('Gate_Lintel',1,0,0,.26,.070,door_top,gate_top-.022,'cutstone')
    edge_box('Gate_Cap',1,0,0,.275,.074,gate_top-.022,gate_top,'cutstone')
    if level >= 2:
        edge_box('Gate_Blue_Eave',1,0,0,.282,.074,gate_top,gate_top+.018,'roof')
        edge_box('Gate_Blue_Ridge',1,0,0,.236,.065,gate_top+.018,gate_top+.035,'roof')
        edge_box('Gate_Owner_Faction',1,0,.038,.052,.004,door_top+.013,door_top+.049,'faction','Faction')
    if level == 3:
        edge_box('Gate_Royal_Gold_Fillet',1,0,.038,.260,.008,gate_top-.032,gate_top-.023,'gold')
        # Three square crown points reproduce the architectural royal motif.
        edge_box('Gate_Crown_Base',1,0,.040,.036,.009,door_top+.016,door_top+.023,'gold')
        for j in (-1,0,1):
            edge_box(f'Gate_Crown_Point_{j}',1,j*.013,.040,.010,.009,door_top+.021,door_top+.035,'gold')

    overlaps_before = audit_coplanar(parts)
    surface_cleanup = clean_human_wall_surfaces(parts)
    assert not audit_coplanar(parts, include_opposing=True), 'Coplanar patches must have a single owner'
    surface_cleanup.update(coplanar_overlaps_before=len(overlaps_before),coplanar_overlaps_after=0,
        atlas_bytes_unchanged=True,method='Visible boundary partition, interpolated original UVs')
    vertices = [obj.matrix_world@v.co for obj in parts for v in obj.data.vertices]
    triangles = sum(len(p.vertices)-2 for obj in parts for p in obj.data.polygons)
    max_half_plane = max(n.dot(Vector((v.x,v.y))) for v in vertices for n in NORMALS)
    height = max(v.z for v in vertices)
    assert max_half_plane <= OUTER_LIMIT+1e-6 and height < .40
    assert min(v.z for v in vertices) >= -1e-7
    # Export two consolidated meshes at most; source keeps every editable part.
    temporary = bpy.data.collections.new(name+'_EXPORT_TEMP')
    scene.collection.children.link(temporary)
    copies = []
    try:
        for group in ('Architecture','Faction'):
            selected = []
            for original in parts:
                if original['group'] == group:
                    copy = original.copy(); copy.data = original.data.copy()
                    temporary.objects.link(copy); selected.append(copy)
            if not selected: continue
            with bpy.context.temp_override(active_object=selected[0], selected_editable_objects=selected, selected_objects=selected):
                bpy.ops.object.join()
            selected[0].name = name+'_'+group
            copies.append(selected[0])
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for copy in copies: copy.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.export_scene.gltf(filepath=str(out/(stem+'.glb')),export_format='GLB',use_selection=True,
            use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,
            export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    finally:
        for copy in list(temporary.objects):
            data = copy.data
            bpy.data.objects.remove(copy,do_unlink=True)
            if data.users==0: bpy.data.meshes.remove(data)
        bpy.data.collections.remove(temporary)

    raw = (out/(stem+'.glb')).read_bytes()
    json_size = struct.unpack_from('<I',raw,12)[0]
    document = json.loads(raw[20:20+json_size])
    binary = raw[28+json_size:]
    exported_triangles = sum(document['accessors'][p['indices']]['count']//3 for m in document['meshes'] for p in m['primitives'])
    assert exported_triangles == triangles
    assert not document.get('animations') and not document.get('skins') and not document.get('cameras')
    assert all(s.get('magFilter')==9728 for s in document['samplers'])
    verified_images = []
    for image in document['images']:
        view = document['bufferViews'][image['bufferView']]
        payload = binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        digest = hashlib.sha256(payload).hexdigest()
        assert digest in image_hashes.values(), 'An approved atlas changed during export'
        verified_images.append(dict(name=image['name'],sha256=digest,bytes=len(payload)))
    report = dict(status='PASS',name=name,stem=stem,race='human',fortification_level=level,
        display_name={1:'Muralhas I',2:'Muralhas II',3:'Fortaleza'}[level],pipeline='Blender 5.2 MCP localhost:9876',
        material_source=str(SOURCE.relative_to(ROOT)),texture_reuse='Byte-identical approved City IV atlas; existing face islands sampled, no repaint',
        embedded_images=verified_images,triangles=triangles,editable_parts=len(parts),runtime_meshes=len(document['meshes']),
        source_boundary_sections=True,surface_cleanup=surface_cleanup,
        shade='Flat',origin='Footprint center, ground Z=0',native_tile_radius=1.0,
        scales_with='City.tile_radius',pointy_hex=True,wall_center_radius=WALL_RADIUS,
        max_half_plane=max_half_plane,tile_half_plane=math.sqrt(3)/2,height=height,
        minimum_city_foundation_clearance=min(footprints),city_foundation_radius=.84,
        includes_ground_plate=False,includes_city=False,bounds_blender=dict(min=[min(v[i] for v in vertices) for i in range(3)],max=[max(v[i] for v in vertices) for i in range(3)]),
        design={1:'Low plain masonry, simple coping, six square corner posts, timber gate.',
                2:'Low crenellated masonry, square corner battlements, arrow slits, dressed portal and blue gate cap.',
                3:'Dressed masonry, buttresses, short stepped blue turret roofs, restrained gold finials and crowned portal.'}[level])
    (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    results.append(report)
    states.append(dict(scene=scene,root=root,parts=parts,out=out))

assert before == {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}, 'An existing city asset changed'
bpy.app.driver_namespace['human_walls_v1'] = states
(WORK/'blender_validation.json').write_text(json.dumps(dict(status='PASS',source_assets_unchanged=True,levels=results),ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='PASS',source_assets_unchanged=True,levels=[{key:r[key] for key in ('stem','height','triangles','runtime_meshes','minimum_city_foundation_clearance')} for r in results])))
