"""Reusable elf stone construction site; execute in the running Blender via MCP."""
import bpy, bmesh, math, json, struct, sys, hashlib, ast
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
sys.path.insert(0, str(ROOT/'tools/art_pipeline'))
from dwarf_animation_motion import solve_chain
STEM = 'elf_construction_site_hex_v1'
OUT = ROOT/'assets/generated/elves/buildings'/STEM
WORK = ROOT/'art_source/elf_construction_review'
REBUILD = globals().get('CONSTRUCTION_REBUILD', False)
assert REBUILD or not (OUT/(STEM+'.glb')).exists(), 'Preserve an existing asset before rebuilding.'
OUT.mkdir(parents=True, exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
WORK.mkdir(parents=True, exist_ok=True); (WORK/'.gdignore').touch()
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
if REBUILD:
    owned=bpy.app.driver_namespace.pop('elf_construction_v1',None) or bpy.app.driver_namespace.pop('elf_construction_build_in_progress')
    assert owned['scene'].name=='Elf_Construction_Site_V1' and owned['out']==OUT
    bpy.data.batch_remove(ids={owned['scene'],*owned['scene'].objects})
prior = [s.name for s in bpy.data.scenes]
if not (WORK/'session_before.json').exists():
    (WORK/'session_before.json').write_text(json.dumps(prior), encoding='utf-8')
scene = bpy.data.scenes.new('Elf_Construction_Site_V1')
bpy.context.window.scene = scene
bpy.app.driver_namespace['elf_construction_build_in_progress']=dict(scene=scene,out=OUT)
root = bpy.data.objects.new(STEM, None); scene.collection.objects.link(root)
root['race'] = 'elf'; root['generic_construction'] = True
parts = []; bones = {'root':Vector((0,0,0))}; workers = []
# Use the approved elf model directly, including its painted facial features.
SOURCE_PATH=ROOT/'assets/generated/elves/elf_settler_v1/elf_settler_v1.blend'
source=bpy.app.driver_namespace.get('elf_construction_reference')
if source is None:
    with bpy.data.libraries.load(str(SOURCE_PATH),link=False) as (src,dst): dst.scenes=[src.scenes[0]]
    source=dst.scenes[0]; bpy.app.driver_namespace['elf_construction_reference']=source
elf_body={o['part']:o for o in source.objects if o.type=='MESH' and o.get('part')}
elf_head=elf_body['Head']; ELF_SCALE=.24
elf_transform=Matrix.Rotation(math.pi,4,'Z')@Matrix.Scale(ELF_SCALE,4)
source_image=next(n.image for n in elf_head.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
source_pixels=np.empty(len(source_image.pixels),dtype=np.float32); source_image.pixels.foreach_get(source_pixels)
source_pixels=source_pixels.reshape(source_image.size[1],source_image.size[0],4)
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
paint_source=ROOT/'tools/art_pipeline/elf_city_level_1_hex_v1_model.py'
elf_palette=next(ast.literal_eval(node.value) for node in ast.parse(paint_source.read_text(encoding='utf-8')).body
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Subscript) and isinstance(t.slice,ast.Constant) and t.slice.value=='palette_overrides' for t in node.targets))
PALETTE = dict(roof=elf_palette['roof'], stone=elf_palette['stone'], cutstone=elf_palette['cutstone'],
    resin=(183,153,69), wood=elf_palette['timber'], wood_light=elf_palette['door'], wood_dark=(81,66,43),
    cloth=(69,111,79), linen=(194,193,153), pants=(93,107,80), skin=(237,221,209),
    roof_dark=elf_palette['roof_dark'], hair=(216,190,124), leather=(119,92,56), iron=(154,171,150), gold=elf_palette['gold'])
