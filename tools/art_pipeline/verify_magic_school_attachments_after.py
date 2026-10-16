"""Run in Blender MCP after all adjusted scenes have been saved."""
from pathlib import Path

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
AUDIT_TAG = 'after'
exec((PIPELINE / 'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
assert len(rows) == 24
assert all(row['polished'] and not row['detached'] for row in rows), result
result = {'verified_scenes': len(rows), 'remaining_physical_adornments': 0,
          'intentional_levitation': sorted(FLOATING_MAGIC),
          'method': 'AABB connectivity with 0.0015 tolerance plus manual preview review'}
