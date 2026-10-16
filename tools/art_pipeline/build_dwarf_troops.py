"""Live Blender MCP factory: original static dwarf meshes, atlases and review views.
The source anatomy is identical in every humanoid; posing changes transforms only.
No human mesh, animation, texture or equipment is imported.
"""
import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dwarf_troop_assets import ASSETS, ROOT, OUT, WORK
from dwarf_troop_paint import PALETTE, paint_tile

PARTS = []
BODY = {}
ROW = None
ROOT_OBJ = None
SCENE = None


def mesh(name, vertices, faces, region, group='equipment', anatomy=False):
    data = bpy.data.meshes.new(name+'_Mesh')
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    assert all(e.is_manifold for e in bm.edges), name
    bm.to_mesh(data); bm.free()
    obj = bpy.data.objects.new(name, data)
    SCENE.collection.objects.link(obj)
    obj.parent = ROOT_OBJ
    obj['part'] = name
    obj['surface'] = region; obj['future_bone'] = group
    if anatomy:
        obj['shared_anatomy'] = name
        BODY[name] = obj
    PARTS.append(obj)
    return obj


def box(name, center, size, region, group='equipment', anatomy=False, bevel=.0):
    w, d, h = size
    verts = [(x*w/2, y*d/2, z*h/2) for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]
    faces = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
    obj = mesh(name, verts, faces, region, group, anatomy)
    # The game's accepted units have SIX-faced cuboids, no softened bevels.
    # `bevel` remains accepted for old equipment recipes, but is intentionally unused.
    obj.location=center
    return obj


def cylinder(name, center, radius, length, region, axis='Z', sides=8, group='equipment'):
    vs=[(math.cos(i*math.tau/sides)*radius, math.sin(i*math.tau/sides)*radius,z*length/2)
        for z in (-1,1) for i in range(sides)]
    fs=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
    fs += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    obj=mesh(name,vs,fs,region,group)
    obj.location=center
    if axis=='X': obj.rotation_euler[1]=math.pi/2
    if axis=='Y': obj.rotation_euler[0]=math.pi/2
    return obj


def beam(name, start, end, width, depth, region, group='equipment', bevel=0):
    a,b=Vector(start),Vector(end)
    obj=box(name,(a+b)/2,(width,depth,(b-a).length),region,group,bevel=bevel)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return obj


def plate(name, outline, y, depth, region, group='equipment', anatomy=False):
    # Outline in X/Z; extrusion along Y. All faces closed, no paper-thin polygons.
    n=len(outline)
    vs=[(x,yy,z) for yy in (-depth/2,depth/2) for x,z in outline]
    fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    obj=mesh(name,vs,fs,region,group,anatomy); obj.location.y=y
    return obj


def follow(obj, body_name, offset=(0,0,0)):
    ref=BODY[body_name]
    obj.rotation_euler=ref.rotation_euler
    obj.location=ref.location+ref.rotation_euler.to_matrix()@Vector(offset)
    obj['future_bone']=ref['future_bone']
    return obj


def limb_rotation(direction):
    axis=Vector(direction).normalized()
    width=Vector((1,0,0)); width=(width-axis*width.dot(axis)).normalized()
    return Matrix((width,axis.cross(width),axis)).transposed().to_euler()


def forward_weapon(frame,tilt=12,downward=False):
    angle=math.radians(tilt)
    axis=Vector((0,math.sin(angle),-math.cos(angle))) if downward else Vector((0,-math.sin(angle),math.cos(angle)))
    cutting=Vector((0,-math.cos(angle),-math.sin(angle)))
    frame.rotation_euler=Matrix((cutting,axis.cross(cutting),axis)).transposed().to_euler()
    frame['striking_direction']='forward_minus_y'


def stepped_shield(w,h):
    return [(-w*.34,-h/2),(w*.34,-h/2),(w*.34,-h*.34),(w/2,-h*.34),
            (w/2,h*.34),(w*.34,h*.34),(w*.34,h/2),(-w*.34,h/2),
            (-w*.34,h*.34),(-w/2,h*.34),(-w/2,-h*.34),(-w*.34,-h*.34)]


