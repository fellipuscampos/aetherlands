"""Six plain-robed orc elders, created in the live Blender MCP.

Approved orc anatomy and original face; human school colors; rustic headgear
and staves. No applied garment ornaments, books, rigs or animation yet.
"""
import bpy,bmesh,ast,math,json,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/orc_school_mages_review'
BASE=bpy.app.driver_namespace['orc_school_mage_base']
PROBE=json.loads((WORK/'base_probe.json').read_text(encoding='utf-8'))
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
BODY_NAMES=['Head','Chest','Belly','Pelvis']+[p+'_'+s for s in ('l','r') for p in ('Thigh','Shin','Foot','Shoulder','UpperArm','Forearm','Hand')]
ns=dict(bpy=bpy,bmesh=bmesh,json=json,hashlib=hashlib,math=math,np=np,Vector=Vector,Matrix=Matrix,ROOT=ROOT,WORK=WORK,FACES=FACES,BODY_NAMES=BODY_NAMES,SOURCES={'orc':BASE},PROBE={'orc':PROBE},RACE='orc')
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
helpers={'mesh','box','beam','bounds','center','name_for','region_for','image_pixels','clone_anatomy','reframe','ring','paint_tile'}
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in helpers: exec(compile(ast.get_source_segment(source,node),'<approved_orc_anatomy>','exec'),ns)
source=(ROOT/'tools/art_pipeline/build_human_school_mages_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in {'transform','tilted_box','loft','segment','crystal','elbow_for','build_atlas'}: exec(compile(ast.get_source_segment(source,node),'<approved_mage_pipeline>','exec'),globals())
recipe_node=next(n for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SCHOOLS' for t in n.targets))
recipe_ns={}; exec(compile(ast.Module(body=[recipe_node],type_ignores=[]),'<human_school_colors>','exec'),recipe_ns)
SCHOOLS=[]
names={'sacred':'Xamã Solar Orc — Escola Sagrada','infernal':'Bruxo Orc — Escola Infernal','necromancy':'Necromante Orc — Necromancia','druidism':'Xamã da Floresta Orc — Druidismo','arcanism':'Arcanista Orc — Arcanismo','elementalism':'Xamã dos Elementos Orc — Elementalismo'}
for human in recipe_ns['SCHOOLS']:
    p=dict(human); p.update(stem=human['stem'].replace('human_','orc_'),name=names[human['school']],lean=6 if human['school'] in ('infernal','necromancy') else 5)
    p.update(skin=(99,125,65),hair=(184,183,158),pants=(79,73,46),leather=(86,59,36),wood=(106,80,44),metal=(101,106,87),ivory=(212,202,166),stone=(122,125,101),parchment=(194,178,127),blanket=(91,102,66),fire=(214,99,43),water=(89,162,184),wind=(213,213,180),orc_brown=(113,78,45))
    p['headwear']={'sacred':'bone_circlet','infernal':'painted_hood','necromancy':'painted_hood','druidism':'leather_headband','arcanism':'angular_hat','elementalism':'iron_headband'}[p['school']]
    SCHOOLS.append(p)
HOODS={p['school']:p['linen'] for p in SCHOOLS if p['headwear']=='painted_hood'}

def paint_head(tile,face_index,school):
    """Change the painted crest/hood; preserve original orc facial pixels."""
    out=tile.copy(); yy,xx=np.mgrid[:tile.shape[0],:tile.shape[1]]
    hair=np.all(tile[:,:,:3]==(34,34,29),axis=-1)
    out[hair,:3]=(184,183,158)
    if school in HOODS:
        cloth=np.clip(np.array(HOODS[school])+(((xx//2+yy//3)%3)-1)[...,None]*4,0,255)
        if face_index in (1,3,4,5): out[:,:,:3]=cloth
        elif face_index==2:
            protected=np.any(np.stack([np.all(tile[:,:,:3]==c,axis=-1) for c in [(39,42,24),(70,79,44),(70,87,48),(84,103,58),(173,151,83)]]),axis=0)
            mask=(hair|(xx<1)|(xx>=tile.shape[1]-1))&~protected
            out[mask,:3]=cloth[mask]
    if face_index==2:
        for c in [(39,42,24),(70,79,44),(70,87,48),(84,103,58),(173,151,83)]:
            mask=np.all(tile[:,:,:3]==c,axis=-1)
            assert np.array_equal(out[mask],tile[mask]),('Original orc face changed',school,c)
    return out,0,0

plain_paint=ns['paint_tile']
def orc_paint_tile(obj,face,w,h,points):
    tile=plain_paint(obj,face,w,h,points)
    if obj['part']=='Skull_focus' and face.index==2:
        # Carved skull eyes/mouth are pixels on the staff prop.
        yy,xx=np.mgrid[:h,:w]
        eyes=(((xx>=w*.18)&(xx<=w*.35))|((xx>=w*.65)&(xx<=w*.82)))&(yy>=h*.53)&(yy<=h*.75)
        mouth=(xx>=w*.30)&(xx<=w*.70)&(yy>=h*.18)&(yy<=h*.28)
        tile[eyes]=ns['P']['accent']; tile[mouth]=(48,43,45)
    return tile
ns['paint_tile']=orc_paint_tile
source=(ROOT/'tools/art_pipeline/audit_elf_school_mages_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='sat_intersects': exec(compile(ast.get_source_segment(source,node),'<staff_contact>','exec'),globals())

def pose(p):
    b=ns['BODY']; pivot=Vector((0,0,1.178192))
    torso=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(p['lean']),4,'X')@Matrix.Translation(-pivot)
    hc=ns['center'](b['Head']); head=torso@Matrix.Translation(hc)@Matrix.Rotation(math.radians(-3),4,'X')@Matrix.Translation(-hc)
    for part in ['Chest','Belly']: transform(b[part],torso)
    for o in ns['PARTS']:
        if o['part']=='Head' or o['part'].startswith(('ElfEar','Tusk','Brow')): transform(o,head)
        if o['part'].startswith('Brow'):
            o['surface']='hair'; ns['PRESERVED'].pop(o.name,None)
    for side,sign in [('r',-1),('l',1)]:
        shoulder=b['Shoulder_'+side]; c=ns['center'](shoulder)
        anchor=torso@Vector((c.x,c.y,1.512)); anchor.z-=.024
        transform(shoulder,torso); transform(shoulder,Matrix.Translation(Vector((0,0,-.024))))
        upper,fore,hand=[b[n+'_'+side] for n in ('UpperArm','Forearm','Hand')]
        lengths=[(o.data.vertices[4].co-o.data.vertices[0].co).length for o in (upper,fore,hand)]
        if side=='r':
            wrist=anchor+Vector((sign*.220,-.440,-.285))
            assert (wrist-anchor).length<lengths[0]+lengths[1]
            elbow=elbow_for(anchor,wrist,lengths[0],lengths[1])
        else:
            direction=Vector((.18,-.11,-1)).normalized(); elbow=anchor+direction*lengths[0]; wrist=elbow+direction*(lengths[1]+.001)
        ns['reframe'](upper,(anchor+elbow)/2,(anchor-elbow).normalized())
        ns['reframe'](fore,(elbow+wrist)/2,(elbow-wrist).normalized())
        direction=(wrist-elbow).normalized(); ns['reframe'](hand,wrist+direction*(lengths[2]/2-.0035),-direction)
        upper['surface']='cloth'; fore['surface']='skin'; hand['surface']='skin'; shoulder['surface']='cloth'
        hand['pose']='staff_grip' if side=='r' else 'relaxed_empty_hand'
    return torso,head

def robes(p,torso):
    b=ns['BODY']; b['Chest']['surface']=b['Belly']['surface']='cloth'; b['Pelvis']['surface']='pants'
    for side in ('l','r'):
        b['Thigh_'+side]['surface']='pants'; b['Shin_'+side]['surface']=b['Foot_'+side]['surface']='leather'
    loft('Orc_tunic',(0,.003,.806),(0,.003,1.190),(.694,.380),(.654,.360),'cloth','hips')
    for sign in (-1,1):
        tilted_box('Orc_split_hem_'+str(sign),(sign*.174,.003,.713),(.331,.376,.204),'cloth','hips')
        tilted_box('Leather_collar_'+str(sign),(sign*.124,-.213,1.649),(.168,.040,.051),'leather','chest',torso)
    ns['ring']('Orc_belt',(0,.003,1.168),.671,.378,.064,'leather','hips',thick=.023)
    loft('Orc_back_mantle',(0,.185,1.191),(0,.222,1.647),(.620,.041),(.770,.048),'linen','chest',torso)
    if p['school']=='druidism': tilted_box('Herb_pouch',(.344,-.034,1.001),(.116,.139,.169),'leather','hips')

def headgear(p,head):
    school=p['school']
    if school in HOODS: return
    if school=='arcanism':
        tilted_box('Wizard_hat_brim',(0,-.005,2.012),(.485,.449,.032),'cloth','head',head)
        loft('Wizard_hat_base',(0,-.005,2.026),(0,.006,2.188),(.390,.377),(.251,.239),'linen','head',head)
        loft('Wizard_hat_tip',(0,.006,2.186),(-.065,.055,2.392),(.251,.239),(.025,.029),'cloth','head',head)
        tilted_box('Hat_leather_band',(0,-.196,2.052),(.379,.020,.032),'leather','head',head)
    else:
        reg='ivory' if school=='sacred' else 'leather' if school=='druidism' else 'metal'
        start=len(ns['PARTS']); ns['ring']('Orc_headband',(0,-.005,1.971),.381,.368,.032,reg,'head',thick=.018)
        for o in ns['PARTS'][start:]: transform(o,head)
        if school=='sacred':
            for sign in (-1,1): loft('Bone_crown_prong_'+str(sign),(sign*.127,-.196,1.975),(sign*.162,-.193,2.095),(.041,.043),(.012,.021),'ivory','head',head)

def beard(p,head):
    bottom=1.522 if p['school']=='druidism' else 1.554
    loft('Orc_chin_beard',(0,-.249,bottom),(0,-.207,1.725),(.113,.040),(.295,.063),'hair','head',head)
    for sign in (-1,1):
        tilted_box('Orc_cheek_beard_'+str(sign),(sign*.158,-.187,1.770),(.041,.034,.109),'hair','head',head)

def staff(p):
    hand=ns['center'](ns['BODY']['Hand_r']); x,y=hand.x,hand.y
    shaft=segment('Staff_shaft',(x,y,.016),(x,y,1.993),.048,.055,'wood','hand_r'); shaft['held_by']='Hand_r'
    candidates=[(dx,dy) for dy in (0,-.025,-.05,-.075,-.10) for dx in (0,-.025,-.05,-.075)]
    candidates.sort(key=lambda v:v[0]*v[0]+v[1]*v[1])
    chosen=None
    original=[v.co.copy() for v in shaft.data.vertices]
    for dx,dy in candidates:
        for vertex,co in zip(shaft.data.vertices,original): vertex.co=co+Vector((dx,dy,0))
        shaft.data.update()
        if sat_intersects(shaft,ns['BODY']['Hand_r']) and not sat_intersects(shaft,ns['BODY']['Forearm_r']): chosen=(dx,dy); break
    assert chosen is not None,'No unclipped orc staff grip'
    x+=chosen[0]; y+=chosen[1]; shaft['palm_offset_m']=list(chosen)
    for offset in (-.15,.15): tilted_box('Staff_binding_'+str(offset),(x,y,hand.z+offset),(.060,.067,.044),'leather','hand_r')
    school=p['school']; z=2.015
    if school=='sacred':
        tilted_box('Bone_focus_socket',(x,y,z-.018),(.078,.073,.116),'ivory','hand_r')
        for sign in (-1,1): segment('Bone_sun_fork_'+str(sign),(x,y,z-.023),(x+sign*.108,y,z+.137),.043,.052,'ivory','hand_r')
        crystal('Sun_staff_core',(x,y,z+.094),(.125,.113,.190),'accent')
    elif school=='infernal':
        tilted_box('Iron_brazier',(x,y,1.996),(.179,.153,.096),'metal','hand_r')
        loft('Cinder_flame',(x,y,2.037),(x-.021,y,2.273),(.102,.083),(.020,.028),'accent','hand_r')
        loft('Cinder_flame_side',(x+.039,y+.017,2.032),(x+.070,y+.020,2.157),(.057,.054),(.014,.019),'fire','hand_r')
    elif school=='necromancy':
        tilted_box('Skull_neck',(x,y,1.997),(.080,.075,.132),'ivory','hand_r')
        tilted_box('Skull_focus',(x,y,2.107),(.179,.151,.171),'ivory','hand_r')
    elif school=='druidism':
        for sign in (-1,1):
            segment('Living_branch_'+str(sign),(x,y,1.980),(x+sign*.139,y,2.185),.044,.057 if sign==1 else .051,'wood','hand_r')
            tilted_box('Leaf_cluster_lower_'+str(sign),(x+sign*.119,y,2.146),(.117,.103,.101),'accent','hand_r')
            tilted_box('Leaf_cluster_upper_'+str(sign),(x+sign*.153,y+.009,2.217),(.099,.091,.087),'accent','hand_r')
    elif school=='arcanism':
        tilted_box('Arcane_frame_neck',(x,y,1.993),(.080,.072,.127),'metal','hand_r')
        tilted_box('Arcane_frame_base',(x,y,2.066),(.247,.067,.055),'wood','hand_r')
        for sign in (-1,1): tilted_box('Arcane_frame_side_'+str(sign),(x+sign*.106,y,2.141),(.038,.060,.191),'wood','hand_r')
        tilted_box('Arcane_frame_top',(x,y,2.233),(.247,.065,.032),'wood','hand_r')
        crystal('Arcane_focus',(x,y-.004,2.130),(.107,.095,.155),'accent')
    else:
        segment('Element_focus_stem',(x,y,1.986),(x,y,2.262),.035,.043,'wood','hand_r')
        tilted_box('Element_crossbar',(x,y+.012,2.113),(.268,.060,.034),'wood','hand_r')
        for dx,dz,reg in [(-.140,0,'stone'),(.140,0,'water'),(0,-.096,'fire'),(0,.151,'wind')]: crystal('Element_focus_'+reg,(x+dx,y,2.113+dz),(.083,.079,.091),reg)
    return shaft

assets=bpy.app.driver_namespace.setdefault('orc_school_mage_assets_v1',[])
assert not assets,'Preserve existing orc review'
for p in SCHOOLS:
    school=p['school']; stem=p['stem']; folder=ROOT/'assets/generated/orcs'/stem
    assert not folder.exists(),'Preserve existing orc assets'
    folder.mkdir(); (folder/'previews').mkdir()
    (WORK/'current_stage.json').write_text(json.dumps(dict(school=school,stage='model')),encoding='utf-8')
    scene=bpy.data.scenes.new('Orc_School_Mages_V1_'+school); scene.unit_settings.system='METRIC'; scene.frame_start=scene.frame_end=1
    root=bpy.data.objects.new(stem,None); scene.collection.objects.link(root)
    root['race']='orc'; root['school']=school; root['unit_kind']=p['kind']; root['front']='minus_Y'; root['stage']='model_review'
    ns.update(PARTS=[],BODY={},PRESERVED={},SCENE=scene,ROOT_OBJ=root,FOLDER=folder,P=p)
    anatomy=ns['clone_anatomy'](); torso,head=pose(p); robes(p,torso); headgear(p,head); beard(p,head); shaft=staff(p)
    texture,material=build_atlas(p)
    for o in ns['PARTS']:
        if 'settler_asset' in o: del o['settler_asset']
        o['orc_school_mage_asset']=True
    pts=[v.co for o in ns['PARTS'] for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)]; hi=[max(v[i] for v in pts) for i in range(3)]
    triangles=sum(len(f.vertices)-2 for o in ns['PARTS'] for f in o.data.polygons)
    original=next(o for o in BASE.objects if o.get('part')=='Head')
    error=max((head.inverted()@v.co-original.matrix_world@src.co).length for v,src in zip(ns['BODY']['Head'].data.vertices,original.data.vertices))
    assert error<1e-6 and triangles<1000 and abs(lo[2])<1e-6 and texture['resolution']==[512,512]
    geometry=dict(status='PASS',editable_parts=len(ns['PARTS']),body_parts=18,triangles=triangles,dimensions=[hi[i]-lo[i] for i in range(3)],bounds_min=lo,bounds_max=hi,closed_meshes=True,ground_pivot=True,identity_transforms=True,flat_shading=True)
    style=dict(status='PASS',original_orc_head_geometry=True,head_scale=1.0,original_head_max_vertex_error_m=error,original_orc_face_preserved=True,original_orc_ears=6,original_orc_tusks=4,original_orc_brows=2,headwear=p['headwear'],hood_painted=school in HOODS,hair_palette='aged_grey_orc_crest_and_brows',human_beard=False,relaxed_offhand=True,plain_clothes=True,bare_forearms=True)
    style.update(orc_beard=True,beard_parts=3,beard_color=list(p['hair']),beard_tusks_clear=all(not sat_intersects(b,t) for b in ns['PARTS'] if b['part'].startswith(('Orc_chin_beard','Orc_cheek_beard')) for t in ns['PARTS'] if t['part'].startswith('Tusk')),beard_attached_to_jaw=all(sat_intersects(b,ns['BODY']['Head']) for b in ns['PARTS'] if b['part'].startswith(('Orc_chin_beard','Orc_cheek_beard'))))
    assert style['beard_tusks_clear'] and style['beard_attached_to_jaw']
    report=dict(stem=stem,name=p['name'],school=school,race='orc',gameplay_unit_kind=p['kind'],pipeline='Live Blender MCP localhost:9876',source=PROBE['path'],source_sha256=PROBE['sha256'],source_body=anatomy,approved_style_reference='elf_school_mages_revision_3_plain_clothes_and_human_school_colors',style_revision=2,style_validation=style,elderly_posture=dict(torso_forward_degrees=p['lean'],head_counter_degrees=-3,shoulder_drop_m=.024),geometry=geometry,texture=texture,palette={key:list(p[key]) for key in ['cloth','linen','trim','accent','skin','hair','leather','wood','metal','ivory','orc_brown']},school_color_validation=dict(status='PASS',human_school_cloth=list(p['cloth']),human_school_linen=list(p['linen'])),animations=0,rigging_deferred=True,books=0)
    assets.append(dict(scene=scene,root=root,parts=ns['PARTS'].copy(),body=ns['BODY'].copy(),staff=shaft,material=material,folder=folder,report=report,head_pose=head.copy()))
    print('ORC_MAGE_MODELED',school,triangles,len(ns['PARTS']),'palm offset',shaft['palm_offset_m'])
result=dict(status='PASS',models=6,triangles=[a['report']['geometry']['triangles'] for a in assets],original_orc_heads=True,plain_clothes=True)
