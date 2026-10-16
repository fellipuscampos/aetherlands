"""Run only in live Blender through MCP. Copy approved geometry, never rebuild humans.

STAGE build/preview/export. INDEX selects one unit. Each asset is completed before
the next is started by run_human_rogue_siege.py. No external Blender process.
"""
import bpy, bmesh, math, json, hashlib, ast
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
PIPE=ROOT/'tools/art_pipeline'
import sys
if str(PIPE) not in sys.path: sys.path.insert(0,str(PIPE))
from human_rogue_siege_assets import ASSETS, roles
A=ASSETS[INDEX]; NAME=A['name']; PREFIX=A['prefix']; OUT=ROOT/'assets/generated/humans'/A['stem']
SOURCE=ROOT/'art_source'/A['stem']; KEY='human_rogue_siege_'+A['stem']

def load_scene(stem):
    info=next((a for a in ASSETS if a['stem']==stem),None)
    name=info['name'] if info else 'Warrior_V1'
    if name not in bpy.data.scenes:
        with bpy.data.libraries.load(str(ROOT/'assets/generated/humans'/stem/(stem+'.blend'))) as (src,dst):
            assert name in src.scenes; dst.scenes=[name]
    return bpy.data.scenes[name]

def action_signature(action):
    records=[]
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    records.append([fc.data_path,fc.array_index,[[round(k.co.x,5),round(k.co.y,7)] for k in fc.keyframe_points]])
    return hashlib.sha256(json.dumps(sorted(records),separators=(',',':')).encode()).hexdigest()

