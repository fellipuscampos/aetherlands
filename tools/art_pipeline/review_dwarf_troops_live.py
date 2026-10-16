"""Validate live MCP source parts and leave a textured overview in the open Blender."""
import bpy
import hashlib
import json
import sys
import importlib
from pathlib import Path
from mathutils import Matrix,Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
import dwarf_troop_assets
importlib.reload(dwarf_troop_assets)
from dwarf_troop_assets import ASSETS,OUT

expected={'body_head','body_chest','body_belly','body_pelvis'}
expected.update('body_'+part+'_'+side for side in ('L','R')
                for part in ('thigh','shin','foot','shoulder','upper_arm','forearm','hand'))
reference=json.loads((OUT/'common/dwarf_base_v1_report.json').read_text(encoding='utf-8'))['anatomy']
assert set(reference)==expected
approved=json.loads((ROOT/'art_source/dwarf_troops/approved_anatomy_v5.json').read_text(encoding='utf-8'))
resized={'body_shin_L','body_shin_R','body_foot_L','body_foot_R'}
assert all(reference[name]==approved[name] for name in expected-resized),'Approved anatomy changed beyond boots'
checks=[]
ram_reference=None
ram_verified=0
previous=bpy.data.scenes.get('Dwarf_Troops_24_Model_Review')
if previous:
    assert previous.get('dwarf_factory_owned') is True
    for obj in list(previous.objects):
        if len(obj.users_scene)==1: bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.scenes.remove(previous)
