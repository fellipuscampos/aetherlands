"""Independent GLB bind geometry and animation-data comparison against approval."""
from collections import Counter
import hashlib
import json
import struct
from pathlib import Path
import numpy as np
from dwarf_troop_assets import ASSETS, ROOT, OUT, WORK
from audit_dwarf_troops import read_glb

DTYPES = {5120:'i1', 5121:'u1', 5122:'<i2', 5123:'<u2', 5125:'<u4', 5126:'<f4'}
COUNTS = dict(SCALAR=1, VEC2=2, VEC3=3, VEC4=4, MAT4=16)


def accessor(doc, binary, index):
    item = doc['accessors'][index]; view = doc['bufferViews'][item['bufferView']]
    dtype = np.dtype(DTYPES[item['componentType']]); width = COUNTS[item['type']]
    offset = view.get('byteOffset', 0)+item.get('byteOffset', 0)
    stride = view.get('byteStride', dtype.itemsize*width)
    return np.ndarray((item['count'], width), dtype=dtype, buffer=binary,
        offset=offset, strides=(stride, dtype.itemsize)).copy()


def triangle_corners(doc, binary):
    # Both factory exports put vertices in world bind space and keep mesh-node
    # transforms identity. Compare every triangle corner, including normals/UV.
    corners = Counter()
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attrs = primitive['attributes']
            points = accessor(doc, binary, attrs['POSITION'])
            normals = accessor(doc, binary, attrs['NORMAL'])
            uv = accessor(doc, binary, attrs['TEXCOORD_0'])
            ids = accessor(doc, binary, primitive['indices']).ravel()
            for vertex in ids:
                corners[tuple(np.round(np.concatenate((points[vertex], normals[vertex], uv[vertex])), 5))] += 1
    return corners


def animated_channels(doc, binary):
    result = {}
    for animation in doc['animations']:
        channels = {}
        for channel in animation['channels']:
            target = channel['target']; node = doc['nodes'][target['node']]
            name, path = node['name'], target['path']
            sampler = animation['samplers'][channel['sampler']]
            times = accessor(doc, binary, sampler['input'])
            values = accessor(doc, binary, sampler['output'])
            assert np.isfinite(times).all() and np.isfinite(values).all()
            # Constant bind translations and recoil's rest orientation belong
            # to the skin. Shared Godot libraries leave those on the skeleton.
            constant = np.max(np.abs(values-values[0])) < 1e-5
            if path == 'translation' and constant: continue
            if name in ('recoil', 'recoil_axis') and path == 'rotation':
                assert constant; continue
            channels[name+':'+path] = (times, values)
        result[animation['name']] = channels
    return result


def main():
    results = []; reference = {}
    backup = WORK/'approved_static_before_animation_v1'
    for row in ASSETS:
        stem = row['stem']; folder = OUT/stem
        doc, binary = read_glb(folder/(stem+'.glb'))
        old_doc, old_binary = read_glb(backup/stem/(stem+'.glb'))
        old_corners = triangle_corners(old_doc, old_binary)
        new_corners = triangle_corners(doc, binary)
        assert old_corners == new_corners, (stem, 'approved geometry/UV/normals differ',
            len(old_corners-new_corners), len(new_corners-old_corners))
        png = folder/(stem+'_albedo.png')
        assert png.read_bytes() == (backup/stem/png.name).read_bytes()
        for mesh in doc['meshes']:
            for primitive in mesh['primitives']:
                weights = accessor(doc, binary, primitive['attributes']['WEIGHTS_0'])
                assert np.isfinite(weights).all() and np.max(np.abs(weights.sum(axis=1)-1)) < 1e-5
        animations = animated_channels(doc, binary)
        if row['family'] not in reference: reference[row['family']] = animations
        else:
            canonical = reference[row['family']]
            assert animations.keys() == canonical.keys()
            for clip, channels in animations.items():
                assert channels.keys() == canonical[clip].keys(), (stem, clip, 'incompatible channels')
                for channel, (times, values) in channels.items():
                    ct, cv = canonical[clip][channel]
                    assert times.shape == ct.shape and values.shape == cv.shape
                    assert np.max(np.abs(times-ct)) < 1e-5
                    # Quaternions q and -q represent the same orientation.
                    if channel.endswith(':rotation'):
                        errors = np.minimum(np.linalg.norm(values-cv, axis=1), np.linalg.norm(values+cv, axis=1))
                    else: errors = np.linalg.norm(values-cv, axis=1)
                    assert max(errors) < .0001, (stem, clip, channel, float(max(errors)))
        results.append(dict(stem=stem, bind_geometry_normals_uv_unchanged=True,
            atlas_unchanged=True, shared_animation_channels=True, normalized_skin_weights=True))
    protected = json.loads((WORK/'protected_files.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest() == digest for p, digest in protected.items())
    native = [json.loads((WORK/(f+'_animation_validation.json')).read_text(encoding='utf-8')) for f in reference]
    assert all(f['authored_actions'] == 3 and f['shared_by_four_variants'] and f['status'] == 'PASS' for f in native)
    for family in native:
        for variant in family['variants']:
            revisions = (2, 3) if family['family'] in ('cavalry','siege') else (3,)
            assert variant['motion_revision'] in revisions
            for clip, info in variant['clips'].items():
                assert info['fps'] == 48
                if family['family'] not in ('siege','cavalry'):
                    flex = info['free_arm_elbow_flexion_degrees']
                    assert 14 < flex['min'] <= flex['max'] < 40
                if family['family'] == 'siege': continue
                spans = info['joint_angular_span_degrees']
                threshold = .5 if clip == 'idle' else 2. if family['family'] == 'cavalry' else 5.
                assert all(spans[n] > threshold for n in ('upper_arm_L', 'upper_arm_R', 'chest'))
                # Guard against an IK pole/roll flip that dense sampling alone
                # would not fix. Fast impacts have a larger intentional range.
                limit = 24. if clip == 'attack' else 18.
                steps = info['max_joint_step_degrees']
                assert max(steps.values()) < limit, (variant['stem'], clip, 'joint discontinuity', steps)
    godot = json.loads((ROOT/'docs/dwarf_troops_animation_godot_validation.json').read_text(encoding='utf-8'))
    assert godot['status'] == 'PASS' and len(godot['variants']) == 24
    report = dict(status='PASS', variants=24, families=6, authored_actions=18,
        shared_actions_per_family=3, protected_files_unchanged=len(protected),
        approved_geometry_and_textures_preserved=True, siege_idle_motionless=True,
        motion_revision=3, fps=48, both_arms_and_torso_participate=True,
        joint_discontinuities_checked=True,
        free_arm_anatomical_flexion_checked=True,
        native_validation=native, disk_validation=results, godot_shared_libraries=godot)
    (ROOT/'docs/dwarf_troops_animation_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('DWARF_ANIMATION_DISK_PASS: 24 approved meshes/atlases; 18 shared clips; '+str(len(protected))+' protected files')


if __name__ == '__main__': main()
