"""Adjust an EXISTING magic-school scene; never execute the original builder.

Preserves building volumes, layout, ground scale and gameplay identifiers.
Caller supplies POLISH_FOLDER. Uses the actual approved skeleton paint for relics.
"""
import ast
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
ASSET_FOLDER,ASSET_NAME = POLISH_FOLDER,POLISH_FOLDER.title()
if ASSET_NAME not in bpy.data.scenes:
    candidates = list((ROOT/'assets/generated').glob('*/buildings/'+POLISH_FOLDER+'/'+POLISH_FOLDER+'.blend'))
    assert len(candidates)==1
    with bpy.data.libraries.load(str(candidates[0]),link=False) as (src,dst):
        assert ASSET_NAME in src.scenes
        dst.scenes = [ASSET_NAME]
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
NAME,scene,parts,groups,root = st['name'],st['scene'],st['parts'],st['groups'],st['root']
bpy.context.window.scene = scene
assert not scene.get('finish_pass_revision'), 'Already polished; preserve further edits: '+NAME
CIV,SCHOOL = scene['civilization'],scene['magic_school']
TRIM = {'human':'gold','orc':'iron','dwarf':'bronze','elf':'gold'}[CIV]
POST = 'cutstone' if CIV=='dwarf' else 'timber'
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (
    ('warrior_hall_hex_v1_model.py',('mesh','box','polygon_prism','hexagon')),
    ('war_stable_hex_v1_model.py',('vertical_prism',)),
    ('magic_school_model.py',('beam','ring','crystal')),
    ('elf_city_level_1_hex_v1_model.py',('leaf',)),
    ('orc_city_level_1_hex_v1_model.py',('tusk',)),
):
    for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<finish_primitives>','exec'))


def bb(obj):
    return Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3))),Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))


def find(label):
    return next(o for o in parts if o['part']==label)


def translate(obj,delta):
    for vertex in obj.data.vertices:
        vertex.co += Vector(delta)
    obj.data.update()


def remove(obj):
    parts.remove(obj)
    data = obj.data
    bpy.data.objects.remove(obj,do_unlink=True)
    if not data.users:
        bpy.data.meshes.remove(data)


def resize_box(obj,center,size):
    old_lo,old_hi = bb(obj)
    old_center = (old_lo+old_hi)/2
    old_size = old_hi-old_lo
    for vertex in obj.data.vertices:
        vertex.co = Vector(tuple(center[i]+(vertex.co[i]-old_center[i])*size[i]/old_size[i] for i in range(3)))
    obj.data.update()


def small_bone(name,a,b,width=.018,group='04_FOCUS'):
    beam(name+'_Shaft',a,b,width,'bone',group)
    direction = (Vector(b)-Vector(a)).normalized()
    ref = Vector((0,0,1)) if abs(direction.z)<.9 else Vector((1,0,0))
    cross = direction.cross(ref).normalized()*width*.48
    for i,point in enumerate((Vector(a),Vector(b))):
        for sign in (-1,1):
            box(name+'_Joint_%s_%s'%(i,sign),point+cross*sign,(width*1.25,width*1.25,width*1.25),'bone',group)


def rivets(name,center,width,reg=TRIM,group='08_DETAILS'):
    x,y,z = center
    for i in range(3):
        box(name+'_%d'%i,(x-width*.38+i*width*.38,y,z),(.015,.016,.015),reg,group)


# Snapshot structural coordinates: no footprint, wall body or original roof shape is rebuilt.
STRUCTURAL_TOKENS = ('Hex_','_Body','_Chamber','_Tower','_Course_','_Terrace_','_Foot','_Shaft','_Post_')
original_structures = {o['part']:[tuple(v.co) for v in o.data.vertices] for o in parts
    if o['part'].startswith('Hex_') or any(t in o['part'] for t in ('_Body','Crypt_Chamber','Conclave_Hex_Tower','Observation_Tower','Mausoleum_Terrace_','_Course_'))}

# Uniform slate color on every roof surface, including the former ivory tomb terraces.
palette = {k:list(v) for k,v in scene['palette_overrides'].items()}
palette['roof'] = {'human':[49,79,127],'orc':[130,58,39],'dwarf':[67,82,89],'elf':[48,122,88]}[CIV]
palette['roof_dark'] = palette['roof']
palette['bone'] = [206,196,166]
palette['bone_highlight'] = [236,230,210]
palette['bone_shadow'] = [170,158,128]
palette['faction_dark'] = [max(0,int(v*.64)) for v in palette.get('faction',[52,83,145])]
palette['glass_cyan'] = [102,173,189]
for obj in parts:
    if obj['region']=='roof_dark' or obj['part'].startswith('Mausoleum_Terrace_'):
        obj['region']='roof'
