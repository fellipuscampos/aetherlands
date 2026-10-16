"""Prepare a dedicated static avatar pipeline using the verified rigid pixel-asset helpers."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TOOLS=ROOT/'tools/art_pipeline'
STEM='nature_avatar_blocky_v1'
NAME='Nature_Avatar_Blocky_V1'
def read(name): return (TOOLS/name).read_text(encoding='utf-8')
def write(name,text): (TOOLS/name).write_text(text,encoding='utf-8')
def names(text):
    return text.replace('elder_lich_blocky_v2',STEM).replace('Elder_Lich_Blocky_V2',NAME).replace('ElderLichModelReviewV2','NatureAvatarModelReview').replace('ELDER_LICH_MODEL_VALIDATION','NATURE_AVATAR_MODEL_VALIDATION').replace('elder_lich_v2_validation_','nature_avatar_validation_')
src=read('build_elder_lich_blocky_v2_mcp.py')
head=src[:src.index('# An ancient mortal mage:')]
head=head.replace('Ancient spectral mage: current skeleton skull and worn purple pixel vestments.','Three-meter living grove avatar of the druidic school.')
head=head.replace("for stem in ['archdemon_blocky_v5_animated','seraph_blocky_v4_animated']:","for stem in ['archdemon_blocky_v5_animated','seraph_blocky_v4_animated','elder_lich_blocky_v3_animated','PROTECTED_STATIC_LICH']:")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Bone motifs are reused')]
uv=uv.replace('GROUND=.20','GROUND=0.0').replace('aged ivory skull and purple cloth','forest bark, cut wood and layered foliage')
tail=src[src.index('images=[]'):]
tail=tail.replace('Ancient_Vestments_Bone_Spectral','Ancient_Wood_Leaf_Amber').replace('Static ancient spectral mage: anatomically connected arms, skull, staff, tome, vestments and residual spirit.','Static grounded living grove: connected root limbs, hollow trunk, sapling, carved mask and branch crown.')
tail=tail.replace('Three-meter ancient spectral lich: mortal mage transformed by necromancy, cubic skull beneath a deep hood, worn purple vestments, antique staff and research tome. No orbiting mana core.','Three-meter druidic nature avatar: ancient living wood, root feet, layered forest foliage, branching crown and a living sapling protected in the hollow trunk.')
tail=tail.replace('data.ortho_scale=4.1','data.ortho_scale=4.3').replace('(0,0,1.77)','(0,0,1.5)')
write('build_nature_avatar_blocky_v1_mcp.py',names(head+read('nature_avatar_geometry.py')+'\n'+uv+read('nature_avatar_texture.py')+'\n'+tail).replace('PROTECTED_STATIC_LICH','elder_lich_blocky_v2'))
export=read('export_elder_lich_blocky_v2_mcp.py')
export=export[:export.index("report={'name':")]+'''report={'name':'Avatar da Natureza','school':'druidism','stage':'Static model only','shared_civilizations':True,
    'concept':'Ancient living grove with connected root limbs, hollow wooden trunk, protected sapling, carved amber-eyed mask, branching crown and layered forest foliage.',
    'height_m':high[2]-low[2],'ground_clearance_m':low[2],'size_m':[b-a for a,b in zip(low,high)],
    'parts':len(parts),'triangles':triangles,'prepared_bones':list(rig.data.bones.keys()),
    'animations':0,'meshes':1,'materials':1,'atlas_size':st['atlas'],'texel_density_px_m':[min(densities),max(densities)],
    'pixel_filter':'NEAREST','closed_geometry':True,'rigid_weights':True,'embedded_textures_match':True,
    'references':['assets/generated/nature/temperate_forest_v1','assets/generated/elves/elf_druid_v1','assets/generated/ancient_golems/ancient_golem_v2',
        'assets/generated/grand_manifestations/seraph_blocky_v4_animated','assets/generated/grand_manifestations/archdemon_blocky_v5_animated','assets/generated/grand_manifestations/elder_lich_blocky_v3_animated'],
    'revision':1,'source_scenes':1,'previous_blender_scenes_preserved':len(st['old_scenes']),
    'gameplay_database_unchanged':True,'source_front':'Blender -Y / Godot +Z'}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
st['report']=report
result=report
'''
export=export.replace('Audit and export the static elder lich','Audit and export the static nature avatar').replace('abs(low[2]-.20)','abs(low[2])')
write('export_nature_avatar_blocky_v1_mcp.py',names(export))
validate=names(read('validate_elder_lich_blocky_v2.py')).replace('static elder lich','static nature avatar').replace('Elder Lich Model Review','Nature Avatar Model Review')
write('validate_nature_avatar_blocky_v1.py',validate)
verify=names(read('verify_elder_lich_blocky_v2.gd')).replace('absf(low.y - 0.20)','absf(low.y)').replace('1.77','1.5')
write('verify_nature_avatar_blocky_v1.gd',verify)
final=names(read('finalize_elder_lich_blocky_v2_mcp.py')).replace('1.77','1.5')
write('finalize_nature_avatar_blocky_v1_mcp.py',final)
review=names((ROOT/'scripts/art_review/ElderLichModelReviewV2.gd').read_text(encoding='utf-8'))
review=review.replace('camera.size = 4.1','camera.size = 4.3').replace('1.77','1.5')
start=review.index('\tlabel.text = '); end=review.index('\n',start)
review=review[:start]+'\tlabel.text = "AVATAR DA NATUREZA — GRANDE INVOCAÇÃO DRUÍDICA\\nModelo · 3 metros · Comum às civilizações\\nSetas: girar · R: restaurar vista"'+review[end:]
(ROOT/'scripts/art_review/NatureAvatarModelReview.gd').write_text(review,encoding='utf-8')
scene=names((ROOT/'scenes/art_review/ElderLichModelReviewV2.tscn').read_text(encoding='utf-8'))
(ROOT/'scenes/art_review/NatureAvatarModelReview.tscn').write_text(scene,encoding='utf-8')
print('Dedicated nature-avatar builder, exporter, native validator and review scene prepared.')
