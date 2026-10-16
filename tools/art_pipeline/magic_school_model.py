"""Original magic-school architecture. Execute inside live Blender MCP.

Caller supplies MAGIC_CIV and MAGIC_SCHOOL; every asset has its own scene.
Only shared geometric primitives and the established studio are reused.
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
    'sacred': ('sacred_temple', 'Templo Sagrado', 'sacred_cleric', 'sacred_ritual'),
    'infernal': ('infernal_sanctum', 'Santuário Infernal', 'infernal_warlock', 'infernal_ritual'),
    'necromancy': ('necromancy_ossuary', 'Ossuário', 'necromancer', 'necromancy_ritual'),
    'druidism': ('druidic_circle', 'Círculo Druídico', 'druid', 'druidic_ritual'),
    'arcanism': ('arcane_conclave', 'Conclave Arcano', 'arcanist', 'arcane_ritual'),
    'elementalism': ('elemental_observatory', 'Observatório Elemental', 'elementalist', 'elemental_ritual'),
}
STEM, DISPLAY, UNIT, RITUAL = RECIPES[MAGIC_SCHOOL]
PLURAL = {'human':'humans','orc':'orcs','dwarf':'dwarves','elf':'elves'}[MAGIC_CIV]
PREFIX = '' if MAGIC_CIV == 'human' else MAGIC_CIV + '_'
FOLDER = PREFIX + STEM + '_hex_v1'
NAME = FOLDER.title()
ASSET_NAME, ASSET_FOLDER = NAME, FOLDER
OUT = ROOT / 'assets/generated' / PLURAL / 'buildings' / FOLDER
if NAME in bpy.data.scenes or (OUT / (FOLDER + '.blend')).exists():
    raise RuntimeError('Existing magic asset preserved: ' + FOLDER)
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_FOCUS','05_COURTYARD',
              '06_TRAINING','07_FACTION','08_DETAILS','09_STUDIO'):
    col = bpy.data.collections.new(NAME + '_' + label)
    scene.collection.children.link(col)
    groups[label] = col
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename, names in (
    ('warrior_hall_hex_v1_model.py', ('mesh','box','polygon_prism','hexagon')),
    ('war_stable_hex_v1_model.py', ('vertical_prism',)),
    ('orc_city_level_1_hex_v1_model.py', ('tusk',)),
    ('elf_city_level_1_hex_v1_model.py', ('leaf',)),
):
    for node in ast.parse((PIPELINE / filename).read_text(encoding='utf-8')).body:
        if isinstance(node, ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node], type_ignores=[]), '<magic_primitives>', 'exec'))

TRIM = {'human':'gold','orc':'iron','dwarf':'bronze','elf':'gold'}[MAGIC_CIV]
BODY = {'human':'plaster','orc':'door','dwarf':'stone','elf':'plaster'}[MAGIC_CIV]
POST = 'cutstone' if MAGIC_CIV == 'dwarf' else 'timber'
PITCH = {'human':.052,'orc':.043,'dwarf':.040,'elf':.064}[MAGIC_CIV]
POST_WIDTH = {'human':.043,'orc':.080,'dwarf':.086,'elf':.031}[MAGIC_CIV]
COLORS = {
    'sacred':(244,218,135), 'infernal':(244,119,78), 'necromancy':(189,134,230),
    'druidism':(116,216,148), 'arcanism':(134,185,252), 'elementalism':(133,232,236),
}
palette = {'gold':[206,181,112], 'bronze':[191,133,71], 'bone':[225,215,174],
    'foliage':[57,112,64], 'foliage_light':[99,151,74], 'grass':[108,139,82],
    'water':[73,157,183], 'glass':list(COLORS[MAGIC_SCHOOL]),
    'school':list(COLORS[MAGIC_SCHOOL]), 'magic':list(COLORS[MAGIC_SCHOOL]),
    'fire':[247,122,48], 'air':[193,224,233], 'earth':[146,185,102],
    'ink':[70,54,82], 'paper':[220,207,161]}
if MAGIC_CIV == 'human':
    palette.update({'faction':[52,83,145]})
elif MAGIC_CIV == 'orc':
    palette.update({'stone':[91,101,98], 'cutstone':[145,141,121], 'foundation':[68,77,77],
        'paving':[107,113,88], 'timber':[78,53,35], 'door':[123,89,54],
        'roof':[130,58,39], 'roof_dark':[83,40,30], 'iron':[53,65,65],
        'iron_light':[126,137,130], 'faction':[170,60,39]})
elif MAGIC_CIV == 'dwarf':
    palette.update({'foundation':[78,87,91], 'stone':[117,124,123], 'cutstone':[175,172,152],
        'paving':[122,130,126], 'timber':[101,75,43], 'door':[130,96,54], 'plaster':[155,163,153],
        'roof':[67,82,89], 'roof_dark':[43,59,64], 'iron':[48,62,67],
        'iron_light':[151,162,160], 'faction':[69,109,153]})
else:
    palette.update({'foundation':[110,128,116], 'stone':[137,158,131], 'cutstone':[209,215,183],
        'paving':[127,146,109], 'plaster':[222,222,192], 'timber':[113,91,55],
        'door':[158,127,76], 'roof':[48,122,88], 'roof_dark':[30,81,66],
        'iron':[60,84,73], 'iron_light':[192,206,180], 'faction':[91,167,143]})


def beam(name, a, b, width, reg=TRIM, group='08_DETAILS'):
    a, b = Vector(a), Vector(b)
    direction = (b-a).normalized()
    ref = Vector((0,0,1)) if abs(direction.z) < .9 else Vector((0,1,0))
    u = direction.cross(ref).normalized() * width/2
    v = direction.cross(u).normalized() * width/2
    verts = [tuple(p + sx*u + sy*v) for p in (a,b) for sy in (-1,1) for sx in (-1,1)]
    return mesh(name, verts, CUBE, reg, group)


def crystal(name, center, width, height, reg='magic', group='04_FOCUS'):
    x,y,z = center
    verts = [(x,y,z-height/2)]
    for dz in (-height*.22,height*.16):
        verts += [(x+width*.5*math.cos(i*math.pi/2+math.pi/4),
                   y+width*.5*math.sin(i*math.pi/2+math.pi/4),z+dz) for i in range(4)]
    verts.append((x,y,z+height/2))
    faces = [(0,(i+1)%4+1,i+1) for i in range(4)]
    faces += [(i+1,(i+1)%4+1,(i+1)%4+5,i+5) for i in range(4)]
    faces += [(i+5,(i+1)%4+5,9) for i in range(4)]
    return mesh(name, verts, faces, reg, group)


def ring(name, center, radius, thickness, reg=TRIM, plane='XY', group='04_FOCUS', count=12):
    c = Vector(center)
    def point(t):
        a,b = radius*math.cos(t),radius*math.sin(t)
        return c + Vector((a,b,0) if plane=='XY' else (a,0,b) if plane=='XZ' else (0,a,b))
    for i in range(count):
        beam(name+'_%02d'%i, point(2*math.pi*i/count), point(2*math.pi*(i+1)/count), thickness, reg, group)


def roof(name, x, y, width, depth, bottom, steps=6, kind='hip'):
    for j in range(steps):
        w = width*(1-j*.125)
        d = depth*(1-j*.13) if kind=='hip' else depth
        box(name+'_Course_%02d'%j,(x,y,bottom+(j+.5)*PITCH),(w,d,PITCH),'roof','03_ROOFS')
        if j in (0,steps-1) or MAGIC_CIV=='dwarf' and j==3:
            box(name+'_Trim_%02d'%j,(x,y-d/2-.003,bottom+j*PITCH+.009),(w+.010,.018,.018),TRIM,'03_ROOFS')
    top = bottom+steps*PITCH
    box(name+'_Ridge',(x,y,top+.012),(max(.07,width*(1-(steps-1)*.125)),.068,.024),'roof_dark','03_ROOFS')
    if MAGIC_CIV=='orc':
        for sign in (-1,1):
            horn_y = y+sign*(d*.30 if kind=='hip' else depth*.33)
            box(name+'_Tusk_Socket_'+str(sign),(x,horn_y,top+.012),(.075,.066,.024),'iron','03_ROOFS')
            tusk(name+'_Roof_Tusk_'+str(sign),(x,horn_y,top+.023),.135,.054,.038,sign)
    elif MAGIC_CIV=='elf':
        leaf(name+'_Leaf',(x,y,top+.096),.11,.145,.023)
    elif MAGIC_CIV=='dwarf':
        box(name+'_Copper_Cap',(x,y,top+.042),(.12,.11,.045),'bronze','03_ROOFS')
    return top


def hall(name, x, y, w, d, bottom, height, roof_kind='hip'):
    box(name+'_Foot',(x,y,bottom+.042),(w+.025,d+.025,.084),'cutstone','02_HALL')
    box(name+'_Body',(x,y,bottom+.084+height/2),(w,d,height),BODY,'02_HALL')
    for sign in (-1,1):
        for rear in (-1,1):
            px,py = x+sign*(w/2-.009),y+rear*(d/2-.009)
            box(name+'_Post_%s_%s'%(sign,rear),(px,py,bottom+.084+height/2),(POST_WIDTH,POST_WIDTH,height+.014),POST,'02_HALL')
            box(name+'_Capital_%s_%s'%(sign,rear),(px,py,bottom+.075+height),
                (POST_WIDTH+.025,POST_WIDTH+.025,.047),TRIM,'08_DETAILS')
    return roof(name,x,y,w+.13,d+.12,bottom+.084+height,kind=roof_kind)


def doorway(name, x, front, bottom=.17, width=.23, height=.35):
    box(name+'_Dark_Recess',(x,front-.010,bottom+height/2),(width+.035,.025,height+.035),'shadow','02_HALL')
    for sign in (-1,1):
        box(name+'_Door_'+str(sign),(x+sign*width*.25,front-.028,bottom+height*.43),
            (width*.47,.026,height*.86),'door','02_HALL')
        box(name+'_Jamb_'+str(sign),(x+sign*(width/2+.035),front-.045,bottom+height*.48),
            (.05,.069,height+.034),'cutstone','02_HALL')
        box(name+'_Hinge_'+str(sign),(x+sign*width*.34,front-.048,bottom+height*.43),(.016,.013,height*.56),TRIM,'08_DETAILS')
        if MAGIC_CIV=='elf':
            for j in range(3):
                box(name+'_Point_%s_%s'%(sign,j),(x+sign*(width*.43-j*width*.15),front-.043,bottom+height+.024+j*.026),
                    (width*.21,.065,.032),'cutstone','02_HALL')
        elif MAGIC_CIV=='orc':
            tusk(name+'_Entry_Tusk_'+str(sign),(x+sign*(width/2+.058),front-.09,bottom),height*.90,.065,.051,-sign)
    box(name+'_Lintel',(x,front-.045,bottom+height+.017),(width+.12,.074,.048),TRIM,'02_HALL')
    for j in range(3):
        box(name+'_Step_%d'%j,(x,front-.072-j*.057,.15-j*.023),
            (width+.12+j*.035,.088,.046),'cutstone','05_COURTYARD')


def window(name, x, y, z, w=.105, h=.17, side=False):
    dims = (.022,w,h) if side else (w,.022,h)
    box(name+'_Glass',(x,y,z),dims,'glass','08_DETAILS')
    for dz in (-h/2,h/2):
        box(name+'_Sill_'+str(dz),(x,y,z+dz),(.040,w+.032,.023) if side else (w+.032,.04,.023),TRIM,'08_DETAILS')
    box(name+'_Mullion',(x+.014 if side else x,y if side else y-.014,z),(.012,.012,h),TRIM,'08_DETAILS')


def lectern(name, x, y, z=.09, reg='school'):
    box(name+'_Foot',(x,y,z+.024),(.135,.125,.048),'cutstone','06_TRAINING')
    box(name+'_Stem',(x,y,z+.125),(.047,.051,.18),POST,'06_TRAINING')
    box(name+'_Top',(x,y,z+.223),(.18,.15,.029),TRIM,'06_TRAINING')
    box(name+'_Open_Book',(x,y-.014,z+.246),(.132,.105,.019),'paper','06_TRAINING')
    box(name+'_Book_Spine',(x,y-.014,z+.258),(.014,.10,.009),reg,'06_TRAINING')
    for sign in (-1,1):
        for j in range(3):
            box(name+'_Text_%s_%s'%(sign,j),(x+sign*.036,y-.047+j*.021,z+.258),(.040,.007,.008),'ink','06_TRAINING')


def pedestal(name, x, y, height=.28, focus='magic', size=.14):
    box(name+'_Foot',(x,y,.112),(size+.07,size+.07,.070),'cutstone','04_FOCUS')
    box(name+'_Column',(x,y,.15+height/2),(size*.65,size*.65,height),POST,'04_FOCUS')
    box(name+'_Capital',(x,y,.15+height),(size+.025,size+.025,.037),TRIM,'04_FOCUS')
    crystal(name+'_Crystal',(x,y,.21+height),size,.16,focus)


def tree(name, x, y, h=.90, w=.35):
    box(name+'_Root',(x,y,.123),(.15,.15,.09),'timber','04_FOCUS')
    box(name+'_Trunk',(x,y,.09+h*.37),(.066,.07,h*.74),'timber','04_FOCUS')
    for sign in (-1,1):
        beam(name+'_Branch_'+str(sign),(x,y,.09+h*.40),(x+sign*w*.30,y,.09+h*.72),.042,'timber','04_FOCUS')
    for j,(f,scale) in enumerate(((.64,1),(.82,.82),(.96,.48))):
        box(name+'_Canopy_%d'%j,(x,y,.09+h*f),(w*scale,w*scale*.83,h*.18),
            'foliage_light' if j==2 else 'foliage','04_FOCUS')


def skull(name, x, y, z, s=.14):
    box(name+'_Cranium',(x,y,z),(s,.045,s*.72),'bone','04_FOCUS')
    for sign in (-1,1):
        box(name+'_Eye_'+str(sign),(x+sign*s*.24,y-.028,z+s*.09),(s*.22,.018,s*.23),'shadow','04_FOCUS')
    box(name+'_Nose',(x,y-.029,z-s*.15),(s*.14,.020,s*.14),'shadow','04_FOCUS')
    box(name+'_Jaw',(x,y,z-s*.43),(s*.70,.040,s*.20),'bone','04_FOCUS')
    for dx in (-.20,0,.20):
        box(name+'_Tooth_'+str(dx),(x+dx*s,y-.025,z-s*.44),(s*.05,.016,s*.18),'shadow','04_FOCUS')


polygon_prism('Hex_Foundation',hexagon(.92),0,.035,'foundation','01_FOUNDATION')
polygon_prism('Hex_Rim',hexagon(.90),.035,.060,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Paving',hexagon(.85),.060,.077,'paving','01_FOUNDATION')
polygon_prism('Entry_Path',[(0,-.82),(.105,-.65),(.09,-.28),(-.09,-.28),(-.105,-.65)],
              .077,.084,'cutstone','05_COURTYARD')

if MAGIC_SCHOOL == 'sacred':
    top = hall('Chapel',.045,.15,.55,.62,.077,.49,'gable')
    doorway('Chapel_Entry',.045,-.16)
    # Separate bell tower, open upper stage and golden solar crest.
    tx,ty = -.48,.145
    box('Bell_Tower_Foot',(tx,ty,.14),(.24,.25,.126),'cutstone','02_HALL')
    box('Bell_Tower_Shaft',(tx,ty,.47),(.19,.20,.54),BODY,'02_HALL')
    for dx in (-.083,.083):
        for dy in (-.084,.084):
            box('Bell_Stage_Post_%s_%s'%(dx,dy),(tx+dx,ty+dy,.86),(.034,.034,.24),POST,'02_HALL')
    box('Bell',(tx,ty,.86),(.082,.082,.104),'gold','04_FOCUS')
    box('Bell_Lip',(tx,ty,.805),(.113,.11,.025),'gold','04_FOCUS')
    roof('Bell_Crown',tx,ty,.29,.30,.982,4)
    window('Chapel_Front',.19,-.177,.54,.073,.155)
    window('Chapel_Right',.335,.20,.48,.15,.23,True)
    ring('Solar_Halo',(.045,-.241,.76),.094,.021,'gold','XZ')
    box('Solar_Cross_Vertical',(.045,-.261,.76),(.029,.028,.135),'magic','04_FOCUS')
    box('Solar_Cross_Horizontal',(.045,-.261,.771),(.113,.028,.029),'magic','04_FOCUS')
    lectern('Cleric_Scripture',.365,-.345)
    box('Healing_Font_Foot',(-.32,-.40,.112),(.22,.22,.07),'cutstone','06_TRAINING')
    box('Healing_Font_Stem',(-.32,-.40,.205),(.11,.11,.12),'cutstone','06_TRAINING')
    box('Healing_Font_Basin',(-.32,-.40,.283),(.23,.23,.047),TRIM,'06_TRAINING')
    box('Healing_Font_Water',(-.32,-.40,.310),(.17,.17,.012),'water','06_TRAINING')
    design = 'Chapel with stepped gable, open bell tower, golden solar halo, scripture lectern and healing font.'
elif MAGIC_SCHOOL == 'infernal':
    hall('Sanctum',0,.22,.68,.49,.077,.40)
    doorway('Sanctum_Entry',0,-.026,height=.29)
    for sign in (-1,1):
        box('Obsidian_Buttress_'+str(sign),(sign*.44,.08,.46),(.16,.21,.69),'stone','02_HALL')
        box('Buttress_Collar_'+str(sign),(sign*.44,.08,.811),(.19,.24,.040),TRIM,'03_ROOFS')
        tusk('Infernal_Horn_'+str(sign),(sign*.44,.08,.832),.25,.14,.09,-sign,'04_FOCUS')
        window('Sanctum_Glass_'+str(sign),sign*.225,-.043,.42,.084,.155)
    polygon_prism('Flame_Dais',hexagon(.26,(0,-.405)),.084,.136,'stone','05_COURTYARD')
    ring('Flame_Dais_Runes',(0,-.405,.147),.206,.018,'school','XY','06_TRAINING',6)
    box('Brazier_Stand',(0,-.405,.235),(.11,.11,.19),TRIM,'04_FOCUS')
    box('Brazier_Bowl',(0,-.405,.345),(.22,.21,.045),'iron','04_FOCUS')
    for i,(dx,dy,h) in enumerate(((-.047,0,.13),(.041,.01,.20),(0,-.046,.11))):
        crystal('Infernal_Flame_%d'%i,(dx,-.405+dy,.36+h/2),.065,h,'fire')
    ring('Infernal_Sigil',(0,-.079,.657),.103,.019,TRIM,'XZ')
    crystal('Infernal_Sigil_Core',(0,-.107,.657),.082,.14)
    lectern('Warlock_Grimoire',-.42,-.31)
    pedestal('Cinder_Training_Focus',.42,-.30,.15,'fire',.09)
    design = 'Broad sanctum, paired horned basalt buttresses, orange windows, sigil and raised training brazier.'
elif MAGIC_SCHOOL == 'necromancy':
    box('Crypt_Foot',(0,.21,.133),(.69,.51,.11),'cutstone','02_HALL')
    box('Crypt_Chamber',(0,.21,.413),(.61,.46,.45),'stone','02_HALL')
    doorway('Crypt_Entry',0,-.03,height=.30)
    # A low stone terraced tomb rather than a colored civilian roof.
    for j in range(4):
        box('Mausoleum_Terrace_%d'%j,(0,.21,.667+j*.054),(.75-j*.15,.59-j*.105,.055),'cutstone','03_ROOFS')
        box('Tomb_Dark_Edge_%d'%j,(0,-.091+j*.052,.660+j*.054),(.73-j*.15,.018,.020),TRIM,'03_ROOFS')
    skull('Crypt_Skull_Crest',0,-.077,.61,.17)
    for sign in (-1,1):
        x = sign*.445
        box('Ossuary_Niche_Tower_'+str(sign),(x,.16,.37),(.18,.26,.58),BODY,'02_HALL')
        roof('Niche_Cap_'+str(sign),x,.16,.22,.30,.68,3)
        for j in range(3):
            box('Bone_Niche_%s_%s'%(sign,j),(x,.018,.23+j*.145),(.13,.026,.102),'shadow','04_FOCUS')
            skull('Niche_Skull_%s_%s'%(sign,j),x,-.004,.245+j*.145,.056)
            box('Stored_Bones_%s_%s'%(sign,j),(x,-.006,.203+j*.145),(.089,.013,.012),'bone','04_FOCUS')
    coffin = [(-.086,-.61),(.086,-.61),(.12,-.53),(.09,-.32),(-.09,-.32),(-.12,-.53)]
    polygon_prism('Practice_Sarcophagus',coffin,.09,.232,'stone','06_TRAINING')
    polygon_prism('Sarcophagus_Lid',[(x*1.06,(y+.46)*1.04-.46) for x,y in coffin],.232,.268,'cutstone','06_TRAINING')
    box('Sarcophagus_Seal',(0,-.46,.279),(.042,.165,.016),'school','06_TRAINING')
    pedestal('Soul_Lantern',.36,-.365,.25,'magic',.08)
    lectern('Necromancer_Grimoire',-.36,-.335)
    window('Crypt_Rear_Window',.317,.31,.45,.11,.15,True)
    design = 'Terraced stone mausoleum, skull crest, stacked bone niches, sealed practice sarcophagus and violet soul lantern.'
elif MAGIC_SCHOOL == 'druidism':
    polygon_prism('Living_Garden',hexagon(.73),.078,.087,'grass','05_COURTYARD')
    polygon_prism('Circle_Paving',hexagon(.45,(0,-.08)),.087,.108,'stone','05_COURTYARD')
    ring('Verdant_Training_Ring',(0,-.08,.117),.345,.022,'school','XY','06_TRAINING')
    for i in range(6):
        a = math.radians(30+i*60)
        x,y = .50*math.cos(a),-.025+.50*math.sin(a)
        h = .50 if MAGIC_CIV=='dwarf' else .57 if MAGIC_CIV=='orc' else .65 if MAGIC_CIV=='elf' else .54
        w = .13 if MAGIC_CIV=='elf' else .18
        box('Standing_Stone_%d'%i,(x,y,.11+h/2),(w,.13,h),'cutstone','02_HALL',a)
        box('Standing_Stone_Cap_%d'%i,(x,y,.12+h),(w+.022,.15,.043),TRIM,'03_ROOFS',a)
        # Rune inset sits on the visible front of each stone.
        box('Stone_Rune_Vertical_%d'%i,(x,y-.079,.17+h*.45),(.018,.012,h*.34),'school','04_FOCUS')
        box('Stone_Rune_Cross_%d'%i,(x,y-.079,.20+h*.45),(.067,.013,.018),'school','04_FOCUS')
        if MAGIC_CIV=='orc':
            tusk('Grove_Totem_Tusk_%d'%i,(x,y,.14+h),.13,.05,.03,1)
        elif MAGIC_CIV=='elf':
            leaf('Grove_Leaf_%d'%i,(x,y,.19+h),.085,.12,.016)
    tree('Sacred_Grove_Tree',-.31,.46,1.04 if MAGIC_CIV=='elf' else .91,.32)
    box('Druid_Altar_Foot',(0,-.045,.148),(.19,.18,.08),'cutstone','04_FOCUS')
    box('Druid_Altar',(0,-.045,.244),(.12,.12,.13),POST,'04_FOCUS')
    crystal('Verdant_Seed',(0,-.045,.371),.11,.16)
    lectern('Druid_Herbarium',-.27,-.365)
    for i,(x,y) in enumerate(((.28,-.345),(-.60,.17),(.58,.18))):
        box('Herb_Bed_%d'%i,(x,y,.128),(.12,.10,.065),'timber','08_DETAILS')
        for j in range(2):
            box('Herb_%s_%s'%(i,j),(x-.025+j*.048,y,.182),(.041,.038,.062),'foliage_light','08_DETAILS')
    design = 'Open six-stone teaching circle, glowing verdant runes, central seed altar, block-canopy grove tree and herbarium.'
elif MAGIC_SCHOOL == 'arcanism':
    cx,cy = -.10,.145
    polygon_prism('Conclave_Foot',hexagon(.35,(cx,cy)),.077,.164,'cutstone','02_HALL')
    polygon_prism('Conclave_Hex_Tower',hexagon(.315,(cx,cy)),.164,.836,BODY,'02_HALL')
    for i,(x,y) in enumerate(hexagon(.321,(cx,cy))):
        box('Arcane_Tower_Post_%d'%i,(x,y,.50),(POST_WIDTH,POST_WIDTH,.704),POST,'02_HALL')
        box('Arcane_Tower_Capital_%d'%i,(x,y,.835),(POST_WIDTH+.03,POST_WIDTH+.03,.05),TRIM,'08_DETAILS')
    for j in range(6):
        polygon_prism('Conclave_Hex_Roof_%d'%j,hexagon(.405-j*.057,(cx,cy)),
                      .858+j*PITCH,.858+(j+1)*PITCH,'roof','03_ROOFS')
    focus_z = .858+6*PITCH+.18
    crystal('Floating_Arcane_Prism',(cx,cy,focus_z),.16,.23)
    ring('Arcane_Crown',(cx,cy,focus_z),.157,.019,TRIM,'XZ')
    doorway('Conclave_Entry',cx,cy-.274,height=.37)
    window('Conclave_Right',cx+.287,cy,.54,.13,.22,True)
    window('Conclave_Rear',cx,.426,.59,.10,.20)
    hall('Scroll_Library',.42,.215,.27,.34,.077,.26)
    doorway('Library_Entry',.42,.041,width=.13,height=.20)
    ring('Arcane_Practice_Circle',(.10,-.41,.101),.207,.02,'school','XY','06_TRAINING',6)
    polygon_prism('Practice_Pad',hexagon(.17,(.10,-.41)),.084,.095,'stone','06_TRAINING')
    crystal('Practice_Focus',(.10,-.41,.24),.065,.11,'magic','06_TRAINING')
    lectern('Arcanist_Spellbook',-.39,-.325)
    pedestal('Attunement_Pillar',.40,-.305,.26,'magic',.09)
    design = 'Tall hexagonal conclave tower, stepped crown with floating prism and orbit, attached scroll library and spell practice circle.'
else:
    cx,cy = 0,.19
    polygon_prism('Observation_Foot',hexagon(.345,(cx,cy)),.077,.16,'cutstone','02_HALL')
    polygon_prism('Observation_Tower',hexagon(.30,(cx,cy)),.16,.57,BODY,'02_HALL')
    doorway('Observation_Entry',0,-.07,height=.30)
    for j in range(3):
        polygon_prism('Open_Deck_Course_%d'%j,hexagon(.35-j*.018,(cx,cy)),
                      .576+j*.035,.610+j*.035,'roof_dark' if j==0 else 'cutstone','03_ROOFS')
    for i,(x,y) in enumerate(hexagon(.30,(cx,cy))):
        box('Observation_Rail_Post_%d'%i,(x,y,.755),(.025,.025,.19),TRIM,'03_ROOFS')
    ring('Observation_Deck_Rail',(cx,cy,.837),.30,.022,TRIM,'XY','03_ROOFS',6)
    box('Armillary_Stand',(cx,cy,.792),(.065,.065,.20),TRIM,'04_FOCUS')
    focus_z = 1.08
    for plane,radius in (('XY',.245),('XZ',.226),('YZ',.205)):
        ring('Elemental_Armillary_'+plane,(cx,cy,focus_z),radius,.024,TRIM,plane)
    crystal('Elemental_Core',(cx,cy,focus_z),.125,.19)
    for i,(x,y,reg) in enumerate(((-.46,-.25,'fire'),(.46,-.25,'water'),(-.48,.29,'earth'),(.48,.29,'air'))):
        pedestal('Element_'+reg,x,y,.19 if i<2 else .27,reg,.10)
        box('Element_Plinth_Sigil_%d'%i,(x,y-.08,.203),(.065,.012,.065),reg,'06_TRAINING')
        if MAGIC_CIV=='orc':
            tusk('Element_Totem_Tusk_%d'%i,(x+.075,y,.15),.26,.05,.031,1)
        elif MAGIC_CIV=='dwarf':
            box('Element_Copper_Band_%d'%i,(x,y,.27),(.104,.104,.025),'bronze','04_FOCUS')
        elif MAGIC_CIV=='elf':
            leaf('Element_Leaf_%d'%i,(x,y,.60),.078,.105,.02)
    lectern('Elemental_Field_Notes',.245,-.44)
    window('Observation_Right',.27,.19,.36,.13,.19,True)
    design = 'Open observation tower with three-axis block armillary, floating cyan core and four teaching foci: fire, water, earth and air.'

# Faction identification is separate from school symbols and emissive colors.
box('Faction_Pole',(.58,.39,.67),(.017,.017,.72),TRIM,'07_FACTION')
box('Faction_Pennant',(.495,.39,.93),(.155,.013,.15),'faction','07_FACTION')
box('School_Pennant_Emblem',(.495,.378,.93),(.042,.012,.060),'school','07_FACTION')
if MAGIC_CIV=='elf' and MAGIC_SCHOOL!='druidism':
    tree('Woodland_Sapling',-.67,.10,.69,.15)
if MAGIC_CIV=='dwarf':
    for sign in (-1,1):
        box('Copper_Ground_Rune_'+str(sign),(sign*.22,-.60,.091),(.075,.074,.018),'bronze','08_DETAILS')
        box('Ground_Rune_Inset_'+str(sign),(sign*.22,-.60,.104),(.017,.044,.010),'school','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_'+STEM
root['civilization'],root['magic_school'],root['asset_only'] = MAGIC_CIV,MAGIC_SCHOOL,True
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.03, (FOLDER,maximum)
studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene.render.resolution_x = scene.render.resolution_y = 800
scene.cycles.samples = 16
scene['preview_target'] = [0,0,.53]
scene['door_clearance'] = [.23,.35] if MAGIC_SCHOOL!='druidism' else [.26,.54]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = FOLDER,128,7
scene['asset_output_relative'] = OUT.relative_to(ROOT).as_posix()
scene['display_name'] = DISPLAY+' — '+{'human':'Humanos','orc':'Orcs','dwarf':'Anões','elf':'Elfos'}[MAGIC_CIV]
scene['civilization'],scene['magic_school'],scene['asset_only'] = MAGIC_CIV,MAGIC_SCHOOL,True
scene['trains'],scene['excludes'] = ['v2_unit_'+UNIT],['v2_building_'+RITUAL]
scene['palette_overrides'] = palette
scene['scale_note'] = 'Native 4X map units, pointy-top hex tile radius 1; foundation .92, placement scale 1.'
scene['design_note'] = {'human':'Blue slate, light plaster and timber. ', 'orc':'Basalt, broad timber posts, rust-red roofs, black iron and tusks. ',
    'dwarf':'Granite, squat dark slate roofs, thick square pillars and copper bands. ',
    'elf':'Ivory stone, slender woodwork, taller emerald roofs and gold leaves. '}[MAGIC_CIV]+design
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),
    'parts':parts,'groups':groups,'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'asset':FOLDER,'parts':len(parts),'max_half_plane':maximum}