scene['palette_overrides'] = palette

# Ground every lectern together with its book and text; keep the established positions.
lectern_roots = [o['part'][:-5] for o in parts if o['part'].endswith('_Foot') and
    any(w in o['part'] for w in ('Scripture','Grimoire','Spellbook','Herbarium','Field_Notes'))]
for prefix in lectern_roots:
    for obj in parts:
        if obj['part'].startswith(prefix+'_'):
            translate(obj,(0,0,-.013))

# Pedestal collars bridge the genuine gap between each stone foot and shaft.
for obj in list(parts):
    if obj['part'].endswith('_Column'):
        lo,hi = bb(obj)
        center = (lo+hi)/2
        box('Finish_'+obj['part']+'_Base_Collar',(center.x,center.y,.151),
            (hi.x-lo.x+.025,hi.y-lo.y+.025,.022),TRIM,'04_FOCUS')

# A properly founded mast, shaped cloth, crossbar, ties and a decorative cap.
pole = find('Faction_Pole')
resize_box(pole,(.58,.39,.559),(.027 if CIV=='orc' else .021,.024,1.0))
box('Finish_Flag_Stone_Foot',(.58,.39,.101),(.103,.103,.050),'cutstone','07_FACTION')
box('Finish_Flag_Foot_Collar',(.58,.39,.140),(.057,.057,.035),TRIM,'07_FACTION')
remove(find('Faction_Pennant'))
remove(find('School_Pennant_Emblem'))
flag_cx,flag_y = .490,.39
flag_h = .26 if CIV=='dwarf' else .22 if CIV=='elf' else .175
flag_w = .15 if CIV=='elf' else .17
flag_top = 1.008
bottom = flag_top-flag_h
profile = [(-flag_w/2,0),(flag_w/2,0),(flag_w/2,-flag_h)]
if CIV=='orc':
    profile += [(flag_w*.17,-flag_h*.83),(0,-flag_h),(-flag_w*.17,-flag_h*.83),(-flag_w/2,-flag_h)]
elif CIV=='elf':
    profile += [(0,-flag_h*.70),(-flag_w/2,-flag_h)]
else:
    profile += [(-flag_w/2,-flag_h)]
vertical_prism('Faction_Pennant',profile,(flag_cx,flag_y,flag_top),.014,'faction','07_FACTION')
box('Finish_Flag_Crossbar',(.500,.39,flag_top+.007),(.21,.033,.026),POST,'07_FACTION')
for sign in (-1,1):
    box('Finish_Flag_Tie_'+str(sign),(flag_cx+sign*flag_w*.32,.39,flag_top-.012),(.015,.035,.047),TRIM,'07_FACTION')
box('Finish_Flag_Pole_Cap',(.58,.39,1.064),(.037,.035,.026),TRIM,'07_FACTION')
if CIV=='elf':
    leaf('Finish_Flag_Leaf',(.58,.39,1.110),.061,.071,.018)
elif CIV=='orc':
    tusk('Finish_Flag_Fang',(.58,.39,1.077),.079,.036,.025,1,'07_FACTION')
elif CIV=='dwarf':
    box('Finish_Flag_Runestone',(.58,.39,1.087),(.050,.048,.030),'bronze','07_FACTION')
emblem_z = flag_top-flag_h*.40
if SCHOOL=='sacred':
    box('School_Pennant_Emblem',(.49,.376,emblem_z),(.011,.014,.058),'school','07_FACTION')
    box('Finish_Flag_Sun_Cross',(.49,.376,emblem_z+.005),(.050,.014,.012),'school','07_FACTION')
elif SCHOOL=='druidism':
    leaf('School_Pennant_Emblem',(.49,.376,emblem_z),.075,.063,.014,'school','07_FACTION')
else:
    vertical_prism('School_Pennant_Emblem',[(-.023,0),(0,-.033),(.023,0),(0,.033)],(.49,.376,emblem_z),.014,'school','07_FACTION')

