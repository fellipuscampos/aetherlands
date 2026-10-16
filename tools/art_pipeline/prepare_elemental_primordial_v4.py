"""Reference-led primordial: charcoal mineral anatomy with massive forelimbs and cyan back crystals."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v3';NEW='elemental_primordial_blocky_v4'
CONCEPT='User-reference-inspired hunched quadrupedal black-rock colossus, massive knuckle-bearing forelimbs, smaller splayed rear legs, a sheltered six-eyed creature head, layered charcoal plates, five huge cyan stepped crystal columns rooted into its back, two smaller shoulder outcrops and a recessed cubic elemental heart. Three meters tall; sharp voxel geometry and pixel-painted mineral textures.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V3','Elemental_Primordial_Blocky_V4').replace('ElementalPrimordialModelReviewV3','ElementalPrimordialModelReviewV4').replace('elemental_primordial_v3','elemental_primordial_v4')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v3_mcp.py')
head=names(src[:src.index('# A colossal mineral predator')])
extra="""for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v3'/('elemental_primordial_blocky_v3.'+ext))
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Closely related mineral tones')]
tail=names(src[src.index('images=[]'):]).replace('Primal_Mineral_Predator_Cyan_Heart','Charcoal_Creature_Cyan_Crystals')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
tail=tail.replace('data.ortho_scale=6.0; camera.location=(7,-10,5.0)','data.ortho_scale=4.8; camera.location=(4,-11,4.0)')
write('build_elemental_primordial_v4_mcp.py',head+read('elemental_primordial_v4_geometry.py')+'\n'+uv+read('elemental_primordial_v4_texture.py')+'\n'+tail)
export=names(read('export_elemental_primordial_v3_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':3","'revision':4").replace("['mineral_predator','crystal_fangs','cold_faults','cyan_heart']","['charcoal_body','cyan_crystal_columns','six_luminous_eyes','recessed_cube_heart']")
export=export.replace("'references':[", "'references':['User supplied black-rock monster with large cyan back crystals',")
write('export_elemental_primordial_v4_mcp.py',export)
for old,new in [('validate_elemental_primordial_v3.py','validate_elemental_primordial_v4.py'),('verify_elemental_primordial_v3.gd','verify_elemental_primordial_v4.gd'),('finalize_elemental_primordial_v3_mcp.py','finalize_elemental_primordial_v4_mcp.py'),('compare_elemental_primordial_v3.py','compare_elemental_primordial_v4.py')]:
    write(new,names(read(old)))
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReviewV3.gd'),('scenes/art_review','ElementalPrimordialModelReviewV3.tscn')]:
    v=names((ROOT/folder/filename).read_text(encoding='utf-8')).replace('camera.size = 6.0','camera.size = 4.8').replace('Vector3(7, 5, 10)','Vector3(4, 4, 10)')
    (ROOT/folder/filename.replace('ReviewV3','ReviewV4')).write_text(v,encoding='utf-8')
gallery=names(read('write_elemental_primordial_v3_review.py'))
gallery=gallery.replace('Um predador elemental quadrúpede de três metros, com dianteira alta e pesada, traseira baixa e quatro patas com garras. Cabeça de mandíbula larga, presas de cristal e chifres voltados para trás. O núcleo cúbico ciano aparece entre as placas do tórax, sob o pescoço. A anatomia usa volumes blocky, rocha escura e fissuras frias em pixels.',
 'Uma criatura rochosa corcunda, com membros dianteiros enormes e patas traseiras menores. Placas de carvão e pedra envolvem uma cabeça pequena de seis olhos luminosos e um núcleo cúbico ciano encaixado no tórax. Cinco grandes colunas de cristal saem das costas, com dois afloramentos nos ombros. A referência enviada orienta a silhueta e a paleta; os volumes têm seções quadradas e recortes em degraus.')
gallery=gallery.replace('O warg e o basilisco atuais orientam a anatomia blocky; as proporções, as placas e o núcleo distinguem a grande invocação.','A referência enviada orienta o corpo corcunda, os membros enormes, a cabeça abrigada e os cristais das costas; o jogo orienta os volumes blocky e a escala.')
gallery=gallery.replace('Predador quadrúpede mineral de 3 metros, com dianteira pesada, quatro patas conectadas, garras, mandíbula com presas de cristal, coroa voltada para trás e cauda articulada. Um núcleo cúbico ciano fica entre as placas abertas do tórax.',
 'Criatura rochosa quadrúpede de 3 metros, inspirada na referência enviada: corpo corcunda, enormes membros dianteiros, patas traseiras menores, cabeça de seis olhos ciano, placas de pedra escura e grandes cristais ciano enraizados nas costas. O núcleo cúbico fica encaixado no tórax.')
write('write_elemental_primordial_v4_review.py',gallery)
print('Reference-inspired Primordial V4 pipeline prepared.')
