"""Build the Guardian Hall through the running Blender MCP, preserving other scenes.

Real meters, Z up, front -Y. Editable cuboids and extruded stepped shield contours;
no round primitives, bevels, downloaded assets or hero/mastery decoration.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
NAME = 'Guardian_Hall_V1'
OUT = ROOT / 'assets/generated/humans/buildings/guardian_hall_v1'
OUT.mkdir(parents=True, exist_ok=True)
if NAME in bpy.data.scenes:
    raise RuntimeError('Guardian Hall already exists. Preserve edits; use its saved scene.')
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
groups = {}
for label in ('01_FOUNDATION', '02_HALL', '03_ROOFS', '04_WATCHTOWER',
              '05_COURTYARD', '06_TRAINING', '07_HERALDRY', '08_DETAILS', '09_STUDIO'):
    collection = bpy.data.collections.new(NAME + '_' + label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
FACES = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
         (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]


def mesh(name, vertices, faces, region, group, up=(0, 0, 1)):
    data = bpy.data.meshes.new(NAME + '_' + name + '_Mesh')
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(NAME + '_' + name, data)
    groups[group].objects.link(obj)
    obj['part'] = name
    obj['region'] = region
    obj['paint_up'] = list(up)
    for polygon in data.polygons:
        polygon.use_smooth = False
    if group != '09_STUDIO':
        parts.append(obj)
    return obj


def box(name, center, size, region='stone', group='02_HALL'):
    cx, cy, cz = center
    sx, sy, sz = (value / 2 for value in size)
    vertices = [(cx + x * sx, cy + y * sy, cz + z * sz)
                for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]
    return mesh(name, vertices, FACES, region, group)


def beam(name, start, end, width, depth, region='timber', group='08_DETAILS'):
    a, b = Vector(start), Vector(end)
    axis = (b - a).normalized()
    u = Vector((0, 1, 0)).cross(axis)
    if u.length < 0.001:
        u = Vector((1, 0, 0))
    u.normalize()
    v = axis.cross(u).normalized()
    vertices = [tuple(c + u * x * width / 2 + v * y * depth / 2)
                for c in (a, b) for y in (-1, 1) for x in (-1, 1)]
    return mesh(name, vertices, FACES, region, group, tuple(axis))


def shield(name, center, width, height, group='07_HERALDRY'):
    # A single solid stepped wood panel, a watertight extruded iron frame,
    # and a square boss. The panel is painted with the Squire's blue band.
    outline = [(-.28, .5), (.28, .5), (.28, .4), (.42, .4), (.42, .24),
               (.5, .24), (.5, -.24), (.42, -.24), (.42, -.4), (.28, -.4),
               (.28, -.5), (-.28, -.5), (-.28, -.4), (-.42, -.4),
               (-.42, -.24), (-.5, -.24), (-.5, .24), (-.42, .24),
               (-.42, .4), (-.28, .4)]
    cx, cy, cz = center
    n = len(outline)
    verts = [(cx + x * width * .84, cy + d, cz + z * height * .84)
             for d in (-.055, .035) for x, z in outline]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    panel = mesh(name + '_Wood', verts, faces, 'shield', group)
    panel['shield_center'] = list(center)
    panel['shield_size'] = [width * .84, height * .84]
    verts = [(cx + x * width * scale, cy + d, cz + z * height * scale)
             for d in (-.085, .045) for scale in (1.0, .84) for x, z in outline]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces += [(i, j, j + n, i + n),
                  (i + 2 * n, i + 3 * n, j + 3 * n, j + 2 * n),
                  (i, i + 2 * n, j + 2 * n, j),
                  (i + n, j + n, j + 3 * n, i + 3 * n)]
    mesh(name + '_IronRim', verts, faces, 'iron', group)
    box(name + '_Boss', (cx, cy - .12, cz),
        (width * .20, .12, height * .19), 'iron_light', group)
    if width > 1:
        for x in (-.30, .30):
            for z in (-.29, .29):
                box(name + '_Rivet_' + str(x) + '_' + str(z),
                    (cx + x * width, cy - .064, cz + z * height),
                    (.05, .025, .05), 'iron_light', group)


def stepped_roof(name, cx, cy, width, depth, eaves, levels,
                 run=.38, rise=.23, axis='X'):
    # Horizontal courses narrow upward. Outer blue strips cover a timber core;
    # each course is an editable box, with geometric overhangs and square eaves.
    for i in range(levels):
        span = width - 2 * run * i
        assert span > 2 * run
        z = eaves + i * rise
        if axis == 'X':
            box(name + '_Core_%02d' % i, (cx, cy, z + rise / 2),
                (span - .07, depth - .10, rise), 'timber', '03_ROOFS')
            for sign, side in ((-1, 'L'), (1, 'R')):
                box(name + '_BlueCourse_' + side + '_%02d' % i,
                    (cx + sign * (span / 2 - run / 2), cy, z + rise / 2 + .025),
                    (run + .025, depth, rise), 'roof', '03_ROOFS')
        else:
            box(name + '_Core_%02d' % i, (cx, cy, z + rise / 2),
                (depth - .10, span - .07, rise), 'timber', '03_ROOFS')
            for sign, side in ((-1, 'F'), (1, 'B')):
                box(name + '_BlueCourse_' + side + '_%02d' % i,
                    (cx, cy + sign * (span / 2 - run / 2), z + rise / 2 + .025),
                    (depth, run + .025, rise), 'roof', '03_ROOFS')
    span = width - 2 * run * levels
    capsize = (span + .10, depth + .10, .18) if axis == 'X' else (depth + .10, span + .10, .18)
    box(name + '_Ridge', (cx, cy, eaves + levels * rise + .09), capsize, 'roof_dark', '03_ROOFS')
    for sign in (-1, 1):
        pos = (cx, cy + sign * (depth / 2 + .055), eaves + levels * rise + .14) if axis == 'X' else (cx + sign * (depth / 2 + .055), cy, eaves + levels * rise + .14)
        box(name + '_RidgeEnd_' + str(sign), pos, (.24, .24, .26), 'iron', '03_ROOFS')


def slit(name, cx, cy, z, side='front', group='08_DETAILS'):
    if side == 'front':
        box(name + '_Shadow', (cx, cy, z), (.22, .028, .76), 'shadow', group)
        for sign in (-1, 1):
            box(name + '_Jamb_' + str(sign), (cx + sign * .20, cy - .025, z),
                (.17, .12, .92), 'cutstone', group)
        box(name + '_Lintel', (cx, cy - .04, z + .49), (.60, .18, .18), 'cutstone', group)
        box(name + '_Sill', (cx, cy - .07, z - .49), (.64, .24, .18), 'cutstone', group)
    else:
        box(name + '_Shadow', (cx, cy, z), (.028, .22, .76), 'shadow', group)
        for sign in (-1, 1):
            box(name + '_Jamb_' + str(sign), (cx + .025, cy + sign * .20, z),
                (.12, .17, .92), 'cutstone', group)
        box(name + '_Lintel', (cx + .04, cy, z + .49), (.18, .60, .18), 'cutstone', group)
        box(name + '_Sill', (cx + .07, cy, z - .49), (.24, .64, .18), 'cutstone', group)


# Low layered foundation with a broad, traversable central approach.
box('Foundation_Lower', (0, 0, .09), (9.8, 8.3, .18), 'foundation', '01_FOUNDATION')
box('Foundation_Upper', (0, 0, .25), (9.5, 8.0, .14), 'cutstone', '01_FOUNDATION')
for i, (y, z, depth) in enumerate(((-4.60, .04, .90), (-4.40, .12, .50), (-4.20, .24, .26))):
    box('Entry_Step_%d' % i, (0, y, z / 2), (2.80, depth, z), 'cutstone', '01_FOUNDATION')

# Main rear hall: thick real walls, clear 1.80 x 2.40 m door opening.
cx, cy = -.65, 2.25
box('Hall_BackWall', (cx, 3.55, 2.00), (5.90, .36, 3.36))
box('Hall_LeftWall', (-3.42, 2.16, 2.00), (.36, 2.42, 3.36))
box('Hall_RightWall', (2.12, 2.16, 2.00), (.36, 2.42, 3.36))
box('Hall_Front_Left', (-2.53, .95, 2.00), (2.14, .36, 3.36))
box('Hall_Front_Right', (1.32, .95, 2.00), (1.96, .36, 3.36))
box('Hall_Door_Header', (-.56, .95, 3.23), (1.80, .36, .90))
box('Hall_Interior_Floor', (cx, 2.24, .345), (5.20, 2.10, .05), 'paving')
for i in range(7):
    width = 5.90 - .76 * i
    for side, y in (('Front', .95), ('Back', 3.55)):
        box('Hall_Gable_' + side + '_%d' % i, (cx, y, 3.795 + i * .23),
            (width, .36, .23), 'plaster')
box('Hall_Eaves', (cx, 2.25, 3.68), (6.20, 3.10, .20), 'timber')
stepped_roof('HallRoof', cx, 2.25, 6.65, 3.70, 3.78, 8)

# Strong square buttresses, alternating large ashlar corner stones.
for x, label in ((-3.48, 'Left'), (2.15, 'Right')):
    for y, side in ((.95, 'Front'), (3.55, 'Rear')):
        for i, (width, z, height) in enumerate(((.74, .70, .76), (.60, 1.54, .92), (.46, 2.68, 1.36))):
            box('Hall_' + label + '_' + side + '_Buttress_%d' % i,
                (x, y, z), (width, .68 if i == 0 else .50, height), 'cutstone')
        box('Hall_' + label + '_' + side + '_Capital', (x, y, 3.42), (.64, .68, .14), 'cutstone')

# Portal: stone jambs, iron reinforced wood doors, raised voxel shield sign.
for sign in (-1, 1):
    box('Portal_Jamb_' + str(sign), (-.56 + sign * 1.00, .69, 1.58),
        (.24, .40, 2.52), 'cutstone')
box('Portal_Lintel', (-.56, .65, 2.90), (2.44, .46, .24), 'cutstone')
box('Portal_Door', (-.56, 1.13, 1.52), (1.78, .14, 2.38), 'door')
for x in (-1.04, -.08):
    for z in (.70, 1.55, 2.37):
        box('Door_Hinge_%s_%s' % (x, z), (x, 1.038, z), (.75, .042, .11), 'iron')
for x in (-.70, -.42):
    box('Door_Handle_' + str(x), (x, 1.005, 1.52), (.07, .06, .15), 'iron_light')
box('Heraldic_Backing', (-.65, .51, 3.93), (1.96, .16, 1.92), 'timber', '07_HERALDRY')
shield('Hall_Crest', (-.65, .34, 3.93), 1.54, 1.64)
for x, label in ((-2.46, 'L'), (1.22, 'R')):
    slit('Hall_Window_' + label, x, .749, 2.44)

# Left low armoury wing, L shape framing the sand yard.
box('Armoury_Body', (-3.69, -.50, 1.54), (1.65, 3.52, 2.44), 'stone')
box('Armoury_Eave', (-3.69, -.50, 2.78), (1.96, 3.84, .20), 'timber')
stepped_roof('ArmouryRoof', -3.69, -.50, 2.32, 3.98, 2.88, 3, run=.29, rise=.23)
for y in (-1.79, .77):
    box('Armoury_Corner_' + str(y), (-4.52, y, 1.48), (.26, .46, 2.32), 'cutstone')
for z in (.74, 2.40):
    box('Armoury_TimberBand_' + str(z), (-2.844, -.50, z), (.09, 3.18, .14), 'timber')
for y in (-1.65, .42):
    slit('Armoury_Slit_' + str(y), -2.835, y, 1.78, 'right')

# Square watchtower at rear right: compact garrison, not a legendary citadel.
box('Tower_Foot', (3.45, 2.39, .62), (2.80, 2.80, .60), 'foundation', '04_WATCHTOWER')
box('Tower_Core', (3.45, 2.39, 2.91), (2.38, 2.38, 4.00), 'stone', '04_WATCHTOWER')
for x in (2.27, 4.63):
    for y in (1.21, 3.57):
        for i in range(7):
            box('Tower_Quoin_%s_%s_%d' % (x, y, i), (x, y, 1.19 + i * .51),
                (.37 if i % 2 == 0 else .31, .31 if i % 2 == 0 else .37, .47),
                'cutstone', '04_WATCHTOWER')
box('Tower_Cornice', (3.45, 2.39, 4.94), (2.69, 2.69, .24), 'cutstone', '04_WATCHTOWER')
box('Tower_Deck', (3.45, 2.39, 5.11), (2.76, 2.76, .10), 'paving', '04_WATCHTOWER')
for sign in (-1, 1):
    box('Tower_Parapet_X_' + str(sign), (3.45 + sign * 1.24, 2.39, 5.31),
        (.28, 2.76, .30), 'stone', '04_WATCHTOWER')
    box('Tower_Parapet_Y_' + str(sign), (3.45, 2.39 + sign * 1.24, 5.31),
        (2.20, .28, .30), 'stone', '04_WATCHTOWER')
for x in (2.21, 3.45, 4.69):
    for y in (1.15, 3.63):
        box('Tower_Merlon_%s_%s' % (x, y), (x, y, 5.68), (.52, .44, .44), 'cutstone', '04_WATCHTOWER')
for x in (2.21, 4.69):
    box('Tower_SideMerlon_' + str(x), (x, 2.39, 5.68), (.44, .52, .44), 'cutstone', '04_WATCHTOWER')
slit('Tower_Front_Slit', 3.45, 1.178, 3.82, group='04_WATCHTOWER')
slit('Tower_Right_Slit', 4.662, 2.39, 3.82, 'right', '04_WATCHTOWER')
box('Tower_Front_Band', (3.45, 1.174, 2.56), (2.43, .08, .16), 'cutstone', '04_WATCHTOWER')
box('Tower_Right_Band', (4.665, 2.39, 2.56), (.08, 2.43, .16), 'cutstone', '04_WATCHTOWER')

# A small square pennant, with a stepped edge and embroidered pale shield.
box('Flag_Pole', (4.12, 2.99, 5.95), (.075, .075, 1.56), 'timber', '07_HERALDRY')
box('Flag_PoleCap', (4.12, 2.99, 6.76), (.14, .14, .14), 'iron', '07_HERALDRY')
box('Flag_Main', (3.60, 2.99, 6.35), (.98, .035, .61), 'banner', '07_HERALDRY')
box('Flag_Step', (3.045, 2.99, 6.435), (.13, .035, .44), 'banner', '07_HERALDRY')

# Low courtyard walls with a broad OPEN front gateway, keeping training visible.
box('Yard_Sand', (-.06, -1.02, .34), (5.38, 3.65, .04), 'sand', '05_COURTYARD')
box('Front_Wall_Left', (-2.86, -3.30, .83), (2.86, .40, 1.02), 'stone', '05_COURTYARD')
box('Front_Wall_Right', (2.86, -3.30, .83), (2.86, .40, 1.02), 'stone', '05_COURTYARD')
box('Yard_RightWall', (4.25, -.85, .83), (.40, 4.50, 1.02), 'stone', '05_COURTYARD')
for x in (-2.98, 2.98):
    box('Front_Wall_Coping_' + str(x), (x, -3.30, 1.39), (2.66, .56, .12), 'cutstone', '05_COURTYARD')
box('Side_Wall_Coping', (4.25, -.94, 1.39), (.56, 4.27, .12), 'cutstone', '05_COURTYARD')
for x in (-4.30, -1.43, 1.43, 4.30):
    box('Gate_Pier_' + str(x), (x, -3.30, 1.08), (.62, .64, 1.52), 'cutstone', '05_COURTYARD')
    box('Gate_Pier_Cap_' + str(x), (x, -3.30, 1.91), (.78, .78, .14), 'cutstone', '05_COURTYARD')
for x in (-3.47, -2.35, 2.35, 3.47):
    box('Front_Merlon_' + str(x), (x, -3.30, 1.64), (.45, .44, .38), 'cutstone', '05_COURTYARD')
for y in (-2.42, -1.31, -.20, .78):
    box('Side_Merlon_' + str(y), (4.25, y, 1.64), (.44, .45, .38), 'cutstone', '05_COURTYARD')

# Portal-to-yard stone path and discreet square formation markers.
box('Approach_Paving', (-.56, -.99, .371), (1.57, 3.88, .042), 'paving', '05_COURTYARD')
box('Entry_Threshold', (0, -3.63, .342), (2.24, .75, .042), 'paving', '05_COURTYARD')
for x in (.88, 1.87):
    for y in (-2.18, -1.28, -.38):
        box('Formation_Marker_%s_%s' % (x, y), (x, y, .371), (.45, .38, .022), 'formation', '06_TRAINING')

# Two unmistakable shield-bash training dummies and a defensive shield rack.
for i, (x, y) in enumerate(((-1.98, -1.63), (-1.98, -.29))):
    box('Dummy_Base_%d' % i, (x, y, .44), (.68, .68, .16), 'timber', '06_TRAINING')
    box('Dummy_Post_%d' % i, (x, y, 1.12), (.17, .17, 1.20), 'timber', '06_TRAINING')
    box('Dummy_Shoulders_%d' % i, (x, y, 1.45), (1.0, .20, .20), 'timber', '06_TRAINING')
    box('Dummy_Head_%d' % i, (x, y, 1.88), (.30, .30, .32), 'straw', '06_TRAINING')
    shield('Dummy_Shield_%d' % i, (x, y - .14, 1.19), .83, .90, '06_TRAINING')
    for sign in (-1, 1):
        beam('Dummy_Brace_%d_%d' % (i, sign), (x + sign * .26, y, .52),
             (x, y, .94), .10, .10, group='06_TRAINING')
for x in (2.69, 3.87):
    box('ShieldRack_Post_' + str(x), (x, -.24, 1.12), (.15, .15, 1.60), 'timber', '06_TRAINING')
    box('ShieldRack_Foot_' + str(x), (x, -.24, .40), (.35, .72, .16), 'timber', '06_TRAINING')
box('ShieldRack_Rail', (3.28, -.24, 1.68), (1.46, .15, .17), 'timber', '06_TRAINING')
for i, x in enumerate((2.92, 3.64)):
    shield('Rack_Shield_%d' % i, (x, -.38, 1.27), .61, .72, '06_TRAINING')

# Spear rack, spare supply crates, seating and restrained warm lanterns.
for x in (2.80, 3.82):
    box('SpearRack_Post_' + str(x), (x, .48, .91), (.13, .16, 1.18), 'timber', '06_TRAINING')
box('SpearRack_Rail', (3.31, .48, 1.34), (1.24, .17, .14), 'timber', '06_TRAINING')
for i in range(4):
    x = 2.95 + i * .25
    box('Spear_%d_Shaft' % i, (x, .41, 1.25), (.052, .052, 1.70), 'timber', '06_TRAINING')
    box('Spear_%d_Head' % i, (x, .41, 2.19), (.12, .055, .20), 'iron_light', '06_TRAINING')
    box('Spear_%d_Tip' % i, (x, .41, 2.32), (.060, .055, .06), 'iron_light', '06_TRAINING')
for i, (x, y, z, size) in enumerate(((3.24, -2.50, .64, .54), (3.81, -2.28, .60, .46), (3.24, -2.50, 1.16, .48))):
    box('Supply_Crate_%d' % i, (x, y, z), (size, size, size), 'crate', '08_DETAILS')
box('Bench_Seat', (1.36, .35, .79), (1.20, .42, .13), 'timber', '08_DETAILS')
for x in (.92, 1.80):
    box('Bench_Leg_' + str(x), (x, .35, .55), (.13, .32, .46), 'timber', '08_DETAILS')
for i, (x, y, z) in enumerate(((-1.95, .51, 2.22), (.84, .51, 2.22), (-1.43, -3.66, 1.27), (1.43, -3.66, 1.27))):
    box('Lantern_%d_Bracket' % i, (x, y + .09, z + .24), (.075, .36, .075), 'iron', '08_DETAILS')
    box('Lantern_%d_Glass' % i, (x, y, z), (.17, .17, .24), 'glow', '08_DETAILS')
    for sign in (-1, 1):
        box('Lantern_%d_Cap_%d' % (i, sign), (x, y, z + sign * .16), (.25, .25, .08), 'iron', '08_DETAILS')
    for sx in (-1, 1):
        for sy in (-1, 1):
            box('Lantern_%d_Frame_%d_%d' % (i, sx, sy), (x + sx * .095, y + sy * .095, z),
                (.025, .025, .25), 'iron', '08_DETAILS')

# Scene studio, excluded from GLB; other currently open scenes remain untouched.
studio = groups['09_STUDIO']
world = bpy.data.worlds.new(NAME + '_World')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.16, .20, .26, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .55
scene.world = world
target = Vector((0, -.20, 2.45))


def aim(obj):
    obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()


for label, pos, power, size, color in (
        ('Key', (-10, -12, 16), 2500, 9, (1, .89, .74)),
        ('Fill', (10, -5, 11), 1700, 8, (.78, .88, 1)),
        ('Rim', (2, 9, 14), 2400, 7, (.82, .90, 1))):
    data = bpy.data.lights.new(NAME + '_' + label, 'AREA')
    data.energy, data.size, data.color = power, size, color
    obj = bpy.data.objects.new(data.name, data)
    studio.objects.link(obj)
    obj.location = pos
    aim(obj)
floor = mesh('StudioGround', [(-200, -200, -.012), (200, -200, -.012),
                            (200, 200, -.012), (-200, 200, -.012)],
             [(0, 1, 2, 3)], 'studio', '09_STUDIO')
floor_material = bpy.data.materials.new(NAME + '_StudioFloor')
floor_material.diffuse_color = (.13, .16, .19, 1)
floor_material.use_nodes = True
floor_material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.13, .16, .19, 1)
floor_material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 1
floor.data.materials.append(floor_material)
data = bpy.data.cameras.new(NAME + '_Camera')
camera = bpy.data.objects.new(data.name, data)
studio.objects.link(camera)
camera.location = (12, -17, 13)
aim(camera)
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 15.5
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 1400
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'
root = bpy.data.objects.new(NAME + '_ROOT', None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_guardian_hall'
root['trains'] = 'Escudeiro, Guardiao, Sentinela; excludes Campeao Guardiao'
root['front'] = '-Y Blender / +Z glTF'
root['scale'] = 'Metric source, 1 Blender unit = 1 meter'
for obj in parts:
    obj.parent = root
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
            area.spaces.active.shading.type = 'MATERIAL'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene': scene, 'name': NAME, 'out': str(OUT), 'parts': parts,
    'groups': groups, 'root': root, 'target': target, 'camera': camera}
result = {'scene': NAME, 'parts': len(parts), 'out': str(OUT)}
