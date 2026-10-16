"""Build the Warrior Hall in the live Blender MCP, in native 4X hex-tile units.
Preserves the Guardian Hall and all other scenes. No headless Blender.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
NAME = 'Warrior_Hall_Hex_V1'
OUT = ROOT / 'assets/generated/humans/buildings/warrior_hall_hex_v1'
OUT.mkdir(parents=True, exist_ok=True)
if NAME in bpy.data.scenes:
    raise RuntimeError('Warrior Hall scene already exists; preserve its edits.')
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION', '02_HALL', '03_ROOFS', '04_ARMORY',
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


def hexagon(radius, center=(0, 0)):
    return [(center[0] + radius * math.cos(math.radians(-30 + i * 60)),
             center[1] + radius * math.sin(math.radians(-30 + i * 60))) for i in range(6)]


def clipped_box(name, center, size, region, group, angle, side):
    # Miter the chevron exactly at X=0, so adjoining roof courses never
    # overlap coplanar faces (which creates black patches in the renderer).
    x, y, z = center
    length, width, height = size
    points = [(x + u * math.cos(angle) - v * math.sin(angle),
               y + u * math.sin(angle) + v * math.cos(angle))
              for u, v in ((-length/2, -width/2), (length/2, -width/2),
                           (length/2, width/2), (-length/2, width/2))]
    clipped = []
    for i, current in enumerate(points):
        previous = points[i - 1]
        cin, pin = current[0] * side >= 0, previous[0] * side >= 0
        if cin != pin:
            t = -previous[0] / (current[0] - previous[0])
            clipped.append((0, previous[1] + (current[1] - previous[1]) * t))
        if cin:
            clipped.append(current)
    return polygon_prism(name, clipped, z - height/2, z + height/2, region, group)


def wall(name, a, b, width, bottom, top, region='timber', group='05_COURTYARD'):
    d = Vector((b[0] - a[0], b[1] - a[1]))
    return box(name, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (bottom + top) / 2),
               (d.length, width, top - bottom), region, group, math.atan2(d.y, d.x))


def sword(name, center, length, angle=0, group='07_HERALDRY'):
    # Upright block blade, stepped tip, contrasting grip and wide guard.
    c = Vector(center)
    up = Vector((math.sin(angle), 0, math.cos(angle)))
    across = Vector((math.cos(angle), 0, -math.sin(angle)))

    def piece(label, height, width, extent, depth, region, y=0):
        mid = c + up * height + Vector((0, y, 0))
        verts = [tuple(mid + across * sx * width / 2 + Vector((0, sy * depth / 2, 0)) + up * sz * extent / 2)
                 for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
        return mesh(name + '_' + label, verts, CUBE, region, group)

    piece('Blade', .08 * length, .10 * length, .59 * length, .032 * length, 'iron_light')
    piece('Tip', .405 * length, .054 * length, .065 * length, .028 * length, 'iron_light')
    piece('Fuller', .08 * length, .023 * length, .53 * length, .009 * length, 'iron', -.021 * length)
    piece('Guard', -.245 * length, .34 * length, .058 * length, .07 * length, 'iron')
    piece('Grip', -.355 * length, .057 * length, .17 * length, .065 * length, 'timber')
    piece('Pommel', -.465 * length, .094 * length, .070 * length, .083 * length, 'iron_light')


def axe(name, center, length, group='04_ARMORY'):
    x, y, z = center
    box(name + '_Haft', (x, y, z), (.025, .027, length), 'timber', group)
    box(name + '_Head', (x + .026, y, z + length * .31), (.106, .033, .066), 'iron', group)
    box(name + '_Edge', (x + .083, y, z + length * .31), (.029, .039, .092), 'iron_light', group)
    box(name + '_Grip', (x, y, z - length * .29), (.034, .035, .095), 'door', group)


# Exact map hex orientation. Foundation leaves an 8% border inside its tile.
polygon_prism('Hex_Foundation', hexagon(.92), 0, .035, 'foundation', '01_FOUNDATION')
polygon_prism('Hex_Rim', hexagon(.90), .035, .060, 'cutstone', '01_FOUNDATION')
polygon_prism('Hex_Paving', hexagon(.85), .060, .075, 'paving', '01_FOUNDATION')

# Two oblique halls run along the back hex edges, forming a chevron.
# The frontage belongs to the training yard; there are no watchtowers.
for label, x, angle in (('Left', -.25, math.radians(30)), ('Right', .25, math.radians(150))):
    side = -1 if label == 'Left' else 1
    clipped_box('Wing_' + label + '_Foundation', (x, .355, .12), (.61, .29, .09), 'cutstone', '02_HALL', angle, side)
    clipped_box('Wing_' + label + '_Hall', (x, .355, .352), (.59, .28, .405), 'plaster', '02_HALL', angle, side)
    clipped_box('Wing_' + label + '_Sill', (x, .355, .20), (.605, .295, .065), 'stone', '02_HALL', angle, side)
    clipped_box('Wing_' + label + '_Beam', (x, .355, .557), (.61, .31, .055), 'timber', '02_HALL', angle, side)
    # Narrowing roof courses form voxel gables, with exposed timber under them.
    for j in range(5):
        clipped_box('Wing_' + label + '_Roof_%d' % j, (x, .355, .610 + j * .052),
            (.65, .36 - j * .066, .052), 'roof', '03_ROOFS', angle, side)
    clipped_box('Wing_' + label + '_Ridge', (x, .355, .867), (.665, .047, .026), 'roof_dark', '03_ROOFS', angle, side)
    along = Vector((math.cos(angle), math.sin(angle)))
    across = Vector((-math.sin(angle), math.cos(angle)))
    for i, u in enumerate((-.25, 0, .25)):
        for sign in (-1, 1):
            p = Vector((x, .355)) + along * u + across * sign * .142
            box('Wing_' + label + '_Post_%d_%d' % (i, sign), (p.x, p.y, .36),
                (.043, .045, .393), 'timber', angle=angle)
    # Rear vents and broad window shutters read at strategic camera distance.
    for i, u in enumerate((-.15, .15)):
        p = Vector((x, .355)) + along * u - across * .148
        box('Wing_' + label + '_Shutter_%d' % i, (p.x, p.y, .414),
            (.095, .018, .137), 'door', angle=angle)

# A central entrance pavilion joins the two wings and carries the weapon crest.
box('Entry_Foot', (0, .205, .14), (.35, .36, .13), 'cutstone')
box('Entry_Pavilion', (0, .205, .475), (.305, .315, .58), 'plaster')
for sign in (-1, 1):
    box('Entry_Post_' + str(sign), (sign * .144, .038, .48), (.049, .055, .60), 'timber')
box('Entry_CrossBeam', (0, .025, .775), (.365, .075, .065), 'timber')
box('Entry_Shadow', (0, .033, .346), (.248, .026, .47), 'shadow')
box('Entry_DoubleDoor', (0, .015, .336), (.221, .025, .45), 'door')
for z in (.205, .475):
    box('Entry_IronBand_' + str(z), (0, -.002, z), (.216, .011, .027), 'iron')
box('Entry_Seam', (0, -.004, .336), (.008, .012, .448), 'shadow')
for j in range(4):
    box('Pavilion_Roof_%d' % j, (0, .205, .836 + j * .058),
        (.41 - j * .088, .39 - j * .083, .058), 'roof', '03_ROOFS')
box('Pavilion_Cap', (0, .205, 1.054), (.096, .094, .030), 'iron', '03_ROOFS')

# Monumental wooden sign: the 4X silhouette is two blades, not a defensive shield.
box('Weapons_Crest_Backboard', (0, -.037, .875), (.41, .037, .32), 'door', '07_HERALDRY')
for sign in (-1, 1):
    sword('Crest_Sword_' + str(sign), (0, -.068 - (sign + 1) * .012, .866), .60,
          math.radians(sign * 38))

# A low hexagonal sparring court, open at the front: modest, not the mastery arena.
court_center = (0, -.295)
polygon_prism('Drill_Hex_Border', hexagon(.45, court_center), .075, .095, 'door', '05_COURTYARD')
polygon_prism('Drill_Sand', hexagon(.414, court_center), .095, .105, 'sand', '05_COURTYARD')
for sign in (-1, 1):
    polygon_prism('Duel_Position_' + str(sign), hexagon(.085, (sign * .17, -.295)),
                  .105, .111, 'formation', '06_TRAINING')
    box('Duel_Line_' + str(sign), (sign * .17, -.295, .115), (.066, .012, .008), 'cutstone', '06_TRAINING')
polygon_prism('Entry_Path', [(-.078, -.66), (0, -.80), (.078, -.66), (.078, -.51), (-.078, -.51)],
              .075, .084, 'paving', '05_COURTYARD')

# Angled timber fences follow the front tile edges, rather than boxing off the tile.
for sign in (-1, 1):
    a, b = (sign * .695, -.32), (sign * .25, -.65)
    for j in range(4):
        t = j / 3
        px, py = a[0] * (1-t) + b[0] * t, a[1] * (1-t) + b[1] * t
        box('Fence_Post_%d_%d' % (sign, j), (px, py, .207), (.052, .052, .264), 'timber', '05_COURTYARD')
        box('Fence_Cap_%d_%d' % (sign, j), (px, py, .344), (.066, .066, .018), 'iron', '05_COURTYARD')
    for z in (.163, .276):
        wall('Fence_Rail_%d_%s' % (sign, z), a, b, .033, z - .019, z + .019)

# Straw cutting dummies, one left and one right, free of defensive shields.
for sign in (-1, 1):
    x, y = sign * .535, -.20
    box('Dummy_Foot_' + str(sign), (x, y, .096), (.125, .13, .04), 'timber', '06_TRAINING')
    box('Dummy_Post_' + str(sign), (x, y, .24), (.035, .035, .25), 'timber', '06_TRAINING')
    box('Dummy_Body_' + str(sign), (x, y, .285), (.095, .068, .155), 'straw', '06_TRAINING')
    box('Dummy_Arms_' + str(sign), (x, y, .32), (.205, .033, .035), 'timber', '06_TRAINING')
    box('Dummy_Head_' + str(sign), (x, y, .405), (.070, .066, .074), 'straw', '06_TRAINING')
    box('Dummy_Belt_' + str(sign), (x, y - .041, .257), (.098, .014, .024), 'door', '06_TRAINING')

# Axe rack and sword rack: represent the base troop and the two evolutions.
for label, cx in (('Axes', -.43), ('Swords', .43)):
    for offset in (-.12, .12):
        box('Rack_' + label + '_Post_' + str(offset), (cx + offset, .00, .27), (.027, .038, .38), 'timber', '04_ARMORY')
    for z in (.17, .355):
        box('Rack_' + label + '_Rail_' + str(z), (cx, .00, z), (.285, .038, .034), 'timber', '04_ARMORY')
    for i in range(3):
        if label == 'Axes':
            axe('Practice_Axe_%d' % i, (cx - .088 + i * .082, -.032, .26), .295)
        else:
            sword('Practice_Sword_%d' % i, (cx - .08 + i * .08, -.032, .275), .345, group='04_ARMORY')

# Small maintenance forge beside the hall; its chimney balances the weapon sign.
box('Forge_Block', (-.64, .145, .20), (.205, .21, .245), 'stone', '08_DETAILS')
box('Forge_Fire_Shadow', (-.64, .029, .207), (.145, .021, .115), 'shadow', '08_DETAILS')
box('Forge_Coals', (-.64, .015, .172), (.116, .020, .033), 'glow', '08_DETAILS')
box('Forge_Hood', (-.64, .145, .358), (.228, .232, .065), 'iron', '08_DETAILS')
box('Forge_Chimney', (-.64, .19, .66), (.09, .094, .54), 'stone', '08_DETAILS')
box('Forge_Chimney_Cap', (-.64, .19, .945), (.129, .134, .04), 'iron', '08_DETAILS')
box('Forge_Chimney_Mouth', (-.64, .19, .968), (.066, .071, .008), 'shadow', '08_DETAILS')
box('Anvil_Stand', (-.625, -.025, .117), (.115, .098, .085), 'timber', '08_DETAILS')
box('Anvil_Foot', (-.625, -.025, .168), (.118, .090, .032), 'iron', '08_DETAILS')
box('Anvil_Waist', (-.625, -.025, .205), (.058, .047, .047), 'iron', '08_DETAILS')
box('Anvil_Face', (-.625, -.025, .242), (.175, .085, .029), 'iron_light', '08_DETAILS')

box('Banner_Pole', (.55, .34, .89), (.018, .018, .77), 'timber', '07_HERALDRY')
box('Banner_Cap', (.55, .34, 1.285), (.032, .032, .032), 'iron_light', '07_HERALDRY')
obj = box('Warrior_Banner', (.432, .34, 1.17), (.225, .012, .172), 'banner', '07_HERALDRY')
obj['banner_center'], obj['banner_size'], obj['heraldry'] = [.432, .34, 1.17], [.225, .172], 'crossed_blades'
for sign in (-1, 1):
    box('Door_Lantern_' + str(sign), (sign * .18, -.012, .565), (.032, .036, .060), 'glow', '08_DETAILS')
    box('Door_Lantern_Cap_' + str(sign), (sign * .18, -.012, .608), (.048, .050, .026), 'iron', '08_DETAILS')

root = bpy.data.objects.new(NAME + '_ROOT', None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_warrior_hall'
root['design'] = 'Warrior training hall: hex-first 4X map architecture, tile radius 1, native scale 1.'
for o in parts:
    o.parent = root
maximum = max(v.co.x * math.cos(math.radians(i * 60)) + v.co.y * math.sin(math.radians(i * 60))
              for o in parts for v in o.data.vertices for i in range(6))
assert maximum <= math.sqrt(3) / 2 + 1e-6, maximum

# Same neutral render studio as the Guardian Hall, so previews are comparable.
studio_code = (ROOT / 'tools/art_pipeline/guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0, 0, .48]
scene['asset_basename'], scene['density'], scene['paint_world_scale'] = OUT.name, 128, 7
scene['display_name'] = 'Salão de Armas'
scene['trains'] = ['v2_unit_warrior', 'v2_unit_swordsman', 'v2_unit_weapon_master']
scene['excludes'] = ['v2_legendary_blade_hero']
scene['scale_note'] = 'Native 4X map units, tile radius 1; model_scale_multiplier 1.0. Symbolic architecture.'
scene['design_note'] = 'Hex foundation; chevron timber halls and stepped gable roofs at the rear. Open hex sparring yard, straw cutting dummies, axe/sword racks, small forge and oversized crossed sword crest.'
bpy.app.driver_namespace['guardian_hall'] = {'scene': scene, 'name': NAME, 'out': str(OUT), 'parts': parts, 'groups': groups,
    'root': root, 'camera': camera, 'target': Vector(scene['preview_target']), 'density': 128, 'paint_world_scale': 7,
    'door_clearance': [.221, .45], 'scale_note': scene['scale_note'], 'design_note': scene['design_note']}
result = {'scene': NAME, 'parts': len(parts), 'max_tile_half_plane': maximum, 'allowed': math.sqrt(3)/2}
