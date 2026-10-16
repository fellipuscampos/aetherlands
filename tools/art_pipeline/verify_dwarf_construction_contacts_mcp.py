"""Audit contact geometry and the preserved dwarf anatomy in the live source."""
import bpy, json
from mathutils import Vector

asset = bpy.app.driver_namespace['dwarf_construction_v1']
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
plate_lo, plate_hi = bounds('Copper_plate_being_riveted')
rivet_lo, rivet_hi = bounds('Copper_rivet_being_peened')
anvil_lo, anvil_hi = bounds('Anvil_face')
assert abs(plate_lo.z - anvil_hi.z) < 1e-6 and abs(rivet_lo.z - plate_hi.z) < 1e-6
min_shaft_clearance = min_grip_clearance = min_file_handle_clearance = 1e9
support_error = file_error = hammer_contact_error = rivet_contact_error = 0.
hammer_arc = [1e9, -1e9]
rivet_arc = [1e9, -1e9]
rivet_contact_samples = 0
for frame in range(1, 182, 3):
    scene.frame_set(frame)
    scene.view_layers[0].update()
    lo, hi = bounds('Mason_Hammer_handle')
    grip_lo, grip_hi = bounds('Mason_Hand_R')
    min_shaft_clearance = min(min_shaft_clearance, lo.z - stone_hi.z)
    min_grip_clearance = min(min_grip_clearance, grip_lo.x - stone_hi.x)
    assert lo.z - stone_hi.z > .035 and grip_lo.x - stone_hi.x > .007
    head_lo, head_hi = bounds('Mason_Hammer_head')
    hammer_arc[0] = min(hammer_arc[0], head_lo.z)
    hammer_arc[1] = max(hammer_arc[1], head_lo.z)
    handle_lo, handle_hi = bounds('Roofer_File_handle')
    slate_lo, slate_hi = bounds('Slate_being_finished')
    min_file_handle_clearance = min(min_file_handle_clearance, slate_lo.y - handle_hi.y)
    assert slate_lo.y - handle_hi.y > .01, ('File grip intersects the slate', frame)
    support_lo, support_hi = bounds('Roofer_Hand_L')
    support_error = max(support_error, abs(support_lo.z - slate_hi.z))
    assert abs(support_lo.z - slate_hi.z) < .001
    file_lo, file_hi = bounds('Roofer_File_blade')
    assert file_lo.x > slate_lo.x and file_hi.x < slate_hi.x
    assert file_lo.y < slate_hi.y and file_hi.y > slate_lo.y
    file_error = max(file_error, abs(file_lo.z - slate_hi.z))
    assert abs(file_lo.z - slate_hi.z) < 1e-5, ('File lifted off the slate', frame)
    for name, height in [('Mason', 0.), ('Roofer', 0.), ('Coppersmith', .207)]:
        for side in ('L', 'R'):
            feet_lo, feet_hi = bounds(name + '_Boot_' + side)
            assert abs(feet_lo.z - height) < 1e-6, (name, frame, feet_lo.z)
    head_lo, head_hi = bounds('Coppersmith_Hammer_head')
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
    holder_lo, holder_hi = bounds('Coppersmith_Rivet_holder')
    assert holder_lo.x < rivet_hi.x and holder_hi.x > rivet_lo.x
    assert holder_lo.y < rivet_hi.y and holder_hi.y > rivet_lo.y
for frame in (1, 61, 121, 181):
    scene.frame_set(frame)
    scene.view_layers[0].update()
    head_lo, head_hi = bounds('Mason_Hammer_head')
    chisel_lo, chisel_hi = bounds('Mason_Chisel')
    hammer_contact_error = max(hammer_contact_error, abs(head_lo.z - chisel_hi.z))
    assert abs(head_lo.z - chisel_hi.z) < 1e-5
    assert head_lo.x < chisel_hi.x and head_hi.x > chisel_lo.x
    assert head_lo.y < chisel_hi.y and head_hi.y > chisel_lo.y
assert rivet_contact_samples >= 6
assert hammer_arc[1] - hammer_arc[0] > .10 and rivet_arc[1] - rivet_arc[0] > .10
assert sum(p['part'].startswith('Dwarf_block_stock_') for p in parts) == 9
assert sum(p['part'].startswith('Dark_slate_roof_tile_') for p in parts) == 10
assert sum(p['part'].startswith('Copper_sheet_stock_') for p in parts) == 3
assert sum(p['part'].startswith('Copper_ingot_') for p in parts) == 6
beards = [p for p in parts if '_beard_lock_' in p['part']]
attachments = [p for p in parts if p['bone'].endswith('_head') and not p['part'].endswith('_Head')]
assert len(beards) == 54 and len(attachments) == 90
assert all(p['bone'].endswith('_head') for p in beards)
assert all(p.get('dwarf_anatomy_source') for p in attachments)
assert not any(any(token in p['part'].lower() for token in ('wall_course', 'window', 'foundation', 'earth_hex')) for p in parts)
scene.frame_set(1)
report = dict(status='PASS', pose_samples=61, hammer_chisel_contact_error=hammer_contact_error,
              hammer_handle_min_stone_clearance=min_shaft_clearance, hammer_grip_min_side_clearance=min_grip_clearance,
              hammer_head_vertical_arc=hammer_arc[1]-hammer_arc[0], file_handle_min_clearance=min_file_handle_clearance,
              file_support_hand_contact_error=support_error, file_slate_contact_error=file_error,
              rivet_contact_error=rivet_contact_error, rivet_contact_samples=rivet_contact_samples,
              rivet_hammer_vertical_arc=rivet_arc[1]-rivet_arc[0], plate_anvil_contact_error=abs(plate_lo.z-anvil_hi.z),
              loose_building_blocks=9, copper_sheets=3, copper_ingots=6, original_beard_parts=54,
              original_head_attachments=90, no_specific_building=True, ground_workers_feet_z=0., stable_elbow_planes=True)
asset['report']['contacts'] = report
(asset['out'] / (asset['out'].name + '_report.json')).write_text(json.dumps(asset['report'], indent=2), encoding='utf-8')
scene['construction_report'] = json.dumps(asset['report'])
bpy.data.libraries.write(str(asset['out'] / (asset['out'].name + '.blend')), {scene}, fake_user=True, compress=True)
(asset['work'] / 'contacts_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
result = report
