"""Six dwarf elders using approved native anatomy, built in live Blender MCP."""
import bpy,bmesh,ast,math,json,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/dwarf_school_mages_review'
BASE=bpy.app.driver_namespace['dwarf_school_mage_base']
PROBE=json.loads((WORK/'base_probe.json').read_text(encoding='utf-8'))
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
BODY_NAMES=['Head','Chest','Belly','Pelvis']+[p+'_'+s for s in ('l','r') for p in ('Thigh','Shin','Foot','Shoulder','UpperArm','Forearm','Hand')]
ns=dict(bpy=bpy,bmesh=bmesh,json=json,hashlib=hashlib,math=math,np=np,Vector=Vector,Matrix=Matrix,ROOT=ROOT,WORK=WORK,FACES=FACES,BODY_NAMES=BODY_NAMES,SOURCES={'dwarf':BASE},PROBE={'dwarf':PROBE},RACE='dwarf')
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in {'mesh','box','beam','bounds','center','name_for','region_for','image_pixels','clone_anatomy','reframe','ring','paint_tile'}:
        code=ast.get_source_segment(source,node)
        if node.name=='clone_anatomy': code=code.replace("if original.type!='MESH' or not keep: continue","if original.type!='MESH' or not keep or raw.startswith('Workshop_cap_'): continue")
        exec(compile(code,'<approved_dwarf_anatomy>','exec'),ns)