if STAGE=='build':
    if NAME in bpy.data.scenes and not (SOURCE/(A['stem']+'_rigged.blend')).exists() and not (OUT/(A['stem']+'.glb')).exists():
        # Retry only this unsaved generated draft; never touch an approved/source scene.
        failed=bpy.data.scenes[NAME]
        for o in list(failed.objects): bpy.data.objects.remove(o,do_unlink=True)
        for c in list(failed.collection.children): bpy.data.collections.remove(c)
        bpy.data.scenes.remove(failed)
        for store in (bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.cameras,bpy.data.lights,bpy.data.worlds,bpy.data.armatures):
            for block in list(store):
                if block.name.startswith(NAME+'_') and block.users==0: store.remove(block)
    assert NAME not in bpy.data.scenes, 'Scene exists: preserve manual edits; resume subsequent stage.'
    assert not (OUT/(A['stem']+'.glb')).exists(), 'Finished asset exists; preserve it.'
    OUT.mkdir(parents=True,exist_ok=True); SOURCE.mkdir(parents=True,exist_ok=True)
    (SOURCE/'.gdignore').write_text('',encoding='utf-8')
    scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
    collections={}
    for label in ['01_BODY','02_HEAD','03_ARMS','04_LEGS','05_GEAR','06_CLOTH','07_STUDIO']:
        c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
    parts=[]; X=Vector((1,0,0)); Y=Vector((0,1,0)); Z=Vector((0,0,1))
    CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
    base=(PIPE/'warrior_model.py').read_text(encoding='utf-8')
    tree=ast.parse(base)
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in ('mesh','fbox','box','beam','check_coplanar'):
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<approved-warrior-primitives>','exec'))
    root=bpy.data.objects.new(NAME+'_ROOT',None); scene.collection.objects.link(root)
    inherited={}; copied=[]; predecessor=None
    if A['parent']:
        predecessor=load_scene(A['parent']); bpy.context.window.scene=scene
        oldrig=next(o for o in predecessor.objects if o.type=='ARMATURE')
        if A['family']=='rogue' and A['level']>0:
            for track in oldrig.animation_data.nla_tracks:
                role=track.name.split('_')[-1]
                if role in roles(A): inherited[role]=track.strips[0].action
        for original in predecessor.objects:
            if original.type!='MESH' or original.get('region') in (None,'studio'): continue
            if A['family']=='siege' and not original.get('chassis'): continue
            if A['level']==0 and (original.get('part')=='Cap' or original.get('part','').startswith('Axe')): continue
            o=original.copy(); o.data=original.data.copy(); o.name=NAME+'_'+o['part']; o.data.name=o.name+'_Mesh'
            o.animation_data_clear(); o.parent=root; o.matrix_parent_inverse=Matrix.Identity(4)
            for m in list(o.modifiers): o.modifiers.remove(m)
            o.vertex_groups.clear(); collections['01_BODY'].objects.link(o); parts.append(o); copied.append(o['part'])
    def part(n): return next(o for o in parts if o['part']==n)
    def avg(v): return sum(v,Vector())/len(v)
    def center(n): return avg([v.co for v in part(n).data.vertices])
    def discard(prefix):
        for o in list(parts):
            if o['part'].startswith(prefix): parts.remove(o); bpy.data.objects.remove(o,do_unlink=True)
    def equipment(n,c,s,reg='dark_leather',bone='hips'): return box(n,c,s,reg,bone,'05_GEAR')
    def dagger(side,elite=False):
        G=center('Hand_'+side); V=Vector((0,-.38,.925)).normalized()
        beam('DaggerGrip_'+side,G-V*.06,G+V*.06,.045,.045,'dark_leather','hand_'+side,'05_GEAR')
        fbox('DaggerGuard_'+side,G+V*.08,X,V,V.cross(X),(.14,.03,.035),'iron','hand_'+side,'05_GEAR')
        beam('DaggerBlade_'+side,G+V*.095,G+V*(.37 if elite else .31),.075 if elite else .06,.028,'blade','hand_'+side,'05_GEAR',end_width=.008,end_depth=.008,side=X)
    if A['family']=='rogue':
        if A['level']==0:
            head=part('Head'); lo=min(v.co.z for v in head.data.vertices); oldhi=max(v.co.z for v in head.data.vertices)
            for v in head.data.vertices: v.co.z=lo+(v.co.z-lo)*(1.8-lo)/(oldhi-lo)
            head['region']='rogue_hood'
            for n in ('Chest','Belly','Shoulder_l','Shoulder_r','UpperArm_l','UpperArm_r'):
                part(n)['region']='jerkin'
            dagger('r')
            # Mantle meets the back of the chest; its width differs from the body by 20 mm.
            beam('ShortMantle',(0,.145,1.465),(0,.16,1.055),.40,.035,'cloak','chest','06_CLOTH',end_width=.35,side=X)
            equipment('BeltPouch',(.245,.01,.975),(.095,.17,.13))
        elif A['level']==1:
            equipment('ToolSatchel',(-.27,.045,1.02),(.15,.18,.24))
            beam('SatchelStrap',(-.21,.135,1.43),(-.265,.14,1.02),.045,.025,'team','chest','06_CLOTH',side=X)
            for i in range(3):
                beam('Tool_'+str(i),(-.322+i*.044,-.055,1.105),(-.322+i*.044,-.055,1.22),.022,.023,'iron','hips','05_GEAR')
            equipment('ToolClasp',(-.27,-.058,.995),(.065,.022,.035),'iron')
        elif A['level']==2:
            dagger('l',True)
            discard('ShortMantle')
            beam('SplitMantle_l',(.12,.132,1.465),(.15,.18,.92),.18,.035,'cloak','chest','06_CLOTH',end_width=.145,side=X)
            beam('SplitMantle_r',(-.12,.132,1.465),(-.15,.18,.92),.18,.035,'cloak','chest','06_CLOTH',end_width=.145,side=X)
            equipment('ShoulderPlate',(-.285,0,1.47),(.195,.24,.045),'iron','chest')
            equipment('ThrowingKnifeCase',(.255,.01,1.08),(.085,.14,.095),'iron')
        else:
            discard('SplitMantle'); discard('Dagger'); dagger('r',True); dagger('l',True)
            for t,side in [('l',1),('r',-1)]:
                beam('RoyalMantle_'+t,(side*.125,.132,1.465),(side*.18,.25,.56),.20,.035,'royal_cloak','chest','06_CLOTH',end_width=.205,side=X)
            equipment('Gorget',(0,-.14,1.455),(.25,.035,.035),'gold','chest')
            equipment('BeltSeal',(0,-.138,.98),(.08,.02,.08),'gold')
            root.scale=(2/1.8,)*3
        # Trousers and boots remain the approved Warrior pieces, with their authored joints.
    else:
        def cylinder(n,c,r,depth,reg,bone,axis=X,N=8,inner=None):
            axis=Vector(axis).normalized(); u=axis.cross(Z)
            if u.length<.01: u=axis.cross(Y)
            u.normalize(); v=axis.cross(u); C=Vector(c)
            vv=[C+axis*offset+u*math.cos(i*math.tau/N)*rr+v*math.sin(i*math.tau/N)*rr for rr in ([r] if inner is None else [r,inner]) for offset in (-depth/2,depth/2) for i in range(N)]
            ff=[]
            for i in range(N): j=(i+1)%N; ff.append((i,j,N+j,N+i))
            if inner is None: ff += [tuple(reversed(range(N))),tuple(range(N,2*N))]
            else:
                for i in range(N):
                    j=(i+1)%N; ff += [(2*N+i,3*N+i,3*N+j,2*N+j),(i,2*N+i,2*N+j,j),(N+i,N+j,3*N+j,3*N+i)]
            return mesh(n,vv,ff,reg,bone,'05_GEAR',Z)
        if A['level']==0:
            equipment('Chassis',(0,0,.47),(.76,1.32,.16),'wood','body')['chassis']=True
            for side,t in ((1,'l'),(-1,'r')):
                for y,t2 in ((-.45,'front'),(.45,'back')):
                    b='wheel_'+t+'_'+t2
                    cylinder('Wheel_'+t+'_'+t2,(side*.48,y,.26),.26,.12,'wheel',b)['chassis']=True
                    cylinder('Hub_'+t+'_'+t2,(side*.548,y,.26),.075,.022,'iron',b)['chassis']=True
                equipment('ChassisRail_'+t,(side*.34,0,.615),(.09,1.35,.13),'wood','body')['chassis']=True
            for y,label in ((-.45,'Front'),(.45,'Back')):
                cylinder('Axle'+label,(0,y,.26),.045,1.05,'iron','body')['chassis']=True
                for side,t in ((1,'l'),(-1,'r')):
                    equipment('Bearing_'+label+'_'+t,(side*.32,y,.345),(.10,.14,.19),'iron','body')['chassis']=True
        else:
            for o in parts: o['rig_bone']='body' if not o['part'].startswith(('Wheel_','Hub_')) else o['rig_bone']
        equipment('HumanPennant',(0,.65,.83),(.38,.045,.36),'team','body')
        equipment('PennantCrossbar',(0,.65,1.015),(.42,.035,.035),'iron','body')
        equipment('PennantBracket',(0,.675,.77),(.045,.055,.50),'iron','body')
        if A['level']<=1:
            H=Vector((0,.08,.94 if A['level']==0 else 1.12))
            for side,t in ((1,'l'),(-1,'r')):
                if A['level']==0:
                    equipment('Upright_'+t,(side*.255,.08,.785),(.10,.13,.49),'wood','body')
                else:
                    beam('AframeFront_'+t,(side*.25,-.40,.66),(side*.25,.08,1.25),.112,.10,'wood','body','05_GEAR')
                    beam('AframeBack_'+t,(side*.25,.54,.66),(side*.25,.08,1.25),.10,.10,'wood','body','05_GEAR')
            cylinder('Pivot',H,.07,.70,'iron','body')
            end=Vector((0,.60,1.60 if A['level']==0 else 1.61))
            beam('ThrowArm',H-Vector((0,.28,.12)),end,.105,.11,'wood','weapon','05_GEAR',side=X)
            equipment('Spoon',end,(.25,.24,.08),'wood','weapon')
            cylinder('ReadyStone',end+Vector((0,0,.105)),.055,.14,'stone','weapon',axis=Z)
            if A['level']==0:
                cylinder('TorsionDrum',(0,.08,.89),.11,.42,'rope','body')
            else:
                equipment('Counterweight',(0,-.29,.86),(.38,.30,.30),'stone','counterweight')
                beam('CounterweightHanger',H-Vector((0,.24,.11)),(0,-.29,.98),.055,.055,'iron','weapon','05_GEAR')
                for side,t in ((1,'l'),(-1,'r')):
                    beam('Sling_'+t,end+Vector((side*.10,0,.035)),(side*.07,.62,1.745),.018,.018,'rope','weapon','05_GEAR')
            equipment('Windlass',(0,.46,.80),(.50,.085,.085),'wood','loader')
            beam('WinchRope',(0,.46,.845),H+Vector((0,0,-.055)),.018,.018,'rope','body','05_GEAR')
            # Attached crossbar sets the common machine height without decorative floating parts.
            equipment('RearMast',(.31,.63,1.16),(.055,.055,1.28),'wood','body')
            equipment('Standard',(.31,.60,1.55),(.24,.045,.35),'team','body')
        else:
            H=Vector((0,0,.96))
            if A['level']==2:
                for side,t in ((1,'l'),(-1,'r')):
                    equipment('GunCheek_'+t,(side*.22,0,.78),(.13,.75,.34),'wood','body')
                cylinder('Trunnion',H,.075,.65,'iron','body')
                barrelaxis=Vector((0,-1,.14)).normalized()
                cylinder('CannonTube',H+barrelaxis*.08,.205,.88,'iron','weapon',axis=barrelaxis,inner=.115)
                for off,n in ((-.26,'Breech'),(.36,'Muzzle')):
                    cylinder(n+'Band',H+barrelaxis*off,.224,.07,'iron_band','weapon',axis=barrelaxis,inner=.205)
                cylinder('BreechCap',H-barrelaxis*.38,.204,.06,'iron','weapon',axis=barrelaxis)
                equipment('ElevationScrew',(0,.31,.80),(.06,.10,.28),'iron','body')
                equipment('ElevationBase',(0,.31,.60),(.11,.12,.18),'iron','body')
                equipment('PowderChest',(0,.48,.78),(.42,.24,.23),'dark_leather','body')
                equipment('RearMast',(.31,.63,1.16),(.055,.055,1.28),'wood','body')
                equipment('Standard',(.31,.60,1.55),(.24,.045,.35),'team','body')
            else:
                # Six wheels require wider axle spacing; keep their bottom on the ground.
                for o in parts:
                    if o['part'].startswith(('Wheel_','Hub_','Axle','Bearing_')):
                        c=center(o['part'])
                        if abs(c.y)>.4:
                            for v in o.data.vertices: v.co.y += math.copysign(.11,c.y)
                            o.data.update()
                equipment('ArmoredHull',(0,0,.90),(.85,1.22,.52),'iron','body')
                for side,t in ((1,'l'),(-1,'r')):
                    equipment('HullBlue_'+t,(side*.436,0,.92),(.025,1.12,.27),'team','body')
                    cylinder('MiddleWheel_'+t,(side*.48,0,.26),.26,.12,'wheel','wheel_'+t+'_middle')
                    cylinder('MiddleHub_'+t,(side*.548,0,.26),.075,.022,'iron','wheel_'+t+'_middle')
                cylinder('MiddleAxle',(0,0,.26),.045,1.05,'iron','body')
                for side,t in ((1,'l'),(-1,'r')):
                    equipment('Bearing_Middle_'+t,(side*.32,0,.345),(.10,.14,.19),'iron','body')['chassis']=True
                equipment('Turret',(0,.03,1.28),(.65,.61,.30),'iron','weapon')
                for side,t in ((1,'l'),(-1,'r')):
                    axis=Vector((0,-1,.08)).normalized(); C=Vector((side*.20,-.19,1.36))
                    cylinder('TwinGun_'+t,C,.145,.84,'iron','weapon',axis=axis,inner=.08)
                    cylinder('TwinRim_'+t,C+axis*.36,.164,.07,'gold','weapon',axis=axis,inner=.145)
                equipment('TurretCrest',(0,.04,1.67),(.17,.17,.48),'team','weapon')
                equipment('CrestCrown',(0,.04,1.955),(.22,.22,.09),'gold','weapon')
                equipment('ElevatingGear',(0,.35,1.255),(.11,.09,.27),'iron','loader')
                # Chassis is genuinely inherited; armor and the third axle are new in the legendary stage.
            equipment('LoadingCrank',(0,.48,1.03),(.30,.04,.045),'wood','loader')
            equipment('LoadingSpindle',(0,.48,.92),(.045,.045,.24),'iron','loader')
        bodyheight=max(v.co.z for o in parts for v in o.data.vertices)
        assert abs(bodyheight-A['height'])<.0002, (bodyheight,A['height'])
    # Reuse the approved metric UV projector and studio, not the Warrior model constructor.
    exec(base[base.index('DENSITY=64; PAD=2; islands=[]'):base.index("scene['description']")])
    for o in parts: o.parent=root
    st={'name':NAME,'scene':scene,'parts':parts,'root':root,'islands':islands,'size':SIZE,'density':64,'pad':2,'out':str(OUT),'source':str(SOURCE),'target':TARGET}
    # Approved human pixel painting for skin, cloth, quilt stitches, wool, leather and blue belt.
    painter=(PIPE/'warrior_paint_save.py').read_text(encoding='utf-8')
    exec(painter[painter.index('GAMB='):painter.index('pixels=')])
    original_paint=paint
    LEATHER=[(66,54,47),(76,63,54),(59,48,42)]; LEATHER_DARK=(35,30,29); LEATHER_HI=(99,82,67)
    GAMB=[(62,67,76),(72,77,86),(54,59,67)]; GAMB_SEAM=(37,42,49); GAMB_HI=(87,93,102)
    import random
    custom={'cloak':[(39,44,57),(44,49,63),(33,37,49)],'royal_cloak':[(35,40,57),(42,48,67),(29,33,48)],'dark_leather':LEATHER,
            'iron':IRON,'iron_band':[(82,85,94),(94,97,105),(73,76,84)],'blade':[(166,173,185),(181,188,201),(151,157,169)],
            'wood':WOOD,'wheel':[(92,62,37),(103,71,43),(83,55,33)],'rope':[(174,150,106),(187,163,116),(160,137,96)],
            'stone':[(113,118,126),(128,133,141),(100,105,114)],'team':TEAM,'gold':BRASS}
    def paint(item,index):
        reg=item['obj']['region']; w,h=item['w'],item['h']; rng=random.Random(9201+index)
        if reg=='rogue_hood':
            item['obj']['region']='face'; t,e=original_paint(item,index); item['obj']['region']=reg
            for y in range(h):
                for x in range(w):
                    front=item['normal'].y<-.6
                    hood=not front or y<max(3,int(h*.22)) or x<2 or x>=w-2 or y>int(h*.69)
                    if hood: t[y][x]=rng.choice(custom['cloak'])
                    if front and (y==int(h*.22) or (x in (2,w-3) and y<int(h*.70))): t[y][x]=(72,77,89)
                    if front and y>int(h*.69) and y%4==0: t[y][x]=(26,30,41)
            return t,e
        if reg not in custom: return original_paint(item,index)
        palette=custom[reg]; t=[[rng.choice(palette) for x in range(w)] for y in range(h)]; e=[[(0,0,0)]*w for _ in range(h)]
        for y in range(h):
            for x in range(w):
                edge=min(x,y,w-1-x,h-1-y)
                if edge==0: t[y][x]=shade(palette[0],-18)
                if reg in ('wood','wheel') and x%7==0: t[y][x]=WOOD_DARK
                if reg in ('iron','iron_band') and edge==1: t[y][x]=IRON_HI
                if reg=='blade' and edge<2: t[y][x]=(219,225,233)
                if reg in ('cloak','royal_cloak') and x%6==0: t[y][x]=shade(palette[0],-9)
                if reg=='royal_cloak' and edge==1: t[y][x]=BRASS[0]
                if reg=='dark_leather' and y%7==0: t[y][x]=LEATHER_HI
                if reg=='rope' and (x+y)%4==0: t[y][x]=shade(palette[0],-23)
                if reg=='team' and item['obj']['part'] in ('Standard','HumanPennant','TurretCrest'):
                    if abs(x-(w-1)/2)<1 or (abs(y-h*.35)<1 and .2*w<x<.8*w): t[y][x]=(197,201,211)
        return t,e
    # Painter's atlas fill, material and UV installation, stopping before its static-only checks/save.
    assembly=painter[painter.index('pixels='):painter.index('root=bpy.data.objects.get')]
    assembly=assembly.replace('warrior_v1_',A['stem']+'_')
    D=64
    exec(assembly)
    st['material']=mat
    if A['family']=='rogue':
        anim=(PIPE/'warrior_animate.py').read_text(encoding='utf-8')
        # Joints are measured from actual copied meshes, including the approved hand edits.
        exec(anim[anim.index('def P(n):'):anim.index('# Idle:')])
        if not inherited:
            block=anim[anim.index('# Idle:'):anim.index('# Attack:')].replace('Warrior_',PREFIX+'_')
            exec(block)
        else:
            for role,old in inherited.items():
                a=old.copy(); a.name=PREFIX+'_'+role; a.use_fake_user=True
                end=int(round(a.frame_range[1])); clips[a.name]={'action':a,'start':1,'end':end,'loop':role in ('Idle','Walk'),'nla_start':1,'description':'Inherited without changing curves from '+A['parent'],'inherited_sha256':action_signature(old)}
                assert action_signature(a)==action_signature(old)
        def gesture(role,length,crouch,lean,twist,right,left,frontstep,work=False):
            n=PREFIX+'_'+role
            if n in clips: return
            new_action(n,length,False,1,{'Attack':'Short knife slash and recovery','SneakAttack':'Crouched silent approach, concealed stab, recovery','Dismantle':'Brace the target, three short prying/tool movements, recover'}[role])
            for f in range(1,length+1):
                t=(f-1)/(length-1); envelope=math.sin(math.pi*t)**2
                pulse=math.sin(math.tau*3*t)*envelope if work else math.sin(math.tau*t)*envelope
                off=(0,-frontstep*.45*envelope,-crouch*envelope)
                fl=J['AN_l']+Vector((0,-frontstep*envelope,.045*math.sin(math.pi*envelope)))
                D=pose(off=off,chest_q=qx(lean*envelope)@qz(twist*pulse),head_q=qx(-lean*.65*envelope),
                       arm_r=(right[0]*envelope,right[1]*envelope+9*pulse,right[2]*envelope),
                       arm_l=(left[0]*envelope,left[1]*envelope,left[2]*envelope),feet=(fl,J['AN_r']))
                bake(f,D)
            clips[n]['impact_frame']=int(length*.50)
        gesture('Attack',33,.035,8,12,(-28,-28,65),(-8,12,0),.14)
        gesture('SneakAttack',57,.17,17,8,(-35,-38,120),(-14,24,0),.19)
        if A['level']>0: gesture('Dismantle',73,.19,21,3,(-13,-43,35),(-24,-20,0),.11,True)
    else:
        arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); collections['01_BODY'].objects.link(rig); rig.parent=root
        bones={'root':(Vector(),Vector((0,0,.3))),'body':(Vector((0,0,.48)),Vector((0,0,.70))),
               'weapon':(H,H+Vector((0,0,.18))),'loader':(Vector((0,.48,.80)),Vector((0,.48,.96)))}
        for o in parts:
            b=o['rig_bone']
            if b.startswith('wheel_') and b not in bones: C=center(o['part']); bones[b]=(C,C+X*.15)
        if A['level']==1: bones['counterweight']=(Vector((0,-.29,.98)),Vector((0,-.29,1.10)))
        bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
        bpy.ops.object.mode_set(mode='EDIT')
        for n,(h,t) in bones.items():
            b=arm.edit_bones.new(n); b.head=h; b.tail=t
            if n!='root': b.parent=arm.edit_bones['root']
        bpy.ops.object.mode_set(mode='OBJECT'); arm.display_type='STICK'; rest={b.name:b.matrix_local.copy() for b in arm.bones}
        for o in parts:
            o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
            mod=o.modifiers.new('Rigid_Mechanical_Parts','ARMATURE'); mod.object=rig; o.parent=rig
        rig.animation_data_create(); clips={}
        for role in roles(A):
            end={'Idle':49,'Walk':49,'Attack':49,'DemolitionAmmo':73,'PreparedBombardment':97}[role]
            n=PREFIX+'_'+role; a=bpy.data.actions.new(n); a.use_fake_user=True; rig.animation_data.action=a
            clips[n]={'action':a,'start':1,'end':end,'loop':role in ('Idle','Walk'),'nla_start':1,
                      'description':{'Idle':'Mechanism at rest, slight taut-rope/crank tension','Walk':'Wheels turn in place; return by a full revolution','Attack':'Launch/recoil, mechanical recovery and reload','DemolitionAmmo':'Load heavy ammunition; amplified shot and recovery','PreparedBombardment':'Set elevation, wind/lock mechanism, deliberate heavy shot, recovery'}[role]}
            if role not in ('Idle','Walk'): clips[n]['impact_frame']=int((end-1)*.56)+1
            prev={}
            for f in range(1,end+1):
                t=(f-1)/(end-1); envelope=math.sin(math.pi*t)**2
                launch=max(0,1-abs(t-.56)/.18); launch=launch*launch*(3-2*launch)
                factor=1.0 if role=='Attack' else 1.2 if role=='DemolitionAmmo' else 1.38
                body=Matrix.Translation((0,.012*launch if role not in ('Idle','Walk') else 0,0))
                D={n:body.copy() for n in bones}; D['root']=Matrix.Identity(4)
                if role=='Walk':
                    for n in bones:
                        if n.startswith('wheel_'):
                            C=bones[n][0]; D[n]=Matrix.Translation(C)@Quaternion(X,-math.tau*t).to_matrix().to_4x4()@Matrix.Translation(-C)
                elif role=='Idle': D['loader']=Matrix.Translation(bones['loader'][0])@Quaternion(X,.015*math.sin(math.tau*t)).to_matrix().to_4x4()@Matrix.Translation(-bones['loader'][0])
                else:
                    # Timber engines throw; cannon stages inherit the same semantic repertoire with recoil.
                    angle=(.9*launch*factor-.08*envelope) if A['level']<=1 else -.055*envelope
                    D['weapon']=body@Matrix.Translation(H)@Quaternion(X,angle).to_matrix().to_4x4()@Matrix.Translation(-H)
                    if A['level']>=2: D['weapon']=Matrix.Translation((0,.11*launch*factor,0))@D['weapon']
                    C=bones['loader'][0]; D['loader']=body@Matrix.Translation(C)@Quaternion(X,.7*envelope*math.sin(math.tau*2*t)).to_matrix().to_4x4()@Matrix.Translation(-C)
                    if A['level']==1:
                        # Counterweight remains physically attached to the moving short arm.
                        C=bones['counterweight'][0]; moved=D['weapon']@C; D['counterweight']=Matrix.Translation(moved-C)
                for bn in bones:
                    b=rig.pose.bones[bn]; b.rotation_mode='QUATERNION'; b.matrix=D[bn]@rest[bn]
                bpy.context.view_layer.update()
                for b in rig.pose.bones:
                    if b.name in prev and prev[b.name].dot(b.rotation_quaternion)<0: b.rotation_quaternion.negate()
                    prev[b.name]=b.rotation_quaternion.copy()
                    b.keyframe_insert('location',frame=f,group=b.name); b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
    # Assign precise loop/recovery markers, sample real evaluated bones and ground contact.
    scene.render.fps=24; rig.animation_data.action=None
    problems=[]; validation={}; offset=1
    for n,d in clips.items():
        a=d['action']; a['loop']=d['loop']; a['fps']=24
        for layer in a.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for k in fc.keyframe_points: k.interpolation='LINEAR'
        rig.animation_data.action=a; minimum=99; finite=True; endpoints=[]
        for f in range(1,d['end']+1):
            scene.frame_set(f); bpy.context.view_layer.update()
            delta={b.name:b.matrix@rest[b.name].inverted() for b in rig.pose.bones}
            if f in (1,d['end']): endpoints.append({k:v.copy() for k,v in delta.items()})
            for o in parts:
                for v in o.data.vertices:
                    p=delta[o['rig_bone']]@v.co; minimum=min(minimum,p.z*root.scale.z); finite=finite and all(math.isfinite(x) for x in p)
        seam=max(abs(endpoints[0][b][i][j]-endpoints[1][b][i][j]) for b in bones for i in range(4) for j in range(4))
        if not finite or minimum<-.01 or seam>.0003: problems.append(n+': ground/finite/recovery failure')
        validation[n]={'min_z':round(minimum,6),'finite':finite,'loop_or_recovery_error':round(seam,8),'curve_sha256':action_signature(a)}
        if 'inherited_sha256' in d: assert validation[n]['curve_sha256']==d['inherited_sha256'],n
        a.pose_markers.new('LOOP_START' if d['loop'] else 'START').frame=1
        a.pose_markers.new('LOOP_END' if d['loop'] else 'RECOVERED').frame=d['end']
        if 'impact_frame' in d: a.pose_markers.new('IMPACT').frame=d['impact_frame']
        d['nla_start']=offset; offset+=d['end']+8
    rig.animation_data.action=None
    for n,d in clips.items():
        track=rig.animation_data.nla_tracks.new(); track.name=n
        strip=track.strips.new(n,d['nla_start'],d['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.frame_start=1; scene.frame_end=offset; scene.frame_set(1)
    triangles=0; nonmanifold=0
    for o in parts:
        o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
        bm=bmesh.new(); bm.from_mesh(o.data); nonmanifold+=sum(not e.is_manifold for e in bm.edges); bm.free()
    assert not nonmanifold and not problems, (nonmanifold,problems)
    sourcefile=ROOT/'assets/generated/humans'/A['parent']/(A['parent']+'.blend') if A['parent'] else None
    st.update(rig=rig,clips=clips,animation_validation={'problems':problems,'samples':validation},report={
        'name':NAME,'kind':A['kind'],'label':A['label'],'pipeline':'Live Blender MCP localhost:9876',
        'height_m':A['height'],'height_convention':'Body/rest geometry; animated equipment may exceed body height',
        'triangles':triangles,'editable_parts':len(parts),'nonmanifold_edges':nonmanifold,'materials':1,'shade':'Flat',
        'texture':{'size':[SIZE,SIZE],'density_px_per_meter':64,'filter':'NEAREST','padding':2},
        'derivation':{'predecessor':A['parent'],'source_blend_sha256':hashlib.sha256(sourcefile.read_bytes()).hexdigest() if sourcefile else None,'copied_parts':copied,'inherited_actions':list(inherited)},
        'notes':'Approved Warrior body, hood painted on the single head block, blue human heraldry; rigid authored equipment.' if A['family']=='rogue' else 'Human timber/iron/blue heraldry, autonomous mechanical rig without visible crew. Chassis copied from predecessor; mechanisms upgraded.'})
    scene['description']=A['label']; scene['status']='Rigged draft: awaiting animation previews and final GLB'
    bpy.app.driver_namespace[KEY]=st
    bpy.data.libraries.write(str(SOURCE/(A['stem']+'_rigged.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    result={'asset':A['stem'],'parts':len(parts),'triangles':triangles,'height':A['height'],'validation':st['animation_validation'],'inherited':list(inherited)}

elif STAGE=='mechanical_finish':
    st=bpy.app.driver_namespace[KEY]; parts=st['parts']; scene=st['scene']; root=st['root']; bpy.context.window.scene=scene; changed=[]
    # Real bearing blocks join every axle to the bed instead of leaving a visual gap.
    if A['family']=='siege':
        X=Vector((1,0,0)); Y=Vector((0,1,0)); Z=Vector((0,0,1))
        CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
        collections={label:bpy.data.collections[NAME+'_'+label] for label in ('05_GEAR',)}
        tree=ast.parse((PIPE/'warrior_model.py').read_text(encoding='utf-8'))
        for node in tree.body:
            if isinstance(node,ast.FunctionDef) and node.name in ('mesh','fbox','box'):
                exec(compile(ast.Module(body=[node],type_ignores=[]),'<bearing-primitives>','exec'))
        def add_support(n,c,s,bone='body',chassis=False):
            if any(o['part']==n for o in parts): return
            o=box(n,c,s,'iron',bone,'05_GEAR')
            o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1,'REPLACE')
            mod=o.modifiers.new('Rigid_Mechanical_Parts','ARMATURE'); mod.object=st['rig']; o.parent=st['rig']
            if chassis: o['chassis']=True
            changed.append(n)
        spacing=.56 if A['level']==3 else .45
        for y,label in ((-spacing,'Front'),(spacing,'Back'))+(((0,'Middle'),) if A['level']==3 else ()):
            for side,t in ((1,'l'),(-1,'r')):
                add_support('Bearing_'+label+'_'+t,(side*.32,y,.345),(.10,.14,.19),chassis=True)
        if A['level']>=2:
            add_support('LoadingSpindle',(0,.48,.92),(.045,.045,.24),'loader')
        if A['level']==2:
            add_support('ElevationBase',(0,.31,.60),(.11,.12,.18))
            screw=next(o for o in parts if o['part']=='ElevationScrew')
            if screw['rig_bone']!='body':
                screw.vertex_groups.clear(); screw.vertex_groups.new(name='body').add(list(range(len(screw.data.vertices))),1,'REPLACE')
                screw['rig_bone']='body'; changed.append('ElevationScrew_fixed_mount')
    for o in st['parts']:
        if o['part'].startswith('Upright_') and abs(min(v.co.z for v in o.data.vertices)-.55)<.001:
            for v in sorted(o.data.vertices,key=lambda v:v.co.z)[:4]: v.co.z-=.01
            o.data.update(); changed.append(o['part']+'_buried_joint')
        if o['part'].startswith('AframeFront_'):
            width=max(v.co.x for v in o.data.vertices)-min(v.co.x for v in o.data.vertices)
            if width<.11:
                cx=sum(v.co.x for v in o.data.vertices)/len(o.data.vertices)
                for v in o.data.vertices: v.co.x=cx+(v.co.x-cx)*1.12
                o.data.update(); changed.append(o['part']+'_different_joint_width')
        if o['part']=='ElevatingGear' and abs(min(v.co.z for v in o.data.vertices)-1.13)<.001:
            for v in sorted(o.data.vertices,key=lambda v:v.co.z)[:4]: v.co.z-=.01
            o.data.update(); changed.append('ElevatingGear_buried_joint')
        if o['part'] in ('RearMast','Standard') and abs(sum(v.co.x for v in o.data.vertices)/len(o.data.vertices))<.01:
            for v in o.data.vertices: v.co.x+=.31
            o.data.update(); changed.append(o['part'])
        if o['part']=='RearMast' and min(v.co.z for v in o.data.vertices)>.7:
            for v in o.data.vertices: v.co.z=.52+(v.co.z-.72)*1.28/1.08
            o.data.update(); changed.append('RearMast_ground_support')
        if o['part']=='PennantBracket' and min(v.co.z for v in o.data.vertices)>.6:
            for v in o.data.vertices:
                v.co.y=.675+(v.co.y-.64)*.055/.13
                v.co.z=.77+(v.co.z-.85)*.50/.34
            o.data.update(); changed.append('PennantBracket_chassis_support')
        if o['part']=='BeltSeal' and abs(sum(v.co.y for v in o.data.vertices)/len(o.data.vertices)+.148)<.002:
            for v in o.data.vertices: v.co.y+=.01
            o.data.update(); changed.append('BeltSeal_attached')
    if changed:
        # Reproject/repaint after the support resize: retain true 64 px/m without stretched grain.
        import textwrap
        base=(PIPE/'warrior_model.py').read_text(encoding='utf-8')
        X=Vector((1,0,0)); Y=Vector((0,1,0)); Z=Vector((0,0,1))
        exec(base[base.index('DENSITY=64; PAD=2; islands=[]'):base.index('TARGET=')])
        st.update(islands=islands,size=SIZE)
        live=(PIPE/'human_rogue_siege_live.py').read_text(encoding='utf-8')
        start=live.index("    painter=(PIPE/'warrior_paint_save.py')")
        end=live.index("    if A['family']=='rogue':",start)
        exec(textwrap.dedent(live[start:end]))
        st['report']['texture']['size']=[SIZE,SIZE]
        for o in parts: o.data.calc_loop_triangles()
        st['report']['triangles']=sum(len(o.data.loop_triangles) for o in parts)
        st['report']['editable_parts']=len(parts)
    result={'supports_and_clearance_corrected':changed}

elif STAGE=='attach_cloth':
    st=bpy.app.driver_namespace[KEY]
    changed=[]
    for o in st['parts']:
        if o['part'].startswith(('SplitMantle','RoyalMantle')):
            original=.148 if o['part'].startswith('Split') else .165
            start=sum((v.co.y for v in o.data.vertices[:4]))/4
            if abs(start-original)<.002:
                # Top four vertices meet the chest; preserve the hem and all body/rig/action data.
                for v in o.data.vertices[:4]: v.co.y += .132-original
                o.data.update(); changed.append(o['part'])
    result={'attached':changed}

elif STAGE=='preview':
    st=bpy.app.driver_namespace[KEY]; scene=st['scene']; rig=st['rig']; camera=scene.camera; bpy.context.window.scene=scene
    mat=st['material']; parts=st['parts']; folder=SOURCE/'animation_frames'; folder.mkdir(exist_ok=True)
    scene.render.engine='BLENDER_WORKBENCH'; scene.render.resolution_x=448; scene.render.resolution_y=448
    sh=scene.display.shading; sh.light='STUDIO'; sh.color_type='TEXTURE'; sh.show_shadows=True; sh.show_cavity=True; sh.cavity_type='BOTH'; sh.background_type='WORLD'; scene.world.color=(.13,.15,.17)
    node=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.label=='Base Color'); mat.node_tree.nodes.active=node
    for track in rig.animation_data.nla_tracks: track.mute=True
    role=PREVIEW_ROLE; n=PREFIX+'_'+role; d=st['clips'][n]; rig.animation_data.action=d['action']
    target=Vector((0,0,A['height']*.49)); direction=Vector((5,-8,3.4)).normalized()
    camera.location=target+direction*12; camera.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=2.70 if A['family']=='rogue' else 3.05
    dest=folder/n; dest.mkdir(exist_ok=True)
    for old in dest.glob('*.png'): old.unlink()
    frames=list(range(1,d['end']+(0 if d['loop'] else 1),2))
    try:
        for f in frames:
            scene.frame_set(f); scene.render.filepath=str(dest/f'{f:04d}.png'); bpy.ops.render.render(write_still=True)
        if role=='Idle':
            scene.frame_set(1); scene.render.resolution_x=900; scene.render.resolution_y=900
            for suffix,vec in [('front',(0,-12,1.6)),('threequarter',(6,-12,5.6)),('back',(-6,12,5.6))]:
                camera.location=target+Vector(vec); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
                scene.render.filepath=str(OUT/'previews'/(suffix+'.png')); bpy.ops.render.render(write_still=True)
    finally:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks: track.mute=False
        scene.frame_set(1); scene.render.resolution_x=900; scene.render.resolution_y=900
        camera.location=target+Vector((6,-12,5.6)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    result={'asset':A['stem'],'clip':n,'frames':len(frames),'fps':12,'directory':str(dest)}

elif STAGE=='export':
    st=bpy.app.driver_namespace[KEY]; bpy.app.driver_namespace['warrior']=st
    exporter=(PIPE/'warrior_export.py').read_text(encoding='utf-8').replace('warrior_v1',A['stem'])
    exec(exporter)
    st['report']['status']='Finished human '+A['label']+'; rig, clips, nearest embedded textures and isolated editable source verified.'
    if A['family']=='siege':
        st['report']['rig']['hierarchy']='Flat rigid mechanical rig: body, wheels, weapon, loading mechanism; hanging counterweight in trebuchet'
    (OUT/(A['stem']+'_report.json')).write_text(json.dumps(st['report'],indent=2),encoding='utf-8')
    # glTF has no loop flag; keep Godot's imported clips faithful to the source.
    loops=[PREFIX+'_Idle',PREFIX+'_Walk']
    (OUT/(A['stem']+'_import.gd')).write_text('@tool\nextends EditorScenePostImport\n\nfunc _post_import(scene: Node) -> Object:\n\tfor node in scene.find_children("*", "AnimationPlayer", true, false):\n\t\tvar player := node as AnimationPlayer\n\t\tfor name in player.get_animation_list():\n\t\t\tplayer.get_animation(name).loop_mode = Animation.LOOP_LINEAR if name in '+json.dumps(loops)+' else Animation.LOOP_NONE\n\treturn scene\n',encoding='utf-8')
    (OUT/'README.md').write_text('# '+A['label']+' humano\n\nCriado sequencialmente pelo Blender MCP. Fonte editável: `'+A['stem']+'.blend`; jogo: `'+A['stem']+'.glb`.\n\nAltura de referência: '+str(A['height'])+' m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.\n\nBase copiada: '+str(A['parent'])+'. Animações: '+', '.join(st['clips'])+'. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).\n\nO script `'+A['stem']+'_import.gd` marca loops no Godot. Desmantelar é entregue como animação; permanece passiva conforme as regras existentes.\n',encoding='utf-8')
    readme=OUT/'README.md'
    if A['family']=='siege':
        readme.write_text(readme.read_text(encoding='utf-8').replace('Desmantelar é entregue como animação; permanece passiva conforme as regras existentes.','Munição Demolidora é entregue como animação; permanece passiva conforme as regras existentes.'),encoding='utf-8')
    elif A['level']==0:
        readme.write_text(readme.read_text(encoding='utf-8').replace('Desmantelar é entregue como animação; permanece passiva conforme as regras existentes.','Ataque Furtivo está incluído. O clipe Desmantelar entra a partir do Sabotador.'),encoding='utf-8')
    result={'saved':A['stem'],'glb':str(OUT/(A['stem']+'.glb')),'clips':list(st['clips'])}
else: raise RuntimeError('Unknown stage')
