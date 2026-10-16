"""Original orc meshes built in the open Blender through localhost MCP.

Uses established primitive, metric atlas and rigid skinning helpers with
mechanism-specific animation. Reference race meshes remain untouched.
"""
import json
import math
import sys
import time
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_elf_siege as g
from orc_siege_assets import OUT, WORK
from human_texture_glb import read_glb
from animate_orc_siege import animate

BASE_PAINT_TILE = g.paint_tile

PALETTE = {
    'wood': (103, 69, 43), 'heartwood': (67, 44, 31),
    'bronze': (127, 100, 63), 'gold': (149, 120, 73),
    'steel': (106, 111, 101), 'iron': (51, 57, 51),
    'rope': (161, 139, 99), 'leather': (91, 52, 32),
    'green': (86, 96, 53), 'ivory': (212, 205, 167),
    'stone': (112, 116, 101),
}
X, Y, Z = g.X, g.Y, g.Z
box, beam, cylinder, bone = g.box, g.beam, g.cylinder, g.bone


def horn(name, points, radius, material='ivory', group='body'):
    """Closed faceted, tapered tusk; broad root intersects its mounting plate."""
    points = [Vector(p) for p in points]
    sides = 6
    verts = []
    for i, p in enumerate(points[:-1]):
        direction = (points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]).normalized()
        u = direction.cross(X if abs(direction.x) < .8 else Y).normalized()
        v = direction.cross(u).normalized()
        r = radius * (1 - i / (len(points) - 1))
        verts.extend([tuple(p + r * (u * math.cos(j * math.tau / sides) + v * math.sin(j * math.tau / sides)))
                      for j in range(sides)])
    verts.append(tuple(points[-1]))
    faces = [tuple(reversed(range(sides)))]
    for i in range(len(points) - 2):
        for j in range(sides):
            a = i * sides + j; b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    start = (len(points) - 2) * sides
    faces.extend([(start + j, start + (j + 1) % sides, len(verts) - 1) for j in range(sides)])
    obj = g.geo.mesh(name, verts, faces, material, group)
    obj['region'] = material; obj['rig_bone'] = group
    return obj


def stone(name, at, size, group='weapon'):
    # Blender's previous sphere had its poles on Z. Preserve its full height
    # so normalising the machine retains the approved structure and scale.
    edge = size
    return box(name, at, (edge, edge, edge), 'stone', group)


def rivet(name, at, axis='X', group='body', heavy=False):
    return cylinder(name, at, .022 if not heavy else .032, .023,
                    'bronze', axis=axis, group=group, sides=6)


def wheel(side, label, at, r, heavy):
    group = 'wheel_' + side + '_' + label
    bone(group, at); c = Vector(at); s = 1 if side == 'l' else -1
    depth = .18 if not heavy else .23
    # Rough solid timber wheels, with visibly projecting iron tyres and hubs.
    cylinder('WheelTimber_' + group, c, r - .027, depth, 'wood', group=group, sides=10)
    cylinder('WheelTyre_' + group, c, r, depth + .025, 'iron', group=group,
             sides=10, inner=r - .028)
    face = c + X * s * (depth / 2 + .012)
    for i in range(-2, 3):
        zz = i * r * .32
        half = math.sqrt(max(0, (r - .055)**2 - zz**2))
        beam('WheelSeam_' + group + str(i), face + Vector((0, -half, zz)),
             face + Vector((0, half, zz)), .012, .010, 'heartwood', group)
    for i in range(4):
        angle = i * math.tau / 4 + math.pi / 4
        v = Vector((0, math.cos(angle), math.sin(angle)))
        beam('WheelIronBrace_' + group + str(i), face + v * .055,
             face + v * (r - .064), .038, .025, 'iron', group)
        rivet('WheelRivet_' + group + str(i), face + v * (r - .084) + X * s * .016, group=group)
    cylinder('WheelHub_' + group, c + X * s * .045, .105 if heavy else .081,
             depth + .12, 'heartwood', group=group, sides=8)
    cylinder('WheelHubCap_' + group, c + X * s * (depth / 2 + .115),
             .085 if heavy else .066, .035, 'bronze', group=group, sides=8)


