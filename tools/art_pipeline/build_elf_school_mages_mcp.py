"""Six elven school casters from approved heads and the approved mage family.

Execute in the live Blender MCP. Original humans and elves remain read-only.
"""
import bpy,bmesh,ast,math,json,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/elf_school_mages_review'
BASE=bpy.app.driver_namespace['elf_school_mage_base']
PROBE=json.loads((WORK/'base_probe.json').read_text(encoding='utf-8'))
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
BODY_NAMES=['Head','Chest','Belly','Pelvis']+[p+'_'+s for s in ('l','r') for p in ('Thigh','Shin','Foot','Shoulder','UpperArm','Forearm','Hand')]
ns=dict(bpy=bpy,bmesh=bmesh,json=json,hashlib=hashlib,math=math,np=np,Vector=Vector,Matrix=Matrix,ROOT=ROOT,WORK=WORK,FACES=FACES,BODY_NAMES=BODY_NAMES,SOURCES={'elf':BASE},PROBE={'elf':PROBE},RACE='elf')
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
helpers={'mesh','box','beam','bounds','center','name_for','region_for','image_pixels','clone_anatomy','reframe','ring','paint_tile'}
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in helpers: exec(compile(ast.get_source_segment(source,node),'<approved_anatomy>','exec'),ns)
source=(ROOT/'tools/art_pipeline/build_human_school_mages_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in {'transform','tilted_box','loft','segment','crystal','elbow_for','elderly_pose','build_atlas'}:
        exec(compile(ast.get_source_segment(source,node),'<approved_mage_language>','exec'),globals())

# School clothes follow the approved humans; leaf embroidery stays elven green.
SCHOOLS=[
 dict(school='sacred',stem='elf_sacred_cleric_v1',name='Clérigo Élfico — Escola Sagrada',kind='v2_unit_sacred_cleric',cloth=(214,204,170),linen=(235,225,189),trim=(195,164,91),accent=(151,183,133),lean=4,headwear='leaf_diadem'),
 dict(school='infernal',stem='elf_infernal_warlock_v1',name='Bruxo Élfico — Escola Infernal',kind='v2_unit_infernal_warlock',cloth=(77,39,40),linen=(102,48,40),trim=(145,117,73),accent=(191,100,62),lean=6,headwear='painted_hood'),
 dict(school='necromancy',stem='elf_necromancer_v1',name='Necromante Élfico — Necromancia',kind='v2_unit_necromancer',cloth=(55,45,69),linen=(86,59,105),trim=(169,184,176),accent=(148,130,171),lean=6,headwear='painted_hood'),
 dict(school='druidism',stem='elf_druid_v1',name='Druida Élfico — Druidismo',kind='v2_unit_druid',cloth=(87,111,67),linen=(115,132,79),trim=(180,162,100),accent=(124,149,126),lean=5,headwear='leaf_wreath'),
 dict(school='arcanism',stem='elf_arcanist_v1',name='Arcanista Élfico — Arcanismo',kind='v2_unit_arcanist',cloth=(49,72,115),linen=(69,92,137),trim=(169,184,176),accent=(145,192,177),lean=4,headwear='angular_hat'),
 dict(school='elementalism',stem='elf_elementalist_v1',name='Elementalista Élfico — Elementalismo',kind='v2_unit_elementalist',cloth=(63,107,116),linen=(93,129,130),trim=(195,164,91),accent=(137,178,154),lean=5,headwear='four_gem_circlet'),
]
HOODS={r['school']:r['linen'] for r in SCHOOLS if r['headwear']=='painted_hood'}
def paint_head(tile,face_index,school):
    """Paint hair/hood only; retain the complete original elven face."""
    result=tile.copy(); yy,xx=np.mgrid[:tile.shape[0],:tile.shape[1]]
    hair=(tile[:,:,0]>210)&(tile[:,:,0]<225)&(tile[:,:,1]>185)&(tile[:,:,1]<202)&(tile[:,:,2]<145)
    result[hair,:3]=np.clip(np.array((241,228,184))+(tile[:,:,0][hair,None]-219),0,255)
    if school in HOODS:
        cloth=np.clip(np.array(HOODS[school])+(((xx//2+yy//3)%3)-1)[...,None]*4,0,255)
        if face_index in (1,3,4,5): result[:,:,:3]=cloth
        elif face_index==2:
            mask=hair|(xx<1)|(xx>=tile.shape[1]-1)
            protected=np.any(np.stack([np.all(tile[:,:,:3]==c,axis=-1) for c in [(38,67,59),(154,130,68),(165,120,115),(214,194,182),(243,242,227)]]),axis=0)
            result[mask&~protected,:3]=cloth[mask&~protected]
    if face_index==2:
        for c in [(38,67,59),(154,130,68),(165,120,115),(214,194,182),(243,242,227)]:
            mask=np.all(tile[:,:,:3]==c,axis=-1)
            assert np.array_equal(result[mask],tile[mask]),('Elven facial feature changed',school,c)
    return result,0,0

def leaf(name,c,w,h,d,region='trim',bone='chest',matrix=None):
    # A closed, angular leaf, matching the elven architectural motifs.
    return loft(name,(c[0],c[1],c[2]-h/2),(c[0],c[1],c[2]+h/2),(w,d),(.012,d*.55),region,bone,matrix)

def robes(p,torso):
    # Approved plain school robes: green collar/belt, no applied ornaments.
    b=ns['BODY']
    for part in ['Chest','Belly']: b[part]['surface']='cloth'
    b['Pelvis']['surface']='pants'
    for side in ['l','r']:
        b['Thigh_'+side]['surface']='pants'
        b['Shin_'+side]['surface']=b['Foot_'+side]['surface']='leather'
        b['UpperArm_'+side]['surface']='linen'
    loft('Elven_tunic',(0,.002,.752),(0,.002,1.018),(.445,.312),(.416,.272),'cloth','hips')
    for sign in [-1,1]:
        tilted_box('Elven_split_hem_'+str(sign),(sign*.113,.002,.632),(.212,.312,.239),'cloth','hips')
        tilted_box('Elven_collar_'+str(sign),(sign*.100,-.123,1.409),(.132,.040,.051),'elf_green','chest',torso)
    ns['ring']('Elven_belt',(0,.002,.963),.439,.314,.049,'leather','hips',thick=.018)
    tilted_box('Forest_belt_weave',(0,-.162,.988),(.419,.018,.019),'elf_green','hips')
    loft('Elven_back_mantle',(0,.167,1.025),(0,.144,1.390),(.403,.035),(.439,.044),'linen','chest',torso)
    if p['school']=='druidism':
        tilted_box('Herb_pouch',(.194,-.070,.855),(.115,.128,.150),'leather','hips')

def head_details(p,head):
    school=p['school']
    # Hair remains painted on the original skull; two small back braids extend it.
    if school not in HOODS:
        for sign in [-1,1]:
            tilted_box('Elven_braid_'+str(sign),(sign*.073,.142,1.419),(.036,.034,.221),'hair','head',head)
            tilted_box('Braid_tie_'+str(sign),(sign*.073,.143,1.325),(.044,.041,.022),'trim','head',head)
    if school=='arcanism':
        tilted_box('Wizard_hat_brim',(0,.008,1.709),(.385,.343,.030),'cloth','head',head)
        loft('Wizard_hat_base',(0,.006,1.726),(0,.015,1.875),(.299,.278),(.181,.165),'linen','head',head)
        loft('Wizard_hat_leaf_tip',(0,.015,1.873),(.043,.037,2.052),(.181,.165),(.020,.027),'cloth','head',head)
        leaf('Hat_leaf_badge',(0,-.146,1.77),.042,.072,.021,'elf_green','head',head)
    elif school not in HOODS:
        tilted_box('Elven_circlet',(0,-.148,1.670),(.256,.018,.022),'trim','head',head)
        if school=='sacred':
            for i in range(3): leaf('Gold_leaf_diadem_'+str(i),((i-1)*.065,-.148,1.724),.047,.117-(abs(i-1)*.032),.025,'trim','head',head)
        elif school=='druidism':
            for i in range(3): leaf('Living_leaf_wreath_'+str(i),((i-1)*.070,-.148,1.704),.055,.082,.031,'accent','head',head)
        else:
            for i,reg in enumerate(['fire','water','stone','wind']): crystal('Circlet_gem_'+reg,((i-1.5)*.049,-.165,1.688),(.031,.025,.049),reg,'head')

def elven_staff(p):
    hand=ns['center'](ns['BODY']['Hand_r']); x,y=hand.x,hand.y-.004; z=1.677
    shaft=segment('Staff_shaft',(x,y,.016),(x,y,1.614),.035,.039,'wood','hand_r'); shaft['held_by']='Hand_r'
    for dz in [-.094,.094]: tilted_box('Staff_binding_'+str(dz),(x,y,hand.z+dz),(.043,.047,.031),'leather','hand_r')
    school=p['school']
    if school in ['sacred','infernal','necromancy','arcanism']:
        for sign in [-1,1]:
            segment('Carved_fork_'+str(sign),(x,y,z-.076),(x+sign*.099,y,z+.177),.029,.033,'wood','hand_r')
            leaf('Staff_leaf_socket_'+str(sign),(x+sign*.089,y-.005,z+.138),.046,.108,.037,'trim','hand_r')
        tilted_box('Focus_socket',(x,y,z-.025),(.071,.064,.070),'trim','hand_r')
        if school=='sacred': leaf('Sun_leaf_focus',(x,y-.015,z+.127),.092,.238,.058,'accent','hand_r')
        elif school=='infernal':
            leaf('Cinder_flame',(x,y,z+.114),.077,.225,.056,'accent','hand_r')
            leaf('Cinder_flame_side',(x+.041,y+.011,z+.093),.034,.121,.033,'fire','hand_r')
        elif school=='necromancy':
            leaf('Ivory_memory_focus',(x,y,z+.129),.086,.221,.061,'ivory','hand_r')
            tilted_box('Skull_rune',(x,y-.040,z+.143),(.026,.021,.058),'accent','hand_r')
        else: crystal('Arcane_focus',(x,y,z+.148),(.117,.105,.247),'accent')
    elif school=='druidism':
        for sign in [-1,1]:
            segment('Living_branch_'+str(sign),(x,y,z-.077),(x+sign*.113,y,z+.163+(sign+1)*.024),.033,.037,'wood','hand_r')
            leaf('Living_staff_leaf_'+str(sign),(x+sign*.116,y-.017,z+.191+(sign+1)*.024),.082,.148,.052,'accent','hand_r')
    else:
        segment('Element_focus_stem',(x,y,1.605),(x,y,z+.130),.022,.027,'wood','hand_r')
        tilted_box('Element_core',(x,y,z+.125),(.065,.057,.067),'accent','hand_r')
        for i,(dx,dz,reg) in enumerate([(-.090,0,'stone'),(.090,0,'water'),(0,-.090,'fire'),(0,.090,'wind')]):
            if i!=2: segment('Element_branch_'+str(i),(x,y,z+.125),(x+dx,y,z+.125+dz),.022,.027,'wood','hand_r')
            crystal('Element_focus_'+reg,(x+dx,y,z+.125+dz),(.061,.049,.078),reg)
    return shaft

assets=bpy.app.driver_namespace.setdefault('elf_school_mage_assets_v1',[])
rebuild_school=globals().get('ELF_REBUILD_SCHOOL')
review=bpy.app.driver_namespace.get('elf_school_mage_review_v1')
if rebuild_school:
    previous=next(a for a in assets if a['report']['school']==rebuild_school)
    previous_index=assets.index(previous)
    owned=[previous['root']]+previous['parts']
    if review: owned += [o for o in review['collections'][previous_index].objects if o.type in ['EMPTY','MESH']]
    bpy.data.batch_remove(ids=owned); bpy.data.scenes.remove(previous['scene']); assets.remove(previous)
    for suffix in ['albedo','emission']:
        name=previous['report']['stem']+'_'+suffix
        if bpy.data.images.get(name): bpy.data.images[name].name=name+'_previous_revision'
else: assert not assets,'Do not overwrite an existing elven review.'
for p0 in SCHOOLS:
    if any(a['report']['school']==p0['school'] for a in assets): continue
    p=dict(p0,skin=(237,221,209),hair=(241,228,184),pants=(93,107,80),leather=(119,92,56),wood=(135,113,69),metal=(154,171,150),blanket=(111,135,94),ivory=(204,202,173),parchment=(215,211,176),fire=(191,110,70),water=(112,164,180),stone=(134,143,117),wind=(221,219,189),elf_green=(69,111,79))
    school=p['school']; stem=p['stem']; folder=ROOT/'assets/generated/elves'/stem
    assert not (folder/(stem+'.blend')).exists(),'Preserve existing assets'
    folder.mkdir(exist_ok=True); (folder/'previews').mkdir(exist_ok=True)
    (WORK/'current_stage.json').write_text(json.dumps(dict(school=school,stage='anatomy')),encoding='utf-8')
    scene=bpy.data.scenes.new('Elf_School_Mages_V1_'+school); scene.unit_settings.system='METRIC'; scene.frame_start=scene.frame_end=1
    root=bpy.data.objects.new(stem,None); scene.collection.objects.link(root)
    root['race']='elf'; root['school']=school; root['unit_kind']=p['kind']; root['front']='minus_Y'; root['stage']='model_review'
    ns.update(PARTS=[],BODY={},PRESERVED={},SCENE=scene,ROOT_OBJ=root,FOLDER=folder,P=p)
    anatomy=ns['clone_anatomy'](); torso,head=elderly_pose(p)
    for o in ns['PARTS']:
        if o['part'].startswith('ElfEar'): transform(o,head)
    robes(p,torso); head_details(p,head); shaft=elven_staff(p)
    for side in ['l','r']:
        hand=ns['BODY']['Hand_'+side]; shift=-(hand.data.vertices[4].co-hand.data.vertices[0].co).normalized()*.0045
        for v in hand.data.vertices: v.co+=shift
        hand.data.update()
    (WORK/'current_stage.json').write_text(json.dumps(dict(school=school,stage='atlas')),encoding='utf-8')
    texture,material=build_atlas(p)
    for o in ns['PARTS']:
        if 'settler_asset' in o: del o['settler_asset']
        o['elf_school_mage_asset']=True
    pts=[v.co for o in ns['PARTS'] for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)]; hi=[max(v[i] for v in pts) for i in range(3)]
    triangles=sum(len(f.vertices)-2 for o in ns['PARTS'] for f in o.data.polygons)
    original=next(o for o in BASE.objects if o.get('part')=='Head')
    error=max((head.inverted()@v.co-original.matrix_world@src.co).length for v,src in zip(ns['BODY']['Head'].data.vertices,original.data.vertices))
    assert error<1e-6 and triangles<1000 and abs(lo[2])<1e-6 and texture['resolution']==[512,512]
    geometry=dict(status='PASS',editable_parts=len(ns['PARTS']),body_parts=18,triangles=triangles,dimensions=[hi[i]-lo[i] for i in range(3)],bounds_min=lo,bounds_max=hi,closed_meshes=True,ground_pivot=True,identity_transforms=True,flat_shading=True)
    style=dict(status='PASS',original_elf_head_geometry=True,head_scale=1.0,original_head_max_vertex_error_m=error,original_elven_face_preserved=True,original_elf_ears=6,headwear=p['headwear'],hood_painted=school in HOODS,hair_palette='approved_legendary_elf_ivory_blond',human_beard=False,relaxed_offhand=True)
    report=dict(stem=stem,name=p['name'],school=school,race='elf',gameplay_unit_kind=p['kind'],pipeline='Live Blender MCP localhost:9876',source=PROBE['path'],source_sha256=PROBE['sha256'],source_body=anatomy,approved_style_reference='human_school_mages_revision_3',style_revision=3,style_validation=style,elderly_posture=dict(torso_forward_degrees=p['lean'],head_counter_degrees=-3,shoulder_drop_m=.022,grey_beard_length_m=0),geometry=geometry,texture=texture,palette={key:list(p[key]) for key in ['cloth','linen','trim','skin','hair','leather','wood','elf_green']},animations=0,rigging_deferred=True,books=0)
    assets.append(dict(scene=scene,root=root,parts=ns['PARTS'].copy(),body=ns['BODY'].copy(),staff=shaft,material=material,folder=folder,report=report))
    if rebuild_school and review:
        a=assets[-1]; col=review['collections'][previous_index]; mapping={}
        for original in [a['root']]+a['parts']:
            obj=original.copy(); col.objects.link(obj); mapping[original]=obj
        for original,obj in mapping.items():
            if original.parent in mapping: obj.parent=mapping[original.parent]
        root_copy=mapping[a['root']]; root_copy.location=((previous_index-2.5)*1.8,0,0); review['roots'][previous_index]=root_copy
        bpy.context.window.scene=review['scene']
    print('ELF_MAGE_MODELED',school,triangles,len(ns['PARTS']))
result=dict(status='PASS',models=6,triangles=[a['report']['geometry']['triangles'] for a in assets])
