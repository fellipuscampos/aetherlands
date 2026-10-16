"""Elven siege equivalents; the legendary machine is a heavy torsion ballista."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/generated/elves'
WORK = ROOT / 'art_source/elf_siege'
SIEGE_ASSETS = [dict(stem='elf_'+key+'_v1', source_stem=key+'_v1', family='siege',
    family_name='Cerco', tier=tier, name=name, gameplay_id=kind,
    character_height_m=2.0 if tier == 3 else 1.8,
    path='res://assets/generated/elves/elf_'+key+'_v1/elf_'+key+'_v1.glb',
    design=design, prefix=prefix)
    for tier,(key,name,kind,design,prefix) in enumerate([
        ('catapult','Catapulta Élfica','v2_unit_catapult','ash_torsion_mangonel','Catapult'),
        ('trebuchet','Trebuchet Élfico','v2_unit_trebuchet','braced_ash_counterweight_engine','Trebuchet'),
        ('bombard','Bombarda Élfica','v2_unit_bombard','bronze_long_bombard','Bombard'),
        ('siege_colossus','Colosso de Guerra Élfico','v2_legendary_siege_colossus','six_wheel_great_torsion_ballista','SiegeColossus')])]
