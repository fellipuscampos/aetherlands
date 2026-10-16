"""Follow the user's claw/leg close-up and restore pixel crystal texture without graphics."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v7';NEW='elemental_primordial_blocky_v8'
CONCEPT='Close-up-reference crab limbs: the entire lower arm is a large continuous claw with an elongated lower opening and a tapered hinged opposing jaw. Rear walking legs follow a down-up-down zigzag with bent terminal blades. Approved V6 torso, face, upper arms, crystal shapes and cubic heart retained. Cyan crystals use irregular pixel mottling without bar graphics or painted line diagrams. Three meters tall.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V7','Elemental_Primordial_Blocky_V8').replace('ElementalPrimordialModelReviewV7','ElementalPrimordialModelReviewV8').replace('elemental_primordial_v7','elemental_primordial_v8')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v7_mcp.py')
head=names(src[:src.index('# Direct reconstruction of the supplied creature')])
extra="""for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v7'/('elemental_primordial_blocky_v7.'+ext))
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
geometry=read('elemental_primordial_v7_geometry.py')
a=geometry.index('    # One broad monolithic forearm face');b=geometry.index('    # Arthropod legs:',a)
geometry=geometry[:a]+read('elemental_primordial_v8_chelae.py')+'\n'+geometry[b:]
a=geometry.index('    # Arthropod legs:');b=geometry.index('# Recreate the asymmetrical cluster',a)
geometry=geometry[:a]+read('elemental_primordial_v8_legs.py')+'\n'+geometry[b:]
write('elemental_primordial_v8_geometry.py',geometry)
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Restrained pixel-painted Hytale materials')]
texture=read('elemental_primordial_v7_texture.py')
a=texture.index("    elif kind=='crystal':");b=texture.index("    elif kind=='core':",a)
texture=texture[:a]+"""    elif kind=='crystal':
        # Random small mineral pixels only. No bands, columns, diagrams, glyphs or painted lines.
        cyan=np.array([(31,83,94),(39,96,107),(45,107,117),(52,117,127)],dtype=float)
        field=rng.choice(4,(math.ceil(h/3),math.ceil(w/3)),p=[.16,.46,.28,.10])
        field=field.repeat(3,0).repeat(3,1)[:h,:w]
        rgb=cyan[field];emission=rgb/255*.025
"""+texture[b:]
write('elemental_primordial_v8_texture.py',texture)
tail=names(src[src.index('images=[]'):]).replace('Approved_Reference_Crab_Legs_Plain_Crystals','Reference_Chelae_Folded_Legs_Pixel_Crystals')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_elemental_primordial_v8_mcp.py',head+geometry+'\n'+uv+texture+'\n'+tail)
export=names(read('export_elemental_primordial_v7_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':7","'revision':8").replace("'approved_carapace_face_forearms_preserved'","'approved_carapace_face_upper_arms_preserved'")
export=export.replace("if o['kind']=='crystal':assert np.max(np.ptp(tile,axis=(0,1)))<1e-7,key", "if o['kind']=='crystal':assert len(np.unique(tile.reshape(-1,3),axis=0))<=4,key")
export=export.replace("assert rig.data.bones['pincer_'+label].parent.name=='hand_'+label","assert rig.data.bones['pincer_'+label].parent.name=='forearm_'+label")
export=export.replace("'painted_crystal_graphics':False", "'painted_crystal_graphics':False,'crystal_pixel_texture':True,'integrated_large_claws':True,'double_bend_walking_legs':True")
write('export_elemental_primordial_v8_mcp.py',export)
for old,new in [('validate_elemental_primordial_v7.py','validate_elemental_primordial_v8.py'),('verify_elemental_primordial_v7.gd','verify_elemental_primordial_v8.gd'),('finalize_elemental_primordial_v7_mcp.py','finalize_elemental_primordial_v8_mcp.py'),('compare_elemental_primordial_v7.py','compare_elemental_primordial_v8.py')]:write(new,names(read(old)))
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReviewV7.gd'),('scenes/art_review','ElementalPrimordialModelReviewV7.tscn')]:
    (ROOT/folder/filename.replace('ReviewV7','ReviewV8')).write_text(names((ROOT/folder/filename).read_text(encoding='utf-8')),encoding='utf-8')
gallery=names(read('write_elemental_primordial_v7_review.py'))
gallery=gallery.replace('antebraços enormes terminando em pinças de caranguejo, com abertura real entre o ramo fixo e o ramo móvel','grandes pinças contínuas com o braço, com uma abertura alongada e um ramo móvel afunilado, seguindo a nova referência de perto')
gallery=gallery.replace('duas pernas articuladas de caranguejo, mais próximas do corpo, com extremidades pontudas','duas patas traseiras de caranguejo com dobras em zigue-zague e lâminas terminais curvas em segmentos retos')
gallery=gallery.replace('Os cristais ciano têm superfícies simples, sem desenhos, barras ou linhas pintadas.','Os cristais ciano têm variação pixelada de quatro tons, sem desenhos, barras ou linhas pintadas.')
write('write_elemental_primordial_v8_review.py',gallery)
print('Close-up-reference claws, bent legs and pixel crystals prepared.')
