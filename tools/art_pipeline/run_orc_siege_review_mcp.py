"""Verify native animated sources and show their joint review in live Blender."""
from blender_mcp_client import execute
from orc_siege_assets import ROOT

for script in ('verify_orc_siege_blender.py', 'review_orc_siege_live.py'):
    print('OPEN_BLENDER_MCP_REVIEW', script, flush=True)
    execute(f'''import sys, importlib.util
if {str(ROOT / 'tools/art_pipeline')!r} not in sys.path: sys.path.insert(0, {str(ROOT / 'tools/art_pipeline')!r})
spec = importlib.util.spec_from_file_location({('orc_siege_' + script.removesuffix('.py'))!r}, {str(ROOT / 'tools/art_pipeline' / script)!r})
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
result = module.result
''', timeout=600)
