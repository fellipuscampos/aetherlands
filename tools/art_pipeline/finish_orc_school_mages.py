"""Orchestrate final exports through the live Blender MCP only."""
import argparse
from pathlib import Path
from blender_mcp_client import execute

parser=argparse.ArgumentParser(); parser.add_argument('schools',nargs='*'); args=parser.parse_args()
source=Path(__file__).with_name('finish_orc_school_mages_mcp.py').read_text(encoding='utf-8')
for school in args.schools or ['sacred','infernal','necromancy','druidism','arcanism','elementalism','review']:
    execute('MAGE_FINISH='+repr(school)+'\n'+source,timeout=900)
