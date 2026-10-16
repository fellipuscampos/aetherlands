"""Recreate the supplied creature directly with large sharp box volumes, respecting its stance."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v5';NEW='elemental_primordial_blocky_v6'
CONCEPT='Direct reconstruction of the supplied reference in large Hytale-style blocks: one dominant broad cyan upper crystal, asymmetrical smaller mineral outcrops, tall dark carapace enclosing a small low six-eyed face, enormous inward-hanging forearms with dark square hooks, two widely splayed outer legs, oblique overlapping breast rock and an internal cubic mana heart. Three meters tall, sharp planar faces and restrained pixel textures.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V5','Elemental_Primordial_Blocky_V6').replace('ElementalPrimordialModelReviewV5','ElementalPrimordialModelReviewV6').replace('elemental_primordial_v5','elemental_primordial_v6')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v5_mcp.py')
head=names(src[:src.index('# Reference-led rebuild: a mineral creature')])
extra="""for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v5'/('elemental_primordial_blocky_v5.'+ext))
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Broken charcoal mineral faces')]
tail=names(src[src.index('images=[]'):]).replace('Broken_Rock_Creature_Cyan_Slabs','Large_Block_Reference_Creature')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
tail=tail.replace('camera.location=(4,-11,4.0)','camera.location=(2,-12,3.3)')
write('build_elemental_primordial_v6_mcp.py',head+read('elemental_primordial_v6_geometry.py')+'\n'+uv+read('elemental_primordial_v6_texture.py')+'\n'+tail)
export=names(read('export_elemental_primordial_v5_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':5","'revision':6")
write('export_elemental_primordial_v6_mcp.py',export)
for old,new in [('validate_elemental_primordial_v5.py','validate_elemental_primordial_v6.py'),('verify_elemental_primordial_v5.gd','verify_elemental_primordial_v6.gd'),('finalize_elemental_primordial_v5_mcp.py','finalize_elemental_primordial_v6_mcp.py'),('compare_elemental_primordial_v5.py','compare_elemental_primordial_v6.py')]:
    value=names(read(old)).replace('Vector3(7, 5, 10)','Vector3(2, 3.2, 10)')
    write(new,value)
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReviewV5.gd'),('scenes/art_review','ElementalPrimordialModelReviewV5.tscn')]:
    value=names((ROOT/folder/filename).read_text(encoding='utf-8')).replace('Vector3(4, 4, 10)','Vector3(2, 3.2, 10)')
    (ROOT/folder/filename.replace('ReviewV5','ReviewV6')).write_text(value,encoding='utf-8')
gallery=names(read('write_elemental_primordial_v5_review.py'))
gallery=gallery.replace('Uma criatura de rochas irregulares e costas corcundas, com antebraços enormes, garras rombas e patas traseiras menores. A cabeça afunilada de seis olhos fica mergulhada na carapaça. Lajes de cristal ciano com pontas quebradas saem das costas; o núcleo cúbico está no fundo do tórax e aparece pelas aberturas entre as rochas oblíquas. Os volumes foram esculpidos em voxels, com cantos em degraus e faces planas.',
 'Recriação da criatura enviada: uma grande massa de cristal ciano no alto, carapaça escura envolvendo uma cabeça pequena e baixa, antebraços enormes pendendo para dentro e duas pernas abertas por fora dos braços. As pedras se sobrepõem em diagonais, e o núcleo cúbico fica dentro do tórax. O modelo usa blocos grandes de faces planas, cantos retos e textura pixelada discreta.')
gallery=gallery.replace('Criatura rochosa quadrúpede de 3 metros, inspirada na referência enviada: corpo corcunda, enormes membros dianteiros, patas traseiras menores, cabeça de seis olhos ciano, placas de pedra escura e grandes lajes de cristal ciano enraizadas nas costas.',
 'Criatura blocky de 3 metros seguindo a referência enviada: uma massa grande de cristal ciano, carapaça alta, cabeça pequena de seis olhos pintados em pixels, antebraços enormes pendendo para dentro e duas pernas abertas por fora dos braços.')
write('write_elemental_primordial_v6_review.py',gallery)
print('Direct reference reconstruction V6 prepared.')
