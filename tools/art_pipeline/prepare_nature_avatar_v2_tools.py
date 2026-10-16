"""Prepare a separate reference-inspired revision, preserving the original avatar."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; TOOLS=ROOT/'tools/art_pipeline'
OLD='nature_avatar_blocky_v1'; NEW='nature_avatar_blocky_v2'
def read(name): return (TOOLS/name).read_text(encoding='utf-8')
def names(s): return s.replace(OLD,NEW).replace('Nature_Avatar_Blocky_V1','Nature_Avatar_Blocky_V2').replace('NatureAvatarModelReview','NatureAvatarModelReviewV2')
def write(name,s): (TOOLS/name).write_text(s,encoding='utf-8')
src=read('build_nature_avatar_blocky_v1_mcp.py')
head=names(src[:src.index('# A living grove given')])
head=head.replace("old_hashes={", "protected.extend(ROOT/'assets/generated/grand_manifestations'/'nature_avatar_blocky_v1'/('nature_avatar_blocky_v1.'+ext) for ext in ('glb','blend'))\nold_hashes={")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Current forest bark/foliage colors')]
tail=names(src[src.index('images=[]'):])
tail=tail.replace('Ancient_Wood_Leaf_Amber','Weathered_Roots_Green_Core')
tail=tail.replace('Static grounded living grove: connected root limbs, hollow trunk, sapling, carved mask and branch crown.','Static root entity with hollow body, massive connected arms, angular crown arch and a separate exposed green cube core.')
tail=tail.replace('Three-meter druidic nature avatar: ancient living wood, root feet, layered forest foliage, branching crown and a living sapling protected in the hollow trunk.','Three-meter root avatar inspired by the user reference: no face, hollow intertwined wooden torso, angular root arch, exposed green cube core, heavy low block hands, splinters and moss.')
write('build_nature_avatar_blocky_v2_mcp.py',head+read('nature_avatar_v2_geometry.py')+'\n'+uv+read('nature_avatar_v2_texture.py')+'\n'+tail)
export=names(read('export_nature_avatar_blocky_v1_mcp.py'))
export=export.replace('Ancient living grove with connected root limbs, hollow wooden trunk, protected sapling, carved amber-eyed mask, branching crown and layered forest foliage.','Headless root entity inspired by the supplied Root Brute reference: hollow crossed roots, angular arch around an exposed green cube core, heavy low block hands, pale weathered wood and sparse moss.')
export=export.replace("'revision':1", "'revision':2").replace("'references':[", "'references':['User-supplied Root Brute Rot concept image',")
export=export.replace("'animations':0,'meshes':1", "'core':'Single exposed emissive green cube, separate rigid pivot inside the upper root arch','animations':0,'meshes':1")
write('export_nature_avatar_blocky_v2_mcp.py',export)
for old,new in [('validate_nature_avatar_blocky_v1.py','validate_nature_avatar_blocky_v2.py'),('verify_nature_avatar_blocky_v1.gd','verify_nature_avatar_blocky_v2.gd'),('finalize_nature_avatar_blocky_v1_mcp.py','finalize_nature_avatar_blocky_v2_mcp.py')]:
    write(new,names(read(old)))
script=names((ROOT/'scripts/art_review/NatureAvatarModelReview.gd').read_text(encoding='utf-8')).replace('Modelo · 3 metros','Modelo V2 · 3 metros')
(ROOT/'scripts/art_review/NatureAvatarModelReviewV2.gd').write_text(script,encoding='utf-8')
scene=names((ROOT/'scenes/art_review/NatureAvatarModelReview.tscn').read_text(encoding='utf-8'))
(ROOT/'scenes/art_review/NatureAvatarModelReviewV2.tscn').write_text(scene,encoding='utf-8')
gallery=names(read('write_nature_avatar_review.py'))
gallery=gallery.replace('Um bosque ancestral reunido em uma entidade: corpo de madeira viva, raízes firmes, manto de folhagem e uma coroa de galhos. No tronco oco, um pequeno broto continua crescendo. A máscara de madeira e os olhos âmbar dão a ele uma expressão serena e antiga.','Uma entidade de raízes com o corpo vazado, braços pesados e baixos, madeira envelhecida e galhos quebrados. Um arco de raízes envolve o núcleo cúbico verde exposto no alto do corpo. A silhueta segue a referência enviada, traduzida para a estética blocky do jogo.')
gallery=gallery.replace('Madeira e folhagem da floresta atual, paleta druídica e escala das grandes manifestações.','Referência principal: conceito Root Brute Rot enviado pelo usuário. A madeira e o musgo seguem a identidade druídica e a escala das grandes manifestações do jogo.')
gallery=gallery.replace('madeira ancestral, raízes, folhagem, máscara talhada, coroa de galhos e broto no tronco oco.','raízes entrelaçadas, corpo vazado, arco superior, núcleo cúbico verde exposto, madeira envelhecida, musgo e galhos quebrados.')
write('write_nature_avatar_v2_review.py',gallery)
print('Reference-inspired V2 pipeline prepared; V1 preserved.')
