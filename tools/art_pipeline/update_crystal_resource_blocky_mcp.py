"""Apply the requested square bases while preserving the initial asset revision."""
from pathlib import Path
import shutil

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
OUT = ROOT / 'assets/generated/resources/crystals/crystal_cluster_v1'
BACKUP = ROOT / 'art_source/crystal_resource_review/original_hex_revision'
BACKUP.mkdir(parents=True, exist_ok=True)
(BACKUP.parent / '.gdignore').touch()
for name in ('crystal_cluster_v1.blend', 'crystal_cluster_v1.glb',
             'crystal_cluster_v1_albedo.png', 'manifest.json'):
    if not (BACKUP / name).exists():
        shutil.copy2(OUT / name, BACKUP / name)
UPDATE_EXISTING = True
exec((ROOT / 'tools/art_pipeline/build_crystal_resource_mcp.py').read_text(encoding='utf-8'), globals())
