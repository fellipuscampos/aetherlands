"""Orc ranged training camp, original blocky hex asset. Live Blender MCP only."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Orc_Ranger_Camp_Hex_V1'
RELATIVE_OUT = 'assets/generated/orcs/buildings/orc_ranger_camp_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Orc Ranger Camp source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_LODGE','03_ROOFS','04_TARGETS','05_COURTYARD',
              '06_EQUIPMENT','07_FACTION','08_DETAILS','09_STUDIO'):
    collection = bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (
    ('guardian_hall_hex_v2_model.py',('mesh','box','polygon_prism','hexagon','wall')),
    ('war_stable_hex_v1_model.py',('clip_to_hex','vertical_prism')),
    ('orc_city_level_1_hex_v1_model.py',('tusk',)),
    ('ranger_camp_hex_v1_model.py',('beam','target_disc')),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))


def orc_bow(name,center,height,group='06_EQUIPMENT'):
    x,y,z = center
    profile = [(.06,-.50),(-.02,-.50),(-.02,-.37),(-.13,-.37),
               (-.13,-.22),(-.25,-.22),(-.25,.22),(-.13,.22),
               (-.13,.37),(-.02,.37),(-.02,.50),(.06,.50),
               (.06,.30),(-.045,.30),(-.045,.13),(-.17,.13),
               (-.17,-.13),(-.045,-.13),(-.045,-.30),(.06,-.30)]
    vertical_prism(name+'_Stepped_Limbs',[(u*height,v*height) for u,v in profile],
                   center,.024,'door',group)
    box(name+'_Grip',(x-.213*height,y-.010,z),(.103*height,.037,.172*height),'iron',group)
    box(name+'_String',(x+.060*height,y,z),(.007,.007,height*.98),'bone',group)
    for sign in (-1,1):
        box(name+'_Limb_Binding_'+str(sign),(x-.162*height,y,z+sign*.207*height),
            (.151*height,.031,.036),'iron',group)
        box(name+'_Ivory_Tip_'+str(sign),(x+.020*height,y,z+sign*.474*height),
            (.114*height,.029,.044),'bone',group)


def arrow(name,start,end,width=.007,group='06_EQUIPMENT'):
    a,b = Vector(start),Vector(end)
    direction = (b-a).normalized()
    right = direction.cross(Vector((0,0,1)))
    if right.length<.001:
        right = direction.cross(Vector((0,1,0)))
    right.normalize()
    up = direction.cross(right).normalized()
    beam(name+'_Shaft',a,b,width,'door',group)
    base = b-direction*width*1.7
    verts = [tuple(base+right*u*width*2+up*v*width*2)
             for u,v in ((-1,-1),(1,-1),(1,1),(-1,1))]
    verts.append(tuple(b+direction*width*4))
    mesh(name+'_Point',verts,[(3,2,1,0),(0,1,4),(1,2,4),(2,3,4),(3,0,4)],'iron_light',group)
    tail = a+direction*width*4
    for i,axis in enumerate((right,up)):
        beam(name+'_Feather_%d'%i,tail-axis*width*2.8,tail+axis*width*2.8,width,'bone',group)


polygon_prism('Hex_Basalt_Foundation',hexagon(.92),0,.036,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Rim',hexagon(.90),.036,.062,'stone','01_FOUNDATION')
polygon_prism('Camp_Moss_Grass',hexagon(.85),.062,.078,'grass','01_FOUNDATION')

# Small lodge stays on the left, preserving a broad open shooting range.
cx,cy = -.468,.172
footprint = [(-.640,-.072),(-.300,-.072),(-.300,.373),(-.465,.482),(-.640,.373)]
polygon_prism('Lodge_Basalt_Foot',footprint,.078,.150,'stone','02_LODGE')
polygon_prism('Lodge_Timber_Body',footprint,.150,.574,'door','02_LODGE')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Lodge_Base_Beam_%d'%i,a,b,.035,.142,.181,'timber','02_LODGE')
    wall('Lodge_Eave_Beam_%d'%i,a,b,.045,.545,.599,'timber','02_LODGE')
    box('Lodge_Post_%d'%i,(a[0],a[1],.367),(.051,.054,.414),'timber','02_LODGE')
    for z in (.224,.510):
        box('Post_Iron_Collar_%d_%s'%(i,z),(a[0],a[1],z),(.068,.071,.037),'iron','02_LODGE')
for j in range(5):
    sx,sy = .445-j*.080,.610-j*.021
    points = [(cx-sx/2,cy-sy/2),(cx+sx/2,cy-sy/2),
              (cx+sx/2,cy+sy/2),(cx-sx/2,cy+sy/2)]
    polygon_prism('Lodge_Red_Hide_Roof_%d'%j,clip_to_hex(points,.855),
                  .598+j*.050,.648+j*.050,'roof','03_ROOFS')
    box('Lodge_Roof_Iron_Binding_%d'%j,(cx,cy-sy/2-.007,.617+j*.050),
        (sx,.031,.022),'iron','03_ROOFS')
box('Lodge_Heavy_Ridge',(cx,cy,.867),(.084,.510,.038),'timber','03_ROOFS')
for y in (-.074,.416):
    box('Lodge_Ridge_Socket_'+str(y),(cx,y,.880),(.102,.052,.051),'iron','03_ROOFS')
    tusk('Lodge_Ridge_Horn_'+str(y),(cx,y,.907),.122,.061,.050,1,'03_ROOFS')
box('Lodge_Door_Shadow',(cx,-.086,.335),(.177,.026,.289),'shadow','02_LODGE')
box('Lodge_Door',(cx,-.107,.330),(.149,.023,.262),'door','02_LODGE')
for z in (.233,.425):
    box('Lodge_Door_Strap_'+str(z),(cx,-.127,z),(.143,.021,.026),'iron','02_LODGE')
box('Lodge_Door_Handle',(cx+.040,-.145,.332),(.019,.019,.026),'iron_light','08_DETAILS')
box('Lodge_Entry_Deck',(cx,-.150,.109),(.272,.131,.062),'timber','05_COURTYARD')
box('Lodge_Entry_Step',(cx,-.243,.092),(.299,.064,.029),'cutstone','05_COURTYARD')
box('Lodge_Right_Window',(-.284,.162,.375),(.025,.100,.119),'shadow','02_LODGE')
for y in (.125,.162,.199):
    box('Lodge_Window_Grille_'+str(y),(-.264,y,.375),(.018,.013,.111),'iron','02_LODGE')

# High-contrast bow and arrow sign, projecting in front of the cabin roof.
box('Bow_Emblem_Iron_Frame',(cx,-.176,.684),(.252,.040,.324),'iron','02_LODGE')
box('Bow_Emblem_Clan_Cloth',(cx,-.202,.684),(.220,.017,.291),'faction','07_FACTION')
orc_bow('Emblem_Heavy_Bow',(cx+.025,-.229,.687),.255,'08_DETAILS')
arrow('Emblem_Arrow',(cx-.099,-.263,.687),(cx+.111,-.263,.687),.008,'08_DETAILS')

# Target line follows the rear-right face of the hex, not a rectangular plot.
angle = math.radians(-30)
across = Vector((math.cos(angle),math.sin(angle),0))
back = Vector((-math.sin(angle),math.cos(angle),0))
centers = [Vector((.044,.595,.386)),Vector((.275,.461,.386)),Vector((.506,.327,.386))]
screen = Vector((.275,.461,0))+back*.076
box('Range_Arrow_Backstop',(screen.x,screen.y,.334),(.811,.041,.386),'timber','04_TARGETS',angle)
box('Range_Backstop_Iron_Top',(screen.x,screen.y,.548),(.868,.049,.031),'iron','04_TARGETS',angle)
for sign in (-1,1):
    p = screen+across*(sign*.440)
    box('Range_Cover_Post_'+str(sign),(p.x,p.y,.377),(.048,.050,.599),'timber','04_TARGETS')
    box('Range_Post_Iron_Socket_'+str(sign),(p.x,p.y,.116),(.071,.073,.078),'iron','04_TARGETS')
    foot = p-back*.137
    beam('Range_Frame_Brace_'+str(sign),(foot.x,foot.y,.094),(p.x,p.y,.405),.039,'timber','04_TARGETS')
for j in range(3):
    p = screen-back*(.083-j*.060)
    box('Target_Red_Hide_Cover_%d'%j,(p.x,p.y,.670+j*.024),(.931,.063,.030),'roof_dark','03_ROOFS',angle)
    if j==0:
        box('Target_Cover_Iron_Fascia',(p.x-back.x*.035,p.y-back.y*.035,.665),
            (.948,.023,.039),'iron','03_ROOFS',angle)
for i,c in enumerate(centers):
    box('Target_Stone_Foot_%d'%i,(c.x,c.y,.098),(.159,.134,.040),'stone','04_TARGETS',angle)
    box('Target_Wood_Stake_%d'%i,(c.x,c.y,.242),(.035,.038,.278),'timber','04_TARGETS')
    for j,(diameter,region) in enumerate(((.256,'iron'),(.230,'straw'),(.195,'bone'),
                                         (.143,'target_red'),(.091,'bone'),(.045,'target_red'))):
        p = c-back*(j*.012)
        target_disc('Target_%d_Ring_%d'%(i,j),p,diameter,.028 if j==0 else .014,angle,region)
    hit = c-back*.077+Vector((.017,0,-.006))
    arrow('Target_Embedded_Arrow_%d'%i,hit-back*.151,hit,.006,'04_TARGETS')

# Three diagonal lanes fan towards the actual target line, leaving cabin access free.
polygon_prism('Range_Dirt_Wedge',[(-.243,-.236),(.531,.218),(.663,-.020),
    (.583,-.300),(.366,-.591),(0,-.812),(-.346,-.508)],.078,.090,'sand','05_COURTYARD')
shooting = [Vector((-.142,-.446,0)),Vector((.085,-.498,0)),Vector((.310,-.505,0))]
for i,(front,target) in enumerate(zip(shooting,centers)):
    direction = Vector((target.x-front.x,target.y-front.y,0)).normalized()
    end = Vector((target.x,target.y,0))-direction*.188
    normal = Vector((-direction.y,direction.x,0))
    for sign in (-1,1):
        a,b = front+normal*sign*.080,end+normal*sign*.080
        wall('Lane_Edge_%d_%d'%(i,sign),(a.x,a.y),(b.x,b.y),.013,.090,.099,'formation','05_COURTYARD')
    box('Shooting_Position_%d'%i,(front.x,front.y,.101),(.124,.084,.022),'formation','05_COURTYARD')
    box('Lane_Number_Peg_%d'%i,(front.x-.042,front.y+.067,.109),(.029,.030,.038),'iron','08_DETAILS')

# Two reinforced wooden bows and a square arrow tub beside the range.
for x in (-.249,-.111):
    box('Bow_Rack_Post_'+str(x),(x,-.092,.278),(.025,.035,.384),'timber','06_EQUIPMENT')
box('Bow_Rack_Rail',(-.180,-.092,.440),(.218,.041,.029),'iron','06_EQUIPMENT')
orc_bow('Rack_Bow_Left',(-.227,-.128,.290),.346)
orc_bow('Rack_Bow_Right',(-.095,-.142,.290),.346)
qx,qy = .597,-.235
box('Arrow_Tub_Base',(qx,qy,.098),(.108,.104,.040),'timber','06_EQUIPMENT')
for dx,dy in ((-.046,0),(.046,0),(0,-.044),(0,.044)):
    box('Arrow_Tub_Side_%s_%s'%(dx,dy),(qx+dx,qy+dy,.167),
        (.021 if dx else .071,.021 if dy else .105,.127),'door','06_EQUIPMENT')
for i,(dx,dy) in enumerate(((-.022,-.019),(.021,-.017),(.002,.020))):
    arrow('Arrow_Tub_Ammo_%d'%i,(qx+dx,qy+dy,.122),(qx+dx,qy+dy,.369+i*.017),.006)
for i,(x,y) in enumerate(((-.669,.205),(.386,.588))):
    box('Supply_Crate_%d'%i,(x,y,.128),(.094,.091,.100),'crate','08_DETAILS')
box('Camp_Bench_Seat',(-.502,-.355,.163),(.216,.071,.025),'door','08_DETAILS')
for x in (-.576,-.430):
    box('Camp_Bench_Leg_'+str(x),(x,-.355,.118),(.026,.050,.080),'timber','08_DETAILS')
for i,(x,y) in enumerate(((.075,.750),(-.530,-.453))):
    box('Camp_Grass_Tuft_%d'%i,(x,y,.102),(.078,.071,.042),'foliage','08_DETAILS')

# Short exposed clan pennant, no watchtower or perimeter wall ring.
px,py = -.663,-.251
box('Clan_Pennant_Stone',(px,py,.108),(.086,.089,.060),'stone','08_DETAILS')
box('Clan_Pennant_Pole',(px,py,.394),(.019,.020,.554),'timber','08_DETAILS')
box('Clan_Pennant_Cap',(px,py,.683),(.032,.035,.027),'iron_light','08_DETAILS')
box('Ranger_Clan_Faction_Banner',(px+.052,py,.570),(.113,.017,.143),'faction','07_FACTION')
arrow('Banner_Arrow',(px+.052,py-.023,.510),(px+.052,py-.023,.620),.006,'08_DETAILS')
box('Lodge_Lantern_Frame',(cx+.108,-.127,.418),(.035,.044,.056),'iron','08_DETAILS')
box('Lodge_Lantern_Glow',(cx+.108,-.155,.418),(.024,.014,.037),'glow','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_ranger_camp','orc',True
root['unit_class'] = 'ranged'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.36]
scene['door_clearance'] = [.149,.262]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Campo dos Patrulheiros Orcs'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_archer','v2_unit_hunter','v2_unit_elite_marksman']
scene['excludes'] = ['v2_legendary_legend_hunter']
scene['civilization'],scene['asset_only'] = 'orc',True
scene['palette_overrides'] = {
    'stone':[91,101,98],'cutstone':[145,141,121],'foundation':[68,77,77],
    'paving':[107,113,88],'timber':[78,53,35],'door':[123,89,54],
    'roof':[130,58,39],'roof_dark':[96,47,34],'iron':[53,65,65],
    'iron_light':[152,161,151],'bone':[225,215,174],'faction':[170,60,39],
    'crate':[123,97,58],'sand':[145,126,84],'formation':[180,164,125],
    'target_red':[167,60,39],'grass':[85,108,66],'foliage':[80,117,62]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92; placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Orc ranged training camp: compact left timber lodge with rust-red horned roof and prominent reinforced bow-and-arrow sign, three stepped red/ivory targets following the rear-right hex side under a hide canopy, embedded arrows, three marked shooting lanes, bow rack and arrow tub. Moss ground, sand, heavy iron and clan cloth continue the orc family. Shared regular ranged line; legendary hunter remains in separate mastery building. No watchtower, character references or outer wall ring.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
