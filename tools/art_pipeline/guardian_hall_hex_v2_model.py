"""Hex-first 4X Guardian Hall, native map units: tile circumradius 1.
Build in the running Blender MCP. Preserve V1 and all other open scenes.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
NAME = 'Guardian_Hall_Hex_V2'
OUT = ROOT / 'assets/generated/humans/buildings/guardian_hall_hex_v2'
OUT.mkdir(parents=True, exist_ok=True)
if NAME in bpy.data.scenes:
    raise RuntimeError('Hex V2 scene exists; preserve its edits.')
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION', '02_HALL', '03_ROOFS', '04_WATCHTOWER',
              '05_COURTYARD', '06_TRAINING', '07_HERALDRY', '08_DETAILS', '09_STUDIO'):
    c = bpy.data.collections.new(NAME + '_' + label)
    scene.collection.children.link(c)
    groups[label] = c
parts = []
CUBE = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]


def mesh(name, vertices, faces, region, group):
    me = bpy.data.meshes.new(NAME + '_' + name + '_Mesh')
    me.from_pydata(vertices, [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(NAME + '_' + name, me)
    groups[group].objects.link(obj)
    obj['part'], obj['region'], obj['paint_up'] = name, region, [0, 0, 1]
    for p in me.polygons:
        p.use_smooth = False
    if group != '09_STUDIO':
        parts.append(obj)
    return obj


def box(name, center, size, region='stone', group='02_HALL', angle=0):
    c = Vector(center)
    a = Vector((math.cos(angle), math.sin(angle), 0))
    b = Vector((-math.sin(angle), math.cos(angle), 0))
    z = Vector((0, 0, 1))
    verts = [tuple(c + a * sx * size[0] / 2 + b * sy * size[1] / 2 + z * sz * size[2] / 2)
             for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    return mesh(name, verts, CUBE, region, group)


def polygon_prism(name, points, bottom, top, region, group):
    n = len(points)
    verts = [(x, y, z) for z in (bottom, top) for x, y in points]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, verts, faces, region, group)


def hexagon(radius, center=(0, 0), angle=-30):
    return [(center[0] + radius * math.cos(math.radians(angle + i * 60)),
             center[1] + radius * math.sin(math.radians(angle + i * 60))) for i in range(6)]


def wall(name, a, b, width, bottom, top, region='stone', group='05_COURTYARD'):
    d = Vector((b[0] - a[0], b[1] - a[1]))
    return box(name, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (bottom + top) / 2),
               (d.length, width, top - bottom), region, group, math.atan2(d.y, d.x))


def shield(name, center, width, height, group='07_HERALDRY'):
    # Stepped, round shield, matching the Squire silhouette, iron frame + blue band.
    shape = [(-.28, .5), (.28, .5), (.28, .4), (.42, .4), (.42, .24), (.5, .24),
             (.5, -.24), (.42, -.24), (.42, -.4), (.28, -.4), (.28, -.5),
             (-.28, -.5), (-.28, -.4), (-.42, -.4), (-.42, -.24), (-.5, -.24),
             (-.5, .24), (-.42, .24), (-.42, .4), (-.28, .4)]
    cx, cy, cz = center
    n = len(shape)
    for suffix, scale, depth, region in (('Rim', 1, .016, 'iron_light'), ('Wood', .82, .018, 'shield')):
        front = cy - (.015 if suffix == 'Wood' else 0)
        verts = [(cx + x * width * scale, front + y, cz + z * height * scale)
                 for y in (-depth / 2, depth / 2) for x, z in shape]
        faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
        faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
        obj = mesh(name + '_' + suffix, verts, faces, region, group)
        if suffix == 'Wood':
            obj['shield_center'], obj['shield_size'] = list(center), [width * .82, height * .82]
    box(name + '_Boss', (cx, cy - .035, cz), (width * .21, .025, height * .21), 'iron_light', group)


# The base is the game's exact pointy-top hex orientation, with an 8% rim margin.
polygon_prism('Hex_Foundation', hexagon(.92), 0, .035, 'foundation', '01_FOUNDATION')
polygon_prism('Hex_Stone_Rim', hexagon(.90), .035, .065, 'cutstone', '01_FOUNDATION')
polygon_prism('Hex_Paving', hexagon(.845), .065, .075, 'paving', '01_FOUNDATION')

# Six-sided hall, centred slightly to the rear to leave a wedge-shaped parade court.
polygon_prism('Hall_Six_Sided', hexagon(.48, (0, .10), 0), .075, .77, 'stone', '02_HALL')
polygon_prism('Hall_Base_Band', hexagon(.50, (0, .10), 0), .075, .17, 'cutstone', '02_HALL')
polygon_prism('Hall_Eaves', hexagon(.53, (0, .10), 0), .745, .80, 'timber', '02_HALL')
for i in range(6):
    radius = .55 - i * .073
    obj = polygon_prism('Hex_Roof_Course_%02d' % i, hexagon(radius, (0, .10), 0),
                        .80 + i * .065, .865 + i * .065, 'roof', '03_ROOFS')
polygon_prism('Hex_Roof_Cap', hexagon(.115, (0, .10), 0), 1.19, 1.235, 'roof_dark', '03_ROOFS')
polygon_prism('Hex_Roof_Finial', hexagon(.052, (0, .10), 0), 1.235, 1.275, 'iron', '03_ROOFS')

# Six heavy stepped buttresses express the radial building structure.
for i, (x, y) in enumerate(hexagon(.48, (0, .10), 0)):
    angle = math.radians(i * 60)
    for j, (radius, size, z, height) in enumerate(((.50, .12, .18, .21), (.505, .09, .40, .23), (.50, .065, .64, .25))):
        bx, by = radius * math.cos(angle), .10 + radius * math.sin(angle)
        box('Hall_Buttress_%d_%d' % (i, j), (bx, by, z), (size, .13 if j == 0 else .095, height), 'cutstone', angle=angle)

# Enlarged portal and crest, readable as military training at strategic distance.
front = .10 - .48 * math.sqrt(3) / 2
box('Portal_Shadow', (0, front - .009, .354), (.34, .026, .49), 'shadow')
box('Portal_Door', (0, front - .029, .35), (.295, .025, .475), 'timber')
for sign in (-1, 1):
    box('Portal_Jamb_' + str(sign), (sign * .182, front - .022, .36), (.065, .09, .56), 'cutstone')
box('Portal_Lintel', (0, front - .045, .672), (.435, .12, .075), 'cutstone')
for z in (.205, .49):
    box('Door_Iron_Band_' + str(z), (0, front - .046, z), (.283, .012, .026), 'iron')
box('Door_Centre_Seam', (0, front - .047, .351), (.008, .014, .472), 'shadow')
box('Portal_Crest_Backing', (0, -.438, .848), (.39, .035, .39), 'timber', '07_HERALDRY')
shield('Portal_Crest', (0, -.466, .849), .345, .37)
for sign in (-1, 1):
    box('Facade_Lantern_' + str(sign), (sign * .257, front - .025, .555), (.033, .037, .060), 'glow', '08_DETAILS')
    for z in (.513, .597):
        box('Lantern_Cap_%d_%s' % (sign, z), (sign * .257, front - .025, z), (.05, .052, .024), 'iron', '08_DETAILS')

# Low towers occupy the two front hex corners; the taller rear tower anchors the apex.
for label, x, y, top in (('Left', -.59, -.34, .61), ('Right', .59, -.34, .61), ('Rear', 0, .655, 1.01)):
    box('Tower_' + label + '_Foot', (x, y, .13), (.25, .25, .11), 'foundation', '04_WATCHTOWER')
    box('Tower_' + label + '_Body', (x, y, (top + .185) / 2), (.21, .21, top - .185), 'stone', '04_WATCHTOWER')
    for sx in (-1, 1):
        for sy in (-1, 1):
            box('Tower_' + label + '_Quoin_%d_%d' % (sx, sy),
                (x + sx * .100, y + sy * .100, (top + .185) / 2), (.035, .035, top - .185), 'cutstone', '04_WATCHTOWER')
    box('Tower_' + label + '_Crown', (x, y, top + .025), (.265, .265, .05), 'cutstone', '04_WATCHTOWER')
    box('Tower_' + label + '_Deck', (x, y, top + .057), (.218, .218, .014), 'paving', '04_WATCHTOWER')
    for sx in (-1, 1):
        for sy in (-1, 1):
            box('Tower_' + label + '_Merlon_%d_%d' % (sx, sy),
                (x + sx * .096, y + sy * .096, top + .107), (.073, .073, .10), 'cutstone', '04_WATCHTOWER')
    box('Tower_' + label + '_Slit', (x, y - .110, top - .15), (.043, .013, .135), 'shadow', '04_WATCHTOWER')
    box('Tower_' + label + '_Slit_Lintel', (x, y - .114, top - .059), (.084, .03, .023), 'cutstone', '04_WATCHTOWER')

# Hexagonal perimeter follows the actual six edges; front point is left open as the approach.
ring = hexagon(.84)
for i in range(4):
    a, b = ring[i], ring[(i + 1) % 6]
    for label, width, bottom, top, region in (('Wall', .078, .075, .285, 'stone'), ('Coping', .112, .285, .320, 'cutstone')):
        outer, inner = hexagon(.84 + width / math.sqrt(3)), hexagon(.84 - width / math.sqrt(3))
        polygon_prism('Hex_' + label + '_%d' % i,
            [outer[i], outer[(i + 1) % 6], inner[(i + 1) % 6], inner[i]], bottom, top, region, '05_COURTYARD')
    for j in (1, 2, 3):
        t = j / 4
        mx, my = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        angle = math.atan2(b[1] - a[1], b[0] - a[0])
        box('Hex_Merlon_%d_%d' % (i, j), (mx, my, .355), (.105, .082, .07), 'cutstone', '05_COURTYARD', angle)
for sign in (-1, 1):
    wall('Front_Oblique_Wall_' + str(sign), (sign * .72746, -.42), (sign * .205, -.7217), .078, .075, .245)
    wall('Front_Oblique_Coping_' + str(sign), (sign * .72746, -.42), (sign * .205, -.7217), .112, .245, .28, 'cutstone')
    box('Entrance_Post_' + str(sign), (sign * .205, -.706, .228), (.115, .11, .30), 'cutstone', '05_COURTYARD')
    box('Entrance_PostCap_' + str(sign), (sign * .205, -.706, .395), (.135, .13, .035), 'iron', '05_COURTYARD')

# Training area conforms to the widening front sector, instead of a rectangular courtyard.
polygon_prism('Training_Sand_Wedge', [(-.44, -.26), (.44, -.26), (.53, -.34), (.40, -.53),
                                     (0, -.76), (-.40, -.53), (-.53, -.34)], .075, .088, 'sand', '06_TRAINING')
polygon_prism('Entrance_Paving_Wedge', [(-.17, -.28), (.17, -.28), (.12, -.67), (0, -.79), (-.12, -.67)],
              .088, .100, 'paving', '06_TRAINING')
for sign in (-1, 1):
    x, y = sign * .305, -.425
    box('Dummy_Foot_' + str(sign), (x, y, .11), (.16, .135, .04), 'timber', '06_TRAINING')
    box('Dummy_Post_' + str(sign), (x, y, .24), (.035, .04, .25), 'timber', '06_TRAINING')
    box('Dummy_Arms_' + str(sign), (x, y, .31), (.19, .04, .038), 'timber', '06_TRAINING')
    box('Dummy_Head_' + str(sign), (x, y, .395), (.065, .065, .070), 'straw', '06_TRAINING')
    shield('Dummy_Shield_' + str(sign), (x, y - .035, .265), .14, .17, '06_TRAINING')
    box('Drill_Marker_' + str(sign), (sign * .225, -.574, .098), (.090, .068, .020), 'formation', '06_TRAINING')

# Deliberately few, large details: a weapon rack and a single banner.
for x in (.45, .63):
    box('Spear_Rack_Post_' + str(x), (x, -.06, .235), (.025, .035, .32), 'timber', '08_DETAILS')
box('Spear_Rack_Rail', (.54, -.06, .342), (.22, .033, .032), 'timber', '08_DETAILS')
for i in range(3):
    x = .475 + i * .065
    box('Spear_%d_Shaft' % i, (x, -.085, .285), (.012, .012, .36), 'timber', '08_DETAILS')
    box('Spear_%d_Head' % i, (x, -.085, .494), (.026, .015, .057), 'iron_light', '08_DETAILS')
box('Flag_Pole', (.054, .655, 1.295), (.016, .016, .36), 'timber', '07_HERALDRY')
box('Flag_Cap', (.054, .655, 1.482), (.029, .029, .029), 'iron_light', '07_HERALDRY')
obj = box('Rear_Banner', (-.071, .655, 1.36), (.23, .012, .155), 'banner', '07_HERALDRY')
obj['banner_center'], obj['banner_size'] = [-.071, .655, 1.36], [.23, .155]

root = bpy.data.objects.new(NAME + '_ROOT', None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_guardian_hall'
root['design'] = '4X map piece. Pointy-top hex radius 0.92 inside tile radius 1. Native placement scale 1.'
for o in parts:
    o.parent = root

# Validate containment against all six tile half-planes, including roof and spear tips.
maximum = 0
for o in parts:
    for v in o.data.vertices:
        for i in range(6):
            angle = math.radians(i * 60)
            maximum = max(maximum, v.co.x * math.cos(angle) + v.co.y * math.sin(angle))
assert maximum <= math.sqrt(3) / 2 + 1e-6, maximum

world = bpy.data.worlds.new(NAME + '_World')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.17, .21, .27, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .55
scene.world = world
target = Vector((0, 0, .62))
for label, position, energy, size, color in (
        ('Key', (-3, -4, 6), 450, 4, (1, .93, .83)),
        ('Fill', (4, -1, 3), 220, 3, (.81, .89, 1)),
        ('Rim', (0, 4, 5), 400, 3, (.83, .93, 1))):
    light = bpy.data.lights.new(NAME + '_' + label, 'AREA')
    light.energy, light.size, light.color = energy, size, color
    obj = bpy.data.objects.new(light.name, light)
    groups['09_STUDIO'].objects.link(obj)
    obj.location = position
    obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()
floor = mesh('Studio_Floor', [(-50, -50, -.006), (50, -50, -.006), (50, 50, -.006), (-50, 50, -.006)], [(0, 1, 2, 3)], 'studio', '09_STUDIO')
mat = bpy.data.materials.new(NAME + '_StudioFloor')
mat.use_nodes = True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.13, .16, .20, 1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 1
floor.data.materials.append(mat)
data = bpy.data.cameras.new(NAME + '_Camera')
camera = bpy.data.objects.new(data.name, data)
groups['09_STUDIO'].objects.link(camera)
camera.location = (2.6, -4, 3.3)
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type, camera.data.ortho_scale = 'ORTHO', 2.8
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples, scene.cycles.use_denoising = 16, True
scene.render.resolution_x = scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'
scene['preview_target'] = list(target)
scene['asset_basename'] = OUT.name
scene['density'] = 128
scene['paint_world_scale'] = 7
scene['scale_note'] = 'Native 4X map units, tile circumradius 1; placement scale 1.0. Symbolic architecture.'
scene['design_note'] = 'Hexagonal foundation and central hall, six-sided stepped roof, three corner towers, oblique walls, front wedge training court. Enlarged shield and banner for 4X readability.'
bpy.app.driver_namespace['guardian_hall'] = {'scene': scene, 'name': NAME, 'out': str(OUT), 'parts': parts, 'groups': groups,
    'root': root, 'camera': camera, 'target': target, 'density': 128, 'paint_world_scale': 7,
    'door_clearance': [.295, .475], 'scale_note': scene['scale_note'], 'design_note': scene['design_note']}
result = {'scene': NAME, 'editable_parts': len(parts), 'max_tile_half_plane': maximum, 'allowed': math.sqrt(3) / 2}
