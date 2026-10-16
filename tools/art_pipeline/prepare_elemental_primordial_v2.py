"""Build a new creature revision while preserving the rejected tempest and all earlier assets."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v1';NEW='elemental_primordial_blocky_v2'
CONCEPT='Three-meter physical elemental beast with a solid mineral torso, broad connected shoulders, massive square fists, weightbearing legs, a stepped mineral crown and one cyan cubic heart recessed in the chest. Fire and ice are embodied by its mineral limbs; no particle-shaped meshes or floating cloud ribbons.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V1','Elemental_Primordial_Blocky_V2').replace('ElementalPrimordialModelReview','ElementalPrimordialModelReviewV2').replace('elemental_primordial_v1','elemental_primordial_v2')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v1_mcp.py')
head=names(src[:src.index('# A four-element living tempest')])
extra="""for relative in ['assets/generated/grand_manifestations/elemental_primordial_blocky_v1/elemental_primordial_blocky_v1.glb',
 'assets/generated/grand_manifestations/elemental_primordial_blocky_v1/elemental_primordial_blocky_v1.blend',
 'assets/generated/ancient_golems/ancient_golem_v2/ancient_golem_v2.glb',
 'assets/generated/trolls/troll_blocky_v3/troll_blocky_v3.glb']:
    protected.append(ROOT/relative)
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Quiet voxel cloud strata')].replace('GROUND=.35','GROUND=0.0')
texture=read('elemental_primordial_texture.py').replace("'core':(115,204,211)","'core':(115,204,211),'dark':(35,49,55),'face':(23,35,42)")
texture=texture.replace("'stone':(81,81,68),'mineral':(125,143,111)","'stone':(69,89,96),'mineral':(120,142,144)")
texture=texture.replace("if kind in ('cloud','mist','wind'):","if kind=='face':\n        rgb[:]=base; mask=(yy>=h*.38)&(yy<h*.60)&(xx>2)&(xx<w-3)\n        rgb[mask]=[126,224,232];emission[mask]=[.23,.65,.73]\n    elif kind=='dark':\n        rgb[yy>=h-2]=base+12;rgb[yy<1]=base-7\n    elif kind in ('cloud','mist','wind'):")
tail=names(src[src.index('images=[]'):]).replace('Four_Elements_Storm_Cyan_Heart','Mineral_Creature_Cyan_Heart')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
tail=tail.replace('aim(camera,(0,0,1.85))','aim(camera,(0,0,1.50))')
write('build_elemental_primordial_v2_mcp.py',head+read('elemental_primordial_v2_geometry.py')+'\n'+uv+texture+'\n'+tail)
export=names(read('export_elemental_primordial_v1_mcp.py')).replace('abs(low[2]-.35)','abs(low[2])')
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':1","'revision':2").replace("['cloud','fire','water','earth','wind']","['mineral_body','molten_basalt','ice','cyan_heart']")
export=export.replace("'references':['scripts/data", "'references':['assets/generated/ancient_golems/ancient_golem_v2','assets/generated/trolls/troll_blocky_v3','scripts/data")
write('export_elemental_primordial_v2_mcp.py',export)
for old,new in [('validate_elemental_primordial_v1.py','validate_elemental_primordial_v2.py'),('verify_elemental_primordial_v1.gd','verify_elemental_primordial_v2.gd'),('finalize_elemental_primordial_v1_mcp.py','finalize_elemental_primordial_v2_mcp.py'),('compare_elemental_primordial_v1.py','compare_elemental_primordial_v2.py')]:
    v=names(read(old)).replace('absf(low.y-.35)','absf(low.y)').replace('Vector3(0, 1.85, 0)','Vector3(0, 1.50, 0)')
    write(new,v)
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReview.gd'),('scenes/art_review','ElementalPrimordialModelReview.tscn')]:
    v=names((ROOT/folder/filename).read_text(encoding='utf-8')).replace('Vector3(0, 1.85, 0)','Vector3(0, 1.50, 0)')
    (ROOT/folder/filename.replace('ModelReview','ModelReviewV2')).write_text(v,encoding='utf-8')
gallery=names(read('write_elemental_primordial_v1_review.py'))
gallery=gallery.replace('Uma tempestade viva suspensa: uma coroa larga de nuvens em blocos envolve um núcleo cúbico ciano. Basalto com fissuras de fogo, gelo azul e um bloco de terra mineral se integram à massa; três faixas de vento afunilam a silhueta até a névoa inferior. O modelo usa prismas e volumes de cuboides, com pintura em pixels.',
 'Uma criatura mineral de três metros, com tronco sólido, cabeça de coroa angular, braços pesados e pés largos. Um núcleo cúbico ciano ocupa uma cavidade real no peito. Basalto com fissuras de fogo e placas de gelo formam os membros, com volumes blocky e textura pixelada.')
gallery=gallery.replace('Os feitiços de névoa, vendaval e tempestade elétrica orientam a silhueta de tempestade.','O golem e o troll atuais orientam a construção dos volumes e dos membros conectados.')
gallery=gallery.replace('das nuvens, dos elementos e do vórtice','do corpo mineral').replace('suspenso 0,35 m acima do solo','com pés no plano do solo').replace('Grande manifestação do Arcanismo','Grande manifestação do Elementalismo').replace('apenas a cena do Arconte','apenas a cena do Primordial')
gallery=gallery.replace('Tempestade viva de 3 metros, com nuvens em blocos, fogo âmbar, gelo, terra mineral e três faixas de vento abertas, que formam um vórtice suspenso.','Criatura mineral de 3 metros, com corpo sólido e membros conectados, basalto com fissuras de fogo e placas de gelo.').replace('a silhueta segue o repertório de controle do clima da escola','o corpo segue a linguagem blocky dos monstros atuais')
write('write_elemental_primordial_v2_review.py',gallery)
print('Primordial V2 creature pipeline prepared.')
