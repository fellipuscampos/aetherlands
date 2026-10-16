"""Build one new grand ritual landmark through the live Blender MCP.

Inputs GRAND_CIV and GRAND_SCHOOL. Existing schools are read as material
references only. Native hex scale, editable closed meshes, no external models.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT / 'tools/art_pipeline'
RECIPES = {
    'sacred': ('sacred_ritual', 'Grande Catedral', 'seraph', 'sacred_temple'),
    'infernal': ('infernal_ritual', 'Círculo Profano', 'archdemon', 'infernal_sanctum'),
    'necromancy': ('necromancy_ritual', 'Mausoléu Negro', 'lich_sovereign', 'necromancy_ossuary'),
    'druidism': ('druidic_ritual', 'Bosque Ancestral', 'nature_avatar', 'druidic_circle'),
    'arcanism': ('arcane_ritual', 'Torre do Véu', 'veil_archon', 'arcane_conclave'),
    'elementalism': ('elemental_ritual', 'Nexus dos Elementos', 'elemental_primordial', 'elemental_observatory'),
}
CIV, SCHOOL = GRAND_CIV, GRAND_SCHOOL
STEM, DISPLAY, MANIFESTATION, PREVIOUS = RECIPES[SCHOOL]
PLURAL = {'human':'humans', 'orc':'orcs', 'dwarf':'dwarves', 'elf':'elves'}[CIV]
PREFIX = '' if CIV == 'human' else CIV + '_'
FOLDER = PREFIX + STEM + '_hex_v1'
NAME = FOLDER.title()
ASSET_NAME, ASSET_FOLDER = NAME, FOLDER
OUT = ROOT / 'assets/generated' / PLURAL / 'buildings' / FOLDER
assert NAME not in bpy.data.scenes and not (OUT/(FOLDER+'.blend')).exists(), 'Preserve existing asset: '+FOLDER
reference_folder = PREFIX + PREVIOUS + '_hex_v1'
reference_name = reference_folder.title()
if reference_name not in bpy.data.scenes:
    source = ROOT/'assets/generated'/PLURAL/'buildings'/reference_folder/(reference_folder+'.blend')
    with bpy.data.libraries.load(str(source),link=False) as (src,dst):
        dst.scenes=[reference_name]
reference_scene = bpy.data.scenes[reference_name]
palette = {key:list(value) for key,value in reference_scene['palette_overrides'].items()}
palette['roof_dark'] = palette['roof']
palette['tombstone'] = [int(v*.40) for v in palette.get('stone',[131,141,145])]
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_FOCUS','05_COURTYARD','06_TRAINING','07_FACTION','08_DETAILS','09_STUDIO'):
    col=bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(col)
    groups[label]=col
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
TRIM={'human':'gold','orc':'iron','dwarf':'bronze','elf':'gold'}[CIV]
BODY={'human':'plaster','orc':'door','dwarf':'stone','elf':'plaster'}[CIV]
POST='cutstone' if CIV=='dwarf' else 'timber'
HEIGHT={'human':1.0,'orc':.95,'dwarf':.90,'elf':1.07}[CIV]
PITCH={'human':.052,'orc':.045,'dwarf':.040,'elf':.061}[CIV]
for filename,names in (
    ('warrior_hall_hex_v1_model.py',('mesh','box','polygon_prism','hexagon')),
    ('war_stable_hex_v1_model.py',('vertical_prism',)),
    ('magic_school_model.py',('beam','ring','crystal')),
    ('orc_city_level_1_hex_v1_model.py',('tusk',)),
    ('elf_city_level_1_hex_v1_model.py',('leaf',)),
):
    for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<grand_primitives>','exec'))

def bounds(obj):
    return Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3))),Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))

def roof(name,x,y,w,d,bottom,steps=6,gable=False,ornament=True):
    for j in range(steps):
        width=w*(1-j*.12)
        depth=d if gable else d*(1-j*.115)
        box(name+'_Course_%02d'%j,(x,y,bottom+(j+.5)*PITCH),(width,depth,PITCH),'roof','03_ROOFS')
    top=bottom+steps*PITCH
    box(name+'_Eave',(x,y-d/2-.002,bottom+.009),(w+.012,.022,.022),TRIM,'03_ROOFS')
    box(name+'_Ridge',(x,y,top+.008),(w*(1-(steps-1)*.12),.055,.020),'roof','03_ROOFS')
    if ornament:
        box(name+'_Finial_Seat',(x,y,top+.021),(.076,.076,.023),TRIM,'03_ROOFS')
        if CIV=='orc':
            tusk(name+'_Clan_Fang',(x,y,top+.028),.145,.057,.042,1,'03_ROOFS')
        elif CIV=='elf':
            leaf(name+'_Gold_Leaf',(x,y,top+.091),.105,.126,.025,'gold','03_ROOFS')
        elif CIV=='dwarf':
            box(name+'_Copper_Block',(x,y,top+.047),(.10,.089,.045),'bronze','03_ROOFS')
        else:
            box(name+'_Finial',(x,y,top+.055),(.025,.025,.060),'gold','03_ROOFS')
    return top

def wall_craft(name,x,y,w,d,z0,z1):
    front=y-d/2
    for sign in (-1,1):
        px=x+sign*w*.43
        width={'human':.049,'orc':.064,'dwarf':.087,'elf':.029}[CIV]
        reg='cutstone' if CIV in ('human','dwarf') else 'timber'
        box(name+'_Pier_'+str(sign),(px,front-.010,(z0+z1)/2),(width,.043,z1-z0),reg,'08_DETAILS')
        box(name+'_Pier_Capital_'+str(sign),(px,front-.011,z1-.034),(width+.028,.055,.038),TRIM,'08_DETAILS')
        if CIV in ('orc','dwarf'):
            for j in range(2):
                z=z0+.09+j*(z1-z0)*.58
                box(name+'_Band_%s_%s'%(sign,j),(px,front-.033,z),(width+.014,.024,.041),TRIM,'08_DETAILS')
                if CIV=='orc':
                    for k in (-1,1):
                        box(name+'_Rivet_%s_%s_%s'%(sign,j,k),(px+k*width*.29,front-.047,z),(.012,.012,.013),'iron_light','08_DETAILS')
                else:
                    box(name+'_Engraving_%s_%s'%(sign,j),(px,front-.047,z),(.009,.012,.027),'iron','08_DETAILS')
        elif CIV=='elf':
            beam(name+'_Branch_'+str(sign),(px,front-.010,z1-.145),(px-sign*.073,front-.010,z1-.018),.022,'timber')
            for j in range(2):
                leaf(name+'_Vine_%s_%s'%(sign,j),(px+sign*.011,front-.034,z0+.125+j*.092),.074,.064,.020,'foliage','08_DETAILS')
    if CIV=='human':
        box(name+'_Rear_Cornice',(x,y+d/2+.005,z1-.037),(w,.027,.035),'cutstone','08_DETAILS')
    elif CIV=='orc':
        beam(name+'_Rear_Brace',(x-w*.38,y+d/2+.007,z0+.10),(x+w*.38,y+d/2+.007,z1-.035),.040,'timber')
    elif CIV=='dwarf':
        box(name+'_Rear_Copper_Band',(x,y+d/2+.006,z1-.056),(w,.026,.032),'bronze','08_DETAILS')

def hall(name,x,y,w,d,z0,h,steps=6,gable=False,craft=True,reg=BODY,ornament=True):
    box(name+'_Foot',(x,y,z0+.035),(w+.025,d+.025,.070),'cutstone','02_HALL')
    box(name+'_Body',(x,y,z0+.065+h/2),(w,d,h),reg,'02_HALL')
    z1=z0+.065+h
    if craft:
        wall_craft(name,x,y,w,d,z0+.065,z1)
    roof(name,x,y,w+.091,d+.083,z1-.002,steps,gable,ornament)
    return z1

def doorway(name,x,front,z0=.148,w=.26,h=.40):
    box(name+'_Backing',(x,front-.003,z0+h/2),(w+.04,.028,h+.035),'shadow','02_HALL')
    for sign in (-1,1):
        box(name+'_Door_'+str(sign),(x+sign*w*.24,front-.022,z0+h*.43),(w*.47,.024,h*.86),'door','02_HALL')
        box(name+'_Jamb_'+str(sign),(x+sign*(w/2+.021),front-.012,z0+h/2),(.045,.060,h+.037),'cutstone','02_HALL')
        box(name+'_Handle_'+str(sign),(x+sign*.023,front-.040,z0+h*.42),(.012,.018,.041),TRIM,'08_DETAILS')
    box(name+'_Lintel',(x,front-.011,z0+h+.012),(w+.102,.062,.040),TRIM,'02_HALL')
    if CIV=='elf':
        for sign in (-1,1):
            beam(name+'_Point_'+str(sign),(x+sign*w*.38,front-.014,z0+h+.014),(x,front-.014,z0+h+.13),.027,'cutstone','02_HALL')
    elif CIV=='orc':
        for sign in (-1,1):
            box(name+'_Fang_Seat_'+str(sign),(x+sign*(w/2+.047),front-.043,z0+.015),(.063,.078,.044),'iron','02_HALL')
            tusk(name+'_Entry_Fang_'+str(sign),(x+sign*(w/2+.047),front-.043,z0+.032),h*.82,.052,.040,-sign,'02_HALL')
    for i in range(3):
        box(name+'_Stair_'+str(i),(x,front-.074-i*.046,.138-i*.022),(w+.11+i*.045,.080,.047),'cutstone','05_COURTYARD')

def window(name,x,front,z,w=.105,h=.22):
    box(name+'_Glass',(x,front-.002,z),(w,.025,h),'glass','08_DETAILS')
    for sign in (-1,1):
        box(name+'_Jamb_'+str(sign),(x+sign*w/2,front-.010,z),(.018,.038,h+.034),TRIM,'08_DETAILS')
        box(name+'_Sill_'+str(sign),(x,front-.010,z+sign*h/2),(w+.02,.038,.022),TRIM,'08_DETAILS')
    box(name+'_Mullion',(x,front-.014,z),(.009,.011,h),TRIM,'08_DETAILS')
    if CIV=='human':
        for sign in (-1,1):
            beam(name+'_Diamond_'+str(sign),(x+sign*w*.37,front-.014,z-.024),(x,front-.014,z+.070),.007,'gold','08_DETAILS')

def standard(x=.61,y=.28):
    top=1.27
    box('Standard_Foot',(x,y,.101),(.106,.106,.052),'cutstone','07_FACTION')
    box('Standard_Socket',(x,y,.145),(.057,.057,.041),TRIM,'07_FACTION')
    box('Standard_Mast',(x,y,(top+.060)/2),(.023,.026,top-.060),POST,'07_FACTION')
    box('Standard_Crossbar',(x-.079,y,top-.040),(.204,.038,.031),POST,'07_FACTION')
    box('Standard_Cap',(x,y,top+.004),(.041,.041,.041),TRIM,'07_FACTION')
    w,h=.16,.21 if CIV=='dwarf' else .18
    points=[(-w/2,0),(w/2,0),(w/2,-h)]
    points += [(w*.15,-h*.80),(-w*.10,-h),(-w*.31,-h*.82),(-w/2,-h)] if CIV=='orc' else (
        [(0,-h*.68),(-w/2,-h)] if CIV=='elf' else [(-w/2,-h)])
    vertical_prism('Standard_Cloth',points,(x-.080,y,top-.047),.014,'faction','07_FACTION')
    for sign in (-1,1):
        box('Standard_Tie_'+str(sign),(x-.080+sign*.044,y,top-.062),(.012,.038,.041),TRIM,'07_FACTION')
    if SCHOOL=='sacred':
        box('Standard_Emblem',(x-.080,y-.010,top-.116),(.012,.014,.055),'school','07_FACTION')
        box('Standard_Emblem_Cross',(x-.080,y-.010,top-.113),(.049,.014,.012),'school','07_FACTION')
    elif SCHOOL=='druidism':
        leaf('Standard_Emblem',(x-.080,y-.010,top-.115),.070,.066,.014,'school','07_FACTION')
    else:
        vertical_prism('Standard_Emblem',[(-.019,0),(0,-.027),(.019,0),(0,.027)],(x-.080,y-.010,top-.117),.014,'school','07_FACTION')

def bowl(name,x,y,z=.077,reg=TRIM):
    box(name+'_Foot',(x,y,z+.031),(.125,.125,.062),'cutstone','06_TRAINING')
    box(name+'_Stem',(x,y,z+.117),(.064,.064,.13),POST,'06_TRAINING')
    box(name+'_Basin',(x,y,z+.190),(.18,.18,.035),reg,'06_TRAINING')
    box(name+'_Water',(x,y,z+.210),(.13,.13,.013),'water','06_TRAINING')

def anatomical_reference():
    key='grand_magic_anatomical_reference'
    cache=bpy.app.driver_namespace.get(key)
    if cache is None:
        labels={'Skull','Jaw','Neck','Ribcage','Spine','Pelvis','Shoulder_l','Shoulder_r','UpperArm_l','UpperArm_r','Forearm_l','Forearm_r','Hand_l','Hand_r','Thigh_l','Thigh_r','Shin_l','Shin_r','Foot_l','Foot_r'}
        source=ROOT/'assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1_static.blend'
        with bpy.data.libraries.load(str(source),link=False) as (src,dst):
            dst.objects=[n for n in src.objects if n.removeprefix('Skeleton_Warrior_V1_') in labels]
        cache={}
        for obj in dst.objects:
            uv=obj.data.uv_layers.active.data
            cache[obj['part']]={'verts':[tuple(v.co) for v in obj.data.vertices],
                'faces':[tuple(p.vertices) for p in obj.data.polygons],
                'uvs':[v for p in obj.data.polygons for li in p.loop_indices for v in uv[li].uv]}
        assert len(cache)==len(labels)
        bpy.app.driver_namespace[key]=cache
    return cache

def painted_relic(name,label,verts,source,group='04_FOCUS'):
    obj=mesh(name+'_'+label,verts,source['faces'],'bone',group)
    obj['source_paint_atlas']=str(ROOT/'assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1_atlas.png')
    obj['source_paint_uvs']=source['uvs']
    obj['relic_reference']='skeleton_warrior_v1:'+label
    return obj

def skull(name,center,width):
    cache=anatomical_reference()
    vertices=cache['Skull']['verts']
    anchor=Vector(tuple((min(v[i] for v in vertices)+max(v[i] for v in vertices))/2 for i in range(3)))
    scale=width/(max(v[0] for v in vertices)-min(v[0] for v in vertices))
    for label in ('Skull','Jaw'):
        source=cache[label]
        painted_relic(name,label,[tuple(Vector(center)+(Vector(v)-anchor)*scale) for v in source['verts']],source)

def skeleton_effigy(name,x,y,bottom=.177,height=.40):
    cache=anatomical_reference()
    all_vertices=[v for source in cache.values() for v in source['verts']]
    z0,z1=min(v[2] for v in all_vertices),max(v[2] for v in all_vertices)
    scale=height/(z1-z0)
    for label,source in cache.items():
        painted_relic(name,label,[(x+v[0]*scale,y+v[1]*scale,bottom+(v[2]-z0)*scale) for v in source['verts']],source)

polygon_prism('Hex_Foundation',hexagon(.92),0,.035,'foundation','01_FOUNDATION')
polygon_prism('Hex_Rim',hexagon(.90),.035,.060,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Paving',hexagon(.85),.060,.077,'paving','01_FOUNDATION')

# Six landmark architectures follow below; every civilization uses the same
# school-specific layout with its established materials and distinct craft.
if SCHOOL=='sacred':
    # Cruciform cathedral: long central nave, lower transept, twin front towers.
    nave_top=hall('Cathedral_Nave',0,.09,.46,.94,.077,.78*HEIGHT,7,True,ornament=False)
    hall('Cathedral_Transept',0,.26,.98,.27,.077,.48*HEIGHT,5,False,ornament=False)
    for sign in (-1,1):
        tx,ty=sign*.385,-.205
        tower_top=hall('Cathedral_Bell_Tower_'+str(sign),tx,ty,.208,.245,.077,.99*HEIGHT,5)
        window('Cathedral_Bell_Window_'+str(sign),tx,ty-.1225,tower_top-.155,.095,.19)
        window('Cathedral_Tower_Lower_Window_'+str(sign),tx,ty-.1225,.50*HEIGHT,.067,.19)
        box('Cathedral_Tower_Buttress_'+str(sign),(tx+sign*.104,ty,.39),(.071,.16,.625),'cutstone','02_HALL')
        if CIV=='dwarf':
            box('Cathedral_Tower_Rune_'+str(sign),(tx,ty-.127,.70*HEIGHT),(.078,.015,.065),'bronze','08_DETAILS')
        elif CIV=='orc':
            tusk('Cathedral_Clan_Corner_'+str(sign),(tx+sign*.10,ty-.03,.701),.21,.058,.041,-sign,'08_DETAILS')
            box('Cathedral_Clan_Corner_Seat_'+str(sign),(tx+sign*.10,ty-.03,.705),(.069,.066,.044),'iron','08_DETAILS')
    front=.09-.94/2
    doorway('Cathedral_Main_Portal',0,front,.148,.265,.44*HEIGHT)
    solar_z=.777*HEIGHT
    box('Cathedral_Rose_Backplate',(0,front-.010,solar_z),(.224,.030,.224),'faction_dark','04_FOCUS')
    ring('Cathedral_Rose_Frame',(0,front-.022,solar_z),.106,.023,TRIM,'XZ','04_FOCUS',12)
    box('Cathedral_Rose_Vertical',(0,front-.030,solar_z),(.025,.024,.125),'magic','04_FOCUS')
    box('Cathedral_Rose_Horizontal',(0,front-.030,solar_z+.012),(.119,.024,.025),'magic','04_FOCUS')
    for sign in (-1,1):
        window('Cathedral_Aisle_Window_'+str(sign),sign*.346,.26-.135,.41*HEIGHT,.10,.20)
    # A row of glass panes on the long side, physically seated in their frames.
    for j in range(3):
        x,y,z=.231,-.09+j*.22,.51*HEIGHT
        pane=box('Cathedral_Side_Glass_'+str(j),(x,y,z),(.025,.115,.24),'glass','08_DETAILS')
        for sign in (-1,1):
            box('Cathedral_Side_Jamb_%s_%s'%(j,sign),(x+.009,y+sign*.0575,z),(.030,.017,.267),TRIM,'08_DETAILS')
            box('Cathedral_Side_Sill_%s_%s'%(j,sign),(x+.009,y,z+sign*.12),(.030,.13,.019),TRIM,'08_DETAILS')
        box('Cathedral_Side_Mullion_'+str(j),(x+.017,y,z),(.012,.009,.24),TRIM,'08_DETAILS')
    bowl('Cathedral_Consecrated_Font',-.53,-.41)
    standard(.61,.29)
    design='Catedral cruciforme monumental com nave longa, transepto, duas torres, vitrais e rosácea solar fixada na fachada.'

elif SCHOOL=='infernal':
    # Open profane court, five capped totems and a supported geometric portal.
    polygon_prism('Profane_Ritual_Dais',hexagon(.49,(0,.015)),.077,.145,'tombstone','05_COURTYARD')
    polygon_prism('Profane_Inner_Dais',hexagon(.31,(0,-.015)),.14,.201,'stone','05_COURTYARD')
    ring('Profane_Ground_Sigil',(0,.015,.145),.408,.020,'school','XY','06_TRAINING',12)
    for i,angle in enumerate((-30,30,90,150,210)):
        a=math.radians(angle)
        x,y=.55*math.cos(a),.015+.55*math.sin(a)
        h=(.48 if i%2==0 else .63)*HEIGHT
        hall('Profane_Totem_'+str(i),x,y,.14,.16,.077,h,3,craft=False)
        box('Profane_Totem_Sigil_'+str(i),(x,y-.084,.077+h*.58),(.048,.017,.095),'school','04_FOCUS')
        if CIV=='orc':
            box('Profane_Totem_Iron_Wrap_'+str(i),(x,y,.29),(.161,.181,.032),'iron','08_DETAILS')
        elif CIV=='dwarf':
            box('Profane_Totem_Copper_Rune_'+str(i),(x,y-.085,.219),(.088,.018,.045),'bronze','08_DETAILS')
        elif CIV=='elf':
            leaf('Profane_Totem_Binding_Leaf_'+str(i),(x,y-.089,.269),.076,.10,.030,'gold','08_DETAILS')
    gate_z=.82*HEIGHT
    for sign in (-1,1):
        x=sign*.271
        box('Profane_Gate_Foot_'+str(sign),(x,.24,.125),(.18,.18,.098),'cutstone','02_HALL')
        box('Profane_Gate_Post_'+str(sign),(x,.24,(.165+gate_z+.19)/2),(.083,.092,gate_z+.19-.165),POST,'02_HALL')
        box('Profane_Gate_Bearing_'+str(sign),(x,.24,gate_z),(.11,.10,.13),TRIM,'04_FOCUS')
        for j in range(2):
            box('Profane_Gate_Band_%s_%s'%(sign,j),(x,.24,.31+j*.31*HEIGHT),(.099,.109,.036),TRIM,'08_DETAILS')
    box('Profane_Gate_Lintel',(0,.24,gate_z+.215),(.65,.13,.055),TRIM,'02_HALL')
    ring('Profane_Portal_Rim',(0,.24,gate_z),.292,.031,TRIM,'XZ','04_FOCUS',12)
    crystal('Infernal_Rift_Core',(0,.24,gate_z),.20,.36,'fire')
    box('Profane_Altar_Stem',(0,-.115,.255),(.18,.18,.116),'tombstone','04_FOCUS')
    box('Profane_Altar_Brazier',(0,-.115,.333),(.30,.28,.053),TRIM,'04_FOCUS')
    for i,(dx,dy,h) in enumerate(((-.07,0,.20),(.047,.035,.29),(.025,-.065,.16))):
        crystal('Profane_Altar_Flame_'+str(i),(dx,-.115+dy,.355+h/2),.10,h,'fire')
    for i in range(3):
        box('Profane_Entry_Step_'+str(i),(0,-.38-i*.074,.132-i*.019),(.32+i*.04,.11,.069),'cutstone','05_COURTYARD')
    standard(.61,.22)
    design='Círculo ritual aberto com cinco totens, portal sustentado, sigilo no piso e altar de fogo em patamares.'

elif SCHOOL=='necromancy':
    # A broad dark crypt and a rising obelisk, with actual skeleton reliquaries.
    crypt_top=hall('Black_Mausoleum_Crypt',0,.055,.68,.59,.077,.57*HEIGHT,5,reg='tombstone',ornament=False)
    doorway('Black_Mausoleum_Portal',0,-.240,.148,.255,.36*HEIGHT)
    for sign in (-1,1):
        tx,ty=sign*.473,.105
        top=hall('Mausoleum_Reliquary_'+str(sign),tx,ty,.162,.242,.077,.79*HEIGHT,4,craft=False)
        for j in range(3):
            z=.275+j*.192*HEIGHT
            box('Mausoleum_Niche_%s_%s'%(sign,j),(tx,ty-.128,z),(.124,.024,.118),'shadow','04_FOCUS')
            box('Mausoleum_Niche_Shelf_%s_%s'%(sign,j),(tx,ty-.129,z-.060),(.15,.065,.022),POST,'04_FOCUS')
            skull('Mausoleum_Niche_Skull_%s_%s'%(sign,j),(tx,ty-.138,z+.001),.065)
    # Rear pillar rises through the crypt roof, mechanically seated at ground.
    box('Mausoleum_Obelisk_Foot',(0,.419,.164),(.32,.28,.174),'cutstone','02_HALL')
    box('Mausoleum_Obelisk',(0,.419,.89*HEIGHT),(.218,.218,1.42*HEIGHT),'tombstone','02_HALL')
    ob_top=.89*HEIGHT+1.42*HEIGHT/2
    for i in range(3):
        box('Mausoleum_Obelisk_Crown_'+str(i),(0,.419,ob_top+i*.047+.016),(.255-i*.065,.255-i*.065,.050),'roof','03_ROOFS')
    for sign in (-1,1):
        box('Mausoleum_Obelisk_Rune_'+str(sign),(sign*.059,.303,.96*HEIGHT),(.023,.024,.39*HEIGHT),'school','04_FOCUS')
    skull('Mausoleum_Skull_Crest',(0,-.263,.669*HEIGHT),.168)
    box('Mausoleum_Crest_Backing',(0,-.246,.650*HEIGHT),(.20,.042,.177),TRIM,'04_FOCUS')
    for sign in (-1,1):
        x,y=sign*.385,-.354
        box('Mausoleum_Effigy_Platform_'+str(sign),(x,y,.127),(.202,.193,.102),'cutstone','06_TRAINING')
        skeleton_effigy('Mausoleum_Ancestor_Effigy_'+str(sign),x,y,.175,.41)
        if CIV=='orc':
            box('Mausoleum_Effigy_Iron_Band_'+str(sign),(x,y,.152),(.214,.207,.024),'iron','06_TRAINING')
        elif CIV=='dwarf':
            box('Mausoleum_Effigy_Copper_Plaque_'+str(sign),(x,y-.100,.125),(.120,.022,.050),'bronze','06_TRAINING')
        elif CIV=='elf':
            leaf('Mausoleum_Memorial_Leaf_'+str(sign),(sign*.473,-.037,.719*HEIGHT),.13,.14,.025,'gold','04_FOCUS')
            beam('Mausoleum_Memorial_Leaf_Bracket_'+str(sign),(sign*.473,-.037,.69*HEIGHT),(sign*.473,.01,.69*HEIGHT),.026,'gold','04_FOCUS')
    polygon_prism('Mausoleum_Offering_Sarcophagus',[(-.09,-.665),(.09,-.665),(.13,-.59),(.10,-.395),(-.10,-.395),(-.13,-.59)],.078,.202,'tombstone','06_TRAINING')
    box('Mausoleum_Sarcophagus_Lid',(0,-.526,.215),(.205,.234,.038),'cutstone','06_TRAINING')
    box('Mausoleum_Sarcophagus_Seal',(0,-.526,.239),(.040,.185,.017),'school','06_TRAINING')
    for sign in (-1,1):
        beam('Mausoleum_Crest_Crossbone_'+str(sign),(-.125,-.277,.574*HEIGHT+sign*.030),(.125,-.277,.574*HEIGHT-sign*.030),.018,'bone','04_FOCUS')
    box('Mausoleum_Crossbone_Mount',(0,-.255,.574*HEIGHT),(.228,.055,.07),TRIM,'04_FOCUS')
    standard(.61,.31)
    design='Mausoléu de pedra escura com obelisco alto, relicários, seis caveiras, ossos cruzados e duas efígies completas do esqueleto aprovado.'

elif SCHOOL=='druidism':
    polygon_prism('Ancestral_Garden',hexagon(.79),.076,.085,'grass','05_COURTYARD')
    polygon_prism('Ancestral_Tree_Planter',hexagon(.28,(0,.13)),.081,.161,'stone','04_FOCUS')
    box('Ancestral_Tree_Root',(0,.13,.18),(.25,.25,.10),'timber','04_FOCUS')
    box('Ancestral_Tree_Trunk',(0,.13,.715),(.14,.16,1.11),'timber','04_FOCUS')
    for i,(dx,dy) in enumerate(((-.31,.08),(.33,.06),(-.14,.35),(.17,-.23))):
        end=(dx,.13+dy,.10)
        box('Ancestral_Root_Seat_'+str(i),(end[0],end[1],.10),(.10,.10,.042),'timber','04_FOCUS')
        beam('Ancestral_Exposed_Root_'+str(i),(0,.13,.31),end,.074,'timber','04_FOCUS')
        beam('Ancestral_Tree_Branch_'+str(i),(0,.13,.79),(dx,.13+dy,1.19),.067,'timber','04_FOCUS')
    canopy=[((0,.13,1.15),(.67,.58,.30)),((-.26,.13,1.28),(.39,.38,.27)),
            ((.29,.12,1.31),(.43,.40,.28)),((-.06,.22,1.47),(.57,.49,.31)),
            ((.09,.17,1.67),(.34,.33,.25))]
    for i,(center,size) in enumerate(canopy):
        box('Ancestral_Canopy_'+str(i),center,size,'foliage_light' if i==4 else 'foliage','04_FOCUS')
    for i in range(6):
        a=math.radians(-30+i*60)
        x,y=.60*math.cos(a),.02+.60*math.sin(a)
        h=.27 if CIV=='dwarf' else .33 if CIV=='orc' else .35 if CIV=='elf' else .29
        box('Ancestral_Marker_Foot_'+str(i),(x,y,.103),(.19,.18,.053),'stone','02_HALL')
        box('Ancestral_Marker_'+str(i),(x,y,.12+h/2),(.145,.13,h),'cutstone','02_HALL')
        box('Ancestral_Marker_Cap_'+str(i),(x,y,.12+h),(.17,.16,.030),TRIM,'03_ROOFS')
        box('Ancestral_Rune_'+str(i),(x,y-.065,.12+h*.54),(.025,.018,h*.39),'school','04_FOCUS')
        if CIV=='orc':
            box('Ancestral_Clan_Wrap_'+str(i),(x,y,.23),(.166,.149,.031),'iron','08_DETAILS')
            tusk('Ancestral_Totem_Fang_'+str(i),(x,y,.12+h+.015),.11,.047,.033,1,'08_DETAILS')
        elif CIV=='dwarf':
            box('Ancestral_Copper_Plaque_'+str(i),(x,y-.070,.18),(.095,.030,.042),'bronze','08_DETAILS')
        elif CIV=='elf':
            leaf('Ancestral_Marker_Leaf_'+str(i),(x,y,.12+h+.069),.087,.11,.025,'gold','08_DETAILS')
    if CIV=='dwarf':
        box('Ancestral_Granite_Root_Basin',(0,.13,.119),(.59,.48,.075),'stone','04_FOCUS')
        box('Ancestral_Basin_Copper_Band',(0,-.111,.126),(.51,.029,.045),'bronze','08_DETAILS')
    elif CIV=='elf':
        for sign in (-1,1):
            box('Ancestral_Carved_Branch_Foot_'+str(sign),(sign*.515,.02,.133),(.095,.091,.112),'timber','08_DETAILS')
            beam('Ancestral_Carved_Branch_'+str(sign),(sign*.515,.02,.16),(sign*.39,.16,.71),.038,'timber','08_DETAILS')
            beam('Ancestral_Woodland_Arch_'+str(sign),(sign*.39,.16,.71),(0,.18,.98),.038,'timber','08_DETAILS')
            for j in range(3):
                leaf('Ancestral_Trunk_Vine_%s_%s'%(sign,j),(sign*.054,.039,.40+j*.13),.078,.086,.027,'foliage_light','08_DETAILS')
    elif CIV=='human':
        for sign in (-1,1):
            box('Ancestral_Garden_Bench_Leg_'+str(sign),(.48,-.06+sign*.078,.135),(.046,.046,.116),'cutstone','06_TRAINING')
        box('Ancestral_Garden_Bench',(.48,-.06,.199),(.13,.235,.036),'timber','06_TRAINING')
    box('Ancestral_Offering_Foot',(0,-.40,.115),(.23,.22,.076),'cutstone','06_TRAINING')
    box('Ancestral_Offering_Table',(0,-.40,.195),(.20,.19,.100),POST,'06_TRAINING')
    box('Ancestral_Offering_Capital',(0,-.40,.251),(.24,.23,.030),TRIM,'06_TRAINING')
    crystal('Ancestral_Seed',(0,-.40,.322),.10,.12,'school')
    for sign in (-1,1):
        box('Ancestral_Herb_Planter_'+str(sign),(sign*.29,-.49,.105),(.15,.13,.055),POST,'06_TRAINING')
        box('Ancestral_Herb_Soil_'+str(sign),(sign*.29,-.49,.132),(.12,.10,.026),'grass','06_TRAINING')
        box('Ancestral_Herb_Sprout_'+str(sign),(sign*.29,-.49,.162),(.080,.072,.052),'foliage_light','06_TRAINING')
    standard(.65,.21)
    design='Bosque de uma árvore ancestral de copa ampla, raízes expostas, marcos baixos, oferenda viva e jardim ritual; o mobiliário e a talha seguem a civilização.'

elif SCHOOL=='arcanism':
    # Three squared setbacks and galleries distinguish this landmark from the school.
    hall('Veil_Lower_Tower',0,.11,.49,.47,.077,.54*HEIGHT,2,craft=True,ornament=False)
    hall('Veil_Middle_Tower',0,.11,.405,.389,.65*HEIGHT,.43*HEIGHT,2,craft=True,ornament=False)
    upper=hall('Veil_Upper_Tower',0,.11,.323,.312,1.10*HEIGHT,.37*HEIGHT,5,craft=True,ornament=False)
    top=upper+5*PITCH-.002
    doorway('Veil_Entrance',0,.11-.235,.148,.24,.40)
    window('Veil_Lower_Window',.172,.11-.235,.475,.075,.21)
    window('Veil_Middle_Window',0,.11-.1945,.865*HEIGHT,.13,.23)
    window('Veil_Upper_Window',0,.11-.156,1.31*HEIGHT,.102,.17)
    for level,(width,z) in enumerate(((.60,.655*HEIGHT),(.50,1.105*HEIGHT))):
        box('Veil_Gallery_'+str(level),(0,.11,z),(width,width*.92,.040),'cutstone','03_ROOFS')
        for sign in (-1,1):
            beam('Veil_Gallery_Bracket_%s_%s'%(level,sign),(sign*(width/2-.09),.11,z-.113),
                 (sign*(width/2-.015),.11,z-.012),.032,TRIM,'08_DETAILS')
    core_z=top+.23
    ring('Veil_Crown_Rim',(0,.11,core_z),.174,.023,TRIM,'XZ','04_FOCUS',12)
    for sign in (-1,1):
        beam('Veil_Crown_Roof_Anchor_'+str(sign),(sign*.070,.11,top-.020),(sign*.168,.11,top+.022),.028,TRIM,'04_FOCUS')
        beam('Veil_Crown_Fork_'+str(sign),(sign*.168,.11,top+.015),(sign*.168,.11,core_z),.024,TRIM,'04_FOCUS')
        if CIV=='elf':
            leaf('Veil_Crown_Leaf_'+str(sign),(sign*.168,.11,core_z-.067),.077,.103,.026,'gold','04_FOCUS')
        elif CIV=='dwarf':
            box('Veil_Crown_Bearing_'+str(sign),(sign*.168,.094,top+.05),(.065,.037,.067),'bronze','04_FOCUS')
    crystal('Veil_Core',(0,.11,core_z),.147,.245,'magic')
    # Stair blocks are filled down to the pavement, never suspended steps.
    for i in range(7):
        height=.085+i*.077
        box('Veil_External_Stair_'+str(i),(.344,-.15+i*.066,.077+height/2),(.172,.083,height),'cutstone','05_COURTYARD')
    box('Veil_Stair_Landing',(.269,.287,.644),(.23,.16,.044),'cutstone','05_COURTYARD')
    for sign in (-1,1):
        box('Veil_Archive_Pedestal_'+str(sign),(sign*.33,-.335,.113),(.16,.15,.072),'cutstone','06_TRAINING')
        box('Veil_Archive_Stela_'+str(sign),(sign*.33,-.335,.285),(.102,.086,.278),POST,'06_TRAINING')
        box('Veil_Archive_Rune_'+str(sign),(sign*.33,-.381,.29),(.039,.015,.159),'school','06_TRAINING')
        box('Veil_Archive_Cap_'+str(sign),(sign*.33,-.335,.439),(.14,.126,.038),TRIM,'06_TRAINING')
    standard(.62,.29)
    design='Torre alta de três corpos recuados, galerias sustentadas, escadaria exterior e coroa com núcleo do Véu em levitação intencional.'

elif SCHOOL=='elementalism':
    polygon_prism('Nexus_Ritual_Base',hexagon(.38,(0,.06)),.077,.162,'stone','05_COURTYARD')
    polygon_prism('Nexus_Central_Platform',hexagon(.31,(0,.06)),.16,.24,'cutstone','04_FOCUS')
    box('Nexus_Core_Stand',(0,.06,.547),(.173,.173,.62),POST,'04_FOCUS')
    box('Nexus_Core_Axis',(0,.06,.85),(.245,.083,.057),TRIM,'04_FOCUS')
    focus_z=1.13
    for plane,radius in (('XY',.323),('XZ',.313),('YZ',.291)):
        ring('Nexus_Armillary_'+plane,(0,.06,focus_z),radius,.028,TRIM,plane,'04_FOCUS',12)
    for sign in (-1,1):
        box('Nexus_Crown_Foot_'+str(sign),(sign*.274,.06,.237),(.075,.079,.054),TRIM,'04_FOCUS')
        beam('Nexus_Crown_Support_'+str(sign),(sign*.274,.06,.235),(sign*.274,.06,focus_z),.030,TRIM,'04_FOCUS')
        box('Nexus_Crown_Bearing_'+str(sign),(sign*.274,.06,focus_z),(.070,.069,.070),TRIM,'04_FOCUS')
        if CIV=='dwarf':
            ring('Nexus_Copper_Gear_'+str(sign),(sign*.274,.019,.93),.053,.018,'bronze','XZ','04_FOCUS',8)
            box('Nexus_Copper_Gear_Axle_'+str(sign),(sign*.274,.035,.93),(.031,.067,.031),'bronze','04_FOCUS')
            box('Nexus_Copper_Gear_Spoke_X_'+str(sign),(sign*.274,.019,.93),(.112,.021,.018),'bronze','04_FOCUS')
            box('Nexus_Copper_Gear_Spoke_Z_'+str(sign),(sign*.274,.019,.93),(.018,.021,.112),'bronze','04_FOCUS')
        elif CIV=='elf':
            leaf('Nexus_Living_Fork_'+str(sign),(sign*.274,.06,1.015),.104,.14,.034,'gold','04_FOCUS')
    crystal('Primordial_Core',(0,.06,focus_z),.207,.285,'magic')
    for i,(x,y,element,h) in enumerate(((-.43,-.29,'fire',.62),(.43,-.29,'water',.56),(-.43,.39,'earth',.45),(.43,.39,'air',.69))):
        z1=hall('Nexus_'+element+'_Tower',x,y,.135,.15,.077,h*HEIGHT,3,craft=False,ornament=False)
        cap_z=z1+3*PITCH-.002
        box('Nexus_'+element+'_Gem_Seat',(x,y,cap_z+.016),(.11,.106,.035),TRIM,'04_FOCUS')
        crystal('Nexus_'+element+'_Gem',(x,y,cap_z+.113),.116,.165,element)
        box('Nexus_'+element+'_Glyph',(x,y-.077,.24),(.045,.024,.128),element,'04_FOCUS')
        # Floor channels are inset; physical conduits meet both towers and stand.
        beam('Nexus_'+element+'_Floor_Channel',(x,y,.079),(0,.06,.079),.024,element,'06_TRAINING')
        beam('Nexus_'+element+'_Conduit',(x,y,.49),(0,.06,.49),.037,TRIM,'04_FOCUS')
        box('Nexus_'+element+'_Conduit_Collar',(x,y,.49),(.157,.171,.047),TRIM,'04_FOCUS')
        if CIV=='orc':
            box('Nexus_'+element+'_Iron_Strap',(x,y,.255),(.151,.166,.031),'iron','08_DETAILS')
            tusk('Nexus_'+element+'_Trophy',(x+.051,y,.149),.23,.044,.031,1,'08_DETAILS')
            box('Nexus_'+element+'_Trophy_Socket',(x+.051,y,.146),(.055,.058,.035),'iron','08_DETAILS')
        elif CIV=='dwarf':
            box('Nexus_'+element+'_Copper_Engraving',(x,y-.080,.38),(.083,.025,.068),'bronze','08_DETAILS')
        elif CIV=='elf':
            leaf('Nexus_'+element+'_Leaf',(x,y-.091,.365),.077,.115,.034,'gold','08_DETAILS')
    standard(.64,.075)
    design='Nexus de quatro torres elementais com telhados da civilização, canais no piso, condutos sustentados e grande armilar central com núcleo primordial.'

root=bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id']='v2_building_'+STEM
root['civilization'],root['asset_only']=CIV,True
for obj in parts:
    obj.parent=root
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
            for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum<=math.sqrt(3)/2-.030,(NAME,maximum)
studio_code=(PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene.render.resolution_x=scene.render.resolution_y=800
scene.cycles.samples=16
scene['preview_target']=[0,0,.79]
scene['door_clearance']=[.26,.40]
scene['asset_basename'],scene['density'],scene['paint_world_scale']=FOLDER,128,7
scene['asset_output_relative']=OUT.relative_to(ROOT).as_posix()
scene['display_name']=DISPLAY+' — '+{'human':'Humanos','orc':'Orcs','dwarf':'Anões','elf':'Elfos'}[CIV]
scene['civilization'],scene['magic_school'],scene['grand_magic'],scene['asset_only']=CIV,SCHOOL,True,True
scene['trains'],scene['excludes']=['v2_manifestation_'+MANIFESTATION],[]
scene['requires_building']='v2_building_'+PREVIOUS
scene['palette_overrides']=palette
scene['material_reference']=reference_scene['asset_output_relative']
scene['scale_note']='Native 4X map units, pointy-top hex tile radius 1; foundation .92, placement scale 1.'
scene['race_details']={'human':'Alvenaria formal, pilastras, vitrais e madeira com ferragens douradas.',
    'orc':'Madeira pesada, ferro escuro, rebites, travamentos de clã e presas.',
    'dwarf':'Granito, pilares quadrados, cobre gravado e mecanismos.',
    'elf':'Pedra marfim, madeira fina, galhos entalhados, folhas e telhados verdes mais altos.'}[CIV]
scene['design_note']=design+' '+scene['race_details']
bpy.app.driver_namespace['guardian_hall']={'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':list(scene['door_clearance']),'scale_note':scene['scale_note'],'design_note':scene['design_note']}
# Physical adornments must be attached before painting/exporting the new asset.
audit_scope={'AUDIT_RUN':False}
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'),audit_scope)
floating_magic={'Infernal_Rift_Core','Veil_Core','Primordial_Core'}
unattached=[o['part'] for o in audit_scope['detached'](parts) if o['part'] not in floating_magic]
scene['physical_attachment_remaining']=unattached
scene['intentional_levitation']=[o['part'] for o in parts if o['part'] in floating_magic]
assert not unattached,(NAME,unattached)
result={'asset':FOLDER,'parts':len(parts),'max_half_plane':maximum,'physical_attachment_remaining':unattached,
        'roof_rgb':palette['roof'],'material_reference':scene['material_reference']}
