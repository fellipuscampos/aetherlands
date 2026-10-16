"""Orc-specific geometry through the shared, UV-preserving wall MCP pipeline."""
from pathlib import Path
WALL_RACE='orc'
exec((Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline')/'build_elf_walls_mcp.py').read_text(encoding='utf-8'))
