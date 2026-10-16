"""Inspect the exported animated geometry, packed atlases and protected sources."""
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from orc_siege_assets import ROOT, OUT, WORK, SIEGE_ASSETS
from human_texture_glb import read_glb, image_bytes
from audit_elf_troops import accessor


def verify():
    protected = json.loads((WORK / 'protected_assets.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == sha for path, sha in protected.items())
    checks = []; signatures = []
    for row in SIEGE_ASSETS:
        folder = OUT / row['stem']
        report = json.loads((folder / (row['stem'] + '_report.json')).read_text(encoding='utf-8'))
        doc, binary = read_glb((folder / (row['stem'] + '.glb')).read_bytes())
        animations = doc.get('animations', [])
        assert len(animations) == (4 if row['tier'] == 0 else 5)
        assert {a['name'] for a in animations} == set(report['clips'])
        assert report['actions_created'] == len(animations)
        for animation in animations:
            duration = 0
            for sampler in animation['samplers']:
                times = accessor(doc, binary, sampler['input']).ravel()
                values = accessor(doc, binary, sampler['output'])
                assert np.isfinite(times).all() and np.isfinite(values).all()
                assert times.min() >= 0 and np.all(np.diff(times) > 0)
                duration = max(duration, float(times.max()))
            assert abs(duration - report['clips'][animation['name']]) < .0001
        assert len(report['ivory_parts']) == 2
        assert all('horn' in n.lower() or 'tusk' in n.lower() for n in report['ivory_parts'])
        assert not any('bone' in name.lower() for name in report['rig']['part_bones'])
        assert len(doc['skins']) == 1 and len(doc['meshes']) == 1
        assert len(doc['skins'][0]['joints']) == len(report['rig']['bones'])
        positions = []; triangles = 0
        for primitive in doc['meshes'][0]['primitives']:
            attrs = primitive['attributes']
            p = accessor(doc, binary, attrs['POSITION']); positions.append(p)
            normals = accessor(doc, binary, attrs['NORMAL'])
            uv = accessor(doc, binary, attrs['TEXCOORD_0'])
            weights = accessor(doc, binary, attrs['WEIGHTS_0'])
            joints = accessor(doc, binary, attrs['JOINTS_0'])
            assert np.isfinite(p).all() and np.isfinite(normals).all() and np.isfinite(uv).all()
            assert np.allclose(np.linalg.norm(normals, axis=1), 1, atol=.0001)
            assert (uv >= 0).all() and (uv <= 1).all()
            assert np.allclose(weights.sum(axis=1), 1) and np.all((weights > .0001).sum(axis=1) == 1)
            assert joints.max() < len(doc['skins'][0]['joints'])
            indices = accessor(doc, binary, primitive['indices']).ravel()
            assert indices.max() < len(p)
            tri = p[indices.reshape(-1, 3)]
            assert (np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1) > 1e-9).all()
            triangles += len(indices) // 3
        positions = np.concatenate(positions)
        assert triangles == report['geometry']['triangles']
        assert abs(positions[:, 1].min()) < .0001
        assert abs(positions[:, 1].max() - row['character_height_m']) < .0001
        assert report['geometry']['closed_meshes'] and report['geometry']['uv_in_bounds']
        assert len(doc['images']) == 1
        atlas = (folder / (row['stem'] + '_albedo.png')).read_bytes()
        assert image_bytes(doc, binary, doc['images'][0]) == atlas
        assert hashlib.sha256(atlas).hexdigest() == report['texture']['sha256']
        assert all(s['magFilter'] == 9728 for s in doc['samplers'])
        assert any(m['pbrMetallicRoughness'].get('metallicFactor', 1) > .5 for m in doc['materials'])
        assert any(m['pbrMetallicRoughness'].get('metallicFactor', 1) == 0 for m in doc['materials'])
        assert not any('camera' in node for node in doc['nodes'])
        wheels = sum(b.startswith('wheel_') for b in report['rig']['bones'])
        assert wheels == (6 if row['tier'] == 3 else 4)
        if row['tier'] == 3:
            names = report['rig']['part_bones']
            assert all(n in names for n in ('GreatIronBarrel_l', 'GreatIronBarrel_r',
                                           'RecoilTrack_l', 'RecoilTrack_r', 'FrontIronShield', 'RearWinchPlatform'))
            assert not any(any(token in n.lower() for token in ('throwing', 'torsion', 'boneskull',
                'bonebrow', 'bonecheek', 'bonenose', 'bonetooth', 'eyeslit', 'shieldtusk')) for n in names)
            assert positions[:, 0].max() - positions[:, 0].min() > 2.4
        signature = hashlib.sha256(positions.tobytes()).hexdigest(); signatures.append(signature)
        checks.append(dict(stem=row['stem'], status='PASS', triangles=triangles, wheels=wheels,
                           height_m=row['character_height_m'], clips=len(animations), geometry_signature=signature,
                           embedded_atlas_matches=True, finite_geometry=True, rigid_weights=True))
    assert len(set(signatures)) == 4
    result = dict(status='PASS', verified=4, clips=sum(a['clips'] for a in checks), protected_files=len(protected), assets=checks)
    (ROOT / 'docs/orc_siege_validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))


def document():
    dest = ROOT / 'docs/previews/orc_siege'; dest.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 18)
    large = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 25)
    for view in ('three_quarter', 'front', 'game_top', 'back', 'side'):
        gallery = Image.new('RGB', (4 * 420, 490), (40, 43, 36)); draw = ImageDraw.Draw(gallery)
        draw.text((16, 8), 'Cerco Orc — chifres e mecanismos animados', font=large, fill=(232, 225, 192))
        for row in SIEGE_ASSETS:
            image = Image.open(OUT / row['stem'] / 'previews' / (view + '.png')).convert('RGB')
            gallery.paste(image.resize((420, 420), Image.Resampling.LANCZOS), (row['tier'] * 420, 44))
            draw.text((row['tier'] * 420 + 10, 467), row['name'], font=font, fill=(232, 225, 192))
        gallery.save(dest / ('progression_' + view + '.jpg'), quality=94)
    comparison = Image.new('RGB', (4 * 350, 4 * 400), (40, 43, 36)); draw = ImageDraw.Draw(comparison)
    for band, (race, label, prefix, view) in enumerate([
            ('humans', 'Humanos', '', 'threequarter'), ('elves', 'Elfos', 'elf_', 'three_quarter'),
            ('dwarves', 'Anões', 'dwarf_', 'three_quarter'), ('orcs', 'Orcs', 'orc_', 'three_quarter')]):
        draw.text((12, band * 400 + 6), label, font=large, fill=(232, 225, 192))
        for row in SIEGE_ASSETS:
            stem = prefix + row['source_stem']
            path = ROOT / 'assets/generated' / race / stem / 'previews' / (view + '.png')
            image = Image.open(path).convert('RGB').resize((350, 350), Image.Resampling.LANCZOS)
            comparison.paste(image, (row['tier'] * 350, band * 400 + 40))
    comparison.save(dest / 'four_races_comparison.jpg', quality=94)


if __name__ == '__main__':
    verify(); document()
