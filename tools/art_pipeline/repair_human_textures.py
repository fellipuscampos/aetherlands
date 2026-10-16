"""Repair existing human UV atlases using their editable Blender face boundaries.

Run audit_human_textures.py in Blender first, then this script in regular Python.
Outputs are staged for inspection; --apply installs validated PNG/GLB files.
The original assets are retained under art_source/human_texture_repair/before.
"""
import argparse
import ast
import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image
from human_texture_style import VERSION, repair_surface
from human_texture_glb import read_glb, image_bytes, replace_images, verify_unchanged

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art_source/human_texture_repair'
ASSETS = ROOT / 'assets/generated/humans'
PIPE = Path(__file__).resolve().parent
ROGUES = {'rogue_v1', 'saboteur_v1', 'assassin_v1', 'shadow_master_v1'}


def palette_for(unit):
    source = PIPE / (('warrior' if unit in ROGUES else unit.removesuffix('_v1')) + '_paint_save.py')
    colors = {}
    for node in ast.parse(source.read_text(encoding='utf-8')).body:
        if not isinstance(node, ast.Assign):
            continue
        try:
            value = ast.literal_eval(node.value)
        except (ValueError, TypeError):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name):
                colors[target.id] = value
    if unit in ROGUES:
        colors.update(LEATHER=[(66,54,47),(76,63,54),(59,48,42)], LEATHER_DARK=(35,30,29),
                      LEATHER_HI=(99,82,67), GAMB=[(62,67,76),(72,77,86),(54,59,67)],
                      GAMB_SEAM=(37,42,49), GAMB_HI=(87,93,102),
                      CLOAK=[(39,44,57),(44,49,63),(33,37,49)],
                      ROYAL_CLOAK=[(35,40,57),(42,48,67),(29,33,48)],
                      BLADE=[(166,173,185),(181,188,201),(151,157,169)])
    return colors


def repair(row, apply):
    unit = row['unit']
    if row.get('legacy'):
        return {'unit': unit, 'status': 'reviewed_no_repair_needed',
                'reason': 'Original small tiled materials have no glove or trouser stroke artifacts.'}
    backup = WORK / 'before' / unit
    out = WORK / 'staged' / unit
    out.mkdir(parents=True, exist_ok=True)
    albedo = unit + '_albedo.png'
    old = Image.open(backup / albedo).convert('RGBA')
    new = old.copy()
    width, height = new.size
    pixels = new.load()
    original = old.load()
    occupied = {}
    colors = palette_for(unit)
    stats = {}
    for part in row['parts']:
        region = part['region']
        for face_index, coords in enumerate(part['faces']):
            x = round(min(u for u,v in coords) * width)
            y = round(min(v for u,v in coords) * height)
            w = max(1, math.ceil((max(u for u,v in coords)-min(u for u,v in coords))*width-0.0001))
            h = max(1, math.ceil((max(v for u,v in coords)-min(v for u,v in coords))*height-0.0001))
            box = (x-2, height-y-h-2, x+w+2, height-y+2)
            assert min(box) >= 0 and box[2] <= width and box[3] <= height, (unit, part['part'], box)
            tile = [[original[xx,yy][:3] for xx in range(box[0],box[2])] for yy in range(box[1],box[3])]
            fixed = repair_surface(tile, region, colors)
            count = 0
            for yy, values in enumerate(fixed, box[1]):
                for xx, rgb in enumerate(values, box[0]):
                    owner = (part['part'], face_index)
                    assert (xx, yy) not in occupied, (unit, owner, occupied.get((xx, yy)))
                    occupied[(xx,yy)] = owner
                    rgba = rgb + (original[xx,yy][3],)
                    count += rgba != original[xx,yy]
                    pixels[xx,yy] = rgba
            stats[region] = stats.get(region, 0) + count
    assert sum(stats.values()) > 0, unit
    features = {colors[k] for k in ('EYE_W','PUPIL','BROW','MOUTH','SKIN_SHADE') if k in colors}
    feature_pixels = 0
    for xx,yy in occupied:
        if original[xx,yy][:3] in features:
            assert pixels[xx,yy] == original[xx,yy], (unit,'facial feature changed',xx,yy)
            feature_pixels += 1
    new.save(out / albedo)
    assert Image.open(out / albedo).convert('RGBA').tobytes() == new.tobytes()
    raw = (backup / (unit+'.glb')).read_bytes()
    doc, binary = read_glb(raw)
    embedded = next(i for i in doc['images'] if i.get('name') == unit+'_albedo')
    assert image_bytes(doc,binary,embedded) == (backup / albedo).read_bytes(), unit
    patched = replace_images(raw, {unit+'_albedo': (out/albedo).read_bytes()})
    (out/(unit+'.glb')).write_bytes(patched)
    verification = verify_unchanged(raw, patched)
    for image in doc['images']:
        if image.get('name') == unit+'_emission':
            assert image_bytes(doc,binary,image) == (backup/(unit+'_emission.png')).read_bytes()
    if apply:
        for name in (albedo, unit+'.glb'):
            shutil.copy2(out/name, ASSETS/unit/name)
        # Godot extracts the embedded image using this stable filename.
        duplicate = ASSETS/unit/(unit+'_'+albedo)
        if duplicate.exists():
            shutil.copy2(out/albedo, duplicate)
    return {'unit': unit, 'status': 'applied' if apply else 'staged', 'size': [width,height],
            'changed_pixels_by_region': stats, 'changed_pixels': sum(stats.values()),
            'outside_uv_padding_unchanged': True, 'alpha_unchanged': True,
            'facial_feature_pixels_preserved': feature_pixels,
            'emission_unchanged': True, 'glb_validation': verification}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--units', nargs='+')
    args = parser.parse_args()
    rows = json.loads((WORK/'native_audit.json').read_text(encoding='utf-8'))
    results = []
    for row in rows:
        if args.units and row['unit'] not in args.units:
            continue
        result = repair(row, args.apply)
        results.append(result)
        print(row['unit'], result['status'], result.get('changed_pixels',0), flush=True)
    (WORK/'pixel_validation.json').write_text(json.dumps({'version': VERSION, 'units': results}, indent=2), encoding='utf-8')