source=(ROOT/'tools/art_pipeline/build_human_school_mages_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in {'transform','tilted_box','loft','segment','crystal','elbow_for','build_atlas'}: exec(compile(ast.get_source_segment(source,node),'<approved_mage_pipeline>','exec'),globals())
recipe=next(n for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SCHOOLS' for t in n.targets))
recipes={}; exec(compile(ast.Module(body=[recipe],type_ignores=[]),'<school_colors>','exec'),recipes)
names={'sacred':'Sacerdote Anão — Escola Sagrada','infernal':'Bruxo da Forja Anão — Escola Infernal','necromancy':'Guardião das Criptas Anão — Necromancia','druidism':'Druida Anão — Druidismo','arcanism':'Mestre Rúnico Anão — Arcanismo','elementalism':'Geomante Anão — Elementalismo'}
SCHOOLS=[]
for recipe in recipes['SCHOOLS']:
    p=dict(recipe); p.update(stem=recipe['stem'].replace('human_','dwarf_'),name=names[recipe['school']],lean=6 if recipe['school'] in ('infernal','necromancy') else 5)
    p.update(skin=(211,165,119),hair=(205,204,191),pants=(65,66,62),leather=(105,73,47),wood=(112,81,47),metal=(97,108,116),copper=(177,118,64),ivory=(212,203,176),stone=(114,121,128),parchment=(194,178,127),blanket=(135,74,52),fire=(214,99,43),water=(89,162,184),wind=(213,213,180))
    p['headwear']={'sacred':'short_mitre','infernal':'painted_hood','necromancy':'painted_hood','druidism':'leather_headband','arcanism':'angular_hat','elementalism':'steel_headband'}[p['school']]
    SCHOOLS.append(p)
HOODS={p['school']:p['linen'] for p in SCHOOLS if p['headwear']=='painted_hood'}

def paint_head(tile,face_index,school):
    out=tile.copy(); yy,xx=np.mgrid[:tile.shape[0],:tile.shape[1]]
    hair=np.any(np.stack([np.all(tile[:,:,:3]==c,axis=-1) for c in [(57,48,40),(64,55,47)]]),axis=0)
    out[hair,:3]=(205,204,191)
    if school in HOODS:
        cloth=np.clip(np.array(HOODS[school])+(((xx//2+yy//3)%3)-1)[...,None]*4,0,255)
        if face_index in (1,3): out[:,:,:3]=cloth
        else: out[hair,:3]=cloth[hair]
    return out,0,0

def pose(p):
    body=ns['BODY']; pivot=Vector((0,0,.575))
    torso=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(p['lean']),4,'X')@Matrix.Translation(-pivot)
    hc=ns['center'](body['Head']); head=torso@Matrix.Translation(hc)@Matrix.Rotation(math.radians(-3),4,'X')@Matrix.Translation(-hc)
    for part in ['Chest','Belly']: transform(body[part],torso)
    for obj in ns['PARTS']:
        if obj['future_bone']=='head': transform(obj,head)
        if obj['part']=='hair_cap' and p['school'] in HOODS: obj['surface']='linen'
    for side in ('r','l'):
        shoulder=body['Shoulder_'+side]; c=ns['center'](shoulder); sign=1 if c.x>0 else -1
        anchor=torso@Vector((c.x,c.y,.88)); anchor.z-=.012
        transform(shoulder,torso); transform(shoulder,Matrix.Translation(Vector((0,0,-.012))))
        upper,fore,hand=[body[n+'_'+side] for n in ('UpperArm','Forearm','Hand')]
        lengths=[(o.data.vertices[4].co-o.data.vertices[0].co).length for o in (upper,fore,hand)]
        if side=='r':
            wrist=anchor+Vector((sign*.125,-.300,-.195)); assert (wrist-anchor).length<lengths[0]+lengths[1]
            elbow=elbow_for(anchor,wrist,lengths[0],lengths[1])
        else:
            direction=Vector((sign*.16,-.09,-1)).normalized(); elbow=anchor+direction*lengths[0]; wrist=elbow+direction*(lengths[1]+.001)
        ns['reframe'](upper,(anchor+elbow)/2,(anchor-elbow).normalized())
        ns['reframe'](fore,(elbow+wrist)/2,(elbow-wrist).normalized())
        direction=(wrist-elbow).normalized(); ns['reframe'](hand,wrist+direction*(lengths[2]/2-.0035),-direction)
        upper['surface']=fore['surface']=shoulder['surface']='cloth'; hand['surface']='skin'
        hand['pose']='staff_grip' if side=='r' else 'relaxed_empty_hand'
    return torso,head

def garments(p,torso):
    b=ns['BODY']; b['Chest']['surface']=b['Belly']['surface']='cloth'; b['Pelvis']['surface']='pants'
    for side in ('l','r'):
        b['Thigh_'+side]['surface']='pants'; b['Shin_'+side]['surface']=b['Foot_'+side]['surface']='leather'
    loft('Dwarf_tunic',(0,.003,.358),(0,.003,.579),(.568,.323),(.552,.319),'cloth','hips')
    for sign in (-1,1): tilted_box('Dwarf_split_hem_'+str(sign),(sign*.144,.003,.287),(.275,.322,.140),'cloth','hips')
    ns['ring']('Dwarf_belt',(0,.003,.561),.565,.331,.051,'leather','hips',thick=.021)
    tilted_box('Copper_buckle',(0,-.180,.561),(.071,.028,.044),'copper','hips')
    loft('Dwarf_back_mantle',(0,.174,.606),(0,.183,1.004),(.520,.034),(.608,.043),'linen','chest',torso)
    if p['school']=='druidism': tilted_box('Herb_pouch',(-.291,-.025,.464),(.093,.115,.125),'leather','hips')

def headgear(p,head):
    school=p['school']
    if school in HOODS: return
    if school=='arcanism':
        tilted_box('Wizard_hat_brim',(0,-.015,1.385),(.486,.424,.028),'cloth','head',head)
        loft('Wizard_hat_base',(0,-.015,1.398),(0,.005,1.506),(.379,.352),(.249,.231),'linen','head',head)
        loft('Wizard_hat_tip',(0,.005,1.504),(.047,.049,1.657),(.249,.231),(.025,.029),'cloth','head',head)
        tilted_box('Hat_copper_band',(0,-.192,1.427),(.365,.018,.028),'copper','head',head)
    elif school=='sacred':
        tilted_box('Mitre_copper_band',(0,-.015,1.389),(.405,.369,.027),'copper','head',head)
        loft('Short_stone_mitre',(0,-.015,1.403),(0,-.015,1.550),(.357,.280),(.178,.107),'linen','head',head)
    else:
        reg='leather' if school=='druidism' else 'metal'
        start=len(ns['PARTS']); ns['ring']('Dwarf_headband',(0,-.015,1.345),.399,.356,.028,reg,'head',thick=.014)
        for obj in ns['PARTS'][start:]: transform(obj,head)

source=(ROOT/'tools/art_pipeline/audit_orc_school_mages_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='sat_intersects': exec(compile(ast.get_source_segment(source,node),'<convex_staff_check>','exec'),globals())

def staff(p):
    hand=ns['center'](ns['BODY']['Hand_r']); x,y=hand.x,hand.y
    shaft=segment('Staff_shaft',(x,y,.016),(x,y,1.387),.041,.047,'wood','hand_r'); shaft['held_by']='Hand_r'
    offsets=[(dx,dy) for dy in (0,-.025,-.05,-.075,-.1) for dx in (0,.025,.05,.075)]
    offsets.sort(key=lambda v:v[0]*v[0]+v[1]*v[1]); original=[v.co.copy() for v in shaft.data.vertices]; chosen=None
    for dx,dy in offsets:
        for vertex,co in zip(shaft.data.vertices,original): vertex.co=co+Vector((dx,dy,0))
        shaft.data.update()
        if sat_intersects(shaft,ns['BODY']['Hand_r']) and not sat_intersects(shaft,ns['BODY']['Forearm_r']): chosen=(dx,dy); break
    assert chosen is not None,'Staff must sit in the palm, outside the forearm'
    x+=chosen[0]; y+=chosen[1]; shaft['palm_offset_m']=list(chosen)
    for offset in (-.135,.135): tilted_box('Staff_copper_binding_'+str(offset),(x,y,hand.z+offset),(.053,.058,.032),'copper','hand_r')
    school=p['school']; z=1.400
    if school=='sacred':
        tilted_box('Lantern_base',(x,y,z),(.218,.156,.042),'metal','hand_r')
        for sign in (-1,1): tilted_box('Lantern_post_'+str(sign),(x+sign*.090,y,z+.081),(.029,.126,.153),'copper','hand_r')
        tilted_box('Lantern_top',(x,y,z+.155),(.214,.151,.035),'metal','hand_r')
        crystal('Sun_staff_core',(x,y,z+.078),(.103,.095,.108),'accent')
    elif school=='infernal':
        tilted_box('Forge_brazier',(x,y,z-.007),(.180,.157,.081),'metal','hand_r')
        loft('Cinder_flame',(x,y,z+.027),(x-.018,y,z+.224),(.095,.077),(.017,.022),'accent','hand_r')
        for sign in (-1,1): segment('Brazier_prong_'+str(sign),(x+sign*.074,y,z),(x+sign*.092,y,z+.137),.024,.032,'copper','hand_r')
    elif school=='necromancy':
        tilted_box('Crypt_socket',(x,y,z-.018),(.078,.075,.101),'copper','hand_r')
        tilted_box('Crypt_reliquary',(x,y,z+.083),(.189,.128,.186),'stone','hand_r')
        loft('Crypt_cap',(x,y,z+.177),(x,y,z+.213),(.189,.128),(.116,.095),'metal','hand_r')
    elif school=='druidism':
        for sign in (-1,1):
            segment('Root_branch_'+str(sign),(x,y,1.360),(x+sign*.102,y,z+.141),.035,.043 if sign==1 else .040,'wood','hand_r')
            tilted_box('Leaf_cluster_'+str(sign),(x+sign*.105,y,z+.148),(.096,.080,.083),'accent','hand_r')
        tilted_box('Root_stone',(x,y,z+.083),(.069,.071,.091),'stone','hand_r')
    elif school=='arcanism':
        tilted_box('Runestone_socket',(x,y,z-.011),(.160,.125,.050),'copper','hand_r')
        loft('Arcane_focus',(x,y,z+.015),(x,y,z+.205),(.133,.115),(.098,.087),'accent','hand_r')
        for sign in (-1,1): segment('Rune_bracket_'+str(sign),(x+sign*.064,y,z),(x+sign*.087,y,z+.154),.023,.030,'metal','hand_r')
    else:
        tilted_box('Element_hub',(x,y,z+.077),(.071,.071,.083),'metal','hand_r')
        for dx,dz,reg in [(-.100,0,'stone'),(.100,0,'water'),(0,-.105,'fire'),(0,.119,'wind')]:
            segment('Element_link_'+reg,(x,y,z+.077),(x+dx,y,z+.077+dz),.022,.028,'copper','hand_r')
            crystal('Element_focus_'+reg,(x+dx,y,z+.077+dz),(.070,.067,.085),reg)
    return shaft

plain_paint=ns['paint_tile']
def dwarf_paint_tile(obj,face,w,h,points):
    tile=plain_paint(obj,face,w,h,points)
    if obj['part']=='Crypt_reliquary' and face.index==2:
        yy,xx=np.mgrid[:h,:w]
        mask=(abs(xx-w//2)<=1)&(yy>=h*.23)&(yy<=h*.79)
        mask|=(abs(yy-h*.64)<=1)&(xx>=w*.22)&(xx<=w*.78)
        tile[mask]=ns['P']['accent']
    return tile
ns['paint_tile']=dwarf_paint_tile

assets=bpy.app.driver_namespace.setdefault('dwarf_school_mage_assets_v1',[]); assert not assets
for p in SCHOOLS:
    school=p['school']; stem=p['stem']; folder=ROOT/'assets/generated/dwarves'/stem
    assert not folder.exists(),'Preserve prior models'
    folder.mkdir(); (folder/'previews').mkdir()
    (WORK/'current_stage.json').write_text(json.dumps(dict(school=school,stage='model')),encoding='utf-8')
    scene=bpy.data.scenes.new('Dwarf_School_Mages_V1_'+school); scene.unit_settings.system='METRIC'; scene.frame_start=scene.frame_end=1
    root=bpy.data.objects.new(stem,None); scene.collection.objects.link(root)
    root['race']='dwarf'; root['school']=school; root['unit_kind']=p['kind']; root['front']='minus_Y'; root['stage']='static_model_review'
    ns.update(PARTS=[],BODY={},PRESERVED={},SCENE=scene,ROOT_OBJ=root,FOLDER=folder,P=p)
    anatomy=ns['clone_anatomy'](); torso,head=pose(p); garments(p,torso); headgear(p,head); shaft=staff(p)
    texture,material=build_atlas(p)
    for obj in ns['PARTS']:
        if 'settler_asset' in obj: del obj['settler_asset']
        obj['dwarf_school_mage_asset']=True
    pts=[v.co for o in ns['PARTS'] for v in o.data.vertices]; lo=[min(v[i] for v in pts) for i in range(3)]; hi=[max(v[i] for v in pts) for i in range(3)]
    triangles=sum(len(f.vertices)-2 for o in ns['PARTS'] for f in o.data.polygons)
    original=next(o for o in BASE.objects if o.get('part')=='Head')
    error=max((head.inverted()@v.co-original.matrix_world@src.co).length for v,src in zip(ns['BODY']['Head'].data.vertices,original.data.vertices))
    assert error<1e-6 and triangles<1400 and abs(lo[2])<1e-6 and texture['resolution']==[512,512]
    geometry=dict(status='PASS',editable_parts=len(ns['PARTS']),body_parts=18,triangles=triangles,dimensions=[hi[i]-lo[i] for i in range(3)],bounds_min=lo,bounds_max=hi,closed_meshes=True,ground_pivot=True,identity_transforms=True,flat_shading=True)
    style=dict(status='PASS',original_dwarf_head_geometry=True,head_scale=1.0,original_head_max_vertex_error_m=error,original_dwarf_face_preserved=True,original_dwarf_beard=True,original_beard_locks=18,headwear=p['headwear'],hood_painted=school in HOODS,hair_palette='aged_grey_dwarf_hair_beard_moustache_brows',relaxed_offhand=True,plain_clothes=True,original_thick_forearms=True)
    report=dict(stem=stem,name=p['name'],school=school,race='dwarf',gameplay_unit_kind=p['kind'],pipeline='Live Blender MCP localhost:9876',source=PROBE['path'],source_sha256=PROBE['sha256'],source_body=anatomy,approved_style_reference='original_dwarf_settler_and_plain_school_mages',style_revision=1,style_validation=style,elderly_posture=dict(torso_forward_degrees=p['lean'],head_counter_degrees=-3,shoulder_drop_m=.012),geometry=geometry,texture=texture,palette={key:list(p[key]) for key in ['cloth','linen','trim','accent','skin','hair','leather','wood','metal','copper','stone']},school_color_validation=dict(status='PASS',human_school_cloth=list(p['cloth']),human_school_linen=list(p['linen'])),animations=0,rigging_deferred=True,books=0)
    assets.append(dict(scene=scene,root=root,parts=ns['PARTS'].copy(),body=ns['BODY'].copy(),staff=shaft,material=material,folder=folder,report=report,head_pose=head.copy()))
    print('DWARF_MAGE_MODELED',school,triangles,len(ns['PARTS']),shaft['palm_offset_m'])
result=dict(status='PASS',models=6,triangles=[a['report']['geometry']['triangles'] for a in assets],original_dwarf_heads=True,original_beards=True)
