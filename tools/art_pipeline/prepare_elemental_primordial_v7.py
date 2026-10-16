"""Keep the approved V6 creature; replace its mammalian feet with crab limbs and clear crystal graphics."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];T=ROOT/'tools/art_pipeline'
OLD='elemental_primordial_blocky_v6';NEW='elemental_primordial_blocky_v7'
CONCEPT='Approved V6 reference creature with complete crab appendages: massive paired pincers with a real opening and independently pivoted opposing jaws, laterally rooted segmented crab legs and sharp terminal blades. Original carapace, large forearm shells, small six-eyed face and buried cubic heart retained. Plain cyan crystals without painted graphics. Three meters tall.'
def read(n):return (T/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Elemental_Primordial_Blocky_V6','Elemental_Primordial_Blocky_V7').replace('ElementalPrimordialModelReviewV6','ElementalPrimordialModelReviewV7').replace('elemental_primordial_v6','elemental_primordial_v7')
def write(n,s):(T/n).write_text(s,encoding='utf-8')
src=read('build_elemental_primordial_v6_mcp.py')
head=names(src[:src.index('# Direct reconstruction of the supplied creature')])
extra="""for ext in ('glb','blend'):
    protected.append(ROOT/'assets/generated/grand_manifestations/elemental_primordial_blocky_v6'/('elemental_primordial_blocky_v6.'+ext))
"""
head=head.replace('old_hashes={',extra+'old_hashes={')
head=head.replace("o['rig_bone']=bone;", "o['source_part_label']=label; o['rig_bone']=bone;")
legacy="""# Preserve the pixel painting on every approved upper-body face exactly.
legacy_path=OUT/'v6_texture_indices.json'
legacy=bpy.app.driver_namespace.get('elemental_primordial_blocky_v6')
if legacy:
    old_texture_indices={it['obj'].name.removeprefix('Elemental_Primordial_Blocky_V6_')+'|'+str(it['polygon']):i for i,it in enumerate(legacy['islands'])}
    legacy_path.write_text(json.dumps(old_texture_indices),encoding='utf-8')
else:
    old_texture_indices=json.loads(legacy_path.read_text(encoding='utf-8'))
