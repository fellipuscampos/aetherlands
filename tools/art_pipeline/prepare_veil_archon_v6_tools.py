"""Prepare the sculpted voxel redesign without replacing earlier drafts or gameplay data."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];TOOLS=ROOT/'tools/art_pipeline'
OLD='veil_archon_blocky_v5';NEW='veil_archon_blocky_v6'
CONCEPT='Sculpted voxel spectral sovereign: swept inverted-V collar, open crown horns, hollow mineral chest enclosing a magenta cube, deep long jagged arm mantles, asymmetric energy arms and a crooked suspended root body. Cuboid-union geometry and pixel-painted mineral planes.'
def read(n):return (TOOLS/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Veil_Archon_Blocky_V5','Veil_Archon_Blocky_V6').replace('VeilArchonModelReviewV5','VeilArchonModelReviewV6')
def write(n,s):(TOOLS/n).write_text(s,encoding='utf-8')
src=read('build_veil_archon_blocky_v5_mcp.py')
head=names(src[:src.index('# Strict voxel geometry:')])
head=head.replace('old_hashes={',"protected.extend(p for ext in ('glb','blend') if (p:=ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v5'/('veil_archon_blocky_v5.'+ext)).is_file())\nold_hashes={")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# The supplied reference')]
tail=names(src[src.index('images=[]'):]).replace('Stepped_Obsidian_Magenta_Core','Sculpted_Mineral_Open_Chest_Core')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_veil_archon_blocky_v6_mcp.py',head+read('veil_archon_v6_geometry.py')+'\n'+uv+read('veil_archon_v6_texture.py')+'\n'+tail)
export=names(read('export_veil_archon_blocky_v5_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export).replace("'revision':5","'revision':6")
write('export_veil_archon_blocky_v6_mcp.py',export)
for old,new in [('validate_veil_archon_blocky_v5.py','validate_veil_archon_blocky_v6.py'),('verify_veil_archon_blocky_v5.gd','verify_veil_archon_blocky_v6.gd'),('finalize_veil_archon_blocky_v5_mcp.py','finalize_veil_archon_blocky_v6_mcp.py')]:write(new,names(read(old)))
comparison=names(read('compare_veil_archon_v5.py')).replace('assets/generated/grand_manifestations/nature_avatar_blocky_v5_animated/nature_avatar_blocky_v5_animated.glb','assets/generated/grand_manifestations/archdemon_blocky_v5_animated/archdemon_blocky_v5_animated.glb').replace('Avatar da Natureza','Arcdemônio').replace('Nature Avatar','Archdemon')
write('compare_veil_archon_v6.py',comparison)
for folder,name in [('scripts/art_review','VeilArchonModelReviewV5.gd'),('scenes/art_review','VeilArchonModelReviewV5.tscn')]:
    (ROOT/folder/name.replace('V5','V6')).write_text(names((ROOT/folder/name).read_text(encoding='utf-8')),encoding='utf-8')
gallery=names(read('write_veil_archon_v5_review.py'))
gallery=gallery.replace('Uma entidade escura suspensa, com uma gola larga em V, coroa aberta de energia magenta e corpo afilado que desvia para o lado. Longas partes negras pendem dos braços; os braços de energia seguem a pose assimétrica da referência. O núcleo cúbico fica exposto no peito. Os volumes são formados por degraus ortogonais de blocos, com pintura pixelada.',
 'Uma entidade mineral suspensa, com gola larga em V, coroa aberta e um peito realmente vazado que abriga o núcleo cúbico. As carapaças dos braços têm espessura e recortes em blocos, com uma pose espectral assimétrica. O corpo termina em uma raiz afilada que desvia para o lado. A textura usa camadas minerais e poucas fissuras de energia magenta.')
gallery=gallery.replace('Corpo escuro em degraus de blocos, gola em V, coroa aberta de energia magenta, longas carapaças pendentes nos braços, braços espectrais em pose assimétrica e um núcleo cúbico magenta exposto no peito.',
 'Volumes minerais de cuboides unidos, gola larga em V, peito vazado com núcleo cúbico magenta, coroa aberta, longas carapaças dos braços, braços espectrais assimétricos e raiz suspensa afilada. Pintura pixelada de planos minerais e poucas fissuras de mana.')
gallery=gallery.replace('Avatar da Natureza','Arcdemônio').replace('Arconte e Avatar','Arconte e Arcdemônio')
write('write_veil_archon_v6_review.py',gallery)
print('Sculpted voxel V6 pipeline prepared.')
