"""Prepare a physical colossal quadrupedal predator, preserving all older revisions."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v2';NEW='elemental_primordial_blocky_v3'
CONCEPT='Colossal quadrupedal mineral predator with high massive withers, a low rear body, muscular connected legs, large clawed paws, a saber-fanged head, swept horns, a jointed tail and a single cyan cubic heart exposed between the chest plates. Three meters tall, sharp blocky cuboid anatomy and pixel mineral textures.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V2','Elemental_Primordial_Blocky_V3').replace('ElementalPrimordialModelReviewV2','ElementalPrimordialModelReviewV3').replace('elemental_primordial_v2','elemental_primordial_v3')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v2_mcp.py')
head=names(src[:src.index('# A physical elemental creature')])
extra="""for relative in ['assets/generated/grand_manifestations/elemental_primordial_blocky_v2/elemental_primordial_blocky_v2.glb',
 'assets/generated/grand_manifestations/elemental_primordial_blocky_v2/elemental_primordial_blocky_v2.blend',
 'assets/generated/wargs/warg_v1/warg_v1.glb','assets/generated/basilisks/basilisk_blocky_v1/basilisk_blocky_v1.glb']:
    protected.append(ROOT/relative)
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Quiet voxel cloud strata')]
tail=names(src[src.index('images=[]'):]).replace('Mineral_Creature_Cyan_Heart','Primal_Mineral_Predator_Cyan_Heart')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
tail=tail.replace("data.ortho_scale=4.8; camera.location=(3,-11,4.0); aim(camera,(0,0,1.50))","data.ortho_scale=6.0; camera.location=(7,-10,5.0); aim(camera,(0,.20,1.50))")
write('build_elemental_primordial_v3_mcp.py',head+read('elemental_primordial_v3_geometry.py')+'\n'+uv+read('elemental_primordial_v3_texture.py')+'\n'+tail)
export=names(read('export_elemental_primordial_v2_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':2","'revision':3").replace("['mineral_body','molten_basalt','ice','cyan_heart']","['mineral_predator','crystal_fangs','cold_faults','cyan_heart']")
export=export.replace('One independent cyan cubic mana heart with pixel-painted fire, water, earth and air focal colors','One independent cyan cubic heart between the open mineral chest plates')
export=export.replace("""for step in range(48):
    R=Matrix.Rotation(math.tau*step/48,3,'Z')
    tree=BVHTree.FromPolygons([center+R@(v.co-center) for v in core.data.vertices],[tuple(p.vertices) for p in core.data.polygons])
    for o,other in targets: assert not tree.overlap(other),('Core clearance',step,o.name)""", """core_samples=0
for axis in ('X','Y','Z'):
    for step in range(48):
        R=Matrix.Rotation(math.tau*step/48,3,axis)
        tree=BVHTree.FromPolygons([center+R@(v.co-center) for v in core.data.vertices],[tuple(p.vertices) for p in core.data.polygons])
        for o,other in targets: assert not tree.overlap(other),('Core clearance',axis,step,o.name)
        core_samples+=1""")
export=export.replace("'core_full_rotation_clearance_samples':48", "'core_full_rotation_clearance_samples':core_samples,'core_rotation_axes':['X','Y','Z']")
export=export.replace("'references':['assets/generated/ancient_golems/ancient_golem_v2','assets/generated/trolls/troll_blocky_v3',","'references':['assets/generated/wargs/warg_v1','assets/generated/basilisks/basilisk_blocky_v1',")
write('export_elemental_primordial_v3_mcp.py',export)
for old,new in [('validate_elemental_primordial_v2.py','validate_elemental_primordial_v3.py'),('verify_elemental_primordial_v2.gd','verify_elemental_primordial_v3.gd'),('finalize_elemental_primordial_v2_mcp.py','finalize_elemental_primordial_v3_mcp.py'),('compare_elemental_primordial_v2.py','compare_elemental_primordial_v3.py')]:
    v=names(read(old)).replace('Vector3(3, 4.2, 10)','Vector3(7, 5, 10)').replace('Vector3(4, 8, 6)','Vector3(6, 9, 7)').replace('Vector3(-4, 5.2, -10)','Vector3(-7, 5.2, -10)')
    write(new,v)
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReviewV2.gd'),('scenes/art_review','ElementalPrimordialModelReviewV2.tscn')]:
    v=names((ROOT/folder/filename).read_text(encoding='utf-8')).replace('camera.size = 4.8','camera.size = 6.0').replace('Vector3(3, 4.1, 10)','Vector3(7, 5, 10)')
    (ROOT/folder/filename.replace('ReviewV2','ReviewV3')).write_text(v,encoding='utf-8')
gallery=names(read('write_elemental_primordial_v2_review.py'))
gallery=gallery.replace('Uma criatura mineral de três metros, com tronco sólido, cabeça de coroa angular, braços pesados e pés largos. Um núcleo cúbico ciano ocupa uma cavidade real no peito. Basalto com fissuras de fogo e placas de gelo formam os membros, com volumes blocky e textura pixelada.',
 'Um predador elemental quadrúpede de três metros, com dianteira alta e pesada, traseira baixa e quatro patas com garras. Cabeça de mandíbula larga, presas de cristal e chifres voltados para trás. O núcleo cúbico ciano aparece entre as placas do tórax, sob o pescoço. A anatomia usa volumes blocky, rocha escura e fissuras frias em pixels.')
gallery=gallery.replace('O golem e o troll atuais orientam a construção dos volumes e dos membros conectados.','O warg e o basilisco atuais orientam a anatomia blocky; as proporções, as placas e o núcleo distinguem a grande invocação.')
gallery=gallery.replace('Criatura mineral de 3 metros, com corpo sólido e membros conectados, basalto com fissuras de fogo e placas de gelo. Um núcleo cúbico ciano fica exposto no centro, com os quatro focos elementais pintados nos cantos.',
 'Predador quadrúpede mineral de 3 metros, com dianteira pesada, quatro patas conectadas, garras, mandíbula com presas de cristal, coroa voltada para trás e cauda articulada. Um núcleo cúbico ciano fica entre as placas abertas do tórax.')
gallery=gallery.replace('em 48 ângulos','nos três eixos, em 144 ângulos')
write('write_elemental_primordial_v3_review.py',gallery)
print('Primordial V3 quadruped pipeline prepared.')
