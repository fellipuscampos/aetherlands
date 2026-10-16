"""Four animated orc siege machines, matching the established siege progression."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/generated/orcs'
WORK = ROOT / 'art_source/orc_siege'
SIEGE_ASSETS = [dict(
    stem='orc_' + key + '_v1', source_stem=key + '_v1', family='siege',
    family_name='Cerco', tier=tier, name=name, gameplay_id=kind,
    character_height_m=2.0 if tier == 3 else 1.8,
    path='res://assets/generated/orcs/orc_' + key + '_v1/orc_' + key + '_v1.glb',
    design=design, prefix=prefix, animated=True)
    for tier, (key, name, kind, design, prefix) in enumerate([
        ('catapult', 'Catapulta Orc', 'v2_unit_catapult', 'hide_bound_torsion_mangonel', 'Catapult'),
        ('trebuchet', 'Trebuchet Orc', 'v2_unit_trebuchet', 'iron_braced_counterweight_engine', 'Trebuchet'),
        ('bombard', 'Bombarda Orc', 'v2_unit_bombard', 'heavy_iron_short_bombard', 'Bombard'),
        ('siege_colossus', 'Colosso Quebra-Muralhas', 'v2_legendary_siege_colossus',
         'six_wheel_twin_heavy_bombard', 'SiegeColossus')])]
