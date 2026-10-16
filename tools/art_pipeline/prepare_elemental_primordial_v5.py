"""Rebuild around the reference's actual mineral anatomy, not rigid armor panels."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v4';NEW='elemental_primordial_blocky_v5'
CONCEPT='User reference translated into a physical voxel mineral creature: irregular hunched charcoal boulders, immense forearms with blunt hooked claws, small splayed rear legs, a tapered six-eyed face buried below its carapace, oblique overlapping breast rocks, huge broken cyan crystal slabs rooted in its back, and a cubic mana heart deep inside the torso. Three meters tall.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V4','Elemental_Primordial_Blocky_V5').replace('ElementalPrimordialModelReviewV4','ElementalPrimordialModelReviewV5').replace('elemental_primordial_v4','elemental_primordial_v5')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v4_mcp.py')
head=names(src[:src.index('# User reference: a hunched black-rock creature')])
extra="""for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v4'/('elemental_primordial_blocky_v4.'+ext))
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Charcoal and warm dark stone')]
tail=names(src[src.index('images=[]'):]).replace('Charcoal_Creature_Cyan_Crystals','Broken_Rock_Creature_Cyan_Slabs')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_elemental_primordial_v5_mcp.py',head+read('elemental_primordial_v5_geometry.py')+'\n'+uv+read('elemental_primordial_v5_texture.py')+'\n'+tail)
export=names(read('export_elemental_primordial_v4_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':4","'revision':5").replace('One independent cyan cubic heart between the open mineral chest plates','One cyan cubic heart deep inside the mineral torso, partially visible through the oblique breast rocks')
write('export_elemental_primordial_v5_mcp.py',export)
for old,new in [('validate_elemental_primordial_v4.py','validate_elemental_primordial_v5.py'),('verify_elemental_primordial_v4.gd','verify_elemental_primordial_v5.gd'),('finalize_elemental_primordial_v4_mcp.py','finalize_elemental_primordial_v5_mcp.py'),('compare_elemental_primordial_v4.py','compare_elemental_primordial_v5.py')]:
    write(new,names(read(old)))
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReviewV4.gd'),('scenes/art_review','ElementalPrimordialModelReviewV4.tscn')]:
    (ROOT/folder/filename.replace('ReviewV4','ReviewV5')).write_text(names((ROOT/folder/filename).read_text(encoding='utf-8')),encoding='utf-8')
gallery=names(read('write_elemental_primordial_v4_review.py'))
gallery=gallery.replace('Uma criatura rochosa corcunda, com membros dianteiros enormes e patas traseiras menores. Placas de carvão e pedra envolvem uma cabeça pequena de seis olhos luminosos e um núcleo cúbico ciano encaixado no tórax. Cinco grandes colunas de cristal saem das costas, com dois afloramentos nos ombros. A referência enviada orienta a silhueta e a paleta; os volumes têm seções quadradas e recortes em degraus.',
 'Uma criatura de rochas irregulares e costas corcundas, com antebraços enormes, garras rombas e patas traseiras menores. A cabeça afunilada de seis olhos fica mergulhada na carapaça. Lajes de cristal ciano com pontas quebradas saem das costas; o núcleo cúbico está no fundo do tórax e aparece pelas aberturas entre as rochas oblíquas. Os volumes foram esculpidos em voxels, com cantos em degraus e faces planas.')
gallery=gallery.replace('Cinco grandes colunas','Cinco grandes lajes').replace('grandes cristais ciano enraizados nas costas','grandes lajes de cristal ciano enraizadas nas costas').replace('O núcleo cúbico fica encaixado no tórax','O núcleo cúbico fica no fundo do tórax, parcialmente encoberto por rochas oblíquas')
write('write_elemental_primordial_v5_review.py',gallery)
print('Reference mineral creature V5 prepared.')
