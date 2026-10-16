"""Prepare an independent static Arcanism manifestation using the metric pixel-asset helpers."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; TOOLS=ROOT/'tools/art_pipeline'
OLD='nature_avatar_blocky_v3'; STEM='veil_archon_blocky_v1'; NAME='Veil_Archon_Blocky_V1'
def read(name): return (TOOLS/name).read_text(encoding='utf-8')
def names(s): return s.replace(OLD,STEM).replace('Nature_Avatar_Blocky_V3',NAME).replace('NatureAvatarModelReviewV3','VeilArchonModelReview').replace('NATURE_AVATAR_MODEL_VALIDATION','VEIL_ARCHON_MODEL_VALIDATION')
def write(name,s): (TOOLS/name).write_text(s,encoding='utf-8')
src=read('build_nature_avatar_blocky_v3_mcp.py')
head=names(src[:src.index('# An ancient root sovereign:')])
head=head.replace('Three-meter living grove avatar of the druidic school.','Three-meter empty ceremonial sovereign of Arcanism, an exposed azure cube and a fractured gate.')
head=head.replace('old_hashes={',"for stem in ['nature_avatar_blocky_v3','nature_avatar_blocky_v4','nature_avatar_blocky_v5_animated']:\n    protected.extend(ROOT/'assets/generated/grand_manifestations'/stem/(stem+'.'+ext) for ext in ('glb','blend'))\nprotected.extend(ROOT/'assets/generated/humans/human_arcanist_v1'/('human_arcanist_v1.'+ext) for ext in ('glb','blend'))\nold_hashes={")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Strong dark bark')]
uv=uv.replace('GROUND=0.0','GROUND=.25').replace('forest bark, cut wood and layered foliage','blue ceremonial cloth, silver and azure mana')
tail=names(src[src.index('images=[]'):]).replace('Sovereign_Bark_Green_Core','Ceremonial_Blue_Silver_Azure_Core')
tail=tail.replace('Static ancient root sovereign: massive asymmetrical shoulder knots, contiguous crown roots, connected heavy arms, a firm grounded stance and exposed green cube core.','Static Veil Archon: faceless open crown, empty broad mantle, exposed azure cube core, floating square hands, suspended veils and four large portal fragments.')
tail=tail.replace('Three-meter ancient root sovereign inspired by the user reference: massive fused bark silhouette, dark layered root knots, broad asymmetric shoulders, dense forearms, root crown, hollow chest and a single exposed green cube core.','Three-meter Veil Archon of Arcanism: empty blue and silver ceremonial mantle, faceless floating crown, broad shoulders, two suspended square hands, exposed azure cube and one fractured dimensional gate. Shared by civilizations.')
tail=tail.replace('data.ortho_scale=4.3','data.ortho_scale=4.6').replace('(0,0,1.5)','(0,0,1.75)')
write('build_veil_archon_blocky_v1_mcp.py',head+read('veil_archon_geometry.py')+'\n'+uv+read('veil_archon_texture.py')+'\n'+tail)
export=names(read('export_nature_avatar_blocky_v3_mcp.py')).replace('static nature avatar','static Veil Archon')
export=export.replace('abs(low[2])<1e-5','abs(low[2]-.25)<1e-5').replace("'name':'Avatar da Natureza','school':'druidism'","'name':'Arconte do Véu','school':'arcanism'")
export=export.replace('Ancient root sovereign: broad asymmetric fused root shoulders, strong contiguous trunk masses, narrow hollow abdomen, sculpted root crown, dense low square fists and dark bark framing an exposed green cube core.','An empty ceremonial sovereign of folded space: open faceless crown, a broad blue-and-silver mantle, suspended veils and square hands, one exposed azure cube core, four large L-shaped fragments forming a broken dimensional gate.')
export=export.replace('Single exposed emissive green cube, separate rigid pivot inside the upper root arch','Single exposed emissive azure cube, separate rigid pivot in a spacious hollow chest')
start=export.index("    'references':["); end=export.index("    'revision':",start)
export=export[:start]+"    'references':['scripts/data/V2MagicContent.gd: Arcanism and Veil Archon',\n        'assets/generated/humans/human_arcanist_v1',\n        'assets/generated/grand_manifestations/seraph_blocky_v4_animated',\n        'assets/generated/grand_manifestations/archdemon_blocky_v5_animated',\n        'assets/generated/grand_manifestations/elder_lich_blocky_v3_animated',\n        'assets/generated/grand_manifestations/nature_avatar_blocky_v5_animated'],\n"+export[end:]
export=export.replace("'revision':3","'revision':1")
# Check the future full-turn envelope against the actual crown, mantle, hands and gate.
at=export.index('temp=bpy.data.collections.new')
clearance='''from mathutils import Vector
from mathutils.bvhtree import BVHTree
import math
core=next(o for o in parts if o['rig_bone']=='core'); center=rig.data.bones['core'].head_local
targets=[(o,BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])) for o in parts if o!=core]
for step in range(48):
    R=Matrix.Rotation(math.tau*step/48,3,'Z')
    tree=BVHTree.FromPolygons([center+R@(v.co-center) for v in core.data.vertices],[tuple(p.vertices) for p in core.data.polygons])
    for o,other in targets: assert not tree.overlap(other),('Core clearance',step,o.name)
'''
export=export[:at]+clearance+export[at:]
export=export.replace("'pixel_filter':'NEAREST'", "'core_full_rotation_clearance_samples':48,'pixel_filter':'NEAREST'")
write('export_veil_archon_blocky_v1_mcp.py',export)
validator=names(read('validate_nature_avatar_blocky_v3.py')).replace('static nature avatar','static Veil Archon').replace('Nature Avatar Model Review','Veil Archon Model Review').replace('nature_avatar_validation_','veil_archon_validation_')
write('validate_veil_archon_blocky_v1.py',validator)
verify=names(read('verify_nature_avatar_blocky_v3.gd')).replace('absf(low.y) < 0.001','absf(low.y-.25) < 0.001').replace('1.5','1.75')
write('verify_veil_archon_blocky_v1.gd',verify)
final=names(read('finalize_nature_avatar_blocky_v3_mcp.py')).replace('1.5','1.75')
write('finalize_veil_archon_blocky_v1_mcp.py',final)
review=names((ROOT/'scripts/art_review/NatureAvatarModelReviewV3.gd').read_text(encoding='utf-8')).replace('camera.size = 4.3','camera.size = 4.6').replace('1.5','1.75')
lines=review.splitlines()
lines=[ '\tlabel.text = "ARCONTE DO VÉU — GRANDE INVOCAÇÃO DO ARCANISMO\\nModelo · 3 metros · Núcleo azul\\nSetas: girar · R: restaurar vista"' if line.startswith('\tlabel.text = ') else line for line in lines ]
(ROOT/'scripts/art_review/VeilArchonModelReview.gd').write_text('\n'.join(lines)+'\n',encoding='utf-8')
scene=names((ROOT/'scenes/art_review/NatureAvatarModelReviewV3.tscn').read_text(encoding='utf-8'))
(ROOT/'scenes/art_review/VeilArchonModelReview.tscn').write_text(scene,encoding='utf-8')
print('Independent Veil Archon builder, exporter, native validator and review scene prepared.')