def anatomy(seated=False, lift=0):
    """18 common cuboids: powerful chest, pinched waist, massive fists and boots."""
    family=ROW.get('family','guardian')
    box('body_pelvis',(0,0,.495),(.52,.30,.16),'cloth','pelvis',True)
    box('body_belly',(0,0,.66),(.43,.29,.17),'linen','chest',True)
    box('body_chest',(0,0,.88),(.62,.33,.28),'linen','chest',True)
    box('body_head',(0,-.015,1.185),(.38,.34,.33),'skin','head',True)
    extras=[]
    extras.append(box('hair_cap',(0,-.015,1.363),(.386,.35,.026),'hair','head'))
    # A real projecting nose, brows and moustache; no painted beard slab.
    extras.append(box('nose_bridge',(0,-.202,1.185),(.062,.062,.111),'skin','head'))
    extras.append(box('nose_tip',(0,-.244,1.152),(.092,.094,.075),'skin','head'))
    for sign in (-1,1):
        extras.append(box('brow_'+str(sign),(sign*.102,-.204,1.271),(.146,.051,.047),'beard','head'))
        extras.append(box('moustache_'+str(sign),(sign*.073,-.244,1.088),(.148,.091,.067),'beard','head'))
        extras.append(box('sideburn_'+str(sign),(sign*.177,-.13,1.098),(.049,.14,.17),'beard','head'))
    # Separate stepped locks give negative spaces, depth and tapered ends.
    for i,x in enumerate((-.139,-.071,0,.071,.139)):
        count=3 if abs(x)>.1 else 4
        for j in range(count):
            z=1.031-j*.064
            width=.077-j*.006
            depth=.086 if i%2 else .095
            y=-.223-(.018 if i%2 else 0)-(.013 if j%2 else 0)
            xx=x+(.009 if j%2 else -.003)*(1 if x>=0 else -1)
            extras.append(box('beard_lock_%s_%s'%(i,j),(xx,y,z),(width,depth,.079),'beard','head'))
    targets={
        'guardian':((-.295,-.26,.70),(.46,-.035,.52)),
        'warrior':((-.46,-.035,.52),(.53,-.31,.70)),
        'ranger':((-.46,-.035,.52),(.43,-.29,.79)),
        'rogue':((-.46,-.035,.52),(.49,-.17,.61)),
        'cavalry':((-.36,-.28,.73),(.54,-.095,.69)),
    }
    for side,sign in [('L',-1),('R',1)]:
        for label,z,size,region in [
            ('thigh',.3375,(.205,.23,.18),'cloth'),
            ('shin',.245,(.235,.245,.18),'leather'),
            ('foot',.0775,(.235,.405,.155),'leather')]:
            box('body_'+label+'_'+side,(sign*.14,-.025 if label!='foot' else -.105,z),
                size,region,label+'_'+side,True)
        box('body_shoulder_'+side,(sign*.402,0,.947),(.23,.335,.205),'leather','upper_arm_'+side,True)
        shoulder=Vector((sign*.395,0,.86))
        target=Vector(targets[family][0 if side=='L' else 1])
        if family=='warrior' and side=='R' and ROW.get('tier',0)==3:
            # The largest upright hammer needs extra clearance from the pauldron.
            target.y-=.025
        free_hand=(family=='guardian' and side=='R') or (family in ('warrior','ranger','rogue') and side=='L')
        u=(target-shoulder).normalized(); distance=(target-shoulder).length
        l1=.245; l2=.215
        assert abs(l1-l2)<distance<l1+l2, 'Unreachable hand target'
        a=(l1*l1-l2*l2+distance*distance)/(2*distance)
        drop=Vector((0,0,-1)); drop=(drop-u*drop.dot(u)).normalized()
        elbow=shoulder+u*a+drop*math.sqrt(l1*l1-a*a)
        if free_hand:
            # A relaxed, near-vertical arm. Avoid IK's bent elbow and flared wrist.
            elbow=shoulder+Vector((sign*.035,-.01,-1)).normalized()*l1
            target=elbow+Vector((sign*.025,0,-1)).normalized()*l2
        for label,start,end,width,depth,region in [
            ('upper_arm',shoulder,elbow,.19,.205,'skin'),
            ('forearm',elbow,target,.225,.235,'leather')]:
            obj=box('body_'+label+'_'+side,(start+end)/2,(width,depth,(end-start).length),region,label+'_'+side,True)
            expected=l1 if label=='upper_arm' else l2
            for v in obj.data.vertices: v.co.z=expected/2 if v.co.z>0 else -expected/2
            obj.rotation_euler=limb_rotation(end-start)
        direction=(target-elbow).normalized()
        hand=box('body_hand_'+side,target+direction*.081,(.22,.235,.175),'skin','hand_'+side,True)
        hand.rotation_euler=(0,0,0)
        hand['resting_hand']=free_hand
    if seated:
        for side,sign in [('L',-1),('R',1)]:
            hip=Vector((sign*.245,0,.42))
            direction=Vector((sign*.15,-.15,-.075)).normalized()
            thigh=BODY['body_thigh_'+side]
            thigh.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
            thigh.location=hip+direction*.09; knee=hip+direction*.18
            BODY['body_shin_'+side].location=knee+Vector((0,0,-.09))
            BODY['body_foot_'+side].location=knee+Vector((0,-.08,-.2575))
    for obj in list(BODY.values())+extras: obj.location.z+=lift
    assert len(BODY)==18 and 'body_neck' not in BODY
    return BODY


def clothing(tier,family):
    heavy=family in ('guardian','warrior','cavalry')
    dark=family=='rogue'; waist=BODY['body_pelvis'].location
    chest=BODY['body_chest']
    if tier==0:
        region,style=('linen','forge_tunic') if family=='warrior' else ('olive','trail_jerkin') if family=='ranger' else ('shadow','mine_jerkin') if dark else ('leather','jerkin')
    elif tier==1:
        region,style=('mail','mail_baldric') if family=='warrior' else ('clan','surcoat') if heavy else ('leather','trail_jerkin') if family=='ranger' else ('shadow','mine_jerkin')
    else:
        region,style=('iron' if tier==3 else 'steel','cuirass') if heavy else ('steel','scout_cuirass') if family=='ranger' else ('iron','scout_cuirass')
    chest['surface']=region; chest['paint_style']=style
    for name in ('body_belly','body_pelvis'):
        BODY[name]['surface']='linen' if tier==0 and heavy else 'shadow' if dark else 'olive' if tier==0 else 'mail'
    BODY['body_pelvis']['paint_style']='belted_skirt'
    for side in ('L','R'):
        BODY['body_thigh_'+side]['surface']='shadow' if dark else 'cloth'
        upper=BODY['body_upper_arm_'+side]
        upper['surface']='skin' if tier==0 and family=='warrior' else 'linen' if tier==0 and heavy else 'olive' if tier==0 and family=='ranger' else 'shadow' if dark and tier<2 else 'mail'
        shoulder=BODY['body_shoulder_'+side]
        shoulder['surface']='linen' if tier==0 and family=='warrior' and side=='L' else 'leather' if tier==0 or tier==1 and not heavy else 'iron' if tier==3 else 'steel'
        shoulder['paint_style']='pauldron' if shoulder['surface'] in ('steel','iron') else 'leather_shoulder' if shoulder['surface']=='leather' else 'woven_sleeve'
        fore=BODY['body_forearm_'+side]
        fore['surface']='iron' if tier==3 and heavy else 'steel' if tier>=2 else 'leather'
        fore['paint_style']='plate_bracer' if tier>=2 else 'bracer'
        BODY['body_hand_'+side]['surface']='skin' if tier==0 and family=='warrior' else 'leather'
        shin=BODY['body_shin_'+side]; foot=BODY['body_foot_'+side]
        shin['surface']='steel' if tier>=2 and heavy else 'leather'; shin['paint_style']='greave'
        foot['surface']='steel' if tier==3 and heavy else 'leather'; foot['paint_style']='sabaton' if foot['surface']=='steel' else 'boot'
    # The belt, wrist cuffs, boot soles and plate divisions are all painted.
    box('belt_buckle',(0,-.165,waist.z+.029),(.083,.03,.053),'iron' if tier==3 else 'copper','pelvis')
    if tier>=1:
        for i,x in enumerate((-.071,.071)):
            z=.86+(waist.z-.495)
            box('braid_ring_'+str(i),(x,-.269,z),(.075,.026,.04),'gold' if tier==3 else 'copper','head')
            if tier>=2:
                for j in range(3):
                    box('braid_weave_%s_%s'%(i,j),(x+(-.014 if j%2 else .014),-.276,z-.045-j*.039),(.052,.052,.046),'beard','head')
        if tier==3: box('beard_ancestral_clasp',(0,-.298,.835+(waist.z-.495)),(.065,.024,.055),'gold','head')