def chassis(tier):
    w = [1.00, 1.14, 1.19, 2.05][tier]
    l = [1.45, 1.77, 1.79, 2.72][tier]
    r = [.29, .31, .34, .43][tier]
    z = r + .23
    for s in (-1, 1):
        box('BedRail_' + str(s), (s * w / 2, 0, z), (.14, l, .20), 'heartwood')
        box('IronRailEdge_' + str(s), (s * (w / 2 + .023), 0, z + .103), (.10, l, .025), 'iron')
    axles = [(-l * .35, 'front'), (l * .35, 'back')]
    if tier == 3: axles.insert(1, (0, 'middle'))
    for y, label in axles:
        cylinder('Axle_' + label, (0, y, r), .055, w + .46, 'iron')
        box('CrossBeam_' + label, (0, y, z), (w + .16, .17, .20), 'wood')
        for s, side in ((1, 'l'), (-1, 'r')):
            box('Bearing_' + side + label, (s * w * .45, y, r + .10), (.18, .20, .24), 'iron')
            wheel(side, label, (s * (w / 2 + .20), y, r), r, tier == 3)
    n = 8 if tier < 3 else 12
    for i in range(n):
        box('DeckPlank_' + str(i), (0, -l * .43 + i * l * .86 / (n - 1), z + .13),
            (w + .04, l * .83 / n, .065), 'wood' if i % 3 else 'heartwood')
    for s in (-1, 1):
        for y in (-l * .35, l * .35):
            box('BedStrap_' + str((s, y)), (s * (w / 2 + .078), y, z), (.033, .12, .235), 'iron')
            rivet('BedRivet_' + str((s, y)), (s * (w / 2 + .10), y, z + .057))
        beam('TowShaft_' + str(s), (s * w * .32, -l * .37, z),
             (s * w * .32, -l * .60, z - .055), .095, material='heartwood')
    return w, l, z


def lashed(name, at, width, group='body'):
    for i in range(3):
        box(name + str(i), Vector(at) + Z * (i - 1) * .028, (width, width + .008, .018), 'leather', group)


def catapult(w, l, z):
    pivot = Vector((0, -.14, z + .38)); bone('weapon', pivot)
    for s in (-1, 1):
        box('TorsionCheek_' + str(s), (s * .38, -.14, z + .25), (.15, .61, .46), 'wood')
        cylinder('TorsionBundle_' + str(s), (s * .24, -.14, z + .38), .12, .28, 'rope')
        cylinder('PivotCap_' + str(s), (s * .48, -.14, z + .38), .10, .048, 'iron')
        beam('StopBrace_' + str(s), (s * .39, -.54, z + .06), (s * .39, -.40, z + .87), .11)
        lashed('StopBinding_' + str(s), (s * .39, -.41, z + .77), .13)
    box('HidePaddedStop', (0, -.40, z + .87), (.91, .15, .17), 'leather')
    end = Vector((0, .34, 1.65))
    beam('ThrowingArm', pivot - Vector((0, .085, .11)), end, .145, .17, 'wood', 'weapon')
    cylinder('ThrowingAxle', pivot, .056, .99, 'iron', group='weapon')
    box('IronCupBase', end, (.29, .31, .068), 'iron', 'weapon')
    for s in (-1, 1):
        box('CupRim_' + str(s), end + Vector((s * .132, 0, .055)), (.043, .32, .12), 'iron', 'weapon')
    stone('LoadedBoulder', end + Z * .135, .235)
    g.winch((0, .57, z + .21), .64)
    beam('LoadCord', end - Z * .03, (0, .57, z + .285), .020,
         material='rope', group='weapon')['cable_ends'] = ('weapon', 'body')
    box('HideToolBag', (-.23, .19, z + .24), (.27, .31, .19), 'leather')
    box('BagClasp', (-.23, .025, z + .24), (.06, .025, .075), 'bronze')
    for s in (-1, 1):
        horn('FrontHorn_' + str(s), [(s * .43, -.52, z + .18),
             (s * .49, -.67, z + .37), (s * .48, -.72, z + .52)], .063)


