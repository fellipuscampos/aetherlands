"""Create the current approved direction for the Nature Avatar summon via MCP."""
from pathlib import Path
script = Path(r"C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/animate_nature_avatar_assembly_mcp.py")
exec(compile(script.read_text(encoding="utf-8"), str(script), "exec"))
