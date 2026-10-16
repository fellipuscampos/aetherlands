"""Replace only the rejected Colossus visual via live Blender MCP.

An oversized medieval great bombard, shaped oak carriage, six real spoked
wheels, functional trunnion, windlass and attached heraldic plates.
Preserves native ten-bone rig, clip names/durations and all action curves.
"""
import bpy, bmesh, math, ast, json, hashlib, shutil, sys, textwrap
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); PIPE=ROOT/'tools/art_pipeline'
if str(PIPE) not in sys.path: sys.path.insert(0,str(PIPE))
from human_rogue_siege_assets import ASSETS
A=ASSETS[7]; INDEX=7; NAME=A['name']; PREFIX=A['prefix']; OUT=ROOT/'assets/generated/humans'/A['stem']
SOURCE=ROOT/'art_source'/A['stem']; KEY='human_rogue_siege_'+A['stem']
backup=ROOT/'art_source/siege_colossus_before_redesign_v1'
if not (backup/'manifest.json').exists():
    backup.mkdir(parents=True,exist_ok=True); (backup/'.gdignore').write_text('',encoding='utf-8')
    hashes={}
    for p in OUT.rglob('*'):
        if p.is_file():
            relative=p.relative_to(OUT); target=backup/'asset'/relative; target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(p,target); hashes[str(relative).replace('\\','/')]=hashlib.sha256(p.read_bytes()).hexdigest()
    other={}
    for a in ASSETS[:7]:
        for p in (ROOT/'assets/generated/humans'/a['stem']).rglob('*'):
            if p.is_file() and not p.name.endswith('.import'):
                other[str(p.relative_to(ROOT)).replace('\\','/')]=hashlib.sha256(p.read_bytes()).hexdigest()
    for relative in ('scripts/data/UnitDatabase.gd','scripts/units/Unit.gd','_human_rogue_siege_review.gd','_human_rogue_siege_review.tscn'):
        other[relative]=hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()
    (backup/'manifest.json').write_text(json.dumps({'colossus_backup':hashes,'other_assets_baseline':other},indent=2),encoding='utf-8')

st=bpy.app.driver_namespace.get(KEY)
if not st:
    if NAME not in bpy.data.scenes:
        with bpy.data.libraries.load(str(OUT/(A['stem']+'.blend'))) as (src,dst): dst.scenes=[NAME]
    scene=bpy.data.scenes[NAME]; report=json.loads((OUT/(A['stem']+'_report.json')).read_text(encoding='utf-8'))
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    clips={}
    for tr in rig.animation_data.nla_tracks:
        clips[tr.name]=dict(report['animations'][tr.name],action=tr.strips[0].action)
    st={'name':NAME,'out':str(OUT),'source':str(SOURCE),'scene':scene,'rig':rig,'root':bpy.data.objects[NAME+'_ROOT'],
        'parts':[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],
        'clips':clips,'report':report,'animation_validation':report['animation_validation']}
    bpy.app.driver_namespace[KEY]=st
scene=st['scene']; rig=st['rig']; root=st['root']; parts=st['parts']; bpy.context.window.scene=scene
assert not scene.get('colossus_redesign_geometry'), 'Draft already exists: continue preview/export, preserving edits.'
live=(PIPE/'human_rogue_siege_live.py').read_text(encoding='utf-8')
node=next(n for n in ast.parse(live).body if isinstance(n,ast.FunctionDef) and n.name=='action_signature')
exec(compile(ast.Module(body=[node],type_ignores=[]),'<curve-signature>','exec'))
before={n:action_signature(d['action']) for n,d in st['clips'].items()}
root.scale=(1,1,1); rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks: tr.mute=True
scene.frame_set(1); rig.data.pose_position='REST'
keep={'Chassis','ChassisRail_l','ChassisRail_r'}
for o in list(parts):
    if o['part'] not in keep:
        parts.remove(o); me=o.data; bpy.data.objects.remove(o,do_unlink=True)
        if me.users==0: bpy.data.meshes.remove(me)
collections={'05_GEAR':bpy.data.collections[NAME+'_05_GEAR']}
X=Vector((1,0,0)); Y=Vector((0,1,0)); Z=Vector((0,0,1))
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
base=(PIPE/'warrior_model.py').read_text(encoding='utf-8')
for node in ast.parse(base).body:
    if isinstance(node,ast.FunctionDef) and node.name in ('mesh','fbox','box','beam'):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<approved-primitives>','exec'))