"""
geometry=read('elemental_primordial_v6_geometry.py')
start=geometry.index('    # Two legs spread outside the hanging arms.')
end=geometry.index('# Recreate the asymmetrical cluster',start)
legs="""    # Arthropod legs: short rising coxa, bent armored merus, and a long pointed tarsus.
    hip=Vector((side*.80,.35,1.47));hinge=Vector((side*1.08,.40,1.31))
    knee=Vector((side*1.27,.37,.78));tip=Vector((side*1.36,.13,0))
    coxa='leg_'+label;merus='shin_'+label;tarsus='tarsus_'+label
    centers.update({coxa:hip,merus:hinge,tarsus:knee});parents.update({coxa:'body',merus:coxa,tarsus:merus})
    beam('Crab_Coxa_'+label,hip,hinge,.26,.28,coxa,'dark')
    R=(hinge-knee).to_track_quat('Z','Y').to_matrix();mid=(hinge+knee)/2
    o=hexa('Crab_Merus_'+label,(0,0,0),(.30,.31),(.38,.37),(hinge-knee).length+.08,merus,'stone')
    for v in o.data.vertices:v.co=mid+R@v.co
    o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    slab('Crab_Joint_'+label,knee,(.29,.31,.22),merus,'dark',(0,side*-11,0))
    # A real pointed blade with a square cross section, four flat sides and no sole or toes.
    R=(knee-tip).to_track_quat('Z','Y').to_matrix()
    vertices=[tip]+[knee+R@Vector((x*.15,y*.16,0)) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    mesh_part('Pointed_Crab_Tarsus_'+label,vertices,[(1,2,3,4),(0,2,1),(0,3,2),(0,4,3),(0,1,4)],tarsus,'dark',R)

"""
geometry=geometry[:start]+legs+geometry[end:]
start=geometry.index("    # The reference's heavy black claws become")
end=geometry.index('    # Arthropod legs:',start)
geometry=geometry[:start]+read('elemental_primordial_v7_pincers.py')+'\n'+geometry[end:]
geometry=geometry.replace('inside the two widely splayed legs','inside two articulated crab legs')
write('elemental_primordial_v7_geometry.py',geometry)
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Restrained pixel-painted Hytale materials')]
texture=read('elemental_primordial_v6_texture.py')
texture=texture.replace("rng=np.random.default_rng(663513+index)","paint_index=old_texture_indices.get(o['source_part_label']+'|'+str(it['polygon']),index)\n    rng=np.random.default_rng(663513+paint_index)")
texture=texture.replace('index%3==0','paint_index%3==0')
a=texture.index("    elif kind=='crystal':");b=texture.index("    elif kind=='core':",a)
texture=texture[:a]+"""    elif kind=='crystal':
        # Intentionally plain cyan: no bars, traces, patches, glyphs or internal diagrams.
        rgb[:]=base;emission[:]=base/255*.025
"""+texture[b:]
write('elemental_primordial_v7_texture.py',texture)
tail=names(src[src.index('images=[]'):]).replace('Large_Block_Reference_Creature','Approved_Reference_Crab_Legs_Plain_Crystals')
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_elemental_primordial_v7_mcp.py',head+legacy+'\n'+geometry+'\n'+uv+texture+'\n'+tail)
export=names(read('export_elemental_primordial_v6_mcp.py'))
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export)
export=export.replace("'revision':6","'revision':7").replace("'source_scenes':1", "'crab_legs':True,'crab_pincers':True,'opposing_pincer_jaws':True,'mammalian_feet':False,'painted_crystal_graphics':False,'approved_carapace_face_forearms_preserved':True,'source_scenes':1")
check="""# Verify the requested scope against the approved V6, including the original pixel painting.
import numpy as np
old=bpy.app.driver_namespace['elemental_primordial_blocky_v6']
old_parts={o.name.removeprefix('Elemental_Primordial_Blocky_V6_'):o for o in old['parts']}
old_islands={it['obj'].name.removeprefix('Elemental_Primordial_Blocky_V6_')+'|'+str(it['polygon']):it for it in old['islands']}
old_pixels=np.asarray(old['images'][0].pixels[:],dtype=np.float32).reshape(old['atlas'],old['atlas'],4)
new_pixels=np.asarray(st['images'][0].pixels[:],dtype=np.float32).reshape(st['atlas'],st['atlas'],4)
for o in parts:
    label=o['source_part_label']
    if label in old_parts:
        before=old_parts[label]
        assert len(o.data.vertices)==len(before.data.vertices)
        assert max((a.co-b.co).length for a,b in zip(o.data.vertices,before.data.vertices))<1e-6,label
for it in st['islands']:
    o=it['obj'];key=o['source_part_label']+'|'+str(it['polygon'])
    tile=new_pixels[it['y']:it['y']+it['h'],it['x']:it['x']+it['w'],:3]
    if o['kind']=='crystal':assert np.max(np.ptp(tile,axis=(0,1)))<1e-7,key
    elif key in old_islands:
        before=old_islands[key]
        original=old_pixels[before['y']:before['y']+before['h'],before['x']:before['x']+before['w'],:3]
        assert tile.shape==original.shape and np.max(np.abs(tile-original))<1e-7,key
assert not any('Long_Outer_Foot' in o.name or 'Foot_Stone_Plane' in o.name for o in parts)
assert len([o for o in parts if 'Pointed_Crab_Tarsus' in o.name])==2
assert not any(any(tag in o.name for tag in ['Main_Dark_Hand','Inner_Hand_Hook','Hand_Base']) for o in parts)
assert len([o for o in parts if 'Fixed_Crab_Pincer' in o.name])==2
assert len([o for o in parts if 'Mobile_Crab_Pincer' in o.name])==2
for label in ('L','R'):
    assert rig.data.bones['pincer_'+label].parent.name=='hand_'+label
"""
export=export.replace('triangles=0; densities=[]',check+'\ntriangles=0; densities=[]')
write('export_elemental_primordial_v7_mcp.py',export)
for old,new in [('validate_elemental_primordial_v6.py','validate_elemental_primordial_v7.py'),('verify_elemental_primordial_v6.gd','verify_elemental_primordial_v7.gd'),('finalize_elemental_primordial_v6_mcp.py','finalize_elemental_primordial_v7_mcp.py'),('compare_elemental_primordial_v6.py','compare_elemental_primordial_v7.py')]:write(new,names(read(old)))
for folder,filename in [('scripts/art_review','ElementalPrimordialModelReviewV6.gd'),('scenes/art_review','ElementalPrimordialModelReviewV6.tscn')]:
    (ROOT/folder/filename.replace('ReviewV6','ReviewV7')).write_text(names((ROOT/folder/filename).read_text(encoding='utf-8')),encoding='utf-8')
gallery=names(read('write_elemental_primordial_v6_review.py'))
gallery=gallery.replace('duas pernas abertas por fora dos braços','duas pernas articuladas de caranguejo, mais próximas do corpo, com extremidades pontudas')
gallery=gallery.replace('textura pixelada discreta.','textura pixelada discreta. Os cristais ciano têm superfícies simples, sem desenhos, barras ou linhas pintadas.')
gallery=gallery.replace('antebraços enormes pendendo para dentro','antebraços enormes terminando em pinças de caranguejo, com abertura real entre o ramo fixo e o ramo móvel')
write('write_elemental_primordial_v7_review.py',gallery)
print('Approved creature: crab-leg correction and plain cyan crystals prepared.')
