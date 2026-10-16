from pathlib import Path
DRAGON_STEM='elemental_dragon_v2'
source=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\verify_elemental_dragon_source_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