def shape_existing(n,center,size):
    o=next(o for o in parts if o['part']==n)
    vv=[v.co.copy() for v in o.data.vertices]; lo=Vector(tuple(min(v[i] for v in vv) for i in range(3))); hi=Vector(tuple(max(v[i] for v in vv) for i in range(3)))
    mid=(lo+hi)/2
    for v in o.data.vertices: v.co=Vector(center)+Vector(tuple((v.co[i]-mid[i])*size[i]/(hi[i]-lo[i]) for i in range(3)))
    o.data.update(); o['redesign']='Scaled approved bombard bed/rail; oak carriage retained.'
shape_existing('Chassis',(0,0,.64),(1.24,1.84,.20))
for side,t in ((1,'l'),(-1,'r')): shape_existing('ChassisRail_'+t,(side*.54,0,.805),(.14,1.88,.13))
def block(n,c,s,reg='wood',bone='body'): return box(n,c,s,reg,bone,'05_GEAR')
def rod(n,start,end,w,d,reg='iron',bone='body',side=None): return beam(n,start,end,w,d,reg,bone,'05_GEAR',side=side)

def cylinder(n,c,r,depth,reg,bone='body',axis=X,N=12,inner=None):
    axis=Vector(axis).normalized(); u=axis.cross(Z)
    if u.length<.01: u=axis.cross(Y)
    u.normalize(); v=axis.cross(u); C=Vector(c)
    vv=[C+axis*offset+u*math.cos(i*math.tau/N)*rr+v*math.sin(i*math.tau/N)*rr
        for rr in ([r] if inner is None else [r,inner]) for offset in (-depth/2,depth/2) for i in range(N)]
    ff=[]
    for i in range(N):
        j=(i+1)%N; ff.append((i,j,N+j,N+i))
    if inner is None: ff += [tuple(reversed(range(N))),tuple(range(N,2*N))]
    else:
        for i in range(N):
            j=(i+1)%N; ff += [(2*N+i,3*N+i,3*N+j,2*N+j),(i,2*N+i,2*N+j,j),(N+i,N+j,3*N+j,3*N+i)]
    return mesh(n,vv,ff,reg,bone,'05_GEAR',Z)

def profile(n,x,thickness,yz,reg='wood'):
    count=len(yz); vv=[(x+offset,y,z) for offset in (-thickness/2,thickness/2) for y,z in yz]
    ff=[tuple(reversed(range(count))),tuple(range(count,2*count))]
    ff += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    return mesh(n,vv,ff,reg,'body','05_GEAR',Z)

WHEEL_HEADS={}
for y,label in ((-.74,'front'),(0,'middle'),(.74,'back')):
    cylinder('Axle_'+label,(0,y,.33),.045,1.52,'iron')
    for side,t in ((1,'l'),(-1,'r')):
        bone='wheel_'+t+'_'+label; C=Vector((side*.72,y,.33)); WHEEL_HEADS[bone]=C
        block('Bearing_'+t+'_'+label,(side*.52,y,.455),(.14,.16,.25),'iron')
        cylinder('Wheel_'+t+'_'+label,C,.33,.155,'iron_band',bone,N=12,inner=.283)
        cylinder('WoodRim_'+t+'_'+label,C,.282,.16,'wheel',bone,N=12,inner=.24)
        cylinder('WheelHub_'+t+'_'+label,C,.091,.19,'wood',bone,N=8)
        cylinder('HubCap_'+t+'_'+label,C+X*side*.102,.064,.025,'gold',bone,N=8)
        for i in range(6):
            direction=Vector((0,math.cos(i*math.tau/6),math.sin(i*math.tau/6)))
            rod('Spoke_'+t+'_'+label+'_'+str(i),C+direction*.055,C+direction*.251,.085,.054,'wood',bone,side=X)