def trebuchet(w, l, z):
    pivot = Vector((0, -.13, 1.53)); bone('weapon', pivot)
    for s in (-1, 1):
        for y, label in ((-.71, 'Front'), (.65, 'Back')):
            beam('AFrame_' + label + str(s), (s * .43, y, z + .05), pivot + X * s * .43, .13, .15)
            box('FrameFoot_' + label + str(s), (s * .43, y, z + .13), (.18, .20, .25), 'iron')
        box('IronPivotPlate_' + str(s), pivot + X * s * .45, (.09, .25, .25), 'iron')
        cylinder('PivotCap_' + str(s), pivot + X * s * .505, .063, .05, 'bronze')
        beam('SideCrossBrace_' + str(s), (s * .43, -.59, z + .23), (s * .43, .40, 1.13), .071, material='heartwood')
    cylinder('ArmAxle', pivot, .057, 1.08, 'iron', group='weapon')
    long = pivot + Vector((0, .71, .79)); short = pivot - Vector((0, .28, .31))
    beam('CounterweightArm', short, long, .122, .155, 'wood', 'weapon')
    bone('counterweight', short, 'weapon')
    for s in (-1, 1):
        beam('WeightHanger_' + str(s), short + X * s * .18,
             short + Vector((s * .18, 0, -.37)), .05, material='iron', group='counterweight')
    box('Counterweight', short - Z * .43, (.47, .36, .38), 'stone', 'counterweight')
    for s in (-1, 1):
        box('WeightIronBand_' + str(s), short + Vector((s * .17, 0, -.43)), (.058, .385, .41), 'iron', 'counterweight')
    pouch = long + Vector((0, .07, -.31)); bone('sling', long, 'weapon')
    for s in (-1, 1):
        beam('SlingCord_' + str(s), long + X * s * .082, pouch + X * s * .082,
             .020, material='rope', group='sling')
    box('SlingPouch', pouch, (.25, .25, .064), 'leather', 'sling')
    stone('SlingBoulder', pouch + Z * .13, .24, 'sling')
    box('SlingTrough', (0, .21, z + .20), (.31, 1.01, .086), 'heartwood')
    g.winch((0, .69, z + .28), .73)
    box('HideFrontApron', (0, -.82, z + .03), (.76, .037, .27), 'leather')
    for s in (-1, 1):
        box('ApronIronClasp_' + str(s), (s * .29, -.847, z + .08), (.12, .035, .22), 'iron')
        rivet('ApronClaspRivet_' + str(s), (s * .29, -.872, z + .14), 'Y')
        horn('FrontHorn_' + str(s), [(s * .43, -.71, z + .18),
             (s * .50, -.84, z + .38), (s * .49, -.92, z + .56)], .067)


