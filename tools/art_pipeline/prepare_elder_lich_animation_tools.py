"""Prepare native Godot import, review and playback checks for the animated Lich."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; TOOLS=ROOT/'tools/art_pipeline'
STEM='elder_lich_blocky_v3_animated'; ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
ASSET.mkdir(parents=True,exist_ok=True)
def replace(text):
    return text.replace('archdemon_blocky_v5_animated',STEM).replace('archdemon_animation_import','elder_lich_animation_import').replace('ArchdemonAnimationReview','ElderLichAnimationReview').replace('ARCHDEMON_ANIMATION_VALIDATION','ELDER_LICH_ANIMATION_VALIDATION').replace('archdemon_animations_','elder_lich_animations_').replace('Archdemon Animation Review','Elder Lich Animation Review').replace('animated seraph','animated elder lich').replace('Seraph animation validation','Lich animation validation')

validator=replace((TOOLS/'validate_archdemon_animations_v5.py').read_text(encoding='utf-8'))
validator=validator.replace('verify_elder_lich_animations_v5.gd','verify_elder_lich_animations.gd')
(TOOLS/'validate_elder_lich_animations.py').write_text(validator,encoding='utf-8')
verify=replace((TOOLS/'verify_archdemon_animations_v5.gd').read_text(encoding='utf-8'))
verify=verify.replace('skeleton.get_bone_count()==29','skeleton.get_bone_count()==int(expected.bones)').replace('indices.size()/3==1084','indices.size()/3==int(expected.triangles)')
lines=verify.splitlines()
lines=[line for line in lines if 'var core_relative' not in line and 'var core_rest' not in line and 'core_relative.distance_to' not in line]
verify='\n'.join(lines)+'\n'
verify=verify.replace('"triangles":1084,"bones":29','"triangles":expected.triangles,"bones":expected.bones').replace('armor_pixels_preserved','approved_textures_preserved')
verify=verify.replace('"Idle":0.0,"Walk":0.5,"Attack":0.625,"Spell":1.4','"Idle":2.0,"Walk":0.5,"Attack":0.625,"Spell":1.45')
verify=verify.replace('1.375 if clip=="Spell" else 1.0','1.45 if clip=="Spell" else 1.0')
verify=verify.replace('var fps := 6 if clip=="Idle" else 12 if clip=="Walk" else 24','var fps := 18 if clip=="Idle" else 24')
verify=verify.replace('for clip in ["Idle","Spell"]:', 'for clip in ["Idle","Spell","Attack"]:')
verify=verify.replace('1.45 if clip=="Spell" else 1.0','1.45 if clip=="Spell" else 0.625 if clip=="Attack" else 1.0')
verify=verify.replace('# Interrupted spell must reset its core scale and all wing transforms.','# Interrupted spell must reset every cloth, arm, book and staff-focus transform.')
(TOOLS/'verify_elder_lich_animations.gd').write_text(verify,encoding='utf-8')
review=replace((ROOT/'scripts/art_review/ArchdemonAnimationReview.gd').read_text(encoding='utf-8'))
review=review.replace('ARCDEMÔNIO','LICH ANCIÃO').replace('camera.size = 4.7','camera.size = 4.4')
(ROOT/'scripts/art_review/ElderLichAnimationReview.gd').write_text(review,encoding='utf-8')
tscn=replace((ROOT/'scenes/art_review/ArchdemonAnimationReview.tscn').read_text(encoding='utf-8'))
(ROOT/'scenes/art_review/ElderLichAnimationReview.tscn').write_text(tscn,encoding='utf-8')
post=replace((ROOT/'assets/generated/grand_manifestations/archdemon_blocky_v5_animated/archdemon_animation_import.gd').read_text(encoding='utf-8'))
(ASSET/'elder_lich_animation_import.gd').write_text(post,encoding='utf-8')
finalize=replace((TOOLS/'finalize_archdemon_animations_v5_mcp.py').read_text(encoding='utf-8'))
finalize=finalize.replace('independent animated seraph','independent animated lich')
finalize=finalize.replace('bpy.context.window.scene=scene','bpy.context.window.scene=scene\nif bpy.context.object and bpy.context.object.mode!=\'OBJECT\': bpy.ops.object.mode_set(mode=\'OBJECT\')')
(TOOLS/'finalize_elder_lich_animations_mcp.py').write_text(finalize,encoding='utf-8')
print('Prepared Lich import/review/validation tools.')
