"""Build a strict voxel version of the user's dark crowned spectral reference."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];TOOLS=ROOT/'tools/art_pipeline'
OLD='veil_archon_blocky_v4';NEW='veil_archon_blocky_v5'
CONCEPT='Strict stepped voxel apparition inspired by the supplied image: open magenta crown horns, continuous broad V collar, long broken dark arm mantles, asymmetric spectral arms, drifting tapered body and one cubic magenta chest nucleus. No skull, robot mask, diagonal plate geometry or closed halo.'
def read(n):return (TOOLS/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Veil_Archon_Blocky_V4','Veil_Archon_Blocky_V5').replace('VeilArchonModelReviewV4','VeilArchonModelReviewV5')
def write(n,s):(TOOLS/n).write_text(s,encoding='utf-8')
src=read('build_veil_archon_blocky_v4_mcp.py')
head=names(src[:src.index('# A continuous floating armored apparition')])
head=head.replace('old_hashes={',"protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v4'/('veil_archon_blocky_v4.'+ext) for ext in ('glb','blend'))\nold_hashes={")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Restrained directional pixel painting')]
tail=names(src[src.index('images=[]'):]).replace('Dark_Armor_Azure_Crown_Core','Stepped_Obsidian_Magenta_Core')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_veil_archon_blocky_v5_mcp.py',head+read('veil_archon_v5_geometry.py')+'\n'+uv+read('veil_archon_v5_texture.py')+'\n'+tail)
export=names(read('export_veil_archon_blocky_v4_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=re.sub(r"'core':'[^']*'","'core':'One magenta cube, with a separate pivot and free rotation inside the chest opening'",export)
export=export.replace("'revision':4","'revision':5,'strict_voxel_geometry':True")
export=export.replace('User-supplied floating dark armored apparition with a wide horizontal energy crown','User-supplied dark spectral apparition with open red-magenta crown horns and flowing long arm mantles')
write('export_veil_archon_blocky_v5_mcp.py',export)
for old,new in [('validate_veil_archon_blocky_v4.py','validate_veil_archon_blocky_v5.py'),('verify_veil_archon_blocky_v4.gd','verify_veil_archon_blocky_v5.gd'),('finalize_veil_archon_blocky_v4_mcp.py','finalize_veil_archon_blocky_v5_mcp.py'),('compare_veil_archon_v4.py','compare_veil_archon_v5.py')]:write(new,names(read(old)))
for folder,name in [('scripts/art_review','VeilArchonModelReviewV4.gd'),('scenes/art_review','VeilArchonModelReviewV4.tscn')]:
    (ROOT/folder/name.replace('V4','V5')).write_text(names((ROOT/folder/name).read_text(encoding='utf-8')).replace('Núcleo azul','Núcleo magenta'),encoding='utf-8')
gallery=names(read('write_veil_archon_v4_review.py'))
gallery=gallery.replace('Uma entidade suspensa de armadura escura, com ombros largos, braços compridos e um corpo que afunila até uma ponta. Uma coroa horizontal azul paira sobre a máscara abstrata, sem caveira. O núcleo cúbico fica exposto na abertura do peito. A nova referência orienta a silhueta, traduzida em volumes sólidos e faces planas blocky.',
 'Uma entidade escura suspensa, com uma gola larga em V, coroa aberta de energia magenta e corpo afilado que desvia para o lado. Longas partes negras pendem dos braços; os braços de energia seguem a pose assimétrica da referência. O núcleo cúbico fica exposto no peito. Os volumes são formados por degraus ortogonais de blocos, com pintura pixelada.')
gallery=gallery.replace('Armadura escura contínua, gola larga, braços articulados compridos, mãos quadradas, corpo suspenso afilado, máscara abstrata, coroa horizontal e núcleo cúbico azul exposto.',
 'Corpo escuro em degraus de blocos, gola em V, coroa aberta de energia magenta, longas carapaças pendentes nos braços, braços espectrais em pose assimétrica e um núcleo cúbico magenta exposto no peito.')
gallery=gallery.replace('A referência principal é a nova entidade de armadura escura e coroa horizontal enviada pelo usuário. O azul mantém a identidade arcana.',
 'A referência principal é a entidade escura com coroa aberta e energia magenta enviada pelo usuário. Todos os volumes, com exceção da orientação do cubo, usam faces ortogonais e contornos em degraus.')
gallery=gallery.replace('A estrutura e a silhueta seguem a nova referência enviada, com formas blocky e a identidade azul do Arcanismo.',
 'A silhueta, a pose e a paleta seguem a nova referência enviada. Todas as peças usam faces ortogonais em degraus; apenas o núcleo cúbico tem orientação própria.')
gallery=gallery.replace('Núcleo azul','Núcleo magenta')
write('write_veil_archon_v5_review.py',gallery)
print('Strict stepped voxel V5 pipeline prepared.')