def bombard(w, l, z):
    pivot = Vector((0, -.10, 1.17)); bone('weapon', pivot)
    for s in (-1, 1):
        box('GunCheek_' + str(s), (s * .37, -.11, z + .40), (.20, .83, .45), 'heartwood')
        cylinder('Trunnion_' + str(s), pivot + X * s * .37, .095, .28, 'iron')
        cylinder('TrunnionCap_' + str(s), pivot + X * s * .52, .114, .045, 'bronze')
        box('FlankIronGuard_' + str(s), (s * .60, -.04, z + .23), (.057, 1.12, .39), 'iron')
        for i, yy in enumerate((-.42, -.12, .18, .43)):
            rivet('GuardRivet_' + str((s, i)), (s * .636, yy, z + .33))
    a = Vector((0, .50, 1.03)); b = Vector((0, -.88, 1.38))
    gun = g.geo.barrel('IronBombardBarrel', a, b, .295, 'iron')
    gun['rig_bone'] = 'weapon'; gun['region'] = 'iron'; gun['future_bone'] = 'weapon'
    axis = (b - a).normalized()
    for i, t in enumerate((.11, .43, .91, 1.38)):
        band = cylinder('BarrelIronBand_' + str(i), a + axis * t, .324, .105,
                        'steel', axis='Z', group='weapon', inner=.291)
        band.rotation_euler = gun.rotation_euler
    cylinder('Breech', a - axis * .028, .295, .072, 'iron', axis='Z', group='weapon').rotation_euler = gun.rotation_euler
    box('FusePan', (0, .34, 1.34), (.067, .12, .05), 'bronze', 'weapon')
    box('RecoilSlide', (0, .13, z + .20), (.46, 1.19, .13), 'iron')
    box('RecoilShoe', (0, .18, z + .285), (.43, .58, .059), 'steel', 'weapon')
    box('ElevationWedge', (0, .46, z + .36), (.39, .35, .18), 'wood')
    g.winch((.14, .74, z + .29), .44)
    box('PowderLocker', (-.29, .64, z + .25), (.29, .33, .30), 'heartwood')
    box('PowderHideLid', (-.29, .64, z + .405), (.31, .35, .04), 'leather')
    for s in (-1, 1):
        horn('MuzzleGuardTusk_' + str(s), [(s * .52, -.56, z + .32),
             (s * .56, -.66, z + .52), (s * .57, -.73, z + .63)], .047)


def colossus(w, l, z):
    """Wide six-wheel battery with two independently mounted heavy bombards."""
    box('ArmoredGunDeck', (0, -.06, z + .22), (1.94, 1.94, .15), 'iron')
    box('CentralSpine', (0, -.13, z + .39), (.16, 1.91, .20), 'heartwood')
    for s, label in ((-1, 'r'), (1, 'l')):
        x = s * .47; group = 'weapon_' + label
        pivot = Vector((x, -.14, 1.35)); bone(group, pivot)
        a = Vector((x, .65, 1.20)); b = Vector((x, -1.12, 1.62))
        gun = g.geo.barrel('GreatIronBarrel_' + label, a, b, .31, 'iron')
        gun['rig_bone'] = group; gun['region'] = 'iron'; gun['future_bone'] = group
        axis = (b - a).normalized()
        for i, t in enumerate((.10, .48, 1.08, 1.78)):
            band = cylinder('GreatBarrelBand_' + label + str(i), a + axis * t,
                            .345, .11, 'steel', axis='Z', group=group, inner=.306)
            band.rotation_euler = gun.rotation_euler
        cylinder('GreatBreech_' + label, a - axis * .03, .309, .076,
                 'iron', axis='Z', group=group).rotation_euler = gun.rotation_euler
        box('FusePan_' + label, (x, .50, 1.51), (.075, .12, .055), 'bronze', group)
        for side in (-1, 1):
            xx = x + side * .32
            box('TrunnionCheek_' + label + str(side), (xx, -.05, 1.13), (.15, 1.13, .47), 'heartwood')
            cylinder('Trunnion_' + label + str(side), (xx, -.14, 1.35), .081, .22, 'iron')
            cylinder('TrunnionCap_' + label + str(side), (xx + side * .125, -.14, 1.35),
                     .104, .037, 'bronze')
            box('CheekIronStrap_' + label + str(side), (xx, .31, 1.12), (.175, .085, .49), 'iron')
        box('RecoilTrack_' + label, (x, -.09, z + .36), (.43, 1.69, .10), 'steel')
        box('RecoilShoe_' + label, (x, .16, z + .43), (.39, .72, .06), 'iron', group)
        box('ElevationWedge_' + label, (x, .54, z + .55), (.32, .34, .21), 'wood')
        box('RearRecoilStop_' + label, (x, .80, z + .46), (.46, .16, .24), 'iron')
    # Low iron armour and paired orc horns; no skull emblem or bone plates.
    box('FrontIronShield', (0, -1.22, z + .26), (1.96, .095, .44), 'iron')
    for i, x in enumerate((-.76, -.38, 0, .38, .76)):
        for zz in (z + .15, z + .37):
            rivet('FrontShieldRivet_' + str((i, zz)), (x, -1.275, zz), 'Y', heavy=True)
    for s in (-1, 1):
        box('FlankIronGuard_' + str(s), (s * 1.075, .01, z + .20), (.070, 2.14, .47), 'iron')
        for i, yy in enumerate((-.84, -.42, 0, .42, .84)):
            for zz in (z + .08, z + .32):
                rivet('FlankGuardRivet_' + str((s, i, zz)), (s * 1.115, yy, zz), heavy=True)
        box('RearPowderLocker_' + str(s), (s * .69, 1.05, z + .41), (.40, .35, .34), 'heartwood')
        box('PowderHideLid_' + str(s), (s * .69, 1.05, z + .595), (.42, .37, .042), 'leather')
        box('LockerIronLatch_' + str(s), (s * .69, 1.247, z + .42), (.09, .026, .20), 'iron')
        horn('SiegeHorn_' + str(s), [(s * .89, -1.19, z + .43),
             (s * 1.00, -1.29, z + .66), (s * .98, -1.36, z + .86)], .090)
    box('RearWinchPlatform', (0, 1.04, z + .30), (.65, .45, .12), 'wood')
    g.winch((0, 1.08, z + .52), .53, gold=True)
    for i, x in enumerate((-.28, 0, .28)):
        box('StoredSquareShot_' + str(i), (x, -.98, z + .31), (.18, .18, .18), 'stone')


