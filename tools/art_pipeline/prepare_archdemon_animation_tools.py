"""Reuse the established Blender/Godot animation pipeline for the infernal relic."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
P=ROOT/'tools/art_pipeline'
STEM='archdemon_blocky_v4_animated'
def adapt(text):
    for a,b in [('seraph_blocky_v4_animated',STEM),('seraph_animation','archdemon_animation'),
                ('seraph_animations','archdemon_animations'),('SeraphAnimationReview','ArchdemonAnimationReview'),
                ('SERAPH_ANIMATION_VALIDATION','ARCHDEMON_ANIMATION_VALIDATION'),
                ('Seraph Animation Review','Archdemon Animation Review')]: text=text.replace(a,b)
    return text
src=(P/'animate_seraph_blocky_v4_mcp.py').read_text(encoding='utf-8')
head=src[:src.index('rig.animation_data_create()')]
head=head.replace("NAME='Sacred_Seraph_Blocky_V4_Animated'","NAME='Infernal_Archdemon_Blocky_V4_Animated'")
head=head.replace("['seraph_blocky_v4']","['archdemon_blocky_v3']").replace("('seraph_blocky_v4.'+ext)","('archdemon_blocky_v3.'+ext)")
head=head.replace("'Sacred_Seraph_Blocky_V4'","'Infernal_Archdemon_Blocky_V3'")
head=head.replace("+'_Sacred_Ivory_Gold'","+'_Weathered_Iron_Red_Core'")
head=head.replace('Approved V4 geometry and textures; rigid Idle, Walk, Attack and Spell. No root motion.','Side stoles attached to skirt surfaces; spinning red cube inside the chest. Four rigid clips, no root motion.')
custom=(P/'archdemon_animation_geometry.py.inc').read_text(encoding='utf-8')
motion=(P/'archdemon_animation_motion.py.inc').read_text(encoding='utf-8')
tail=src[src.index('clips={}; previous={}'):]
tail=tail.replace('clips=clips,old_scenes=old_scenes','islands=old[\'islands\'],clips=clips,old_scenes=old_scenes')
tail=tail.replace("'geometry_and_textures_preserved':True","'side_stoles_attached':True,'core_is_cube_inside_chest':True")
(P/'animate_archdemon_blocky_v4_mcp.py').write_text(adapt(head)+custom+motion+adapt(tail),encoding='utf-8')
export=(P/'export_seraph_animations_mcp.py').read_text(encoding='utf-8')
start=export[:export.index('old=st[\'reference\']')]
end=export[export.index('# Assemble one export mesh'):]
end=end.replace("==11","==29").replace("==2072","==1084")
report_start=end.index("report={'status'")
report_end=end.index("(OUT/'animation_report.json')")
end=end[:report_start]+'''report={'status':'PASS','model':STEM,'armor_pixels_preserved':True,
        'side_stoles_attached':True,'core_is_cube_inside_chest':True,
        'meshes':1,'materials':1,'triangles':triangles,'bones':29,'root_motion':False,'fps':24,
        'same_channels_all_clips':True,'rest_height_m':3.,'clips':validation,
        'protected_files':len(st['old_hashes'])}
'''+end[report_end:]
(P/'export_archdemon_animations_mcp.py').write_text(adapt(start)+(P/'archdemon_animation_audit.py.inc').read_text(encoding='utf-8')+adapt(end),encoding='utf-8')
for source,target in [('validate_seraph_animations.py','validate_archdemon_animations.py'),('finalize_seraph_animations_mcp.py','finalize_archdemon_animations_mcp.py')]:
    text=adapt((P/source).read_text(encoding='utf-8')).replace('view_distance=7.','view_distance=5.')
    (P/target).write_text(text,encoding='utf-8')
verify=adapt((P/'verify_seraph_animations.gd').read_text(encoding='utf-8'))
verify=verify.replace('==11','==29').replace('==2072','==1084').replace('"triangles":2072,"bones":11','"triangles":1084,"bones":29')
begin=verify.index('\t\t\tvar core_origin')
finish=verify.index('\t\t\tvar points :=',begin)
verify=verify[:begin]+'''\t\t\tvar core_relative := skeleton.get_bone_global_pose(skeleton.find_bone("chest")).affine_inverse() * skeleton.get_bone_global_pose(skeleton.find_bone("core")).origin
\t\t\tvar core_rest := skeleton.get_bone_global_rest(skeleton.find_bone("chest")).affine_inverse() * skeleton.get_bone_global_rest(skeleton.find_bone("core")).origin
\t\t\tassert(core_relative.distance_to(core_rest)<0.00001)
'''+verify[finish:]
verify=verify.replace('"textures_preserved":true','"armor_pixels_preserved":true')
(P/'verify_archdemon_animations.gd').write_text(verify,encoding='utf-8')
review=adapt((ROOT/'scripts/art_review/SeraphAnimationReview.gd').read_text(encoding='utf-8'))
review=review.replace('camera.size = 6.8','camera.size = 4.7').replace('= 0.35','= 0.55').replace('= 0.70','= 0.85').replace('SERAFIM','ARCDEMÔNIO')
(ROOT/'scripts/art_review/ArchdemonAnimationReview.gd').write_text(review,encoding='utf-8')
(ROOT/'scenes/art_review/ArchdemonAnimationReview.tscn').write_text(adapt((ROOT/'scenes/art_review/SeraphAnimationReview.tscn').read_text(encoding='utf-8')),encoding='utf-8')
asset=ROOT/'assets/generated/grand_manifestations'/STEM; asset.mkdir(parents=True,exist_ok=True)
(asset/'archdemon_animation_import.gd').write_text((ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4_animated/seraph_animation_import.gd').read_text(encoding='utf-8'),encoding='utf-8')
print('Prepared archdemon Blender and native Godot animation tools.')