def helmet(tier,family):
    head=BODY['body_head'].location
    if family=='rogue':
        # Four large cowl surfaces, no decorative scraps/temple plates.
        for sign in (-1,1): box('cowl_side_'+str(sign),(sign*.205,.025,head.z+.034),(.038,.31,.264),'shadow','head')['paint_style']='cowl'
        box('cowl_crown',(0,.005,head.z+.182),(.446,.375,.038),'shadow','head')['paint_style']='cowl'
        box('cowl_back',(0,.158,head.z+.02),(.406,.038,.30),'shadow','head')['paint_style']='cowl'
        return
    if tier==0 and family=='warrior': return
    if tier==0 and family=='ranger':
        box('trail_cap',(0,-.015,head.z+.155),(.405,.365,.065),'leather','head')['paint_style']='cap'
        return
    metal='iron' if tier==3 else 'steel'
    box('helm_cap',(0,-.015,head.z+.156),(.41,.37,.106),metal,'head')['paint_style']='helm'
    box('helm_crown',(0,-.015,head.z+.22),(.32,.28,.035),metal,'head')['paint_style']='helm'
    if tier==0:
        box('helm_brim',(0,-.015,head.z+.103),(.455,.415,.028),metal,'head')
    elif tier>=2:
        # One enclosing shell for each cheek is structural, not an ornament.
        for sign in (-1,1): box('helm_cheek_'+str(sign),(sign*.203,.045,head.z+.026),(.029,.235,.175),metal,'head')['paint_style']='helm_cheek'


def armor(tier,family):
    helmet(tier,family)
    chest=BODY['body_chest'].location; waist=BODY['body_pelvis'].location
    # Actual hanging cloth is additional geometry, like the human tabards/capes.
    if family in ('guardian','cavalry') and tier>=1:
        box('clan_tabard',(0,-.178,waist.z-.108),(.23,.026,.158),'clan','pelvis')['paint_style']='tabard'
    if family in ('ranger','rogue') and tier>=1 or tier==3:
        box('back_mantle',(0,.192,chest.z-.154),(.56,.036,.51),'shadow' if family=='rogue' else 'clan','chest')['paint_style']='mantle'


def weapon_frame(name, grip):
    obj=bpy.data.objects.new(name,None); SCENE.collection.objects.link(obj)
    obj.parent=ROOT_OBJ; obj.location=grip; obj['future_bone']='hand_R'
    return obj


def group_frame(frame, first):
    for obj in PARTS[first:]:
        obj.parent=frame # positions authored local to weapon frame
        obj['future_bone']=frame['future_bone']


def axe(grip,tier,double=False,side='R'):
    frame=weapon_frame('forged_axe_'+side,grip); frame['future_bone']='hand_'+side; first=len(PARTS)
    length=.91+tier*.055; z=.46+tier*.035
    box('axe_haft',(0,0,.11),(.075,.075,length),'wood')['paint_style']='haft'
    box('axe_grip',(0,0,0),(.087,.09,.22),'leather')['paint_style']='grip'
    box('axe_head',(0,0,z),(.15,.11,.23),'iron')['paint_style']='axe_socket'
    reach=.51+tier*.045; height=.45+tier*.04
    for sign in ([1,-1] if double else [1]):
        # A single forged, stepped blade, rather than a stack of decorative cubes.
        outline=[(.055,z-height*.26),(reach*.60,z-height*.26),
                 (reach*.60,z-height*.50),(reach,z-height*.50),
                 (reach,z+height*.50),(reach*.60,z+height*.50),
                 (reach*.60,z+height*.26),(.055,z+height*.26)]
        blade=plate('axe_blade_'+str(sign),[(sign*x,zz) for x,zz in outline],0,.12+tier*.009,'steel')
        blade['paint_style']='axe_blade'; blade['cutting_edge_x']=sign*reach
    group_frame(frame,first); forward_weapon(frame)
    frame['grip_anchor']=list(grip); frame['grip_hand']='body_hand_'+side


def hammer(grip,tier,side='R'):
    frame=weapon_frame('clan_hammer_'+side,grip); frame['future_bone']='hand_'+side; first=len(PARTS)
    box('hammer_haft',(0,0,.055),(.074,.076,.57+tier*.025),'wood')['paint_style']='haft'
    box('hammer_grip',(0,0,0),(.092,.095,.22),'leather')['paint_style']='grip'
    # Upright one-handed warhammer: substantial, with a head scaled to the dwarf.
    box('hammer_head',(0,0,.325),(.43+tier*.025,.245+tier*.015,.235+tier*.010),'iron')['paint_style']='hammer_head'
    group_frame(frame,first); forward_weapon(frame,10)
    frame['grip_anchor']=list(grip); frame['grip_hand']='body_hand_'+side


def shield(grip,tier):
    frame=weapon_frame('clan_shield',grip); frame['future_bone']='hand_L'; first=len(PARTS)
    w=.66+tier*.042; h=.72+tier*.05
    field=plate('shield_field',[(x,z-.022) for x,z in stepped_shield(w,h)],-.18,.075,'wood' if tier<=1 else 'iron' if tier==3 else 'steel')
    field['paint_style']='clan_shield'; field['shield_width']=w; field['shield_height']=h
    box('shield_boss',(0,-.235,-.022),(.135,.047,.135),'steel')['paint_style']='shield_boss'
    box('shield_handle',(0,0,0),(.068,.068,.22),'leather')
    for z in (-.102,.102): box('shield_grip_mount_'+str(z),(0,-.082,z),(.056,.164,.028),'iron')
    group_frame(frame,first)
    frame['grip_anchor']=list(grip); frame['grip_hand']='body_hand_L'