# Shaped structural cheeks, cut to reveal the gun instead of hiding it in an iron box.
outline=[(-.80,.73),(.78,.73),(.54,2.00),(.29,1.93),(-.07,1.29),(-.80,1.10)]
for side,t in ((1,'l'),(-1,'r')):
    profile('OakGunCheek_'+t,side*.48,.18,outline)
    rod('LowerIronBind_'+t,(side*.580,-.79,.84),(side*.580,.75,.84),.026,.065,side=X)
    rod('RearIronBind_'+t,(side*.585,.735,.83),(side*.585,.53,1.955),.030,.065,side=X)
    profile('HeraldicPanel_'+t,side*.578,.028,[(-.48,1.03),(.48,1.03),(.29,1.73),(.08,1.61),(-.14,1.20)],'team')
    for y,z in ((-.65,.86),(.58,.86),(.51,1.78)):
        cylinder('CheekRivet_'+t+'_'+str(z)+'_'+str(y),(side*.60,y,z),.025,.036,'iron',axis=X,N=8)
    block('CheekGoldClasp_'+t,(side*.588,.47,1.85),(.030,.12,.065),'gold')
    # These front reinforcements taper with the gun bed; their sloping form reads as a siege carriage.
    rod('ForwardBrace_'+t,(side*.39,-.73,.79),(side*.39,.08,1.265),.115,.115,'wood',side=X)
    block('FrontFootIron_'+t,(side*.43,-.74,.77),(.18,.17,.065),'iron')
block('RearCrossbeam',(0,.69,.92),(1.06,.15,.16),'wood')
block('FrontCrossbeam',(0,-.73,.97),(1.04,.13,.16),'wood')

H=Vector((0,.05,1.325)); axis=Vector((0,-1,.10)).normalized()
for side,t in ((1,'l'),(-1,'r')):
    cylinder('Trunnion_'+t,H+X*side*.47,.097,.31,'iron',axis=X,N=12)
    cylinder('TrunnionCap_'+t,H+X*side*.64,.115,.055,'iron_band',axis=X,N=12)
    cylinder('TrunnionSeal_'+t,H+X*side*.678,.058,.025,'gold',axis=X,N=8)
C=H+axis*.24
cylinder('GreatBombardBarrel',C,.372,1.44,'iron_band','weapon',axis=axis,N=12,inner=.225)
for distance,n,r,depth,reg in ((.70,'MuzzleRing',.425,.095,'iron'),(.27,'ForwardBand',.398,.075,'iron'),
                              (-.27,'RearBand',.398,.085,'iron'),(-.65,'BreechBand',.405,.12,'iron')):
    cylinder(n,C+axis*distance,r,depth,reg,'weapon',axis=axis,N=12,inner=.371)
cylinder('BreechPlug',C-axis*.737,.371,.075,'iron_band','weapon',axis=axis,N=12)
cylinder('BreechMedallion',C-axis*.785,.10,.025,'gold','weapon',axis=axis,N=8)
block('RecoilSlide',(0,.13,.9475),(.40,1.16,.125),'iron_band')
block('RecoilShoe',(0,.22,.985),(.30,.55,.12),'iron','weapon')
block('RearRecoilStop',(0,.72,1.16),(.55,.12,.25),'wood')

# Visible manual loading/elevation winch, with its own existing animated bone.
L=Vector((.71,.40,1.10))
cylinder('WinchSpindle',(.63,.40,1.10),.04,.20,'iron',axis=X,N=8)
cylinder('WinchWheel',L,.16,.065,'iron_band','loader',axis=X,N=12,inner=.112)
cylinder('WinchHub',L,.043,.085,'gold','loader',axis=X,N=8)
for i in range(4):
    direction=Vector((0,math.cos(i*math.tau/4),math.sin(i*math.tau/4)))
    rod('WinchSpoke_'+str(i),L+direction*.04,L+direction*.125,.053,.031,'iron','loader',side=X)
rod('WinchGrip',L+Vector((.01,0,.14)),L+Vector((.16,0,.14)),.055,.055,'wood','loader',side=Y)
block('PowderLocker',(0,.70,.87),(.38,.28,.22),'dark_leather')
for x in (-.13,.13): cylinder('StoredShot_'+str(x),(x,.78,1.025),.083,.16,'stone',axis=Z,N=8)

# Correct pivot positions, keeping orientations and every existing animation curve.
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,C in WHEEL_HEADS.items():
    b=rig.data.edit_bones[n]; b.head=C; b.tail=C+X*.15
for n,C,length in (('body',Vector((0,0,.64)),.22),('weapon',H,.18),('loader',L,.16)):
    b=rig.data.edit_bones[n]; b.head=C; b.tail=C+Z*length
bpy.ops.object.mode_set(mode='OBJECT'); rig.data.pose_position='POSE'
for o in parts:
    if not o.vertex_groups:
        o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
        mod=o.modifiers.new('Rigid_Colossus_Parts','ARMATURE'); mod.object=rig
    o.parent=rig; o.matrix_parent_inverse=Matrix.Identity(4)