# The rear/side of the old buildings was bare: add restrained structural craft.
body_parts = [o for o in parts if o['part'] in ('Chapel_Body','Sanctum_Body','Crypt_Chamber','Conclave_Hex_Tower','Observation_Tower')]
body = body_parts[0] if body_parts else None
if body:
    lo,hi = bb(body)
    front = lo.y
    center = (lo+hi)/2
    if CIV=='human':
        # Stone courses and timber braces, recognizable medieval formal architecture.
        for sign in (-1,1):
            px = center.x+sign*(hi.x-lo.x)*.42
            box('Finish_Human_Pilaster_'+str(sign),(px,front-.024,(lo.z+hi.z)/2),(.042,.051,hi.z-lo.z),'cutstone','08_DETAILS')
            box('Finish_Human_Pilaster_Cap_'+str(sign),(px,front-.032,hi.z-.027),(.070,.067,.036),'gold','08_DETAILS')
        box('Finish_Human_Rear_Cornice',(center.x,hi.y+.015,hi.z-.038),(hi.x-lo.x,.040,.037),'cutstone','08_DETAILS')
        if SCHOOL not in ('arcanism','elementalism'):
            for side in (-1,1):
                beam('Finish_Human_Side_Brace_'+str(side),(hi.x+.020,center.y+side*.085,hi.z-.16),
                    (hi.x+.020,center.y,hi.z-.017),.027,'timber','08_DETAILS')
    elif CIV=='orc':
        # Heavy iron straps, crooked clan braces and visible rivets.
        for sign in (-1,1):
            px = center.x+sign*(hi.x-lo.x)*.43
            box('Finish_Orc_Iron_Strapped_Post_'+str(sign),(px,front-.025,center.z),(.044,.052,hi.z-lo.z),'timber','08_DETAILS')
            for j in range(2):
                z = lo.z+.105+j*(hi.z-lo.z)*.56
                box('Finish_Orc_Post_Band_%s_%s'%(sign,j),(px,front-.055,z),(.067,.024,.043),'iron','08_DETAILS')
                rivets('Finish_Orc_Rivet_%s_%s'%(sign,j),(px,front-.072,z),.049,'iron_light')
        beam('Finish_Orc_Rear_Diagonal',(lo.x+.06,hi.y+.018,lo.z+.10),(hi.x-.05,hi.y+.018,hi.z-.04),.044,'timber','08_DETAILS')
    elif CIV=='dwarf':
        # Squared granite pilasters and engraved copper, rather than a wooden reskin.
        for sign in (-1,1):
            px = center.x+sign*(hi.x-lo.x)*.44
            box('Finish_Dwarf_Granite_Pier_'+str(sign),(px,front-.034,(.077+hi.z)/2),(.085,.087,hi.z-.077),'stone','08_DETAILS')
            box('Finish_Dwarf_Pier_Foot_'+str(sign),(px,front-.031,.112),(.115,.111,.070),'cutstone','08_DETAILS')
            box('Finish_Dwarf_Copper_Strap_'+str(sign),(px,front-.082,hi.z-.080),(.083,.018,.053),'bronze','08_DETAILS')
            box('Finish_Dwarf_Rune_Groove_'+str(sign),(px,front-.095,hi.z-.080),(.012,.013,.035),'iron','08_DETAILS')
        for i in range(3):
            box('Finish_Dwarf_Rear_Stone_Course_%d'%i,(center.x,hi.y+.012,lo.z+.070+i*(hi.z-lo.z)*.32),
                (hi.x-lo.x,.035,.027),'cutstone','08_DETAILS')
    else:
        # Fine carved branches and a real pointed keystone; foliage stays attached.
        for sign in (-1,1):
            px = center.x+sign*(hi.x-lo.x)*.44
            beam('Finish_Elf_Branch_Post_'+str(sign),(px,front-.011,lo.z+.045),
                 (px,front-.011,hi.z-.035),.025,'timber','08_DETAILS')
            beam('Finish_Elf_Branch_Brace_'+str(sign),(px,front-.010,hi.z-.16),
                 (px-sign*.082,front-.010,hi.z-.025),.021,'timber','08_DETAILS')
            for j in range(3):
                leaf('Finish_Elf_Facade_Leaf_%s_%s'%(sign,j),(px+sign*.022,front-.029,lo.z+.16+j*.094),
                     .08,.063,.018,'foliage' if j%2 else 'foliage_light')
        # Gentle vine on the right wall, fixed by a trellis.
        for j in range(3):
            box('Finish_Elf_Side_Vine_%d'%j,(hi.x+.018,center.y-.030+j*.023,lo.z+.14+j*.081),
                (.021,.044,.112),'foliage','08_DETAILS')
        if body['part'] in ('Conclave_Hex_Tower','Observation_Tower'):
            for obj in parts:
                if not obj['part'].startswith(('Finish_Elf_Branch_Post_','Finish_Elf_Branch_Brace_','Finish_Elf_Facade_Leaf_')):
                    continue
                for vertex in obj.data.vertices:
                    vertex.co.y+=abs(vertex.co.x-center.x)/math.sqrt(3)
                obj.data.update()
                bm=bmesh.new();bm.from_mesh(obj.data)
                bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
                bm.to_mesh(obj.data);bm.free()