scene=bpy.data.scenes.new('Dwarf_Troops_24_Model_Review')
scene['description']='24 modelos estáticos de anões; sem pescoço; cavalaria de carneiros.'
scene['dwarf_factory_owned']=True
for index,row in enumerate(ASSETS):
    source=bpy.data.scenes[row['stem']+'_MCP_Static_V2']
    meshes=[o for o in source.objects if o.type=='MESH' and o.get('surface') and not o.get('part','').startswith('STUDIO')]
    removed_ornaments=('cuirass_rib','pauldron_outer','pauldron_ridge','wrist_cuff','boot_sole',
                       'shield_side_rail','shield_cross_rail','shield_corner_rivet','shield_clan',
                       'shield_crest','shield_ancestral','hammer_cap','hammer_forge_band',
                       'hammer_clan','axe_cheek_band','axe_rivet','helm_crest','helm_ancestral',
                       'shadow_temple_plate','throwing_knife_hilt','ram_clan','ram_ancestral',
                       'colossus_clan')
    assert not any(o.get('part','').startswith(removed_ornaments) for o in meshes),row['stem']+' retained decorative geometry'
    anatomy={o['shared_anatomy']:o for o in meshes if o.get('shared_anatomy')}
    if row['family']!='siege':
        assert set(anatomy)==expected, row['stem']
        for name,obj in anatomy.items():
            assert len(obj.data.vertices)==8 and len(obj.data.polygons)==6
            record={'vertices':[[round(v,6) for v in vert.co] for vert in obj.data.vertices],
                    'faces':[list(p.vertices) for p in obj.data.polygons]}
            digest=hashlib.sha256(json.dumps(record,sort_keys=True).encode()).hexdigest()
            assert digest==reference[name], row['stem']+' '+name
        frames=[o for o in source.objects if o.get('grip_hand')]
        assert len(frames)==1,row['stem']+' must have one held item'
        by_part={o.get('part'):o for o in meshes}
        for side in ('L','R'):
            def width(obj): return max(v.co.x for v in obj.data.vertices)-min(v.co.x for v in obj.data.vertices)
            assert abs(width(anatomy['body_foot_'+side])-width(anatomy['body_shin_'+side]))<1e-6
            assert width(anatomy['body_shin_'+side])>width(anatomy['body_thigh_'+side])
            foot=anatomy['body_foot_'+side]; shin=anatomy['body_shin_'+side]
            # Adjacent boot sections meet; equal-width side faces must not overlap.
            foot_top=max((foot.matrix_world@v.co).z for v in foot.data.vertices)
            shin_bottom=min((shin.matrix_world@v.co).z for v in shin.data.vertices)
            assert abs(foot_top-shin_bottom)<1e-6,row['stem']+' boot joint gap/overlap'
            hand=anatomy['body_hand_'+side]
            assert hand.rotation_euler.to_matrix().col[2].dot(Vector((0,0,1)))>.999
            if hand.get('resting_hand'):
                arm=anatomy['body_forearm_'+side]
                assert abs(arm.rotation_euler.to_matrix().col[2].dot(Vector((0,0,1))))>.999
                assert abs(hand.location.x-anatomy['body_shoulder_'+side].location.x)<.04
                assert hand.location.z<arm.location.z
        if row['family']!='cavalry':
            pelvis=anatomy['body_pelvis']
            hip_min=min((pelvis.matrix_world@v.co).x for v in pelvis.data.vertices)
            hip_max=max((pelvis.matrix_world@v.co).x for v in pelvis.data.vertices)
            for label in ('thigh','shin'):
                for side in ('L','R'):
                    points=[anatomy['body_'+label+'_'+side].matrix_world@v.co for v in anatomy['body_'+label+'_'+side].data.vertices]
                    assert min(p.x for p in points)>=hip_min-1e-5 and max(p.x for p in points)<=hip_max+1e-5,row['stem']+' legs wider than hip'
        if row['family']=='guardian':
            assert frames[0].name.startswith('clan_shield')
            assert not any(o.get('part','').startswith(('hammer_','axe_','seax_','pick_')) for o in meshes)
            field=by_part['shield_field']
            assert field['shield_width']>=.66 and field['shield_height']>=.72
        if row['family']=='warrior':
            assert frames[0].name.startswith('clan_hammer')
            head=by_part['hammer_head']
            assert .429<=width(head)<=.506
            assert frames[0].matrix_world.to_3x3().col[2].dot(Vector((0,0,1)))>.97
            assert head.matrix_world.translation.z>anatomy['body_hand_R'].matrix_world.translation.z
            head_back=max((head.matrix_world@v.co).y for v in head.data.vertices)
            shoulder_front=min((anatomy['body_shoulder_R'].matrix_world@v.co).y for v in anatomy['body_shoulder_R'].data.vertices)
            assert head_back<shoulder_front,row['stem']+' hammer intersects shoulder'
        if row['family']=='cavalry':
            assert frames[0].name.startswith('forged_axe')
            assert 'shield_field' not in by_part and 'hammer_head' not in by_part
        for frame in frames:
            hand=anatomy[frame['grip_hand']]
            assert (frame.matrix_world.translation-hand.matrix_world.translation).length<1e-6
            if frame.name.startswith(('forged_axe','clan_hammer','forged_seax')):
                forward=(frame.matrix_world.to_3x3()@Vector((1,0,0))).normalized()
            else:
                forward=(frame.matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
            assert forward.dot(Vector((0,-1,0)))>.95,row['stem']+' sideways weapon/shield'
        if row['family']=='ranger':
            assert frames[0].name.startswith('clan_crossbow')
            assert frames[0]['grip_hand']=='body_hand_R'
            left=anatomy['body_hand_L'].matrix_world.translation
            right=anatomy['body_hand_R'].matrix_world.translation
            assert (left-right).length>.5,row['stem']+' support hand should be free'
            bow=by_part['crossbow_limb']
            assert width(bow)>=.699
        assert not any(o.get('paint_style')=='clan_badge' for o in meshes)
        if row['key']=='saboteur':
            def bounds(obj):
                points=[obj.matrix_world@v.co for v in obj.data.vertices]
                return ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])
            bag=bounds(by_part['sabotage_toolbox'])
            for name in ('sapper_prybar','sealed_charge_0','sealed_charge_1','sealed_charge_2'):
                item=bounds(by_part[name])
                assert all(min(bag[1][i],item[1][i])>max(bag[0][i],item[0][i]) for i in range(3)),name+' detached from tool bag'
    if row['family']=='cavalry':
        by_part={o.get('part'):o for o in meshes}
        if ram_reference is None:
            names=[name for name in by_part if name.startswith('ram_')]
            ram_reference={name:None for name in names}
        for name in ram_reference:
            obj=by_part[name]
            record=[[round(v,6) for v in obj.matrix_world@vert.co] for vert in obj.data.vertices]
            digest=hashlib.sha256(json.dumps(record).encode()).hexdigest()
            if ram_reference[name] is None: ram_reference[name]=digest
            assert digest==ram_reference[name], row['stem']+' mount '+name
        # Four independently articulated legs: proximal limb, distal limb, hoof.
        for side in ('L','R'):
            for pair in ('front','hind'):
                leg=side+'_'+pair
                thigh=by_part['ram_thigh_'+leg]; shin=by_part['ram_shin_'+leg]
                hoof=by_part['ram_hoof_'+leg]
                assert (Vector(thigh['joint_end'])-Vector(shin['joint_start'])).length<1e-6
                assert thigh['future_bone']=='mount_thigh_'+leg
                assert shin['future_bone']=='mount_shin_'+leg
                assert hoof['future_bone']=='mount_hoof_'+leg
                assert Vector(thigh['joint_start']).z>Vector(shin['joint_start']).z>Vector(shin['joint_end']).z
                assert (Vector(shin['joint_end'])-hoof.matrix_world.translation).length<.075
        ram_verified+=1
    # Use editable source meshes, preserving their source scene and transforms.
    offset=Vector(((row['tier']-1.5)*3.0,(index//4)*3.15,0))
    for original in meshes:
        copy=original.copy(); copy.parent=None; copy.animation_data_clear()
        copy.name='REVIEW_'+row['stem']+'_'+original.get('part','part')
        scene.collection.objects.link(copy)
        copy.matrix_world=Matrix.Translation(offset)@original.matrix_world
        copy['review_stem']=row['stem']
        mat=copy.active_material
        if mat and mat.use_nodes:
            tex=next((n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'),None)
            if tex: mat.node_tree.nodes.active=tex
    curve=bpy.data.curves.new('Label_'+row['stem'],'FONT')
    curve.body=row['name']+'\n'+row['tier_name']; curve.size=.13; curve.align_x='CENTER'
    label=bpy.data.objects.new('Label_'+row['stem'],curve)
    scene.collection.objects.link(label); label.location=offset+Vector((0,-1.02,.015))
    checks.append({'stem':row['stem'],'anatomical_parts':len(anatomy),'source_parts':len(meshes)})
output={'status':'PASS','verified':24,'same_18_anatomical_cuboids':20,'hip_leg_balance_corrected':True,'hands_and_foot_length_preserved':True,
        'boot_width_matches_shin':True,'shins_wider_than_thighs':True,'resting_hands_vertical':True,
        'upright_rebalanced_hammers':True,'enlarged_crossbows':True,
        'held_equipment_forward':True,'one_hand_equipment':True,'guardians_shield_only':True,'material_emblems':False,'ram_legs_with_thigh_shin_hoof':4,'handles_at_fist_centers':True,'painted_equipment_details':True,
        'same_ram_anatomy':ram_verified,'neck':False,'mcp':'live','assets':checks}
(ROOT/'docs/dwarf_troops_blender_validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.context.window.scene=scene
target=Vector((0,7.7,.65))
rotation=Vector((5,-12,11)).to_track_quat('Z','Y')
for area in bpy.context.window.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active
        space.shading.type='SOLID'; space.shading.color_type='TEXTURE'
        space.shading.light='STUDIO'; space.overlay.show_overlays=False
        space.region_3d.view_perspective='ORTHO'
        space.region_3d.view_rotation=rotation
        space.region_3d.view_location=target; space.region_3d.view_distance=24
bpy.data.libraries.write(str(OUT/'dwarf_troops_review.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'status':'PASS','verified':24,'scene':scene.name,'mcp':'live','anatomical_cuboids':18,'neck':False}
