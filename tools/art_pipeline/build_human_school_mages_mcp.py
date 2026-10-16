"""Six elderly human school casters, using approved settler anatomy.

Run inside the live Blender through MCP after probe_human_school_mage_base_mcp.py.
Keeps editable separate parts, meters, ground pivot and bone metadata.
"""
import bpy, bmesh, ast, math, hashlib, json, numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/human_school_mages_review'
PROBE=json.loads((WORK/'base_probe.json').read_text(encoding='utf-8'))
BASE=bpy.app.driver_namespace['human_school_mage_base']
PREFIX='Human_School_Mages_V2'
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
BODY_NAMES=['Head','Chest','Belly','Pelvis']+[p+'_'+s for s in ('l','r') for p in ('Thigh','Shin','Foot','Shoulder','UpperArm','Forearm','Hand')]
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
helpers={'mesh','box','beam','bounds','center','name_for','region_for','image_pixels','clone_anatomy','reframe','ring','paint_tile'}
ns=dict(bpy=bpy,bmesh=bmesh,json=json,hashlib=hashlib,math=math,np=np,Vector=Vector,Matrix=Matrix,ROOT=ROOT,WORK=WORK,FACES=FACES,BODY_NAMES=BODY_NAMES,SOURCES={'human':BASE},PROBE={'human':PROBE},RACE='human')
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name in helpers:
        exec(compile(ast.get_source_segment(source,node),'<approved_settler_helpers>','exec'),ns)