# Same human palette and metric pixel mapping; the large barrel uses quiet clusters.
exec(base[base.index('DENSITY=64; PAD=2; islands=[]'):base.index('TARGET=')])
st.update(parts=parts,islands=islands,size=SIZE)
start=live.index("    painter=(PIPE/'warrior_paint_save.py')"); end=live.index("    if A['family']=='rogue':",start)
paintcode=textwrap.dedent(live[start:end])
insert=paintcode.index("# Painter's atlas fill")
exec(paintcode[:insert])
old_paint=paint
def paint(item,index):
    t,e=old_paint(item,index); w,h=item['w'],item['h']; reg=item['obj']['region']; n=item['obj']['part']
    if reg=='iron_band':
        import random
        rng=random.Random(18700+index)
        patches={}
        palette=[(76,79,86),(82,85,92),(87,90,98)]
        for y in range(h):
            for x in range(w):
                key=(x//3,y//4)
                if key not in patches: patches[key]=rng.choice(palette)
                t[y][x]=patches[key]
                if min(x,y,w-1-x,h-1-y)==0: t[y][x]=(59,62,69)
    if reg=='team' and n.startswith('HeraldicPanel') and abs(item['normal'].x)>.9:
        # White crown and shield, using the faction blue rather than a tall roof ornament.
        for y in range(h):
            for x in range(w):
                fx=(x+.5)/w; fy=(y+.5)/h
                crown=(.34<fx<.66 and .35<fy<.44) or (any(abs(fx-v)<.035 for v in (.36,.5,.64)) and .27<fy<.37)
                shield=.38<fy<.70 and abs(fx-.5)<.13*(.70-fy)/.32
                if crown or shield: t[y][x]=(211,214,220)
    return t,e
exec(paintcode[insert:])
assert all(action_signature(d['action'])==before[n] for n,d in st['clips'].items())
triangles=0; bad=0
for o in parts:
    o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
    bm=bmesh.new(); bm.from_mesh(o.data); bad+=sum(not e.is_manifold for e in bm.edges); bm.free()
assert bad==0
maximum=max(v.co.z for o in parts for v in o.data.vertices); minimum=min(v.co.z for o in parts for v in o.data.vertices)
assert abs(maximum-2)<.001 and abs(minimum)<.001,(maximum,minimum)
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}; validation={}
for n,d in st['clips'].items():
    rig.animation_data.action=d['action']; endpoints=[]; low=99; finite=True
    for f in range(1,d['end']+1):
        scene.frame_set(f); bpy.context.view_layer.update()
        D={b.name:b.matrix@rest[b.name].inverted() for b in rig.pose.bones}
        if f in (1,d['end']): endpoints.append({k:v.copy() for k,v in D.items()})
        for o in parts:
            for v in o.data.vertices:
                p=D[o['rig_bone']]@v.co; low=min(low,p.z); finite=finite and all(math.isfinite(c) for c in p)
    seam=max(abs(endpoints[0][b][i][j]-endpoints[1][b][i][j]) for b in D for i in range(4) for j in range(4))
    assert low>-.01 and finite and seam<.0003,(n,low,seam)
    validation[n]={'min_z':round(low,6),'finite':finite,'loop_or_recovery_error':round(seam,8),'curve_sha256':action_signature(d['action'])}
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks: tr.mute=False
scene.frame_set(1)
report=st['report']
report.update(triangles=triangles,editable_parts=len(parts),nonmanifold_edges=bad,
    notes='Colossus redesign: human great bombard, shaped oak cheeks, six open spoked iron-rimmed wheels, giant hollow barrel, working trunnion and windlass, attached blue crown shields.',
    height_convention='2.00 m to the structural oak gun cheeks; no mast or height ornament',
    redesign={'backup':'art_source/siege_colossus_before_redesign_v1/asset','retained_parts':sorted(keep),
              'rig_and_clip_names_preserved':True,'all_animation_curves_preserved':True,'old_curve_hashes':before})
report['texture']['size']=[SIZE,SIZE]; report.pop('geometry_validation',None)
st['animation_validation']={'problems':[],'samples':validation}; report['animation_validation']=st['animation_validation']
scene['description']=report['notes']; scene['colossus_redesign_geometry']=True
SOURCE.mkdir(parents=True,exist_ok=True)
bpy.data.libraries.write(str(SOURCE/'siege_colossus_redesign_draft.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'asset':A['stem'],'parts':len(parts),'triangles':triangles,'height_m':maximum,'rig_bones':len(rig.data.bones),'curves_preserved':True,'draft':str(SOURCE/'siege_colossus_redesign_draft.blend')}
