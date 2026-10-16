"""Prepare the last school's three-meter living tempest and static native review."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];TOOLS=ROOT/'tools/art_pipeline'
OLD='veil_archon_blocky_v8';NEW='elemental_primordial_blocky_v1'
CONCEPT='Three-meter suspended living tempest: broad cuboid cloud crown, charred fire flank with voxel amber flames, stepped blue ice, a mineral earth anchor, three narrowing open wind curls and one central cyan cubic elemental heart. Weather-control manifestation shared by all civilizations.'
def read(n):return (TOOLS/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Veil_Archon_Blocky_V8','Elemental_Primordial_Blocky_V1').replace('VeilArchonModelReviewV8','ElementalPrimordialModelReview').replace('Arconte do Véu','Primordial dos Elementos').replace('VEIL_ARCHON_MODEL_VALIDATION','ELEMENTAL_PRIMORDIAL_MODEL_VALIDATION')
def write(n,s):(TOOLS/n).write_text(s,encoding='utf-8')
src=read('build_veil_archon_blocky_v8_mcp.py')
head=names(src[:src.index('# Nonhumanoid fractured runic polyhedron')])
extra="""for stem in ['veil_archon_blocky_v8','veil_archon_blocky_v9_animated']:
    protected.extend(ROOT/'assets/generated/grand_manifestations'/stem/(stem+'.'+ext) for ext in ('glb','blend'))
for relative in ['assets/generated/humans/human_elementalist_v1/human_elementalist_v1.glb',
 'assets/generated/humans/buildings/elemental_observatory_hex_v1/elemental_observatory_hex_v1.glb',
 'assets/generated/humans/buildings/elemental_ritual_hex_v1/elemental_ritual_hex_v1.glb']:
    protected.append(ROOT/relative)
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
helper=read('veil_archon_v7_geometry.py');helper=helper[helper.index('def solid('):helper.index('def steps(')]
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Hand-designed pixel glyphs')]
tail=names(src[src.index('images=[]'):]).replace('Runic_Obsidian_White_Violet_Core','Four_Elements_Storm_Cyan_Heart')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_elemental_primordial_v1_mcp.py',head+helper+'\n'+read('elemental_primordial_geometry.py')+'\n'+uv+read('elemental_primordial_texture.py')+'\n'+tail)
export=names(read('export_veil_archon_blocky_v8_mcp.py'))
export=export[:export.index('plate_trees=')]+export[export.index('temp=bpy.data.collections.new'):]
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export).replace("'school':'arcanism'","'school':'elementalism'")
export=re.sub(r"'core':'[^']*'","'core':'One independent cyan cubic mana heart with pixel-painted fire, water, earth and air focal colors'",export)
export=export.replace(",'runic_plate_pairs_checked':plate_pairs,'runic_plate_intersections':0",'')
start=export.index("'references':[");end=export.index("'revision':8",start)
refs="""'references':['scripts/data/V2MagicContent.gd: Elementalism and Primordial dos Elementos',
 'assets/generated/humans/human_elementalist_v1',
 'assets/generated/humans/buildings/elemental_observatory_hex_v1',
 'assets/generated/humans/buildings/elemental_ritual_hex_v1',
 'assets/generated/grand_manifestations/veil_archon_blocky_v9_animated',
 'assets/generated/grand_manifestations/archdemon_blocky_v5_animated'],
 """
export=export[:start]+refs+export[end:]
export=export.replace("'revision':8","'revision':1").replace(",'runic_panels':34",",'elemental_components':['cloud','fire','water','earth','wind']")
write('export_elemental_primordial_v1_mcp.py',export)
for old,new in [('validate_veil_archon_blocky_v8.py','validate_elemental_primordial_v1.py'),('verify_veil_archon_blocky_v8.gd','verify_elemental_primordial_v1.gd'),('finalize_veil_archon_blocky_v8_mcp.py','finalize_elemental_primordial_v1_mcp.py')]:
    value=names(read(old)).replace('verify_'+NEW+'.gd','verify_elemental_primordial_v1.gd')
    write(new,value)