# Better window construction: side mullions, diamond leads or iron bars by race.
for obj in list(parts):
    if obj['part'].endswith('_Glass') and obj['region']=='glass':
        lo,hi = bb(obj)
        c = (lo+hi)/2
        side = hi.x-lo.x < hi.y-lo.y
        width = hi.y-lo.y if side else hi.x-lo.x
        for sign in (-1,1):
            point = (c.x+.016,c.y+sign*width/2,c.z) if side else (c.x+sign*width/2,c.y-.016,c.z)
            box('Finish_'+obj['part']+'_Jamb_'+str(sign),point,(.023,.018,hi.z-lo.z+.022),TRIM,'08_DETAILS')
        if CIV=='human':
            if side:
                beam('Finish_'+obj['part']+'_Lead_A',(c.x+.014,c.y-width*.34,c.z-.032),(c.x+.014,c.y,c.z+.054),.008,'gold')
                beam('Finish_'+obj['part']+'_Lead_B',(c.x+.014,c.y+width*.34,c.z-.032),(c.x+.014,c.y,c.z+.054),.008,'gold')
            else:
                beam('Finish_'+obj['part']+'_Lead',(c.x-width*.33,c.y-.014,c.z),(c.x,c.y-.014,c.z+.042),.008,'gold')

if SCHOOL=='sacred':
    # Roof seat and bell hanger eliminate both the upper-stage gap and floating bell.
    box('Finish_Bell_Stage_Head',(-.48,.145,.980),(.214,.225,.036),POST,'02_HALL')
    box('Finish_Bell_Hanger',(-.48,.145,.943),(.015,.015,.085),TRIM,'04_FOCUS')
    polygon = [(-.112,-.104),(.112,-.104),(.112,.072),(.074,.110),(-.074,.110),(-.112,.072)]
    vertical_prism('Finish_Solar_Crest_Backing',polygon,(.045,-.222,.760),.022,'faction_dark','04_FOCUS')
    beam('Finish_Solar_Crest_Mount',(.045,-.230,.760),(.045,-.10,.760),.026,TRIM,'04_FOCUS')
    beam('Finish_Solar_Cross_Stem',(.045,-.249,.760),(.045,-.223,.760),.014,TRIM,'04_FOCUS')
    # A modest side bench contrasts formal human seating, clan timber, dwarf stone, elven wood.
    bx,by = .49,.14
    bench_reg = 'cutstone' if CIV=='dwarf' else 'timber'
    for sign in (-1,1):
        box('Finish_Sacred_Bench_Leg_'+str(sign),(bx,by+sign*.094,.136),(.037,.037,.118),bench_reg,'06_TRAINING')
    box('Finish_Sacred_Bench_Seat',(bx,by,.207),(.12,.267,.032),bench_reg,'06_TRAINING')
    if CIV=='elf':
        leaf('Finish_Font_Leaf',(-.32,-.524,.251),.085,.094,.017,'gold','06_TRAINING')
    elif CIV=='dwarf':
        box('Finish_Font_Copper_Face',(-.32,-.524,.245),(.145,.016,.045),'bronze','06_TRAINING')
    elif CIV=='orc':
        rivets('Finish_Font_Iron_Rivets',(-.32,-.519,.278),.17,'iron_light','06_TRAINING')
elif SCHOOL=='infernal':
    box('Finish_Brazier_Stand_Socket',(0,-.405,.144),(.133,.133,.023),TRIM,'04_FOCUS')
    for obj in parts:
        if obj['part'].startswith('Flame_Dais_Runes_'):
            translate(obj,(0,0,-.003))
    vertical_prism('Finish_Infernal_Sigil_Backing',[(-.118,-.108),(.118,-.108),(.118,.065),(0,.120),(-.118,.065)],
                   (0,-.080,.657),.028,'iron','04_FOCUS')
    beam('Finish_Infernal_Sigil_Mount',(0,-.066,.657),(0,.14,.657),.026,TRIM,'04_FOCUS')
    for sign in (-1,1):
        x = sign*.44
        if CIV=='dwarf':
            find('Infernal_Horn_'+str(sign))['region']='bronze'
            rivets('Finish_Infernal_Copper_Bolts_'+str(sign),(x,-.049,.790),.14,'bronze')
        elif CIV=='elf':
            find('Infernal_Horn_'+str(sign))['region']='iron'
            leaf('Finish_Infernal_Binding_Leaf_'+str(sign),(x,-.045,.885),.16,.15,.027,'gold')
            beam('Finish_Infernal_Binding_Leaf_Mount_'+str(sign),(x,-.038,.86),(x,.05,.86),.022,'gold','08_DETAILS')
        elif CIV=='orc':
            box('Finish_Infernal_Buttress_Band_'+str(sign),(x,-.037,.530),(.177,.040,.046),'iron','08_DETAILS')
            rivets('Finish_Infernal_Buttress_Rivet_'+str(sign),(x,-.064,.530),.14,'iron_light')