def crossbow(grip,tier):
    frame=weapon_frame('clan_crossbow',grip); frame['future_bone']='hand_R'; first=len(PARTS)
    length=.72+tier*.045; width=.70+tier*.045
    box('crossbow_stock',(0,-.17,.067),(.105,length,.105),'wood')['paint_style']='crossbow_stock'
    box('crossbow_trigger_grip',(0,0,-.014),(.072,.075,.172),'leather')
    y=-.17-length/2+.065
    box('crossbow_limb',(0,y,.09),(width,.065,.065),'steel')['paint_style']='crossbow_limb'
    for sign in (-1,1):
        box('crossbow_limb_tip_'+str(sign),(sign*width*.45,y+.04,.09),(.048,.125,.065),'steel')
        beam('crossbow_string_'+str(sign),(sign*width*.45,y+.095,.092),(0,y+.20,.092),.008,.008,'linen')
    box('crossbow_bolt',(0,-.18,.13),(.015,length+.02,.015),'wood')
    box('crossbow_bolt_tip',(0,-.17-length/2-.035,.13),(.025,.046,.023),'edge')
    if tier>=2: box('crossbow_sight',(0,-.09,.158),(.028,.036,.05),'iron')
    group_frame(frame,first)
    frame['grip_anchor']=list(grip); frame['grip_hand']='body_hand_R'
    frame['striking_direction']='forward_minus_y'