for folder,name in [('scripts/art_review','VeilArchonModelReviewV8.gd'),('scenes/art_review','VeilArchonModelReviewV8.tscn')]:
    value=names((ROOT/folder/name).read_text(encoding='utf-8')).replace('ARCONTE DO VÉU','PRIMORDIAL DOS ELEMENTOS').replace('ARCANISMO','ELEMENTALISMO').replace('Núcleo branco e violeta','Núcleo ciano')
    (ROOT/folder/name.replace('VeilArchonModelReviewV8','ElementalPrimordialModelReview')).write_text(value,encoding='utf-8')
comparison=names(read('compare_veil_archon_v8.py')).replace('Arcanista humano','Elementalista humano').replace('assets/generated/humans/human_arcanist_v1/human_arcanist_v1.glb','assets/generated/humans/human_elementalist_v1/human_elementalist_v1.glb')
comparison=comparison.replace('Arcdemônio','Arconte do Véu').replace('assets/generated/grand_manifestations/archdemon_blocky_v5_animated/archdemon_blocky_v5_animated.glb','assets/generated/grand_manifestations/veil_archon_blocky_v9_animated/veil_archon_blocky_v9_animated.glb')
write('compare_elemental_primordial_v1.py',comparison)
gallery=names(read('write_veil_archon_v8_review.py'))
gallery=gallery.replace('Arcanismo · Grande invocação','Elementalismo · Grande invocação')
gallery=gallery.replace('Uma entidade geométrica suspensa, formada por placas escuras com runas claras. Placas principais, oblíquas e de vértice formam uma casca fragmentada em várias camadas; fendas reais expõem a energia branca e violeta. Um núcleo cúbico independente ocupa o centro, dentro de uma estrutura angular aberta. Os recortes em degraus e a pintura em pixels mantêm a estética blocky.',
 'Uma tempestade viva suspensa: uma coroa larga de nuvens em blocos envolve um núcleo cúbico ciano. Basalto com fissuras de fogo, gelo azul e um bloco de terra mineral se integram à massa; três faixas de vento afunilam a silhueta até a névoa inferior. O modelo usa prismas e volumes de cuboides, com pintura em pixels.')
gallery=gallery.replace('Poliedro rúnico suspenso com 34 placas escuras de tamanhos diferentes, dispostas em três camadas. Glifos pixelados claros, fendas luminosas reais, estrutura interna de mana aberta, um núcleo cúbico branco-violeta independente e uma órbita angular interrompida.',
 'Tempestade viva de 3 metros, com nuvens em blocos, fogo âmbar, gelo, terra mineral e três faixas de vento abertas, que formam um vórtice suspenso. Um núcleo cúbico ciano fica exposto no centro, com os quatro focos elementais pintados nos cantos.')
gallery=gallery.replace('Arcanista humano, Primordial dos Elementos e Arcdemônio','Elementalista humano, Primordial dos Elementos e Arconte do Véu').replace('Arcanista, Arconte e Arcdemônio','Elementalista, Primordial e Arconte')
gallery=gallery.replace('A referência principal é a nova entidade de placas rúnicas e interior branco-violeta enviada pelo usuário. O modelo é construído com prismas fechados de faces planas e cantos recortados em degraus.',
 'O elementalista e os edifícios atuais da escola fornecem a paleta e os quatro focos elementais. Os feitiços de névoa, vendaval e tempestade elétrica orientam a silhueta de tempestade.')
gallery=gallery.replace('A estrutura e a paleta seguem a nova referência geométrica enviada. As placas têm faces planas e recortes em degraus; todos os glifos são pintados em pixels.',
 'A paleta se baseia no elementalista e nos focos dos edifícios atuais; a silhueta segue o repertório de controle do clima da escola.')
gallery=gallery.replace('Núcleo branco-violeta','Núcleo ciano').replace('das placas e da estrutura interna','das nuvens, dos elementos e do vórtice').replace('as placas e a estrutura interna','as massas elementais')
write('write_elemental_primordial_v1_review.py',gallery)
print('Living tempest model, native validation and review pipeline prepared.')
