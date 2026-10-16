"""Original elven timber/bronze siege machines, built only in live Blender MCP.

Reuses the game's cuboid/low-poly construction and metric UV packing utilities,
not the existing races' mesh assets. Rigid machinery has authored moving pivots.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix, Quaternion

sys.path.insert(0, str(Path(__file__).resolve().parent))
from elf_siege_assets import ROOT, OUT, WORK, SIEGE_ASSETS
import build_dwarf_troops as geo
from build_elf_troops import export_glb

PALETTE = {'wood': (173,148,100), 'heartwood': (104,89,58),
           'bronze': (145,117,73), 'gold': (195,164,91), 'steel': (169,184,176),
           'iron': (70,83,79), 'rope': (213,201,161), 'leather': (94,76,49),
           'green': (61,103,82), 'ivory': (204,202,173), 'stone': (143,151,138)}
PARTS=[]; BONES={}; SCENE=None; ROOT_OBJ=None; ROW=None; SCALED=1
X=Vector((1,0,0)); Y=Vector((0,1,0)); Z=Vector((0,0,1))


def bone(name, at=(0,0,0), parent='body'):
    BONES[name]=dict(at=Vector(at), parent=parent)


def box(name, at, size, material='wood', group='body'):
    obj=geo.box(name,at,size,material,group)
    obj['region']=material; obj['rig_bone']=group
    return obj


def beam(name, a, b, width=.08, depth=None, material='wood', group='body'):
    obj=geo.beam(name,a,b,width,depth or width,material,group)
    obj['region']=material; obj['rig_bone']=group
    return obj


def cylinder(name, at, radius, length, material='bronze', axis='X', group='body', sides=12, inner=None):
    if inner is None:
        obj=geo.cylinder(name,at,radius,length,material,axis,sides,group)
    else:
        vs=[(r*math.cos(i*math.tau/sides),r*math.sin(i*math.tau/sides),z*length/2)
            for r in (radius,inner) for z in (-1,1) for i in range(sides)]
        fs=[]
        for i in range(sides):
            j=(i+1)%sides
            fs.extend([(i,j,sides+j,sides+i),
                (2*sides+i,3*sides+i,3*sides+j,2*sides+j),
                (i,2*sides+i,2*sides+j,j),
                (sides+i,sides+j,3*sides+j,3*sides+i)])
        obj=geo.mesh(name,vs,fs,material,group)
        obj.location=at
        if axis=='X': obj.rotation_euler[1]=math.pi/2
        if axis=='Y': obj.rotation_euler[0]=math.pi/2
    obj['region']=material; obj['rig_bone']=group
    return obj


def wheel(side, label, at, r, heavy=False):
    group='wheel_'+side+'_'+label; bone(group,at)
    s=1 if side=='l' else -1
    c=Vector(at)
    cylinder('Tire_'+group,c,r,.13 if not heavy else .18,'iron',group=group,inner=r-.036)
    cylinder('Rim_'+group,c,r-.037,.135 if not heavy else .185,'wood',group=group,inner=r-.082)
    cylinder('Hub_'+group,c,.075 if not heavy else .095,.185 if not heavy else .23,'heartwood',group=group,sides=8)
    cylinder('Cap_'+group,c+X*s*(.105 if not heavy else .132),.05 if not heavy else .065,.028,'gold' if heavy else 'bronze',group=group,sides=8)
    for i in range(8):
        v=Vector((0,math.cos(i*math.tau/8),math.sin(i*math.tau/8)))
        beam('Spoke_'+group+'_'+str(i),c+v*.056,c+v*(r-.069),.046 if not heavy else .062,.045,'wood',group)


def chassis(tier):
    width=[.86,1.00,1.09,1.55][tier]; length=[1.29,1.55,1.66,2.40][tier]
    r=[.27,.29,.32,.37][tier]; deck=r+.26
    for s in (-1,1):
        box('BedRail_'+str(s),(s*width/2,0,deck),(.105,length,.16),'wood')
        box('RailBronzeCap_'+str(s),(s*(width/2+.018),0,deck+.082),(.075,length,.016),'gold' if tier==3 else 'bronze')
    axles=[(-length*.36,'front'),(length*.36,'back')]
    if tier==3: axles.insert(1,(0,'middle'))
    for y,label in axles:
        cylinder('Axle_'+label,(0,y,r),.045,width+.35,'iron')
        box('CrossBeam_'+label,(0,y,deck),(width+.12,.14,.17),'heartwood')
        for side,s in (('l',1),('r',-1)):
            box('Bearing_'+side+label,(s*width*.46,y,r+.135),(.13,.16,.22),'bronze')
            wheel(side,label,(s*(width/2+.15),y,r),r,tier==3)
    count=8 if tier<3 else 12
    for i in range(count):
        box('DeckPlank_'+str(i),(0,-length*.43+i*length*.86/(count-1),deck+.10),
            (width+.02,length*.85/count,.048),'wood')
    for s in (-1,1):
        beam('TowShaft_'+str(s),(s*width*.32,-length*.40,deck),(s*width*.32,-length*.60,deck-.045),.07,material='heartwood')
        for y in (-length*.36,length*.36):
            box('BedStrap_'+str((s,y)),(s*(width/2+.06),y,deck),(.035,.09,.18),'bronze' if tier<3 else 'gold')
    return width,length,deck


def winch(at,width=.55,group='loader',gold=False):
    c=Vector(at); bone(group,c)
    cylinder('Windlass_'+group,c,.07,width,'heartwood',group=group)
    for s in (-1,1):
        box('WinchBearing_'+group+str(s),c+Vector((s*(width/2-.03),0,-.04)),(.10,.15,.19),'bronze')
        cylinder('WinchEnd_'+group+str(s),c+X*s*(width/2+.025),.09,.045,'gold' if gold else 'bronze',group=group,sides=8)
    hand=c+X*(width/2+.065)
    beam('Crank_'+group,hand,hand+Z*.15,.035,material='bronze',group=group)
    cylinder('CrankGrip_'+group,hand+Z*.15+X*.045,.03,.12,'wood',group=group,sides=8)
    for i in range(5): cylinder('WoundCord_'+group,c+X*(i-2)*.025,.078,.015,'rope',group=group)


def catapult(w,l,z):
    pivot=Vector((0,-.12,z+.35)); bone('weapon',pivot)
    for s in (-1,1):
        box('TorsionCheek_'+str(s),(s*.34,-.10,z+.23),(.115,.57,.45))
        cylinder('TorsionBundle_'+str(s),(s*.20,-.12,z+.35),.105,.22,'rope')
        cylinder('PivotCap_'+str(s),(s*.425,-.12,z+.35),.09,.045,'bronze')
        beam('StopAFrame_'+str(s),(s*.34,-.49,z+.03),(s*.34,-.37,z+.75),.085)
        box('StopFoot_'+str(s),(s*.34,-.46,z+.15),(.12,.13,.19),'bronze')
    box('PaddedStop',(0,-.37,z+.75),(.83,.105,.12),'leather')
    end=Vector((0,.38,1.58))
    beam('ThrowingArm',pivot-Vector((0,.08,.09)),end,.10,.12,'wood','weapon')
    box('CupBase',end,(.235,.26,.065),'leather','weapon')
    for s in (-1,1): box('CupEdge_'+str(s),end+Vector((s*.105,0,.042)),(.035,.245,.08),'leather','weapon')
    box('LoadedStone',end+Z*.11,(.15,.17,.155),'stone','weapon')
    cylinder('ThrowingAxle',pivot,.046,.87,'bronze',group='weapon')
    winch((0,.48,z+.20))
    beam('LoadCord',end-Vector((0,.06,.02)),(0,.48,z+.26),.014,material='rope',group='weapon')['cable_ends']=('weapon','body')
    box('ToolChest',(-.17,.20,z+.18),(.28,.29,.15),'heartwood')
    box('ClothCover',(-.17,.20,z+.268),(.29,.30,.023),'green')


def trebuchet(w,l,z):
    pivot=Vector((0,-.10,1.40)); bone('weapon',pivot)
    for s in (-1,1):
        for y,label in ((-.62,'Front'),(.59,'Back')):
            beam('AFrame_'+label+str(s),(s*.37,y,z+.02),pivot+X*s*.37,.092,.11)
            box('FrameFoot_'+label+str(s),(s*.37,y,z+.07),(.135,.15,.20),'bronze')
        cylinder('PivotCap_'+str(s),pivot+X*s*.41,.09,.06,'bronze')
        beam('SideBrace_'+str(s),(s*.37,-.53,z+.21),(s*.37,.32,1.06),.048,material='heartwood')
    cylinder('ArmPivot',pivot,.042,.86,'steel',group='weapon')
    long=pivot+Vector((0,.65,.72)); short=pivot-Vector((0,.24,.266))
    beam('CounterweightArm',short,long,.082,.11,'wood','weapon')
    bone('counterweight',short,'weapon')
    for s in (-1,1): beam('WeightHanger_'+str(s),short+X*s*.14,short+Vector((s*.14,0,-.32)),.035,material='bronze',group='counterweight')
    box('Counterweight',short-Z*.38,(.40,.30,.31),'stone','counterweight')
    for s in (-1,1): box('WeightBand_'+str(s),short+Vector((s*.135,0,-.38)),(.035,.32,.34),'bronze','counterweight')
    pouch=long+Vector((0,.055,-.26)); bone('sling',long,'weapon')
    for s in (-1,1): beam('SlingCord_'+str(s),long+X*s*.062,pouch+X*s*.062,.014,material='rope',group='sling')
    box('SlingPouch',pouch,(.19,.20,.052),'leather','sling')
    box('SlingStone',pouch+Z*.09,(.15,.16,.15),'stone','sling')
    box('SlingTrough',(0,.15,z+.16),(.23,.83,.072),'heartwood')
    winch((0,.56,z+.26))
    box('GreenApron',(0,-.75,z+.04),(.67,.026,.21),'green')
    for x in (-.28,.28): box('ApronClasp_'+str(x),(x,-.771,z+.125),(.065,.028,.055),'bronze')


def bombard(w,l,z):
    pivot=Vector((0,-.10,1.19)); bone('weapon',pivot)
    for s in (-1,1):
        beam('GunCheek_'+str(s),(s*.32,-.50,z+.13),(s*.32,.29,1.26),.17,.18)
        box('CheekFoot_'+str(s),(s*.32,-.32,z+.18),(.21,.69,.18),'heartwood')
        cylinder('Trunnion_'+str(s),pivot+X*s*.31,.084,.30,'bronze')
        cylinder('TrunnionCap_'+str(s),pivot+X*s*.485,.10,.035,'steel')
        box('GreenGuard_'+str(s),(s*.535,-.02,z+.21),(.045,1.03,.31),'green')
        for y in (-.40,.38): box('GuardClasp_'+str((s,y)),(s*.562,y,z+.21),(.025,.065,.32),'bronze')
    a=Vector((0,.49,1.04)); b=Vector((0,-.98,1.39))
    obj=geo.barrel('BronzeGun',a,b,.235,'bronze'); obj['rig_bone']='weapon'; obj['region']='bronze'; obj['future_bone']='weapon'
    axis=(b-a).normalized()
    for i,t in enumerate((.10,.53,1.02,1.49)):
        band=cylinder('GunBand_'+str(i),a+axis*t,.253,.067,'steel',axis='Z',group='weapon',inner=.233)
        band.rotation_euler=obj.rotation_euler
    cylinder('Breech',a-axis*.025,.234,.065,'bronze',axis='Z',group='weapon').rotation_euler=obj.rotation_euler
    box('TouchHole',(0,.38,1.295),(.056,.10,.043),'iron','weapon')
    box('SlideRail',(0,.04,z+.185),(.36,1.15,.105),'steel')
    box('RecoilShoe',(0,.16,z+.253),(.34,.49,.055),'bronze','weapon')
    box('ElevationWedge',(0,.41,z+.31),(.29,.31,.14),'heartwood')
    winch((.13,.63,z+.28),.35)
    box('PowderLocker',(-.24,.60,z+.21),(.25,.26,.26),'heartwood')
    box('LeatherLid',(-.24,.60,z+.345),(.27,.28,.03),'leather')


def colossus(w,l,z):
    # Two vertical torsion bundles, swept timber limbs, a loaded bolt track and
    # visible tension cords. No boiler, cannon tube, tower or magical ornament.
    bridge_y=-.38; pivot_z=1.58
    box('TorsionBridge',(0,bridge_y,1.30),(1.74,.25,.24),'heartwood')
    for s,side in ((-1,'r'),(1,'l')):
        center=Vector((s*.68,bridge_y,pivot_z)); group='bow_'+side; bone(group,center)
        beam('BridgeStrut_'+side,(s*.69,-.75,z+.08),(s*.69,bridge_y,1.26),.14)
        cylinder('TorsionRope_'+side,(s*.68,bridge_y,1.63),.16,.54,'rope',axis='Z')
        for zz in (1.36,1.91):
            cylinder('TorsionCap_'+side,(s*.68,bridge_y,zz),.215,.10,'gold',axis='Z')
        for y in (bridge_y-.20,bridge_y+.20):
            box('TorsionPost_'+side+str(y),(s*.68,y,1.63),(.075,.09,.64),'wood')
            box('PostFerrule_'+side+str(y),(s*.68,y,1.915),(.095,.11,.085),'gold')
        points=[center,center+Vector((s*.28,.15,.025)),center+Vector((s*.52,.35,.04)),center+Vector((s*.68,.48,.05))]
        for i,(aa,bb) in enumerate(zip(points,points[1:])):
            beam('BowLimb_'+side+str(i),aa,bb,.12-i*.018,.13-i*.02,'wood',group)
            beam('BowLamination_'+side+str(i),aa-Z*.055,bb-Z*.055,.075-i*.010,.024,'heartwood',group)
        box('BowRootBand_'+side,center+X*s*.06,(.18,.17,.13),'gold',group)
        box('BowTipShoe_'+side,points[-1],(.095,.11,.14),'gold',group)
        cable=beam('Bowstring_'+side,points[-1],(0,.90,1.63),.023,material='rope',group=group)
        cable['cable_ends']=(group,'sled')
    for s in (-1,1):
        box('ArrowRail_'+str(s),(s*.13,-.07,1.55),(.13,2.27,.15),'heartwood')
        box('RailSteelEdge_'+str(s),(s*.085,-.07,1.638),(.018,2.27,.025),'steel')
        beam('RearTrackBrace_'+str(s),(s*.45,.97,z+.07),(s*.13,.80,1.45),.105)
        box('FlankPanel_'+str(s),(s*.80,.07,z+.11),(.043,1.64,.35),'green')
        for y in (-.72,.04,.80): box('FlankGoldStrap_'+str((s,y)),(s*.827,y,z+.11),(.026,.055,.37),'gold')
    box('ForwardTrackBed',(0,-.99,1.43),(.45,.17,.14),'bronze')
    bone('sled',(0,.90,1.63))
    box('TriggerSled',(0,.89,1.645),(.18,.22,.09),'gold','sled')
    box('LoadedBolt',(0,-.04,1.70),(.075,1.78,.075),'wood','sled')
    beam('BoltSteelHead',(0,-.99,1.70),(0,-1.16,1.70),.12,.075,'steel','sled')
    for s in (-1,1): beam('BoltFeather_'+str(s),(s*.035,.74,1.70),(s*.13,.83,1.70),.028,.095,'ivory','sled')
    winch((0,1.005,1.29),.89,gold=True)
    beam('DrawCord',(0,.94,1.63),(0,1.005,1.37),.018,material='rope',group='sled')['cable_ends']=('sled','body')
    box('WinchPlatform',(0,.91,1.12),(1.17,.38,.10),'wood')
    for s in (-1,1):
        box('ToolLocker_'+str(s),(s*.49,.64,z+.19),(.29,.43,.26),'heartwood')
        box('LockerLeather_'+str(s),(s*.49,.64,z+.329),(.30,.44,.025),'leather')
        beam('StoredBolt_'+str(s),(s*.40,.49,z+.40),(s*.40,-.56,z+.40),.055,material='wood')


def paint_tile(obj,face,w,h,row):
    material=obj['surface']; base=np.array(PALETTE[material],dtype=np.int16)
    seed=int(hashlib.sha256((obj['part']+str(face.index)).encode()).hexdigest()[:8],16)
    rng=np.random.default_rng(seed)
    yy,xx=np.mgrid[:h,:w]
    clusters=rng.integers(-2,3,(math.ceil(h/3),math.ceil(w/3)))
    tile=np.clip(base+clusters[yy//3,xx//3,None],0,255)
    edge=np.minimum.reduce([xx,yy,w-1-xx,h-1-yy])
    if material in ('wood','heartwood'):
        across=xx if h>=w else yy
        along=yy if h>=w else xx
        grain=(across+((along//13)%2))%9==3
        tile[grain]=np.clip(base-12,0,255)
        tile[edge==0]=np.clip(base-15,0,255)
    elif material in ('bronze','gold','steel','iron'):
        tile[edge==0]=np.clip(base-24,0,255)
        tile[edge==1]=np.clip(base+13,0,255)
        if w>9 and h>9 and obj['part'].startswith(('Guard','Flank','BedStrap','PostFerrule')):
            for x,y in ((3,3),(w-4,3),(3,h-4),(w-4,h-4)):
                tile[y:y+2,x:x+2]=np.clip(base+27,0,255)
    elif material=='rope':
        tile[(xx+yy)%5==0]=np.clip(base-22,0,255)
    elif material in ('green','ivory','leather'):
        tile[edge==0]=np.clip(base-14,0,255)
        tile[(edge==2)&((xx+yy)%4==0)]=np.clip(base+17,0,255)
    if obj['part']=='BronzeGun' and face.index>=obj.get('bore_faces_start',9999):
        tile[:]=(39,44,40)
    return tile.astype(np.float32)/255


def materials(folder,stem):
    previous_painter=geo.paint_tile
    try:
        geo.paint_tile=paint_tile
        atlas=geo.pack_and_paint(folder,stem)
    finally:
        geo.paint_tile=previous_painter
    image=bpy.data.images[stem+'_albedo']
    palette_materials={}
    for region in sorted({obj['surface'] for obj in PARTS}):
        mat=bpy.data.materials.new(stem+'_'+region); mat.use_nodes=True
        shader=mat.node_tree.nodes.get('Principled BSDF')
        metal=region in ('bronze','gold','steel','iron')
        shader.inputs['Metallic'].default_value=.72 if metal else 0
        shader.inputs['Roughness'].default_value=.55 if metal else .92
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image; tex.interpolation='Closest'
        mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        palette_materials[region]=mat
    for obj in PARTS:
        obj.data.materials.clear(); obj.data.materials.append(palette_materials[obj['surface']])
    return atlas


def create_rig():
    data=bpy.data.armatures.new(ROW['stem']+'_Skeleton')
    rig=bpy.data.objects.new(ROW['stem']+'_Rig',data); SCENE.collection.objects.link(rig); rig.parent=ROOT_OBJ
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name,info in BONES.items():
        b=data.edit_bones.new(name); b.head=info['at']*SCALED; b.tail=b.head+Y*.10
        if info['parent']: b.parent=data.edit_bones[info['parent']]
    bpy.ops.object.mode_set(mode='OBJECT'); data.display_type='STICK'
    for obj in PARTS:
        # Store global rest coordinates in every editable part, so skinning and
        # rigid pivots share exactly one transform convention.
        transform=obj.matrix_world.copy()
        if obj.get('cable_ends'):
            start,end=obj['cable_ends']
            for group in {start,end}: obj.vertex_groups.new(name=group)
            for vertex in obj.data.vertices:
                obj.vertex_groups[end if vertex.co.z>0 else start].add([vertex.index],1,'REPLACE')
        else:
            obj.vertex_groups.new(name=obj['rig_bone']).add(list(range(len(obj.data.vertices))),1,'REPLACE')
        obj.data.transform(transform)
        for vertex in obj.data.vertices: vertex.co*=SCALED
        obj.matrix_world=Matrix.Identity(4); obj.parent=rig
        modifier=obj.modifiers.new('Elf_Rigid_Machinery','ARMATURE'); modifier.object=rig
    for b in rig.pose.bones: b.rotation_mode='QUATERNION'
    rig.animation_data_create()
    return rig


def animate(rig):
    clips={}; offset=1; tier=ROW['tier']
    roles=['Idle','Walk','Attack','DemolitionAmmo']+(['PreparedBombardment'] if tier else [])
    for role in roles:
        end={'Idle':49,'Walk':49,'Attack':49,'DemolitionAmmo':73,'PreparedBombardment':97}[role]
        name=ROW['prefix']+'_'+role; action=bpy.data.actions.new(name); action.use_fake_user=True
        rig.animation_data.action=action
        impact=round((end-1)*.56)+1
        for frame in range(1,end+1):
            t=(frame-1)/(end-1); envelope=math.sin(math.pi*t)**2
            shot=max(0,1-abs(t-.56)/.17); shot=shot*shot*(3-2*shot)
            heavy=1 if role=='Attack' else 1.17 if role=='DemolitionAmmo' else 1.3
            rotations={}; locations={}
            if role=='Walk':
                for name_b in BONES:
                    if name_b.startswith('wheel_'): rotations[name_b]=Quaternion(X,-math.tau*t)
            elif role not in ('Idle','Walk'):
                rotations['loader']=Quaternion(X,.75*envelope*math.sin(math.tau*2*t))
                if tier<2:
                    angle=(.95*shot*heavy-.07*envelope)
                    rotations['weapon']=Quaternion(X,angle)
                    if tier==1:
                        rotations['counterweight']=Quaternion(X,-angle)
                        rotations['sling']=Quaternion(X,-angle*.75)
                elif tier==2:
                    locations['weapon']=Vector((0,.15*shot*heavy,0))*SCALED
                    rotations['weapon']=Quaternion(X,-.035*envelope)
                else:
                    rotations['bow_l']=Quaternion(Z,-.58*shot*heavy)
                    rotations['bow_r']=Quaternion(Z,.58*shot*heavy)
                    locations['sled']=Vector((0,-1.04*shot*heavy,0))*SCALED
            for b in rig.pose.bones:
                # All rest bone axes are world +Y. Local rotations therefore
                # use world axes while preserving each hierarchical hinge.
                q=rotations.get(b.name,Quaternion())
                b.matrix_basis=Matrix.Translation(locations.get(b.name,Vector()))@q.to_matrix().to_4x4()
                b.keyframe_insert('location',frame=frame,group=b.name)
                b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation='LINEAR'
        action['loop']=role in ('Idle','Walk'); action['impact_frame']=impact if role not in ('Idle','Walk') else -1
        action.pose_markers.new('LOOP_START' if action['loop'] else 'START').frame=1
        action.pose_markers.new('LOOP_END' if action['loop'] else 'RECOVERED').frame=end
        if not action['loop']: action.pose_markers.new('IMPACT').frame=impact
        clips[ROW['prefix']+'_'+role]=dict(action=action,start=offset,end=end,seconds=(end-1)/24,impact_frame=impact,loop=action['loop'])
        offset+=end+8
    rig.animation_data.action=None
    for name,info in clips.items():
        track=rig.animation_data.nla_tracks.new(); track.name=name
        strip=track.strips.new(name,info['start'],info['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
        SCENE.timeline_markers.new(name,frame=info['start'])
    SCENE.frame_start=1; SCENE.frame_end=offset-8; SCENE.frame_set(1)
    return clips


def validate_motion(rig,clips):
    result={}
    for name,info in clips.items():
        for tr in rig.animation_data.nla_tracks: tr.mute=True
        rig.animation_data.action=info['action']
        poses=[]; minimum=99.0
        for frame in sorted({1,info['end']//4,info['end']//2,info['impact_frame'],info['end']*3//4,info['end']}):
            SCENE.frame_set(frame); bpy.context.view_layer.update()
            poses.append({b.name:b.matrix.copy() for b in rig.pose.bones})
            deps=bpy.context.evaluated_depsgraph_get()
            for obj in PARTS:
                evaluated=obj.evaluated_get(deps)
                for v in evaluated.data.vertices:
                    p=evaluated.matrix_world@v.co
                    assert all(math.isfinite(value) for value in p), (name,obj.name)
                    minimum=min(minimum,p.z)
        seam=max(abs(poses[0][b][i][j]-poses[-1][b][i][j]) for b in poses[0] for i in range(4) for j in range(4))
        # A rotating wheel closes its seam by exactly one revolution.
        assert seam<.0001,(name,seam)
        assert minimum>-.004,(name,minimum)
        movement=max(abs(p[b][i][j]-poses[0][b][i][j]) for p in poses[1:] for b in p for i in range(4) for j in range(4))
        assert movement>.1 if not name.endswith('_Idle') else movement<.00001,(name,movement)
        result[name]=dict(finite=True,minimum_z=minimum,recovery_error=seam,movement=movement,samples=len(poses))
    rig.animation_data.action=None
    for tr in rig.animation_data.nla_tracks: tr.mute=False
    SCENE.frame_set(1); bpy.context.view_layer.update()
    return result


def studio(folder,geometry):
    scene=SCENE; scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=640; scene.render.resolution_y=640; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    scene.world=bpy.data.worlds.new(ROW['stem']+'_World'); scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.17,.21,.20,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
    ground_data=bpy.data.meshes.new('ElfSiegeStudioGround')
    ground_data.from_pydata([(-20,-20,-.01),(20,-20,-.01),(20,20,-.01),(-20,20,-.01)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new('ElfSiegeStudioGround',ground_data); scene.collection.objects.link(floor)
    mat=bpy.data.materials.new('ElfSiegeGround'); mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.10,.13,.12,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; floor.data.materials.append(mat)
    for name,at,power,size in [('Key',(-4,-5,8),1600,6),('Fill',(6,-2,5),1100,5),('Rim',(0,6,7),1400,5)]:
        data=bpy.data.lights.new('ElfSiege_'+name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
        obj=bpy.data.objects.new(data.name,data); scene.collection.objects.link(obj); obj.location=at
        obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
    camera_data=bpy.data.cameras.new('ElfSiegeCamera'); camera_data.type='ORTHO'
    camera_data.ortho_scale=max(3.0,max(geometry['dimensions'])*1.32)
    camera=bpy.data.objects.new('ElfSiegeCamera',camera_data); scene.collection.objects.link(camera); scene.camera=camera
    center=(Vector(geometry['bounds_min'])+Vector(geometry['bounds_max']))/2
    dest=folder/'previews'; dest.mkdir(exist_ok=True)
    for name,at in {'three_quarter':(6,-12,6.4),'front':(0,-12,2.6),'game_top':(5,-7,11),'back':(-6,12,6)}.items():
        camera.location=center+Vector(at); camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(dest/(name+'.png')); bpy.ops.render.render(write_still=True)
    camera.location=center+Vector((6,-12,6.4)); camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()


def build(row):
    global PARTS,BONES,SCENE,ROOT_OBJ,ROW,SCALED
    ROW=row; PARTS=[]; BONES={}; SCALED=1
    if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
    SCENE=bpy.data.scenes.new(row['stem']+'_Scene'); bpy.context.window.scene=SCENE; SCENE.render.fps=24
    ROOT_OBJ=bpy.data.objects.new(row['stem']+'_Root',None); SCENE.collection.objects.link(ROOT_OBJ)
    ROOT_OBJ['race']='elf'; ROOT_OBJ['family']='siege'; ROOT_OBJ['tier']=row['tier']; ROOT_OBJ['design']=row['design']
    geo.SCENE=SCENE; geo.ROOT_OBJ=ROOT_OBJ; geo.PARTS=PARTS; geo.BODY={}; geo.ROW=row
    bone('root',parent=None); bone('body',parent='root')
    w,l,z=chassis(row['tier'])
    (catapult,trebuchet,bombard,colossus)[row['tier']](w,l,z)
    bpy.context.view_layer.update()
    high=max((obj.matrix_world@v.co).z for obj in PARTS for v in obj.data.vertices)
    SCALED=row['character_height_m']/high
    folder=OUT/row['stem']; folder.mkdir(parents=True,exist_ok=True)
    # UVs use final metric geometry, not an atlas stretched by a scaled parent.
    for obj in PARTS:
        obj.data.transform(Matrix.Scale(SCALED,4)); obj.location*=SCALED
    atlas=materials(folder,row['stem'])
    for obj in PARTS:
        obj.data.transform(Matrix.Scale(1/SCALED,4)); obj.location/=SCALED
    rig=create_rig()
    bpy.context.view_layer.update(); geometry=geo.geometry_report()
    clips=animate(rig); motion=validate_motion(rig,clips)
    studio(folder,geometry)
    exported=export_glb(row,SCENE,PARTS,rig,ROOT_OBJ,folder)
    actual={clip['name']:max(exported['accessors'][sampler['input']]['max'][0] for sampler in clip['samplers']) for clip in exported['animations']}
    expected={name:info['seconds'] for name,info in clips.items()}
    assert actual.keys()==expected.keys() and all(abs(actual[name]-expected[name])<.0001 for name in expected)
    SCENE.frame_set(1)
    SCENE['description']=row['name']+' — practical ash timber, bronze fittings, rigid animated siege engineering.'
    bpy.data.libraries.write(str(folder/(row['stem']+'.blend')),{SCENE},path_remap='RELATIVE',fake_user=True,compress=True)
    report=row|dict(status='PASS',pipeline='Open Blender MCP localhost:9876',revision='elf_siege_v1',
        geometry=geometry,texture=atlas,rig=dict(bones=list(BONES),rigid_weights=True,
        part_bones={obj['part']:obj['rig_bone'] for obj in PARTS},cord_endpoints_skinned=True),
        clips=actual,motion=motion,height_convention='Highest functional rest part: 1.80 m conventional / 2.00 m legendary',
        material_palette=PALETTE,materials=len(exported['materials']),real_material_properties=True,
        animation_contract='Human-equivalent clip names, durations and techniques; mechanism-specific choreography',
        anatomy_parts=0,crew=False)
    (folder/(row['stem']+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('ELF_SIEGE_DONE',row['stem'],geometry['parts'],geometry['triangles'],len(actual),flush=True)
    return dict(stem=row['stem'],scene=SCENE.name,triangles=geometry['triangles'],clips=len(actual),status='PASS')
