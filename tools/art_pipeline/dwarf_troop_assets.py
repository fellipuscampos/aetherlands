"""Static dwarf roster. Gameplay IDs are references, not a runtime replacement."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/generated/dwarves'
WORK = ROOT / 'art_source/dwarf_troops'
FAMILIES = {
    'guardian': ('Guardião', [
        ('shieldbearer', 'Escudeiro do Clã', 'v2_unit_shieldbearer'),
        ('guardian', 'Guardião de Ferro', 'v2_unit_guardian'),
        ('sentinel', 'Sentinela da Montanha', 'v2_unit_sentinel'),
        ('guardian_champion', 'Baluarte Ancestral', 'v2_legendary_guardian_champion')]),
    'warrior': ('Guerreiro', [
        ('warrior', 'Marteleiro do Clã', 'v2_unit_warrior'),
        ('swordsman', 'Combatente da Forja', 'v2_unit_swordsman'),
        ('weapon_master', 'Mestre do Aço', 'v2_unit_weapon_master'),
        ('blade_hero', 'Herdeiro da Forja', 'v2_legendary_blade_hero')]),
    'ranger': ('Patrulheiro', [
        ('archer', 'Besteiro do Clã', 'v2_unit_archer'),
        ('hunter', 'Vigia das Passagens', 'v2_unit_hunter'),
        ('elite_marksman', 'Besteiro de Precisão', 'v2_unit_elite_marksman'),
        ('legend_hunter', 'Olho da Montanha', 'v2_legendary_legend_hunter')]),
    'cavalry': ('Cavaleiro', [
        ('cavalier', 'Cavaleiro de Carneiro', 'v2_unit_cavalier'),
        ('shock_cavalier', 'Machado do Clã', 'v2_unit_shock_cavalier'),
        ('armored_cavalier', 'Couraça da Montanha', 'v2_unit_armored_cavalier'),
        ('ram_lord', 'Senhor dos Carneiros', 'v2_legendary_griffon_rider')]),
    'rogue': ('Ladino', [
        ('rogue', 'Batedor das Minas', 'v2_unit_rogue'),
        ('saboteur', 'Sabotador das Galerias', 'v2_unit_saboteur'),
        ('assassin', 'Gume de Ardósia', 'v2_unit_assassin'),
        ('shadow_master', 'Sombra da Montanha', 'v2_legendary_shadow_master')]),
    'siege': ('Cerco', [
        ('catapult', 'Mangonel do Clã', 'v2_unit_catapult'),
        ('trebuchet', 'Lança-rochas de Contrapeso', 'v2_unit_trebuchet'),
        ('bombard', 'Bombarda da Forja', 'v2_unit_bombard'),
        ('siege_colossus', 'Colosso da Forja', 'v2_legendary_siege_colossus')]),
}
TIERS = ['Básica', 'Evolução I', 'Evolução II', 'Suprema lendária']
ASSETS = [dict(stem='dwarf_'+key+'_v1', key=key, family=family,
               family_name=title, tier=tier, tier_name=TIERS[tier],
               name=name, gameplay_id=kind)
          for family, (title, units) in FAMILIES.items()
          for tier, (key, name, kind) in enumerate(units)]
