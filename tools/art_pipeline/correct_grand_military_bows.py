"""Review bow reliefs and the dwarf crossbow while preserving existing buildings."""
from pathlib import Path
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
recipes=[('Ranger_Mastery_Hex_V1','ranger_mastery_hex_v1','Ranger_Bow',.13,-.014,1.16,.75),
         ('Orc_Ranger_Mastery_Hex_V1','orc_ranger_mastery_hex_v1','Hunt_Bow',.02,-.102,1.05,.82),
         ('Dwarf_Ranger_Mastery_Hex_V1','dwarf_ranger_mastery_hex_v1','Survey_Crossbow',-.06,-.060,.68,.78)]
for task_name,task_folder,glyph,cx,cy,cz,sc in recipes:
    ASSET_NAME,ASSET_FOLDER=task_name,task_folder
    exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
    exec((PIPELINE/'grand_military_draft_parts.py').read_text(encoding='utf-8'))
    for obj in list(parts):
        if obj['part'].startswith((glyph+'_Bow_',glyph+'_Arrow',glyph+'_Ranged')):
            parts.remove(obj)
            for col in list(obj.users_collection):
                col.objects.unlink(obj)
            groups['09_STUDIO'].objects.link(obj)
            obj['preview_only']=True
            obj.hide_render=obj.hide_viewport=True
    for node in ast.parse((PIPELINE/'grand_military_primitives.py').read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name=='ranged_relief':
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<ranged_relief_review>','exec'))
    ranged_relief(glyph+'_Ranged',cx,cy,cz,sc)
    exec((PIPELINE/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
    print('BOW_REVIEW_SAVED',task_folder,flush=True)
