"""Restore the family rust-red roofing on the existing editable orc guild."""
import ast
from pathlib import Path

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER = 'Orc_Rogue_Guild_Hex_V1','orc_rogue_guild_hex_v1'
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
# Resolve the authoritative palette/design from the builder without rebuilding.
tree = ast.parse((PIPELINE/'orc_rogue_guild_hex_v1_model.py').read_text(encoding='utf-8'))
for node in tree.body:
    if isinstance(node,ast.Assign) and len(node.targets)==1:
        target=node.targets[0]
        if (isinstance(target,ast.Subscript) and isinstance(target.value,ast.Name)
                and target.value.id=='scene' and isinstance(target.slice,ast.Constant)
                and target.slice.value in ('palette_overrides','design_note')):
            scene[target.slice.value] = ast.literal_eval(node.value)
st['design_note'] = scene['design_note']
# The painter creates fresh image datablocks and packs the new disk PNG bytes.
exec((PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8'))
exec((PIPELINE/'orc_rogue_guild_hex_v1_finish.py').read_text(encoding='utf-8'))