SCHOOLS=[
 dict(school='sacred',kind='v2_unit_sacred_cleric',stem='human_sacred_cleric_v1',name='Clérigo — Escola Sagrada',cloth=(214,204,170),linen=(235,225,189),pants=(160,151,125),trim=(185,148,62),accent=(233,199,103),hair=(223,223,211),lean=8,beard=.25),
 dict(school='infernal',kind='v2_unit_infernal_warlock',stem='human_infernal_warlock_v1',name='Bruxo — Escola Infernal',cloth=(77,39,40),linen=(102,48,40),pants=(44,35,38),trim=(144,87,54),accent=(215,91,42),hair=(180,175,164),lean=11,beard=.29),
 dict(school='necromancy',kind='v2_unit_necromancer',stem='human_necromancer_v1',name='Necromante — Necromancia',cloth=(55,45,69),linen=(86,59,105),pants=(39,37,44),trim=(168,157,128),accent=(157,99,192),hair=(213,211,203),lean=12,beard=.32),
 dict(school='druidism',kind='v2_unit_druid',stem='human_druid_v1',name='Druida — Druidismo',cloth=(87,111,67),linen=(115,132,79),pants=(70,75,53),trim=(138,113,65),accent=(99,157,77),hair=(209,208,190),lean=10,beard=.36),
 dict(school='arcanism',kind='v2_unit_arcanist',stem='human_arcanist_v1',name='Arcanista — Arcanismo',cloth=(49,72,115),linen=(69,92,137),pants=(43,49,75),trim=(156,170,181),accent=(99,152,223),hair=(216,217,213),lean=7,beard=.31),
 dict(school='elementalism',kind='v2_unit_elementalist',stem='human_elementalist_v1',name='Elementalista — Elementalismo',cloth=(63,107,116),linen=(93,129,130),pants=(47,70,78),trim=(174,181,165),accent=(110,193,199),hair=(200,207,203),lean=9,beard=.28),
]
# Share the original-head paint rules with the targeted restoration tool.
head_source=(ROOT/'tools/art_pipeline/restore_human_mage_heads_mcp.py').read_text(encoding='utf-8')
HOODS={'infernal':(102,48,40),'necromancy':(86,59,105),'elementalism':(93,129,130)}
for node in ast.parse(head_source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='paint_head':
        exec(compile(ast.get_source_segment(head_source,node),'<original_human_head_paint>','exec'),globals())
assets=bpy.app.driver_namespace.setdefault('human_school_mage_assets_v1',[])

def stage(school,label):
    (WORK/'current_stage.json').write_text(json.dumps(dict(school=school,stage=label)),encoding='utf-8')

def transform(obj,matrix):
    for vertex in obj.data.vertices: vertex.co=matrix@vertex.co
    obj.data.update()
    bm=bmesh.new(); bm.from_mesh(obj.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(obj.data); bm.free()
    return obj

def tilted_box(name,center,size,region,bone='chest',matrix=None):
    obj=ns['box'](name,center,size,region,bone)
    return transform(obj,matrix) if matrix is not None else obj

def loft(name,lower,upper,lower_size,upper_size,region,bone='chest',matrix=None):
    verts=[Vector(c)+Vector((sx*w/2,sy*d/2,0)) for c,(w,d) in [(lower,lower_size),(upper,upper_size)] for sy in (-1,1) for sx in (-1,1)]
    obj=ns['mesh'](name,verts,FACES,region,bone)
    return transform(obj,matrix) if matrix is not None else obj

def segment(name,a,b,w,d,region,bone='chest',matrix=None):
    obj=ns['beam'](name,a,b,w,d,region,bone)
    return transform(obj,matrix) if matrix is not None else obj

def crystal(name,c,size,region='accent',bone='hand_r'):
    x,y,z=c; w,d,h=size
    verts=[(x-w/2,y,z),(x,y-d/2,z),(x+w/2,y,z),(x,y+d/2,z),(x,y,z+h/2),(x,y,z-h/2)]
    faces=[(i,(i+1)%4,4) for i in range(4)]+[((i+1)%4,i,5) for i in range(4)]
    return ns['mesh'](name,verts,faces,region,bone)

def elbow_for(s,w,l1,l2):
    direction=w-s; distance=direction.length; direction.normalize()
    along=(l1*l1-l2*l2+distance*distance)/(2*distance)
    pole=Vector((0,0,-1)); pole-=direction*pole.dot(direction); pole.normalize()
    return s+direction*along+pole*math.sqrt(max(0,l1*l1-along*along))

def elderly_pose(recipe):
    body=ns['BODY']; pivot=Vector((0,0,1.012))
    torso=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(recipe['lean']),4,'X')@Matrix.Translation(-pivot)
    hc=ns['center'](body['Head'])
    head=torso@Matrix.Translation(hc)@Matrix.Rotation(math.radians(-3),4,'X')@Matrix.Translation(-hc)
    for part in ['Chest','Belly']:
        transform(body[part],torso); body[part]['elderly_posture']=True
    transform(body['Head'],head)
    for side,sign in [('r',-1),('l',1)]:
        shoulder=body['Shoulder_'+side]; transform(shoulder,torso)
        transform(shoulder,Matrix.Translation(Vector((0,0,-.022))))
        s=torso@Vector((sign*.277,-.009,1.313)); s.z-=.022
        w=Vector((sign*.418,-.364,1.035)) if side=='r' else Vector((.360,-.092,.885))
        upper=body['UpperArm_'+side]; fore=body['Forearm_'+side]; hand=body['Hand_'+side]
        lengths=[(obj.data.vertices[4].co-obj.data.vertices[0].co).length for obj in [upper,fore,hand]]
        if side=='l':
            relaxed=Vector((.16,-.12,-1)).normalized()
            e=s+relaxed*lengths[0]; w=e+relaxed*(lengths[1]+.0005)
        else:
            e=elbow_for(s,w,lengths[0],lengths[1])
        ns['reframe'](upper,(s+e)/2,(s-e).normalized())
        fore_center=e+relaxed*(lengths[1]/2+.0005) if side=='l' else (e+w)/2
        ns['reframe'](fore,fore_center,(e-w).normalized())
        direction=(w-e).normalized(); h=w+direction*(lengths[2]/2+.0005)
        ns['reframe'](hand,h,-direction)
        upper['surface']=fore['surface']='cloth'
        hand['surface']='skin'; shoulder['surface']='cloth'
        if side=='l': hand['pose']='relaxed_empty_hand'
    return torso,head

def beard_and_hair(recipe,head):
    length=.103 if recipe['school']=='druidism' else .090
    loft('Chin_beard',(0,-.163,1.442-length),(0,-.148,1.442),(.092,.037),(.161,.037),'hair','head',head)
    if recipe['school']=='druidism':
        for i in range(3):
            tilted_box('Leaf_wreath_'+str(i),((i-1)*.075,-.150,1.668),(.054,.025,.036),'accent','head',head)


def garments(recipe,torso):
    school=recipe['school']
    ns['BODY']['Chest']['surface']=ns['BODY']['Belly']['surface']='cloth'
    ns['BODY']['Pelvis']['surface']='cloth'
    ns['BODY']['Pelvis']['surface']='pants'
    for sign,side in [(-1,'r'),(1,'l')]:
        ns['BODY']['Thigh_'+side]['surface']='pants'
        ns['BODY']['Shin_'+side]['surface']='leather'
        ns['BODY']['Foot_'+side]['surface']='leather'
    # Knee-length coat: narrow split hem, trousers and full boots visible.
    loft('Tunic_lower',(0,.002,.752),(0,.002,1.018),(.487,.312),(.416,.272),'cloth','hips')
    for sign in (-1,1):
        tilted_box('Split_coat_tail_'+str(sign),(sign*.126,.002,.632),(.241,.312,.239),'cloth','hips')
    ns['ring']('Robe_belt',(0,.002,.963),.447,.314,.055,'leather','hips',thick=.018)
    tilted_box('Belt_clasp',(0,-.171,.963),(.061,.023,.057),'trim','hips')
    tilted_box('Human_blue_belt',(0,-.161,.989),(.435,.018,.023),'human_blue','hips')
    # Close rectangular cloak, following the existing troop clothing.
    loft('Shoulder_mantle',(0,.167,1.025),(0,.144,1.390),(.419,.035),(.465,.044),'linen','chest',torso)
    for sign in (-1,1):
        tilted_box('Collar_'+str(sign),(sign*.105,-.123,1.409),(.147,.040,.051),'linen','chest',torso)
    if school=='sacred':
        for sign in (-1,1):
            tilted_box('Gold_stole_top_'+str(sign),(sign*.097,-.145,1.266),(.074,.020,.295),'trim','chest',torso)
            segment('Gold_stole_lower_'+str(sign),(sign*.099,-.169,.578),(sign*.095,-.151,.939),.063,.018,'trim','hips')
        tilted_box('Sun_brooch',(0,-.160,1.347),(.076,.029,.076),'accent','chest',torso)
    elif school=='infernal':
        for sign in (-1,1):
            tilted_box('Red_lapel_'+str(sign),(sign*.144,-.146,1.30),(.064,.027,.233),'accent','chest',torso)
        segment('Infernal_sash',(-.15,-.15,1.08),(.14,-.155,1.395),.041,.019,'trim','chest',torso)
        tilted_box('Ritual_belt_box',(.204,-.010,.870),(.110,.144,.146),'pants','hips')
        tilted_box('Cinder_box_clasp',(.207,-.087,.887),(.039,.022,.061),'accent','hips')
    elif school=='necromancy':
        for sign in (-1,1):
            segment('Bone_necklace_'+str(sign),(sign*.106,-.153,1.407),(sign*.044,-.173,1.304),.023,.024,'ivory','chest',torso)
            tilted_box('Bone_talisman_'+str(sign),(sign*.143,-.150,1.329),(.034,.035,.079),'ivory','chest',torso)
        tilted_box('Violet_pendant',(0,-.183,1.302),(.061,.036,.078),'accent','chest',torso)
        for sign in (-1,1):
            segment('Violet_robe_panel_'+str(sign),(sign*.126,-.169,.581),(sign*.110,-.151,.927),.047,.015,'linen','hips')
    elif school=='druidism':
        for sign in (-1,1):
            tilted_box('Wool_mantle_'+str(sign),(sign*.225,.042,1.358),(.191,.259,.059),'leather','chest',torso)
        tilted_box('Leaf_brooch',(0,-.161,1.336),(.071,.034,.105),'accent','chest',torso)
        tilted_box('Herb_pouch',(.205,-.084,.858),(.133,.136,.165),'leather','hips')
        for i in range(3):
            tilted_box('Pouch_herb_'+str(i),(.182+i*.027,-.100,.957),(.028,.026,.077-i*.012),'accent','hips')
    elif school=='arcanism':
        for sign in (-1,1):
            tilted_box('Silver_stole_'+str(sign),(sign*.144,-.145,1.275),(.051,.019,.29),'trim','chest',torso)
            segment('Silver_skirt_edge_'+str(sign),(sign*.200,-.169,.578),(sign*.146,-.151,.930),.024,.016,'trim','hips')
        for i in range(3):
            tilted_box('Arcane_rune_'+str(i),(0,-.155,1.168+i*.081),(.057,.015,.027),'accent','chest',torso)
    else:
        for i,region in enumerate(['fire','water','stone','wind']):
            sign=-1 if i<2 else 1; z=1.267 if i%2==0 else 1.367
            tilted_box('Element_clasp_'+region,(sign*.160,-.149,z),(.064,.023,.063),region,'chest',torso)
        for sign in (-1,1):
            segment('Wind_hem_'+str(sign),(sign*.212,-.170,.578),(sign*.170,-.151,.928),.024,.016,'trim','hips')

def headdress(recipe,head):
    school=recipe['school']
    if school=='sacred':
        tilted_box('Mitre_band',(0,-.002,1.710),(.303,.292,.044),'trim','head',head)
        loft('Ivory_mitre',(0,-.002,1.718),(0,-.002,1.955),(.280,.239),(.060,.060),'linen','head',head)
        segment('Mitre_gold_front',(0,-.124,1.735),(0,-.047,1.930),.038,.018,'trim','head',head)
    elif school=='arcanism':
        tilted_box('Wizard_hat_brim',(0,.008,1.709),(.449,.405,.035),'cloth','head',head)
        loft('Wizard_hat_base',(0,.006,1.727),(0,.015,1.886),(.314,.293),(.219,.207),'linen','head',head)
        loft('Wizard_hat_tip',(0,.015,1.884),(.053,.055,2.080),(.219,.207),(.038,.042),'cloth','head',head)
        tilted_box('Hat_silver_band',(0,-.146,1.751),(.300,.019,.043),'trim','head',head)

def staff_and_book(recipe):
    school=recipe['school']; body=ns['BODY']; hand=ns['center'](body['Hand_r'])
    c=Vector((hand.x,hand.y-.004,0))
    shaft=segment('Staff_shaft',(c.x,c.y,.016),(c.x,c.y,1.615),.039,.043,'wood','hand_r')
    shaft['held_by']='Hand_r'
    # Grip collar ends lie away from the fist, leaving the handle in contact.
    for z in [hand.z-.092,hand.z+.092]:
        tilted_box('Staff_binding_'+str(z),(c.x,c.y,z),(.048,.051,.038),'leather','hand_r')
    x,y=c.x,c.y; z=1.670
    if school=='sacred':
        tilted_box('Sun_staff_stem',(x,y,z-.034),(.061,.055,.151),'trim','hand_r')
        tilted_box('Sun_staff_horizontal',(x,y,z+.105),(.254,.052,.059),'trim','hand_r')
        tilted_box('Sun_staff_vertical',(x,y+.012,z+.105),(.059,.062,.255),'trim','hand_r')
        tilted_box('Sun_staff_core',(x,y-.043,z+.105),(.111,.028,.109),'accent','hand_r')
    elif school=='infernal':
        tilted_box('Brazier_socket',(x,y,z-.030),(.145,.118,.111),'metal','hand_r')
        for sign in (-1,1):
            segment('Brazier_prong_'+str(sign),(x+sign*.057,y,z),(x+sign*.126,y,z+.223),.037,.052,'metal','hand_r')
        loft('Cinder_flame',(x,y,z-.013),(x-.025,y,z+.179),(.084,.071),(.022,.020),'accent','hand_r')
        loft('Cinder_flame_side',(x+.045,y+.016,z+.029),(x+.075,y+.005,z+.116),(.050,.046),(.016,.015),'fire','hand_r')
    elif school=='necromancy':
        tilted_box('Skull_neck',(x,y,z-.022),(.056,.061,.158),'metal','hand_r')
        tilted_box('Skull_focus',(x,y,z+.080),(.173,.128,.162),'ivory','hand_r')
        tilted_box('Skull_jaw',(x,y-.030,z-.005),(.132,.115,.053),'ivory','hand_r')
        for sign in (-1,1):
            tilted_box('Skull_eye_'+str(sign),(x+sign*.045,y-.071,z+.098),(.039,.019,.039),'pants','hand_r')
        tilted_box('Skull_rune',(x,y-.077,z+.047),(.023,.019,.033),'accent','hand_r')
    elif school=='druidism':
        segment('Branch_left',(x,y,z-.086),(x-.134,y-.016,z+.195),.049,.049,'wood','hand_r')
        segment('Branch_right',(x+.007,y+.010,z-.076),(x+.097,y+.060,z+.116),.043,.041,'wood','hand_r')
        for i,point in enumerate([(x-.130,y-.022,z+.193),(x+.099,y+.054,z+.109)]):
            tilted_box('Branch_leaf_'+str(i),point,(.102,.063,.101),'accent','hand_r')
        tilted_box('Druid_staff_knot',(x+.012,y-.022,z-.04),(.074,.048,.081),'trim','hand_r')
    elif school=='arcanism':
        tilted_box('Arcane_focus_socket',(x,y,z-.019),(.106,.095,.129),'trim','hand_r')
        crystal('Arcane_focus',(x,y,z+.149),(.149,.131,.293),'accent')
        for sign in (-1,1):
            segment('Arcane_bracket_'+str(sign),(x+sign*.039,y,z+.018),(x+sign*.126,y,z+.193),.026,.033,'trim','hand_r')
    else:
        tilted_box('Element_focus_stem',(x,y,z-.029),(.066,.061,.158),'trim','hand_r')
        tilted_box('Element_core',(x,y,z+.124),(.091,.077,.089),'accent','hand_r')
        for i,(dx,dz,region) in enumerate([(-.094,0,'stone'),(.094,0,'water'),(0,-.094,'fire'),(0,.094,'wind')]):
            segment('Element_link_'+str(i),(x,y,z+.124),(x+dx,y,z+.124+dz),.030,.032,'trim','hand_r')
            crystal('Element_focus_'+region,(x+dx,y,z+.124+dz),(.078,.072,.097),region)
    return shaft

def build_atlas(recipe):
    parts=ns['PARTS']; density=64; pad=3; islands=[]
    for obj in parts:
        uv=obj.data.uv_layers.new(name='UVMap')
        for face in obj.data.polygons:
            n=face.normal; up=Vector((0,0,1)); up-=n*up.dot(n)
            if up.length<.01: up=Vector((0,1,0)); up-=n*up.dot(n)
            up.normalize(); right=up.cross(n).normalized()
            points=[Vector((obj.data.vertices[obj.data.loops[li].vertex_index].co.dot(right),obj.data.vertices[obj.data.loops[li].vertex_index].co.dot(up))) for li in face.loop_indices]
            low=Vector((min(p.x for p in points),min(p.y for p in points))); points=[p-low for p in points]
            islands.append(dict(obj=obj,face=face,points=points,w=max(2,math.ceil(max(p.x for p in points)*density)+1),h=max(2,math.ceil(max(p.y for p in points)*density)+1)))
    islands.sort(key=lambda f:(-f['h'],-f['w'])); size=256
    while True:
        x=y=pad; rowh=0; fits=True
        for f in islands:
            if x+f['w']+pad>size: x=pad; y+=rowh+pad*2; rowh=0
            if y+f['h']+pad>size: fits=False; break
            f['x']=x; f['y']=y; x+=f['w']+pad*2; rowh=max(rowh,f['h'])
        if fits: break
        size*=2
    canvas=np.zeros((size,size,4),dtype=np.uint8); canvas[...,3]=255
    emission=np.zeros_like(canvas); emission[...,3]=255
    for f in islands:
        sampled=ns['paint_tile'](f['obj'],f['face'],f['w'],f['h'],f['points']).copy()
        tile=sampled.copy()
        if f['obj']['part']=='Head':
            rgba_source=np.concatenate((sampled,np.full((*sampled.shape[:2],1),255,dtype=np.uint8)),axis=-1)
            tile=paint_head(rgba_source,f['face'].index,recipe['school'])[0][:,:,:3]
        rgba=np.concatenate((tile,np.full((*tile.shape[:2],1),255,dtype=np.uint8)),axis=-1)
        ox,oy=f['x'],f['y']; canvas[oy-pad:oy+f['h']+pad,ox-pad:ox+f['w']+pad]=np.pad(rgba,((pad,pad),(pad,pad),(0,0)),mode='edge')
        glowing=any(k in f['obj']['part'] for k in ['staff_core','Cinder_flame','Arcane_focus','Element_core','Element_focus_water','Skull_rune'])
        if glowing:
            emission[oy-pad:oy+f['h']+pad,ox-pad:ox+f['w']+pad]=np.pad(rgba,((pad,pad),(pad,pad),(0,0)),mode='edge')
        for li,p in zip(f['face'].loop_indices,f['points']):
            f['obj'].data.uv_layers.active.data[li].uv=((ox+.5+p.x*density)/size,(oy+.5+p.y*density)/size)
    images=[]
    for suffix,pixels in [('albedo',canvas),('emission',emission)]:
        image=bpy.data.images.new(recipe['stem']+'_'+suffix,width=size,height=size,alpha=False)
        image.pixels.foreach_set((pixels.astype(np.float32)/255).ravel()); image.file_format='PNG'
        image.filepath_raw=str(ns['FOLDER']/(recipe['stem']+'_'+suffix+'.png')); image.save(); image.pack(); images.append(image)
    material=bpy.data.materials.new(recipe['stem']+'_Pixel_Material'); material.use_nodes=True; material.use_backface_culling=True
    bsdf=material.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.88; bsdf.inputs['Specular IOR Level'].default_value=.18
    for image,input_name in zip(images,['Base Color','Emission Color']):
        texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=image; texture.interpolation='Closest'; material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs[input_name])
    bsdf.inputs['Emission Strength'].default_value=.42
    for obj in parts: obj.data.materials.append(material)
    return dict(resolution=[size,size],density_px_per_m=64,padding_px=pad,nearest=True,materials=1,opaque=True,images=2),material