def quiver(tier):
    ref=BODY['body_chest'].location
    box('bolt_case',(.31,.16,ref.z-.08),(.125,.116,.29),'leather','chest')['paint_style']='bolt_case'
    for i in range(4):
        x=.279+(i%2)*.061; y=.143+(i//2)*.035
        box('spare_bolt_'+str(i),(x,y,ref.z+.071),(.015,.015,.158),'wood','chest')
        box('spare_bolt_fletching_'+str(i),(x,y,ref.z+.145),(.035,.023,.042),'linen','chest')
    if tier>=2:
        ref=BODY['body_head'].location
        box('raised_goggles',(0,-.217,ref.z+.179),(.215,.045,.062),'copper','head')['paint_style']='goggles'


def dagger(grip,tier,side):
    frame=weapon_frame('forged_seax_'+side,grip); frame['future_bone']='hand_'+side; first=len(PARTS)
    box('seax_grip_'+side,(0,0,0),(.075,.077,.22),'leather')
    box('seax_guard_'+side,(0,0,.12),(.16,.067,.036),'iron')
    length=.28+tier*.035
    blade=plate('seax_blade_'+side,[(-.038,.13),(.068,.13),(.068,.13+length*.68),
                                  (.035,.13+length*.68),(.035,.13+length),(-.038,.13+length)],0,.035,'steel')
    blade['paint_style']='seax_blade'
    group_frame(frame,first); forward_weapon(frame,10,downward=True)
    frame['grip_anchor']=list(grip); frame['grip_hand']='body_hand_'+side


def foot_equipment(family,tier):
    right=BODY['body_hand_R'].location.copy(); left=BODY['body_hand_L'].location.copy()
    if family=='guardian': shield(left,tier)
    if family=='warrior':
        hammer(right,tier)
    if family=='ranger':
        crossbow(right,tier); quiver(tier)
    if family=='rogue':
        dagger(right,tier,'R')
        if tier==1:
            ref=BODY['body_chest'].location
            box('sabotage_toolbox',(0,.235,ref.z-.11),(.32,.21,.31),'leather','chest')['paint_style']='toolbox'
            for i in range(3): box('sealed_charge_'+str(i),(-.13+i*.13,.24,ref.z+.093),(.081,.083,.113),'copper','chest')
            box('sapper_prybar',(-.175,.323,ref.z-.09),(.035,.032,.37),'steel','chest')


def war_ram(tier):
    # Exactly the same mount anatomy in all FOUR tiers, including the legendary.
    first=len(PARTS)
    rise=.18
    box('ram_body',(0,.045,.64),(.62,1.00,.47),'linen','mount_body',bevel=.082)
    box('ram_neck',(0,-.39,.715),(.405,.28,.36),'linen','mount_neck',bevel=.050)
    box('ram_head',(0,-.565,.689),(.269,.35,.273),'fur','mount_head',bevel=.04)
    box('ram_muzzle',(0,-.756,.61),(.20,.13,.135),'mane','mount_head',bevel=.025)
    for x in (-.048,.048): box('ram_nostril_'+str(x),(x,-.825,.625),(.02,.008,.018),'coal','mount_head')
    for s in (-1,1):
        box('ram_ear_'+str(s),(s*.191,-.456,.751),(.142,.094,.056),'fur','mount_head',bevel=.015)
        box('ram_eye_'+str(s),(s*.139,-.623,.74),(.012,.029,.024),'coal','mount_head')
        for y in (-.30,.37):
            leg=('L' if s<0 else 'R')+('_front' if y<0 else '_hind')
            hip=(s*.228,y,.735)
            knee=(s*.228,y+(-.055 if y<0 else .105),.402)
            ankle=(s*.228,y-.024,.14)
            for label,a,b,width,depth in [('thigh',hip,knee,.14,.15),('shin',knee,ankle,.102,.116)]:
                obj=beam('ram_'+label+'_'+leg,a,b,width,depth,'fur','mount_'+label+'_'+leg)
                obj['mount_anatomy_segment']=label
                obj['joint_start']=a; obj['joint_end']=b
            hoof=box('ram_hoof_'+leg,(s*.228,y-.024,.073),(.144,.16,.146),'coal','mount_hoof_'+leg)
            hoof['mount_anatomy_segment']='hoof'
        # Curled mountain ram horns, tapering faceted solid segments, no spikes.
        points=[(s*.148,-.452,.84),(s*.255,-.389,.88),(s*.319,-.426,.787),
                (s*.326,-.514,.633),(s*.291,-.628,.57),(s*.256,-.692,.623),
                (s*.230,-.681,.698)]
        for i in range(len(points)-1):
            width=.104-i*.012
            beam('ram_horn_%s_%s'%(s,i),points[i],points[i+1],width,width,'ivory','mount_head',.008)
    # Broad fleece facets, deliberately quiet wool rather than noisy dots.
    for s in (-1,1):
        for i in range(4):
            box('ram_fleece_%s_%s'%(s,i),(s*.299,-.28+i*.22,.692),(.064,.21,.223),'linen','mount_body',bevel=.016)
    beam('ram_tail',(0,.55,.69),(0,.67,.625),.065,.061,'linen','mount_body')
    box('saddle_blanket',(0,.03,.882),(.57,.54,.046),'clan','mount_body',bevel=.008)
    box('saddle_seat',(0,.061,.94),(.285,.32,.092),'leather','mount_body',bevel=.016)
    for y in (-.103,.22): box('saddle_bolster_'+str(y),(0,y,.973),(.32,.057,.103),'leather','mount_body',bevel=.012)
    for s in (-1,1):
        box('girth_strap_'+str(s),(s*.325,.06,.68),(.023,.08,.38),'leather','mount_body')
        if tier>=1:
            box('ram_flank_plate_'+str(s),(s*.344,.02,.703),(.037,.50,.261),'steel','mount_body')['paint_style']='mount_plate'
    if tier>=1:
        box('ram_forehead_plate',(0,-.562,.831),(.181,.233,.036),'steel','mount_head')['paint_style']='mount_plate'
    if tier>=2:
        box('ram_chest_armor',(0,-.52,.47),(.34,.06,.17),'iron','mount_neck')['paint_style']='riveted_panel'
        for y in (-.28,.38): box('ram_spine_plate_'+str(y),(0,y,.923),(.43,.20,.049),'steel','mount_body',bevel=.012)
    if tier==3:
        for s in (-1,1):
            for y in (-.30,.32):
                box('ram_royal_guard_'+str((s,y)),(s*.263,y,.57),(.045,.25,.22),'iron','mount_body')['paint_style']='mount_plate'
    for obj in PARTS[first:]:
        if not obj.get('mount_anatomy_segment'): obj.location.z+=rise


def cavalry(tier):
    war_ram(tier)
    anatomy(True,.71)
    clothing(tier,'cavalry'); armor(tier,'cavalry')
    right=BODY['body_hand_R'].location.copy(); left=BODY['body_hand_L'].location.copy()
    axe(right,tier,double=tier==3)
    # Reins actually reach the bridle instead of floating props.
    front=(0,-.69,.90)
    for s in (-1,1):
        hand=left+Vector((s*.025,.016,.02))
        beam('rein_'+str(s),hand,(s*.16,front[1],front[2]),.012,.012,'leather','mount_head')
        box('bridle_cheek_'+str(s),(s*.153,front[1]+.05,front[2]),(.022,.16,.08),'leather','mount_head')


def wheel(name,x,y,z,r,heavy=False):
    cylinder(name+'_tire',(x,y,z),r,.095,'iron','X',10)
    cylinder(name+'_wood',(x+(.05 if x>0 else -.05),y,z),r*.85,.015,'wood','X',10)
    cylinder(name+'_hub',(x+(.069 if x>0 else -.069),y,z),r*.23,.049,'copper','X')
    for i in range(4):
        angle=i*math.pi/4
        dy,dz=math.cos(angle)*r*.79,math.sin(angle)*r*.79
        xx=x+(.061 if x>0 else -.061)
        beam(name+'_spoke_'+str(i),(xx,y-dy,z-dz),(xx,y+dy,z+dz),.024,.031,'copper' if heavy else 'iron')


def siege_chassis(tier):
    width=[.79,.93,1.02,1.18][tier]; length=[1.05,1.28,1.16,1.47][tier]
    radius=[.205,.225,.25,.29][tier]; deck=radius*1.6
    for x in (-width/2,width/2):
        box('chassis_rail_'+str(x),(x,0,deck),(.095,length,.13),'wood' if tier<2 else 'iron',bevel=.012)
    for y in (-length*.38,length*.38):
        box('chassis_crossbeam_'+str(y),(0,y,deck),(width+.14,.12,.13),'wood',bevel=.01)
        cylinder('chassis_axle_'+str(y),(0,y,radius),.047,width+.28,'iron','X')
        for s in (-1,1): wheel('wheel_'+str((s,y)),s*(width/2+.094),y,radius,radius,tier>=2)
    for i in range(6): box('deck_plank_'+str(i),(0,-length*.4+i*length*.16,deck+.087),(width,.14,.043),'wood',bevel=.004)
    for s in (-1,1):
        box('front_band_'+str(s),(s*width*.29,-length*.386,deck),(.065,.143,.156),'copper',bevel=.006)
    return width,length,deck


def barrel(name,start,end,radius,region='iron'):
    # Closed tube with a dark, recessed bore: export remains manifold.
    a,b=Vector(start),Vector(end); n=12; length=(b-a).length
    vs=[]
    for z,r in [(0,radius),(length,radius),(length,radius*.70),(length-radius*.60,radius*.70)]:
        vs.extend([(math.cos(i*math.tau/n)*r,math.sin(i*math.tau/n)*r,z) for i in range(n)])
    fs=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
    for ring1,ring2 in [(0,1),(1,2),(2,3)]:
        fs += [(ring1*n+i,ring1*n+(i+1)%n,ring2*n+(i+1)%n,ring2*n+i) for i in range(n)]
    obj=mesh(name,vs,fs,region); obj.location=a; obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    obj['bore_faces_start']=2+n*2
    return obj


def siege(tier):
    w,l,z=siege_chassis(tier)
    if tier==0:
        for s in (-1,1):
            box('torsion_cheek_'+str(s),(s*.32,-.11,z+.22),(.11,.55,.37),'wood',bevel=.012)
            cylinder('torsion_rope_'+str(s),(s*.275,-.10,z+.38),.097,.18,'linen','X')
        cylinder('torsion_shaft',(0,-.10,z+.38),.050,.79,'iron','X')
        beam('mangonel_arm',(0,-.16,z+.27),(0,.17,z+.87),.093,.105,'wood',bevel=.008)
        box('stone_cup',(0,.18,z+.895),(.22,.245,.082),'iron',bevel=.014)
        box('loaded_stone',(0,.18,z+.969),(.15,.16,.14),'steel',bevel=.026)
        for s in (-1,1): beam('stop_brace_'+str(s),(s*.32,-.40,z+.09),(s*.32,-.13,z+.60),.07,.07,'wood')
        box('stop_crossbar',(0,-.13,z+.60),(.78,.065,.065),'iron')
        cylinder('winch',(0,.32,z+.22),.071,.51,'wood','X')
    elif tier==1:
        for s in (-1,1):
            beam('trebuchet_A_front_'+str(s),(s*.34,-.43,z+.04),(s*.34,-.04,z+.98),.075,.085,'wood')
            beam('trebuchet_A_back_'+str(s),(s*.34,.44,z+.04),(s*.34,-.04,z+.98),.075,.085,'wood')
            box('trebuchet_pivot_cap_'+str(s),(s*.35,-.04,z+.98),(.117,.14,.14),'copper',bevel=.01)
        cylinder('trebuchet_pivot',(0,-.04,z+.98),.045,.82,'iron','X')
        a=Vector((0,-.28,z+.72)); b=Vector((0,.46,z+1.39))
        beam('trebuchet_arm',a,b,.083,.09,'wood')
        box('counterweight',(0,-.28,z+.46),(.32,.26,.27),'iron',bevel=.025)
        for x in (-.12,.12): beam('counterweight_hanger_'+str(x),(x,-.28,z+.71),(x,-.28,z+.55),.029,.029,'copper')
        end=b+Vector((0,.12,-.27))
        for x in (-.066,.066): beam('sling_rope_'+str(x),b+Vector((x,0,0)),end+Vector((x,0,0)),.012,.012,'linen')
        box('sling_pocket',end,(.18,.16,.04),'leather',bevel=.005)
        box('sling_stone',end+Vector((0,0,.069)),(.125,.13,.125),'steel',bevel=.023)
    elif tier==2:
        for s in (-1,1): box('bombard_trunnion_support_'+str(s),(s*.275,-.09,z+.28),(.115,.40,.39),'iron',bevel=.025)
        cylinder('bombard_trunnion',(0,-.1,z+.40),.065,.65,'copper','X')
        a=Vector((0,.35,z+.35)); b=Vector((0,-.66,z+.59))
        obj=barrel('bombard_barrel',a,b,.18)
        axis=(b-a).normalized()
        for i in range(4):
            center=a+axis*(.08+i*.265)
            band=cylinder('bombard_copper_band_'+str(i),center,.194,.063,'copper')
            band.rotation_euler=obj.rotation_euler
        box('bombard_breech',(0,.38,z+.35),(.37,.14,.33),'iron',bevel=.03)
        box('fuse_pan',(0,.33,z+.53),(.073,.10,.04),'copper',bevel=.006)
        for s in (-1,1): box('blast_guard_'+str(s),(s*.46,-.31,z+.23),(.064,.67,.29),'steel',bevel=.014)
        box('powder_case',(0,.48,z+.18),(.44,.17,.20),'wood',bevel=.011)
        for x in (-.14,.14): box('powder_case_band_'+str(x),(x,.576,z+.18),(.035,.015,.19),'copper')
    else:
        # Mobile single siege mortar / pressure boiler; deliberately unlike human twin cannon.
        box('colossus_armored_deck',(0,.02,z+.18),(1.02,1.22,.20),'iron',bevel=.035)
        for s in (-1,1):
            box('colossus_flank_armor_'+str(s),(s*.60,0,z+.04),(.055,1.31,.38),'steel',bevel=.023)
            for yy in (-.4,0,.4): box('colossus_flank_band_'+str((s,yy)),(s*.636,yy,z+.04),(.022,.052,.34),'copper')
        cylinder('colossus_boiler',(0,.33,z+.49),.28,.61,'copper','X',12)
        for x in (-.316,.316): cylinder('boiler_endcap_'+str(x),(x,.33,z+.49),.258,.037,'iron','X',12)
        box('boiler_firebox',(0,.44,z+.24),(.48,.37,.13),'iron',bevel=.018)
        box('firebox_grille',(0,.634,z+.25),(.20,.013,.056),'ember')
        for x in (-.08,-.027,.027,.08): box('firebox_bar_'+str(x),(x,.645,z+.25),(.014,.015,.072),'iron')
        for s in (-1,1):
            cylinder('exhaust_stack_'+str(s),(s*.20,.43,z+.99),.061,.47,'iron')
            cylinder('exhaust_copper_cap_'+str(s),(s*.20,.43,z+1.225),.083,.040,'copper')
            cylinder('drive_piston_'+str(s),(s*.44,.25,z+.40),.071,.46,'copper','Y')
            beam('piston_rod_'+str(s),(s*.44,.20,z+.40),(s*.44,-.31,z+.40),.035,.035,'edge')
            beam('boiler_pipe_'+str(s),(s*.27,.32,z+.64),(s*.32,-.11,z+.62),.046,.046,'copper')
        a=Vector((0,-.18,z+.36)); b=Vector((0,-.64,z+1.12))
        obj=barrel('colossus_siege_mortar',a,b,.245)
        for t in (.16,.61):
            band=cylinder('mortar_copper_band_'+str(t),a+(b-a).normalized()*t,.268,.083,'copper',sides=12)
            band.rotation_euler=obj.rotation_euler
        for s in (-1,1):
            beam('mortar_support_'+str(s),(s*.24,-.37,z+.24),(s*.24,-.34,z+.72),.113,.09,'steel')
        box('colossus_front_shield',(0,-.65,z+.25),(.86,.055,.37),'iron')['paint_style']='riveted_panel'
        for s in (-1,1): box('colossus_front_stair_'+str(s),(s*.39,-.675,z+.405),(.14,.085,.098),'copper',bevel=.008)
        cylinder('pressure_dial',(.356,.31,z+.67),.076,.03,'linen','X')
        beam('pressure_needle',(.38,.31,z+.67),(.38,.35,z+.71),.010,.012,'coal')


def anatomy_hashes():
    return {name:hashlib.sha256(json.dumps({
        'vertices':[[round(v,6) for v in vert.co] for vert in obj.data.vertices],
        'faces':[list(p.vertices) for p in obj.data.polygons]},sort_keys=True).encode()).hexdigest()
        for name,obj in sorted(BODY.items())}


def pack_and_paint(folder,stem):
    """Metric per-face atlas with padding; quiet surfaces, meaningful facial pixels."""
    density=64; pad=3; islands=[]
    for obj in PARTS:
        uv=obj.data.uv_layers.new(name='UVMap')
        for face in obj.data.polygons:
            normal=face.normal
            up=Vector((0,0,1)); up-=normal*up.dot(normal)
            if up.length<.01: up=Vector((0,1,0)); up-=normal*up.dot(normal)
            up.normalize(); right=up.cross(normal).normalized()
            points=[Vector((obj.data.vertices[obj.data.loops[li].vertex_index].co.dot(right),
                            obj.data.vertices[obj.data.loops[li].vertex_index].co.dot(up))) for li in face.loop_indices]
            lo=Vector((min(p.x for p in points),min(p.y for p in points)))
            points=[p-lo for p in points]
            w=max(2,math.ceil(max(p.x for p in points)*density)+1)
            h=max(2,math.ceil(max(p.y for p in points)*density)+1)
            islands.append(dict(obj=obj,face=face,points=points,w=w,h=h))
    islands.sort(key=lambda f:(-f['h'],-f['w']))
    size=256
    while True:
        x=y=pad; rowh=0; fits=True
        for f in islands:
            if x+f['w']+pad>size: x=pad; y+=rowh+pad*2; rowh=0
            if y+f['h']+pad>size: fits=False; break
            f['x']=x; f['y']=y
            x+=f['w']+pad*2; rowh=max(rowh,f['h'])
        if fits: break
        size*=2
    atlas=np.zeros((size,size,4),dtype=np.float32); atlas[:,:,3]=1
    for index,f in enumerate(islands):
        obj,face=f['obj'],f['face']; w,h=f['w'],f['h']; region=obj['surface']
        tile=paint_tile(obj,face,w,h,ROW)
        rgba=np.concatenate((tile,np.ones((h,w,1))),axis=2)
        ox,oy=f['x'],f['y']
        atlas[oy-pad:oy+h+pad,ox-pad:ox+w+pad]=np.pad(rgba,((pad,pad),(pad,pad),(0,0)),mode='edge')
        for li,p in zip(face.loop_indices,f['points']):
            obj.data.uv_layers.active.data[li].uv=((ox+.5+p.x*density)/size,(oy+.5+p.y*density)/size)
    im=bpy.data.images.new(stem+'_albedo',width=size,height=size,alpha=True)
    im.pixels.foreach_set(atlas.ravel()); im.file_format='PNG'
    im.filepath_raw=str(folder/(stem+'_albedo.png')); im.save(); im.pack()
    material=bpy.data.materials.new(stem+'_pixel_material'); material.use_nodes=True
    bsdf=material.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.86
    tex=material.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.interpolation='Closest'
    material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    for obj in PARTS: obj.data.materials.append(material)
    return dict(size=size,density_px_per_m=density,padding_px=pad,face_islands=len(islands),paint_revision=7,
                sha256=hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest())


def geometry_report():
    triangles=0; lo=Vector((1e9,1e9,1e9)); hi=-lo
    for obj in PARTS:
        bm=bmesh.new(); bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges),obj.name
        assert all(f.calc_area()>1e-10 for f in bm.faces),obj.name
        bm.free()
        triangles+=sum(len(f.vertices)-2 for f in obj.data.polygons)
        for v in obj.data.vertices:
            p=obj.matrix_world@v.co
            assert all(math.isfinite(a) for a in p)
            lo=Vector(tuple(min(a,b) for a,b in zip(lo,p)))
            hi=Vector(tuple(max(a,b) for a,b in zip(hi,p)))
        assert all(-1e-5<=a<=1.00001 for uv in obj.data.uv_layers.active.data for a in uv.uv)
    return dict(parts=len(PARTS),triangles=triangles,bounds_min=list(lo),bounds_max=list(hi),
                dimensions=list(hi-lo),closed_meshes=True,uv_in_bounds=True)


