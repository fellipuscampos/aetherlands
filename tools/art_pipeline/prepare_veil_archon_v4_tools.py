"""Prepare an independent, continuous armored V4 from the user's new reference."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];TOOLS=ROOT/'tools/art_pipeline'
OLD='veil_archon_blocky_v3';NEW='veil_archon_blocky_v4'
CONCEPT='Suspended dark armored apparition: broad swept collar, long articulated arms, tapered floating body, faceless crown mask, horizontal azure blade halo and one exposed cubic chest core. No skull, skeletal ribs or feet.'
def read(n):return (TOOLS/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Veil_Archon_Blocky_V3','Veil_Archon_Blocky_V4').replace('VeilArchonModelReviewV3','VeilArchonModelReviewV4')
def write(n,s):(TOOLS/n).write_text(s,encoding='utf-8')
src=read('build_veil_archon_blocky_v3_mcp.py')
head=names(src[:src.index('# User reference:')])
head=head.replace('old_hashes={',"protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v3'/('veil_archon_blocky_v3.'+ext) for ext in ('glb','blend'))\nold_hashes={")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# The current game')]
tail=names(src[src.index('images=[]'):])
tail=tail.replace('Obsidian_Spectral_Bone_Azure_Core','Dark_Armor_Azure_Crown_Core')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_veil_archon_blocky_v4_mcp.py',head+read('veil_archon_v4_geometry.py')+'\n'+uv+read('veil_archon_v4_texture.py')+'\n'+tail)
export=names(read('export_veil_archon_blocky_v3_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=re.sub(r"'core':'[^']*'","'core':'One azure cube with an independent pivot and clearance inside the open chest'",export)
export=export.replace("'revision':3","'revision':4")
export=export.replace("'assets/generated/skeletons/skeleton_warrior_v1','User-supplied spectral skeleton and black fractured carapace reference'","'User-supplied floating dark armored apparition with a wide horizontal energy crown'")
write('export_veil_archon_blocky_v4_mcp.py',export)
for old,new in [('validate_veil_archon_blocky_v3.py','validate_veil_archon_blocky_v4.py'),('verify_veil_archon_blocky_v3.gd','verify_veil_archon_blocky_v4.gd'),('finalize_veil_archon_blocky_v3_mcp.py','finalize_veil_archon_blocky_v4_mcp.py'),('compare_veil_archon_v3.py','compare_veil_archon_v4.py')]:write(new,names(read(old)))
for folder,name in [('scripts/art_review','VeilArchonModelReviewV3.gd'),('scenes/art_review','VeilArchonModelReviewV3.tscn')]:
    (ROOT/folder/name.replace('V3','V4')).write_text(names((ROOT/folder/name).read_text(encoding='utf-8')),encoding='utf-8')
gallery=names(read('write_veil_archon_v3_review.py'))
gallery=gallery.replace('Uma entidade espectral cercada por grandes carapaças negras quebradas. Costelas e coluna de energia azul ficam expostas, com um crânio cúbico pequeno acima do núcleo de mana. Lâminas suspensas, facetas azuis e poucos fragmentos grandes seguem a referência enviada, com bordas em degraus e faces planas no estilo blocky do jogo.',
 'Uma entidade suspensa de armadura escura, com ombros largos, braços compridos e um corpo que afunila até uma ponta. Uma coroa horizontal azul paira sobre a máscara abstrata, sem caveira. O núcleo cúbico fica exposto na abertura do peito. A nova referência orienta a silhueta, traduzida em volumes sólidos e faces planas blocky.')
gallery=gallery.replace('Carapaças negras fragmentadas, lâminas suspensas, costelas e coluna espectrais azuis, crânio cúbico do estilo do esqueleto atual, núcleo cúbico azul exposto e filamentos de mana abaixo do corpo.','Armadura escura contínua, gola larga, braços articulados compridos, mãos quadradas, corpo suspenso afilado, máscara abstrata, coroa horizontal e núcleo cúbico azul exposto.')
gallery=gallery.replace('A referência principal é a entidade espectral enviada pelo usuário. O azul mantém a identidade arcana; o crânio usa os motivos do esqueleto atual.','A referência principal é a nova entidade de armadura escura e coroa horizontal enviada pelo usuário. O azul mantém a identidade arcana.')
gallery=gallery.replace('A estrutura e a silhueta seguem a referência enviada; o crânio respeita a estética atual do jogo, e o núcleo mantém a identidade azul do Arcanismo.','A estrutura e a silhueta seguem a nova referência enviada, com formas blocky e a identidade azul do Arcanismo.')
gallery=gallery.replace('das carapaças, das costelas e das lâminas','da armadura e das juntas').replace('as carapaças, os ossos e as lâminas','as peças da armadura')
write('write_veil_archon_v4_review.py',gallery)
print('Independent V4 armored apparition pipeline prepared.')
