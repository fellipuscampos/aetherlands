"""The eight human units and their animation inheritance contract."""
from pathlib import Path

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
ASSETS = [
    dict(stem='rogue_v1', name='Rogue_V1', prefix='Rogue', label='Ladino', kind='v2_unit_rogue', parent='warrior_v1', height=1.8, family='rogue', level=0),
    dict(stem='saboteur_v1', name='Saboteur_V1', prefix='Saboteur', label='Sabotador', kind='v2_unit_saboteur', parent='rogue_v1', height=1.8, family='rogue', level=1),
    dict(stem='assassin_v1', name='Assassin_V1', prefix='Assassin', label='Assassino', kind='v2_unit_assassin', parent='saboteur_v1', height=1.8, family='rogue', level=2),
    dict(stem='shadow_master_v1', name='ShadowMaster_V1', prefix='ShadowMaster', label='Mestre das Sombras', kind='v2_legendary_shadow_master', parent='assassin_v1', height=2.0, family='rogue', level=3),
    dict(stem='catapult_v1', name='Catapult_V1', prefix='Catapult', label='Catapulta', kind='v2_unit_catapult', parent=None, height=1.8, family='siege', level=0),
    dict(stem='trebuchet_v1', name='Trebuchet_V1', prefix='Trebuchet', label='Trebuchet', kind='v2_unit_trebuchet', parent='catapult_v1', height=1.8, family='siege', level=1),
    dict(stem='bombard_v1', name='Bombard_V1', prefix='Bombard', label='Bombarda', kind='v2_unit_bombard', parent='trebuchet_v1', height=1.8, family='siege', level=2),
    dict(stem='siege_colossus_v1', name='SiegeColossus_V1', prefix='SiegeColossus', label='Colosso de Cerco', kind='v2_legendary_siege_colossus', parent='bombard_v1', height=2.0, family='siege', level=3),
]

def roles(asset):
    return ['Idle', 'Walk', 'Attack'] + (['SneakAttack'] + (['Dismantle'] if asset['level'] else []) if asset['family']=='rogue' else ['DemolitionAmmo'] + (['PreparedBombardment'] if asset['level'] else []))
