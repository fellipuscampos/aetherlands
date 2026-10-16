"""Prepare a completely nonhumanoid runic polyhedron from the user's latest reference."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];TOOLS=ROOT/'tools/art_pipeline'
OLD='veil_archon_blocky_v7';NEW='veil_archon_blocky_v8'
CONCEPT='Nonhumanoid suspended runic polyhedron: thirty-four dark violet runestones arranged in principal, oblique and vertex layers, white pixel glyphs, real luminous fissures, an open internal mana lattice, one central cubic white-violet nucleus and a broken angular orbital trail. Sharp closed blocky prisms with stepped clipped corners.'
def read(n):return (TOOLS/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Veil_Archon_Blocky_V7','Veil_Archon_Blocky_V8').replace('VeilArchonModelReviewV7','VeilArchonModelReviewV8')
def write(n,s):(TOOLS/n).write_text(s,encoding='utf-8')
src=read('build_veil_archon_blocky_v7_mcp.py')
head=names(src[:src.index('# Sculpted unions of cuboids')])
head=head.replace('old_hashes={',"protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v7'/('veil_archon_blocky_v7.'+ext) for ext in ('glb','blend'))\nold_hashes={")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Mineral layers, painted creases')]
tail=names(src[src.index('images=[]'):]).replace('Sculpted_Mineral_Open_Chest_Core','Runic_Obsidian_White_Violet_Core')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_veil_archon_blocky_v8_mcp.py',head+read('veil_archon_v8_geometry.py')+'\n'+uv+read('veil_archon_v8_texture.py')+'\n'+tail)
export=names(read('export_veil_archon_blocky_v7_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export).replace("'revision':7","'revision':8")
export=export.replace("'core':'One magenta cube, with a separate pivot and free rotation inside the chest opening'","'core':'One central cubic white-violet mana nucleus, with an independent rigid pivot inside an open luminous lattice'")
export=export.replace('User-supplied dark spectral apparition with open red-magenta crown horns and flowing long arm mantles','User-supplied fractured dark runic polyhedron with a bright white-violet interior and energy trails')
export=export.replace("'cuboid_geometry':True,'rigid_rotated_cuboids':True","'blocky_prism_geometry':True,'stepped_corners':True,'runic_panels':34")
export=export.replace("temp=bpy.data.collections.new", "plate_trees=[(o,tree) for o,tree in targets if o['kind']=='plate']\nplate_pairs=0\nfor i,(a,tree) in enumerate(plate_trees):\n    for b,other in plate_trees[i+1:]:\n        plate_pairs+=1\n        assert not tree.overlap(other),('Runic plate intersection',a.name,b.name)\ntemp=bpy.data.collections.new")
export=export.replace("'core_full_rotation_clearance_samples':48", "'core_full_rotation_clearance_samples':48,'runic_plate_pairs_checked':plate_pairs,'runic_plate_intersections':0")
write('export_veil_archon_blocky_v8_mcp.py',export)
for old,new in [('validate_veil_archon_blocky_v7.py','validate_veil_archon_blocky_v8.py'),('verify_veil_archon_blocky_v7.gd','verify_veil_archon_blocky_v8.gd'),('finalize_veil_archon_blocky_v7_mcp.py','finalize_veil_archon_blocky_v8_mcp.py'),('compare_veil_archon_v7.py','compare_veil_archon_v8.py')]:write(new,names(read(old)))
for folder,name in [('scripts/art_review','VeilArchonModelReviewV7.gd'),('scenes/art_review','VeilArchonModelReviewV7.tscn')]:
    (ROOT/folder/name.replace('V7','V8')).write_text(names((ROOT/folder/name).read_text(encoding='utf-8')).replace('Núcleo magenta','Núcleo branco e violeta'),encoding='utf-8')
gallery=names(read('write_veil_archon_v7_review.py'))
gallery=gallery.replace('Uma entidade mineral suspensa, com gola larga em V, coroa aberta e um peito realmente vazado que abriga o núcleo cúbico. As carapaças dos braços têm espessura e recortes em blocos, com uma pose espectral assimétrica. O corpo termina em uma raiz afilada que desvia para o lado. A textura usa camadas minerais e poucas fissuras de energia magenta.',
 'Uma entidade geométrica suspensa, formada por placas escuras com runas claras. Placas principais, oblíquas e de vértice formam uma casca fragmentada em várias camadas; fendas reais expõem a energia branca e violeta. Um núcleo cúbico independente ocupa o centro, dentro de uma estrutura angular aberta. Os recortes em degraus e a pintura em pixels mantêm a estética blocky.')
gallery=gallery.replace('Volumes minerais de cuboides unidos, gola larga em V, peito vazado com núcleo cúbico magenta, coroa aberta, longas carapaças dos braços, braços espectrais assimétricos e raiz suspensa afilada. Pintura pixelada de planos minerais e poucas fissuras de mana.',
 'Poliedro rúnico suspenso com 34 placas escuras de tamanhos diferentes, dispostas em três camadas. Glifos pixelados claros, fendas luminosas reais, estrutura interna de mana aberta, um núcleo cúbico branco-violeta independente e uma órbita angular interrompida.')
gallery=gallery.replace('A referência principal é a entidade escura com coroa aberta e energia magenta enviada pelo usuário. Os volumes têm cortes em blocos e faces planas; os membros usam poses angulares rígidas.',
 'A referência principal é a nova entidade de placas rúnicas e interior branco-violeta enviada pelo usuário. O modelo é construído com prismas fechados de faces planas e cantos recortados em degraus.')
gallery=gallery.replace('A silhueta, a pose e a paleta seguem a nova referência enviada. As peças são volumes de cuboides com recortes em degraus, orientados em poses rígidas.',
 'A estrutura e a paleta seguem a nova referência geométrica enviada. As placas têm faces planas e recortes em degraus; todos os glifos são pintados em pixels.')
gallery=gallery.replace('Núcleo magenta','Núcleo branco-violeta').replace('da armadura e das juntas','das placas e da estrutura interna').replace('as peças da armadura','as placas e a estrutura interna')
write('write_veil_archon_v8_review.py',gallery)
print('New runic polyhedron V8 pipeline prepared.')