def paint_tile(obj, face, w, h, row):
    tile = BASE_PAINT_TILE(obj, face, w, h, row)
    if obj.get('bore_faces_start') is not None and face.index >= obj['bore_faces_start']:
        tile[:] = np.array((24, 27, 23)) / 255
    return tile


def materials(folder, stem):
    """Use the freshly painted image even when this asset is already open."""
    images_before = set(bpy.data.images)
    previous = g.geo.paint_tile
    try:
        g.geo.paint_tile = paint_tile
        atlas = g.geo.pack_and_paint(folder, stem)
    finally: g.geo.paint_tile = previous
    images = set(bpy.data.images) - images_before
    assert len(images) == 1
    image = images.pop()
    palette_materials = {}
    for region in sorted({obj['surface'] for obj in g.PARTS}):
        mat = bpy.data.materials.new(stem + '_' + region); mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        metal = region in ('bronze', 'gold', 'steel', 'iron')
        shader.inputs['Metallic'].default_value = .72 if metal else 0
        shader.inputs['Roughness'].default_value = .55 if metal else .92
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = image; tex.interpolation = 'Closest'
        mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
        palette_materials[region] = mat
    for obj in g.PARTS:
        obj.data.materials.clear(); obj.data.materials.append(palette_materials[obj['surface']])
    return atlas


