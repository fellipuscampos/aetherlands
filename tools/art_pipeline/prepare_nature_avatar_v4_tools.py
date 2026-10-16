"""Replace only the unapproved legs, preserving every approved upper-body shape and its scale."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; TOOLS=ROOT/'tools/art_pipeline'
OLD='nature_avatar_blocky_v3'; NEW='nature_avatar_blocky_v4'
def read(name): return (TOOLS/name).read_text(encoding='utf-8')
def names(s): return s.replace(OLD,NEW).replace('Nature_Avatar_Blocky_V3','Nature_Avatar_Blocky_V4').replace('NatureAvatarModelReviewV3','NatureAvatarModelReviewV4')
def write(name,s): (TOOLS/name).write_text(s,encoding='utf-8')
src=read('build_nature_avatar_blocky_v3_mcp.py')
head=names(src[:src.index('# An ancient root sovereign:')])
head=head.replace('old_hashes={',"protected.extend(ROOT/'assets/generated/grand_manifestations'/'nature_avatar_blocky_v3'/('nature_avatar_blocky_v3.'+ext) for ext in ('glb','blend'))\nold_hashes={")
geometry=read('nature_avatar_v3_geometry.py').split('# Firm, wide stance')[0]+read('nature_avatar_v4_floating_roots.py')
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Strong dark bark')]
# Keep the exact old scale and ground datum instead of scaling up the shortened body.
uv=uv.replace('zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)',
 'zmin=0.0; zmax=max(v.z for v in coords); factor=3.0/zmax')
check='''
previous=bpy.app.driver_namespace['nature_avatar_blocky_v3']
old_parts={o.name.removeprefix('Nature_Avatar_Blocky_V3_'):o for o in previous['parts']}
upper_names=[]
for o in parts:
    label=o.name.removeprefix(NAME+'_')
    if label in old_parts and not label.startswith('Lower_Living_Root'):
        old=old_parts[label]
        assert len(o.data.vertices)==len(old.data.vertices)
        assert max((a.co-b.co).length for a,b in zip(o.data.vertices,old.data.vertices))<1e-6,label
        upper_names.append(label)
assert len(upper_names)>60
'''
# The geometry equality check runs after normalization, before atlas packing.
uv=uv.replace('# Metric pixel atlas:',check+'\n# Metric pixel atlas:')
tail=names(src[src.index('images=[]'):])
tail=tail.replace('Static ancient root sovereign: massive asymmetrical shoulder knots, contiguous crown roots, connected heavy arms, a firm grounded stance and exposed green cube core.',
 'Static floating root sovereign: approved upper body preserved, no legs or feet, tapered unequal suspended roots and exposed green cube core.')
tail=tail.replace('Three-meter ancient root sovereign inspired by the user reference: massive fused bark silhouette, dark layered root knots, broad asymmetric shoulders, dense forearms, root crown, hollow chest and a single exposed green cube core.',
 'Floating ancient root sovereign: approved crown, shoulders, torso, arms and green core preserved at the original scale. Suspended tapered roots replace the legs; crown reaches three meters above ground.')
tail=tail.replace('old_scenes=list(old_scenes),old_hashes=old_hashes)', 'old_scenes=list(old_scenes),old_hashes=old_hashes,upper_preserved=upper_names)')
tail=tail.replace("'height_m':3.0,'prepared_bones'", "'height_above_ground_m':3.0,'floating':True,'upper_preserved_parts':len(upper_names),'prepared_bones'")
write('build_nature_avatar_blocky_v4_mcp.py',head+geometry+'\n'+uv+read('nature_avatar_v3_texture.py')+'\n'+tail)
export=names(read('export_nature_avatar_blocky_v3_mcp.py')).replace("'revision':3","'revision':4")
export=export.replace('assert abs(high[2]-low[2]-3)<1e-5 and abs(low[2])<1e-5', "assert abs(high[2]-3)<1e-5 and low[2]>.35\nassert not any(n.startswith(('thigh_','shin_','root_foot_')) for n in rig.data.bones.keys())")
export=export.replace('Ancient root sovereign: broad asymmetric fused root shoulders, strong contiguous trunk masses, narrow hollow abdomen, sculpted root crown, dense low square fists and dark bark framing an exposed green cube core.',
 'Floating root sovereign: approved upper body preserved exactly; legs and feet replaced with a central tapered trunk and unequal suspended roots. Exposed green cube core inside the crown.')
export=export.replace("'height_m':high[2]-low[2],", "'floating':True,'height_above_ground_m':high[2],'upper_body_preserved_parts':st['upper_preserved'],'height_m':high[2]-low[2],")
write('export_nature_avatar_blocky_v4_mcp.py',export)
verify=names(read('verify_nature_avatar_blocky_v3.gd')).replace('skeleton.get_bone_count() > 15','skeleton.get_bone_count() > 10')
verify=verify.replace('assert(absf((high-low).y - 3) < 0.001 and absf(low.y) < 0.001)', 'assert(absf(high.y - 3) < 0.001 and low.y > .35)\n\tfor bone in skeleton.get_bone_count():\n\t\tvar name := str(skeleton.get_bone_name(bone))\n\t\tassert(not name.begins_with("thigh_") and not name.begins_with("shin_") and not name.begins_with("root_foot_"))')
verify=verify.replace('"height_m": high.y-low.y,', '"floating":true,"height_above_ground_m":high.y,"height_m": high.y-low.y,')
write('verify_nature_avatar_blocky_v4.gd',verify)
for old,new in [('validate_nature_avatar_blocky_v3.py','validate_nature_avatar_blocky_v4.py'),('finalize_nature_avatar_blocky_v3_mcp.py','finalize_nature_avatar_blocky_v4_mcp.py')]: write(new,names(read(old)).replace("'height_m':3,'animations'", "'height_above_ground_m':3,'floating':True,'animations'"))
script=names((ROOT/'scripts/art_review/NatureAvatarModelReviewV3.gd').read_text(encoding='utf-8')).replace('Modelo V3 · 3 metros','Modelo V4 · Flutuante · Coroa a 3 metros')
(ROOT/'scripts/art_review/NatureAvatarModelReviewV4.gd').write_text(script,encoding='utf-8')
scene=names((ROOT/'scenes/art_review/NatureAvatarModelReviewV3.tscn').read_text(encoding='utf-8'))
(ROOT/'scenes/art_review/NatureAvatarModelReviewV4.tscn').write_text(scene,encoding='utf-8')
gallery=names(read('write_nature_avatar_v3_review.py'))
gallery=gallery.replace('Um soberano de raízes ancestrais, com ombros enormes e assimétricos, tronco robusto, braços maciços e uma postura firme. A coroa nasce de massas contínuas de casca; o núcleo cúbico verde brilha no alto do corpo, contrastando com a madeira escura. O abdômen mantém sua abertura e suas raízes internas.',
 'Uma entidade flutuante de raízes ancestrais. A coroa, o núcleo verde, os ombros, o tronco e os braços mantêm exatamente as formas e a escala da versão aprovada. A base agora termina em um tronco afunilado e raízes suspensas de comprimentos diferentes, com espaço livre acima do chão.')
gallery=gallery.replace('<span>3 metros</span>','<span>Coroa a 3 metros</span><span>Flutuante</span>')
gallery=gallery.replace('Druida humano, Avatar V2, Avatar V3 e Arcdemônio V5','Druida humano, Avatar V3, Avatar flutuante V4 e Arcdemônio V5').replace('As três grandes invocações mantêm 3 metros de altura.','A coroa do Avatar mantém a altura anterior de 3 metros em relação ao chão; as raízes ficam suspensas.')
gallery=gallery.replace('massas contínuas de raízes, ombros enormes e assimétricos, braços pesados, coroa esculpida, casca escura, abdômen vazado e núcleo cúbico verde exposto.', 'parte superior aprovada preservada, sem pernas ou pés, tronco inferior afunilado e raízes suspensas.')
gallery=gallery.replace('Altura: 3 m; apoiado no solo;', "Coroa a 3 m do solo; corpo de {r['height_m']:.3f} m e vão inferior de {r['ground_clearance_m']:.3f} m;")
write('write_nature_avatar_v4_review.py',gallery)
compare=read('compare_nature_avatar_v3.py').replace('nature_avatar_blocky_v3_review','nature_avatar_blocky_v4_review')
compare=compare.replace("'previous':['Avatar anterior · V2','assets/generated/grand_manifestations/nature_avatar_blocky_v2/nature_avatar_blocky_v2.glb']", "'previous':['Avatar aprovado · V3','assets/generated/grand_manifestations/nature_avatar_blocky_v3/nature_avatar_blocky_v3.glb']")
compare=compare.replace("'avatar':['Avatar revisado · V3','assets/generated/grand_manifestations/nature_avatar_blocky_v3/nature_avatar_blocky_v3.glb']", "'avatar':['Avatar flutuante · V4','assets/generated/grand_manifestations/nature_avatar_blocky_v4/nature_avatar_blocky_v4.glb']")
write('compare_nature_avatar_v4.py',compare)
print('Floating avatar pipeline prepared; approved upper-body geometry is checked against V3.')
