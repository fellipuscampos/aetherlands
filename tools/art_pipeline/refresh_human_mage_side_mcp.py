"""Refresh the side image after dropping the empty arm; preserve review view."""
from pathlib import Path
MAGE_INSPECT_SIDE_ONLY=True
source=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/inspect_human_school_mages_mcp.py')
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
