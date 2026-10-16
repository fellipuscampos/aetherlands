"""Restore the orc warrior's axe heraldry from its basic military tradition."""
from pathlib import Path
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER='Orc_Warrior_Mastery_Hex_V1','orc_warrior_mastery_hex_v1'
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
exec((PIPELINE/'grand_military_draft_parts.py').read_text(encoding='utf-8'))
for obj in list(parts):
    if obj['part'].startswith(('Pit_Axes_Blade_','Pit_Axes_Clan_Weapon_')):
        parts.remove(obj)
        for col in list(obj.users_collection):
            col.objects.unlink(obj)
        groups['09_STUDIO'].objects.link(obj)
        obj['preview_only']=True
        obj.hide_render=obj.hide_viewport=True
for node in ast.parse((PIPELINE/'grand_military_primitives.py').read_text(encoding='utf-8')).body:
    if isinstance(node,ast.FunctionDef) and node.name=='weapon_relief':
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<clan_axe_relief>','exec'))
for sx in (-1,1):
    weapon_relief('Pit_Axes_Clan_Weapon_'+str(sx),0,.305-.040,.70,.30*.91,sx*.66,'axe')
exec((PIPELINE/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