def grip_report():
    """Held handles must contain the fist centre in their own local volume."""
    checks=[]
    for frame in ROOT_OBJ.children:
        name=frame.get('grip_hand')
        if not name: continue
        hand=BODY[name]
        anchor=frame.matrix_world.translation
        assert (anchor-hand.matrix_world.translation).length<1e-6,frame.name
        handles=[obj for obj in frame.children if 'grip' in obj.get('part','') or obj.get('part')=='shield_handle']
        assert handles,frame.name
        contained=False
        for handle in handles:
            local=handle.matrix_world.inverted()@anchor
            lo=[min(v.co[i] for v in handle.data.vertices) for i in range(3)]
            hi=[max(v.co[i] for v in handle.data.vertices) for i in range(3)]
            contained |= all(lo[i]-1e-6<=local[i]<=hi[i]+1e-6 for i in range(3))
        assert contained,'Detached handle: '+frame.name
        checks.append(dict(weapon=frame.name,hand=name,fist_center_inside_handle=True))
    return checks


def export(folder,stem,atlas):
    path=folder/(stem+'.glb')
    # Compact runtime meshes by future attachment. Editable source keeps ALL parts.
    groups={}
    for obj in PARTS: groups.setdefault(obj['future_bone'],[]).append(obj)
    copies=[]
    try:
        for group,objects in groups.items():
            batch=[]
            for obj in objects:
                copy=obj.copy(); copy.data=obj.data.copy(); copy.parent=None
                copy.data.transform(obj.matrix_world)
                copy.matrix_world.identity()
                SCENE.collection.objects.link(copy); batch.append(copy)
            if len(batch)>1:
                with bpy.context.temp_override(scene=SCENE,view_layer=SCENE.view_layers[0],active_object=batch[0],selected_editable_objects=batch,selected_objects=batch):
                    bpy.ops.object.join()
            copy=batch[0]; copy.name=stem+'_'+group; copy.parent=ROOT_OBJ
            copy['future_bone']=group
            if 'shared_anatomy' in copy: del copy['shared_anatomy']
            copies.append(copy)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in copies+[ROOT_OBJ]: obj.select_set(True)
        bpy.context.view_layer.objects.active=ROOT_OBJ
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
            use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,export_extras=True,
            export_cameras=False,export_lights=False)
    finally:
        for obj in copies:
            data=obj.data; bpy.data.objects.remove(obj,do_unlink=True)
            if data.users==0: bpy.data.meshes.remove(data)
    raw=path.read_bytes(); jl=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+jl]); binary=raw[28+jl:]
    assert not doc.get('animations') and not doc.get('skins') and not doc.get('cameras')
    assert len(doc['images'])==1 and len(doc['materials'])==1
    assert len(doc['meshes'])==len(groups), 'Unexpected mesh/scene included in export'
    bv=doc['bufferViews'][doc['images'][0]['bufferView']]
    png=binary[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
    assert hashlib.sha256(png).hexdigest()==atlas['sha256']
    assert all(s['magFilter']==9728 for s in doc['samplers'])
    return dict(bytes=len(raw),meshes=len(doc['meshes']),animations=0,skins=0,
                embedded_png_matches=True,nearest_filter=True,
                sha256=hashlib.sha256(raw).hexdigest())


def studio(folder,geometry):
    scene=SCENE
    scene.render.engine='CYCLES'
    scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.render.resolution_x=720; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
    scene.world=bpy.data.worlds.new('DwarfReviewWorld'); scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='None'
    ground=box('STUDIO_floor',(0,0,-.031),(200,200,.055),'shadow')
    PARTS.remove(ground); ground.parent=None
    mat=bpy.data.materials.new('StudioGround'); mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.13,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1
    ground.data.materials.append(mat)
    for name,loc,power,size in [('key',(-5,-6,9),1400,6),('fill',(6.5,-2.5,6.5),700,6),('rim',(0,7,8),1500,5)]:
        ld=bpy.data.lights.new('STUDIO_'+name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        obj=bpy.data.objects.new('STUDIO_'+name,ld); scene.collection.objects.link(obj); obj.location=loc
        obj.rotation_euler=(Vector((0,0,.8))-obj.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('STUDIO_camera'); cam=bpy.data.objects.new('STUDIO_camera',cd)
    scene.collection.objects.link(cam); scene.camera=cam; cd.type='ORTHO'
    center=(Vector(geometry['bounds_min'])+Vector(geometry['bounds_max']))/2
    # A common per-family scale lets the upgrades be compared honestly.
    cd.ortho_scale=2.27 if ROW['family'] not in ('cavalry','siege') else (3.4 if ROW['family']=='cavalry' else 3.05)
    views={'three_quarter':(6,-12,5.6),'back':(-6,12,5),'game_top':(5,-7,11),'front':(0,-12,1.2)}
    previews=folder/'previews'; previews.mkdir(exist_ok=True)
    for name,offset in views.items():
        cam.location=center+Vector(offset)
        cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(previews/(name+'.png'))
        bpy.ops.render.render(write_still=True,scene=SCENE.name)
    cam.location=center+Vector(views['three_quarter'])
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()


def build(row,render=True):
    global SCENE
    SCENE=new_live_scene(row['stem'])
    with bpy.context.temp_override(scene=SCENE,view_layer=SCENE.view_layers[0]):
        _build_current(row,render)


def _build_current(row,render=True):
    global PARTS,BODY,ROW,ROOT_OBJ
    PARTS=[]; BODY={}; ROW=row
    ROOT_OBJ=bpy.data.objects.new(row['stem'],None)
    SCENE.collection.objects.link(ROOT_OBJ)
    ROOT_OBJ['asset_stage']='static_model_review'; ROOT_OBJ['race']='dwarf'
    ROOT_OBJ['family']=row['family']; ROOT_OBJ['tier']=row['tier']
    ROOT_OBJ['gameplay_reference']=row['gameplay_id']
    folder=OUT/row['stem']; folder.mkdir(parents=True,exist_ok=True)
    if row['family']=='siege': siege(row['tier'])
    elif row['family']=='cavalry': cavalry(row['tier'])
    else:
        anatomy(); clothing(row['tier'],row['family']); armor(row['tier'],row['family'])
        foot_equipment(row['family'],row['tier'])
    SCENE.view_layers[0].update()
    fingerprint=anatomy_hashes()
    atlas=pack_and_paint(folder,row['stem'])
    SCENE.view_layers[0].update()
    geometry=geometry_report(); exported=export(folder,row['stem'],atlas)
    report=dict(**row,status='PASS',stage='static_models_only',body_height_m=1.35 if BODY else None,
                anatomy=fingerprint,anatomical_parts=len(BODY),neck=False,style_revision=6,
                created_via='live_blender_mcp',geometry=geometry,atlas=atlas,export=exported,
                held_grips=grip_report(),design='balanced_hips_large_feet_one_hand_role_equipment_forged_materials',
                material_emblems=False,mount_leg_segments=8 if row['family']=='cavalry' else 0)
    report['body_part_dimensions']={name:[round(max(v.co[i] for v in obj.data.vertices)-min(v.co[i] for v in obj.data.vertices),6)
                                              for i in range(3)] for name,obj in BODY.items()}
    if render: studio(folder,geometry)
    bpy.data.libraries.write(str(folder/(row['stem']+'.blend')),{SCENE},
                             path_remap='RELATIVE',fake_user=True,compress=True)
    (folder/(row['stem']+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('DWARF_DONE '+json.dumps({'stem':row['stem'],'triangles':geometry['triangles'],'parts':geometry['parts']},ensure_ascii=False),flush=True)


def build_base(render=True):
    global SCENE
    SCENE=new_live_scene('dwarf_base_v1')
    with bpy.context.temp_override(scene=SCENE,view_layer=SCENE.view_layers[0]):
        _build_base_current(render)


def _build_base_current(render=True):
    global PARTS,BODY,ROW,ROOT_OBJ
    PARTS=[]; BODY={}; ROW={'family':'guardian','tier':0}
    stem='dwarf_base_v1'; folder=OUT/'common'; folder.mkdir(exist_ok=True)
    ROOT_OBJ=bpy.data.objects.new(stem,None); SCENE.collection.objects.link(ROOT_OBJ)
    ROOT_OBJ['asset_stage']='shared_anatomy_reference'
    anatomy(); SCENE.view_layers[0].update()
    atlas=pack_and_paint(folder,stem); geometry=geometry_report()
    report={'status':'PASS','anatomy':anatomy_hashes(),'geometry':geometry,'atlas':atlas,
            'export':export(folder,stem,atlas)}
    (folder/(stem+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    if render: studio(folder,geometry)
    bpy.data.libraries.write(str(folder/(stem+'.blend')),{SCENE},path_remap='RELATIVE',fake_user=True,compress=True)


def new_live_scene(stem):
    name=stem+'_MCP_Static_V2'
    previous=bpy.data.scenes.get(name)
    # Recover only our own failed draft roots, including a failed MCP context switch.
    draft_roots=[obj for obj in bpy.data.objects if obj.get('race')=='dwarf' and obj.get('asset_stage')=='static_model_review' and obj.name.startswith(stem)]
    for root in draft_roots:
        if root:
            owned=[]
            def collect(obj):
                for child in obj.children: collect(child)
                owned.append(obj)
            collect(root)
            for obj in owned: bpy.data.objects.remove(obj,do_unlink=True)
    if previous:
        assert previous.get('dwarf_factory_owned') is True
        # Only replace our own rejected/generated scene. Preserve every other open scene.
        for obj in list(previous.objects):
            if len(obj.users_scene)==1: bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.scenes.remove(previous)
    scene=bpy.data.scenes.new(name); scene['dwarf_factory_owned']=True
    bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'
    return scene


if __name__=='__main__':
    raise RuntimeError('Use run_dwarf_troop_mcp.py: live Blender MCP is required.')
