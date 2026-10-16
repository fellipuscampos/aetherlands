"""Dwarf-specific geometry through the shared wall modeling/export pipeline."""
from pathlib import Path
WALL_RACE='dwarf'
exec((Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline')/'build_elf_walls_mcp.py').read_text(encoding='utf-8'))
