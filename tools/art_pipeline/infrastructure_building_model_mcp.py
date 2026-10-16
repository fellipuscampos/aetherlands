"""Build one new infrastructure asset in the live Blender editor, via MCP only."""
import ast
import bpy
import bmesh
import json
import math
import time
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE=ROOT/'tools/art_pipeline'
REVIEW=ROOT/'art_source/infrastructure_buildings_review'
REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').touch(exist_ok=True)
CIV,ROLE=INFRA_CIV,INFRA_ROLE
PLURALS={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}
DISPLAY={'market':'Mercado','farm':'Fazenda','workshop':'Oficina','university':'Universidade','arcane_shrine':'Santuário Arcano'}
BRANCHES={'market':'economy','farm':'logistics','workshop':'industry','university':'academy','arcane_shrine':'arcane'}
GAME_ID='v2_building_'+('academy' if ROLE=='university' else ROLE)
FOLDER=('' if CIV=='human' else CIV+'_')+ROLE+'_hex_v1'
NAME=CIV.title()+'_'+ROLE.title()+'_Hex_V1'
OUT=ROOT/'assets/generated'/PLURALS[CIV]/'buildings'/FOLDER
assert NAME not in bpy.data.scenes,'Preserve existing scene: '+NAME
assert not (OUT/(FOLDER+'.glb')).exists(),'Preserve existing export: '+FOLDER
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'previews').mkdir(exist_ok=True)
phase_start=time.monotonic()
def checkpoint(stage):
    (REVIEW/'current_stage.json').write_text(json.dumps({'asset':FOLDER,'stage':stage,'elapsed':round(time.monotonic()-phase_start,1)}),encoding='utf-8')
checkpoint('create_geometry')
scene=bpy.data.scenes.new(NAME)
bpy.context.window.scene=scene
groups={}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_FOCUS','05_COURTYARD','06_STRUCTURE','07_FACTION','08_DETAILS','09_STUDIO'):
    collection=bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(collection)
    groups[label]=collection
parts=[]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (
    ('guardian_hall_hex_v2_model.py',('mesh','box','polygon_prism','hexagon','wall')),
    ('war_stable_hex_v1_model.py',('clip_to_hex','vertical_prism')),
    ('ranger_camp_hex_v1_model.py',('beam',)),
    ('elf_city_level_1_hex_v1_model.py',('leaf',)),
    ('orc_city_level_1_hex_v1_model.py',('tusk',)),
):
    for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            if node.name=='tusk': node.name='_native_tusk'
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<infrastructure_primitives>','exec'))
def tusk(name,center,height,width,group='08_DETAILS'):
    return _native_tusk(name,center,height,width,width*.68,1,group)

BODY={'human':'stone','elf':'plaster','dwarf':'stone','orc':'timber'}[CIV]
POST={'human':'cutstone','elf':'timber','dwarf':'cutstone','orc':'timber'}[CIV]
TRIM={'human':'gold','elf':'gold','dwarf':'bronze','orc':'iron'}[CIV]
DESIGNS={
 'human':'Alvenaria de blocos de pedra, cantaria nos pilares e bases, telhados de ardósia azul. Madeira nos móveis, portas e mecanismos.',
 'elf':'Pedra clara e madeira esbelta com apoios ramificados, pavilhões abertos, telhados verdes altos com cantos facetados e folhas douradas.',
 'dwarf':'Granito, pilares espessos, sapatas de pedra e cintas de cobre. Telhados baixos de ardósia escura e engenharia mecânica robusta.',
 'orc':'Madeira grossa com cintas de ferro, escoras diagonais e bases de pedra escura. Telhados ferrugem e presas nos pontos estruturais.',
}
PALETTES={
 'human':{'roof':[49,79,127],'roof_dark':[37,59,95],'faction':[52,83,145],'gold':[185,153,70]},
 'elf':{'stone':[171,180,157],'cutstone':[210,211,177],'foundation':[100,119,105],'plaster':[210,211,177],'paving':[139,158,126],'timber':[116,93,55],'door':[137,112,72],'roof':[48,122,88],'roof_dark':[34,87,66],'faction':[47,111,81],'gold':[209,186,101]},
 'dwarf':{'stone':[111,123,130],'cutstone':[150,158,155],'foundation':[82,94,102],'paving':[112,126,127],'roof':[67,82,89],'roof_dark':[43,53,60],'bronze':[177,111,55],'faction':[65,92,120]},
 'orc':{'stone':[87,101,102],'cutstone':[116,124,111],'foundation':[61,76,79],'paving':[105,115,94],'timber':[85,56,35],'door':[114,74,42],'roof':[130,58,39],'roof_dark':[85,37,29],'iron':[52,66,70],'iron_light':[124,137,133],'faction':[153,49,31]},
}
palette={'gold':[190,154,70],'bronze':[177,111,55],'bone':[208,199,163],
 'foliage':[59,105,48],'foliage_light':[109,150,68],'fruit':[178,91,50],
 'grain':[201,169,83],'soil':[96,75,48],'soil_dark':[66,53,36],
 'glass':[91,149,156],'water':[60,125,147],'leather':[103,63,40],
 'paper':[213,203,168],'ink':[78,79,64],'book_cover':[87,89,130],
 'mana':[79,162,221],'mana_water':[55,129,183],'fire':[242,132,40]}