def export_animated(row, scene, parts, rig, root, folder):
    def progress(stage):
        with (WORK / (row['stem'] + '_export.log')).open('a', encoding='utf-8') as log:
            log.write(str(time.time()) + ' ' + stage + '\n')
    progress('consolidate_mesh_data')
    collection = bpy.data.collections.new('ORC_SIEGE_EXPORT_TEMP')
    scene.collection.children.link(collection)
    vertices = []; faces = []; face_materials = []; uv_values = []; smooth = []
    materials = []; groups = {}
    for obj in parts:
        assert np.allclose(np.array(obj.matrix_world), np.eye(4))
        offset = len(vertices)
        vertices.extend(tuple(v.co) for v in obj.data.vertices)
        local_materials = []
        for mat in obj.data.materials:
            if mat not in materials: materials.append(mat)
            local_materials.append(materials.index(mat))
        uv = obj.data.uv_layers.active.data
        for face in obj.data.polygons:
            faces.append(tuple(offset + i for i in face.vertices))
            face_materials.append(local_materials[face.material_index])
            smooth.append(face.use_smooth)
            for li in face.loop_indices: uv_values.extend(uv[li].uv)
        for vertex in obj.data.vertices:
            assert len(vertex.groups) == 1 and abs(vertex.groups[0].weight - 1) < .00001
            name = obj.vertex_groups[vertex.groups[0].group].name
            groups.setdefault(name, []).append(offset + vertex.index)
    mesh_data = bpy.data.meshes.new(row['stem'] + '_ExportMesh')
    mesh_data.from_pydata(vertices, [], faces); mesh_data.update()
    for mat in materials: mesh_data.materials.append(mat)
    for face, material, shading in zip(mesh_data.polygons, face_materials, smooth):
        face.material_index = material; face.use_smooth = shading
    mesh_data.uv_layers.new(name='UVMap').data.foreach_set('uv', uv_values)
    model = bpy.data.objects.new(row['stem'] + '_Model', mesh_data)
    collection.objects.link(model); model.parent = rig
    for name, indices in groups.items(): model.vertex_groups.new(name=name).add(indices, 1, 'REPLACE')
    modifier = model.modifiers.new('Orc_Rigid_Machinery', 'ARMATURE'); modifier.object = rig
    progress('select_export')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (model, rig, root): obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    try:
        progress('export_glb')
        bpy.ops.export_scene.gltf(filepath=str(folder / (row['stem'] + '.glb')),
            export_format='GLB', use_selection=True, use_active_scene=True,
            export_animations=True, export_animation_mode='NLA_TRACKS',
            export_anim_slide_to_zero=True, export_force_sampling=True,
            export_frame_range=False, export_skins=True, export_def_bones=False,
            export_yup=True, export_cameras=False, export_lights=False)
    finally:
        mesh_data = model.data
        bpy.data.objects.remove(model, do_unlink=True)
        if not mesh_data.users: bpy.data.meshes.remove(mesh_data)
        bpy.data.collections.remove(collection)
    doc = read_glb((folder / (row['stem'] + '.glb')).read_bytes())[0]
    assert len(doc.get('animations', [])) == (4 if row['tier'] == 0 else 5)
    progress('complete')
    return doc