REGIONS = list(PALETTE)
pixels = np.ones((512,512,4), dtype=np.float32)
for i,(region,color) in enumerate(PALETTE.items()):
    rng=np.random.default_rng(924+i); y,x=np.mgrid[:128,:128]
    tile=np.full((128,128,3), color, dtype=float)
    tile += rng.integers(-5,6,(64,64)).repeat(2,0).repeat(2,1)[:,:,None]
    if region.startswith('wood'):
        tile[((y//2*7+x//19*3)%23)<3] -= 13
        tile[(y%22==0)&(x%31<24)] -= 19
    elif region in ('stone','cutstone'):
        tile[((y//3*7+x//3*13)%73)<9] -= 16
        tile[((y//6*11+x//5*17)%43)<4] += 10
        tile[(y%31==0)&(x%29<18)] -= 9
    elif region.startswith('roof'):
        tile[(y%18==0)|(x%25==0)] -= 12
        tile[(x%25==1)&(y%18<16)] += 6
    elif region in ('cloth','linen'): tile += (((x//3+y//3)%2)*2-1)[:,:,None]*9
    elif region=='leather': tile[(x%4==0)&(y%4==0)] -= 8
    pixels[(i//4)*128:(i//4+1)*128,(i%4)*128:(i%4+1)*128,:3] = np.clip(tile/255,0,1)
# Pack the six original head faces into an unused palette tile. No face meshes
# or independently invented eyes, brows, mouth or protruding nose are added.
head_uvs={}; head_tile=REGIONS.index('hair'); hx=(head_tile%4)*128; hy=(head_tile//4)*128
cursor_x=cursor_y=4; row_height=0
for face in elf_head.data.polygons:
    uv=np.array([list(elf_head.data.uv_layers.active.data[i].uv) for i in face.loop_indices])*np.array(source_image.size)
    origin=np.floor(uv.min(axis=0)).astype(int); edge=np.ceil(uv.max(axis=0)).astype(int)
    w,h=edge-origin+1
    if cursor_x+w+4>128: cursor_x=4; cursor_y+=row_height+8; row_height=0
    assert cursor_y+h+4<128
    tile=source_pixels[origin[1]:origin[1]+h,origin[0]:origin[0]+w]
    pixels[hy+cursor_y-2:hy+cursor_y+h+2,hx+cursor_x-2:hx+cursor_x+w+2]=np.pad(tile,((2,2),(2,2),(0,0)),mode='edge')
    head_uvs[face.index]=[(np.array((hx+cursor_x,hy+cursor_y))+point-origin)/512 for point in uv]
    cursor_x+=w+8; row_height=max(row_height,h)
im = bpy.data.images.new(STEM+'_albedo',512,512,alpha=False)
im.pixels.foreach_set(pixels.ravel()); im.filepath_raw=str(OUT/(STEM+'_albedo.png'))
im.file_format='PNG'; im.save(); im.pack()
mat=bpy.data.materials.new(STEM+'_Pixel_Material'); mat.use_nodes=True; mat.use_backface_culling=True
bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.9
bsdf.inputs['Specular IOR Level'].default_value=.18
tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

def mesh(name, vertices, faces, region, bone=None):
    data=bpy.data.meshes.new(STEM+'_'+name); data.from_pydata(vertices,[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    assert bm.calc_volume(signed=True)>1e-11, name
    bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.parent=root
    obj['surface']=region; obj['part']=name; obj['bone']=bone or ''
    data.materials.append(mat); uv=data.uv_layers.new(name='Pixel_UV')
    tile=REGIONS.index(region); tx=(tile%4)*128; ty=(tile//4)*128
    for poly in data.polygons:
        drop=max(range(3),key=lambda a:abs(poly.normal[a])); axes=[a for a in range(3) if a!=drop]
        values=[Vector((data.vertices[i].co[axes[0]],data.vertices[i].co[axes[1]])) for i in poly.vertices]
        lo=Vector((min(v.x for v in values),min(v.y for v in values)))
        span=max(max(v.x for v in values)-lo.x,max(v.y for v in values)-lo.y,.01)
        density=min(110,112/span)
        for li,v in zip(poly.loop_indices,values): uv.data[li].uv=((tx+8+(v.x-lo.x)*density)/512,(ty+8+(v.y-lo.y)*density)/512)
        poly.use_smooth=False
    parts.append(obj); return obj

def box(name,c,size,region,bone=None,frame=None):
    c=Vector(c); frame=frame if frame is not None else Matrix.Identity(3)
    return mesh(name,[c+frame@Vector((x*size[0]/2,y*size[1]/2,z*size[2]/2))
        for z in (-1,1) for y in (-1,1) for x in (-1,1)],CUBE,region,bone)

def beam(name,a,b,width,region,bone=None,depth=None):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); side=axis.cross(Vector((0,0,1)))
    if side.length<.001: side=Vector((1,0,0))
    side.normalize(); forward=axis.cross(side).normalized()
    return box(name,(a+b)/2,(width,depth or width,(b-a).length),region,bone,Matrix((side,forward,axis)).transposed())

def prism(name,outline,z0,z1,region,bone=None):
    n=len(outline)
    return mesh(name,[(x,y,z) for z in (z0,z1) for x,y in outline],
        [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],region,bone)

def hewn_stone(name,c,size,region='stone'):
    return box(name,c,size,region)

def square_beam(name,a,b,width,region='wood',sides=None):
    return beam(name,a,b,width,region)

# Generic timber preparation, without a building layout or ground plate.
GROUND_OFFSET=.032; WORK_TOP=.379

# Timber scaffolding is visibly assembled, braced, lashed and supported on dirt.
for x in (-.48,.48):
    for y in (.29,.51):
        box('Scaffold_foot', (x,y,.043),(.092,.083,.022),'wood_dark')
        square_beam('Scaffold_log_post',(x,y,.05),(x+(.005 if x<0 else -.005),y,.72),.035,'wood',7)
        # Square timber joinery and bronze pegs, rather than heavy rope bundles.
        for z in (.24,.57):
            box('Scaffold_joinery',(x,y,z),(.051,.049,.018),'wood_light')
            box('Scaffold_bronze_peg',(x,y-.028,z),(.009,.008,.008),'gold')
    square_beam('Diagonal_log_brace',(x,.29,.075),(x,.51,.50),.025,'wood')
for y in (.29,.51):
    box('Platform_bearer',(0,y,.196),(.99,.035,.035),'wood_dark')
    if y>.4: square_beam('Back_scaffold_log',( -.48,y,.56),(.48,y,.56),.032,'wood_dark')
square_beam('Back_cross_brace',(-.48,.526,.12),(.48,.526,.56),.026,'wood')
# Forked timber braces echo the squared branch supports of elven buildings.
for sign in (-1,1):
    square_beam('Forked_scaffold_branch',(sign*.48,.51,.48),(sign*.37,.51,.64),.022,'wood_light')
    square_beam('Forked_scaffold_tip',(sign*.37,.51,.64),(sign*.30,.51,.68),.020,'wood_light')
for j in range(6): box('Scaffold_walkboard_%d'%j,((j%3-1)*.009,.286+j*.04,.226),(.93+(j%3)*.009,.037,.026),'wood_light' if j%2 else 'wood')
for z in (.07,.14,.21): box('Ladder_rung',(.49,.22,z),(.124,.024,.017),'wood_light')
for x in (.428,.552): beam('Ladder_side',(x,.185,.032),(x,.295,.275),.022,'wood')

def workbench(prefix,x,y,width,top):
    for xx in (-width*.38,width*.38):
        for yy in (-.063,.063): square_beam(prefix+'_splayed_trestle',(x+xx,y+yy,.035),(x+xx,y,top-.012),.024,'wood_dark')
        square_beam(prefix+'_trestle_tie',(x+xx,y-.055,.085),(x+xx,y+.055,.085),.019,'wood')
    for j in range(3): box(prefix+'_plank',(x,y+(j-1)*.045,top), (width,.042,.023),'wood')
    beam(prefix+'_brace',(x-width*.38,y+.059,.07),(x+width*.38,y+.059,top-.025),.018,'wood_light')
workbench('Joinery_bench',0,.115,.78,WORK_TOP-.068-.0115+GROUND_OFFSET)
box('Beam_being_planed',(0,.115,WORK_TOP-.034+GROUND_OFFSET),(.78,.170,.068),'wood_light')
for sign in (-1,1):
    box('Planing_bench_stop',(sign*.366,.115,WORK_TOP-.058+GROUND_OFFSET),(.024,.185,.038),'wood_dark')
workbench('Mortise_bench',-.40,-.235,.25,.194)
box('Timber_being_mortised',(-.40,-.235,.240),(.155,.106,.069),'wood_light')
workbench('Saw_trestle',.40,-.26,.245,.183)
box('Board_being_sawn',(.40,-.225,.217),(.335,.091,.044),'wood_light')
# Loose building blocks on a small timber pallet, rather than a built wall.
for x in (-.65,-.43):
    box('Block_stock_pallet_runner',(x,.095,.043),(.023,.173,.022),'wood_dark')
for y in (.028,.063,.098,.133):
    box('Block_stock_pallet_plank',(-.54,y,.060),(.280,.030,.012),'wood')
for layer in range(2):
    for col in range(3):
        box('Elven_block_stock_%d_%d'%(layer,col),(-.63+col*.09,.095,.099+layer*.067),(.083,.125,.064),'cutstone' if (col+layer)%2 else 'stone')

# Unprocessed square-section logs with irregular bark and visible cut ends.
# Every bark strip remains a cuboid: no cylinders, bevels or smooth surfaces.
for log,(y,z) in enumerate(((-.533,.067),(-.467,.067),(-.500,.134))):
    box('Raw_timber_core_%d'%log,(.27,y,z),(.360,.056,.060),'wood')
    for end in (-1,1):
        box('Raw_timber_cut_end_%d_%d'%(log,end),(.27+end*.183,y,z),(.006,.054,.058),'wood_light')
    for band in range(4):
        bx=.270
        for side in (-1,1):
            box('Raw_timber_bark_%d_%d_%d'%(log,band,side),(bx,y+side*.030,z-.023+band*.015),(.354,.007,.014),'wood_dark')
        box('Raw_timber_top_bark_%d_%d'%(log,band),(bx,y+(band-1.5)*.011,z+.0315),(.350,.0105,.007),'wood_dark')
# Emerald roofing stock uses the exact palette of the elven buildings.
for x in (-.275,-.085): box('Roof_stock_pallet_runner',(x,-.48,.043),(.025,.16,.022),'wood_dark')
for j in range(4): box('Roof_stock_pallet_plank',(-.18,-.535+j*.035,.061),(.25,.030,.014),'wood')
for column in range(2):
    for layer in range(5):
        box('Emerald_roof_slate_%d_%d'%(column,layer),(-.24+column*.12+(layer%2)*.005,-.48,.076+layer*.014),(.106,.114,.012),'roof_dark' if layer==0 else 'roof')
for x in (-.24,-.12): box('Slate_bundle_binding',(x,-.48,.141),(.014,.118,.009),'linen')
box('Roof_nails_box',(-.065,-.35,.054),(.084,.071,.040),'wood_dark')
# Uninstalled leaf ornaments and gold edging stock, not a completed facade.
for item in range(3):
    for band,width in enumerate((.007,.016,.021,.016,.007)):
        box('Loose_gold_leaf_%d_%d'%(item,band),(-.091+item*.026,-.367+band*.008,.079),(width,.008,.005),'gold')
for j in range(3):
    box('Loose_gold_roof_edging',(.27,-.50,.172+j*.007),(.29,.012,.006),'gold')
box('Joinery_tool_tray',(-.20,.39,.259),(.17,.125,.039),'wood_dark')
for peg in range(6):
    box('Wooden_joinery_peg',(-.25+(peg%3)*.05,.365+(peg//3)*.035,.281),(.036,.012,.014),'wood_light')
bucket_start=len(parts)
box('Resin_bucket_bottom',(-.15,-.56,.041),(.080,.080,.014),'wood_dark')
for side in (-1,1):
    box('Bucket_side_x_'+str(side),(-.15+side*.037,-.56,.077),(.008,.080,.062),'wood')
    box('Bucket_side_y_'+str(side),(-.15,-.56+side*.037,.077),(.064,.008,.062),'wood_light')
    for z in (.059,.094):
        box('Bucket_band_x',(-.15+side*.042,-.56,z),(.005,.085,.006),'iron')
        box('Bucket_band_y',(-.15,-.56+side*.042,z),(.080,.005,.006),'iron')
box('Bucket_resin',(-.15,-.56,.0705),(.063,.063,.043),'resin')
for x in (-.190,-.110): square_beam('Bucket_rope_handle',(x,-.56,.101),(x,-.56,.139),.007,'linen',5)
square_beam('Bucket_rope_top',(-.190,-.56,.139),(-.110,-.56,.139),.007,'linen',5)
for obj in parts[bucket_start:]:
    for vertex in obj.data.vertices: vertex.co+=Vector((.08,-.06,0))
# Medieval timber windlass, built entirely from square-section pieces.
windlass_start=len(parts)
square_beam('Windlass_mast',(-.50,.56,.032),(-.50,.56,.835),.048,'wood_dark',8)
square_beam('Windlass_jib',(-.50,.59,.81),(-.50,.04,.81),.043,'wood')
square_beam('Windlass_jib_brace',(-.50,.56,.53),(-.50,.15,.79),.027,'wood_light')
square_beam('Windlass_axle',(-.50,.43,.56),(-.50,.67,.56),.033,'wood_light',8)
for side in (-1,1):
    box('Windlass_wheel_side',(-.50+side*.102,.59,.56),(.025,.025,.229),'wood')
    box('Windlass_wheel_cross',(-.50,.59,.56+side*.102),(.180,.025,.025),'wood')
box('Windlass_wheel_spoke_horizontal',(-.50,.59,.56),(.195,.020,.015),'wood_light')
box('Windlass_wheel_spoke_vertical',(-.50,.59,.56),(.015,.020,.195),'wood_light')
square_beam('Windlass_hand_crank',(-.50,.43,.56),(-.44,.43,.58),.019,'wood')
square_beam('Windlass_crank_grip',(-.44,.43,.58),(-.44,.39,.58),.017,'wood_light')
square_beam('Hoist_hemp_rope',(-.50,.07,.81),(-.50,.07,.352),.007,'linen',6)
box('Suspended_timber',(-.50,.07,.313),(.152,.054,.068),'wood_light')
for x in (-.534,-.466):
    square_beam('Timber_rope_sling',(x,.026,.28),(x,.026,.353),.006,'linen',5)
    square_beam('Timber_sling_top',(x,.026,.353),(-.50,.07,.368),.006,'linen',5)
for obj in parts[windlass_start:]:
    for vertex in obj.data.vertices: vertex.co+=Vector((.075,-.12,0))
for i in range(8):
    rng=np.random.default_rng(57+i)
    box('Wood_shaving_%d'%i,(-.50+rng.uniform(-.08,.16),-.31+rng.uniform(-.03,.08),.037),(.026,.010,.009),'wood_light')
# Lower all props to the terrain plane. Ground supports are kept flush.
for obj in parts:
    for vertex in obj.data.vertices: vertex.co.z-=GROUND_OFFSET
    low=min(v.co.z for v in obj.data.vertices)
    if low<0:
        for vertex in obj.data.vertices: vertex.co.z-=low

def worker(name,position,angle,job,shirt,skin):
    B=Matrix.Translation(Vector(position))@Matrix.Rotation(angle,4,'Z')
    R=B.to_3x3(); P=lambda p:B@Vector(p); prefix=name+'_'
    def wb(part,c,size,region,bone): return box(prefix+part,P(c),size,region,prefix+bone,R)
    def wbeam(part,a,b,width,region,bone,depth=None): return beam(prefix+part,P(a),P(b),width,region,prefix+bone,depth)
    local=dict(body=Vector((0,0,.22)),head=Vector((0,0,.33)))
    slopes={'L':.45,'R':-.45} if job=='hammer' else {'L':.30,'R':.30}
    for side,sgn in [('L',-1),('R',1)]:
        slope=slopes[side]
        local['upper_'+side]=Vector((sgn*.065,0,.334))
        local['fore_'+side]=Vector((sgn*(.065-slope*.022),.022,.228))
        local['hand_'+side]=Vector((sgn*(.065-slope*.059),.059,.158))
    bones.update({prefix+k:P(v) for k,v in local.items()})
    def approved(part,reference,region,bone='body'):
        original=elf_body[reference]
        obj=mesh(prefix+part,[P(elf_transform@(original.matrix_world@v.co)) for v in original.data.vertices],
            [tuple(f.vertices) for f in original.data.polygons],region,prefix+bone)
        obj['elf_anatomy_source']=reference; obj['uniform_anatomy_scale']=ELF_SCALE
        return obj
    for side,source_side in [('L','l'),('R','r')]:
        approved('Boot_'+side,'Foot_'+source_side,'leather')
        approved('Shin_'+side,'Shin_'+source_side,'leather')
        approved('Thigh_'+side,'Thigh_'+source_side,'pants')
    approved('Hips','Pelvis',shirt)
    approved('Belly','Belly',shirt)
    approved('Shirt','Chest',shirt)
    wb('Belt',(0,0,.240),(.098,.056,.014),'leather','body')
    wb('Buckle',(0,.033,.240),(.018,.008,.014),'gold','body')
    wb('Leather_work_apron',(0,.035,.277),(.069,.007,.090),'leather','body')
    for sx in (-1,1): wbeam('Apron_tie_'+str(sx),(sx*.031,.033,.342),(sx*.021,.039,.320),.006,'leather','body')
    wb('Belt_pouch',(-.056,.003,.231),(.023,.030,.028),'wood_dark','body')
    wb('Pouch_flap',(-.056,.021,.238),(.024,.008,.014),'leather','body')
    head=approved('Head','Head','hair','head')
    for face in head.data.polygons:
        original=elf_head.data.polygons[face.index]
        uv_by_vertex=dict(zip(original.vertices,head_uvs[face.index]))
        for li,vi in zip(face.loop_indices,face.vertices): head.data.uv_layers.active.data[li].uv=uv_by_vertex[vi]
    # Exposed blonde painted hair and the six original squared ear pieces.
    for ear in sorted(k for k in elf_body if k.startswith('ElfEar')):
        approved(ear,ear,'skin','head')
    wb('Linen_neckline',(0,.031,.337),(.059,.006,.008),'linen','body')
    wb('Gold_neck_clasp',(0,.036,.332),(.010,.006,.012),'gold','body')
    for side in ('L','R'):
        a,b,c=(local[k+'_'+side] for k in ('upper','fore','hand'))
        # The sleeve itself forms the shoulder; its cap rotates with the arm.
        sleeve_start=a-(b-a).normalized()*.012
        wbeam('Sleeve_'+side,sleeve_start,a+(b-a)*.55,.041,shirt,'upper_'+side,depth=.043)
        wbeam('Upper_arm_'+side,a+(b-a)*.55,b,.027,skin,'upper_'+side,depth=.029)
        wbeam('Forearm_'+side,b,c,.027,skin,'fore_'+side,depth=.029)
        wb('Hand_'+side,c,(.032,.032,.031),skin,'hand_'+side)
    # Tools are rigidly weighted to their hand; their contact paths are authored below.
    h=local['hand_R']
    if job=='hammer':
        wbeam('Hammer_handle',h+Vector((.016,0,.009)),h+Vector((-.130,0,.009)),.012,'wood_light','hand_R')
        wb('Hammer_head',h+Vector((-.130,0,.009)),(.030,.036,.070),'wood_light','hand_R')
        for sz in (-1,1): wb('Mallet_band_'+str(sz),h+Vector((-.130,0,.009+sz*.026)),(.031,.037,.005),'iron','hand_R')
        l=local['hand_L']; wbeam('Chisel',l+Vector((0,0,-.032)),l+Vector((0,0,.020)),.010,'iron','hand_L')
    elif job=='saw':
        wb('Saw_handle',h,(.034,.016,.041),'wood_dark','hand_R')
        wb('Saw_blade',h+Vector((0,.087,-.012)),(.007,.160,.033),'iron','hand_R')
        for yy in (.010,.166): wbeam('Frame_saw_upright_'+str(yy),h+Vector((0,yy,-.007)),h+Vector((0,yy,.073)),.012,'wood','hand_R')
        wbeam('Frame_saw_crossbar',h+Vector((0,.010,.061)),h+Vector((0,.166,.061)),.011,'wood_light','hand_R')
        wbeam('Frame_saw_tension',h+Vector((0,.010,.083)),h+Vector((0,.166,.083)),.004,'linen','hand_R')
        for j in range(8):
            yy=h.y+.018+j*.020; zz=h.z-.029
            wb('Saw_tooth_%d'%j,(h.x,yy,zz-.0045),(.007,.010,.009),'iron','hand_R')
    else:
        wb('Handplane_sole',(h.x,h.y+.058,h.z-.0095),(.040,.064,.005),'iron','hand_R')
        wb('Handplane_body',(h.x,h.y+.052,h.z+.008),(.037,.060,.030),'wood_dark','hand_R')
        wb('Handplane_blade',(h.x,h.y+.058,h.z+.022),(.033,.008,.040),'iron','hand_R')
        wbeam('Handplane_rear_grip',h+Vector((0,0,-.006)),h+Vector((0,.018,.031)),.012,'wood_light','hand_R')
        wb('Handplane_front_knob',(h.x,h.y+.075,h.z+.036),(.014,.014,.022),'wood_light','hand_R')
    item=dict(name=name,job=job,B=B,local=local,P=P,prefix=prefix,slopes=slopes)
    workers.append(item)

worker('Joiner',(-.40,-.335,0),0,'hammer','cloth','skin')
worker('Carpenter',(.40,-.38,0),0,'saw','cloth','skin')
worker('Woodworker',(.20,.278,.239-GROUND_OFFSET),math.pi,'plane','cloth','skin')

def T(p): return Matrix.Translation(Vector(p))
def around(p,q): return T(p)@q.to_matrix().to_4x4()@T(-Vector(p))

def pose(fraction):
    out={name:Matrix.Identity(4) for name in bones}
    for w in workers:
        job=w['job']; pre=w['prefix']; P=w['P']; L=w['local']; B=w['B']
        def wrist(side,y,z):
            sign=-1 if side=='L' else 1
            return Vector((sign*(.065-w['slopes'][side]*y),y,z))
        if job=='hammer':
            phase=(fraction*3)%1
            def ease(t): return t*t*(3-2*t)
            if phase<.12: rise=0.
            elif phase<.65: rise=ease((phase-.12)/.53)
            elif phase<.78: rise=1.
            else: rise=1-ease((phase-.78)/.22)
            # The grip stays outside the stone. The mallet swings around it;
            # only the head descends onto the stationary chisel.
            r=wrist('R',.100,.312+.022*rise); l=wrist('L',.100,.266)
        elif job=='saw':
            travel=.023*math.sin(math.tau*fraction*4)
            r=wrist('R',.055+travel,.202); l=wrist('L',.110,.222)
        else:
            r=wrist('R',.076+.016*math.sin(math.tau*fraction*2),WORK_TOP-w['B'].translation.z+.012)
            l=wrist('L',.038,.185)
        for side,target in [('L',l),('R',r)]:
            a,b,c=[P(L[k+'_'+side]) for k in ('upper','fore','hand')]
            dest=P(target)
            # One fixed elbow plane per arm. Both segments keep the same roll;
            # hands stay in front of the worker without crossing or elbow flips.
            upper,fore,actual=solve_chain(a,b,c,a,dest,Vector((0,0,-1)),stable_roll=True)
            assert (actual-dest).length<1e-6,(job,side,fraction,'unreachable hand')
            out[pre+'upper_'+side]=upper; out[pre+'fore_'+side]=fore; out[pre+'hand_'+side]=T(dest-c)
        if job=='hammer':
            palm=P(r); q=Quaternion(B.to_3x3()@Vector((0,1,0)),math.radians(55*rise))
            out[pre+'hand_R']=around(palm,q)@out[pre+'hand_R']
        head=bones[pre+'head']; axis=B.to_3x3()@Vector((1,0,0))
        out[pre+'head']=around(head,Quaternion(axis,math.radians(6+.6*math.sin(math.tau*fraction*(3 if job=='hammer' else 2)))))
    return out

data=bpy.data.armatures.new(STEM+'_Skeleton'); rig=bpy.data.objects.new('Construction_Workers_Rig',data)
scene.collection.objects.link(rig); rig.parent=root; rig.show_in_front=True; data.display_type='STICK'
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name,point in bones.items():
    bone=data.edit_bones.new(name); bone.head=point; bone.tail=point+Vector((0,.03,0))
    if name!='root': bone.parent=data.edit_bones['root']
bpy.ops.object.mode_set(mode='OBJECT')
for obj in parts:
    if obj['bone']:
        obj.vertex_groups.new(name=obj['bone']).add(list(range(len(obj.data.vertices))),1.,'REPLACE')
        obj.parent=rig; obj.modifiers.new('Rigid_worker_skin','ARMATURE').object=rig
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
rest={b.name:b.matrix_local.copy() for b in data.bones}
action=bpy.data.actions.new(STEM+'_construction'); rig.animation_data_create(); rig.animation_data.action=action
previous={}; FPS=30; COUNT=181
for frame in range(1,COUNT+1):
    desired=pose(0 if frame==COUNT else (frame-1)/(COUNT-1))
    for name,delta in desired.items():
        pb=rig.pose.bones[name]; pb.matrix_basis=rest[name].inverted()@delta@rest[name]
        if name in previous and previous[name].dot(pb.rotation_quaternion)<0: pb.rotation_quaternion.negate()
        previous[name]=pb.rotation_quaternion.copy()
        pb.keyframe_insert('location',frame=frame,group=name); pb.keyframe_insert('rotation_quaternion',frame=frame,group=name)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points: key.interpolation='LINEAR'
rig.animation_data.action=None
for pb in rig.pose.bones: pb.matrix_basis.identity()
track=rig.animation_data.nla_tracks.new(); track.name='construction'
strip=track.strips.new('construction',1,action); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
scene.render.fps=FPS; scene.frame_start=1; scene.frame_end=COUNT
scene.use_preview_range=True; scene.frame_preview_start=1; scene.frame_preview_end=COUNT-1
scene.frame_set(1); scene.view_layers[0].update()

# Validate every baked pose: fixed feet, closed loop, rigid bones and tile containment.
max_hex=0.; max_content_hex=0.; min_z=1e9; joint_error=0.; first=None; loop_error=0.; limiting_part=''
min_elbow=180.; max_elbow=0.; plane_error=0.; max_rotation_step=0.; last_rotations={}; min_hand_gap=1e9
inverse={b.name:b.matrix_local.inverted() for b in data.bones}
for frame in range(1,COUNT+1):
    scene.frame_set(frame); scene.view_layers[0].update()
    delta={b.name:b.matrix@inverse[b.name] for b in rig.pose.bones}
    values=np.array([list(row) for m in delta.values() for row in m])
    if first is None: first=values.copy()
    if frame==COUNT: loop_error=float(np.max(abs(values-first)))
    for w in workers:
        pre=w['prefix']; P=w['P']; L=w['local']
        assert np.max(abs(np.array(delta[pre+'body'])-np.eye(4)))<1e-6
        hand_positions=[]
        for side in ('L','R'):
            a,b,c=[P(L[k+'_'+side]) for k in ('upper','fore','hand')]
            joint_error=max(joint_error,(delta[pre+'upper_'+side]@b-delta[pre+'fore_'+side]@b).length,(delta[pre+'fore_'+side]@c-delta[pre+'hand_'+side]@c).length)
            elbow=delta[pre+'upper_'+side]@b; wrist=delta[pre+'hand_'+side]@c
            bend=math.degrees((elbow-a).angle(wrist-elbow))
            min_elbow=min(min_elbow,bend); max_elbow=max(max_elbow,bend)
            normal=(c-a).cross(b-a).normalized()
            for segment in ('upper_','fore_'):
                name=pre+segment+side; q=delta[name].to_quaternion()
                plane_error=max(plane_error,(delta[name].to_3x3()@normal-normal).length)
                if name in last_rotations:
                    max_rotation_step=max(max_rotation_step,math.degrees(q.rotation_difference(last_rotations[name]).angle))
                last_rotations[name]=q.copy()
            hand_positions.append(wrist)
        min_hand_gap=min(min_hand_gap,(hand_positions[0]-hand_positions[1]).length)
    for obj in parts:
        d=delta[obj['bone']] if obj['bone'] else Matrix.Identity(4)
        for v in obj.data.vertices:
            p=d@v.co; min_z=min(min_z,p.z)
            half_plane=max(p.x*math.cos(i*math.pi/3)+p.y*math.sin(i*math.pi/3) for i in range(6))
            max_hex=max(max_hex,half_plane)
            if half_plane>max_content_hex:
                max_content_hex=half_plane; limiting_part=obj['part']
assert loop_error<1e-6 and joint_error<1e-5 and min_z>-.00001
assert max_hex<.9*math.sqrt(3)/2-.035,(max_hex,limiting_part,'Outside reserved footprint')
assert min_elbow>20 and max_elbow<135 and plane_error<1e-5 and max_rotation_step<6,(min_elbow,max_elbow,plane_error,max_rotation_step,'Unnatural arm motion')
assert min_hand_gap>.035,('Hands overlap',min_hand_gap)
assert all(len(o.data.vertices)==8 and len(o.data.polygons)==6 for o in parts),'All site parts must be cuboids'
assert not any('_Shoulder_' in o['part'] for o in parts),'No duplicate static shoulder blocks'
assert sum('_Sleeve_' in o['part'] and '_upper_' in o['bone'] for o in parts)==6
assert not any(any(token in o['part'].lower() for token in ('earth_hex','window','arch','foundation')) for o in parts)
head_error=0.
for w in workers:
    obj=next(o for o in parts if o['part']==w['prefix']+'Head')
    for vertex,reference in zip(obj.data.vertices,elf_head.data.vertices):
        head_error=max(head_error,(vertex.co-w['P'](elf_transform@(elf_head.matrix_world@reference.co))).length)
assert head_error<1e-7
scene.frame_set(1)

def consolidate(items,name,skinned):
    vertices=[]; faces=[]; uvs=[]; spans=[]
    for item in items:
        start=len(vertices); vertices.extend(tuple(v.co) for v in item.data.vertices)
        faces.extend(tuple(start+i for i in f.vertices) for f in item.data.polygons)
        uvs.extend(tuple(l.uv) for l in item.data.uv_layers.active.data)
        spans.append((item['bone'],start,len(item.data.vertices)))
    data=bpy.data.meshes.new(name+'_Export'); data.from_pydata(vertices,[],faces); data.update(); data.materials.append(mat)
    uv=data.uv_layers.new(name='UVMap')
    for l,value in zip(uv.data,uvs): l.uv=value
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.parent=rig if skinned else root
    if skinned:
        groups={n:obj.vertex_groups.new(name=n) for n in bones}
        for bone,start,count in spans: groups[bone].add(list(range(start,start+count)),1.,'REPLACE')
        obj.modifiers.new('Rigid_worker_skin','ARMATURE').object=rig
    return obj

runtime=[consolidate([p for p in parts if not p['bone']],'Construction_Props',False),consolidate([p for p in parts if p['bone']],'Construction_Workers',True)]
bpy.ops.object.select_all(action='DESELECT')
for obj in [root,rig,*runtime]: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,
    export_yup=True,export_cameras=False,export_lights=False,export_extras=False,export_anim_slide_to_zero=True)
raw=(OUT/(STEM+'.glb')).read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size])
assert len(doc['meshes'])==2 and len(doc['materials'])==1 and len(doc['skins'])==1
assert [a['name'] for a in doc['animations']]==['construction']
assert all(s.get('magFilter')==9728 for s in doc['samplers'])
triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
for obj in runtime:
    data=obj.data; bpy.data.objects.remove(obj,do_unlink=True); bpy.data.meshes.remove(data)
report=dict(stem=STEM,race='elf',revision=3,style='Generic blocky elven construction with loose building blocks, rough bark-covered timber, emerald roofing stock and gold leaf ornaments; woodwork loops, original elf faces and ears, no specific building or ground plate',pipeline='Live Blender MCP localhost:9876',workers=3,
    jobs=['timber_mortise_mallet_and_chisel','timber_sawing','timber_hand_planing'],
    geometry=dict(editable_parts=len(parts),triangles=triangles,closed_solids=True,flat_shading=True,all_content_cuboids=True,hex_radius=1.,footprint_radius=.9,ground_plate=False,ground_workers_feet_z=0.,specific_architecture=False,hex_corner_angle_degrees=-30,hex_orientation='pointy-top virtual footprint; matches HexMetrics.corner',max_hex_half_plane=max_hex,max_content_half_plane=max_content_hex,footprint_margin=.9*math.sqrt(3)/2-max_content_hex,limiting_part=limiting_part,minimum_ground_z=min_z),
    building_materials=dict(reference=paint_source.relative_to(ROOT).as_posix(),structure='timber_and_loose_blocks',timber=PALETTE['wood'],raw_timber_logs=3,raw_timber_continuous_bark=True,stone=PALETTE['stone'],cutstone=PALETTE['cutstone'],loose_building_blocks=6,gold=PALETTE['gold'],roof=PALETTE['roof'],roof_dark=PALETTE['roof_dark'],loose_green_roof_slates=10,loose_gold_leaf_ornaments=3),
    elf_style=dict(reference=SOURCE_PATH.relative_to(ROOT).as_posix(),head_original_geometry=True,head_scale=ELF_SCALE,head_max_vertex_error=head_error,original_face_pixels=True,original_ear_parts_per_worker=6,facial_detail_meshes=0,fixed_body_original_proportions=True,static_shoulder_blocks=0,animated_shoulder_height=.334,shoulder_sleeve_cap_extension=.012,forearm_lengths={w['name']:{s:(w['local']['hand_'+s]-w['local']['fore_'+s]).length for s in ('L','R')} for w in workers}),
    animation=dict(clip='construction',seconds=6.,fps=FPS,frames=COUNT,loop_error=loop_error,max_joint_error=joint_error,feet_stationary=True,root_motion=False,stable_elbow_planes=True,axial_twist_error=plane_error,min_elbow_bend_degrees=min_elbow,max_elbow_bend_degrees=max_elbow,max_arm_rotation_step_degrees=max_rotation_step,min_hand_center_gap=min_hand_gap),
    export=dict(bytes=len(raw),meshes=2,materials=1,skins=1,bones=len(doc['skins'][0]['joints']),embedded_images=len(doc['images']),cameras=0,lights=0),status='PASS')
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')

# Preview studio is intentionally excluded from the selected game export.
studio=bpy.data.collections.new('Preview_Studio'); scene.collection.children.link(studio)
floor_mat=bpy.data.materials.new(STEM+'_StudioFloor'); floor_mat.diffuse_color=(.12,.16,.19,1)
data=bpy.data.meshes.new('Construction_Studio_floor'); data.from_pydata([(-200,-200,-.001),(200,-200,-.001),(200,200,-.001),(-200,200,-.001)],[],[(0,1,2,3)])
floor=bpy.data.objects.new('Preview_floor',data); studio.objects.link(floor); data.materials.append(floor_mat)
camera_data=bpy.data.cameras.new('Construction_Preview_Camera'); camera=bpy.data.objects.new('Construction_Preview_Camera',camera_data); studio.objects.link(camera)
camera_data.type='ORTHO'; camera_data.ortho_scale=2.55; camera.location=(2.4,-3.5,2.9)
camera.rotation_euler=(Vector((0,0,.24))-camera.location).to_track_quat('-Z','Y').to_euler(); scene.camera=camera
for name,pos,power,size,color in [('Key',(-3,-4,6),500,4,(1,.91,.78)),('Fill',(4,0,4),350,4,(.77,.85,1)),('Rim',(0,4,5),450,3,(1,1,.90))]:
    data=bpy.data.lights.new(STEM+'_'+name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(data.name,data); studio.objects.link(obj); obj.location=pos; obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(STEM+'_World'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.32,.39,1); world.node_tree.nodes['Background'].inputs[1].default_value=.45; scene.world=world
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='AgX'
scene['construction_report']=json.dumps(report)
bpy.app.driver_namespace['elf_construction_v1']=dict(scene=scene,root=root,rig=rig,parts=parts,report=report,out=OUT,work=WORK,studio=studio)
bpy.app.driver_namespace.pop('elf_construction_build_in_progress',None)
assert all(name in bpy.data.scenes for name in prior)
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},fake_user=True,compress=True)
result=report
