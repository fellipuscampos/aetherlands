"""Paint face UVs with pixel masonry, timber, blue roof and heraldry.
Density defaults to 64 px/m; native map pieces may override it.
Run inside the current Blender editor through blender_mcp_client.py.
"""
import bpy
import bmesh
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector

st = bpy.app.driver_namespace['guardian_hall']
scene, parts, NAME = st['scene'], st['parts'], st['name']
OUT = Path(st['out'])
PROJECT_ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
BASENAME = OUT.name
bpy.context.window.scene = scene
D, PAD = st.get('density', 64), 3
islands = []
for obj in parts:
    me = obj.data
    for poly in me.polygons:
        normal = poly.normal.normalized()
        up = Vector(obj['paint_up'])
        up -= normal * normal.dot(up)
        if up.length < .001:
            up = Vector((0, 1, 0)) - normal * normal.y
        if up.length < .001:
            up = Vector((1, 0, 0)) - normal * normal.x
        up.normalize()
        right = up.cross(normal).normalized()
        coords = [Vector((me.vertices[i].co.dot(right), me.vertices[i].co.dot(up))) for i in poly.vertices]
        lo = Vector((min(v.x for v in coords), min(v.y for v in coords)))
        coords = [co - lo for co in coords]
        anchor = me.vertices[poly.vertices[0]].co.copy()
        origin = anchor + right * (lo.x - anchor.dot(right)) + up * (lo.y - anchor.dot(up))
        islands.append({'obj': obj, 'poly': poly.index, 'coords': coords, 'origin': origin,
                        'right': right, 'up': up, 'normal': normal,
                        'w': max(1, math.ceil(max(v.x for v in coords) * D)),
                        'h': max(1, math.ceil(max(v.y for v in coords) * D))})


def pack(size):
    x = y = PAD
    row = 0
    for it in sorted(islands, key=lambda i: (-i['h'], -i['w'])):
        w, h = it['w'] + PAD * 2, it['h'] + PAD * 2
        if x + w > size - PAD:
            x = PAD
            y += row
            row = 0
        if y + h > size - PAD:
            return False
        it['x'], it['y'] = x + PAD, y + PAD
        x += w
        row = max(row, h)
    return True


SIZE = next(s for s in (512, 1024, 2048, 4096, 8192) if pack(s))
albedo = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
albedo[:] = (.25, .28, .32, 1)
emission = np.zeros_like(albedo)
emission[:, :, 3] = 1
PALETTE = {
    'stone': (131, 141, 145), 'cutstone': (172, 179, 174),
    'foundation': (93, 106, 113), 'plaster': (183, 176, 153),
    'timber': (100, 65, 40), 'door': (134, 91, 52),
    'crate': (137, 100, 62), 'shield': (151, 109, 64),
    'roof': (49, 79, 127), 'roof_dark': (37, 59, 95),
    'banner': (52, 83, 145), 'iron': (84, 98, 108),
    'iron_light': (151, 163, 173), 'shadow': (23, 31, 35),
    'sand': (157, 135, 94), 'paving': (126, 136, 135),
    'formation': (191, 177, 143), 'straw': (190, 161, 99), 'glow': (244, 172, 62)}
PALETTE.update({key: tuple(value) for key, value in scene.get('palette_overrides', {}).items()})
SOURCE_PAINT_CACHE = {}