palette.update(PALETTES[CIV])
scene['palette_overrides']=palette
polygon_prism('Hex_Foundation',hexagon(.92),0,.035,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Rim',hexagon(.90),.035,.060,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Courtyard',hexagon(.85),.060,.076,'paving','01_FOUNDATION')
exec((PIPELINE/'infrastructure_primitives.py').read_text(encoding='utf-8'))
exec((PIPELINE/'infrastructure_building_recipes.py').read_text(encoding='utf-8'))
pennant(.55,-.45,.65)
root=bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id']=GAME_ID
root['civilization']=CIV
root['infrastructure_branch']=BRANCHES[ROLE]
root['evolutions']=False
for obj in parts: obj.parent=root
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60)) for o in parts for v in o.data.vertices for i in range(6))
assert maximum<=math.sqrt(3)/2-.030,(FOLDER,maximum)
assert all(o.location.length<1e-7 and tuple(o.scale)==(1,1,1) for o in parts)
studio=(PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio[studio.index('world = bpy.data.worlds.new'):studio.index("scene['preview_target']")])
scene.render.resolution_x=scene.render.resolution_y=800
scene.cycles.samples=16
scene['asset_output_relative']=OUT.relative_to(ROOT).as_posix()
scene['asset_basename']=FOLDER
scene['preview_target']=[0,0,.61]
scene['display_name']=DISPLAY[ROLE]
scene['civilization']=CIV
scene['infrastructure_branch']=BRANCHES[ROLE]
scene['infrastructure_only_version']=True
scene['trains']=['v2_unit_builder'] if ROLE=='workshop' else []
scene['excludes']=[]
scene['density']=128
scene['paint_world_scale']=7
scene['door_clearance']=[.20,.32]
scene['scale_note']='Escala nativa 1:1 do mapa; tile pointy-top de raio 1; multiplicador 1.0.'
scene['design_note']=DESIGNS[CIV]+' '+DISPLAY[ROLE]+' de infraestrutura, uma única versão sem evolução.'
scene['integration_source']='scripts/data/BuildingArtCatalog.gd'
st={'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,'door_clearance':[.20,.32],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
bpy.app.driver_namespace['guardian_hall']=st
checkpoint('paint_atlases')
paint_code=(PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8')
paint_code=paint_code.replace("elif reg == 'glow':","elif reg in ('mana','mana_water','fire'):\n        e[:] = np.asarray(PALETTE[reg]) * (.45 if reg == 'mana_water' else 1.0)\n    elif reg == 'glow':")
exec(paint_code)
st['report'].update({'civilization':CIV,'integration_source':'scripts/data/BuildingArtCatalog.gd','infrastructure':{'branch':BRANCHES[ROLE],'single_version':True,'evolutions':[],'blender_mcp_only':True,'architecture':DESIGNS[CIV],'recipe':CIV+'_'+ROLE},'hex_tile':{'circumradius':1.0,'source_base_radius':.92,'max_half_plane_blender':maximum,'minimum_margin':math.sqrt(3)/2-maximum}})
checkpoint('export_glb')
exec((PIPELINE/'export_architecture_revision_mcp.py').read_text(encoding='utf-8'))
checkpoint('render_previews')
prefs=bpy.context.preferences.addons['cycles'].preferences
previous_compute=prefs.compute_device_type
try:
    try:
        prefs.compute_device_type='OPTIX'; prefs.get_devices()
        if any(d.type=='OPTIX' and d.use for d in prefs.devices): scene.cycles.device='GPU'
    except (TypeError,RuntimeError): pass
    for view,(position,scale) in {'three_quarter':((2.6,-4,3.3),2.8),'game_top':((1.8,-2.9,4.9),2.65),'top':((0,0,6),2.25),'back':((-2.6,4,3.4),2.8)}.items():
        checkpoint('render_'+view)
        camera.location=position; camera.data.ortho_scale=scale
        aim=Vector((0,0,0)) if view=='top' else Vector(scene['preview_target'])
        camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/'previews'/(view+'.png'))
        bpy.ops.render.render(write_still=True)
finally:
    prefs.compute_device_type=previous_compute
camera.location=(2.6,-4,3.3); camera.data.ortho_scale=2.8
camera.rotation_euler=(Vector(scene['preview_target'])-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(FOLDER+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
report=st['report']
body='# '+DISPLAY[ROLE]+' — '+CIV+'\n\n'+scene['design_note']+'\n\n'
body+='Criado pelo **Blender MCP**. Categoria `'+BRANCHES[ROLE]+'`, ID `'+GAME_ID+'`. Uma única versão por civilização; sem evoluções.\n\n'
body+=f'- {report["editable_parts"]} peças editáveis, {report["triangles"]} triângulos, atlas {report["texture"]["size"][0]}² com filtro nearest.\n'
body+='- .blend com atlas empacotados; .glb com duas texturas embutidas.\n- Escala nativa do tile, origem central no solo; frente −Y no Blender / +Z no Godot.\n- Malha Faction separada para a cor do dono.\n\n'
body+='Prévias: [três quartos](previews/three_quarter.png), [mapa](previews/game_top.png), [topo](previews/top.png), [traseira](previews/back.png).\n'
(OUT/'README.md').write_text(body,encoding='utf-8')
checkpoint('complete')
result={'asset':FOLDER,'civilization':CIV,'role':ROLE,'gameplay_building_id':GAME_ID,'triangles':report['triangles'],'editable_parts':len(parts),'max_half_plane':maximum,'mcp_only':True}
