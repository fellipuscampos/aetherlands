"""Audit actual deformed tool meshes against the stone/wood targets."""
import bpy,json
from mathutils import Vector
asset=bpy.app.driver_namespace['elf_construction_v1']; scene=asset['scene']; rig=asset['rig']; parts=asset['parts']
bpy.context.window.scene=scene; by={p['part']:p for p in parts}
inverse={b.name:b.matrix_local.inverted() for b in rig.data.bones}
def bounds(name):
    obj=by[name]
    transform=rig.pose.bones[obj['bone']].matrix@inverse[obj['bone']] if obj['bone'] else None
    points=[transform@v.co if transform else v.co for v in obj.data.vertices]
    return Vector(tuple(min(p[i] for p in points) for i in range(3))),Vector(tuple(max(p[i] for p in points) for i in range(3)))
max_contact_error=0.; min_handle_clearance=1e9; min_trough_clearance=1e9
work_min,work_max=bounds('Beam_being_planed')
max_trowel_error=0.; max_support_hand_error=0.
min_mallet_handle_clearance=1e9; min_mallet_grip_clearance=1e9
mallet_min_z=1e9; mallet_max_z=-1e9
for frame in range(1,182,3):
    scene.frame_set(frame); scene.view_layers[0].update()
    lo,hi=bounds('Woodworker_Handplane_sole')
    assert lo.x>work_min.x and hi.x<work_max.x and lo.y>work_min.y and hi.y<work_max.y,('Handplane outside timber surface',frame)
    max_trowel_error=max(max_trowel_error,abs(lo.z-work_max.z))
    assert abs(lo.z-work_max.z)<1e-5,('Handplane lost contact with timber',frame,lo.z)
    sawlo,sawhi=bounds('Carpenter_Saw_handle'); boardlo,boardhi=bounds('Board_being_sawn')
    clearance=boardlo.y-sawhi.y; min_handle_clearance=min(min_handle_clearance,clearance)
    assert clearance>.01,('Saw handle in plank',frame)
    supportlo,supporthi=bounds('Carpenter_Hand_L')
    max_support_hand_error=max(max_support_hand_error,abs(supportlo.z-boardhi.z))
    assert abs(supportlo.z-boardhi.z)<.001,('Off hand lost its grip on the board',frame)
    sawlo,sawhi=bounds('Carpenter_Saw_blade')
    assert sawlo.y<boardhi.y and sawhi.y>boardlo.y and sawlo.z<boardhi.z and sawhi.z>boardlo.z,('Saw lost wood contact',frame)
    stone_lo,stone_hi=bounds('Timber_being_mortised')
    handle_lo,handle_hi=bounds('Joiner_Hammer_handle')
    grip_lo,grip_hi=bounds('Joiner_Hand_R')
    head_lo,head_hi=bounds('Joiner_Hammer_head')
    min_mallet_handle_clearance=min(min_mallet_handle_clearance,handle_lo.z-stone_hi.z)
    min_mallet_grip_clearance=min(min_mallet_grip_clearance,grip_lo.x-stone_hi.x)
    mallet_min_z=min(mallet_min_z,head_lo.z); mallet_max_z=max(mallet_max_z,head_lo.z)
    assert handle_lo.z-stone_hi.z>.035,('Mallet shaft too close to stone',frame)
    assert grip_lo.x-stone_hi.x>.009,('Mallet grip over the stone',frame)
    for worker in ('Joiner','Carpenter'):
        for side in ('L','R'):
            footlo,foothi=bounds(worker+'_Boot_'+side)
            assert abs(footlo.z)<1e-6,('Worker floats above terrain',worker,side,frame)
    for side in ('L','R'):
        footlo,foothi=bounds('Woodworker_Boot_'+side); troughlo,troughhi=bounds('Joinery_tool_tray')
        clearance=footlo.x-troughhi.x; min_trough_clearance=min(min_trough_clearance,clearance)
        assert clearance>.10,('Trough in worker stance',frame)
for frame in (1,61,121,181):
    scene.frame_set(frame); scene.view_layers[0].update()
    hammerlo,hammerhi=bounds('Joiner_Hammer_head'); chisello,chiselhi=bounds('Joiner_Chisel')
    error=abs(hammerlo.z-chiselhi.z); max_contact_error=max(max_contact_error,error)
    assert error<1e-5,('Hammer missed chisel',frame,error)
    assert hammerlo.x<chiselhi.x and hammerhi.x>chisello.x and hammerlo.y<chiselhi.y and hammerhi.y>chisello.y
scene.frame_set(1)
assert mallet_max_z-mallet_min_z>.10,('Mallet has no clear raised strike',mallet_max_z-mallet_min_z)
block_stock=[p for p in parts if p['surface'] in ('stone','cutstone')]
assert len(block_stock)==6 and all(p['part'].startswith('Elven_block_stock_') and not p['bone'] for p in block_stock)
assert not any(p['part'].startswith('Wall_course_') or p['surface']=='mortar' for p in parts),'No specific masonry building'
assert sum(p['part'].startswith('Raw_timber_core_') for p in parts)==3
assert sum('_ElfEar_' in p['part'] for p in parts)==18
assert all(p['bone'].endswith('_head') for p in parts if '_ElfEar_' in p['part'])
report=dict(status='PASS',pose_samples=61,hammer_chisel_contact_error=max_contact_error,hammer_handle_min_timber_clearance=min_mallet_handle_clearance,hammer_grip_min_side_clearance=min_mallet_grip_clearance,hammer_head_vertical_arc=mallet_max_z-mallet_min_z,saw_handle_min_clearance=min_handle_clearance,peg_tray_min_foot_clearance=min_trough_clearance,handplane_contact_error=max_trowel_error,saw_support_hand_contact_error=max_support_hand_error,generic_timberwork=True,loose_building_blocks=len(block_stock),raw_timber_logs=3,no_built_masonry=True,original_ear_parts=18,ground_workers_feet_z=0.,stable_elbow_planes=asset['report']['animation']['stable_elbow_planes'])
asset['report']['contacts']=report
(asset['out']/(asset['out'].name+'_report.json')).write_text(json.dumps(asset['report'],indent=2),encoding='utf-8')
scene['construction_report']=json.dumps(asset['report'])
bpy.data.libraries.write(str(asset['out']/(asset['out'].name+'.blend')),{scene},fake_user=True,compress=True)
(asset['work']/'contacts_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result=report