def build(row):
    if bpy.context.screen and bpy.context.screen.is_animation_playing:
        bpy.ops.screen.animation_cancel(restore_frame=False)
    actions_before = set(bpy.data.actions)
    scene = bpy.data.scenes.new(row['stem'] + '_Scene')
    bpy.context.window.scene = scene; scene.render.fps = 24
    root = bpy.data.objects.new(row['stem'] + '_Root', None); scene.collection.objects.link(root)
    root['race'] = 'orc'; root['family'] = 'siege'; root['tier'] = row['tier']; root['design'] = row['design']
    g.ROW = row; g.PARTS = []; g.BONES = {}; g.SCALED = 1; g.SCENE = scene; g.ROOT_OBJ = root
    g.PALETTE = PALETTE
    g.geo.SCENE = scene; g.geo.ROOT_OBJ = root; g.geo.PARTS = g.PARTS; g.geo.BODY = {}; g.geo.ROW = row
    bone('root', parent=None); bone('body', parent='root')
    w, l, z = chassis(row['tier'])
    (catapult, trebuchet, bombard, colossus)[row['tier']](w, l, z)
    bpy.context.view_layer.update()
    high = max((obj.matrix_world @ v.co).z for obj in g.PARTS for v in obj.data.vertices)
    g.SCALED = row['character_height_m'] / high
    folder = OUT / row['stem']; folder.mkdir(parents=True, exist_ok=True)
    for obj in g.PARTS:
        obj.data.transform(Matrix.Scale(g.SCALED, 4)); obj.location *= g.SCALED
    atlas = materials(folder, row['stem'])
    for obj in g.PARTS:
        obj.data.transform(Matrix.Scale(1 / g.SCALED, 4)); obj.location /= g.SCALED
    rig = g.create_rig()
    for obj in g.PARTS: obj.modifiers[0].name = 'Orc_Rigid_Machinery'
    bpy.context.view_layer.update()
    geometry = g.geo.geometry_report()
    assert abs(geometry['bounds_min'][2]) < .0001
    assert abs(geometry['bounds_max'][2] - row['character_height_m']) < .0001
    g.studio(folder, geometry)
    # Extra profile view for inspecting pivots, cradle, guards and braces.
    center = (Vector(geometry['bounds_min']) + Vector(geometry['bounds_max'])) / 2
    camera = scene.camera; camera.location = center + Vector((12, 0, 3.8))
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(folder / 'previews/side.png'); bpy.ops.render.render(write_still=True)
    camera.location = center + Vector((6, -12, 6.4))
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    clips = animate(g, rig)
    motion = g.validate_motion(rig, clips)
    exported = export_animated(row, scene, g.PARTS, rig, root, folder)
    actual = {clip['name']: max(exported['accessors'][sampler['input']]['max'][0]
              for sampler in clip['samplers']) for clip in exported['animations']}
    assert actual.keys() == clips.keys()
    assert all(abs(actual[name] - clips[name]['seconds']) < .0001 for name in actual)
    assert len(set(bpy.data.actions) - actions_before) == len(clips)
    scene['description'] = row['name'] + ': orc horns, iron armour and animated rigid machinery.'
    for obj in g.PARTS:
        assert obj.animation_data is None
    bpy.data.libraries.write(str(folder / (row['stem'] + '.blend')), {scene},
                             path_remap='RELATIVE', fake_user=True, compress=True)
    report = row | dict(status='PASS', pipeline='Open Blender MCP localhost:9876',
        revision='orc_siege_animated_v3', geometry=geometry, texture=atlas,
        rig=dict(bones=list(g.BONES), rigid_weights=True,
                 part_bones={obj['part']: obj['rig_bone'] for obj in g.PARTS},
                 cord_endpoints_skinned=True), clips=actual, motion=motion,
        clip_metadata={name: {key: value for key, value in info.items() if key != 'action'}
                       for name, info in clips.items()}, actions_created=len(clips),
        ivory_parts=[obj['part'] for obj in g.PARTS if obj['surface'] == 'ivory'],
        material_palette=PALETTE, materials=len(exported['materials']),
        real_material_properties=True, crew=False,
        height_convention='Highest rest part: 1.80 m conventional / 2.00 m legendary',
        animation_contract='Same 19 clips and durations as human/elven siege; rigid mechanism motion, loop/recovery checked. Projectiles and combat effects remain gameplay-owned.')
    (folder / (row['stem'] + '_report.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    (folder / 'README.md').write_text(
        '# ' + row['name'] + '\n\nModelo original animado criado pelo MCP do Blender aberto.\n\n'
        'Fonte editável: `' + row['stem'] + '.blend`; jogo: `' + row['stem'] + '.glb`. '
        'Atlas pixelado embutido no GLB e empacotado no Blender; filtro nearest. '
        'Frente -Y no Blender / +Z no Godot. Origem no solo, escala aplicada.\n\n'
        'Altura: ' + str(row['character_height_m']) + ' m. Madeira escura, ferro, couro, corda e chifres orcs. '
        'Peças separadas no Blender; mesh consolidada na exportação. '
        'Animações: ' + ', '.join(actual) + '. Rodas e mecanismos com pesos rígidos. '
        'Idle/Walk em loop; ataques recuperam a posição de repouso. '
        'Disparos do colosso alternam os dois canhões.\n', encoding='utf-8')
    print('ORC_SIEGE_DONE', row['stem'], geometry['parts'], geometry['triangles'], len(actual), flush=True)
    return dict(stem=row['stem'], scene=scene.name, triangles=geometry['triangles'], clips=len(actual), status='PASS')
