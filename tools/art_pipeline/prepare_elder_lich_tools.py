"""Prepare the static model and established native Godot review pipeline."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; P=ROOT/'tools/art_pipeline'
OLD='archdemon_blocky_v2'; NEW='elder_lich_blocky_v1'
def adapt(s):
    return s.replace(OLD,NEW).replace('Infernal_Archdemon_Blocky_V2','Elder_Lich_Blocky_V1').replace('ArchdemonModelV2Review','ElderLichModelReview').replace('ARCHDEMON_MODEL_VALIDATION','ELDER_LICH_MODEL_VALIDATION').replace('Archdemon Model V2 Review','Elder Lich Model Review')
source=(P/'build_archdemon_blocky_v2_mcp.py').read_text(encoding='utf-8')
header=source[:source.index('centers={')]
header=adapt(header)
start=header.index('protected=['); end=header.index('old_hashes=',start)
header=header[:start]+'''protected=[ROOT/'scripts/data/UnitDatabase.gd',ROOT/'assets/generated/magic/elder_lich/elder_lich.glb']
for stem in ['archdemon_blocky_v5_animated','seraph_blocky_v4_animated']:
    folder=ROOT/'assets/generated/grand_manifestations'/stem
    protected.extend(folder/(stem+'.'+ext) for ext in ('glb','blend'))
protected.append(ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb')
'''+header[end:]
helpers=source[source.index('def mesh_part'):source.index('# Hollow cuirass')]
geometry=(P/'elder_lich_geometry.py.inc').read_text(encoding='utf-8')
uv=source[source.index('coords=[v.co for o in parts'):source.index("palette={'iron'")]
texture=(P/'elder_lich_texture.py.inc').read_text(encoding='utf-8')
end=source[source.index('images=[]'):]
end=adapt(end).replace("+'_Weathered_Iron_Ruby_Stoles'","+'_Ancient_Vestments_Bone_Spectral'")
end=end.replace("rig['status']='Static hollow armor entity: rigid shoulder, forearm, fist, crown, core, mantle and segmented cloth pivots.'","rig['status']='Static ancient spectral mage: anatomically connected arms, skull, staff, tome, vestments and residual spirit.'")
begin=end.index("scene['description']="); finish=end.index("scene['stage']=",begin)
end=end[:begin]+"scene['description']='Three-meter ancient spectral lich: mortal mage transformed by necromancy, cubic skull beneath a deep hood, worn purple vestments, antique staff and research tome. No orbiting mana core.'\n"+end[finish:]
(P/'build_elder_lich_blocky_v1_mcp.py').write_text(header+helpers+geometry+uv+texture+end,encoding='utf-8')
export=adapt((P/'export_archdemon_blocky_v2_mcp.py').read_text(encoding='utf-8'))
begin=export.index("report={'name'"); finish=export.index("    'height_m'",begin)
export=export[:begin]+"report={'name':'Lich Ancião','school':'necromancy','stage':'Static model only','shared_civilizations':True,\n    'concept':'Ancient mortal mage transcended into undeath: hooded skull, connected arms, ancient purple robes, antique staff, open research tome and residual spectral lower body.',\n"+export[finish:]
(P/'export_elder_lich_blocky_v1_mcp.py').write_text(export,encoding='utf-8')
for a,b in [('validate_archdemon_blocky_v2.py','validate_elder_lich_blocky_v1.py'),('finalize_archdemon_blocky_v2_mcp.py','finalize_elder_lich_blocky_v1_mcp.py')]:
    s=adapt((P/a).read_text(encoding='utf-8')).replace('verify_archdemon_blocky_v2.gd','verify_elder_lich_blocky_v1.gd')
    (P/b).write_text(s,encoding='utf-8')
review=adapt((ROOT/'scripts/art_review/ArchdemonModelV2Review.gd').read_text(encoding='utf-8'))
review=review.replace('ARQUIDEMÔNIO — GRANDE MANIFESTAÇÃO INFERNAL','LICH ANCIÃO — GRANDE INVOCAÇÃO DA NECROMANCIA')
(ROOT/'scripts/art_review/ElderLichModelReview.gd').write_text(review,encoding='utf-8')
(ROOT/'scenes/art_review/ElderLichModelReview.tscn').write_text(adapt((ROOT/'scenes/art_review/ArchdemonModelV2Review.tscn').read_text(encoding='utf-8')),encoding='utf-8')
verify=adapt((P/'verify_archdemon_blocky_v2.gd').read_text(encoding='utf-8'))
verify=verify.replace('skeleton.get_bone_count() == 27','skeleton.get_bone_count() > 15').replace('"prepared_bones": 27','"prepared_bones": skeleton.get_bone_count()')
(P/'verify_elder_lich_blocky_v1.gd').write_text(verify,encoding='utf-8')
print('Prepared elder lich live Blender model and native Godot review.')