def paint(it, index):
    h, w = it['h'], it['w']
    obj, reg, normal = it['obj'], it['obj']['region'], it['normal']
    xx, yy = np.meshgrid(np.arange(w), np.arange(h))
    # Points are projected in WORLD SPACE: masonry seams align between parts.
    points = np.array(it['origin'])[None, None, :] + (xx[:, :, None] + .5) / D * np.array(it['right']) + (yy[:, :, None] + .5) / D * np.array(it['up'])
    X, Y, Z = (points[:, :, axis] for axis in range(3))
    if obj.get('source_paint_atlas'):
        # Repaint approved props into the building atlas without losing their
        # original markings. Each planar quad maps affinely to its source UVs.
        path = obj['source_paint_atlas']
        if path not in SOURCE_PAINT_CACHE:
            source_image = bpy.data.images.load(path, check_existing=True)
            sw, sh = source_image.size
            pixels = np.empty(sw * sh * 4, dtype=np.float32)
            source_image.pixels.foreach_get(pixels)
            SOURCE_PAINT_CACHE[path] = pixels.reshape(sh, sw, 4)
        source_pixels = SOURCE_PAINT_CACHE[path]
        poly = obj.data.polygons[it['poly']]
        start = sum(len(p.vertices) * 2 for p in obj.data.polygons[:it['poly']])
        uvs = np.asarray(obj['source_paint_uvs'][start:start + len(poly.vertices) * 2]).reshape(-1, 2)
        positions = np.array([list(obj.data.vertices[v].co) + [1] for v in poly.vertices])
        coefficients = np.linalg.lstsq(positions, uvs, rcond=None)[0]
        sample_uvs = points @ coefficients[:3] + coefficients[3]
        sh, sw = source_pixels.shape[:2]
        sx = np.clip(np.floor(sample_uvs[:, :, 0] * sw).astype(int), 0, sw - 1)
        sy = np.clip(np.floor(sample_uvs[:, :, 1] * sh).astype(int), 0, sh - 1)
        return source_pixels[sy, sx, :3], np.zeros((h, w, 3), dtype=np.float32)
    U = X if abs(normal.y) > .6 else Y
    V = Z
    if abs(normal.z) > .6:
        U, V = X, Y
    world_scale = st.get('paint_world_scale', 1)
    U, V = U * world_scale, V * world_scale
    rng = np.random.default_rng(27011 + index)
    # Calm pixel clusters with sparse wear, instead of high contrast white noise.
    coarse = rng.integers(-5, 6, ((h + 2) // 3, (w + 2) // 3))
    noise = np.repeat(np.repeat(coarse, 3, axis=0), 3, axis=1)[:h, :w]
    fine = rng.integers(-2, 3, (h, w))
    c = np.zeros((h, w, 3), dtype=np.float32)
    c[:] = PALETTE[reg]
    c += (noise + fine)[:, :, None]
    e = np.zeros_like(c)

    def setcolor(mask, color):
        c[mask] = np.asarray(color) + fine[mask, None]

    def shift(mask, amount):
        c[mask] += amount

    if reg in ('stone', 'cutstone', 'foundation', 'paving'):
        bw, bh = ((.70, .36) if reg == 'stone' else
                  (.82, .48) if reg == 'foundation' else
                  (.49, .34) if reg == 'paving' else (.64, .42))
        row = np.floor(V / bh)
        column = np.floor((U + (row % 2) * bw / 2) / bw)
        fv, fu = (V / bh) % 1, ((U + (row % 2) * bw / 2) / bw) % 1
        variation = ((np.sin(row * 3.11 + column * 5.37) * 147.4) % 1 - .5) * 16
        c += variation[:, :, None]
        seam = (fv < .040) | (fu < .022)
        setcolor(seam, tuple(max(0, v - 33) for v in PALETTE[reg]))
        shift((fv >= .040) & (fv < .085) & ~seam, 12)
        shift((fu >= .022) & (fu < .047) & ~seam, 7)
        # Tiny chips confined to the bottom corners of individual blocks.
        shift((fu < .095) & (fv > .86) & (np.sin(column * 7 + row * 11) > .20), -17)
    elif reg == 'plaster':
        shift(((np.floor(U * 9) * 3 + np.floor(V * 9) * 7) % 29) == 0, -8)
    elif reg in ('timber', 'door', 'crate', 'shield'):
        # Long grain follows vertical posts, with crisp plank seams on doors.
        along, across = yy, xx
        grain = ((np.sin((across // 2) * 2.7 + np.floor(along / 18) * .9) * 44) % 1 - .5) * 12
        c += grain[:, :, None]
        shift((across % 11 == 0) & (along % 27 < 21), -15)
        edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
        if reg == 'timber':
            shift(edge < 1, -22)
            shift(edge == 1, 9)
        if reg == 'door':
            planks = ((X + 1.46) * 64) % 12
            setcolor(planks < 1, (76, 49, 29))
            shift((planks >= 1) & (planks < 2), 16)
            setcolor(abs(X + .56) < .018, (43, 33, 26))
        if reg == 'crate':
            setcolor((xx % 9) == 0, (87, 62, 36))
            rim = edge < 3
            setcolor(rim, (93, 63, 36))
            shift(edge == 3, 15)
            setcolor(((xx < 4) | (xx > w - 5)) & ((yy < 4) | (yy > h - 5)), (151, 155, 148))
        if reg == 'shield' and normal.y < -.6:
            sc, sz = obj['shield_center'], obj['shield_size']
            across = (X - sc[0]) / sz[0]
            plank = ((X - sc[0]) * 64) % 10
            setcolor(plank < 1, (103, 72, 40))
            setcolor(abs(across) < .17, (51, 81, 143))
            shift((abs(across) >= .145) & (abs(across) < .17), -14)
            for px in (-.30, .30):
                for pz in (-.29, .29):
                    setcolor((abs(across - px) < .022) & (abs((Z - sc[2]) / sz[1] - pz) < .022), (182, 186, 180))
    elif reg in ('roof', 'roof_dark'):
        # Smaller weathered blue slate shingles on the horizontal stepped roof.
        u, v = Y * world_scale, X * world_scale
        row = np.floor(v / .23)
        fu = ((u + (row % 2) * .15) / .30) % 1
        fv = (v / .23) % 1
        shift((fv < .08) | (fu < .05), -23)
        shift((fv >= .08) & (fv < .17), 17)
        c += (((np.sin(np.floor(u / .30) * 6.1 + row * 1.7) * 13) % 1 - .5) * 9)[:, :, None]
        if abs(normal.z) < .6:
            shift(np.ones((h, w), dtype=bool), -8)
            shift(yy > h - 2, 24)
    elif reg == 'banner':
        # Shield silhouette stitched onto both sides of the pennant.
        bc, bs = obj.get('banner_center', [3.57, 2.99, 6.35]), obj.get('banner_size', [.98, .61])
        fx, fz = (X - bc[0]) / bs[0], (Z - bc[2]) / bs[1]
        badge = ((abs(fx) < .14) & (fz > -.25) & (fz < .25)) | ((abs(fx) < .09) & (fz > -.35) & (fz <= -.25))
        if obj.get('heraldry') == 'crossed_blades':
            badge = (abs(abs(fx) - abs(fz) * .70) < .038) & (abs(fz) < .32)
        elif obj.get('heraldry') == 'arrow':
            badge = ((abs(fz) < .035) & (abs(fx) < .34)) | ((fx > .12) & (fx < .34) & (abs(fz) < (.34 - fx) * .70))
        elif obj.get('heraldry') == 'horseshoe':
            badge = ((abs(fx) > .11) & (abs(fx) < .22) & (fz > -.17) & (fz < .28)) | ((abs(fx) < .22) & (fz > -.26) & (fz < -.14))
        elif obj.get('heraldry') == 'dagger':
            badge = ((abs(fx) < .055) & (fz > -.06) & (fz < .24)) | ((fz >= .24) & (fz < .34) & (abs(fx) < (.34-fz)*.55)) | ((abs(fx) < .14) & (abs(fz+.09) < .035)) | ((abs(fx) < .035) & (fz > -.31) & (fz < -.09))
        elif obj.get('heraldry') == 'gear':
            badge = (((abs(fx) < .20) & (abs(fz) < .23)) | ((abs(fx) < .07) & (abs(fz) < .34)) | ((abs(fx) < .30) & (abs(fz) < .08))) & ~((abs(fx) < .075) & (abs(fz) < .085))
        setcolor(badge, (210, 212, 188))
        if obj.get('heraldry') not in ('crossed_blades', 'arrow', 'horseshoe', 'dagger', 'gear'):
            setcolor(badge & (abs(fx) < .026), (107, 133, 171))
        setcolor((abs(fz) > .43) | (fx > .45), (30, 53, 104))
    elif reg in ('iron', 'iron_light'):
        edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
        shift(edge < 1, -24)
        shift((yy > h - 3) & (edge >= 1), 20)
    elif reg == 'sand':
        shift(((np.floor(X * 12) * 13 + np.floor(Y * 12) * 11) % 73) == 0, -22)
    elif reg == 'formation':
        edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
        setcolor(edge < 2, (104, 94, 70))
        shift((xx > w // 2 - 1) & (xx < w // 2 + 1), -22)
    elif reg == 'straw':
        setcolor(((xx + yy // 5) % 4) == 0, (143, 115, 65))
        setcolor((yy // 3 % 5) == 0, (132, 101, 60))
    elif reg == 'glow':
        e[:] = (236, 125, 29)
        shift((xx > w / 3) & (xx < w * 2 / 3), 12)
    return np.clip(c / 255, 0, 1), np.clip(e / 255, 0, 1)


for index, it in enumerate(islands):
    colors, energy = paint(it, index)
    ox, oy, w, h = it['x'], it['y'], it['w'], it['h']
    albedo[oy - PAD:oy + h + PAD, ox - PAD:ox + w + PAD, :3] = np.pad(colors, ((PAD, PAD), (PAD, PAD), (0, 0)), mode='edge')
    emission[oy - PAD:oy + h + PAD, ox - PAD:ox + w + PAD, :3] = np.pad(energy, ((PAD, PAD), (PAD, PAD), (0, 0)), mode='edge')
images = []
for suffix, pixels in (('albedo', albedo), ('emission', emission)):
    im = bpy.data.images.new(NAME + '_' + suffix, width=SIZE, height=SIZE, alpha=True)
    im.colorspace_settings.name = 'sRGB'
    im.pixels.foreach_set(pixels.ravel())
    im.filepath_raw = str(OUT / (BASENAME + '_' + suffix + '.png'))
    im.file_format = 'PNG'
    im.save()
    im.pack()
    images.append(im)
mat = bpy.data.materials.new(NAME + '_PixelAtlas')
mat.use_nodes = True
bsdf = mat.node_tree.nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value = .89
bsdf.inputs['Metallic'].default_value = 0
bsdf.inputs['Specular IOR Level'].default_value = .25
bsdf.inputs['Emission Strength'].default_value = .85
for im, socket in zip(images, ('Base Color', 'Emission Color')):
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image, tex.interpolation, tex.extension = im, 'Closest', 'EXTEND'
    tex.label = socket
    mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs[socket])
for obj in parts:
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    if 'Metric_Pixel_UV' not in obj.data.uv_layers:
        obj.data.uv_layers.new(name='Metric_Pixel_UV')
    obj.data.uv_layers.active_index = obj.data.uv_layers.find('Metric_Pixel_UV')
    obj.data.uv_layers['Metric_Pixel_UV'].active_render = True
for it in islands:
    me = it['obj'].data
    uv = me.uv_layers['Metric_Pixel_UV'].data
    for li, co in zip(me.polygons[it['poly']].loop_indices, it['coords']):
        uv[li].uv = ((it['x'] + co.x * D) / SIZE, (it['y'] + co.y * D) / SIZE)

triangles = nonmanifold = 0
for obj in parts:
    me = obj.data
    me.calc_loop_triangles()
    triangles += len(me.loop_triangles)
    bm = bmesh.new()
    bm.from_mesh(me)
    nonmanifold += sum(not e.is_manifold for e in bm.edges)
    bm.free()
    assert all(p.area > 1e-9 and not p.use_smooth for p in me.polygons), obj.name
    assert not obj.modifiers, obj.name
assert nonmanifold == 0, nonmanifold
coordinates = [v.co for obj in parts for v in obj.data.vertices]
lo = [min(v[axis] for v in coordinates) for axis in range(3)]
hi = [max(v[axis] for v in coordinates) for axis in range(3)]
report = {
    'name': NAME, 'display_name': scene.get('display_name', 'Salão dos Guardiões'),
    'gameplay_building_id': st['root'].get('gameplay_building_id', 'v2_building_guardian_hall'),
    'trains': list(scene.get('trains', ['v2_unit_shieldbearer', 'v2_unit_guardian', 'v2_unit_sentinel'])),
    'excludes': list(scene.get('excludes', ['v2_legendary_guardian_champion'])),
    'pipeline': 'Blender 5.2 editor MCP localhost:9876',
    'integrated_in_game': ('"res://' + (OUT / (BASENAME + '.glb')).relative_to(PROJECT_ROOT).as_posix() + '"'
                           in (PROJECT_ROOT / scene.get('integration_source', 'scripts/data/BuildingDatabase.gd')).read_text(encoding='utf-8')
                           or '"' + BASENAME + '"' in (PROJECT_ROOT / 'scripts/data/BuildingArtCatalog.gd').read_text(encoding='utf-8')),
    'triangles': triangles,
    'editable_parts': len(parts), 'nonmanifold_edges': nonmanifold,
    'materials': 1, 'shade': 'Flat', 'bounds_blender_m': {'min': lo, 'max': hi},
    'dimensions_m': [hi[i] - lo[i] for i in range(3)],
    'origin': 'center of footprint on ground Z=0',
    'front': '-Y in Blender / +Z in glTF (Godot)',
    'scale': st.get('scale_note', '1 source unit = 1 meter; scale deliberately at placement for strategic map'),
    'texture': {'size': [SIZE, SIZE], 'filter': 'NEAREST',
                'density_px_per_meter': D, 'padding': PAD, 'unique_uv_islands': len(islands),
                'images': ['albedo', 'emission'], 'emission_strength': .85},
    'rig': False, 'animations': [],
    'design': st.get('design_note', 'Fortified training hall, stepped blue roofs, squared watchtower, open gateway, sand yard, shield dummies and formation markers.'),
    'door_clearance_m': list(st.get('door_clearance', [1.80, 2.40])),
    'notes': 'Studio and scale reference excluded from export. Separate editable source parts; consolidated game meshes by architectural group.'}
st.update({'islands': islands, 'size': SIZE, 'density': D, 'pad': PAD,
           'material': mat, 'images': images, 'report': report})
(OUT / (BASENAME + '_report.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
bpy.data.libraries.write(str(OUT / (BASENAME + '.blend')), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
result = {'triangles': triangles, 'parts': len(parts), 'atlas': SIZE,
          'dimensions_m': report['dimensions_m'], 'nonmanifold_edges': nonmanifold}