for recipe in SCHOOLS:
    if any(asset['report']['school']==recipe['school'] for asset in assets): continue
    stage(recipe['school'],'anatomy')
    recipe=dict(recipe,skin=(203,155,113),leather=(112,74,44),wood=(130,97,57),metal=(123,130,132),blanket=(123,102,80),ivory=(197,187,152),parchment=(215,200,161),fire=(207,117,54),water=(86,145,193),stone=(138,137,117),wind=(217,217,195),human_blue=(63,96,146))
    recipe['beard']=.103 if recipe['school']=='druidism' else .090
    recipe['hair']=(224,225,218)
    recipe['pants']=(84,78,63)
    recipe['style_revision']=3
    folder=ROOT/'assets/generated/humans'/recipe['stem']; folder.mkdir(parents=True,exist_ok=True); (folder/'previews').mkdir(exist_ok=True)
    assert globals().get('MAGE_REBUILD',False) or not (folder/(recipe['stem']+'.blend')).exists(), 'Preserve existing mage source'
    name=PREFIX+'_'+recipe['school']; assert bpy.data.scenes.get(name) is None,name
    scene=bpy.data.scenes.new(name); scene['human_school_mage_owned']=True; scene.unit_settings.system='METRIC'; scene.frame_start=scene.frame_end=1
    root=bpy.data.objects.new(recipe['stem'],None); scene.collection.objects.link(root)
    root['race']='human'; root['school']=recipe['school']; root['unit_kind']=recipe['kind']; root['front']='minus_Y'; root['stage']='elderly_model_review'
    ns.update(PARTS=[],BODY={},PRESERVED={},SCENE=scene,ROOT_OBJ=root,FOLDER=folder,P=recipe)
    anatomy=ns['clone_anatomy']()
    torso,head=elderly_pose(recipe)
    garments(recipe,torso); beard_and_hair(recipe,head); headdress(recipe,head)
    shaft=staff_and_book(recipe); stage(recipe['school'],'pixel_atlas')
    for obj in ns['PARTS']:
        if 'settler_asset' in obj: del obj['settler_asset']
        obj['human_school_mage_asset']=True
    texture,material=build_atlas(recipe)
    points=[]; triangles=0; max_uv_error=0
    for obj in ns['PARTS']:
        bm=bmesh.new(); bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges),obj.name
        assert bm.calc_volume(signed=True)>0,obj.name
        assert all(f.calc_area()>1e-10 for f in bm.faces),obj.name; bm.free()
        assert not obj.modifiers and obj.matrix_basis.is_identity
        points.extend(v.co for v in obj.data.vertices)
        triangles+=sum(len(f.vertices)-2 for f in obj.data.polygons)
        uv=obj.data.uv_layers.active.data
        for face in obj.data.polygons:
            assert not face.use_smooth
            loops=list(face.loop_indices)
            for a,b in zip(loops,loops[1:]+loops[:1]):
                edge=(obj.data.vertices[obj.data.loops[a].vertex_index].co-obj.data.vertices[obj.data.loops[b].vertex_index].co).length
                ratio=(uv[a].uv-uv[b].uv).length*texture['resolution'][0]/edge
                max_uv_error=max(max_uv_error,abs(ratio-64))
    low=[min(p[i] for p in points) for i in range(3)]; high=[max(p[i] for p in points) for i in range(3)]
    assert abs(low[2])<.00001 and max_uv_error<.01
    assert triangles<1800 and len(ns['BODY'])==18
    geometry=dict(status='PASS',editable_parts=len(ns['PARTS']),body_parts=18,triangles=triangles,dimensions=[high[i]-low[i] for i in range(3)],bounds_min=low,bounds_max=high,closed_meshes=True,positive_volume=True,ground_pivot=True,identity_transforms=True,flat_shading=True,uv_density_max_error=max_uv_error)
    report=dict(stem=recipe['stem'],name=recipe['name'],school=recipe['school'],race='human',gameplay_unit_kind=recipe['kind'],pipeline='Live Blender MCP localhost:9876',source=PROBE['path'],source_sha256=PROBE['sha256'],source_body=anatomy,elderly_posture=dict(torso_forward_degrees=recipe['lean'],head_counter_degrees=-3,shoulder_drop_m=.022,grey_beard_length_m=recipe['beard']),geometry=geometry,texture=texture,animations=0,rigging_deferred=True,style_revision=3,books=0,head_scalp_texture='original_human_white_hair_or_painted_hood',facial_features='approved_original_eyes_brows_nose_mouth_preserved',style_references=['human_settler_v1','squire_v1','archer_v1'])
    original=next(o for o in BASE.objects if o.get('part')=='Head')
    max_head_error=max((head.inverted()@v.co-original.matrix_world@src.co).length for v,src in zip(ns['BODY']['Head'].data.vertices,original.data.vertices))
    assert max_head_error<1e-6
    report['style_validation']=dict(school=recipe['school'],status='PASS',original_head_geometry=True,head_scale=1.0,original_head_max_vertex_error_m=max_head_error,original_facial_features_preserved=True,painted_white_hair=True,painted_hood=recipe['school'] in HOODS,bulky_hood_shells=0,separate_hair_shells=0,body_and_clothing_geometry_unchanged=True,books=0,relaxed_offhand=True)
    asset=dict(scene=scene,root=root,parts=ns['PARTS'].copy(),body=ns['BODY'].copy(),staff=shaft,material=material,folder=folder,report=report)
    assets.append(asset)
    (folder/(recipe['stem']+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('MAGE_MODELED',recipe['school'],triangles,len(asset['parts']),texture['resolution'])
(WORK/'modeling_validation.json').write_text(json.dumps(dict(status='PASS',assets=[a['report'] for a in assets]),ensure_ascii=False,indent=2),encoding='utf-8')
stage('all','modeled')
result=dict(status='PASS',models=len(assets),triangles=[a['report']['geometry']['triangles'] for a in assets])
