"""Standing crab anatomy rebuilt strictly from large cuboids: six weightbearing legs and two block pincers."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v8';NEW='elemental_primordial_blocky_v9'
CONCEPT='Upright blocky crab mini boss: six imposing independently articulated cuboid walking legs, three on each side, form a balanced support footprint. Two massive cuboid palms have opposing angular block jaws and separate moving-jaw pivots. All new appendages are built only from eight-vertex cuboids. Approved carapace, face, upper-arm roots, cyan pixel crystals and internal cubic heart retained. Three meters tall.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V8','Elemental_Primordial_Blocky_V9').replace('ElementalPrimordialModelReviewV8','ElementalPrimordialModelReviewV9').replace('elemental_primordial_v8','elemental_primordial_v9')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v8_mcp.py')
head=names(src[:src.index('# Direct reconstruction of the supplied creature')])
extra="""for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v8'/('elemental_primordial_blocky_v8.'+ext))
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
geometry=read('elemental_primordial_v8_geometry.py')
a=geometry.index('# Gigantic hanging arms');b=geometry.index('# Recreate the asymmetrical cluster',a)
geometry=geometry[:a]+read('elemental_primordial_v9_appendages.py')+'\n'+geometry[b:]
geometry=geometry.replace('inside two articulated crab legs','above six articulated cuboid walking legs')
write('elemental_primordial_v9_geometry.py',geometry)
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Restrained pixel-painted Hytale materials')]
texture=read('elemental_primordial_v8_texture.py')
tail=names(src[src.index('images=[]'):]).replace('Reference_Chelae_Folded_Legs_Pixel_Crystals','Standing_Crab_Cuboid_Limbs')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
tail=tail.replace('data.ortho_scale=4.8; camera.location=(2,-12,3.3)','data.ortho_scale=5.2; camera.location=(5,-11,4.4)')
write('build_elemental_primordial_v9_mcp.py',head+geometry+'\n'+uv+texture+'\n'+tail)
export=names(read('export_elemental_primordial_v8_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':8","'revision':9")
a=export.index("assert len([o for o in parts if 'Pointed_Crab_Tarsus'")
b=export.index('triangles=0; densities=[]',a)
export=export[:a]+"""# All redesigned appendages are large cuboids; six distinct ground contacts support the body.
appendages=[o for o in parts if o.get('construction')=='cuboid']
assert len(appendages)==48
assert all(len(o.data.vertices)==8 and len(o.data.polygons)==6 for o in appendages)
assert all(len(p.vertices)==4 for o in appendages for p in o.data.polygons)
contacts=[o for o in parts if 'Crab_Contact_Tip_Block' in o.name]
assert len(contacts)==6 and len({o['walking_leg'] for o in contacts})==6
assert all(abs(min(v.co.z for v in o.data.vertices))<1e-6 for o in contacts)
points=[min(o.data.vertices,key=lambda v:v.co.z).co for o in contacts]
from mathutils.geometry import convex_hull_2d
hull=[points[i] for i in convex_hull_2d(points)]
body_xy=rig.data.bones['body'].head_local
crosses=[(hull[(i+1)%len(hull)].x-p.x)*(body_xy.y-p.y)-(hull[(i+1)%len(hull)].y-p.y)*(body_xy.x-p.x) for i,p in enumerate(hull)]
assert min(crosses)>0 or max(crosses)<0,'Body pivot must lie inside the six-leg support footprint'
for label in ('L','R'):
    assert rig.data.bones['pincer_'+label].parent.name=='forearm_'+label
    assert len([o for o in parts if 'Pincer_' in o.name and o.name.endswith('_'+label)])==4
"""+export[b:]
export=export.replace("'double_bend_walking_legs':True", "'double_bend_walking_legs':True,'walking_legs':6,'cuboid_appendage_parts':48,'body_inside_support_footprint':True")
write('export_elemental_primordial_v9_mcp.py',export)
for old,new in [('validate_elemental_primordial_v8.py','validate_elemental_primordial_v9.py'),('verify_elemental_primordial_v8.gd','verify_elemental_primordial_v9.gd'),('finalize_elemental_primordial_v8_mcp.py','finalize_elemental_primordial_v9_mcp.py'),('compare_elemental_primordial_v8.py','compare_elemental_primordial_v9.py')]:
    value=names(read(old)).replace('Vector3(2, 3.2, 10)','Vector3(5, 4.4, 10)').replace('space.region_3d.view_distance=5.2','space.region_3d.view_distance=6.0')
    write(new,value)
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReviewV8.gd'),('scenes/art_review','ElementalPrimordialModelReviewV8.tscn')]:
    value=names((ROOT/folder/filename).read_text(encoding='utf-8')).replace('camera.size = 4.8','camera.size = 5.2').replace('Vector3(2, 3.2, 10)','Vector3(5, 4.4, 10)')
    (ROOT/folder/filename.replace('ReviewV8','ReviewV9')).write_text(value,encoding='utf-8')
gallery=names(read('write_elemental_primordial_v8_review.py'))
gallery=gallery.replace('grandes pinças contínuas com o braço, com uma abertura alongada e um ramo móvel afunilado, seguindo a nova referência de perto','duas pinças volumosas construídas com blocos, com palmas cúbicas e dois ramos angulares opostos')
gallery=gallery.replace('duas patas traseiras de caranguejo com dobras em zigue-zague e lâminas terminais curvas em segmentos retos','seis patas de caranguejo construídas com blocos grandes, três de cada lado, distribuídas na frente, no meio e atrás da carapaça')
write('write_elemental_primordial_v9_review.py',gallery)
print('Standing crab: six cuboid walking legs and two massive block pincers prepared.')
