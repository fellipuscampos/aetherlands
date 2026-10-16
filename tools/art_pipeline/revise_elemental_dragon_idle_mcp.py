from pathlib import Path
DRAGON_REVISE_IDLE=True
source=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/animate_elemental_dragon_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
