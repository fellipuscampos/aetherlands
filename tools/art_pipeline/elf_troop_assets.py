"""Twenty elf variants made directly from the game's editable human troops."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/generated/elves'
WORK = ROOT / 'art_source/elf_troops'
FAMILIES = {
    'guardian': ('Guardião', [
        ('squire', 'Escudeiro', 'v2_unit_shieldbearer'),
        ('guardian', 'Guardião', 'v2_unit_guardian'),
        ('sentinel', 'Sentinela', 'v2_unit_sentinel'),
        ('guardian_champion', 'Campeão Guardião', 'v2_legendary_guardian_champion')]),
    'warrior': ('Guerreiro', [
        ('warrior', 'Guerreiro', 'v2_unit_warrior'),
        ('swordsman', 'Espadachim', 'v2_unit_swordsman'),
        ('weapon_master', 'Mestre de Armas', 'v2_unit_weapon_master'),
        ('blade_hero', 'Herói da Lâmina', 'v2_legendary_blade_hero')]),
    'ranger': ('Patrulheiro', [
        ('archer', 'Arqueiro', 'v2_unit_archer'),
        ('hunter', 'Caçador', 'v2_unit_hunter'),
        ('elite_marksman', 'Atirador de Elite', 'v2_unit_elite_marksman'),
        ('legend_hunter', 'Caçador Lendário', 'v2_legendary_legend_hunter')]),
    'cavalry': ('Cavalaria', [
        ('cavalier', 'Cavaleiro', 'v2_unit_cavalier'),
        ('shock_cavalier', 'Cavaleiro de Choque', 'v2_unit_shock_cavalier'),
        ('armored_cavalier', 'Cavaleiro Couraçado', 'v2_unit_armored_cavalier'),
        ('griffon_rider', 'Campeão da Cavalaria', 'v2_legendary_griffon_rider')]),
    'rogue': ('Ladino', [
        ('rogue', 'Ladino', 'v2_unit_rogue'),
        ('saboteur', 'Sabotador', 'v2_unit_saboteur'),
        ('assassin', 'Assassino', 'v2_unit_assassin'),
        ('shadow_master', 'Mestre das Sombras', 'v2_legendary_shadow_master')]),
}
TEAM_COLORS = {'guardian': (61, 103, 82), 'warrior': (69, 112, 87),
               'ranger': (62, 101, 69), 'cavalry': (54, 99, 84), 'rogue': (39, 57, 52)}
HAIR_COLORS = [(219, 195, 133), (231, 212, 156), (210, 186, 123), (241, 228, 184)]
ASSETS = [dict(stem='elf_'+key+'_v1', source_stem=key+'_v1', family=family,
               family_name=title, tier=tier, name=name+' Élfico', gameplay_id=kind,
               character_height_m=2.0 if tier == 3 else 1.8,
               path='res://assets/generated/elves/elf_'+key+'_v1/elf_'+key+'_v1.glb')
          for family, (title, units) in FAMILIES.items()
          for tier, (key, name, kind) in enumerate(units)]
