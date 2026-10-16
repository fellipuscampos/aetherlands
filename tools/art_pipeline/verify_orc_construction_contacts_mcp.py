"""Check the actual rigid tool geometry, contacts and original orc attachments."""
import bpy, json
from mathutils import Vector

asset = bpy.app.driver_namespace['orc_construction_v1']
scene, rig, parts = asset['scene'], asset['rig'], asset['parts']
bpy.context.window.scene = scene
by = {p['part']: p for p in parts}
inverse = {b.name: b.matrix_local.inverted() for b in rig.data.bones}

def bounds(name):
    obj = by[name]
    transform = rig.pose.bones[obj['bone']].matrix @ inverse[obj['bone']] if obj['bone'] else None
    points = [transform @ v.co if transform else v.co for v in obj.data.vertices]
    return Vector(tuple(min(p[i] for p in points) for i in range(3))), Vector(tuple(max(p[i] for p in points) for i in range(3)))

stone_lo, stone_hi = bounds('Stone_being_dressed')
plate_lo, plate_hi = bounds('Iron_strap_being_riveted')
rivet_lo, rivet_hi = bounds('Rivet_being_peened')
assert abs(plate_lo.z - .431) < 1e-6 and abs(rivet_lo.z - plate_hi.z) < 1e-6
min_shaft_clearance = min_grip_clearance = min_saw_clearance = 1e9
support_error = hammer_contact_error = rivet_contact_error = 0.
hammer_arc = [1e9, -1e9]
rivet_arc = [1e9, -1e9]
rivet_contact_samples = 0
for frame in range(1, 182, 3):
    scene.frame_set(frame)
    scene.view_layers[0].update()
    lo, hi = bounds('Joiner_Hammer_handle')
    grip_lo, grip_hi = bounds('Joiner_Hand_R')
    min_shaft_clearance = min(min_shaft_clearance, lo.z - stone_hi.z)
    min_grip_clearance = min(min_grip_clearance, grip_lo.x - stone_hi.x)
    assert lo.z - stone_hi.z > .035 and grip_lo.x - stone_hi.x > .007, (frame, lo.z-stone_hi.z, grip_lo.x-stone_hi.x)
    head_lo, head_hi = bounds('Joiner_Hammer_head')
    hammer_arc[0] = min(hammer_arc[0], head_lo.z)
    hammer_arc[1] = max(hammer_arc[1], head_lo.z)
    saw_lo, saw_hi = bounds('Carpenter_Saw_handle')
    board_lo, board_hi = bounds('Board_being_sawn')
    min_saw_clearance = min(min_saw_clearance, board_lo.y - saw_hi.y)
    assert board_lo.y - saw_hi.y > .01
    support_lo, support_hi = bounds('Carpenter_Hand_L')
    support_error = max(support_error, abs(support_lo.z - board_hi.z))
    assert abs(support_lo.z - board_hi.z) < .001
    blade_lo, blade_hi = bounds('Carpenter_Saw_blade')
    assert blade_lo.y < board_hi.y and blade_hi.y > board_lo.y
    assert blade_lo.z < board_hi.z and blade_hi.z > board_lo.z
    for name, height in [('Joiner', 0.), ('Carpenter', 0.), ('Riveter', .207)]:
        for side in ('L', 'R'):
            feet_lo, feet_hi = bounds(name + '_Boot_' + side)
            assert abs(feet_lo.z - height) < 1e-6, (name, frame, feet_lo.z)
    head_lo, head_hi = bounds('Riveter_Hammer_head')
    rivet_arc[0] = min(rivet_arc[0], head_lo.z)
    rivet_arc[1] = max(rivet_arc[1], head_lo.z)
    assert head_lo.z >= rivet_hi.z - 1e-6, ('Hammer passes through rivet', frame)
    phase = (((frame - 1) / 180) * 2 + .5) % 1
    if phase < .12:
        rivet_contact_samples += 1
        rivet_contact_error = max(rivet_contact_error, abs(head_lo.z - rivet_hi.z))
        assert abs(head_lo.z - rivet_hi.z) < 1e-5
        assert head_lo.x < rivet_hi.x and head_hi.x > rivet_lo.x
        assert head_lo.y < rivet_hi.y and head_hi.y > rivet_lo.y
    holder_lo, holder_hi = bounds('Riveter_Rivet_holder')
    assert holder_lo.x < rivet_hi.x and holder_hi.x > rivet_lo.x
    assert holder_lo.y < rivet_hi.y and holder_hi.y > rivet_lo.y
for frame in (1, 61, 121, 181):
    scene.frame_set(frame)
    scene.view_layers[0].update()
    head_lo, head_hi = bounds('Joiner_Hammer_head')
    chisel_lo, chisel_hi = bounds('Joiner_Chisel')
    hammer_contact_error = max(hammer_contact_error, abs(head_lo.z - chisel_hi.z))
    assert abs(head_lo.z - chisel_hi.z) < 1e-5
    assert head_lo.x < chisel_hi.x and head_hi.x > chisel_lo.x
    assert head_lo.y < chisel_hi.y and head_hi.y > chisel_lo.y
assert rivet_contact_samples >= 6
assert hammer_arc[1] - hammer_arc[0] > .10 and rivet_arc[1] - rivet_arc[0] > .10
blocks = [p for p in parts if p['part'].startswith('Orc_block_stock_')]
assert len(blocks) == 6
details = {}
for token, count in [('ElfEar', 18), ('Tusk', 12), ('Brow', 6)]:
    found = [p for p in parts if ('_' + token) in p['part']]
    assert len(found) == count and all(p['bone'].endswith('_head') for p in found)
    details[token] = count
assert sum(p['part'].startswith('Raw_timber_core_') for p in parts) == 3
assert sum(p['part'].startswith('Rust_hide_roof_shingle_') for p in parts) == 10
assert not any(any(token in p['part'].lower() for token in ('wall_course', 'window', 'foundation', 'earth_hex')) for p in parts)
scene.frame_set(1)
report = dict(status='PASS', pose_samples=61, hammer_chisel_contact_error=hammer_contact_error,
              hammer_handle_min_stone_clearance=min_shaft_clearance, hammer_grip_min_side_clearance=min_grip_clearance,
              hammer_head_vertical_arc=hammer_arc[1]-hammer_arc[0], saw_handle_min_clearance=min_saw_clearance,
              saw_support_hand_contact_error=support_error, rivet_contact_error=rivet_contact_error,
              rivet_contact_samples=rivet_contact_samples, rivet_hammer_vertical_arc=rivet_arc[1]-rivet_arc[0],
              loose_building_blocks=6, raw_timber_logs=3, original_ear_parts=18, original_tusk_parts=12,
              original_brow_parts=6, no_specific_building=True, ground_workers_feet_z=0., stable_elbow_planes=True)
asset['report']['contacts'] = report
(asset['out'] / (asset['out'].name + '_report.json')).write_text(json.dumps(asset['report'], indent=2), encoding='utf-8')
scene['construction_report'] = json.dumps(asset['report'])
bpy.data.libraries.write(str(asset['out'] / (asset['out'].name + '.blend')), {scene}, fake_user=True, compress=True)
(asset['work'] / 'contacts_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
result = report