elif SCHOOL=='necromancy':
    # Fix feet and cornice without changing the mausoleum or its stepped roof geometry.
    for sign in (-1,1):
        box('Finish_Ossuary_Tower_Socle_'+str(sign),(sign*.445,.16,.110),(.206,.286,.066),'cutstone','02_HALL')
    box('Finish_Crypt_Roof_Cornice',(0,.21,.638),(.648,.50,.026),TRIM,'03_ROOFS')
    lid = find('Sarcophagus_Lid')
    coffin = find('Practice_Sarcophagus')
    c_lo,c_hi = bb(coffin)
    box('Finish_Sarcophagus_Stone_Bed',((c_lo.x+c_hi.x)/2,(c_lo.y+c_hi.y)/2,.087),
        (c_hi.x-c_lo.x+.025,c_hi.y-c_lo.y+.013,.023),'cutstone','06_TRAINING')
    # Real Skull/Jaw UVs from the in-game approved skeleton, repacked into this atlas.
    cache_key = 'magic_finish_skeleton_reference'
    reference = bpy.app.driver_namespace.get(cache_key)
    if reference is None:
        source = ROOT/'assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1_static.blend'
        with bpy.data.libraries.load(str(source),link=False) as (src,dst):
            dst.objects = [n for n in src.objects if n in ('Skeleton_Warrior_V1_Skull','Skeleton_Warrior_V1_Jaw','Skeleton_Warrior_V1_Ribcage')]
        reference = {}
        for obj in dst.objects:
            assert obj and obj.data.uv_layers
            uv = obj.data.uv_layers.active.data
            reference[obj['part']] = {'verts':[tuple(v.co) for v in obj.data.vertices],
                'faces':[tuple(p.vertices) for p in obj.data.polygons],
                'uvs':[axis for p in obj.data.polygons for li in p.loop_indices for axis in uv[li].uv]}
        assert {'Skull','Jaw','Ribcage'} <= reference.keys()
        bpy.app.driver_namespace[cache_key] = reference
    reference_scale = 1.85/2.0175
    skull_anchor = Vector((0,-.05,1.785))*reference_scale
    paint_atlas = ROOT/'assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1_atlas.png'

    def relic_skull(name,center,width):
        scale = width/(.32*reference_scale)
        for key in ('Skull','Jaw'):
            source = reference[key]
            vertices = [tuple(Vector(center)+(Vector(v)-skull_anchor)*scale) for v in source['verts']]
            obj = mesh(name+'_'+key,vertices,source['faces'],'bone','04_FOCUS')
            obj['source_paint_atlas'],obj['source_paint_uvs'] = str(paint_atlas),source['uvs']
            obj['relic_reference'] = 'skeleton_warrior_v1: '+key+'; original aged ivory paint and facial cavities'
        return scale

    old_skulls = [o for o in parts if o['part'].startswith(('Crypt_Skull_Crest_','Niche_Skull_'))]
    for obj in old_skulls:
        remove(obj)
    relic_skull('Crypt_Skull_Crest',(0,-.101,.625),.155)
    for sign in (-1,1):
        x = sign*.445
        for j in range(3):
            z = .244+j*.145
            relic_skull('Niche_Skull_%s_%s'%(sign,j),(x,.012,z),.061)
            remove(find('Stored_Bones_%s_%s'%(sign,j)))
            box('Finish_Niche_Shelf_%s_%s'%(sign,j),(x,.014,z-.044),(.146,.068,.020),
                'cutstone' if CIV=='dwarf' else 'timber','04_FOCUS')
            small_bone('Finish_Niche_Femur_%s_%s'%(sign,j),(x-.048,-.014,z-.028),(x+.049,-.014,z-.025),.009)
    # Crossed long bones under the skull: recognizable ossuary heraldry.
    small_bone('Finish_Crypt_Crossbone_A',(-.108,-.113,.516),(.103,-.113,.571),.015)
    small_bone('Finish_Crypt_Crossbone_B',(-.103,-.132,.570),(.109,-.132,.516),.015)
    box('Finish_Crypt_Crossbone_Mount',(0,-.062,.544),(.199,.111,.075),'iron','04_FOCUS')
    box('Finish_Crypt_Crossbone_Binding',(0,-.125,.544),(.032,.046,.033),TRIM,'04_FOCUS')
    # A restrained teaching ribcage on the existing coffin lid, using the approved rib paint.
    source = reference['Ribcage']
    rib_center = Vector((0,0,1.42))*reference_scale
    ratio = .127/(.38*reference_scale)
    vertices = []
    for v in source['verts']:
        rel = (Vector(v)-rib_center)*ratio
        vertices.append((rel.x,-.465+rel.z,.278-rel.y*.23))
    relic = mesh('Finish_Sarcophagus_Rib_Relic',vertices,source['faces'],'bone','06_TRAINING')
    relic['source_paint_atlas'],relic['source_paint_uvs'] = str(paint_atlas),source['uvs']
    # Soft flattening rotates the former front upward; recalculate normals after transformation.
    bm = bmesh.new();bm.from_mesh(relic.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(relic.data);bm.free()
    translate(find('Sarcophagus_Seal'),(.076,0,0))
    small_bone('Finish_Reliquary_Longbone',(-.38,.049,.100),(-.25,.049,.100),.014,'06_TRAINING')
    box('Finish_Reliquary_Tray',(-.315,.049,.091),(.174,.089,.028),TRIM,'06_TRAINING')
    if CIV=='orc':
        # Iron skull rack and trophy tusks, rather than civil stone storage.
        for sign in (-1,1):
            beam('Finish_Orc_Bone_Rack_'+str(sign),(sign*.523,-.028,.152),(sign*.523,-.028,.613),.022,'iron','04_FOCUS')
    elif CIV=='dwarf':
        for sign in (-1,1):
            box('Finish_Dwarf_Reliquary_Plate_'+str(sign),(sign*.445,.022,.163),(.135,.017,.041),'bronze','04_FOCUS')
    elif CIV=='elf':
        for sign in (-1,1):
            leaf('Finish_Elf_Memorial_Leaf_'+str(sign),(sign*.445,-.052,.680),.18,.135,.022)
            beam('Finish_Elf_Memorial_Leaf_Mount_'+str(sign),(sign*.445,.031,.660),
                 (sign*.445,-.048,.660),.023,'gold','04_FOCUS')
    else:
        box('Finish_Human_Crypt_Inscription',(0,-.028,.35),(.014,.020,.22),'gold','08_DETAILS')
elif SCHOOL=='druidism':
    for i in range(6):
        obj = find('Standing_Stone_%d'%i)
        lo,hi = bb(obj)
        c = (lo+hi)/2
        box('Finish_Grove_Stone_Foot_%d'%i,(c.x,c.y,.100),
            (hi.x-lo.x+.035,hi.y-lo.y+.035,.043),'stone','02_HALL')
        if CIV=='elf':
            for j in range(2):
                leaf('Finish_Grove_Vine_%s_%s'%(i,j),(c.x-.056,c.y-.086,.205+j*.105),.074,.058,.016,'foliage')
                box('Finish_Grove_Vine_Stem_%s_%s'%(i,j),(c.x-.050,c.y-.078,.208+j*.100),(.015,.017,.125),'foliage','08_DETAILS')
        elif CIV=='dwarf':
            box('Finish_Grove_Copper_Rune_Plate_%d'%i,(c.x,c.y-.080,.19),(.095,.019,.045),'bronze','08_DETAILS')
        elif CIV=='orc':
            box('Finish_Grove_Totem_Wrap_%d'%i,(c.x,c.y,.30),
                (hi.x-lo.x+.015,hi.y-lo.y+.015,.034),'iron','08_DETAILS')
    for obj in list(parts):
        if obj['part'].startswith('Herb_Bed_'):
            lo,hi = bb(obj);c=(lo+hi)/2
            box('Finish_'+obj['part']+'_Soil_Foot',(c.x,c.y,.095),(.139,.115,.036),'stone','08_DETAILS')
    if CIV=='human':
        # Formal herbalists' stone table at the back of the circle.
        box('Finish_Human_Herb_Table',(.165,.466,.260),(.165,.125,.033),'timber','06_TRAINING')
        for sign in (-1,1):
            box('Finish_Human_Herb_Table_Leg_'+str(sign),(.165+sign*.06,.466,.170),(.025,.075,.177),'timber','06_TRAINING')
    elif CIV=='elf':
        # A branch connecting two existing rear pillars; no new building volume.
        a = bb(find('Standing_Stone_1'));b = bb(find('Standing_Stone_2'))
        ac,bc=(a[0]+a[1])/2,(b[0]+b[1])/2
        beam('Finish_Elf_Grove_Branch_Lintel',(ac.x,ac.y,a[1].z-.020),(bc.x,bc.y,b[1].z-.020),.042,'timber','08_DETAILS')
elif SCHOOL=='arcanism':
    lo,hi = bb(find('Conclave_Hex_Roof_5'))
    roof_z = hi.z
    focus_lo,focus_hi = bb(find('Floating_Arcane_Prism'))
    focus = (focus_lo+focus_hi)/2
    for sign in (-1,1):
        x = focus.x+sign*.15
        box('Finish_Arcane_Fork_Foot_'+str(sign),(x,focus.y,roof_z-.006),(.045,.067,.032),TRIM,'04_FOCUS')
        beam('Finish_Arcane_Fork_'+str(sign),(x,focus.y,roof_z-.006),(x,focus.y,focus.z),.020,TRIM,'04_FOCUS')
        # Feet land on the next lower roof tier, not outside the tiny top course.
        beam('Finish_Arcane_Fork_Roof_Anchor_'+str(sign),(focus.x+sign*.062,focus.y,roof_z-.037),
             (x,focus.y,roof_z-.006),.026,TRIM,'04_FOCUS')
    # Visible bound scrolls on a fixed rear wall shelf.
    body = find('Scroll_Library_Body');lo,hi=bb(body);c=(lo+hi)/2
    box('Finish_Arcane_Scroll_Shelf',(hi.x+.028,c.y,.30),(.090,.21,.031),'timber','06_TRAINING')
    beam('Finish_Arcane_Shelf_Bracket',(hi.x+.004,c.y,.22),(hi.x+.070,c.y,.287),.023,TRIM,'06_TRAINING')
    for i in range(3):
        box('Finish_Arcane_Bound_Scroll_%d'%i,(hi.x+.029,c.y-.067+i*.062,.337),(.057,.043,.056),'paper','06_TRAINING')
        box('Finish_Arcane_Scroll_Band_%d'%i,(hi.x+.062,c.y-.067+i*.062,.337),(.012,.017,.056),TRIM,'06_TRAINING')
    if CIV=='dwarf':
        for sign in (-1,1):
            box('Finish_Dwarf_Arcane_Fork_Gear_'+str(sign),(focus.x+sign*.15,focus.y-.023,roof_z+.040),(.065,.021,.064),'bronze','04_FOCUS')
    elif CIV=='elf':
        for sign in (-1,1):
            leaf('Finish_Elf_Arcane_Crown_Leaf_'+str(sign),(focus.x+sign*.15,focus.y,focus.z-.053),.08,.12,.025)
elif SCHOOL=='elementalism':
    polygon_prism('Finish_Observation_Deck_Seat',hexagon(.323,(0,.19)),.566,.589,'roof','03_ROOFS')
    polygon_prism('Finish_Armillary_Pedestal_Seat',hexagon(.096,(0,.19)),.675,.708,TRIM,'04_FOCUS')
    for i,reg in enumerate(('fire','water','earth','air')):
        glyph = find('Element_Plinth_Sigil_%d'%i)
        translate(glyph,(0,.025,0))
        col = find('Element_'+reg+'_Column');lo,hi = bb(col);c=(lo+hi)/2
        box('Finish_Element_'+reg+'_Glyph_Backing',(c.x,c.y-.043,.203),(.079,.035,.079),TRIM,'04_FOCUS')
        if CIV=='elf':
            ornament=find('Element_Leaf_%d'%i)
            capital=find('Element_'+reg+'_Capital');a,b=bb(capital)
            leaf_lo,leaf_hi=bb(ornament)
            translate(ornament,(0,0,b.z+.002-leaf_lo.z))
            beam('Finish_Element_Leaf_Stem_%d'%i,(c.x,c.y,b.z-.008),
                 (c.x,c.y,b.z+.030),.012,'gold','04_FOCUS')
        elif CIV=='orc':
            tusk_obj=find('Element_Totem_Tusk_%d'%i)
            foot=find('Element_'+reg+'_Foot');a,b=bb(foot)
            box('Finish_Element_Tusk_Boot_%d'%i,(c.x+.075,c.y,.142),(.040,.052,.033),'iron','04_FOCUS')
    # Physical declination bearing and accessible short exterior ladder.
    box('Finish_Armillary_Axis',(0,.19,.869),(.20,.041,.042),TRIM,'04_FOCUS')
    for sign in (-1,1):
        box('Finish_Armillary_Bearing_'+str(sign),(sign*.092,.19,.891),(.061,.068,.068),TRIM,'04_FOCUS')
    for sign in (-1,1):
        beam('Finish_Observation_Ladder_Rail_'+str(sign),(-.227,.19+sign*.055,.091),(-.320,.19+sign*.055,.677),.021,POST,'08_DETAILS')
    for i in range(5):
        t=i/4
        beam('Finish_Observation_Ladder_Rung_%d'%i,(-.237-t*.071,.135,.157+t*.460),
             (-.237-t*.071,.245,.157+t*.460),.017,TRIM,'08_DETAILS')
    if CIV=='dwarf':
        ring('Finish_Dwarf_Armillary_Gear_Rim',(.092,.144,.891),.038,.018,'bronze','XZ','04_FOCUS',8)
        for i in range(8):
            a=i*math.pi/4
            box('Finish_Dwarf_Armillary_Gear_Tooth_%d'%i,(.092+math.cos(a)*.044,.144,.891+math.sin(a)*.044),
                (.021,.024,.021),'bronze','04_FOCUS')
    elif CIV=='elf':
        for sign in (-1,1):
            beam('Finish_Elf_Armillary_Branch_'+str(sign),(0,.19,.806),(sign*.112,.19,.924),.019,'gold','04_FOCUS')
            leaf('Finish_Elf_Armillary_Branch_Leaf_'+str(sign),(sign*.112,.19,.932),.084,.081,.023)

# Narrow elf stones require face-aligned ornaments, including the rotated pillars.
if CIV=='elf' and SCHOOL=='druidism':
    for i in range(6):
        a=math.radians(30+i*60)
        x,y=.50*math.cos(a),-.025+.50*math.sin(a)
        labels={'Stone_Rune_Vertical_'+str(i):.009,'Stone_Rune_Cross_'+str(i):.009,
                **{'Finish_Grove_Vine_%s_%s'%(i,j):.016 for j in range(2)},
                **{'Finish_Grove_Vine_Stem_%s_%s'%(i,j):.011 for j in range(2)}}
        for obj in parts:
            if obj['part'] not in labels:
                continue
            for vertex in obj.data.vertices:
                dx,dy=vertex.co.x-x,vertex.co.y-y+labels[obj['part']]
                vertex.co.x=x+dx*math.cos(a)-dy*math.sin(a)
                vertex.co.y=y+dx*math.sin(a)+dy*math.cos(a)
            obj.data.update()
    scene['grove_face_ornaments_seated']=True

# Small floor engravings used to hover just above the paving.
for obj in parts:
    if obj['part'].startswith(('Copper_Ground_Rune_','Ground_Rune_Inset_')):
        translate(obj,(0,0,-.007))
for obj in parts:
    obj.parent = root

# Support audit catches remaining tiny seat gaps. Fix isolated clusters with narrow
# architecture-specific sockets; crystals with intentional levitation stay exempt.
AUDIT_RUN = False
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
unattached = detached(parts)
scene['finish_pass_attachment_before_remaining'] = [o['part'] for o in unattached]
for obj in unattached:
    # Physical pinpoints/cavities on source relics are textures, not floating meshes.
    # Automatically cover only small vertical gaps with a discreet local seat.
    if obj['part'].endswith('_Foot') or obj['part'].startswith('Finish_'):
        lo,hi = bb(obj)
        if .077 < lo.z < .14:
            box('Finish_Ground_Seat_'+obj['part'],((lo.x+hi.x)/2,(lo.y+hi.y)/2,(lo.z+.077)/2),
                (hi.x-lo.x,hi.y-lo.y,lo.z-.077+.004),'cutstone','08_DETAILS')

remaining = detached(parts)
scene['finish_pass_attachment_remaining'] = [o['part'] for o in remaining]
# All original structural vertices must remain byte-for-byte numerically unchanged.
for label,vertices in original_structures.items():
    obj = find(label)
    assert vertices == [tuple(v.co) for v in obj.data.vertices], label
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.03,(NAME,maximum)
scene['finish_pass_revision'] = 1
scene['finish_pass_preserves_structure'] = True
scene['finish_pass_note'] = {'human':'Formal masonry pilasters, stained-glass leads, timber side braces and a fixed standard.',
    'orc':'Iron strapped timber, rivets, clan braces, jagged cloth and secured tusks.',
    'dwarf':'Squared granite piers, engraved copper, stone furniture and mechanical bearings.',
    'elf':'Carved branches, attached vine foliage, pointed details and leaf-shaped mounts.'}[CIV]
scene['design_note'] = scene['design_note']+' Finish pass: '+scene['finish_pass_note']+' Roof palette unified; structural volumes and layout preserved.'
if SCHOOL=='necromancy':
    scene['design_note'] += ' Skull/jaw and ribcage paint reused from approved skeleton_warrior_v1; bone shelves, femurs, crossed-bone relief and coffin relic.'
st.update({'parts':parts,'design_note':scene['design_note']})
bpy.app.driver_namespace['guardian_hall'] = st
result = {'asset':POLISH_FOLDER,'original_structure_preserved':True,'parts':len(parts),
          'roof_rgb':palette['roof'],'attachment_remaining':[o['part'] for o in remaining]}
